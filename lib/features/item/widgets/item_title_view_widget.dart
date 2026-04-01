import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_asset_image_widget.dart';
import 'package:sixam_mart/common/widgets/custom_tool_tip_widget.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/favourite/controllers/favourite_controller.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/organic_tag.dart';
import 'package:sixam_mart/common/widgets/rating_bar.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';

class ItemTitleViewWidget extends StatelessWidget {
  final Item? item;
  final bool inStorePage;
  final bool isCampaign;
  final bool inStock;
  const ItemTitleViewWidget({
    super.key,
    required this.item,
    this.inStorePage = false,
    this.isCampaign = false,
    required this.inStock,
  });

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print(inStock ? 'out_of_stock'.tr : 'in_stock'.tr);
    }
    double? startingPrice;
    double? endingPrice;
    if (item!.variations!.isNotEmpty) {
      List<double?> priceList = [];
      for (var variation in item!.variations!) {
        priceList.add(variation.price);
      }
      priceList.sort((a, b) => a!.compareTo(b!));
      startingPrice = priceList[0];
      if (priceList[0]! < priceList[priceList.length - 1]!) {
        endingPrice = priceList[priceList.length - 1];
      }
    } else {
      startingPrice = item!.price;
    }

    double? discount = Get.find<ItemController>().item!.discount;
    String? discountType = Get.find<ItemController>().item!.discountType;

    return ResponsiveHelper.isDesktop(context)
        ? GetBuilder<ItemController>(
          builder: (itemController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              item?.name ?? '',
                              style: robotoMedium.copyWith(
                                fontSize: Dimensions.fontSizeOverLarge,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width:
                                item!.isStoreHalalActive! && item!.isHalalItem!
                                    ? Dimensions.paddingSizeSmall
                                    : 0,
                          ),

                          item!.isStoreHalalActive! && item!.isHalalItem!
                              ? CustomToolTip(
                                message: 'this_is_a_halal_food'.tr,
                                preferredDirection: AxisDirection.up,
                                child: const CustomAssetImageWidget(
                                  Images.halalTag,
                                  height: 35,
                                  width: 35,
                                ),
                              )
                              : const SizedBox(),

                          const SizedBox(
                            width: Dimensions.paddingSizeExtraSmall,
                          ),

                          ((Get.find<SplashController>()
                                          .configModel!
                                          .moduleConfig!
                                          .module!
                                          .unit! &&
                                      item!.unitType != null) ||
                                  (Get.find<SplashController>()
                                          .configModel!
                                          .moduleConfig!
                                          .module!
                                          .vegNonVeg! &&
                                      Get.find<SplashController>()
                                          .configModel!
                                          .toggleVegNonVeg!))
                              ? Text(
                                Get.find<SplashController>()
                                        .configModel!
                                        .moduleConfig!
                                        .module!
                                        .unit!
                                    ? '(${item!.unitType})'
                                    : item!.veg == 0
                                    ? '(${'non_veg'.tr})'
                                    : '(${'veg'.tr})',
                                style: robotoRegular.copyWith(
                                  fontSize: Dimensions.fontSizeExtraSmall,
                                  color: Theme.of(context).disabledColor,
                                ),
                              )
                              : const SizedBox(),
                        ],
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),

                    item!.availableTimeStarts != null
                        ? const SizedBox()
                        : Container(
                          padding: const EdgeInsets.all(8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                          ),
                          child: GetBuilder<FavouriteController>(
                            builder: (favouriteController) {
                              return InkWell(
                                onTap: () {
                                  if (AuthHelper.isLoggedIn()) {
                                    if (favouriteController.wishItemIdList
                                        .contains(itemController.item!.id)) {
                                      favouriteController
                                          .removeFromFavouriteList(
                                            itemController.item!.id,
                                            false,
                                          );
                                    } else {
                                      favouriteController.addToFavouriteList(
                                        itemController.item,
                                        null,
                                        false,
                                      );
                                    }
                                  } else {
                                    showCustomSnackBar(
                                      'you_are_not_logged_in'.tr,
                                    );
                                  }
                                },
                                child: Icon(
                                  favouriteController.wishItemIdList.contains(
                                        itemController.item!.id,
                                      )
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 25,
                                  color: Theme.of(context).primaryColor,
                                ),
                              );
                            },
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                (itemController.item!.genericName != null &&
                        itemController.item!.genericName!.isNotEmpty)
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          children: List.generate(
                            itemController.item!.genericName!.length,
                            (index) {
                              return Text(
                                '${itemController.item!.genericName![index]}${itemController.item!.genericName!.length - 1 == index ? '.' : ', '}',
                                style: robotoRegular.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .color
                                      ?.withValues(alpha: 0.5),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeLarge),
                      ],
                    )
                    : const SizedBox(),
                SizedBox(
                  height:
                      (itemController.item!.genericName != null &&
                              itemController.item!.genericName!.isNotEmpty)
                          ? Dimensions.paddingSizeSmall
                          : 0,
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeExtraSmall,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            inStock ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                      ),
                      child: Text(
                        inStock ? 'out_of_stock'.tr : 'in_stock'.tr,
                        style: robotoRegular.copyWith(
                          color: Theme.of(context).disabledColor,
                          fontSize: Dimensions.fontSizeOverSmall,
                        ),
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeDefault),

                    OrganicTag(item: item!, fromDetails: true),
                  ],
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                InkWell(
                  onTap: () {
                    if (inStorePage) {
                      Get.back();
                    } else {
                      Get.offNamed(
                        RouteHelper.getStoreRoute(
                          id: item!.storeId,
                          page: 'item',
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 5, 5, 5),
                    child: Text(
                      item?.storeName ?? '',
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ),
                ),

                if (item!.ratingCount! > 0)
                  RatingBar(
                    rating: item!.avgRating,
                    ratingCount: item!.ratingCount,
                    size: 15,
                  ),
                SizedBox(
                  height:
                      item!.ratingCount! > 0
                          ? Dimensions.paddingSizeExtraSmall
                          : 0,
                ),

                Row(
                  children: [
                    discount! > 0
                        ? Flexible(
                          child: Text(
                            '${PriceConverter.convertPrice(startingPrice)}'
                            '${endingPrice != null ? ' - ${PriceConverter.convertPrice(endingPrice)}' : ''}',
                            textDirection: TextDirection.ltr,
                            style: robotoRegular.copyWith(
                              color: Theme.of(context).disabledColor,
                              decoration: TextDecoration.lineThrough,
                              fontSize: Dimensions.fontSizeExtraSmall,
                            ),
                          ),
                        )
                        : const SizedBox(),
                    SizedBox(width: discount > 0 ? 10 : 0),

                    Text(
                      '${PriceConverter.convertPrice(startingPrice, discount: discount, discountType: discountType)}'
                      '${endingPrice != null ? ' - ${PriceConverter.convertPrice(endingPrice, discount: discount, discountType: discountType)}' : ''}',
                      style: robotoBold.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ],
            );
          },
        )
        : Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          transform: Matrix4.translationValues(0, -16, 0),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: GetBuilder<ItemController>(
            builder: (itemController) {

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Organic tag row (tags moved to image as stickers)
                  if (item!.organic == 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OrganicTag(item: item!, fromDetails: true),
                    ),

                  // Product name + price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Expanded(
                        child: Text(
                          item?.name ?? '',
                          style: robotoBlack.copyWith(
                            fontSize: 19,
                            color: const Color(0xFF1A1A2E),
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Price chip + old price below
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Theme.of(context).secondaryHeaderColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              PriceConverter.convertPrice(startingPrice, discount: discount, discountType: discountType),
                              style: robotoBlack.copyWith(
                                color: Theme.of(context).primaryColor,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                          if (discount != null && discount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                PriceConverter.convertPrice(startingPrice),
                                textDirection: TextDirection.ltr,
                                style: robotoMedium.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: Dimensions.fontSizeDefault,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          Builder(builder: (context) {
                            final xpConfig = Get.find<XpController>().xpConfig;
                            if (xpConfig == null || !xpConfig.levelingEnabled) return const SizedBox.shrink();
                            final multiplier = xpConfig.multipliers[item!.moduleType] ?? 1.0;
                            final xp = item!.getDisplayXp(multiplier: multiplier);
                            if (xp <= 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.shade300, width: 0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, size: 12, color: Colors.amber.shade700),
                                    const SizedBox(width: 3),
                                    Text(
                                      '+$xp XP',
                                      style: robotoMedium.copyWith(fontSize: 11, color: Colors.amber.shade800),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),

                  // Description - directly under title
                  if (item!.description != null && item!.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        item!.description!,
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Colors.grey.shade400,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Store chip + unit type row
                  Row(
                    children: [
                      if (item!.storeName != null && item!.storeName!.isNotEmpty)
                        InkWell(
                          onTap: () {
                            if (inStorePage) {
                              Get.back();
                            } else {
                              Get.offNamed(
                                RouteHelper.getStoreRoute(
                                  id: item!.storeId,
                                  page: 'item',
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Store logo image
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Builder(
                                      builder: (context) {
                                        final logoUrl = Get.find<ItemController>().storeLogoUrl;
                                        if (logoUrl != null && logoUrl.isNotEmpty) {
                                          return CustomImage(
                                            image: logoUrl,
                                            fit: BoxFit.cover,
                                            width: 28,
                                            height: 28,
                                          );
                                        }
                                        return Center(
                                          child: Text(
                                            item!.storeName![0].toUpperCase(),
                                            style: robotoBold.copyWith(
                                              fontSize: 13,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item!.storeName!,
                                  style: robotoMedium.copyWith(
                                    fontSize: Dimensions.fontSizeSmall,
                                    color: const Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ),

                    
                    ],
                  ),

                  // Rating
                  if (item!.ratingCount! > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFA000)),
                              const SizedBox(width: 3),
                              Text(
                                item!.avgRating!.toStringAsFixed(1),
                                style: robotoBold.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                  color: const Color(0xFFF57C00),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${item!.ratingCount} ${'ratings'.tr})',
                          style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeExtraSmall,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],

                ],
              );
            },
          ),
        );
  }
}
