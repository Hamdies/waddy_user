import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_tool_tip_widget.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:waddy_app/features/checkout/widgets/payment_section.dart';
import 'package:waddy_app/features/checkout/widgets/prescription_image_picker_widget.dart';
import 'package:waddy_app/features/checkout/widgets/prize_selection_widget.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// The lower half of checkout: XP prize, "Pay with", and the payment
/// summary. Each block is a direct child of the page's column so the spacing
/// between them is the page's, not nested paddings'.
class BottomSection extends StatelessWidget {
  final CheckoutController checkoutController;
  final double total;
  final Module module;
  final double subTotal;
  final double discount;

  /// The item-level part of [discount] — what the cart's lines already show
  /// net. [discount] is the larger of this and a store-wide discount.
  final double itemDiscount;
  final CouponController couponController;
  final bool taxIncluded;
  final double tax;
  final double deliveryCharge;
  final double orderAmount;
  final int? storeId;
  final bool isPrescriptionRequired;
  final double referralDiscount;
  final bool isCashOnDeliveryActive;
  final bool isDigitalPaymentActive;
  final bool isWalletActive;
  final bool isOfflinePaymentActive;

  /// Extra vehicle charge folded into the delivery fee, explained by a
  /// tooltip on that row. Zero when there is none.
  final double extraChargeForToolTip;

  /// Anchors "Pay with" so the bottom bar can scroll the list into view.
  final GlobalKey payWithKey;

  /// Changes each time the bottom bar sends the user here; the card pulses.
  final ValueListenable<int> payAttention;

  const BottomSection({
    super.key,
    required this.checkoutController,
    required this.total,
    required this.module,
    required this.subTotal,
    required this.discount,
    required this.itemDiscount,
    required this.couponController,
    required this.taxIncluded,
    required this.tax,
    required this.deliveryCharge,
    required this.orderAmount,
    this.storeId,
    required this.isPrescriptionRequired,
    required this.referralDiscount,
    required this.isCashOnDeliveryActive,
    required this.isDigitalPaymentActive,
    required this.isWalletActive,
    required this.isOfflinePaymentActive,
    required this.extraChargeForToolTip,
    required this.payWithKey,
    required this.payAttention,
  });

