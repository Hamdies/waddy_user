import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/item_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';

class AllStoreScreen extends StatefulWidget {
  final bool isPopular;
  final bool isFeatured;
  final bool isNearbyStore;
  final bool isTopOfferStore;
  final bool isRecommendedStore;
  const AllStoreScreen({
    super.key,
    required this.isPopular,
    required this.isFeatured,
    required this.isNearbyStore,
    required this.isTopOfferStore,
    required this.isRecommendedStore,
  });

  @override
  State<AllStoreScreen> createState() => _AllStoreScreenState();
}

class _AllStoreScreenState extends State<AllStoreScreen> {
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    if (widget.isFeatured) {
      Get.find<StoreListController>().getFeaturedStoreList();
    } else if (widget.isPopular) {
      Get.find<StoreListController>().getPopularStoreList(false, 'all', false);
    } else if (widget.isTopOfferStore) {
      Get.find<StoreListController>().getTopOfferStoreList(false, false);
    } else if (widget.isRecommendedStore) {
      Get.find<StoreListController>().getRecommendedStoreList();
    } else {
      Get.find<StoreListController>().getLatestStoreList(false, 'all', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFood = Get.find<SplashController>().module?.type == ModuleType.food;

    return GetBuilder<StoreListController>(
      id: StoreListController.allStoresId,
      builder: (storeController) {
        return Scaffold(
          appBar: CustomAppBar(
            title:
                widget.isFeatured
                    ? 'featured_stores'.tr
                    : widget.isPopular
                    ? Get.find<SplashController>()
                                .configModel
                                .moduleConfig!
                                .module!
                                .showRestaurantText ??
                            false
                        ? widget.isNearbyStore
                            ? 'best_store_nearby'.tr
                            : 'popular_restaurants'.tr
                        : widget.isNearbyStore
                        ? 'best_store_nearby'.tr
                        : 'popular_stores'.tr
                    : widget.isTopOfferStore
                    ? 'top_offers_near_me'.tr
                    : widget.isRecommendedStore
                    ? 'recommended_store'.tr
                    : '${'new_on'.tr} ${AppConstants.appName}',
            type: widget.isFeatured ? null : storeController.type,
            onVegFilterTap:
                widget.isRecommendedStore
                    ? null
                    : (String type) {
                      if (widget.isPopular) {
                        Get.find<StoreListController>().getPopularStoreList(
                          true,
                          type,
                          true,
                        );
                      } else {
                        Get.find<StoreListController>().getLatestStoreList(
                          true,
                          type,
                          true,
                        );
                      }
                    },
          ),
          endDrawer: const MenuDrawer(),
          endDrawerEnableOpenDragGesture: false,
          body: RefreshIndicator(
            onRefresh: () async {
              if (widget.isFeatured) {
                await Get.find<StoreListController>().getFeaturedStoreList();
              } else if (widget.isPopular) {
                await Get.find<StoreListController>().getPopularStoreList(
                  true,
                  Get.find<StoreListController>().type,
                  false,
                );
              } else if (widget.isRecommendedStore) {
                await Get.find<StoreListController>().getRecommendedStoreList();
              } else {
                await Get.find<StoreListController>().getLatestStoreList(
                  true,
                  Get.find<StoreListController>().type,
                  false,
                );
              }
            },
            child: SingleChildScrollView(
              controller: scrollController,
              child: FooterView(
                child: Column(
                  children: [
                    SizedBox(
                      width: Dimensions.maxContentWidth,
                      child: GetBuilder<StoreListController>(
                        id: StoreListController.allStoresId,
                        builder: (storeController) {
                          return ItemsView(
                            isStore: true,
                            items: null,
                            isFeatured: widget.isFeatured,
                            noDataText:
                                widget.isFeatured
                                    ? 'no_store_available'.tr
                                    : Get.find<SplashController>()
                                            .configModel
                                            .moduleConfig!
                                            .module!
                                            .showRestaurantText ??
                                        false
                                    ? 'no_restaurant_available'.tr
                                    : 'no_store_available'.tr,
                            stores:
                                widget.isFeatured
                                    ? storeController.featuredStoreList
                                    : widget.isPopular
                                    ? storeController.popularStoreList
                                    : widget.isTopOfferStore
                                    ? storeController.topOfferStoreList
                                    : widget.isRecommendedStore
                                    ? storeController.recommendedStoreList
                                    : storeController.latestStoreList,
                          );
                        },
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
