import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_asset_image_widget.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class StoreRegistrationSuccessBottomSheet extends StatelessWidget {
  const StoreRegistrationSuccessBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(Dimensions.paddingSizeExtraLarge),
          topRight: Radius.circular(Dimensions.paddingSizeExtraLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(
                top: Dimensions.paddingSizeDefault,
                bottom: Dimensions.paddingSizeDefault,
              ),
              height: 5,
              width: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).highlightColor,
                borderRadius: BorderRadius.circular(
                  Dimensions.radiusExtraSmall,
                ),
              ),
            ),
          ),

          const SizedBox(),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeLarge,
                vertical: Dimensions.paddingSizeSmall,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CustomAssetImageWidget(Images.storeRegistrationSuccess),
                  const SizedBox(height: Dimensions.paddingSizeLarge),

                  Text(
                    '${'welcome_to'.tr} ${AppConstants.appName}!',
                    style: waddyBold.copyWith(
                      fontSize: Dimensions.fontSizeExtraLarge,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeDefault),

                  Text(
                    'thanks_for_joining_us_your_registration_is_under_review_hang_tight_we_ll_notify_you_once_approved'
                        .tr,
                    textAlign: TextAlign.center,
                    style: waddyRegular,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraOverLarge),

                  SafeArea(
                    child: CustomButton(
                      width: 100,
                      buttonText: 'okay'.tr,
                      isBold: false,
                      onPressed: () => Get.back(),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