  @override
  Widget build(BuildContext context) {
    bool takeAway = checkoutController.orderType == 'take_away';
    bool isGuestLoggedIn = false;
    const gap = SizedBox(height: Dimensions.paddingSizeDefault);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /// XP Prize Selection (for logged in users, delivery orders only)
        if (!isGuestLoggedIn && !takeAway && storeId == null) ...[
          CheckoutPrizeSection(orderAmount: orderAmount),
        ],

        const SizedBox(height: Dimensions.paddingSizeExtraLarge),
        CheckoutSectionTitle('pay_with'.tr, key: payWithKey),
        const SizedBox(height: Dimensions.paddingSizeMedium),
        _AttentionPulse(
          trigger: payAttention,
          child: PaymentSection(
            storeId: storeId,
            isCashOnDeliveryActive: isCashOnDeliveryActive,
            isDigitalPaymentActive: isDigitalPaymentActive,
            isWalletActive: isWalletActive,
            total: total,
            checkoutController: checkoutController,
            isOfflinePaymentActive: isOfflinePaymentActive,
          ),
        ),

        const SizedBox(height: Dimensions.paddingSizeExtremeLarge),
        CheckoutSectionTitle('payment_summary'.tr),
        const SizedBox(height: Dimensions.paddingSizeMedium),
        _paymentSummary(context, takeAway: takeAway),

        PrescriptionImagePickerWidget(
          checkoutController: checkoutController,
          storeId: storeId,
          isPrescriptionRequired: isPrescriptionRequired,
        ),
      ],
    );
  }

  /// Plain rows on the page, no card: the summary is read, not interacted
  /// with. Zero-value lines are omitted — "Discount (-) EGP 0.00" is noise.
  Widget _paymentSummary(BuildContext context, {required bool takeAway}) {
    final config = Get.find<SplashController>().configModel;
    final bool couponFreeDelivery =
        couponController.coupon != null &&
        couponController.coupon!.couponType == 'free_delivery';
    final bool showTax =
        !(checkoutController.taxIncluded == null ||
            taxIncluded ||
            checkoutController.orderTax == 0);
    final bool showPackaging =
        storeId == null &&
        checkoutController.store!.extraPackagingStatus! &&
        Get.find<CartController>().needExtraPackage;

    final Widget deliveryValue;
    if (checkoutController.distance == -1) {
      deliveryValue = _value('calculating'.tr, color: WaddyColors.error);
    } else if (deliveryCharge == 0 || couponFreeDelivery) {
      deliveryValue = _saving('free'.tr);
    } else {
      deliveryValue = _value(PriceConverter.convertPrice(deliveryCharge));
    }

    final String? promoCode = couponController.coupon?.code;

    // Everything that came off this order, shown once under "To pay" as a
    // settled fact rather than as minus lines to reconcile.
    final double couponOff =
        couponFreeDelivery ? 0 : (couponController.discount ?? 0);
    final double saved =
        (storeId == null ? discount : 0) + couponOff + referralDiscount;

    // The design's order: what you bought, what it costs to get it to you,
    // what came off, then the tip — each line reads as a step toward "To pay".
    //
    // Items are shown NET of item discounts, the same figure the cart's lines
    // and Checkout button show. A gross subtotal with a "−discount" line
    // reconciled mathematically, but read as the price changing between
    // screens. A store-wide discount beyond the item discounts is not on the
    // cart's lines, so it keeps a line of its own.
    final double storeExtra = math.max(0, discount - itemDiscount);
    final List<Widget> rows = [
      if (storeId == null)
        _row(
          module.addOn! ? 'subtotal'.tr : 'item_price'.tr,
          _value(PriceConverter.convertPrice(subTotal - itemDiscount)),
        ),
      if (storeId == null && storeExtra > 0)
        _row(
          'discount'.tr,
          _saving('−${PriceConverter.convertPrice(storeExtra)}'),
        ),
      if (!takeAway)
        _row(
          'delivery_fee'.tr,
          deliveryValue,
          info:
              (checkoutController.orderType == 'delivery') &&
                      (checkoutController.store?.selfDeliverySystem == 0) &&
                      (checkoutController.surgePrice?.customerNoteStatus == 1)
                  ? CustomToolTip(
                    message:
                        '${'this_delivery_fee_includes_all_the_applicable_charges_on_delivery'.tr} ${checkoutController.surgePrice?.customerNote ?? ''}',
                    child: const _InfoGlyph(),
                  )
                  // Moved here from the old delivery-type card, which was
                  // the only place the vehicle surcharge was explained.
                  : (checkoutController.extraCharge != null &&
                      extraChargeForToolTip > 0 &&
                      deliveryCharge > 0)
                  ? CustomToolTip(
                    message:
                        '${'this_charge_include_extra_vehicle_charge'.tr} ${PriceConverter.convertPrice(extraChargeForToolTip)}',
                    child: const _InfoGlyph(),
                  )
                  : null,
        ),
      if (config.additionalChargeStatus!)
        _row(
          config.additionalChargeName!,
          _value(PriceConverter.convertPrice(config.additionCharge)),
        ),
      if (showTax) _row('vat_tax'.tr, _value(PriceConverter.convertPrice(tax))),
      if (showPackaging)
        _row(
          'extra_packaging'.tr,
          _value(
            PriceConverter.convertPrice(
              checkoutController.store!.extraPackagingAmount!,
            ),
          ),
        ),
      if (couponController.discount! > 0 || couponController.freeDelivery)
        _row(
          promoCode != null && promoCode.isNotEmpty
              ? 'promo_with_code'.trParams({'code': promoCode.toUpperCase()})
              : 'coupon_discount'.tr,
          couponFreeDelivery
              ? _saving('free_delivery'.tr)
              : _saving(
                '−${PriceConverter.convertPrice(couponController.discount)}',
              ),
        ),
      if (referralDiscount > 0)
        _row(
          'referral_discount'.tr,
          _saving('−${PriceConverter.convertPrice(referralDiscount)}'),
        ),
      if (checkoutController.isPartialPay)
        _row(
          'balance_used'.tr,
          _value(
            '−${PriceConverter.convertPrice(Get.find<ProfileController>().userInfoModel!.walletBalance!)}',
          ),
        ),
      if (!takeAway && config.dmTipsStatus == 1)
        _row(
          'rider_tip'.tr,
          _value(PriceConverter.convertPrice(checkoutController.tips)),
        ),
    ];

    final TextStyle totalStyle = waddyBold.copyWith(
      fontSize: Dimensions.fontSizeDefault,
      color: WaddyColors.ink,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: WaddyColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Receipt-style: dashed rules between lines.
          for (final row in rows) ...[row, const _DashedRule()],
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: Dimensions.paddingSizeDefault,
            ),
            child: Row(
              children: [
                Expanded(child: Text('to_pay'.tr, style: totalStyle)),
                // convertPrice, not convertAnimationPrice: the animated
                // variant drops the space before the currency ("388LE").
                Text(
                  PriceConverter.convertPrice(
                    checkoutController.isPartialPay
                        ? checkoutController.viewTotalPrice
                        : total,
                  ),
                  textDirection: TextDirection.ltr,
                  style: totalStyle,
                ),
              ],
            ),
          ),
          if (saved > 0)
            Padding(
              padding: const EdgeInsets.only(
                bottom: Dimensions.paddingSizeDefault,
              ),
              child: Row(
                children: [
                  // "Waddy!" is the Egyptian-slang pun (واضي), on purpose.
                  Expanded(
                    child: Text(
                      'youre_saving'.tr,
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall,
                        color: WaddyColors.mintInk,
                      ),
                    ),
                  ),
                  _saving(PriceConverter.convertPrice(saved)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, Widget value, {Widget? info}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeMedium,
      ),
      child: Row(
        children: [
          // Label and its info icon take the free width; the amount is
          // pinned to the end edge so every figure lines up in one column.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: WaddyColors.inkMid,
                    ),
                  ),
                ),
                if (info != null) ...[
                  const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                  info,
                ],
              ],
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          value,
        ],
      ),
    );
  }

  Widget _saving(String text) => CheckoutSavingChip(text);

  Widget _value(String text, {Color color = WaddyColors.ink}) {
    return Text(
      text,
      textDirection: TextDirection.ltr,
      style: waddyBold.copyWith(
        fontSize: Dimensions.fontSizeSmall,
        color: color,
      ),
    );
  }
}

