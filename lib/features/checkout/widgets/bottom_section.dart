import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_tool_tip_widget.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/checkout/widgets/extra_discount_view_widget.dart';
import 'package:sixam_mart/features/checkout/widgets/prescription_image_picker_widget.dart';
import 'package:sixam_mart/features/checkout/widgets/prize_selection_widget.dart';
import 'package:sixam_mart/features/coupon/controllers/coupon_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/common/models/config_model.dart';
import 'package:sixam_mart/features/checkout/controllers/checkout_controller.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/features/xp/widgets/xp_preview_widget.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/features/checkout/widgets/condition_check_box.dart';
import 'package:sixam_mart/features/checkout/widgets/coupon_section.dart';
import 'package:sixam_mart/features/checkout/widgets/note_prescription_section.dart';
import 'package:sixam_mart/features/checkout/widgets/partial_pay_view.dart';

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
    bool isDesktop = ResponsiveHelper.isDesktop(context);
    bool isGuestLoggedIn = false;
    return Container(
      decoration:
          ResponsiveHelper.isDesktop(context)
              ? BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              )
              : null,
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeSmall,
      ),
      child: Column(
        children: [
          isDesktop
              ? pricingView(context: context, takeAway: takeAway)
              : const SizedBox(),

          const SizedBox(height: Dimensions.paddingSizeSmall),

          /// Coupon
          isDesktop && !isGuestLoggedIn
              ? CouponSection(
                storeId: storeId,
                checkoutController: checkoutController,
                total: total,
                price: price,
                discount: discount,
                addOns: addOns,
                deliveryCharge: deliveryCharge,
                variationPrice: variationPrice,
              )
              : const SizedBox(),

          /// XP Prize Selection (for logged in users, delivery orders only)
          !isGuestLoggedIn && !takeAway && storeId == null
              ? GetBuilder<XpController>(
                builder: (xpController) {
                  // Fetch prizes only once when not already fetched
                  if (!xpController.checkoutPrizesFetched &&
                      !xpController.isCheckoutPrizesLoading &&
                      orderAmount > 0) {
                    Future.microtask(
                      () => xpController.getCheckoutPrizes(orderAmount),
                    );
                  }
                  return PrizeSelectionWidget(orderAmount: orderAmount);
                },
              )
              : const SizedBox(),

          Container(
            margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: isDesktop ? null : BorderRadius.circular(14),
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

                isDesktop && !isGuestLoggedIn
                    ? PartialPayView(
                      totalPrice: total,
                      isPrescription: storeId != null,
                    )
                    : const SizedBox(),

                !isDesktop
                    ? pricingView(context: context, takeAway: takeAway)
                    : const SizedBox(),
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

                ResponsiveHelper.isDesktop(context)
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'total_amount'.tr,
                                  style: robotoMedium.copyWith(
                                    fontSize: Dimensions.fontSizeLarge,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                storeId == null
                                    ? const SizedBox()
                                    : Text(
                                      'Once_your_order_is_confirmed_you_will_receive'
                                          .tr,
                                      style: robotoRegular.copyWith(
                                        fontSize: Dimensions.fontSizeOverSmall,
                                        color: Theme.of(context).disabledColor,
                                      ),
                                    ),
                              ],
                            ),
                            storeId == null
                                ? const SizedBox()
                                : Text(
                                  'a_notification_with_your_bill_total'.tr,
                                  style: robotoRegular.copyWith(
                                    fontSize: Dimensions.fontSizeOverSmall,
                                    color: Theme.of(context).disabledColor,
                                  ),
                                ),
                          ],
                        ),
                        PriceConverter.convertAnimationPrice(
                          checkoutController.viewTotalPrice,
                          textStyle: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeLarge,
                            color:
                                checkoutController.isPartialPay
                                    ? Theme.of(
                                      context,
                                    ).textTheme.bodyMedium!.color
                                    : Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    )
                    : const SizedBox(),
              ],
            ),
          ),

          ResponsiveHelper.isDesktop(context)
              ? Padding(
                padding: const EdgeInsets.only(
                  top: Dimensions.paddingSizeLarge,
                ),
                child: checkoutButton,
              )
              : const SizedBox(),
        ],
      ),
    );
  }

  Widget pricingView({required BuildContext context, required bool takeAway}) {
    final Color primaryColor = Theme.of(context).primaryColor;
    bool isDesktop = ResponsiveHelper.isDesktop(context);

    return Container(
      margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: isDesktop ? null : BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: isDesktop ? BorderRadius.zero : BorderRadius.circular(14),
        child: Stack(
          children: [
            // Decorative glow circle top-right
            if (!isDesktop)
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
                        Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.18),
                        Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(isDesktop ? 0 : 12),
              child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        if (!isDesktop)
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
              Icon(Icons.receipt_long_rounded, size: 16, color: primaryColor),
              const SizedBox(width: 6),
              Text(
                'order_summary'.tr,
                style: robotoBold.copyWith(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),

        if (!isDesktop) const SizedBox(height: 10),

        ResponsiveHelper.isDesktop(context)
            ? Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                  vertical: Dimensions.paddingSizeSmall,
                ),
                child: Text(
                  'order_summary'.tr,
                  style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                  ),
                ),
              ),
            )
            : const SizedBox(),

        // Item breakdown section
        Container(
          padding: isDesktop ? EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge) : const EdgeInsets.all(10),
          decoration: isDesktop ? null : BoxDecoration(
            color: primaryColor.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade100, width: 1),
          ),
          child: Column(
            children: [
              storeId == null
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        module.addOn! ? 'subtotal'.tr : 'item_price'.tr,
                        style: robotoRegular.copyWith(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      Text(
                        PriceConverter.convertPrice(subTotal),
                        style: robotoMedium.copyWith(fontSize: 13),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  )
                  : const SizedBox(),
              SizedBox(
                height: storeId == null ? Dimensions.paddingSizeSmall : 0,
              ),

              storeId == null
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('discount'.tr, style: robotoRegular.copyWith(fontSize: 13, color: Colors.grey.shade600)),
                      Text(
                        '(-) ${PriceConverter.convertPrice(discount)}',
                        style: robotoMedium.copyWith(fontSize: 13, color: Colors.green.shade600),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  )
                  : const SizedBox(),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              (couponController.discount! > 0 || couponController.freeDelivery)
                  ? Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('coupon_discount'.tr, style: robotoRegular),
                          (couponController.coupon != null &&
                                  couponController.coupon!.couponType ==
                                      'free_delivery')
                              ? Text(
                                'free_delivery'.tr,
                                style: robotoRegular.copyWith(
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                              : Text(
                                '(-) ${PriceConverter.convertPrice(couponController.discount)}',
                                style: robotoRegular,
                                textDirection: TextDirection.ltr,
                              ),
                        ],
                      ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                    ],
                  )
                  : const SizedBox(),

              referralDiscount > 0
                  ? Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('referral_discount'.tr, style: robotoRegular),

                          Text(
                            '(-) ${PriceConverter.convertPrice(referralDiscount)}',
                            style: robotoRegular,
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),
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
                      Text('vat_tax'.tr, style: robotoRegular),
                      Text(
                        ('(+) ') + PriceConverter.convertPrice(tax),
                        style: robotoRegular,
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
                      Get.find<SplashController>().configModel!.dmTipsStatus ==
                          1)
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('delivery_man_tips'.tr, style: robotoRegular),
                      Text(
                        '(+) ${PriceConverter.convertPrice(checkoutController.tips)}',
                        style: robotoRegular,
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  )
                  : const SizedBox.shrink(),
              SizedBox(
                height:
                    !takeAway &&
                            Get.find<SplashController>()
                                    .configModel!
                                    .dmTipsStatus ==
                                1
                        ? Dimensions.paddingSizeSmall
                        : 0.0,
              ),

              storeId == null
                  ? (checkoutController.store!.extraPackagingStatus! &&
                          Get.find<CartController>().needExtraPackage)
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('extra_packaging'.tr, style: robotoRegular),
                          Text(
                            '(+) ${PriceConverter.convertPrice(checkoutController.store!.extraPackagingAmount!)}',
                            style: robotoRegular,
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      )
                      : const SizedBox.shrink()
                  : const SizedBox(),
              SizedBox(
                height:
                    storeId == null
                        ? (checkoutController.store!.extraPackagingStatus! &&
                                Get.find<CartController>().needExtraPackage)
                            ? Dimensions.paddingSizeSmall
                            : 0.0
                        : 0.0,
              ),

              Row(
                    children: [
                      Text('delivery_fee'.tr, style: robotoRegular),
                      const SizedBox(width: 5),

                      (checkoutController.orderType == 'delivery') &&
                              (checkoutController.store?.selfDeliverySystem ==
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
                            style: robotoRegular.copyWith(color: Colors.red),
                          )
                          : (deliveryCharge == 0 ||
                              (couponController.coupon != null &&
                                  couponController.coupon!.couponType ==
                                      'free_delivery'))
                          ? Text(
                            'free'.tr,
                            style: robotoRegular.copyWith(
                              color: Theme.of(context).primaryColor,
                            ),
                          )
                          : Text(
                            '(+) ${PriceConverter.convertPrice(deliveryCharge)}',
                            style: robotoRegular,
                            textDirection: TextDirection.ltr,
                          ),
                    ],
                  ),

              SizedBox(
                height:
                    Get.find<SplashController>()
                                .configModel!
                                .additionalChargeStatus! &&
                            true
                        ? Dimensions.paddingSizeSmall
                        : 0,
              ),

              Get.find<SplashController>().configModel!.additionalChargeStatus!
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Get.find<SplashController>()
                            .configModel!
                            .additionalChargeName!,
                        style: robotoRegular,
                      ),
                      Text(
                        '(+) ${PriceConverter.convertPrice(Get.find<SplashController>().configModel!.additionCharge)}',
                        style: robotoRegular,
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
                      Text('paid_by_wallet'.tr, style: robotoRegular),
                      Text(
                        '(-) ${PriceConverter.convertPrice(Get.find<ProfileController>().userInfoModel!.walletBalance!)}',
                        style: robotoRegular,
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
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                          color:
                              !ResponsiveHelper.isDesktop(context)
                                  ? Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.color
                                  : Theme.of(context).primaryColor,
                        ),
                      ),
                      PriceConverter.convertAnimationPrice(
                        checkoutController.viewTotalPrice,
                        textStyle: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                          color:
                              !ResponsiveHelper.isDesktop(context)
                                  ? Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.color
                                  : Theme.of(context).primaryColor,
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
                  color: Theme.of(context).hintColor.withValues(alpha: 0.5),
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

  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: (isBold ? robotoMedium : robotoRegular).copyWith(
              fontSize: isBold ? 14 : 13,
              color: isBold ? Colors.black87 : Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: (isBold ? robotoBold : robotoMedium).copyWith(
            fontSize: isBold ? 14 : 13,
            color: valueColor ?? Colors.black87,
          ),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }
}
