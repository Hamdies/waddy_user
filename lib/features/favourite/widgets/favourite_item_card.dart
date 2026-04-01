import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/features/favourite/controllers/favourite_controller.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/common/widgets/custom_favourite_widget.dart';
import 'package:sixam_mart/features/store/domain/models/store_model.dart';
import 'package:sixam_mart/features/store/screens/store_screen.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/styles.dart';

class FavouriteItemCard extends StatelessWidget {
  final Item item;
  final Store? store;

  const FavouriteItemCard({
    super.key,
    required this.item,
    this.store,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasDiscount = item.discount != null && item.discount! > 0 && item.discountType != null;
    final double originalPrice = item.price ?? 0;
    final String formattedPrice = PriceConverter.convertPrice(
      originalPrice,
      discount: item.discount,
      discountType: item.discountType,
    );
    final String originalFormatted = PriceConverter.convertPrice(originalPrice);

    return GestureDetector(
      onTap: () {
        Get.find<ItemController>().navigateToItemPage(item, context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ─── Square image with discount badge ───
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Discount tag
                if (hasDiscount)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.discount}${item.discountType == 'percent' ? '%' : 'LE'} OFF',
                        style: robotoBold.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // ─── Info column ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Item name
                  Text(
                    item.name ?? '',
                    style: robotoBold.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Store name
                  if (store != null)
                    Text(
                      store!.name ?? '',
                      style: robotoRegular.copyWith(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),

                  // Price
                  Row(
                    children: [
                      Text(
                        formattedPrice,
                        style: robotoBold.copyWith(
                          fontSize: 13,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text(
                          originalFormatted,
                          style: robotoRegular.copyWith(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ─── Favorite + Add buttons ───
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                GetBuilder<FavouriteController>(
                  builder: (favouriteController) {
                    bool isWished = favouriteController.wishItemIdList.contains(item.id);
                    return CustomFavouriteWidget(
                      isWished: isWished,
                      isStore: false,
                      store: null,
                      item: item,
                    );
                  },
                ),
                const SizedBox(height: 50),
                GestureDetector(
                  onTap: () {
                    Get.find<ItemController>().navigateToItemPage(item, context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