/// Two soft mint glows around [child] each time [trigger] changes — "this is
/// what you still need to choose".
class _AttentionPulse extends StatefulWidget {
  final ValueListenable<int> trigger;
  final Widget child;
  const _AttentionPulse({required this.trigger, required this.child});

  @override
  State<_AttentionPulse> createState() => _AttentionPulseState();
}

class _AttentionPulseState extends State<_AttentionPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_pulse);
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_pulse);
    _controller.dispose();
    super.dispose();
  }

  void _pulse() => _controller.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Two bumps over the run: |sin(2πt)| fades in and out twice.
        final double glow =
            _controller.isAnimating
                ? (math.sin(_controller.value * 2 * math.pi)).abs()
                : 0;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: WaddyColors.mint.withValues(alpha: 0.7 * glow),
                blurRadius: 16 * glow,
                spreadRadius: 3 * glow,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

class _InfoGlyph extends StatelessWidget {
  const _InfoGlyph();

  @override
  Widget build(BuildContext context) => const CheckoutIcon(
    icon: HugeIcons.strokeRoundedInformationCircle,
    size: 18,
    color: WaddyColors.inkMuted,
  );
}

class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1.5,
      width: double.infinity,
      child: CustomPaint(painter: _DashPainter()),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double dash = 5, gap = 4;
    final Paint paint =
        Paint()
          ..color = WaddyColors.divider
          ..strokeWidth = size.height;
    final double y = size.height / 2;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

/// Keeps the XP prize list in step with the cart's current value.
///
/// Eligibility depends on the order amount, so this re-syncs whenever the
/// amount changes rather than fetching once — see `syncCheckoutPrizes`. The
/// trigger lives in lifecycle callbacks and not in a builder: firing a fetch
/// from inside `build` is what the controller's `Future.microtask(update)`
/// workarounds existed to tolerate.
class CheckoutPrizeSection extends StatefulWidget {
  const CheckoutPrizeSection({super.key, required this.orderAmount});

  final double orderAmount;

  @override
  State<CheckoutPrizeSection> createState() => _CheckoutPrizeSectionState();
}

class _CheckoutPrizeSectionState extends State<CheckoutPrizeSection> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(CheckoutPrizeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderAmount != widget.orderAmount) _sync();
  }

  void _sync() {
    final amount = widget.orderAmount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Get.find<XpController>().syncCheckoutPrizes(amount);
    });
  }

  @override
  Widget build(BuildContext context) =>
      PrizeSelectionWidget(orderAmount: widget.orderAmount);
}
