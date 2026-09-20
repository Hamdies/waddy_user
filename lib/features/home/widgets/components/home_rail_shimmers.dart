import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/common/widgets/title_widget.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Loading placeholders for the home rails.
///
/// These three used to live inside `features/home/widgets/web/` alongside the
/// desktop-only rail widgets, but the mobile rails were the ones importing
/// them. When the web widgets were deleted for the Android/iOS-only build the
/// shimmers were the only part still in use, so they were lifted out here.
/// `WebNewOnShimmerView` keeps its name because it is referenced from three
/// call sites; the `Web` prefix is historical, not a platform marker.
class MedicineCardShimmer extends StatelessWidget {
  const MedicineCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: Dimensions.paddingSizeDefault,
              top: Dimensions.paddingSizeDefault,
              right: Dimensions.paddingSizeDefault,
            ),
            child: Shimmer(
              duration: const Duration(seconds: 2),
              enabled: true,
              child: Container(
                width: 180,
                height: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(Dimensions.radiusSmall),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).disabledColor.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(Dimensions.radiusSmall),
                          topRight: Radius.circular(Dimensions.radiusSmall),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeSmall,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 10,
                              width: 100,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).disabledColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: Dimensions.paddingSizeExtraSmall,
                            ),
                            Container(
                              height: 10,
                              width: 50,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).disabledColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: Dimensions.paddingSizeExtraSmall,
                            ),
                            Container(
                              height: 10,
                              width: 80,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).disabledColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
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
          );
        },
      ),
    );
  }
}

class PopularStoreShimmer extends StatelessWidget {
  const PopularStoreShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(
            right: Dimensions.paddingSizeDefault,
            bottom: Dimensions.paddingSizeExtraSmall,
          ),
          child: Shimmer(
            duration: const Duration(seconds: 2),
            enabled: true,
            child: Container(
              width: 260,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 170,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        width: double.infinity,
                        height: 87,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(
                            Dimensions.paddingSizeSmall,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    height: 40,
                                    width: 40,
                                    color: Colors.grey[300],
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: Dimensions.paddingSizeDefault,
                              ),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      height: 5,
                                      width: 100,
                                      color: Colors.grey[300],
                                    ),

                                    Container(
                                      height: 5,
                                      width: 100,
                                      color: Colors.grey[300],
                                    ),

                                    Container(
                                      height: 5,
                                      width: 100,
                                      color: Colors.grey[300],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WebNewOnShimmerView extends StatelessWidget {
  final bool fromAllStore;
  final bool? isFood;
  const WebNewOnShimmerView({
    super.key,
    this.fromAllStore = false,
    this.isFood = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        isFood!
            ? Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeDefault,
              ),
              child: TitleWidget(
                title:
                    isFood!
                        ? 'best_store_nearby'.tr
                        : '${'new_on'.tr} ${AppConstants.appName}',
                onTap:
                    () => Get.toNamed(
                      RouteHelper.getAllStoreRoute(
                        'latest',
                        isNearbyStore: isFood! ? true : false,
                      ),
                    ),
              ),
            )
            : const SizedBox(),

        Shimmer(
          duration: const Duration(seconds: 2),
          enabled: true,
          child: SizedBox(
            height: 215,
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: fromAllStore ? Axis.vertical : Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: Dimensions.paddingSizeDefault,
                    top: Dimensions.paddingSizeDefault,
                    left:
                        Get.find<LocalizationController>().isLtr
                            ? 0
                            : Dimensions.paddingSizeDefault,
                    right:
                        Get.find<LocalizationController>().isLtr
                            ? Dimensions.paddingSizeDefault
                            : 0,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        width: 260,
                        decoration: BoxDecoration(
                          color: Theme.of(context).shadowColor,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              flex: 1,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                  topRight: Radius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      height: double.infinity,
                                      width: double.infinity,
                                      color: Theme.of(context).shadowColor,
                                    ),

                                    Positioned(
                                      top: 15,
                                      right: 15,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Theme.of(
                                            context,
                                          ).cardColor.withValues(alpha: 0.8),
                                        ),
                                        child: Icon(
                                          Icons.favorite_border,
                                          color: Theme.of(context).shadowColor,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 95),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 5,
                                              width: 100,
                                              color:
                                                  Theme.of(context).cardColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),

                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on_outlined,
                                                color:
                                                    Theme.of(context).cardColor,
                                                size: 15,
                                              ),
                                              const SizedBox(
                                                width:
                                                    Dimensions
                                                        .paddingSizeExtraSmall,
                                              ),
                                              Expanded(
                                                child: Container(
                                                  height: 10,
                                                  width: 100,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).cardColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    flex: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal:
                                            Dimensions.paddingSizeDefault,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            height: 10,
                                            width: 70,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 3,
                                              horizontal:
                                                  Dimensions.paddingSizeSmall,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  Theme.of(context).cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusLarge,
                                                  ),
                                            ),
                                          ),

                                          Container(
                                            height: 20,
                                            width: 65,
                                            decoration: BoxDecoration(
                                              color:
                                                  Theme.of(context).cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusSmall,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        top: 60,
                        left: 15,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 65,
                              width: 65,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
