import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

class PermissionDialogWidget extends StatelessWidget {
  const PermissionDialogWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      insetPadding: const EdgeInsets.all(Dimensions.paddingSizeExtremeLarge),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_location_alt_rounded,
                color: Theme.of(context).primaryColor,
                size: 100,
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),

              Text(
                'location_access_needed'.tr,
                textAlign: TextAlign.center,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeExtraLarge,
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              Text(
                'location_access_needed_desc'.tr,
                textAlign: TextAlign.center,
                style: waddyRegular.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: Theme.of(context).disabledColor,
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),

              // Settings first: granting permission is the outcome we want, and
              // it's the only one that gets an accurate position. Declining is
              // still available and leads to the manual picker.
              CustomButton(
                buttonText: 'go_to_settings'.tr,
                onPressed: () async {
                  await Geolocator.openAppSettings();
                  Get.back();
                },
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(1, 50)),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'dont_allow'.tr,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
