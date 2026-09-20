import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:waddy_app/features/checkout/widgets/guest_create_account.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_dropdown.dart';
import 'package:waddy_app/features/cart/widgets/delivery_option_button_widget.dart';
import 'package:waddy_app/features/checkout/widgets/coupon_section.dart';
import 'package:waddy_app/features/checkout/widgets/delivery_instruction_view.dart';
import 'package:waddy_app/features/checkout/widgets/delivery_section.dart';
import 'package:waddy_app/features/checkout/widgets/deliveryman_tips_section.dart';
import 'package:waddy_app/features/checkout/widgets/payment_section.dart';
import 'package:waddy_app/features/checkout/widgets/time_slot_section.dart';
import 'package:waddy_app/features/store/widgets/camera_button_sheet_widget.dart';
import 'dart:io';

class TopSection extends StatelessWidget {
  final CheckoutController checkoutController;
  final double charge;
  final double deliveryCharge;
  final List<DropdownItem<int>> addressList;
  final bool tomorrowClosed;
  final bool todayClosed;
  final Module? module;
  final double price;
  final double discount;
  final double addOns;
  final int? storeId;
  final List<AddressModel> address;
  final List<CartModel?>? cartList;
  final bool isCashOnDeliveryActive;
  final bool isDigitalPaymentActive;
  final bool isWalletActive;
  final double total;
  final bool isOfflinePaymentActive;
  final TextEditingController guestNameTextEditingController;
  final TextEditingController guestNumberTextEditingController;
  final TextEditingController guestEmailController;
  final FocusNode guestNumberNode;
  final FocusNode guestEmailNode;
  final JustTheController tooltipController1;
  final JustTheController tooltipController2;
  final JustTheController dmTipsTooltipController;
  final TextEditingController guestPasswordController;
  final TextEditingController guestConfirmPasswordController;
  final FocusNode guestPasswordNode;
  final FocusNode guestConfirmPasswordNode;
  final double variationPrice;
  final String deliveryChargeForView;
  final double badWeatherCharge;
  final double extraChargeForToolTip;

  const TopSection({
    super.key,
    required this.deliveryCharge,
    required this.charge,
    required this.tomorrowClosed,
    required this.todayClosed,
    required this.price,
    required this.discount,
    required this.addOns,
    required this.addressList,
    required this.checkoutController,
    this.module,
    this.storeId,
    required this.address,
    required this.cartList,
    required this.isCashOnDeliveryActive,
    required this.isDigitalPaymentActive,
    required this.isWalletActive,
    required this.total,
    required this.isOfflinePaymentActive,
    required this.guestNameTextEditingController,
    required this.guestNumberTextEditingController,
    required this.guestNumberNode,
    required this.guestEmailController,
    required this.guestEmailNode,
    required this.tooltipController1,
    required this.tooltipController2,
    required this.dmTipsTooltipController,
    required this.guestPasswordController,
    required this.guestConfirmPasswordController,
    required this.guestPasswordNode,
    required this.guestConfirmPasswordNode,
    required this.variationPrice,
    required this.deliveryChargeForView,
    required this.badWeatherCharge,
    required this.extraChargeForToolTip,
  });

