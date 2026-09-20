import 'package:waddy_app/common/widgets/cart_count_view.dart';
import 'package:waddy_app/common/widgets/corner_banner/banner.dart';
import 'package:waddy_app/common/widgets/corner_banner/corner_discount_tag.dart';
import 'package:waddy_app/common/widgets/custom_asset_image_widget.dart';
import 'package:waddy_app/common/widgets/custom_favourite_widget.dart';
import 'package:waddy_app/common/widgets/custom_ink_well.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/discount_tag.dart';
import 'package:waddy_app/common/widgets/not_available_widget.dart';
import 'package:waddy_app/common/widgets/organic_tag.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ItemWidget extends StatelessWidget {
  final Item? item;
  final Store? store;
  final bool isStore;
  final int index;
  final int? length;
  final bool inStore;
  final bool isCampaign;
  final bool isFeatured;
  final bool fromCartSuggestion;
  final double? imageHeight;
  final double? imageWidth;
  final bool? isCornerTag;
  const ItemWidget({
    super.key,
    required this.item,
    required this.isStore,
    required this.store,
    required this.index,
    required this.length,
    this.inStore = false,
    this.isCampaign = false,
    this.isFeatured = false,
    this.fromCartSuggestion = false,
    this.imageHeight,
    this.imageWidth,
    this.isCornerTag = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool ltr = Get.find<LocalizationController>().isLtr;
    double? discount;
    String? discountType;
    bool isAvailable;
    String genericName = '';

    if (!isStore &&
        item!.genericName != null &&
        item!.genericName!.isNotEmpty) {
      for (String name in item!.genericName!) {
        genericName += name;
      }
    }
    if (isStore) {
      discount = store!.discount != null ? store!.discount!.discount : 0;
      discountType =
          store!.discount != null ? store!.discount!.discountType : 'percent';
      isAvailable = store!.open == 1 && store!.active!;
    } else {
      discount = item!.discount;
      discountType = item!.discountType;
      isAvailable = DateConverter.isAvailable(
        item!.availableTimeStarts,
        item!.availableTimeEnds,
      );
    }

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            color: Theme.of(context).cardColor,
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1),
            ],
          ),
          child: CustomInkWell(
            onTap: () {
              if (isStore) {
                if (store != null) {
                  if (isFeatured) {
                    Get.find<SplashController>().activateModuleFor(
                      store!.moduleId,
                    );
                  }
                  Get.toNamed(
                    RouteHelper.getStoreRoute(
                      id: store!.id,
                      page: isFeatured ? 'module' : 'item',
                    ),
                    arguments: StoreScreen(
                      store: store,
                      fromModule: isFeatured,
                    ),
                  );
                }
              } else {
                if (isFeatured) {
                  Get.find<SplashController>().activateModuleFor(
                    item!.moduleId,
                  );
                }
                Get.find<ItemController>().navigateToItemPage(
                  item,
                  context,
                  inStore: inStore,
                  isCampaign: isCampaign,
                );
              }
            },
            radius: Dimensions.radiusDefault,
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeSmall,
              vertical: Dimensions.paddingSizeExtraSmall,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: Dimensions.paddingSizeExtraSmall,
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusDefault,
                              ),
                              child: CustomImage(
                                image:
                                    '${isStore
                                        ? store != null
                                            ? store!.logoFullUrl
                                            : ''
                                        : item!.imageFullUrl}',
                                height:
                                    imageHeight ?? (length == null ? 100 : 90),
                                width: imageWidth ?? (90),
                                fit: BoxFit.cover,
                                variants:
                                    isStore
                                        ? store?.logoVariants
                                        : item?.imageVariants,
                              ),
                            ),

                            (isStore || isCornerTag!)
                                ? DiscountTag(
                                  discount: discount,
                                  discountType: discountType,
                                  freeDelivery:
                                      isStore ? store!.freeDelivery : false,
                                )
                                : const SizedBox(),

                            !isStore
                                ? OrganicTag(item: item!, placeInImage: true)
                                : const SizedBox(),

                            isAvailable
                                ? const SizedBox()
                                : NotAvailableWidget(isStore: isStore),

                            Positioned(
                              top: 5,
                              left: 5,
                              child: GetBuilder<FavouriteController>(
                                builder: (favouriteController) {
                                  bool isWished =
                                      isStore
                                          ? favouriteController.wishStoreIdList
                                              .contains(store!.id)
                                          : favouriteController.wishItemIdList
                                              .contains(item!.id);
                                  return CustomFavouriteWidget(
                                    isWished: isWished,
                                    isStore: isStore,
                                    store: store,
                                    item: item,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      isStore ? store!.name! : item!.name!,
                                      style: waddyMedium.copyWith(
                                        fontSize: Dimensions.fontSizeSmall,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: Dimensions.paddingSizeExtraSmall,
                                  ),

                                  (!isStore &&
                                          Get.find<SplashController>()
                                              .configModel
                                              .moduleConfig!
                                              .module!
                                              .vegNonVeg! &&
                                          Get.find<SplashController>()
                                              .configModel
                                              .toggleVegNonVeg!)
                                      ? Image.asset(
                                        item != null && item!.veg == 0
                                            ? Images.nonVegImage
                                            : Images.vegImage,
                                        height: 10,
                                        width: 10,
                                        fit: BoxFit.contain,
                                      )
                                      : const SizedBox(),

                                  (Get.find<SplashController>()
                                              .configModel
                                              .moduleConfig!
                                              .module!
                                              .unit! &&
                                          item != null &&
                                          item!.unitType != null)
                                      ? Text(
                                        '(${item!.unitType ?? ''})',
                                        style: waddyRegular.copyWith(
                                          fontSize:
                                              Dimensions.fontSizeExtraSmall,
                                          color: Theme.of(context).hintColor,
                                        ),
                                      )
                                      : const SizedBox(),

                                  SizedBox(
                                    width:
                                        item!.isStoreHalalActive! &&
                                                item!.isHalalItem!
                                            ? Dimensions.paddingSizeExtraSmall
                                            : 0,
                                  ),

                                  !isStore &&
                                          item!.isStoreHalalActive! &&
                                          item!.isHalalItem!
                                      ? const CustomAssetImageWidget(
                                        Images.halalTag,
                                        height: 13,
                                        width: 13,
                                      )
                                      : const SizedBox(),

                                  SizedBox(width: 0),
                                ],
                              ),
                              const SizedBox(height: 3),

                              inStore
                                  ? const SizedBox()
                                  : (isStore
                                      ? store!.address != null
                                      : item!.storeName != null)
                                  ? Text(
                                    isStore
                                        ? store!.address ?? ''
                                        : item!.storeName ?? '',
                                    style: waddyRegular.copyWith(
                                      fontSize: Dimensions.fontSizeExtraSmall,
                                      color: Theme.of(context).disabledColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                  : const SizedBox(),

                              (genericName.isNotEmpty)
                                  ? Flexible(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: Dimensions.paddingSizeExtraSmall,
                                      ),
                                      child: Text(
                                        genericName,
                                        style: waddyMedium.copyWith(
                                          fontSize: Dimensions.fontSizeSmall,
                                          color:
                                              Theme.of(context).disabledColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  : const SizedBox(),
                              SizedBox(
                                height:
                                    ((isStore) &&
                                            (isStore
                                                ? store!.address != null
                                                : item!.storeName != null))
                                        ? 3
                                        : 3,
                              ),

                              !isStore && (item!.ratingCount! > 0)
                                  ? Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      const SizedBox(
                                        width: Dimensions.paddingSizeExtraSmall,
                                      ),

                                      Text(
                                        item!.avgRating!.toStringAsFixed(1),
                                        style: waddyMedium.copyWith(
                                          fontSize: Dimensions.fontSizeSmall,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: Dimensions.paddingSizeExtraSmall,
                                      ),

                                      Text(
                                        '(${item!.ratingCount})',
                                        style: waddyRegular.copyWith(
                                          fontSize: Dimensions.fontSizeSmall,
                                          color: Theme.of(context).hintColor,
                                        ),
                                      ),
                                    ],
                                  )
                                  : const SizedBox(),

                              SizedBox(
                                height:
                                    (!isStore && (item!.ratingCount! > 0))
                                        ? 3
                                        : 0,
                              ),

                              isStore &&
                                      (store != null && store!.ratingCount! > 0)
                                  ? Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      const SizedBox(
                                        width: Dimensions.paddingSizeExtraSmall,
                                      ),

                                      Text(
                                        store!.avgRating!.toStringAsFixed(1),
                                        style: waddyMedium,
                                      ),
                                      const SizedBox(
                                        width: Dimensions.paddingSizeExtraSmall,
                                      ),

                                      Text(
                                        '(${store!.ratingCount})',
                                        style: waddyRegular.copyWith(
                                          fontSize: Dimensions.fontSizeSmall,
                                          color: Theme.of(context).hintColor,
                                        ),
                                      ),
                                    ],
                                  )
                                  : Row(
                                    children: [
                                      Text(
                                        PriceConverter.convertPrice(
                                          item!.price,
                                          discount: discount,
                                          discountType: discountType,
                                        ),
                                        style: waddyMedium.copyWith(
                                          fontSize: Dimensions.fontSizeSmall,
                                        ),
                                        textDirection: TextDirection.ltr,
                                      ),
                                      SizedBox(
                                        width:
                                            discount! > 0
                                                ? Dimensions
                                                    .paddingSizeExtraSmall
                                                : 0,
                                      ),

                                      discount > 0
                                          ? Text(
                                            PriceConverter.convertPrice(
                                              item!.price,
                                            ),
                                            style: waddyMedium.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeExtraSmall,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).disabledColor,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                            textDirection: TextDirection.ltr,
                                          )
                                          : const SizedBox(),
                                    ],
                                  ),
                            ],
                          ),
                        ),

                        Column(
                          mainAxisAlignment:
                              isStore
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(),

                            CartCountView(item: item!, index: index),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        (!isStore && isCornerTag! == false)
            ? Positioned(
              right: ltr ? 0 : null,
              left: ltr ? null : 0,
              child: CornerDiscountTag(
                bannerPosition:
                    ltr
                        ? CornerBannerPosition.topRight
                        : CornerBannerPosition.topLeft,
                elevation: 0,
                discount: discount,
                discountType: discountType,
                freeDelivery: isStore ? store!.freeDelivery : false,
              ),
            )
            : const SizedBox(),
      ],
    );
  }
}
