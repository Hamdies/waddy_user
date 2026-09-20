import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/organic_tag.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';

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

    return Container(
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
                  padding: const EdgeInsets.only(
                    bottom: Dimensions.paddingSizeSmall,
                  ),
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
                      style: waddyBlack.copyWith(
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeSmall,
                          vertical: Dimensions.paddingSizeExtraSmall,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).secondaryHeaderColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                        ),
                        child: Text(
                          PriceConverter.convertPrice(
                            startingPrice,
                            discount: discount,
                            discountType: discountType,
                          ),
                          style: waddyBlack.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontSize: 18,
                            letterSpacing: -0.5,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                      if (discount != null && discount > 0)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: Dimensions.paddingSizeExtraSmall,
                          ),
                          child: Text(
                            PriceConverter.convertPrice(startingPrice),
                            textDirection: TextDirection.ltr,
                            style: waddyMedium.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: Dimensions.fontSizeDefault,
                              decoration: TextDecoration.lineThrough,
                              decorationColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      Builder(
                        builder: (context) {
                          final xpConfig = Get.find<XpController>().xpConfig;
                          if (xpConfig == null || !xpConfig.levelingEnabled)
                            return const SizedBox.shrink();
                          final multiplier =
                              xpConfig.multipliers[item!.moduleType] ?? 1.0;
                          final xp = item!.getDisplayXp(multiplier: multiplier);
                          if (xp <= 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Dimensions.paddingSizeSmall,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                                border: Border.all(
                                  color: Colors.amber.shade300,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 12,
                                    color: Colors.amber.shade700,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '+$xp XP',
                                    style: waddyMedium.copyWith(
                                      fontSize: 11,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
                    style: waddyRegular.copyWith(
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
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).secondaryHeaderColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
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
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.12),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final logoUrl =
                                        Get.find<ItemController>().storeLogoUrl;
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
                                        style: waddyBold.copyWith(
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
                              style: waddyMedium.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: const Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.5),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFFFA000),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item!.avgRating!.toStringAsFixed(1),
                            style: waddyBold.copyWith(
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
                      style: waddyRegular.copyWith(
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
