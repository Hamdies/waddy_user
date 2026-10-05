import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/add_to_cart_control.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/item/screens/mart_product_screen.dart';
import 'package:waddy_app/features/store/helpers/pack_size.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// The supermarket page's product language (Mart Store Page v4): one card
/// for every rail — Buy again, Best sellers, the aisle sections — and one
/// row tile for the two-row aisle grid.
///
/// ```
///   ┌────────────────┐
///   │ ┌#1──────────┐ │   photo on a raised ground, badge top-start
///   │ │    photo   │ │
///   │ │        [+] │ │   36 square "+", the stepper once it is in the cart
///   │ └────────────┘ │
///   │ Name, two lines│   size taken off the name's end…
///   │ 125 g          │   …and shown here (else the unit)
///   │ EGP 15  30     │   price, then the was-price struck through
///   └────────────────┘
/// ```

bool _soldOut(Item item) => item.stock != null && item.stock! <= 0;

String? _unitOf(Item item) {
  final String? unit = item.unitType?.trim();
  return unit == null || unit.isEmpty ? null : unit;
}

/// The size line for a packaged-goods card: the size the name states
/// ("Heinz Ketchup 125g" → "125 g"), or nothing. Never the unit field — live
/// units sit on a "Kilogram" default under ketchup and bleach, and a guessed
/// "kg" under every product read as wrong data.
String? _sizeOf(Item item) => PackSize.of(item.name).size;

/// The description as one plain line ("Local, grass-fed"), or null.
String? _blurbOf(Item item) {
  final String text =
      (item.description ?? '')
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
  if (text.isEmpty) return null;
  // Seed and admin data often copy the name into the description; a second
  // line that repeats the first only makes the card taller.
  if (text.toLowerCase() == (item.name ?? '').trim().toLowerCase()) {
    return null;
  }
  return text;
}

void _openItem(Item item) => MartProductScreen.open(item);

/// A packshot on its ground: the photo is multiplied with the ground colour,
/// so the white a catalogue photo ships on becomes the ground instead of a
/// white block with grey bands either side. Cutouts and cover photos are
/// untouched; the ground is near-white, so colours barely move.
Widget _onGround({required BoxFit fit, required Widget child}) =>
    fit == BoxFit.contain
        // Clipped: multiply paints the ground colour over every transparent
        // pixel of its layer, and an unclipped layer is the whole screen.
        ? ClipRect(
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              WaddyColors.surfaceRaised,
              BlendMode.multiply,
            ),
            child: child,
          ),
        )
        : child;

// ═══════════════════════════════════════════════════════════════
// CARD
// ═══════════════════════════════════════════════════════════════
class StoreProductCard extends StatelessWidget {
  final Item item;

  /// "#3" in the photo's corner. Takes the corner over the sale badge.
  final int? rank;

  /// Drawn under the price — the best sellers' order count.
  final Widget? footer;

  /// Off on a tinted panel, where the card's white already separates it.
  final bool bordered;

  /// `cover` for a specialty store's photos (a cut of meat, a crate of
  /// mangoes), which fill the frame; `contain` for packshots.
  final BoxFit fit;

  /// A specialty store's card: the description under the name and the unit
  /// after the price ("EGP 420 / kg"), instead of the unit on its own line.
  final bool perUnit;

  /// Replaces opening the item page — on a tap of the card, and on the "+"
  /// of an item with options. The specialty page opens its product sheet.
  final VoidCallback? onOpen;

  /// The card's width; null fills what it is given (a short aisle's grid).
  final double? cardWidth;

  const StoreProductCard({
    super.key,
    required this.item,
    this.cardWidth = width,
    this.rank,
    this.footer,
    this.bordered = true,
    this.fit = BoxFit.contain,
    this.perUnit = false,
    this.onOpen,
  });

  static const double width = 164;
  static const double _kPhotoHeight = 120;

  /// The height a horizontal rail of these cards needs at the viewer's text
  /// scale. The card's name and price rows grow with it, so a rail sized to a
  /// fixed number clips the price at large text.
  static double railHeight(BuildContext context) =>
      172 + 96 * MediaQuery.textScalerOf(context).scale(1);

