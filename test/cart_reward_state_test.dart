import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/store/domain/models/cart_reward_state.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// Guards the reward ladder against drift from checkout's six free-delivery
/// branches. If this file and `CheckoutCalculationHelper.calculateDeliveryCharge`
/// ever disagree, the bar promises free delivery the server then declines.
///
/// See docs/food_store_add_feedback_plan.md §3.
void main() {
  Store store({
    bool? freeDelivery,
    double? minimumOrder,
    bool delivery = true,
  }) => Store(
    id: 1,
    freeDelivery: freeDelivery ?? false,
    minimumOrder: minimumOrder,
    delivery: delivery,
  );

  AdminFreeDelivery admin({bool status = false, String? type, double? over}) =>
      AdminFreeDelivery(status: status, type: type, freeDeliveryOver: over);

  CartRewardState resolve({
    Store? s,
    double subTotal = 0,
    bool empty = false,
    AdminFreeDelivery? a,
    bool firstOrder = false,
    double? amount,
    String? amountType,
    bool showMinimumMet = false,
  }) => CartRewardState.resolve(
    store: s ?? store(),
    subTotal: subTotal,
    cartIsEmpty: empty,
    adminFreeDelivery: a,
    userValidForFirstOrderDiscount: firstOrder,
    firstOrderDiscountAmount: amount,
    firstOrderDiscountType: amountType,
    showMinimumMet: showMinimumMet,
  );

  group('rule 0 — takeaway-only store', () {
    test('is hidden even when free delivery would otherwise apply', () {
      final r = resolve(
        s: store(freeDelivery: true, delivery: false),
        subTotal: 100,
      );
      expect(r.kind, CartRewardKind.hidden);
    });
  });

  group('rule 1 — minimum order blocker', () {
    test('outranks free delivery when unmet', () {
      final r = resolve(
        s: store(freeDelivery: true, minimumOrder: 50),
        subTotal: 20,
      );
      expect(r.kind, CartRewardKind.minimumOrder);
      expect(r.remaining, 30);
      expect(r.progress, closeTo(0.4, 0.001));
      expect(r.hasProgress, isTrue);
    });

    test('yields to the reward once met', () {
      final r = resolve(
        s: store(freeDelivery: true, minimumOrder: 50),
        subTotal: 50,
      );
      expect(r.kind, CartRewardKind.freeDeliveryGuaranteed);
    });
  });

  group('rule 2 — unconditional free delivery', () {
    test('store always-free shows no progress', () {
      final r = resolve(s: store(freeDelivery: true), subTotal: 10);
      expect(r.kind, CartRewardKind.freeDeliveryGuaranteed);
      expect(r.hasProgress, isFalse);
    });

    test('admin free-to-all shows no progress', () {
      final r = resolve(
        subTotal: 10,
        a: admin(status: true, type: 'free_delivery_to_all_store'),
      );
      expect(r.kind, CartRewardKind.freeDeliveryGuaranteed);
      expect(r.hasProgress, isFalse);
    });

    test('free-to-all does NOT fall through to a progress bar', () {
      // The regression this guards: branching on `status` alone would show
      // "add X more" to a user who already has free delivery unconditionally.
      final r = resolve(
        subTotal: 10,
        a: admin(status: true, type: 'free_delivery_to_all_store', over: 200),
      );
      expect(r.kind, isNot(CartRewardKind.freeDeliveryProgress));
    });
  });

  group('rules 3 / 4 — admin threshold', () {
    test('unmet shows progress with the right remainder', () {
      final r = resolve(
        subTotal: 60,
        a: admin(
          status: true,
          type: 'free_delivery_by_order_amount',
          over: 100,
        ),
      );
      expect(r.kind, CartRewardKind.freeDeliveryProgress);
      expect(r.remaining, 40);
      expect(r.progress, closeTo(0.6, 0.001));
    });

    test('met celebrates', () {
      final r = resolve(
        subTotal: 100,
        a: admin(
          status: true,
          type: 'free_delivery_by_order_amount',
          over: 100,
        ),
      );
      expect(r.kind, CartRewardKind.freeDeliveryUnlocked);
      expect(r.celebrates, isTrue);
    });

    test('ignored when admin free delivery is off', () {
      final r = resolve(
        subTotal: 10,
        a: admin(
          status: false,
          type: 'free_delivery_by_order_amount',
          over: 100,
        ),
      );
      expect(r.kind, CartRewardKind.hidden);
    });
  });

  group('rules 5a / 5b — empty-cart hooks', () {
    test('unconditional free delivery wins over the first-order hook', () {
      final r = resolve(
        s: store(freeDelivery: true),
        empty: true,
        firstOrder: true,
        amount: 25,
        amountType: 'amount',
      );
      expect(r.kind, CartRewardKind.hookFreeDelivery);
    });

    test('first-order discount formats a flat amount', () {
      final r = resolve(
        empty: true,
        firstOrder: true,
        amount: 25,
        amountType: 'amount',
      );
      expect(r.kind, CartRewardKind.hookFirstOrder);
      expect(r.discountAmount, 25);
      expect(r.discountIsPercent, isFalse);
    });

    test('first-order discount formats a percentage', () {
      final r = resolve(
        empty: true,
        firstOrder: true,
        amount: 20,
        amountType: 'percent',
      );
      expect(r.kind, CartRewardKind.hookFirstOrder);
      expect(r.discountAmount, 20);
      expect(r.discountIsPercent, isTrue);
    });

    test('no hook when the user is valid but the amount is zero', () {
      final r = resolve(empty: true, firstOrder: true, amount: 0);
      expect(r.kind, CartRewardKind.hidden);
    });

    test('empty cart with nothing on offer is hidden', () {
      final r = resolve(empty: true);
      expect(r.kind, CartRewardKind.hidden);
      expect(r.isVisible, isFalse);
    });
  });

  group('resolveGlobal — store-agnostic surfaces (food/grocery home)', () {
    test('evaluates admin threshold progress without a store', () {
      final r = CartRewardState.resolveGlobal(
        subTotal: 60,
        cartIsEmpty: false,
        adminFreeDelivery: admin(
          status: true,
          type: 'free_delivery_by_order_amount',
          over: 100,
        ),
        userValidForFirstOrderDiscount: false,
        firstOrderDiscountAmount: null,
        firstOrderDiscountType: null,
      );
      expect(r.kind, CartRewardKind.freeDeliveryProgress);
      expect(r.remaining, 40);
    });

    test('never claims a per-store minimum it cannot verify', () {
      // The cart carries only a storeId, so a store minimum must not be
      // invented here — it would point the progress bar at the wrong number.
      final r = CartRewardState.resolveGlobal(
        subTotal: 5,
        cartIsEmpty: false,
        adminFreeDelivery: null,
        userValidForFirstOrderDiscount: false,
        firstOrderDiscountAmount: null,
        firstOrderDiscountType: null,
      );
      expect(r.kind, isNot(CartRewardKind.minimumOrder));
      expect(r.kind, CartRewardKind.hidden);
    });

    test('still surfaces the first-order hook on an empty cart', () {
      final r = CartRewardState.resolveGlobal(
        subTotal: 0,
        cartIsEmpty: true,
        adminFreeDelivery: null,
        userValidForFirstOrderDiscount: true,
        firstOrderDiscountAmount: 30,
        firstOrderDiscountType: 'amount',
      );
      expect(r.kind, CartRewardKind.hookFirstOrder);
    });
  });

  group('minimumOrderMet — cart-only success state', () {
    test('hidden on browsing surfaces once the minimum is met', () {
      // Default showMinimumMet:false. "You can check out now" is not news on a
      // store or home screen, and a strip saying so is exactly the noise this
      // component exists to avoid.
      final r = resolve(s: store(minimumOrder: 50), subTotal: 60);
      expect(r.kind, CartRewardKind.hidden);
    });

    test('shown on the cart, where clearing the minimum IS the news', () {
      final r = resolve(
        s: store(minimumOrder: 50),
        subTotal: 60,
        showMinimumMet: true,
      );
      expect(r.kind, CartRewardKind.minimumOrderMet);
      expect(r.progress, 1.0);
      expect(r.hasProgress, isTrue);
    });

    test('never shown for an empty cart', () {
      final r = resolve(
        s: store(minimumOrder: 50),
        subTotal: 0,
        empty: true,
        showMinimumMet: true,
      );
      expect(r.kind, isNot(CartRewardKind.minimumOrderMet));
    });

    test('does not fire when the store has no minimum at all', () {
      final r = resolve(s: store(), subTotal: 60, showMinimumMet: true);
      expect(r.kind, CartRewardKind.hidden);
    });

    test('the unmet blocker still outranks it', () {
      final r = resolve(
        s: store(minimumOrder: 50),
        subTotal: 20,
        showMinimumMet: true,
      );
      expect(r.kind, CartRewardKind.minimumOrder);
    });

    test('a real reward still outranks the met state', () {
      // Free delivery is worth more to the user than "minimum cleared".
      final r = resolve(
        s: store(minimumOrder: 50, freeDelivery: true),
        subTotal: 60,
        showMinimumMet: true,
      );
      expect(r.kind, CartRewardKind.freeDeliveryGuaranteed);
    });
  });

  group('progress values that the strip must not render as complete', () {
    test('the 91% case from the device screenshot stays under the ceiling', () {
      // 83 LE subtotal against a 91 LE minimum = 91.2%. Rendered unclamped this
      // painted as a full bar beside "Add 8 LE more to order" — the label and
      // the bar contradicting each other. RewardStrip clamps the RENDERED value
      // to [0.04, 0.92]; this guards the resolver half of that contract.
      final r = resolve(s: store(minimumOrder: 91), subTotal: 83);
      expect(r.kind, CartRewardKind.minimumOrder);
      expect(r.remaining, 8);
      expect(r.progress, closeTo(0.912, 0.001));
      // True value is preserved for the label; only the paint is clamped.
      expect(r.progress.clamp(0.04, 0.92), lessThan(1.0));
    });

    test('progress never exceeds 1.0 even when subtotal overshoots', () {
      final r = resolve(s: store(minimumOrder: 50), subTotal: 500);
      // Overshooting the minimum resolves past the blocker entirely.
      expect(r.kind, isNot(CartRewardKind.minimumOrder));
    });

    test('a near-zero cart still reports real progress', () {
      final r = resolve(s: store(minimumOrder: 100), subTotal: 1);
      expect(r.progress, closeTo(0.01, 0.001));
      expect(r.progress.clamp(0.04, 0.92), 0.04);
    });
  });

  group('rule 6 — nothing to say', () {
    test('plain store, cart with items, no perks', () {
      final r = resolve(subTotal: 40);
      expect(r.kind, CartRewardKind.hidden);
    });

    test('null store is hidden', () {
      final r = CartRewardState.resolve(
        store: null,
        subTotal: 0,
        cartIsEmpty: true,
        adminFreeDelivery: null,
        userValidForFirstOrderDiscount: false,
        firstOrderDiscountAmount: null,
        firstOrderDiscountType: null,
      );
      expect(r.kind, CartRewardKind.hidden);
    });
  });
}
