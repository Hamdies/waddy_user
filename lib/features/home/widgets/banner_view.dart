import 'package:carousel_slider/carousel_slider.dart';
import 'package:sixam_mart/features/banner/controllers/banner_controller.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/item/domain/models/basic_campaign_model.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/common/models/module_model.dart';
import 'package:sixam_mart/features/store/domain/models/store_model.dart';
import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/features/store/screens/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sixam_mart/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';

class BannerView extends StatelessWidget {
  final bool isFeatured;
  final bool showRamadanWrapper;
  const BannerView({super.key, required this.isFeatured, this.showRamadanWrapper = true});

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

          return (bannerList != null && bannerList.isEmpty)
              ? const SizedBox()
              : Container(
                width: MediaQuery.of(context).size.width,
                height:
                    GetPlatform.isDesktop
                        ? 500
                        : MediaQuery.of(context).size.width * 0.38,
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
                              height:
                                  GetPlatform.isDesktop
                                      ? 450
                                      : MediaQuery.of(context).size.width *
                                          0.32,
                              child: CarouselSlider.builder(
                                options: CarouselOptions(
                                  autoPlay: true,
                                  enlargeCenterPage: true,
                                  disableCenter: true,
                                  viewportFraction: 0.85,
                                  aspectRatio: 16 / 9,
                                  autoPlayInterval: const Duration(seconds: 7),
                                  onPageChanged: (index, reason) {
                                    bannerController.setCurrentIndex(
                                      index,
                                      true,
                                    );
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
                                      } else if (bannerDataList[index]
                                          is Store) {
                                        Store? store = bannerDataList[index];
                                        if (isFeatured &&
                                            (AddressHelper.getUserAddressFromSharedPref()!
                                                        .zoneData !=
                                                    null &&
                                                AddressHelper.getUserAddressFromSharedPref()!
                                                    .zoneData!
                                                    .isNotEmpty)) {
                                          for (ModuleModel module
                                              in Get.find<SplashController>()
                                                  .moduleList!) {
                                            if (module.id == store!.moduleId) {
                                              Get.find<SplashController>()
                                                  .setModule(module);
                                              break;
                                            }
                                          }
                                          ZoneData zoneData =
                                              AddressHelper.getUserAddressFromSharedPref()!
                                                  .zoneData!
                                                  .firstWhere(
                                                    (data) =>
                                                        data.id ==
                                                        store!.zoneId,
                                                  );

                                          Modules module = zoneData.modules!
                                              .firstWhere(
                                                (module) =>
                                                    module.id ==
                                                    store!.moduleId,
                                              );
                                          Get.find<SplashController>()
                                              .setModule(
                                                ModuleModel(
                                                  id: module.id,
                                                  moduleName: module.moduleName,
                                                  moduleType: module.moduleType,
                                                  themeId: module.themeId,
                                                  storesCount:
                                                      module.storesCount,
                                                ),
                                              );
                                        }
                                        Get.toNamed(
                                          RouteHelper.getStoreRoute(
                                            id: store!.id,
                                            page:
                                                isFeatured
                                                    ? 'module'
                                                    : 'banner',
                                          ),
                                          arguments: StoreScreen(
                                            store: store,
                                            fromModule: isFeatured,
                                          ),
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
                                            mode:
                                                LaunchMode.externalApplication,
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
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          color:
                                              bannerController.currentIndex ==
                                                      entry.key
                                                  ? Theme.of(
                                                    context,
                                                  ).primaryColor
                                                  : Theme.of(context)
                                                      .primaryColor
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
                        : Shimmer(
                          duration: const Duration(seconds: 2),
                          enabled: bannerList == null,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusSmall,
                              ),
                              color: Colors.grey[300],
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
