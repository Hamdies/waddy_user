import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_tool_tip_widget.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/checkout/widgets/extra_discount_view_widget.dart';
import 'package:waddy_app/features/checkout/widgets/prescription_image_picker_widget.dart';
import 'package:waddy_app/features/checkout/widgets/prize_selection_widget.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/widgets/xp_preview_widget.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/checkout/widgets/condition_check_box.dart';
import 'package:waddy_app/features/checkout/widgets/note_prescription_section.dart';

class BottomSection extends StatelessWidget {
  final CheckoutController checkoutController;
  final double total;
  final Module module;
  final double subTotal;
  final double discount;
  final CouponController couponController;
  final bool taxIncluded;
  final double tax;
  final double deliveryCharge;
  final bool todayClosed;
  final bool tomorrowClosed;
  final double orderAmount;
  final double? maxCodOrderAmount;
  final int? storeId;
  final double? taxPercent;
  final double price;
  final double addOns;
  final Widget? checkoutButton;
  final bool isPrescriptionRequired;
  final double referralDiscount;
  final double variationPrice;
  final double extraDiscount;

  const BottomSection({
    super.key,
    required this.checkoutController,
    required this.total,
    required this.module,
    required this.subTotal,
    required this.discount,
    required this.couponController,
    required this.taxIncluded,
    required this.tax,
    required this.deliveryCharge,
    required this.todayClosed,
    required this.tomorrowClosed,
    required this.orderAmount,
    this.maxCodOrderAmount,
    this.storeId,
    this.taxPercent,
    required this.price,
    required this.addOns,
    this.checkoutButton,
    required this.isPrescriptionRequired,
    required this.referralDiscount,
    required this.variationPrice,
    required this.extraDiscount,
  });

  @override
  Widget build(BuildContext context) {
    bool takeAway = checkoutController.orderType == 'take_away';
    bool isGuestLoggedIn = false;
    return Container(
      decoration: null,
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeSmall,
      ),
      child: Column(
        children: [
          const SizedBox(),

          const SizedBox(height: Dimensions.paddingSizeSmall),

          /// Coupon
          const SizedBox(),

          /// XP Prize Selection (for logged in users, delivery orders only)
          !isGuestLoggedIn && !takeAway && storeId == null
              ? _CheckoutPrizeSection(orderAmount: orderAmount)
              : const SizedBox(),

          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              vertical: Dimensions.paddingSizeDefault,
              horizontal: Dimensions.paddingSizeLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ///Additional Note & prescription..
                NoteAndPrescriptionSection(
                  checkoutController: checkoutController,
                  storeId: storeId,
                ),

                const SizedBox(),

                pricingView(context: context, takeAway: takeAway),
                const SizedBox(height: Dimensions.paddingSizeLarge),

                PrescriptionImagePickerWidget(
                  checkoutController: checkoutController,
                  storeId: storeId,
                  isPrescriptionRequired: isPrescriptionRequired,
                ),

                const CheckoutCondition(),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                ExtraDiscountViewWidget(extraDiscount: extraDiscount),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                const SizedBox(),
              ],
            ),
          ),

