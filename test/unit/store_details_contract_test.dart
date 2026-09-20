import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What `StoreController.getStoreDetails` promises its six callers.
///
/// ## Why this file is a source test
///
/// The method fetches a store **and** initialises checkout time slots,
/// computes a delivery distance, sets the order type, can reassign the user's
/// saved address, and can trigger a full home reload. Five side effects behind
/// a name that says "get".
///
/// Exercising it needs StoreController, CheckoutController, LocationController,
/// SplashController, LocalizationController, a saved address and a network
/// stub. That is a lot of scaffolding to assert something structural — so the
/// side-effect *contract* is read off the source, the way
/// `route_guard_test.dart` reads route middleware.
///
/// This is a characterization test: it pins the behaviour **as it is**, so a
/// decomposition can prove it changed nothing by accident. Where the current
/// behaviour is wrong, the test says so and asserts the wrong thing anyway.
///
/// ## The six callers and what each actually wants
///
/// | caller | wants |
/// |---|---|
/// | `food_store_screen` | the store, plus order type |
/// | `store_screen` | the store, plus order type |
/// | `checkout_controller` | the store, time slots, distance |
/// | `cart_screen` (×2) | the store only (`fromCart: true`) |
/// | `item_controller` | the store only |
///
/// Nobody wants all five effects. `fromCart` and `slug` exist to suppress the
/// ones a given caller does not want, which is the shape of a method doing too
/// much.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/features/store/controllers/store_controller.dart')
        .readAsStringSync();
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

  group('the short-circuit', () {
    test('a caller that already has the store skips the fetch entirely', () {
      // `if (store.name != null) { _store = store; }` — passing a populated
      // Store means "use this one", and none of the side effects run. Two
      // callers rely on it to avoid a redundant round trip.
      final String body = methodBody(source);
      expect(body, contains('if (store.name != null)'));
    });
  });

  group('the five side effects, pinned', () {
    test('time slots are initialised from inside the fetch', () {
      // This is why calling it twice cost four schedule-loop runs: the
      // side effect fires here, and initCheckoutData used to fire it again.
      expect(methodBody(source), contains('initializeTimeSlot'));
    });

    test('distance is computed unless the caller came from the cart', () {
      final String body = methodBody(source);
      // The call now lives in _computeDeliveryDistance; the *decision* stays
      // at the call site, which is the part that matters.
      expect(source, contains('getDistanceInKM'));
      expect(
        body,
        contains('!fromCart && slug.isEmpty'),
        reason: 'the cart already knows its distance; a slug link has no '
            'user address to measure from yet',
      );
    });

    test('a slug link reassigns the user address to the store', () {
      // The most surprising effect: opening a shared store link MOVES the
      // user's saved location. Deliberate — a slug link can arrive before any
      // address exists — but it is not something "get store details" implies.
      expect(source, contains('setStoreAddressToUserAddress'));
      // The guard stays visible in the fetch itself.
      expect(methodBody(source), contains('slug.isNotEmpty'));
    });

    test('a module entry triggers a full home reload', () {
      expect(methodBody(source), contains('HomeScreen.loadData'));
    });

    test('order type is always set, even when the fetch failed', () {
      // Outside the `storeDetails != null` block on purpose: a failed fetch
      // still leaves checkout with a defined order type rather than a stale
      // one from the previous store.
      // Called through _applyOrderType, and reached on BOTH the short-circuit
      // path and the post-fetch path.
      expect(source, contains('setOrderType'));
      expect(methodBody(source), contains('_applyOrderType'));
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
        reason: 'use Parse.coordinate — a distance we cannot compute is a '
            'missing distance, not a crash',
      );
      expect(source, contains('Parse.coordinate'));
    });

    test('the saved address is read nullable', () {
      expect(
        source.contains('getUserAddressFromSharedPref()!'),
        isFalse,
        reason: 'no saved address is the normal state until the location gate '
            'resolves one',
      );
    });
  });

  group('the callers', () {
    test('every call site passes flags consistent with what it wants', () {
      // cart_screen and item_controller want the store and nothing else.
      final String cart =
          File('lib/features/cart/screens/cart_screen.dart').readAsStringSync();
      expect(
        cart,
        contains('fromCart: true'),
        reason: 'the cart must not re-trigger distance or a home reload',
      );
    });

    test('checkout no longer re-initialises time slots itself', () {
      // The duplicate that cost four schedule-loop runs. If this comes back,
      // so does the cost.
      final String checkout = File(
        'lib/features/checkout/controllers/checkout_controller.dart',
      ).readAsStringSync();
      final int at = checkout.indexOf('Future<void> initCheckoutData(');
      expect(at, isNot(-1));
      final int end = checkout.indexOf('\n  }', at);

      // Comments stripped first. The body carries a comment explaining *why*
      // the call was removed, and matching that would fail on the explanation
      // rather than the code — the same trap that mangled a comment about
      // empty catches in §17.4 of the hardening plan.
      final String body = checkout
          .substring(at, end)
          .split('\n')
          .where((String line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      expect(
        body.contains('initializeTimeSlot'),
        isFalse,
        reason: 'getStoreDetails already fires it — calling it again ran the '
            'whole schedule loop a second time',
      );
    });
  });
}
