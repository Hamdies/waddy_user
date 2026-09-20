import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Delivery-address bottom sheet — opened by tapping the "deliver to" row in
/// the home header. Shows the saved address as a single card (this app pins
/// one active delivery address, not a full saved-address list) plus an
/// "Add new address" action that hands off to the pick-on-map flow.
class DeliveryAddressSheetWidget extends StatelessWidget {
  const DeliveryAddressSheetWidget({super.key});

  static void show() {
    showModalBottomSheet(
      isScrollControlled: true,
      useRootNavigator: true,
      context: Get.context!,
      backgroundColor: WaddyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(Dimensions.radiusExtraLarge),
          topRight: Radius.circular(Dimensions.radiusExtraLarge),
        ),
      ),
      builder: (_) => const DeliveryAddressSheetWidget(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final address = AddressHelper.getUserAddressFromSharedPref();
    final String addressLine =
        address?.address ??
        Get.find<LocationController>().displayAddress ??
        'your_location'.tr;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Dimensions.paddingSizeLarge,
          Dimensions.paddingSizeSmall,
          Dimensions.paddingSizeLarge,
          Dimensions.paddingSizeExtraLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(
                  bottom: Dimensions.paddingSizeLarge,
                ),
                decoration: BoxDecoration(
                  color: WaddyColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(
                    Dimensions.radiusExtraSmall,
                  ),
                ),
              ),
            ),
            Text(
              'select_delivery_address'.tr,
              style: waddyBold.copyWith(fontSize: 18, color: WaddyColors.ink),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),

            // Current address card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              decoration: BoxDecoration(
                color: WaddyColors.mintSurface,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                border: Border.all(
                  color: WaddyColors.mintDark.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.near_me_rounded,
                    size: 18,
                    color: WaddyColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'current_location'.tr,
                          style: waddyMedium.copyWith(
                            fontSize: 12,
                            color: WaddyColors.primary.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          addressLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: waddyBold.copyWith(
                            fontSize: 14,
                            color: WaddyColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),

            // Add new address
            GestureDetector(
              onTap: () {
                Get.back();
                Get.toNamed(RouteHelper.getPickMapRoute('home', false));
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
                    color: WaddyColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'add_new_address'.tr,
                    style: waddyBold.copyWith(
                      fontSize: 14,
                      color: WaddyColors.primary,
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
