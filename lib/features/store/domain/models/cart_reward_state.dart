import 'package:get/get.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// What the reward strip is currently saying.
enum CartRewardKind {
  /// Nothing worth showing — the strip is not rendered at all.
  hidden,

  /// Store minimum not met. A BLOCKER: the user cannot check out yet, so this
  /// outranks any delivery reward.
  minimumOrder,

  /// Store minimum just cleared. Only surfaced where clearing it is the news —
  /// see [showMinimumMet]. Everywhere else the ladder falls through to whatever
  /// reward applies, because "you may now check out" is not worth a strip on a
  /// browsing screen.
  minimumOrderMet,

  /// Free delivery already guaranteed, unconditionally. No progress to show.
  freeDeliveryGuaranteed,

  /// Free delivery available over a threshold, not yet reached.
  freeDeliveryProgress,

  /// Threshold just cleared. The one state that celebrates.
  freeDeliveryUnlocked,

  /// Empty cart, reward waiting — the acquisition hook.
  hookFirstOrder,
  hookFreeDelivery,
}

/// Resolved state of the reward strip.
///
/// ## Why this is a separate, pure class
///
/// `CheckoutCalculationHelper.calculateDeliveryCharge` resolves SIX independent
/// paths to a zero delivery charge (takeaway, store-always-free, admin-to-all,
/// admin-over-threshold, coupon, XP prize). If the strip re-derived any of that
/// inline it would drift from checkout, and the bar would promise free delivery
/// the server then declines — the worst possible bug for this feature.
///
/// So the ladder lives here, once, as a pure function of its inputs. No widget
/// builds, no side effects, trivially testable.
///
/// Two of the six are deliberately NOT represented:
/// coupon and XP-prize free delivery only resolve AFTER the user acts on the
/// checkout screen. There is no pre-checkout signal for either, and inventing
/// one would mean promising a discount that may not materialise.
///
/// See docs/food_store_add_feedback_plan.md §3 and §9.
class CartRewardState {
  final CartRewardKind kind;

  /// Remaining amount to reach the target, when [kind] is progress-shaped.
  final double remaining;

  /// 0..1 progress toward the target. Only meaningful for progress states.
  final double progress;

  /// Raw first-order discount amount, and whether it is a percentage.
  ///
  /// Deliberately NOT pre-formatted: `PriceConverter.convertPrice` reaches into
  /// `SplashController` for the currency symbol, and calling it here would make
  /// this class depend on a live GetX container — which is exactly what keeping
  /// the ladder pure and testable was meant to avoid. The widget formats it.
  final double? discountAmount;
  final bool discountIsPercent;

  const CartRewardState({
    required this.kind,
    this.remaining = 0,
    this.progress = 0,
    this.discountAmount,
    this.discountIsPercent = false,
  });

  static const CartRewardState _hidden = CartRewardState(
    kind: CartRewardKind.hidden,
  );

  bool get isVisible => kind != CartRewardKind.hidden;

  bool get hasProgress =>
      kind == CartRewardKind.minimumOrder ||
      kind == CartRewardKind.minimumOrderMet ||
      kind == CartRewardKind.freeDeliveryProgress;

  /// Only the unlock moment is worth a looping animation.
  bool get celebrates => kind == CartRewardKind.freeDeliveryUnlocked;

  /// The empty-cart states, which advertise rather than report.
  ///
  /// Every other state describes a cart that exists and renders a tappable
  /// pill beneath the message. These two render a message ALONE — there is no
  /// cart to view — which makes them the only states where the bar holds
  /// screen space without offering an action. That is what earns them a
  /// timeout in the UI; see `PillCartBar`.
  bool get isAcquisitionHook =>
      kind == CartRewardKind.hookFirstOrder ||
      kind == CartRewardKind.hookFreeDelivery;