  @override
  Widget build(BuildContext context) {
    bool takeAway = (checkoutController.orderType == 'take_away');
    // Pinned false, which is why the analyzer calls the three branches below
    // dead (CS-10). Not stray dead code: it is the guest-checkout UI, kept
    // against the guest-mode plan (docs/guest_mode_plan.md), which is
    // specified but not built. Left in place deliberately — deleting it would
    // throw away the scaffolding that plan assumes. Becomes live when guest
    // checkout is wired; until then the analyzer's five warnings here are
    // expected and should not be "fixed" by deletion.
    bool isGuestLoggedIn = false;

    return Container(
      decoration: null,
      child: Column(
        children: [
          storeId != null
              ? Container(
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
                  horizontal: Dimensions.paddingSizeLarge,
                  vertical: Dimensions.paddingSizeSmall,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('your_prescription'.tr, style: waddyMedium),
                        const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                        JustTheTooltip(
                          backgroundColor: Colors.black87,
                          controller: tooltipController1,
                          preferredDirection: AxisDirection.right,
                          tailLength: 14,
                          tailBaseWidth: 20,
                          content: Padding(
                            padding: const EdgeInsets.all(
                              Dimensions.paddingSizeSmall,
                            ),
                            child: Text(
                              'prescription_tool_tip'.tr,
                              style: waddyRegular.copyWith(color: Colors.white),
                            ),
                          ),
                          child: InkWell(
                            onTap: () => tooltipController1.showTooltip(),
                            child: const Icon(Icons.info_outline),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),

                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount:
                            checkoutController.pickedPrescriptions.length + 1,
                        padding: const EdgeInsets.only(
                          bottom: Dimensions.paddingSizeExtraSmall,
                        ),
                        itemBuilder: (context, index) {
                          XFile? file =
                              index ==
                                      checkoutController
                                          .pickedPrescriptions
                                          .length
                                  ? null
                                  : checkoutController
                                      .pickedPrescriptions[index];
                          if (index < 5 &&
                              index ==
                                  checkoutController
                                      .pickedPrescriptions
                                      .length) {
                            return InkWell(
                              onTap: () {
                                if (GetPlatform.isIOS) {
                                  checkoutController.pickPrescriptionImage(
                                    isRemove: false,
                                    isCamera: false,
                                  );
                                } else {
                                  Get.bottomSheet(
                                    const CameraButtonSheetWidget(),
                                  );
                                }
                              },
                              child: DottedBorder(
                                color: Theme.of(context).primaryColor,
                                strokeWidth: 1,
                                strokeCap: StrokeCap.butt,
                                dashPattern: const [5, 5],
                                padding: const EdgeInsets.all(0),
                                borderType: BorderType.RRect,
                                radius: const Radius.circular(
                                  Dimensions.radiusDefault,
                                ),
                                child: Container(
                                  height: 98,
                                  width: 98,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusSmall,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload,
                                        color: Theme.of(context).disabledColor,
                                        size: 32,
                                      ),
                                      Text(
                                        'upload_your_prescription'.tr,
                                        style: waddyRegular.copyWith(
                                          color:
                                              Theme.of(context).disabledColor,
                                          fontSize: Dimensions.fontSizeSmall,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          return file != null
                              ? Container(
                                margin: const EdgeInsets.only(
                                  right: Dimensions.paddingSizeSmall,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusSmall,
                                  ),
                                ),
                                child: DottedBorder(
                                  color: Theme.of(context).primaryColor,
                                  strokeWidth: 1,
                                  strokeCap: StrokeCap.butt,
                                  dashPattern: const [5, 5],
                                  padding: const EdgeInsets.all(0),
                                  borderType: BorderType.RRect,
                                  radius: const Radius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      Dimensions.paddingSizeExtraSmall,
                                    ),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusDefault,
                                          ),
                                          child: Image.file(
                                            File(file.path),
                                            width: 98,
                                            height: 98,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: InkWell(
                                            onTap:
                                                () => checkoutController
                                                    .removePrescriptionImage(
                                                      index,
                                                    ),
                                            child: const Padding(
                                              padding: EdgeInsets.all(
                                                Dimensions.paddingSizeSmall,
                                              ),
                                              child: Icon(
                                                Icons.delete_forever,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              : const SizedBox();
                        },
                      ),
                    ),
                  ],
                ),
              )
              : const SizedBox(),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          // delivery option
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
              horizontal: Dimensions.paddingSizeLarge,
              vertical: Dimensions.paddingSizeSmall,
            ),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('delivery_type'.tr, style: waddyMedium),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                storeId != null
                    ? DeliveryOptionButtonWidget(
                      value: 'delivery',
                      title: 'home_delivery'.tr,
                      charge: charge,
                      isFree: checkoutController.store!.freeDelivery,
                      fromWeb: true,
                      total: total,
                      deliveryChargeForView: deliveryChargeForView,
                      badWeatherCharge: badWeatherCharge,
                      extraChargeForToolTip: extraChargeForToolTip,
                    )
                    : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Get.find<SplashController>()
                                          .configModel
                                          .homeDeliveryStatus ==
                                      1 &&
                                  checkoutController.store!.delivery!
                              ? DeliveryOptionButtonWidget(
                                value: 'delivery',
                                title: 'home_delivery'.tr,
                                charge: charge,
                                isFree: checkoutController.store!.freeDelivery,
                                fromWeb: true,
                                total: total,
                                deliveryChargeForView: deliveryChargeForView,
                                badWeatherCharge: badWeatherCharge,
                                extraChargeForToolTip: extraChargeForToolTip,
                              )
                              : const SizedBox(),
                          const SizedBox(width: Dimensions.paddingSizeDefault),

                          Get.find<SplashController>()
                                          .configModel
                                          .takeawayStatus ==
                                      1 &&
                                  checkoutController.store!.takeAway!
                              ? DeliveryOptionButtonWidget(
                                value: 'take_away',
                                title: 'take_away'.tr,
                                charge: deliveryCharge,
                                isFree: true,
                                fromWeb: true,
                                total: total,
                                deliveryChargeForView: deliveryChargeForView,
                                badWeatherCharge: badWeatherCharge,
                                extraChargeForToolTip: extraChargeForToolTip,
                              )
                              : const SizedBox(),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),

          ///delivery section
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child: DeliverySection(
                checkoutController: checkoutController,
                address: address,
                addressList: addressList,
                guestNameTextEditingController: guestNameTextEditingController,
                guestNumberTextEditingController:
                    guestNumberTextEditingController,
                guestNumberNode: guestNumberNode,
                guestEmailController: guestEmailController,
                guestEmailNode: guestEmailNode,
              ),
            ),
          ),

          SizedBox(height: !takeAway ? Dimensions.paddingSizeSmall : 0),

          ///Create Account with existing info
          isGuestLoggedIn &&
                  Get.find<SplashController>()
                      .configModel
                      .centralizeLoginSetup!
                      .manualLoginStatus!
              ? Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                child: GuestCreateAccount(
                  guestPasswordController: guestPasswordController,
                  guestConfirmPasswordController:
                      guestConfirmPasswordController,
                  guestPasswordNode: guestPasswordNode,
                  guestConfirmPasswordNode: guestConfirmPasswordNode,
                ),
              )
              : const SizedBox(),
          SizedBox(
            height:
                isGuestLoggedIn &&
                        Get.find<SplashController>()
                            .configModel
                            .centralizeLoginSetup!
                            .manualLoginStatus!
                    ? Dimensions.paddingSizeSmall
                    : 0,
          ),

          ///delivery instruction
          !takeAway
              ? Container(
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  child: const DeliveryInstructionView(),
                ),
              )
              : const SizedBox(),
          SizedBox(height: !takeAway ? Dimensions.paddingSizeSmall : 0),

          /// Time Slot
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child: TimeSlotSection(
                storeId: storeId,
                checkoutController: checkoutController,
                cartList: cartList,
                tooltipController2: tooltipController2,
                tomorrowClosed: tomorrowClosed,
                todayClosed: todayClosed,
                module: module,
              ),
            ),
          ),

          /// Coupon..
          !isGuestLoggedIn
              ? Container(
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  child: CouponSection(
                    storeId: storeId,
                    checkoutController: checkoutController,
                    total: total,
                    price: price,
                    discount: discount,
                    addOns: addOns,
                    deliveryCharge: deliveryCharge,
                    variationPrice: variationPrice,
                  ),
                ),
              )
              : const SizedBox(),

          ///DmTips..
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child: DeliveryManTipsSection(
                takeAway: takeAway,
                tooltipController3: dmTipsTooltipController,
                totalPrice: total,
                onTotalChange: (double price) => total + price,
                storeId: storeId,
              ),
            ),
          ),

          ///Payment..
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
          const SizedBox(height: 0),
        ],
      ),
    );
  }
}
