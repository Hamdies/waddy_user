import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What `StoreController.getStoreDetails` promises, and who may use it.
///
/// ## Why this file is a source test
///
/// The method used to fetch a store **and** initialise checkout time slots,
/// compute a delivery distance, set the order type, reset checkout, reload
/// home and (on a slug link) reassign the user's saved address — six effects
/// behind a name that says "get", with `fromCart` / `fromModule` flags to
/// suppress the ones a caller did not want. Exercising it needs half the app
/// registered, so the contract is read off the source, the way
/// `route_guard_test.dart` reads route middleware.
///
/// ## What it is now (ST-02, ST-11)
///
/// A fetch for the store PAGE. Its only callers are the two store screens.
/// The cart has its own store (`CartController.cartStore`, behaviour-tested in
/// `cart_store_test.dart`) and checkout applies its own setup
/// (`CheckoutController._applyStore`). What the page keeps is the one effect a
/// shared link genuinely needs: moving the saved address to the store.
///
/// The ST-02 guard at the bottom is the one that matters most: on device, the
/// cart screen wrote the cart's store into `StoreController.store` and the
/// store page under it showed the wrong store's header over its own menu.
void main() {
  late String source;

  setUpAll(() {
    source =
        File(
          'lib/features/store/controllers/store_page_controller.dart',
        ).readAsStringSync();
  });

  /// The body of `getStoreDetails`, by brace matching from its signature.
  String methodBody(String src) {
    final int at = src.indexOf('Future<Store?> getStoreDetails(');
    expect(at, isNot(-1), reason: 'getStoreDetails was renamed or removed');

    // Skip the signature's own parentheses first — the optional-parameter
    // block `{ bool fromCart = false, ... }` is braces too, and matching from
    // the first `{` would return the parameter list rather than the body.
    int p = src.indexOf('(', at);
    int parenDepth = 0;
    while (p < src.length) {
      if (src[p] == '(') parenDepth++;
      if (src[p] == ')') {
        parenDepth--;
        if (parenDepth == 0) break;
      }
      p++;
    }

    int i = src.indexOf('{', p);
    int depth = 0;
    final int start = i;
    while (i < src.length) {
      if (src[i] == '{') depth++;
      if (src[i] == '}') {
        depth--;
        if (depth == 0) return src.substring(start, i + 1);
      }
      i++;
    }
    fail('unbalanced braces in getStoreDetails');
  }

  /// Lines of [code] with `//` comments removed — bodies explain removed
  /// calls by name, and matching the explanation would fail on the prose.
  String stripComments(String code) => code
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  group('a fetch for the store page, nothing else (ST-02)', () {
    test('no checkout setup and no home reload inside the fetch', () {
      final String body = stripComments(methodBody(source));
      for (final String effect in <String>[
        'CheckoutController',
        'initializeTimeSlot',
        'setOrderType',
        'getDistanceInKM',
        'clearPrevData',
        'HomeScreen.loadData',
      ]) {
        expect(body.contains(effect), isFalse, reason: '$effect is back');
      }
    });

    test('the suppressor flags are gone', () {
      final int at = source.indexOf('Future<Store?> getStoreDetails(');
      final String signature = source.substring(at, source.indexOf('{', at));
      expect(signature.contains('fromCart'), isFalse);
      expect(signature.contains('fromModule'), isFalse);
    });

    test('a slug link reassigns the user address to the store', () {
      // The one effect kept: a shared store URL can arrive before the user
      // has any saved address, and nothing downstream can price delivery
      // without one.
      expect(source, contains('setStoreAddressToUserAddress'));
      expect(methodBody(source), contains('slug.isNotEmpty'));
    });

    test('only the two store screens call it', () {
      final List<String> callers = <String>[];
      for (final FileSystemEntity f in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.contains('/domain/')) continue; // the service layer's own
        final String code = stripComments(f.readAsStringSync());
        // `storeServiceInterface.getStoreDetails` is the network call itself.
        if (RegExp(
          r'(?<!ServiceInterface)\.getStoreDetails\(',
        ).hasMatch(code)) {
          callers.add(f.path);
        }
      }
      callers.sort();
      expect(callers, <String>[
        'lib/features/store/screens/food_store_screen.dart',
        'lib/features/store/screens/store_screen.dart',
      ]);
    });
  });

  group('failure behaviour', () {
    test('a failed fetch leaves _store null rather than stale', () {
      // `_store = null` before the await: a store that fails to load must not
      // leave the previous store's menu on screen.
      expect(methodBody(source), contains('_store = null'));
    });

    test('the loading flag is always cleared', () {
      final String body = methodBody(source);
      expect(body, contains('_isLoading = true'));
      expect(body, contains('_isLoading = false'));
    });
  });

  group('coordinates cannot crash the store open path', () {
    test('no raw double.parse on a coordinate in this method', () {
      // Four throwing reads used to sit on the distance call: a `!` on the
      // nullable saved address plus three `double.parse` on server strings.
      // Opening a store is not a place to crash.
      // Whole file: the coordinate reads moved into helpers.
      expect(
        source.contains('double.parse('),
        isFalse,
        reason:
            'use Parse.coordinate — a distance we cannot compute is a '
            'missing distance, not a crash',
      );
      expect(source, contains('Parse.coordinate'));
    });

    test('the saved address is read nullable', () {
      expect(
        source.contains('getUserAddressFromSharedPref()!'),
        isFalse,
        reason:
            'no saved address is the normal state until the location gate '
            'resolves one',
      );
    });
  });

  group('checkout owns its setup', () {
    late String checkout;
    setUpAll(() {
      checkout =
          File(
            'lib/features/checkout/controllers/checkout_controller.dart',
          ).readAsStringSync();
    });

    test('time slots, order type and distance are applied by checkout', () {
      final int at = checkout.indexOf('void _applyStore(Store store)');
      expect(at, isNot(-1));
      final String body = checkout.substring(at, checkout.indexOf('\n  }', at));
      expect(body, contains('initializeTimeSlot'));
      expect(body, contains('setOrderType'));
      expect(body, contains('_computeDistanceTo'));
    });

    test('the schedule loop runs once per checkout, not twice', () {
      // It ran as a side effect of the store fetch AND from initCheckoutData,
      // which is what cost four schedule-loop runs. One call site now.
      // Bare calls only: not the definition, not the service call inside it.
      final int calls =
          RegExp(
            r'(?<!Future<void> )(?<![.\w])initializeTimeSlot\(',
          ).allMatches(stripComments(checkout)).length;
      expect(calls, 1);
    });

    test('checkout does not go through StoreListController for its store', () {
      expect(stripComments(checkout).contains('StoreListController'), isFalse);
    });
  });

  group('the page\'s store stays the page\'s (ST-02, Phase 4)', () {
    test('the app-wide StoreListController holds no store page state', () {
      // Phase 4 moved the page's store, menu, categories and filters onto a
      // per-page StorePageController. If any of it comes back to the
      // singleton, it outlives its page again — which is what ST-01 was.
      final String app = stripComments(
        File(
          'lib/features/store/controllers/store_list_controller.dart',
        ).readAsStringSync(),
      );
      for (final String member in <String>[
        'Store? get store',
        'storeItemModel',
        'categoryIndex',
        'subCategoriesOf',
        'storeRail(',
        'getStoreDetails(',
        'resetStoreBrowsing',
      ]) {
        expect(app.contains(member), isFalse, reason: '$member is back');
      }
    });

    test('outside the store feature, only the no-delivery sheet asks which '
        'store page is open', () {
      // It names the store PAGE a blocked add-to-cart tap came from. Anything
      // else wanting "the store" means the cart's (CartController.cartStore)
      // or checkout's own.
      final Map<String, int> readers = <String, int>{};
      for (final FileSystemEntity f in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.startsWith('lib/features/store/')) continue;
        final int n = RegExp(r'StorePageController\b')
            .allMatches(stripComments(f.readAsStringSync()))
            .length;
        if (n > 0) readers[f.path] = n;
      }
      expect(readers, <String, int>{
        'lib/features/cart/controllers/cart_controller.dart': 1,
      });
    });
  });
}