  /// Resolve the strip's state.
  ///
  /// [subTotal] is the cart subtotal, [cartIsEmpty] distinguishes the hook
  /// states from the in-cart states. Config, user and store are read from the
  /// arguments rather than looked up here so this stays pure and testable;
  /// [resolveFromContext] does the lookups.
  /// [showMinimumMet] makes clearing the store minimum its own visible state.
  ///
  /// False on browsing surfaces: once you can check out, "you can check out" is
  /// not news, and a strip that says so is the kind of noise this whole
  /// component exists to avoid. True on the CART, where the minimum is the gate
  /// standing between the user and the button they came to press — there,
  /// silently removing the progress strip would read as the app forgetting.
  static CartRewardState resolve({
    required Store? store,
    required double subTotal,
    required bool cartIsEmpty,
    required AdminFreeDelivery? adminFreeDelivery,
    required bool userValidForFirstOrderDiscount,
    required double? firstOrderDiscountAmount,
    required String? firstOrderDiscountType,
    bool showMinimumMet = false,
  }) {
    if (store == null) return _hidden;

    // ── Rule 0: takeaway-only store. Nothing is being delivered, so every
    // delivery promise below would read as broken.
    if (store.delivery == false) return _hidden;

    final bool adminOn = adminFreeDelivery?.status == true;
    final String? adminType = adminFreeDelivery?.type;

    final bool unconditionalFreeDelivery =
        (store.freeDelivery == true) ||
        (adminOn && adminType == 'free_delivery_to_all_store');

    // ── Rules 5a / 5b: empty cart. The hook — a reason to START a cart.
    if (cartIsEmpty) {
      if (unconditionalFreeDelivery) {
        return const CartRewardState(kind: CartRewardKind.hookFreeDelivery);
      }
      // The first-order perk is a DISCOUNT, not free delivery (it comes from
      // Helpers::getCusromerFirstOrderDiscount and is gated on a referral).
      // Saying "free delivery" here would be factually wrong.
      if (userValidForFirstOrderDiscount &&
          (firstOrderDiscountAmount ?? 0) > 0) {
        return CartRewardState(
          kind: CartRewardKind.hookFirstOrder,
          discountAmount: firstOrderDiscountAmount,
          discountIsPercent: firstOrderDiscountType == 'percent',
        );
      }
      return _hidden;
    }

    // ── Rule 1: store minimum unmet. A blocker outranks any reward — free
    // delivery is irrelevant if you cannot check out at all.
    final double minimum = store.minimumOrder ?? 0;
    if (minimum > 0 && subTotal < minimum) {
      return CartRewardState(
        kind: CartRewardKind.minimumOrder,
        remaining: minimum - subTotal,
        progress: (subTotal / minimum).clamp(0.0, 1.0),
      );
    }

    // ── Rule 2: already free, unconditionally. No progress to show.
    if (unconditionalFreeDelivery) {
      return const CartRewardState(kind: CartRewardKind.freeDeliveryGuaranteed);
    }

    // ── Rules 3 / 4: the threshold. Note this branches on `type`, not just
    // `status` — 'free_delivery_to_all_store' is handled above and must NOT
    // fall through to a progress bar.
    if (adminOn && adminType == 'free_delivery_by_order_amount') {
      final double over = adminFreeDelivery?.freeDeliveryOver ?? 0;
      if (over > 0) {
        if (subTotal >= over) {
          return const CartRewardState(
            kind: CartRewardKind.freeDeliveryUnlocked,
          );
        }
        return CartRewardState(
          kind: CartRewardKind.freeDeliveryProgress,
          remaining: over - subTotal,
          progress: (subTotal / over).clamp(0.0, 1.0),
        );
      }
    }

    // ── Minimum cleared, and nothing better to say. Deliberately LAST: a real
    // reward (free delivery, threshold progress) is worth more to the user than
    // "you can check out now", so this only surfaces when the ladder would
    // otherwise fall through to hidden.
    if (showMinimumMet && minimum > 0 && !cartIsEmpty) {
      return const CartRewardState(
        kind: CartRewardKind.minimumOrderMet,
        progress: 1.0,
      );
    }

    // ── Rule 6: nothing to say. A strip with no message is noise.
    return _hidden;
  }

  /// Store-agnostic resolve, for surfaces that are not inside one store —
  /// the food/grocery home screen, where the cart may span a store whose
  /// `minimumOrder` and `freeDelivery` flags are not in memory.
  ///
  /// Only the ADMIN-WIDE rules are evaluated here (threshold progress,
  /// free-to-all) plus the first-order hook. Store-specific rules are
  /// deliberately skipped rather than guessed: `CartModel` carries only a
  /// `storeId`, and inventing a minimum we cannot verify would show the user a
  /// progress bar toward the wrong number.
  static CartRewardState resolveGlobal({
    required double subTotal,
    required bool cartIsEmpty,
    required AdminFreeDelivery? adminFreeDelivery,
    required bool userValidForFirstOrderDiscount,
    required double? firstOrderDiscountAmount,
    required String? firstOrderDiscountType,
  }) {
    return resolve(
      // A synthetic store with no minimum and no always-free flag, so the
      // ladder falls through to the admin rules and the hook.
      store: Store(id: -1, delivery: true, freeDelivery: false),
      subTotal: subTotal,
      cartIsEmpty: cartIsEmpty,
      adminFreeDelivery: adminFreeDelivery,
      userValidForFirstOrderDiscount: userValidForFirstOrderDiscount,
      firstOrderDiscountAmount: firstOrderDiscountAmount,
      firstOrderDiscountType: firstOrderDiscountType,
    );
  }

  /// Convenience wrapper that pulls config and user state from GetX.
  ///
  /// Kept separate from [resolve] so the ladder itself has no dependencies and
  /// can be unit-tested without a GetX container.
  static CartRewardState resolveFromContext({
    required Store? store,
    required double subTotal,
    required bool cartIsEmpty,
    bool globalOnly = false,
    bool showMinimumMet = false,
  }) {
    AdminFreeDelivery? admin;
    try {
      admin = Get.find<SplashController>().configModelOrNull?.adminFreeDelivery;
    } catch (_) {
      admin = null;
    }

    bool valid = false;
    double? amount;
    String? type;
    try {
      final info = Get.find<ProfileController>().userInfoModel;
      valid = info?.isValidForDiscount ?? false;
      amount = info?.discountAmount;
      type = info?.discountAmountType;
    } catch (_) {
      // Guest, or profile not loaded yet. No hook, no crash.
    }

    if (globalOnly) {
      return resolveGlobal(
        subTotal: subTotal,
        cartIsEmpty: cartIsEmpty,
        adminFreeDelivery: admin,
        userValidForFirstOrderDiscount: valid,
        firstOrderDiscountAmount: amount,
        firstOrderDiscountType: type,
      );
    }

    return resolve(
      store: store,
      subTotal: subTotal,
      cartIsEmpty: cartIsEmpty,
      adminFreeDelivery: admin,
      userValidForFirstOrderDiscount: valid,
      firstOrderDiscountAmount: amount,
      firstOrderDiscountType: type,
      showMinimumMet: showMinimumMet,
    );
  }
}
