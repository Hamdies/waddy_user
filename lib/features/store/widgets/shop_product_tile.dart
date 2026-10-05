import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/add_to_cart_control.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/item/screens/mart_product_screen.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

// ═══════════════════════════════════════════════════════════════
// PRODUCT CARD
// ═══════════════════════════════════════════════════════════════

/// A product as the grocery card language draws it: photo on a soft ground
/// with a round "+" pinned to its corner, then the price in bold and the name
/// in grey under it.
///
/// Shared by the supermarket aisle grid and the menu page's shop variant
/// (D3): one card, so a price or stepper fix lands in both.
///
/// Photo on a soft ground with a round "+" pinned to its corner, then the
/// price in bold and the name in grey under it. The photo and the price are
/// what people scan by, so they get the room and the weight; the name is the
/// tie-breaker.
class ShopProductTile extends StatelessWidget {
  final Item item;

  /// Decode width for the photo, sized to the tile: the aisle grid's three
  /// columns want less than the menu page's two.
  final double decodeWidth;

  const ShopProductTile({
    super.key,
    required this.item,
    this.decodeWidth = 160,
  });

  static const double _kNameLines = 2;
  static const double _kNameSize = 12.5;

  /// Card height for a given width: a square photo, then the price line and
  /// two name lines at the viewer's text scale — a fixed grid extent has to
  /// be told how tall the text will be.
  static double heightFor(BuildContext context, double width) {
    final double scale = MediaQuery.textScalerOf(context).scale(1.0);
    return width +
        8 +
        PriceTag.lineHeight(PriceTagSize.regular) * scale +
        4 +
        _kNameSize * 1.25 * _kNameLines * scale +
        2;
  }

  bool get _soldOut => item.stock != null && item.stock! <= 0;

  @override
  Widget build(BuildContext context) {
    final ItemPrice price = ItemPrice.of(item);

    return PressableScale(
      semanticLabel: item.name,
      onTap: () => MartProductScreen.open(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: WaddyColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusLarge,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Opacity(
                        opacity: _soldOut ? 0.45 : 1,
                        child: CustomImage(
                          image: item.imageFullUrl ?? '',
                          variants: item.imageVariants,
                          fit: BoxFit.contain,
                          decodeWidth: decodeWidth,
                        ),
                      ),
                    ),
                  ),
                ),
                // The shared offer collar, compact for an image overlay — the
                // same "% OFF" the store rows wear, not a card-local chip.
                if (price.onSale && !_soldOut)
                  PositionedDirectional(
                    top: 6,
                    start: 6,
                    child:
                        OfferCollarBadge.forPrice(
                          price,
                          compact: true,
                          onPhoto: true,
                        )!,
                  ),
                if (_soldOut)
                  PositionedDirectional(
                    top: 6,
                    start: 6,
                    child: _Tag(
                      label: 'out_of_stock'.tr,
                      background: WaddyColors.divider,
                      foreground: WaddyColors.inkLight,
                    ),
                  ),
                // Pinned by its END edge: the stepper grows toward the start
                // across the photo, so the "+" the finger is on doesn't move
                // out from under it when it opens.
                if (!_soldOut)
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    height: Dimensions.minTapTarget,
                    child: AddToCartControl(item: item, inset: 4),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          PriceTag(
            price: price,
            size: PriceTagSize.regular,
            dimmed: _soldOut,
            oneLine: true,
          ),
          const SizedBox(height: 4),
          Text(
            item.name ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: waddyRegular.copyWith(
              fontSize: _kNameSize,
              height: 1.25,
              color: WaddyColors.inkLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: waddyBold.copyWith(fontSize: 10.5, color: foreground),
      ),
    );
  }
}

/// A card-shaped block for a tile still loading, at the tile's own geometry
/// so the real grid lands where the placeholder was.
class ShopProductTilePlaceholder extends StatelessWidget {
  final double width;
  const ShopProductTilePlaceholder({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: WaddyColors.surfaceRaised,
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: width * 0.55,
          height: 14,
          decoration: BoxDecoration(
            color: WaddyColors.surfaceRaised,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: width * 0.85,
          height: 11,
          decoration: BoxDecoration(
            color: WaddyColors.surfaceRaised,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
