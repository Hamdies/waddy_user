import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_asset_image_widget.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';

class SubscriptionSuccessOrFailedScreen extends StatefulWidget {
  final bool success;
  final bool fromSubscription;
  final int? storeId;
  const SubscriptionSuccessOrFailedScreen({
    super.key,
    required this.success,
    required this.fromSubscription,
    this.storeId,
  });

  @override
  State<SubscriptionSuccessOrFailedScreen> createState() =>
      _SubscriptionSuccessOrFailedScreenState();
}

class _SubscriptionSuccessOrFailedScreenState
    extends State<SubscriptionSuccessOrFailedScreen> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        Get.offAllNamed(RouteHelper.getInitialRoute());
      },
      child: Scaffold(
        appBar: null,
        endDrawer: const MenuDrawer(),
        endDrawerEnableOpenDragGesture: false,

        body: SingleChildScrollView(
          child: FooterView(
            child: Column(
              children: [
                SizedBox(
                  width: Dimensions.maxContentWidth,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 0),

                        Padding(
                          padding: const EdgeInsets.only(
                            left: Dimensions.paddingSizeLarge,
                            right: Dimensions.paddingSizeLarge,
                            top: Dimensions.paddingSizeExtraOverLarge,
                            bottom: Dimensions.paddingSizeLarge,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'vendor_registration'.tr,
                                style: waddyMedium.copyWith(
                                  fontSize: Dimensions.fontSizeLarge,
                                ),
                              ),

                              Text(
                                widget.success
                                    ? 'registration_success'.tr
                                    : 'transaction_failed'.tr,
                                style: waddyRegular.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                              const SizedBox(
                                height: Dimensions.paddingSizeSmall,
                              ),

                              LinearProgressIndicator(
                                backgroundColor:
                                    Theme.of(context).disabledColor,
                                minHeight: 2,
                                value: widget.success ? 1 : 0.75,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: context.height * 0.2),

                        Container(
                          width: Dimensions.maxContentWidth,
                          padding: EdgeInsets.all(0),
                          decoration: null,
                          child: Column(
                            children: [
                              CustomAssetImageWidget(
                                widget.success
                                    ? Images.checkGif
                                    : Images.cancelGif,
                                height: 100,
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Dimensions.paddingSizeLarge,
                                ),
                                child:
                                    widget.success
                                        ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              height:
                                                  Dimensions.paddingSizeSmall,
                                            ),

                                            Text(
                                              '${'congratulations'.tr}!',
                                              style: waddyBold.copyWith(
                                                fontSize:
                                                    Dimensions
                                                        .fontSizeExtraLarge,
                                              ),
                                            ),
                                            const SizedBox(
                                              height:
                                                  Dimensions.paddingSizeSmall,
                                            ),

                                            SizedBox(
                                              width: context.width,
                                              child: RichText(
                                                textAlign: TextAlign.center,
                                                text: TextSpan(
                                                  style: waddyRegular.copyWith(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).hintColor,
                                                    height: 1.7,
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text:
                                                          widget.fromSubscription
                                                              ? '${'subscription_success_message'.tr} '
                                                              : '${'commission_base_success_message'.tr} ',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              height:
                                                  Dimensions
                                                      .paddingSizeExtremeLarge,
                                            ),

                                            TextButton(
                                              onPressed:
                                                  () => Get.offAllNamed(
                                                    RouteHelper.getInitialRoute(),
                                                  ),
                                              child: Text(
                                                'continue_to_home_page'.tr,
                                                style: waddyMedium.copyWith(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                  fontSize:
                                                      Dimensions
                                                          .fontSizeDefault,
                                                  decoration:
                                                      TextDecoration.underline,
                                                  decorationColor:
                                                      Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                        : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              height:
                                                  Dimensions.paddingSizeLarge,
                                            ),

                                            Text(
                                              '${'transaction_failed'.tr}!',
                                              style: waddyBold.copyWith(
                                                fontSize:
                                                    Dimensions
                                                        .fontSizeExtraLarge,
                                              ),
                                            ),
                                            const SizedBox(
                                              height:
                                                  Dimensions.paddingSizeSmall,
                                            ),

                                            SizedBox(
                                              width: context.width,
                                              child: Text(
                                                'sorry_your_transaction_can_not_be_completed_please_choose_another_payment_method_or_try_again'
                                                    .tr,
                                                style: waddyRegular.copyWith(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).hintColor,
                                                  fontSize:
                                                      Dimensions
                                                          .fontSizeDefault,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            const SizedBox(
                                              height:
                                                  Dimensions.paddingSizeDefault,
                                            ),

                                            TextButton(
                                              onPressed: () {
                                                // Get.toNamed(RouteHelper.getBusinessPlanRoute(widget.storeId));
                                              },
                                              child: Text(
                                                'try_again'.tr,
                                                style: waddyMedium.copyWith(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                  fontSize:
                                                      Dimensions
                                                          .fontSizeDefault,
                                                  decoration:
                                                      TextDecoration.underline,
                                                  decorationColor:
                                                      Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
