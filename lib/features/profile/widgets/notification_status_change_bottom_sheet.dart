import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_asset_image_widget.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';

class NotificationStatusChangeBottomSheet extends StatelessWidget {
  const NotificationStatusChangeBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500,
      padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(Dimensions.radiusExtraLarge),
          topRight: Radius.circular(Dimensions.radiusExtraLarge),
        ),
      ),
      child: GetBuilder<AuthController>(
        builder: (authController) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  ),
                ),
                const SizedBox(height: 35),

                const CustomAssetImageWidget(
                  Images.warning,
                  height: 50,
                  width: 50,
                ),
                const SizedBox(height: 35),

                Text(
                  'are_you_sure'.tr,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeLarge,
                  ),
                  child: Text(
                    !authController.notification
                        ? 'you_want_to_enable_notification'.tr
                        : 'you_want_to_disable_notification'.tr,
                    style: waddyRegular.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 50),

                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        isLoading: authController.notificationLoading,
                        onPressed: () async {
                          await authController.setNotificationActive(
                            !authController.notification,
                          );
                          Get.back();
                        },
                        buttonText: 'yes'.tr,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),

                    Expanded(
                      child: CustomButton(
                        onPressed: () {
                          Get.back();
                        },
                        buttonText: 'no'.tr,
                        color: Theme.of(
                          context,
                        ).disabledColor.withValues(alpha: 0.5),
                        textColor: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
