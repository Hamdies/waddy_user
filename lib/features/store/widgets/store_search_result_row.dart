import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/add_to_cart_control.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/helpers/pack_size.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// A product row for the in-store search, from the Mart Search design.
///
/// ```
///   ┌────────────────────────────────┐
///   │ ┌──────┐  Heinz Ketchup        │   name, two lines, size cut off the end…
///   │ │ photo│  125 g                │   …and shown on its own line
///   │ └──────┘  EGP 22  EGP 30   [+] │   price, struck was-price, add control
///   └────────────────────────────────┘
/// ```
///
/// This replaces the shared `ItemWidget` here. That card truncated every name
/// to one line ("Smoked Turkey Breast 2…"), never showed the size, wore a
/// favourite heart over the photo, and let the add button float mid-card.
/// Favouriting stays on the item page.
class StoreSearchResultRow extends StatelessWidget {
  final Item item;

  /// Opens the item's page from the search (a store page is underneath it).
  final bool inStore;

  const StoreSearchResultRow({
    super.key,
    required this.item,
    this.inStore = true,
  });

  static const double _photo = 84;
  static const Color _border = Color(0xFFD4F0E8);
  static const Color _photoGround = Color(0xFFF1FBF7);

  @override
  Widget build(BuildContext context) {
    final ItemPrice price = ItemPrice.of(item);
    final bool soldOut = item.stock != null && item.stock! <= 0;
    final PackSize pack = PackSize.of(item.name);

    return PressableScale(
      semanticLabel: item.name,
      onTap:
          () => Get.find<ItemController>().navigateToItemPage(
            item,
            context,
            inStore: inStore,
          ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(color: _border),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Intrinsic so the text column can stretch to the photo's height and
            // push the price to the foot; a Spacer needs a bounded height.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: _photo,
                        height: _photo,
                        decoration: BoxDecoration(
                          color: _photoGround,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Opacity(
                          opacity: soldOut ? 0.45 : 1,
                          // Multiplied with the ground so the white a catalogue
                          // photo ships on becomes the tile, not a white block.
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              _photoGround,
                              BlendMode.multiply,
                            ),
                            child: CustomImage(
                              image: item.imageFullUrl ?? '',
                              variants: item.imageVariants,
                              fit: BoxFit.contain,
                              decodeWidth: 200,
                            ),
                          ),
                        ),
                      ),
                      if (price.onSale && !soldOut)
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
                  const SizedBox(width: Dimensions.paddingSizeMedium),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pack.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: waddyMedium.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: WaddyColors.ink,
                          ),
                        ),
                        if ((pack.size ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            pack.size!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: waddyRegular.copyWith(
                              fontSize: Dimensions.fontSizeExtraSmall,
                              color: WaddyColors.inkLight,
                            ),
                          ),
                        ],
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        // Sits on the card's foot, ahead of the add control.
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 44),
                          child: PriceTag(
                            price: price,
                            size: PriceTagSize.regular,
                            dimmed: soldOut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // A 120×48 room in the card's bottom-end corner for the stepper to
            // grow into; the Align loosens it so the idle "+" is a 48 target
            // of its own and the rest of the card still opens the product.
            if (!soldOut)
              PositionedDirectional(
                bottom: -6,
                end: -6,
                width: AddToCartControl.hitWidth,
                height: Dimensions.minTapTarget,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AddToCartControl(item: item),
                ),
              )
            else
              PositionedDirectional(
                bottom: 0,
                end: 0,
                child: Text(
                  'sold_out'.tr,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: WaddyColors.inkLight,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
