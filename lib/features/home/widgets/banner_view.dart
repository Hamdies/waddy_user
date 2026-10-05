import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/common/models/image_variants.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:waddy_app/features/banner/controllers/banner_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/item/domain/models/basic_campaign_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';

class BannerView extends StatelessWidget {
  final bool isFeatured;
  final bool showRamadanWrapper;
  const BannerView({
    super.key,
    required this.isFeatured,
    this.showRamadanWrapper = true,
  });

  @override
  Widget build(BuildContext context) {
    final bannerContent = GetBuilder<BannerController>(
      builder: (bannerController) {
        List<String?>? bannerList =
            isFeatured
                ? bannerController.featuredBannerList
                : bannerController.bannerImageList;
        List<dynamic>? bannerDataList =
            isFeatured
                ? bannerController.featuredBannerDataList
                : bannerController.bannerDataList;
        // Featured banners are not flattened with a variants list yet, so
        // they keep the original URL — null here is the correct fallback, not
        // a missing case.
        final List<ImageVariants?>? bannerVariants =
            isFeatured ? null : bannerController.bannerVariantsList;

        return (bannerList != null && bannerList.isEmpty)
            ? const SizedBox()
            : Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width * 0.38,
              padding: const EdgeInsets.only(
                top: Dimensions.paddingSizeExtraSmall,
              ),
              child:
                  bannerList != null
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.width * 0.32,
                            child: CarouselSlider.builder(
                              options: CarouselOptions(
                                autoPlay: true,
                                enlargeCenterPage: true,
                                disableCenter: true,
                                viewportFraction: 0.85,
                                aspectRatio: 16 / 9,
                                autoPlayInterval: const Duration(seconds: 7),
                                onPageChanged: (index, reason) {
                                  bannerController.setCurrentIndex(index, true);
                                },
                              ),
                              itemCount:
                                  bannerList.isEmpty ? 1 : bannerList.length,
                              itemBuilder: (context, index, _) {
                                return InkWell(
                                  onTap: () async {
                                    if (bannerDataList![index] is Item) {
                                      Item? item = bannerDataList[index];
                                      Get.find<ItemController>()
                                          .navigateToItemPage(item, context);
                                    } else if (bannerDataList[index] is Store) {
                                      Store? store = bannerDataList[index];
                                      // A featured banner opens the store
                                      // in its own module. Unresolvable ids
                                      // (a banner pointing outside the
                                      // saved address's zone) skip the
                                      // switch rather than crash — which is
                                      // what the zone-data lookup that used
                                      // to sit here was for. It resolved the
                                      // same module a second time out of
                                      // `zoneData`, set it again, and could
                                      // hand the app a module that is not in
                                      // `moduleList` at all.
                                      StoreNavigator.open(
                                        store!,
                                        page: isFeatured ? 'module' : 'banner',
                                      );
                                    } else if (bannerDataList[index]
                                        is BasicCampaignModel) {
                                      BasicCampaignModel campaign =
                                          bannerDataList[index];
                                      Get.toNamed(
                                        RouteHelper.getBasicCampaignRoute(
                                          campaign,
                                        ),
                                      );
                                    } else {
                                      String url = bannerDataList[index];
                                      if (await canLaunchUrlString(url)) {
                                        await launchUrlString(
                                          url,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      } else {
                                        showCustomSnackBar(
                                          'unable_to_found_url'.tr,
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 5,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      vertical:
                                          Dimensions.paddingSizeExtraSmall,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      child: GetBuilder<SplashController>(
                                        builder: (splashController) {
                                          return CustomImage(
                                            image: '${bannerList[index]}',
                                            fit: BoxFit.fill,
                                            // Guarded on length: the two
                                            // lists are built together, but
                                            // a partially-rebuilt controller
                                            // must not throw inside a
                                            // carousel builder.
                                            variants:
                                                (bannerVariants != null &&
                                                        index <
                                                            bannerVariants
                                                                .length)
                                                    ? bannerVariants[index]
                                                    : null,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(
                            height: Dimensions.paddingSizeExtraSmall,
                          ),

                          // Carousel Indicators
                          if (bannerList.length > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children:
                                  bannerList.asMap().entries.map((entry) {
                                    return Container(
                                      width:
                                          bannerController.currentIndex ==
                                                  entry.key
                                              ? 20
                                              : 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color:
                                            bannerController.currentIndex ==
                                                    entry.key
                                                ? Theme.of(context).primaryColor
                                                : Theme.of(context).primaryColor
                                                    .withValues(alpha: 0.3),
                                      ),
                                    );
                                  }).toList(),
                            ),

                          const SizedBox(
                            height: Dimensions.paddingSizeExtraSmall,
                          ),
                        ],
                      )
                      // Shaped like the carousel it stands in for: the
                      // 85% centre slide, its neighbours peeking either side.
                      : Shimmer(
                        duration: const Duration(seconds: 2),
                        enabled: bannerList == null,
                        child: SizedBox(
                          height: MediaQuery.of(context).size.width * 0.32,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double slide = constraints.maxWidth * 0.85;
                              final double peek =
                                  (constraints.maxWidth - slide) / 2 - 8;
                              Widget block(double width, double inset) =>
                                  Container(
                                    width: width,
                                    margin: EdgeInsets.symmetric(
                                      vertical: inset,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      color: WaddyColors.divider,
                                    ),
                                  );
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  block(peek, 14),
                                  block(slide, 4),
                                  block(peek, 14),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
            );
      },
    );

    return showRamadanWrapper
        ? RamadanStringLightWrapper(
          position: WrapperPosition.top,
          showTopString: true,
          showBottomString: false,
          showLeftConnector: false,
          showRightConnector: false,
          child: bannerContent,
        )
        : bannerContent;
  }
}
