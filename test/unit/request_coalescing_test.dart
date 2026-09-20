import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Concurrent callers of the same fetch must share one request.
///
/// The Mi 9T cold-load trace showed `/api/v1/module` twice (20.8 KB),
/// `/api/v1/stores/get-stores/all` three times (91.7 KB) and
/// `/api/v1/customer/cart/list` twice — because several rails each asked for
/// the same list inside one `Future.wait`.
///
/// A `if (x == null) fetch()` guard does not help there: every caller reads
/// null before any of them has assigned, so the guard loses the race. The fix
/// is to hold the in-flight future and hand it to later callers.
///
/// Asserted on the source because exercising it needs the whole DI graph and a
/// network stub, and the property is structural — the same reasoning as
/// `route_guard_test.dart`.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// A coalesced fetch keeps the future, returns it to a second caller, and
  /// clears it on completion — checking identity so a newer fetch is not
  /// cleared by an older one finishing late.
  void expectCoalesced(String source, String field, String label) {
    expect(
      source,
      contains('Future<void>? $field'),
      reason: '$label must hold the in-flight future',
    );
    expect(
      source,
      contains('if (inFlight != null) return inFlight;'),
      reason: '$label must hand the in-flight future to a second caller',
    );
    expect(
      source,
      contains('identical($field, fetch)'),
      reason: '$label must clear by identity — a stale completion must not '
          'clear a newer fetch',
    );
  }

  test('getModules coalesces', () {
    // Home calls this twice on a cold load: once unconditionally, once behind
    // a `moduleList == null` guard that the race defeats.
    expectCoalesced(
      read('lib/features/splash/controllers/splash_controller.dart'),
      '_modulesFetchInFlight',
      'SplashController.getModules',
    );
  });

  test('getFeaturedStoreList coalesces', () {
    expectCoalesced(
      read('lib/features/store/controllers/store_controller.dart'),
      '_featuredFetchInFlight',
      'StoreController.getFeaturedStoreList',
    );
  });

  test('getCartDataOnline coalesces — the original of the pattern', () {
    // This one predates the others and is where the shape came from.
    final String cart = read(
      'lib/features/cart/controllers/cart_controller.dart',
    );
    expect(cart, contains('_cartFetchInFlight'));
    expect(cart, contains('identical(_cartFetchInFlight, fetch)'));
  });

  test('the featured-store prefetch stays bounded', () {
    // An unbounded per-store fan-out turned a 16-request home load into 29,
    // and it grows with the feed — a merchant signing up makes home slower
    // for everyone.
    final String home = read('lib/features/home/screens/home_screen.dart');
    expect(home, contains('_kRecommendedPrefetchLimit'));
    expect(
      home,
      contains('storeRecommendedItems.containsKey'),
      reason: 'a refresh must not re-request stores it already has',
    );
  });
}
