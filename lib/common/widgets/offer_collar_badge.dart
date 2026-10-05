import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// The one shape every offer badge in the app wears.
///
/// A "collar": a tinted pill whose icon rides a filled disc hung off the
/// leading edge, slightly taller than the pill itself, with the tint fading
/// out toward the trailing end so the label sits on nearly-bare card rather
/// than inside a hard-edged block.
///
/// Before this, the same two facts — money off, free delivery — were drawn
/// four different ways on four screens: a flat square chip on the store row,
/// a rounded icon pill on the top-10 card, a plain coloured word on the hero
/// card, and a solid red rectangle on the popular card. Same promise, four
/// visual weights, so none of them read as a system. [OfferCollarBadge] is
/// that system; per-screen the only choice left is [OfferCollarTone] and
/// [compact].
enum OfferCollarTone {
  /// Money off — a percentage or an amount. Coral, because promotions are
  /// coral in this app and amber is already the warning/in-transit hue.
  sale,

  /// Free delivery. Mint, the "worth your attention" family.
  delivery,

  /// Buy one get one and other item-count perks. Amber.
  gift,
}

/// The three pieces of colour a tone resolves to: the disc behind the icon,
/// the ink both the icon and the label are set in, and the tint the pill
/// fades from.
///
/// [disc] is one step deeper than [surface], not a saturated fill. The badge
/// is then a single hue at three strengths — tint, deeper tint, ink — which is
/// what lets the icon sit in the same colour as its label instead of being a
/// separate dark object the eye lands on first.
class _ToneColors {
  final Color disc;
  final Color ink;
  final Color surface;

  const _ToneColors(this.disc, this.ink, this.surface);
}

_ToneColors _colorsFor(OfferCollarTone tone) {
  switch (tone) {
    case OfferCollarTone.sale:
      return const _ToneColors(
        Color(0xFFFBD5D5), // coral 100
        WaddyColors.coralInk,
        WaddyColors.coralSurface,
      );
    case OfferCollarTone.delivery:
      return const _ToneColors(
        WaddyColors.mintSurfaceDeep,
        WaddyColors.mintInk,
        WaddyColors.mintSurface,
      );
    case OfferCollarTone.gift:
      return const _ToneColors(
        Color(0xFFFDECC0), // amber 100
        WaddyColors.amberInk,
        WaddyColors.amberSurface,
      );
  }
}

List<List<dynamic>> _iconFor(OfferCollarTone tone) {
  switch (tone) {
    case OfferCollarTone.sale:
      return HugeIcons.strokeRoundedHotPrice;
    case OfferCollarTone.delivery:
      return HugeIcons.strokeRoundedScooter02;
    case OfferCollarTone.gift:
      return HugeIcons.strokeRoundedGift;
  }
}

class OfferCollarBadge extends StatelessWidget {
  final String label;
  final OfferCollarTone tone;

  /// Dense card slots (the top-10 rail, image overlays) take the compact
  /// build: same proportions, ~0.8x. Rows and detail headers take the full
  /// size.
  final bool compact;

  /// Laid over a product photo. The pill is solid instead of fading out —
  /// the fade reads as intended on a white card and as a smudge on a photo,
  /// where the label would sit on bare image — and gets a white rim so it
  /// separates from busy packaging.
  final bool onPhoto;

  const OfferCollarBadge({
    super.key,
    required this.label,
    required this.tone,
    this.compact = false,
    this.onPhoto = false,
  });

  /// An item's own markdown — "15% OFF", or "50 LE OFF" for a flat one — or
  /// null when it is not on sale. Same tone and shape as the store badges, so
  /// "money off" looks the same on a store card and on a product.
  static OfferCollarBadge? forItem(
    Item item, {
    double? base,
    bool compact = false,
    bool onPhoto = false,
  }) => forPrice(
    ItemPrice.of(item, base: base),
    compact: compact,
    onPhoto: onPhoto,
  );

  static OfferCollarBadge? forPrice(
    ItemPrice price, {
    bool compact = false,
    bool onPhoto = false,
  }) {
    if (!price.onSale) return null;
    return OfferCollarBadge(
      label: price.offLabel!,
      tone: OfferCollarTone.sale,
      compact: compact,
      onPhoto: onPhoto,
    );
  }

  /// The store's best money-off perk, or null when there is none.
  ///
  /// Discount wins over free delivery when a store has both and only one slot
  /// is available — a percentage is the larger claim.
  static OfferCollarBadge? forDiscount(
    Store store, {
    bool compact = false,
    bool onPhoto = false,
  }) {
    final discount = store.discount;
    if (discount?.discount == null || discount!.discount! <= 0) return null;
    return OfferCollarBadge(
      label:
          discount.discountType == 'percent'
              ? '${discount.discount!.toInt()}% ${'off'.tr}'
              : '${PriceConverter.convertPrice(discount.discount!)} ${'off'.tr}',
      tone: OfferCollarTone.sale,
      compact: compact,
      onPhoto: onPhoto,
    );
  }

  /// "Up to 30% OFF" — the deepest markdown on any item the store sells, or
  /// null when it has no item on sale. Distinct from [forDiscount], which is a
  /// store-wide offer applied to the whole basket.
  static OfferCollarBadge? forMaxItemDiscount(
    Store store, {
    bool compact = false,
    bool onPhoto = false,
  }) {
    final int? percent = store.maxItemDiscount;
    if (percent == null || percent <= 0) return null;
    return OfferCollarBadge(
      label: '${'up_to'.tr} $percent% ${'off'.tr}',
      tone: OfferCollarTone.sale,
      compact: compact,
      onPhoto: onPhoto,
    );
  }

