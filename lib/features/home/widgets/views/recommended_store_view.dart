import 'package:waddy_app/common/widgets/card_design/store_card_with_distance.dart';
import 'package:waddy_app/common/widgets/section_error_view.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/home/widgets/components/home_rail_shimmers.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/title_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RecommendedStoreView extends StatelessWidget {
  const RecommendedStoreView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.recommendedId,
      builder: (storeController) {
        List<Store>? storeList = storeController.recommendedStoreList;

        // A null list means "no answer yet" — which is the loading state AND the
        // failed state, because nothing sets the list on error. Shimmering
        // forever is the worse of the two readings, so ask the controller which
        // one this is before falling through to the shimmer.
        if (storeList == null) {
          return GetBuilder<HomeController>(
            id: HomeSection.recommended,
            builder: (homeController) {
              if (homeController.hasError(HomeSection.recommended)) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimensions.paddingSizeDefault,
                  ),
                  child: SectionErrorView(
                    onRetry: () => HomeScreen.loadData(true),
                  ),
                );
              }
              return const WebNewOnShimmerView();
            },
          );
        }

        return storeList.isNotEmpty
            ? Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeDefault,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                    ),
                    child: TitleWidget(
                      title: 'recommended_store'.tr,
                      onTap:
                          () => Get.toNamed(
                            RouteHelper.getAllStoreRoute('recommended'),
                          ),
                    ),
                  ),

                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(
                        left: Dimensions.paddingSizeDefault,
                      ),
                      itemCount: storeList.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            right: Dimensions.paddingSizeDefault,
                            bottom: Dimensions.paddingSizeSmall,
                            top: Dimensions.paddingSizeSmall,
                          ),
                          child: StoreCardWithDistance(
                            store: storeList[index],
                            recommendedStore: true,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
            : const SizedBox.shrink();
      },
    );
  }
}
