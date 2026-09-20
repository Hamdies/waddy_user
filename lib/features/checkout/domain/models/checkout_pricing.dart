import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/checkout/helpers/checkout_calculation_helper.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// Every number the checkout screen prices an order with, computed once.
///
/// `CS-01`: these fourteen figures were computed by fourteen chained calls
/// inside `build()`, each feeding the next, with their intermediate results
/// written back onto `State` fields. The order total was a side effect of
/// painting a frame — which is why the tax fetch had to live in `build()` too
/// (`CC-09`), why the order payload had to be rebuilt from scratch in the
/// place-order handler (`CS-02`), and why a rebuild from any of nine
/// controllers could silently change what the screen believed.
///
/// This is the same move `SpotsRound` made for the Spots round seam: one
/// derived object, one owner, computed from its inputs rather than from the
/// order its callers happen to run in.
///
/// Immutable on purpose. `build()` formats these; it does not produce them.
class CheckoutPricing {
  /// Gross item price — unit price times quantity, before any discount.
  final double price;

  /// Add-on total across the cart.
  final double addOns;

  /// Variation total, computed without discount.
  final double variations;

  /// Discount attributable to the item itself.
  final double itemDiscount;

  /// Discount attributable to the store.
  final double storeDiscount;

  /// The larger of the two discounts above, used for display.
  final double extraDiscount;

  /// The discount actually applied.
  final double discount;

  /// Coupon discount, as resolved by `CouponController`.
  final double couponDiscount;

  /// What the customer is buying, before delivery, tax and extras.
  ///
  /// This is the figure `order_amount` carries on **both** the tax quote and
  /// the order — see `CS-02`.
  final double subTotal;

  /// First-order referral bonus, subtracted from the total.
  final double referralDiscount;

  /// The figure the delivery-charge tiers are evaluated against.
  final double orderAmount;

  /// Delivery charge before free-delivery and surge rules are applied.
  final double originalDeliveryCharge;

  /// Delivery charge as actually billed.
  final double deliveryCharge;

  /// Platform-wide additional charge, when enabled.
  final double additionalCharge;

  /// Extra packaging charge, when the cart opted in.
  final double extraPackagingCharge;

  /// The amount due, referral bonus already deducted.
  final double total;

  /// Surge portion of the delivery charge, for the tooltip.
  ///
  /// `CS-09`: this and [extraChargeForToolTip] were left on the helper as
  /// mutable fields and read back out *after* `calculateDeliveryCharge`
  /// returned — an out-parameter that worked only because the calls happened
  /// in a fixed order in one method. They are return values now.
  final double badWeatherChargeForToolTip;

  /// Distance-based extra charge, for the tooltip.
  final double extraChargeForToolTip;

  /// Whether the variation price path ran, which the summary rows key off.
  final bool isPassedVariationPrice;

  const CheckoutPricing({
    required this.price,
    required this.addOns,
    required this.variations,
    required this.itemDiscount,
    required this.storeDiscount,
    required this.extraDiscount,
    required this.discount,
    required this.couponDiscount,
    required this.subTotal,
    required this.referralDiscount,
    required this.orderAmount,
    required this.originalDeliveryCharge,
    required this.deliveryCharge,
    required this.additionalCharge,
    required this.extraPackagingCharge,
    required this.total,
    required this.badWeatherChargeForToolTip,
    required this.extraChargeForToolTip,
    required this.isPassedVariationPrice,
  });

  /// Runs the fourteen calculations in dependency order, once.
  ///
  /// The body is the chain exactly as `build()` ran it, so this is a move and
  /// not a re-derivation. The one deliberate difference is that the two
  /// tooltip figures are read off the helper immediately after the call that
  /// sets them and returned as fields, rather than left for a caller to
  /// collect later.
  factory CheckoutPricing.calculate({
    required CheckoutCalculationHelper helper,
    required Store? store,
    required List<CartModel?>? cartList,
    required AddressModel address,
    required double? distance,
    required double? extraCharge,
    required String orderType,
    required double couponDiscount,
    required double tips,
    required double additionalCharge,
    required double extraPackagingCharge,
    required bool taxIncluded,
    required double tax,
    required double? surgePrice,
    required String? surgePriceType,
  }) {
    final double price = helper.calculatePrice(
      store: store,
      cartList: cartList,
    );
    final double addOns = helper.calculateAddonsPrice(
      store: store,
      cartList: cartList,
    );
    final double variations = helper.calculateVariationPrice(
      store: store,
      cartList: cartList,
      calculateWithoutDiscount: true,
    );
    final double itemDiscount = helper.calculateDiscountPrice(
      store: store,
      cartList: cartList,
      price: price,
      addOns: addOns,
      calStoreDiscount: false,
    );
    final double storeDiscount = helper.calculateDiscountPrice(
      store: store,
      cartList: cartList,
      price: price,
      addOns: addOns,
      calStoreDiscount: true,
    );
    final double extraDiscount = helper.getExtraDiscountPrice(
      storeDiscount,
      itemDiscount,
    );
    final double discount = helper.getDiscountPrice(
      storeDiscount,
      itemDiscount,
    );
    final double subTotal = helper.calculateSubTotal(
      price: price,
      addOns: addOns,
      variations: variations,
      cartList: cartList,
    );
    final double referralDiscount = helper.calculateReferralDiscount(
      subTotal,
      discount,
      couponDiscount,
    );
    final double orderAmount = helper.calculateOrderAmount(
      price: price,
      variations: variations,
      discount: discount,
      addOns: addOns,
      couponDiscount: couponDiscount,
      cartList: cartList,
      referralDiscount: referralDiscount,
    );
    final double originalDeliveryCharge = helper
        .calculateOriginalDeliveryCharge(
          store: store,
          address: address,
          distance: distance,
          extraCharge: extraCharge,
          surgePrice: surgePrice,
          surgePriceType: surgePriceType,
        );
    final double deliveryCharge = helper.calculateDeliveryCharge(
      store: store,
      address: address,
      distance: distance,
      extraCharge: extraCharge,
      orderType: orderType,
      orderAmount: orderAmount,
      surgePrice: surgePrice,
      surgePriceType: surgePriceType,
    );

    // Read immediately, while the call that set them is the one just made.
    final double badWeather = helper.badWeatherChargeForToolTip;
    final double extraTooltip = helper.extraChargeForToolTip;
    final bool passedVariation = helper.isPassedVariationPrice;

    final double total =
        helper.calculateTotal(
          subTotal: subTotal,
          deliveryCharge: deliveryCharge,
          discount: discount,
          couponDiscount: couponDiscount,
          taxIncluded: taxIncluded,
          tax: tax,
          orderType: orderType,
          tips: tips,
          additionalCharge: additionalCharge,
          extraPackagingCharge: extraPackagingCharge,
        ) -
        referralDiscount;

    return CheckoutPricing(
      price: price,
      addOns: addOns,
      variations: variations,
      itemDiscount: itemDiscount,
      storeDiscount: storeDiscount,
      extraDiscount: extraDiscount,
      discount: discount,
      couponDiscount: couponDiscount,
      subTotal: subTotal,
      referralDiscount: referralDiscount,
      orderAmount: orderAmount,
      originalDeliveryCharge: originalDeliveryCharge,
      deliveryCharge: deliveryCharge,
      additionalCharge: additionalCharge,
      extraPackagingCharge: extraPackagingCharge,
      total: total,
      badWeatherChargeForToolTip: badWeather,
      extraChargeForToolTip: extraTooltip,
      isPassedVariationPrice: passedVariation,
    );
  }
}
