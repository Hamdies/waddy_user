import 'package:waddy_app/common/models/module_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/item_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';

class PopularItemScreen extends StatefulWidget {
  final bool isPopular;
  final bool isSpecial;
  const PopularItemScreen({
    super.key,
    required this.isPopular,
    required this.isSpecial,
  });

  @override
  State<PopularItemScreen> createState() => _PopularItemScreenState();
}

class _PopularItemScreenState extends State<PopularItemScreen> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    ItemController itemController = Get.find<ItemController>();
    itemController.setOffset(1);
    itemController.clearFilters(
      isPopular: widget.isPopular,
      isSpecial: widget.isSpecial,
    );
    itemController.clearSearch(withUpdate: false);
  }

  @override
  Widget build(BuildContext context) {
    bool isShop =
        Get.find<SplashController>().module?.type == ModuleType.ecommerce;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        Get.find<ItemController>().resetFilters(
          isPopular: widget.isPopular,
          isSpecial: widget.isSpecial,
        );
        Get.find<ItemController>().clearSearch();
      },
      child: GetBuilder<ItemController>(
        builder: (itemController) {
          return Scaffold(
            appBar: CustomAppBar(
              key: scaffoldKey,
              title:
                  widget.isPopular
                      ? isShop
                          ? 'most_popular_products'.tr
                          : 'most_popular_items'.tr
                      : widget.isSpecial
                      ? 'special_offer'.tr
                      : 'best_reviewed_item'.tr,
              showCart: true,
              type:
                  widget.isPopular
                      ? itemController.popularType
                      : widget.isSpecial
                      ? itemController.discountedType
                      : itemController.reviewType,
              onVegFilterTap: (String type) {
                if (widget.isPopular) {
                  itemController.getPopularItemList(notify: true, offset: '1');
                } else if (widget.isSpecial) {
                  itemController.getDiscountedItemList(
                    notify: true,
                    offset: '1',
                  );
                } else {
                  itemController.getReviewedItemList(notify: true, offset: '1');
                }
              },
            ),
            endDrawer: const MenuDrawer(),
            endDrawerEnableOpenDragGesture: false,
            body: SingleChildScrollView(
              child: FooterView(
                child: Column(
                  children: [
                    const SizedBox(),

                    SizedBox(
                      width: Dimensions.maxContentWidth,
                      child: Column(
                        children: [
                          ItemsView(
                            isStore: false,
                            stores: null,
                            items:
                                widget.isPopular
                                    ? itemController.popularItemList
                                    : widget.isSpecial
                                    ? itemController.discountedItemList
                                    : itemController.reviewedItemList,
                          ),

                          if (itemController.hasMoreData(
                            isPopular: widget.isPopular,
                            isSpecial: widget.isSpecial,
                          ))
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: Dimensions.paddingSizeExtraLarge,
                              ),
                              child: CustomButton(
                                buttonText: 'view_more'.tr,
                                width: 180,
                                isLoading: itemController.isLoading,
                                onPressed: () {
                                  itemController.setOffset(
                                    itemController.offset + 1,
                                  );

                                  itemController.showBottomLoader();

                                  if (widget.isPopular) {
                                    itemController.getPopularItemList(
                                      dataSource: DataSourceEnum.client,
                                      offset: itemController.offset.toString(),
                                    );
                                  } else if (widget.isSpecial) {
                                    itemController.getDiscountedItemList(
                                      dataSource: DataSourceEnum.client,
                                      offset: itemController.offset.toString(),
                                    );
                                  } else {
                                    itemController.getReviewedItemList(
                                      dataSource: DataSourceEnum.client,
                                      offset: itemController.offset.toString(),
                                    );
                                  }
                                },
                              ),
                            ),
                        ],
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