  static OfferCollarBadge? forFreeDelivery(
    Store store, {
    bool compact = false,
    bool onPhoto = false,
  }) {
    final bool free =
        store.freeDelivery == true || store.minimumShippingCharge == 0;
    if (!free) return null;
    return OfferCollarBadge(
      label: 'free_delivery'.tr,
      tone: OfferCollarTone.delivery,
      compact: compact,
      onPhoto: onPhoto,
    );
  }

  /// The store's best perk as a photo-corner badge, or nothing — for a
  /// store card's cover or logo. Money off wins over free delivery.
  ///
  /// [atBottom] for a slot whose top-start corner already holds something
  /// (the favourite heart).
  static Widget storeCorner(
    Store store, {
    double inset = 6,
    bool atBottom = false,
  }) {
    final OfferCollarBadge? badge =
        forDiscount(store, compact: true, onPhoto: true) ??
        forFreeDelivery(store, compact: true, onPhoto: true);
    if (badge == null) return const SizedBox.shrink();
    return PositionedDirectional(
      top: atBottom ? null : inset,
      bottom: atBottom ? inset : null,
      start: inset,
      child: badge,
    );
  }

  /// An item's sale collar on its photo's top-start corner, or nothing.
  static Widget itemCorner(
    Item item, {
    double? base,
    double top = 6,
    double start = 6,
  }) {
    final OfferCollarBadge? badge = forItem(
      item,
      base: base,
      compact: true,
      onPhoto: true,
    );
    if (badge == null) return const SizedBox.shrink();
    return PositionedDirectional(top: top, start: start, child: badge);
  }

  @override
  Widget build(BuildContext context) {
    final _ToneColors c = _colorsFor(tone);

    // The disc overhangs the pill on both axes, so the pill's leading padding
    // has to clear it and the whole badge has to be laid out with the disc
    // free to sit outside the pill's box.
    //
    // Scaled DOWN from the source design's 38/42px. Those numbers were drawn
    // on a 420px-wide canvas holding three badges and nothing else; dropped
    // into a real store row they made the disc taller than the delivery-time
    // text beside it, so the icon — the least important part — became the
    // biggest thing on the row. The badge is an annotation on a line of text,
    // so the pill is sized to that line and the disc only just exceeds it.
    final double height = compact ? 22 : 28;
    final double disc = compact ? 23 : 20;
    const double overhang = 1.5;
    final double leadPad = disc - overhang + (compact ? 4 : 5);

    // Equal to the gap the label has on its leading side (the space between
    // the disc's trailing edge and the text), so the label is optically
    // centred in the run of pill that is actually visible beside the disc.
    // The source design used a much larger trailing pad, which parked the
    // text hard against the disc with a wide empty tail after it.
    final double trailPad = compact ? 4 : 5;

    // Directional, so the collar flips to the right edge in Arabic and the
    // gradient fades the other way with it.
    final bool rtl = Directionality.of(context) == TextDirection.rtl;

    // The badge hugs its label. A bare Stack takes every pixel the parent
    // offers, which stretched the pill across the whole row and left the text
    // stranded in the middle of it, far from the icon that belongs to it.
    // [IntrinsicWidth] + a non-positioned pill makes the pill size the Stack,
    // and the disc (the only positioned child) then hangs off that.
    return IntrinsicWidth(
      child: SizedBox(
        height: disc,
        child: Stack(
          alignment: AlignmentDirectional.centerStart,
          clipBehavior: Clip.none,
          children: [
            // The pill. Inset by the overhang so the disc's outer edge, not the
            // pill's, is what aligns with whatever sits to the left of it.
            Padding(
              padding: const EdgeInsetsDirectional.only(start: overhang),
              child: Container(
                height: height,
                padding: EdgeInsetsDirectional.only(
                  start: leadPad,
                  end: trailPad,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  color: onPhoto ? c.surface : null,
                  border:
                      onPhoto
                          ? Border.all(color: WaddyColors.surface, width: 1)
                          : null,
                  gradient:
                      onPhoto
                          ? null
                          : LinearGradient(
                            begin:
                                rtl
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            end:
                                rtl
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                            stops: const [0.55, 1.0],
                            colors: [c.surface, c.surface.withValues(alpha: 0)],
                          ),
                ),
                // Centre the label in the pill on both axes.
                //
                // NOT `Container.alignment` — that makes the box expand to
                // every pixel the parent offers, which defeats the
                // [IntrinsicWidth] above and stretches the pill across the
                // whole row again. `Center` with widthFactor 1.0 centres the
                // text while still sizing the box to it.
                child: Center(
                  widthFactor: 1.0,
                  child: Text(
                    displayCaps(label),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyBold.copyWith(
                      fontSize: compact ? 11.5 : 14,
                      height: 1.0,
                      color: c.ink,
                      letterSpacing: displayTracking(0.3),
                    ),
                  ),
                ),
              ),
            ),

            // The disc, hung off the leading edge and vertically centred.
            PositionedDirectional(
              start: 0,
              child: Container(
                width: disc,
                height: disc,
                // No drop shadow. A coloured glow under a 24pt circle reads
                // as a smudge at this size, not as lift, and it was the only
                // shadow on an otherwise flat row — so the badge looked like
                // it had come loose from the card.
                decoration: BoxDecoration(
                  color: c.disc,
                  shape: BoxShape.circle,
                ),
                // Icon in the tone's own ink, not white. White demanded a
                // saturated disc dark enough to carry it, which made the disc
                // the loudest element in the badge and left the icon reading
                // as a hole punched in it. Ink-on-tint keeps the whole badge
                // one colour at two strengths, so the label leads and the
                // icon supports it.
                child: HugeIcon(
                  icon: _iconFor(tone),
                  size: compact ? 8 : 8,
                  strokeWidth: 1.8,
                  color: c.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
