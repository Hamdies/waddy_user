import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every route that exposes a user's own data must carry `AuthGuardMiddleware`.
///
/// ## Why a source test rather than a widget test
///
/// Building 75 routes needs the whole DI graph, a config, an address and a
/// network. The property being asserted is structural — "this route declares
/// that middleware" — so it is read off `route_helper.dart` directly. A widget
/// test would be slower, flakier and would not cover more.
///
/// ## Why this matters
///
/// `app_links` deep linking is live, so a URL can drop a user straight onto a
/// named route. Before this, 69 of 75 routes were unguarded, and six of the
/// sensitive ones had **neither** a middleware nor an in-screen
/// `NotLoggedInScreen` fallback: `order`, `orderTracking`, `refund`,
/// `addAddress`, `editAddress` and `offlinePaymentScreen`. The rest were
/// "defended by accident" — the screen happened to check, which is not the
/// same as the route refusing to open.
///
/// ## The deliberate exclusions
///
/// `payment` and `orderSuccess` are **not** guarded, and must not be. Both
/// carry `guest_id` and `create_account` parameters: they are the tail of the
/// guest-to-account conversion flow, where the order is placed before the
/// account exists. Guarding them would bounce a paying customer to a login
/// screen mid-payment.
///
/// Guest *checkout* is disabled (`splash_controller.dart` forces
/// `guestCheckoutStatus = false`), so the rest of the checkout chain does
/// require an account.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/helper/route_helper.dart').readAsStringSync();
  });

  /// Returns the full `GetPage(...)` block declaring [routeName], by matching
  /// parentheses rather than guessing at line counts.
  String? pageBlockFor(String source, String routeName) {
    final int nameAt = source.indexOf('name: $routeName,');
    if (nameAt < 0) return null;
    final int start = source.lastIndexOf('GetPage(', nameAt);
    if (start < 0) return null;

    int depth = 0;
    int i = source.indexOf('(', start);
    while (i < source.length) {
      if (source[i] == '(') {
        depth++;
      } else if (source[i] == ')') {
        depth--;
        if (depth == 0) return source.substring(start, i + 1);
      }
      i++;
    }
    return null;
  }

  /// Routes that expose a user's own data, money, or conversations.
  ///
  /// Add to this list when adding such a route. The test then fails until the
  /// middleware is attached, which is the entire point.
  const List<String> sensitiveRoutes = <String>[
    // Money and orders
    'order',
    'orderDetails',
    'orderTracking',
    'refund',
    'wallet',
    'checkout',
    'offlinePaymentScreen',
    'subscriptionPayment',
    // Identity and personal data
    'profile',
    'updateProfile',
    'address',
    'addAddress',
    'editAddress',
    // Account-scoped rewards
    'coupon',
    'loyalty',
    'referAndEarn',
    'favourite',
    // Private communication
    'messages',
    'conversation',
    'notification',
    // Attributable user content
    'storeReview',
    'rateReview',
  ];

  /// Guarding these would break a real flow. Each needs a reason, not just an
  /// entry.
  const Map<String, String> deliberatelyOpen = <String, String>{
    'payment':
        'carries guest_id and create_account — the guest-to-account conversion '
        'happens here, after the order is placed but before the account exists',
    'orderSuccess':
        'same conversion flow: takes guestId and createAccount parameters',
  };

  group('sensitive routes require authentication', () {
    test('every sensitive route exists in route_helper', () {
      final List<String> missing = <String>[
        for (final String route in sensitiveRoutes)
          if (pageBlockFor(source, route) == null) route,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'these route names are in the sensitive list but not declared — '
            'either they were renamed or the list is stale: $missing',
      );
    });

    test('every sensitive route declares AuthGuardMiddleware', () {
      final List<String> unguarded = <String>[
        for (final String route in sensitiveRoutes)
          if (!(pageBlockFor(source, route)?.contains('AuthGuardMiddleware') ??
              false))
            route,
      ];

      expect(
        unguarded,
        isEmpty,
        reason:
            'unguarded sensitive routes: $unguarded\n'
            'A deep link can open these directly. Add '
            '`middlewares: [AuthGuardMiddleware()]` to the GetPage, or move the '
            'route into deliberatelyOpen with a reason.',
      );
    });
  });

  group('the exclusions stay deliberate', () {
    test('a deliberately-open route is not quietly guarded later', () {
      // If someone guards `payment`, a paying guest gets bounced to login
      // mid-transaction. This fails loudly rather than becoming a support
      // ticket about abandoned carts.
      for (final MapEntry<String, String> entry in deliberatelyOpen.entries) {
        final String? block = pageBlockFor(source, entry.key);
        expect(block, isNotNull, reason: '${entry.key} is no longer declared');
        expect(
          block!.contains('AuthGuardMiddleware'),
          isFalse,
          reason:
              '${entry.key} must stay open: ${entry.value}. '
              'If that is no longer true, remove it from deliberatelyOpen.',
        );
      }
    });

    test('sensitive and deliberately-open do not overlap', () {
      final Set<String> overlap =
          sensitiveRoutes.toSet().intersection(deliberatelyOpen.keys.toSet());
      expect(overlap, isEmpty);
    });
  });

  group('the guard itself', () {
    test('route_helper imports the middleware it relies on', () {
      expect(source, contains('auth_guard_middleware.dart'));
    });

    test('AuthGuardMiddleware redirects rather than throwing', () {
      // A guard that throws would crash the app on a deep link instead of
      // sending the user to sign in.
      final String middleware =
          File('lib/common/widgets/auth_guard_middleware.dart')
              .readAsStringSync();
      expect(middleware, contains('RouteSettings'));
      expect(middleware, contains('isLoggedIn'));
      expect(middleware, isNot(contains('throw ')));
    });
  });

  group('route parameters cannot crash the app', () {
    test('no route parses a parameter without a fallback', () {
      // `app_links` deep linking is live, so route parameters are attacker-
      // controlled strings. `int.parse(Get.parameters['id']!)` threw twice
      // over on a malformed link — on the `!` when the key was absent, and on
      // the parse when it was not a number — and a throw inside a GetPage
      // builder takes the app down as it opens. That is a crash any stranger
      // could trigger with a URL.
      final RegExp unguardedParse =
          RegExp(r"(?:int|double)\.parse\(Get\.parameters");
      final Iterable<Match> hits = unguardedParse.allMatches(source);
      expect(
        hits.map((Match m) => source.substring(m.start, m.start + 60)).toList(),
        isEmpty,
        reason: 'use _paramInt / _paramDouble (or the OrNull variants) so a '
            'malformed deep link renders an empty screen instead of crashing',
      );
    });

    test('the safe accessors exist and use tryParse', () {
      expect(source, contains('static int _paramInt('));
      expect(source, contains('static int? _paramIntOrNull('));
      expect(source, contains('static double _paramDouble('));
      expect(source, contains('static double? _paramDoubleOrNull('));
      // tryParse is the whole point; parse would reintroduce the throw.
      expect(source, contains('int.tryParse'));
      expect(source, contains('double.tryParse'));
    });

    test('the accessors treat the literal string "null" as absent', () {
      // GetX stringifies absent parameters as "null" in several call sites
      // (the route table itself checks for it), so the accessors must too.
      expect(source, contains("raw == 'null'"));
    });
  });
}
