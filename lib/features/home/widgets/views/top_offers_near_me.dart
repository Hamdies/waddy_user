import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/card_design/store_card.dart';
import 'package:waddy_app/common/widgets/title_widget.dart';
import 'package:waddy_app/features/home/widgets/components/home_rail_shimmers.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';

class TopOffersNearMe extends StatelessWidget {
  const TopOffersNearMe({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.topOfferId,
      builder: (storeController) {
        List<Store>? storeList = storeController.topOfferStoreList;

        return storeList != null
            ? storeList.isNotEmpty
                ? Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimensions.paddingSizeDefault,
                  ),
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeDefault,
                        ),
                        child: TitleWidget(
                          title: 'top_offers_near_me'.tr,
                          image: Images.fireIcon,
                          onTap:
                              () => Get.toNamed(
                                RouteHelper.getAllStoreRoute('topOffer'),
                              ),
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          controller: ScrollController(),
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(
                            left: Dimensions.paddingSizeSmall,
                          ),
                          itemCount: storeList.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                right: Dimensions.paddingSizeDefault,
                                bottom: Dimensions.paddingSizeSmall,
                                top: Dimensions.paddingSizeSmall,
                              ),
                              child: StoreCard(
                                store: storeList[index],
                                isTopOffers: true,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )
                : const SizedBox.shrink()
            : const WebNewOnShimmerView();
      },
    );
  }
}