  @override
  Widget build(BuildContext context) {
    final ItemPrice price = ItemPrice.of(item);
    final bool soldOut = _soldOut(item);
    final String? unit = _unitOf(item);
    // A specialty card prices per unit and describes the cut; a packshot
    // card names the product and states its size underneath.
    final String? secondLine = perUnit ? _blurbOf(item) : _sizeOf(item);
    final String name =
        perUnit ? (item.name ?? '') : PackSize.of(item.name).name;
    final bool onSale = price.onSale && !soldOut;
    return SizedBox(
      width: cardWidth,
      child: PressableScale(
        semanticLabel: item.name,
        onTap: onOpen ?? () => _openItem(item),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
          decoration: BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            border: Border.all(
              color: bordered ? WaddyColors.divider : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: _kPhotoHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: WaddyColors.surfaceRaised,
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusDefault,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Opacity(
                              opacity: soldOut ? 0.45 : 1,
                              child: _onGround(
                                fit: fit,
                                child: CustomImage(
                                  image: item.imageFullUrl ?? '',
                                  variants: item.imageVariants,
                                  fit: fit,
                                  decodeWidth: 260,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (rank != null)
                          PositionedDirectional(
                            top: 6,
                            start: 6,
                            child: _Badge(label: '#$rank'),
                          )
                        // The sale collar on the photo's corner, as on store
                        // cards: beside the price it squeezed "378 LE" into
                        // an overflow on a narrow card.
                        else if (onSale)
                          OfferCollarBadge.itemCorner(item),
                        if (soldOut)
                          const PositionedDirectional(
                            bottom: 6,
                            end: 6,
                            child: _SoldOutTag(),
                          )
                        else
                          // A 120×48 room in the photo's bottom-end corner for
                          // the stepper to grow into; the Align loosens it, so
                          // the idle "+" is a 48 target and the rest of the
                          // photo's bottom strip still opens the product.
                          PositionedDirectional(
                            bottom: 0,
                            end: 0,
                            width: AddToCartControl.hitWidth,
                            height: Dimensions.minTapTarget,
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: AddToCartControl(
                                item: item,
                                onOptions: onOpen,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Name, then size right under it.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: waddyMedium.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: WaddyColors.ink,
                          ),
                        ),
                        if ((secondLine ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            secondLine!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: waddyRegular.copyWith(
                              fontSize: 12,
                              color: WaddyColors.inkLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // The price sits on the card's foot. Rails stretch their cards
              // to the tallest one, so a one-line name's slack lands here,
              // above the price, and prices line up across the rail.
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wrap, not one line: the was-price drops under the
                    // price on a narrow card instead of overflowing.
                    PriceTag(
                      price: price,
                      size: PriceTagSize.regular,
                      dimmed: soldOut,
                      unit: perUnit ? unit : null,
                    ),
                    if (footer != null) ...[const SizedBox(height: 4), footer!],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ROW TILE — the two-row aisle grid
// ═══════════════════════════════════════════════════════════════
class StoreProductRow extends StatelessWidget {
  final Item item;

  /// Null fills the width it is given: a short aisle lists its rows
  /// full-width instead of scrolling one narrow column.
  final double? width;

  const StoreProductRow({
    super.key,
    required this.item,
    this.width = defaultWidth,
  });

  static const double defaultWidth = 268;

  @override
  Widget build(BuildContext context) {
    final ItemPrice price = ItemPrice.of(item);
    final bool soldOut = _soldOut(item);
    final PackSize pack = PackSize.of(item.name);
    final String? size = _sizeOf(item);

    return SizedBox(
      width: width,
      child: PressableScale(
        semanticLabel: item.name,
        onTap: () => _openItem(item),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 0, 4),
          decoration: BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: WaddyColors.divider),
          ),
          child: Row(
            children: [
              // The sale collar rides the photo's top corner: a line of its
              // own under the price would make this row taller than its
              // neighbours and leave the aisle grid ragged.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: WaddyColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Opacity(
                      opacity: soldOut ? 0.45 : 1,
                      child: CustomImage(
                        image: item.imageFullUrl ?? '',
                        variants: item.imageVariants,
                        fit: BoxFit.contain,
                        decodeWidth: 140,
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: waddyRegular.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: WaddyColors.ink,
                      ),
                    ),
                    if (size != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        size,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyRegular.copyWith(
                          fontSize: 11,
                          color: WaddyColors.inkLight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    PriceTag(price: price, dimmed: soldOut),
                  ],
                ),
              ),
              // Shrinks to the "+" (a 48 target) so the name gets the room;
              // widens to the stepper's 120 once the item is in the cart.
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: Dimensions.minTapTarget,
                ),
                child: SizedBox(
                  height: 64,
                  child:
                      soldOut
                          ? const Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(end: 8),
                              child: _SoldOutTag(),
                            ),
                          )
                          : AddToCartControl(item: item),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MENU ROW — a specialty store's counter: photo, name, blurb, price / unit
// ═══════════════════════════════════════════════════════════════
class StoreMenuRow extends StatelessWidget {
  final Item item;

  /// Replaces opening the item page, as on [StoreProductCard.onOpen].
  final VoidCallback? onOpen;

  const StoreMenuRow({super.key, required this.item, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final ItemPrice price = ItemPrice.of(item);
    final bool soldOut = _soldOut(item);
    final String? blurb = _blurbOf(item);

    return PressableScale(
      semanticLabel: item.name,
      onTap: onOpen ?? () => _openItem(item),
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(color: WaddyColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The sale collar rides the photo, not a line under the price:
            // that line made every discounted row taller than its neighbours.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: WaddyColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Opacity(
                    opacity: soldOut ? 0.45 : 1,
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      variants: item.imageVariants,
                      fit: BoxFit.cover,
                      decodeWidth: 180,
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 84),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: waddyBold.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: WaddyColors.ink,
                            ),
                          ),
                          if (blurb != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              blurb,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: waddyRegular.copyWith(
                                fontSize: 12,
                                color: WaddyColors.inkLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: PriceTag(
                            price: price,
                            size: PriceTagSize.regular,
                            dimmed: soldOut,
                            unit: _unitOf(item),
                            oneLine: true,
                          ),
                        ),
                        if (soldOut)
                          const _SoldOutTag()
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: Dimensions.minTapTarget,
                            ),
                            child: SizedBox(
                              height: Dimensions.minTapTarget,
                              child: AddToCartControl(
                                item: item,
                                inset: 0,
                                onOptions: onOpen,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPACT ROW — Buy again on a specialty store: 276 wide, photo 56
// ═══════════════════════════════════════════════════════════════
class StoreCompactRow extends StatelessWidget {
  final Item item;

  /// Replaces opening the item page, as on [StoreProductCard.onOpen].
  final VoidCallback? onOpen;

  /// What the "+" of an item with options does — Buy again repeats the last
  /// line. Falls back to [onOpen].
  final VoidCallback? onAdd;

  /// The line's description ("2 kg · For salad"), over the unit.
  final String? spec;

  const StoreCompactRow({
    super.key,
    required this.item,
    this.onOpen,
    this.onAdd,
    this.spec,
  });

  static const double width = 276;

  @override
  Widget build(BuildContext context) {
    final ItemPrice price = ItemPrice.of(item);
    final bool soldOut = _soldOut(item);
    final String? spec = this.spec ?? _sizeOf(item) ?? _blurbOf(item);
    final String name = PackSize.of(item.name).name;

    return SizedBox(
      width: width,
      child: PressableScale(
        semanticLabel: item.name,
        onTap: onOpen ?? () => _openItem(item),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 2, 4),
          decoration: BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            border: Border.all(color: WaddyColors.divider),
          ),
          child: Row(
            children: [
              // The sale collar rides the photo's top corner: a line of its
              // own under the price would make this row taller than its
              // neighbours and leave the aisle grid ragged.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: WaddyColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Opacity(
                      opacity: soldOut ? 0.45 : 1,
                      child: CustomImage(
                        image: item.imageFullUrl ?? '',
                        variants: item.imageVariants,
                        fit: BoxFit.cover,
                        decodeWidth: 120,
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: waddyBold.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: WaddyColors.ink,
                      ),
                    ),
                    if (spec != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        spec,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyRegular.copyWith(
                          fontSize: 11,
                          color: WaddyColors.inkLight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    PriceTag(price: price, dimmed: soldOut),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: Dimensions.minTapTarget,
                ),
                child: SizedBox(
                  height: 64,
                  child:
                      soldOut
                          ? const Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(end: 6),
                              child: _SoldOutTag(),
                            ),
                          )
                          : AddToCartControl(
                            item: item,
                            onOptions: onAdd ?? onOpen,
                            // Buy again's "+" repeats the last line.
                            quickAdd: onAdd == null,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small teal-on-tint label under a row's price ("20% off").
class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: WaddyColors.primary,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: waddyBold.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
          color: WaddyColors.mint,
        ),
      ),
    );
  }
}

class _SoldOutTag extends StatelessWidget {
  const _SoldOutTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: WaddyColors.divider,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'out_of_stock'.tr,
        style: waddyBold.copyWith(fontSize: 10.5, color: WaddyColors.inkLight),
      ),
    );
  }
}
