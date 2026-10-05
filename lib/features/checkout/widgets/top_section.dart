import 'package:flutter/material.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_delivery_eta_card.dart';
import 'package:waddy_app/features/checkout/widgets/guest_create_account.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_dropdown.dart';
import 'package:waddy_app/features/checkout/widgets/coupon_section.dart';
import 'package:waddy_app/features/checkout/widgets/delivery_instruction_view.dart';
import 'package:waddy_app/features/checkout/widgets/delivery_section.dart';
import 'package:waddy_app/features/checkout/widgets/deliveryman_tips_section.dart';
import 'package:waddy_app/features/store/widgets/camera_button_sheet_widget.dart';
import 'dart:io';

/// The upper half of checkout, in the design's order: prescription upload
/// (prescription orders only), when it arrives, the rider tip, delivery
/// instructions, then the promo code.
///
/// The delivery address is not here any more — it lives in the bottom bar,
/// next to the button it qualifies ("Delivering to Home · Change").
class TopSection extends StatelessWidget {
  final CheckoutController checkoutController;
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
  final double total;
  final TextEditingController guestNameTextEditingController;
  final TextEditingController guestNumberTextEditingController;
  final TextEditingController guestEmailController;
  final FocusNode guestNumberNode;
  final FocusNode guestEmailNode;
  final JustTheController tooltipController1;
  final JustTheController tooltipController2;
  final TextEditingController guestPasswordController;
  final TextEditingController guestConfirmPasswordController;
  final FocusNode guestPasswordNode;
  final FocusNode guestConfirmPasswordNode;
  final double variationPrice;
  final String deliveryChargeForView;

  const TopSection({
    super.key,
    required this.deliveryCharge,
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
    required this.total,
    required this.guestNameTextEditingController,
    required this.guestNumberTextEditingController,
    required this.guestNumberNode,
    required this.guestEmailController,
    required this.guestEmailNode,
    required this.tooltipController1,
    required this.tooltipController2,
    required this.guestPasswordController,
    required this.guestConfirmPasswordController,
    required this.guestPasswordNode,
    required this.guestConfirmPasswordNode,
    required this.variationPrice,
    required this.deliveryChargeForView,
  });

  @override
  Widget build(BuildContext context) {
    bool takeAway = (checkoutController.orderType == 'take_away');
    // Pinned false, which is why the analyzer calls the branches below dead
    // (CS-10). Not stray dead code: it is the guest-checkout UI, kept against
    // the guest-mode plan (docs/guest_mode_plan.md), which is specified but
    // not built. Left in place deliberately — deleting it would throw away the
    // scaffolding that plan assumes. Becomes live when guest checkout is
    // wired; until then the analyzer's warnings here are expected and should
    // not be "fixed" by deletion.
    bool isGuestLoggedIn = false;
    const gap = SizedBox(height: Dimensions.paddingSizeDefault);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        storeId != null
            ? Padding(
              padding: const EdgeInsets.only(
                bottom: Dimensions.paddingSizeDefault,
              ),
              child: CheckoutCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('your_prescription'.tr, style: waddyMedium),
                        const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                        JustTheTooltip(
                          backgroundColor: WaddyColors.ink,
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
                              style: waddyRegular.copyWith(
                                color: WaddyColors.surface,
                              ),
                            ),
                          ),
                          child: InkWell(
                            onTap: () => tooltipController1.showTooltip(),
                            child: const CheckoutIcon(
                              icon: HugeIcons.strokeRoundedInformationCircle,
                            ),
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
                                color: WaddyColors.primary,
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
                                      CheckoutIcon(
                                        icon:
                                            HugeIcons.strokeRoundedCloudUpload,
                                        color: WaddyColors.inkMuted,
                                        size: 32,
                                      ),
                                      Text(
                                        'upload_your_prescription'.tr,
                                        style: waddyRegular.copyWith(
                                          color: WaddyColors.inkMuted,
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
                                  color: WaddyColors.primary,
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
                                              child: CheckoutIcon(
                                                icon:
                                                    HugeIcons
                                                        .strokeRoundedDelete02,
                                                color: WaddyColors.error,
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
              ),
            )
            : const SizedBox(),

        CheckoutDeliveryEtaCard(
          checkoutController: checkoutController,
          cartList: cartList,
          storeId: storeId,
          todayClosed: todayClosed,
          tomorrowClosed: tomorrowClosed,
          module: module,
          total: total,
          deliveryCharge: deliveryCharge,
          deliveryChargeForView: deliveryChargeForView,
          scheduleTooltipController: tooltipController2,
        ),

        ///DmTips.. (renders nothing for take-away or when tips are off)
        if (!takeAway &&
            Get.find<SplashController>().configModel.dmTipsStatus == 1) ...[
          gap,
          DeliveryManTipsSection(
            takeAway: takeAway,
            totalPrice: total,
            onTotalChange: (double price) => total + price,
            storeId: storeId,
          ),
        ],

        ///delivery instruction
        if (!takeAway) ...[
          gap,
          DeliveryInstructionView(savedVoiceUrl: _selectedAddressVoiceUrl()),
        ],

        /// Guest address form — see the note on [isGuestLoggedIn].
        if (isGuestLoggedIn) ...[
          gap,
          CheckoutCard(
            padding: EdgeInsets.zero,
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
        ],

        ///Create Account with existing info
        if (isGuestLoggedIn &&
            Get.find<SplashController>()
                .configModel
                .centralizeLoginSetup!
                .manualLoginStatus!) ...[
          gap,
          CheckoutCard(
            padding: EdgeInsets.zero,
            child: GuestCreateAccount(
              guestPasswordController: guestPasswordController,
              guestConfirmPasswordController: guestConfirmPasswordController,
              guestPasswordNode: guestPasswordNode,
              guestConfirmPasswordNode: guestConfirmPasswordNode,
            ),
          ),
        ],

        /// Coupon..
        if (!isGuestLoggedIn && storeId == null) ...[
          const SizedBox(height: Dimensions.paddingSizeExtraLarge),
          CouponSection(
            storeId: storeId,
            checkoutController: checkoutController,
            total: total,
            price: price,
            discount: discount,
            addOns: addOns,
            deliveryCharge: deliveryCharge,
            variationPrice: variationPrice,
          ),
        ],
      ],
    );
  }

  /// The selected delivery address's saved voice note, if it has one.
  String? _selectedAddressVoiceUrl() {
    final int index = checkoutController.addressIndex ?? 0;
    if (index < 0 || index >= address.length) return null;
    final String? url = address[index].voiceInstructionFullUrl;
    return (url == null || url.isEmpty) ? null : url;
  }
}