          const SizedBox(),
        ],
      ),
    );
  }

  Widget pricingView({required BuildContext context, required bool takeAway}) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(
          color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        child: Stack(
          children: [
            // Decorative glow circle top-right
            Positioned(
              top: -18,
              right: -18,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).secondaryHeaderColor.withValues(alpha: 0.18),
                      Theme.of(
                        context,
                      ).secondaryHeaderColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).secondaryHeaderColor,
                              primaryColor,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 16,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'order_summary'.tr,
                        style: waddyBold.copyWith(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  const SizedBox(),

                  // Item breakdown section
                  Container(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                      border: Border.all(color: Colors.grey.shade100, width: 1),
                    ),
                    child: Column(
                      children: [
                        storeId == null
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  module.addOn!
                                      ? 'subtotal'.tr
                                      : 'item_price'.tr,
                                  style: waddyRegular.copyWith(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  PriceConverter.convertPrice(subTotal),
                                  style: waddyMedium.copyWith(fontSize: 13),
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            )
                            : const SizedBox(),
                        SizedBox(
                          height:
                              storeId == null ? Dimensions.paddingSizeSmall : 0,
                        ),

                        storeId == null
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'discount'.tr,
                                  style: waddyRegular.copyWith(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '(-) ${PriceConverter.convertPrice(discount)}',
                                  style: waddyMedium.copyWith(
                                    fontSize: 13,
                                    color: Colors.green.shade600,
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            )
                            : const SizedBox(),
                        const SizedBox(height: Dimensions.paddingSizeSmall),

                        (couponController.discount! > 0 ||
                                couponController.freeDelivery)
                            ? Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'coupon_discount'.tr,
                                      style: waddyRegular,
                                    ),
                                    (couponController.coupon != null &&
                                            couponController
                                                    .coupon!
                                                    .couponType ==
                                                'free_delivery')
                                        ? Text(
                                          'free_delivery'.tr,
                                          style: waddyRegular.copyWith(
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        )
                                        : Text(
                                          '(-) ${PriceConverter.convertPrice(couponController.discount)}',
                                          style: waddyRegular,
                                          textDirection: TextDirection.ltr,
                                        ),
                                  ],
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeSmall,
                                ),
                              ],
                            )
                            : const SizedBox(),

                        referralDiscount > 0
                            ? Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'referral_discount'.tr,
                                      style: waddyRegular,
                                    ),

                                    Text(
                                      '(-) ${PriceConverter.convertPrice(referralDiscount)}',
                                      style: waddyRegular,
                                      textDirection: TextDirection.ltr,
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeSmall,
                                ),
                              ],
                            )
                            : const SizedBox(),

                        ((checkoutController.taxIncluded == null) ||
                                taxIncluded ||
                                (checkoutController.orderTax == 0))
                            ? const SizedBox()
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('vat_tax'.tr, style: waddyRegular),
                                Text(
                                  ('(+) ') + PriceConverter.convertPrice(tax),
                                  style: waddyRegular,
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            ),
                        SizedBox(
                          height:
                              ((checkoutController.taxIncluded == null) ||
                                      taxIncluded ||
                                      (checkoutController.orderTax == 0))
                                  ? 0
                                  : Dimensions.paddingSizeSmall,
                        ),

                        (!takeAway &&
                                Get.find<SplashController>()
                                        .configModel
                                        .dmTipsStatus ==
                                    1)
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'delivery_man_tips'.tr,
                                  style: waddyRegular,
                                ),
                                Text(
                                  '(+) ${PriceConverter.convertPrice(checkoutController.tips)}',
                                  style: waddyRegular,
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            )
                            : const SizedBox.shrink(),
                        SizedBox(
                          height:
                              !takeAway &&
                                      Get.find<SplashController>()
                                              .configModel
                                              .dmTipsStatus ==
                                          1
                                  ? Dimensions.paddingSizeSmall
                                  : 0.0,
                        ),

                        storeId == null
                            ? (checkoutController
                                        .store!
                                        .extraPackagingStatus! &&
                                    Get.find<CartController>().needExtraPackage)
                                ? Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'extra_packaging'.tr,
                                      style: waddyRegular,
                                    ),
                                    Text(
                                      '(+) ${PriceConverter.convertPrice(checkoutController.store!.extraPackagingAmount!)}',
                                      style: waddyRegular,
                                      textDirection: TextDirection.ltr,
                                    ),
                                  ],
                                )
                                : const SizedBox.shrink()
                            : const SizedBox(),
                        SizedBox(
                          height:
                              storeId == null
                                  ? (checkoutController
                                              .store!
                                              .extraPackagingStatus! &&
                                          Get.find<CartController>()
                                              .needExtraPackage)
                                      ? Dimensions.paddingSizeSmall
                                      : 0.0
                                  : 0.0,
                        ),

                        Row(
                          children: [
                            Text('delivery_fee'.tr, style: waddyRegular),
                            const SizedBox(width: 5),

                            (checkoutController.orderType == 'delivery') &&
                                    (checkoutController
                                            .store
                                            ?.selfDeliverySystem ==
                                        0) &&
                                    (checkoutController
                                            .surgePrice
                                            ?.customerNoteStatus ==
                                        1)
                                ? CustomToolTip(
                                  message:
                                      '${'this_delivery_fee_includes_all_the_applicable_charges_on_delivery'.tr} ${checkoutController.surgePrice?.customerNote ?? ''}',
                                )
                                : const SizedBox(),

                            const Spacer(),

                            checkoutController.distance == -1
                                ? Text(
                                  'calculating'.tr,
                                  style: waddyRegular.copyWith(
                                    color: Colors.red,
                                  ),
                                )
                                : (deliveryCharge == 0 ||
                                    (couponController.coupon != null &&
                                        couponController.coupon!.couponType ==
                                            'free_delivery'))
                                ? Text(
                                  'free'.tr,
                                  style: waddyRegular.copyWith(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                )
                                : Text(
                                  '(+) ${PriceConverter.convertPrice(deliveryCharge)}',
                                  style: waddyRegular,
                                  textDirection: TextDirection.ltr,
                                ),
                          ],
                        ),

                        SizedBox(
                          height:
                              Get.find<SplashController>()
                                      .configModel
                                      .additionalChargeStatus!
                                  ? Dimensions.paddingSizeSmall
                                  : 0,
                        ),

                        Get.find<SplashController>()
                                .configModel
                                .additionalChargeStatus!
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  Get.find<SplashController>()
                                      .configModel
                                      .additionalChargeName!,
                                  style: waddyRegular,
                                ),
                                Text(
                                  '(+) ${PriceConverter.convertPrice(Get.find<SplashController>().configModel.additionCharge)}',
                                  style: waddyRegular,
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            )
                            : const SizedBox(),
                        SizedBox(
                          height:
                              checkoutController.isPartialPay
                                  ? Dimensions.paddingSizeSmall
                                  : 0,
                        ),

                        checkoutController.isPartialPay
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('paid_by_wallet'.tr, style: waddyRegular),
                                Text(
                                  '(-) ${PriceConverter.convertPrice(Get.find<ProfileController>().userInfoModel!.walletBalance!)}',
                                  style: waddyRegular,
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            )
                            : const SizedBox(),
                        SizedBox(
                          height:
                              checkoutController.isPartialPay
                                  ? Dimensions.paddingSizeSmall
                                  : 0,
                        ),

                        checkoutController.isPartialPay
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'due_payment'.tr,
                                  style: waddyMedium.copyWith(
                                    fontSize: Dimensions.fontSizeLarge,
                                    color:
                                        Theme.of(
                                          context,
                                        ).textTheme.bodyMedium!.color,
                                  ),
                                ),
                                PriceConverter.convertAnimationPrice(
                                  checkoutController.viewTotalPrice,
                                  textStyle: waddyMedium.copyWith(
                                    fontSize: Dimensions.fontSizeLarge,
                                    color:
                                        Theme.of(
                                          context,
                                        ).textTheme.bodyMedium!.color,
                                  ),
                                ),
                              ],
                            )
                            : const SizedBox(),

                        // XP Preview Widget (for logged-in users)
                        XpPreviewWidget(orderAmount: orderAmount),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Dimensions.paddingSizeSmall,
                          ),
                          child: Divider(
                            thickness: 1,
                            color: Theme.of(
                              context,
                            ).hintColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the XP prize list in step with the cart's current value.
///
/// Eligibility depends on the order amount, so this re-syncs whenever the
/// amount changes rather than fetching once — see `syncCheckoutPrizes`. The
/// trigger lives in lifecycle callbacks and not in a builder: firing a fetch
/// from inside `build` is what the controller's `Future.microtask(update)`
/// workarounds existed to tolerate.
class _CheckoutPrizeSection extends StatefulWidget {
  const _CheckoutPrizeSection({required this.orderAmount});

  final double orderAmount;

  @override
  State<_CheckoutPrizeSection> createState() => _CheckoutPrizeSectionState();
}

class _CheckoutPrizeSectionState extends State<_CheckoutPrizeSection> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_CheckoutPrizeSection oldWidget) {
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
