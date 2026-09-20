import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_asset_image_widget.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';

class ReferBottomSheetWidget extends StatelessWidget {
  const ReferBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.only(top: Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(Dimensions.radiusExtraLarge),
          topRight: Radius.circular(Dimensions.radiusExtraLarge),
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 5,
            width: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
            ),
          ),

          const SizedBox(),

          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeLarge,
                  vertical: Dimensions.paddingSizeDefault,
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(
                        top: Dimensions.paddingSizeExtremeLarge,
                        bottom: Dimensions.paddingSizeExtraLarge,
                      ),
                      child: CustomAssetImageWidget(
                        Images.referBg,
                        height: 120,
                        width: 190,
                      ),
                    ),

                    Text(
                      '${'welcome_to'.tr} ${AppConstants.appName}!',
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),

                    Text(
                      '${'get_ready_for_a_special_welcome_gift_enjoy_a_special_discount_on_your_first_order_within'.tr} ${Get.find<ProfileController>().userInfoModel!.validity} ${'start_exploring_the_best_services_around_you'.tr}',
                      textAlign: TextAlign.center,
                      style: waddyRegular.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyLarge!.color?.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
