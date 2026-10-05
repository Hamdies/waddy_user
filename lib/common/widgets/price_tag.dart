import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// One item's price facts: what it costs now, what it cost before, and the
/// "N% OFF" label — computed once so the price, the strike and the collar can
/// never disagree.
///
/// The percentage is derived from the two real prices (`1 - now/was`), not
/// read off `discount`, which can be a flat EGP amount — showing that number
/// with a "%" would be wrong. A flat discount reads "50 LE OFF" instead.
class ItemPrice {
  final double now;
  final double was;
  final String? offLabel;

  const ItemPrice(this.now, this.was, this.offLabel);

  bool get onSale => offLabel != null;

  /// [base] overrides the item's own price — a variation's price.
  factory ItemPrice.of(Item item, {double? base}) {
    final double price = base ?? item.price ?? 0;
    final double discount = item.discount ?? 0;
    final double now =
        PriceConverter.convertWithDiscount(
          price,
          discount,
          item.discountType,
        ) ??
        price;
    return ItemPrice.from(
      now: now,
      was: price,
      flat: item.discountType == 'amount',
    );
  }

  factory ItemPrice.from({
    required double now,
    required double was,
    bool flat = false,
  }) {
    if (was <= 0 || now >= was) return ItemPrice(now, now, null);
    final String label =
        flat
            ? '${PriceConverter.convertPrice(was - now)} ${'off'.tr}'
            : '${((1 - now / was) * 100).round()}% ${'off'.tr}';
    return ItemPrice(now, was, label);
  }
}

enum PriceTagSize {
  /// Cards and rows: 14 / 12.
  compact,

  /// Food menu, search: 15 / 13.
  regular,

  /// Item details and the sheets: 20 / 15.
  large,
}

/// The app's one price line.
///
/// ```
///   discounted   ▐148 LE▌  1̶8̶5̶ ̶L̶E̶      mint block, coral strike
///   regular       148 LE
///   per unit     ▐638 LE▌ / kg  7̶5̶0̶ ̶L̶E̶
/// ```
///
/// The sale price sits on a full-mint block — the brand's attention colour,
/// the same move as the saving chip — so a discounted row is findable by
/// colour alone. The was-price stays a readable grey; only its strike is
/// coral, which is what says "this was more".
///
/// A [Wrap], so a narrow card drops the strike to the next line instead of
/// clipping it.
class PriceTag extends StatelessWidget {
  final ItemPrice price;

  /// Drawn as "/ kg" after the price.
  final String? unit;
  final PriceTagSize size;

  /// Sold out: the price greys and loses its block.
  final bool dimmed;

  /// Never wraps: the was-price ellipsizes instead. For fixed-extent grids,
  /// whose cell height was computed for one price line.
  final bool oneLine;

  /// Two fixed lines: the price (and unit) on top, the was-price under it —
  /// and that second line is reserved even when the item is not on sale, so
  /// every card in a rail is the same height. For narrow cards, where a
  /// wrapping [Wrap] put "638 LE", "/ Kilogram" and "750 LE" on three lines.
  final bool stacked;

  const PriceTag({
    super.key,
    required this.price,
    this.unit,
    this.size = PriceTagSize.compact,
    this.dimmed = false,
    this.oneLine = false,
    this.stacked = false,
  });

  PriceTag.forItem(
    Item item, {
    super.key,
    double? base,
    this.unit,
    this.size = PriceTagSize.compact,
    this.dimmed = false,
    this.oneLine = false,
    this.stacked = false,
  }) : price = ItemPrice.of(item, base: base);

  /// "Kilogram" → "kg". Units arrive as admin-typed words; spelled out they
  /// were longer than the price they qualify.
  static String shortUnit(String unit) {
    final String u = unit.trim();
    switch (u.toLowerCase()) {
      case 'kilogram':
      case 'kilograms':
      case 'kilo':
      case 'kg':
        return 'kg';
      case 'gram':
      case 'grams':
      case 'gm':
      case 'g':
        return 'g';
      case 'liter':
      case 'litre':
      case 'liters':
      case 'litres':
      case 'l':
        return 'L';
      case 'milliliter':
      case 'millilitre':
      case 'ml':
        return 'ml';
      case 'piece':
      case 'pieces':
      case 'pcs':
      case 'pc':
        return 'pc';
      default:
        return u;
    }
  }

  /// The line's height at [size], block included, for a grid that has to
  /// know it up front. Multiply by the text scale.
  static double lineHeight(PriceTagSize size) =>
      _Metrics.of(size).now * 1.2 + 4;

  @override
  Widget build(BuildContext context) {
    final _Metrics m = _Metrics.of(size);
    final bool block = price.onSale && !dimmed;

    final Widget nowText = Container(
      padding: EdgeInsets.symmetric(
        horizontal: block ? m.blockPadH : 0,
        vertical: block ? 2 : 0,
      ),
      color: block ? WaddyColors.mint : null,
      child: Text(
        PriceConverter.convertPrice(price.now),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        style: waddyBold.copyWith(
          fontSize: m.now,
          fontWeight: FontWeight.w800,
          height: 1.2,
          letterSpacing: displayTracking(-0.2),
          color: dimmed ? WaddyColors.inkLight : WaddyColors.primary,
        ),
      ),
    );
    final List<Widget> rest = [
     
      if (price.onSale)
        Text(
          PriceConverter.convertPrice(price.was),
          maxLines: 1,
          textDirection: TextDirection.ltr,
          style: waddyMedium.copyWith(
            fontSize: m.was,
            color: WaddyColors.inkMid,
            decoration: TextDecoration.lineThrough,
            decorationColor: WaddyColors.error,
            decorationThickness: 2,
          ),
        ),
    ];

    if (stacked) {
      final Widget wasLine =
          price.onSale
              ? rest.last
              : Text(' ', style: waddyMedium.copyWith(fontSize: m.was));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              nowText,
              if (unit != null) ...[
                SizedBox(width: m.gap - 2),
                Flexible(
                  child: DefaultTextStyle.merge(
                    overflow: TextOverflow.ellipsis,
                    child: rest.first,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          wasLine,
        ],
      );
    }

    if (oneLine) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          nowText,
          for (final Widget w in rest) ...[
            SizedBox(width: m.gap),
            Flexible(
              child: DefaultTextStyle.merge(
                overflow: TextOverflow.ellipsis,
                child: w,
              ),
            ),
          ],
        ],
      );
    }

    return Wrap(
      spacing: m.gap,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [nowText, ...rest],
    );
  }
}

class _Metrics {
  final double now;
  final double was;
  final double gap;
  final double blockPadH;

  const _Metrics(this.now, this.was, this.gap, this.blockPadH);

  static _Metrics of(PriceTagSize size) => switch (size) {
    PriceTagSize.compact => const _Metrics(14, 12, 6, 4),
    PriceTagSize.regular => const _Metrics(15, 13, 8, 5),
    PriceTagSize.large => const _Metrics(20, 15, 10, 6),
  };
}
