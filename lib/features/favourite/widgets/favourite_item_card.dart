import 'package:waddy_app/common/widgets/add_to_cart_control.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/custom_favourite_widget.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';

class FavouriteItemCard extends StatelessWidget {
  final Item item;
  final Store? store;

  const FavouriteItemCard({super.key, required this.item, this.store});

  @override
  Widget build(BuildContext context) {
    final ItemPrice price = ItemPrice.of(item);

    return GestureDetector(
      onTap: () {
        Get.find<ItemController>().navigateToItemPage(item, context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeMedium),
        padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
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
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    color: Colors.grey.shade50,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (price.onSale)
                  PositionedDirectional(
                    top: -4,
                    start: -4,
                    child:
                        OfferCollarBadge.forPrice(
                          price,
                          compact: true,
                          onPhoto: true,
                        )!,
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
                    style: waddyBold.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Store name
                  if (store != null)
                    Text(
                      store!.name ?? '',
                      style: waddyRegular.copyWith(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),

                  PriceTag(price: price),
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
                    bool isWished = favouriteController.wishItemIdList.contains(
                      item.id,
                    );
                    return CustomFavouriteWidget(
                      isWished: isWished,
                      isStore: false,
                      store: null,
                      item: item,
                    );
                  },
                ),
                const SizedBox(height: 36),
                SizedBox(
                  height: Dimensions.minTapTarget,
                  child: AddToCartControl(item: item, inset: 0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
