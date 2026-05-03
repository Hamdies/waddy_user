import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/common/widgets/address_widget.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_dropdown.dart';
import 'package:waddy_app/common/widgets/custom_text_field.dart';
import 'package:waddy_app/features/checkout/widgets/guest_delivery_address.dart';

class DeliverySection extends StatelessWidget {
  final CheckoutController checkoutController;
  final List<AddressModel> address;
  final List<DropdownItem<int>> addressList;
  final TextEditingController guestNameTextEditingController;
  final TextEditingController guestNumberTextEditingController;
  final TextEditingController guestEmailController;
  final FocusNode guestNumberNode;
  final FocusNode guestEmailNode;
  const DeliverySection({super.key, required this.checkoutController, required this.address, required this.addressList, required this.guestNameTextEditingController,
    required this.guestNumberTextEditingController, required this.guestNumberNode, required this.guestEmailController, required this.guestEmailNode,
  });

  @override
  Widget build(BuildContext context) {
    bool isGuestLoggedIn = false;
    bool takeAway = (checkoutController.orderType == 'take_away');
    bool isDesktop = ResponsiveHelper.isDesktop(context);
    return Column(children: [
      isGuestLoggedIn ? GuestDeliveryAddress(
        checkoutController: checkoutController, guestNumberNode: guestNumberNode,
        guestNameTextEditingController: guestNameTextEditingController, guestNumberTextEditingController: guestNumberTextEditingController,
        guestEmailController: guestEmailController, guestEmailNode: guestEmailNode,
      ) : !takeAway ? Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('deliver_to'.tr, style: robotoMedium),
            TextButton.icon(
              onPressed: () async {
                var address = await Get.toNamed(RouteHelper.getAddAddressRoute(true, false, checkoutController.store!.zoneId));
                if(address != null) {
                  checkoutController.getDistanceInKM(
                    LatLng(double.parse(address.latitude), double.parse(address.longitude)),
                    LatLng(double.parse(checkoutController.store!.latitude!), double.parse(checkoutController.store!.longitude!)),
                  );
                  checkoutController.streetNumberController.text = address.streetNumber ?? '';
                  checkoutController.houseController.text = address.house ?? '';
                  checkoutController.floorController.text = address.floor ?? '';
                }
              },
              icon: const Icon(Icons.add, size: 20),
              label: Text('add_new'.tr, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
            ),
          ]),

          isDesktop ? Stack(children: [
            Container(
              constraints: const BoxConstraints(minHeight:  90),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              ),
              child: Container(
                height: 45,
                padding: const EdgeInsets.symmetric(
                  vertical: Dimensions.paddingSizeExtraSmall,
                  horizontal: Dimensions.paddingSizeExtraSmall,
                ),
                child: AddressWidget(
                  address: address[checkoutController.addressIndex!],
                  fromAddress: false, fromCheckout: true,
                ),
              ),
            ),

            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton(
                    position: PopupMenuPosition.under,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onSelected: (value) {},
                    itemBuilder: (context)  => List.generate(
                      address.length, (index) => PopupMenuItem(
                      child: InkWell(
                        onTap: () {
                          checkoutController.getDistanceInKM(
                            LatLng(
                              double.parse(address[index].latitude!),
                              double.parse(address[index].longitude!),
                            ),
                            LatLng(double.parse(checkoutController.store!.latitude!), double.parse(checkoutController.store!.longitude!)),
                          );
                          checkoutController.setAddressIndex(index);
                          checkoutController.streetNumberController.text = address[checkoutController.addressIndex!].streetNumber ?? '';
                          checkoutController.houseController.text = address[checkoutController.addressIndex!].house ?? '';
                          checkoutController.floorController.text = address[checkoutController.addressIndex!].floor ?? '';
                          Navigator.pop(context);
                        },
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 20, width: 20,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: checkoutController.addressIndex == index ? Theme.of(context).primaryColor : Theme.of(context).disabledColor),
                                ),
                                child: checkoutController.addressIndex == index ? Container(
                                  height: 15, width: 15,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).primaryColor),
                                ) : const SizedBox(),
                              ),

                              const SizedBox(width: Dimensions.paddingSizeSmall),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(address[index].addressType!.tr, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
                                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                                    Text(
                                      address[index].address!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                        ),
                      ),
                    )
                    )
                ),
              ),
            ),
          ]) :
          // ── Mobile: Waddy-styled address row with popup selector ──
          PopupMenuButton<int>(
            position: PopupMenuPosition.under,
            elevation: 4,
            color: WaddyColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (index) {
              checkoutController.getDistanceInKM(
                LatLng(double.parse(address[index].latitude!), double.parse(address[index].longitude!)),
                LatLng(double.parse(checkoutController.store!.latitude!), double.parse(checkoutController.store!.longitude!)),
              );
              checkoutController.setAddressIndex(index);
              checkoutController.streetNumberController.text = address[index].streetNumber ?? '';
              checkoutController.houseController.text = address[index].house ?? '';
              checkoutController.floorController.text = address[index].floor ?? '';
            },
            itemBuilder: (context) => List.generate(
              address.length,
              (index) => PopupMenuItem<int>(
                value: index,
                child: Row(
                  children: [
                    Container(
                      height: 20, width: 20,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: checkoutController.addressIndex == index
                              ? WaddyColors.primary
                              : WaddyColors.inkMuted,
                        ),
                      ),
                      child: checkoutController.addressIndex == index
                          ? Container(height: 15, width: 15, decoration: const BoxDecoration(shape: BoxShape.circle, color: WaddyColors.primary))
                          : const SizedBox(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(address[index].addressType!.tr, style: robotoMedium.copyWith(fontSize: 13, color: WaddyColors.ink)),
                          Text(
                            address[index].address ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: robotoRegular.copyWith(fontSize: 12, color: WaddyColors.inkLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: WaddyColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, size: 24, color: WaddyColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'deliver_to'.tr,
                          style: robotoRegular.copyWith(fontSize: 11, color: WaddyColors.inkMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          address.isNotEmpty ? (address[checkoutController.addressIndex!].address ?? 'tap_to_set_address'.tr) : 'tap_to_set_address'.tr,
                          style: robotoMedium.copyWith(fontSize: 13, color: WaddyColors.ink),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: WaddyColors.inkMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),

          !isDesktop ? CustomTextField(
            labelText: 'street_number'.tr,
            titleText: 'write_street_number'.tr,
            inputType: TextInputType.streetAddress,
            focusNode: checkoutController.streetNode,
            nextFocus: checkoutController.houseNode,
            controller: checkoutController.streetNumberController,
          ) : const SizedBox(),
          SizedBox(height: !isDesktop ? Dimensions.paddingSizeLarge : 0),

          Row(
              children: [
                isDesktop ? Expanded(
                  child: CustomTextField(
                    titleText: 'write_street_number'.tr,
                    labelText: 'street_number'.tr,
                    inputType: TextInputType.streetAddress,
                    focusNode: checkoutController.streetNode,
                    nextFocus: checkoutController.houseNode,
                    controller: checkoutController.streetNumberController,
                  ),
                ) : const SizedBox(),
                SizedBox(width: isDesktop ? Dimensions.paddingSizeSmall : 0),

                Expanded(
                  child: CustomTextField(
                    titleText: 'write_house_number'.tr,
                    labelText: 'house'.tr,
                    inputType: TextInputType.text,
                    focusNode: checkoutController.houseNode,
                    nextFocus: checkoutController.floorNode,
                    controller: checkoutController.houseController,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),

                Expanded(
                  child: CustomTextField(
                    titleText: 'write_floor_number'.tr,
                    labelText: 'floor'.tr,
                    inputType: TextInputType.text,
                    focusNode: checkoutController.floorNode,
                    inputAction: TextInputAction.done,
                    controller: checkoutController.floorController,
                  ),
                ),
                //const SizedBox(height: Dimensions.paddingSizeLarge),
              ]
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),
        ]),
      ) : const SizedBox(),
    ]);
  }
}
