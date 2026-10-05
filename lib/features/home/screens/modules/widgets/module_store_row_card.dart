import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/card_design/store_list_card.dart'
    show kMinRatingsToShow;
import 'package:waddy_app/features/cuisine/controllers/cuisine_controller.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_semantics.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/location/widgets/coming_soon_delivery.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Above this, a distance is describing a coordinate problem rather than a
/// restaurant. Waddi delivers inside city zones; nothing orderable is 50km
/// out, so a larger figure means the device GPS and the selected address are
/// pointing at different cities and the number should not be shown at all.
const double kMaxPlausibleDeliveryKm = 50;

/// Below this many ratings a store shows a NEW badge instead of a score.
///
/// [kMinRatingsToShow] is the bar for trusting a number; this is what the row
/// says while a store is still under it. On a catalogue this young that is
/// most of them, and the honest read of "no score yet" is "nobody has tried
/// it" — which is an invitation, not a gap.
const int kNewStoreRatingCeiling = kMinRatingsToShow;

/// Whether the NEW badge renders at all.
///
/// Off for now — nearly every store in the catalogue currently qualifies, so
/// the badge stopped meaning "just opened" and started meaning "most rows".
/// Flip back on once the catalogue has enough rated stores that NEW is rare
/// again.
const bool kShowNewBadge = false;

/// How many cuisines a browse row prints before the rest are dropped.
///
/// Three is what fits one line at the widest name on a small phone without
/// the ellipsis biting into a word. It is also about where the list stops
/// describing the place and starts listing its menu: "Egyptian, Koshary,
/// Sandwiches" is a restaurant, "…, Breakfast, Desserts" is an inventory.
const int _maxCuisines = 3;

/// Browse-list store row: square photo on the leading edge, everything the
/// user decides on stacked beside it.
///
/// Replaces the hero card that gave each store a 150pt cover photo. On a
/// browse list the photo is not the decision — the name, the cuisines, the fee
/// and the wait are — and a 150pt hero meant barely two stores fit on screen,
/// so comparing three restaurants was three separate scroll-and-remember
/// steps. An 84pt thumbnail keeps the food visible while putting five
/// comparable rows in one viewport.
///
/// The row reads in decision order, top to bottom:
///   1. name           — who
///   2. rating·cuisine — how good, and what kind of food
///   3. meta line      — fee · time · distance, the numbers you compare on
///   4. offer chips    — what you save, only when there is something to save
///
/// Rating and cuisine share line 2 because they answer the same question —
/// "is this the kind of place I want, and is it any good" — and splitting
/// them cost a whole line per row. The score leads it: it is the shorter,
/// higher-signal half, so it survives when a long cuisine list truncates.
///
/// Out of zone (`isComingSoon`) the meta line and the offer chips collapse to
/// a single "Coming soon" chip: promoting a delivery time or a discount for a
/// store we cannot deliver from is the bait-and-switch the zone gate exists to
/// prevent. That block is wrapped in [ZoneAware] because the card is usually
/// built under a `GetBuilder<StoreController>`, which never rebuilds when the
/// address — and therefore the zone — changes mid-session.
class ModuleStoreRowCard extends StatelessWidget {
  final Store store;

  final VoidCallback onTap;

  const ModuleStoreRowCard({
    super.key,
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOpen = store.open == 1;

    return PressableScale(
      semanticLabel: moduleStoreSemanticLabel(store),
      onTap: onTap,
      // No Opacity layer when the store is open.
      //
      // `Opacity` allocates an offscreen buffer and composites it back — even
      // at 1.0, where it changes nothing. Most stores are open most of the
      // time, so every row in the list was paying for a layer that did
      // nothing. The dim is a real requirement for closed stores, so it stays
      // for those; it just no longer taxes the common case.
      child: _maybeDim(
        isOpen: isOpen,
        child: Padding(
          // 10 a side = a 20pt gutter between neighbouring rows, tight enough
          // that five rows fit a viewport and the list reads as one column
          // rather than a stack of separate cards.
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(store: store, isOpen: isOpen),
              const SizedBox(width: 14),
              Expanded(child: _Details(store: store)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// THUMBNAIL
// ═══════════════════════════════════════════

/// Square cover photo with the brand logo tucked into its bottom-trailing
/// corner.
///
/// The logo is what makes a chain recognisable at a glance — a Papa Johns cover
/// photo is just pizza until the mark is on it — so it stays even though the
/// card no longer has a hero to float it over.
class _Thumbnail extends StatelessWidget {
  static const double _size = 84;
  static const double _radius = 14;

  final Store store;
  final bool isOpen;

  const _Thumbnail({required this.store, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      // The logo badge sits 5pt outside the thumbnail's own bounds on two
      // edges — a hardEdge Stack (the default) would clip that overhang off.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: ColoredBox(
                color: WaddyColors.mintSurface,
                child: CustomImage(
                  image: store.coverPhotoFullUrl ?? '',
                  fit: BoxFit.cover,
                  variants: store.coverPhotoVariants,
                  decodeWidth: _size,
                ),
              ),
            ),
          ),

          // Logo chip, bottom-trailing corner, half off the thumbnail. A
          // brand mark reads as a stamp of authenticity there — the way a
          // wax seal sits on a corner, not centred on the item — and bottom-
          // trailing keeps it clear of the top-leading NEW badge's row and
          // off the food itself, which top-leading was cropping into on
          // square dish shots.
          PositionedDirectional(
            bottom: -5,
            end: -5,
            child: Container(
              width: 30,
              height: 30,
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CustomImage(
                  image: store.logoFullUrl ?? '',
                  fit: BoxFit.cover,
                  decodeWidth: 30,
                ),
              ),
            ),
          ),

          if (!isOpen)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(_radius),
                ),
                child: Center(
                  child: Text(
                    displayCaps('closed'.tr),
                    textAlign: TextAlign.center,
                    style: waddyBold.copyWith(
                      fontSize: 11,
                      color: Colors.white,
                      letterSpacing: displayTracking(1.0),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// DETAILS COLUMN
// ═══════════════════════════════════════════

class _Details extends StatelessWidget {
  final Store store;

  const _Details({required this.store});

  @override
  Widget build(BuildContext context) {
    // A score is only shown once enough reviews stand behind it. `5.0 (1)`
    // reads as fabricated and makes a rating sort meaningless across a
    // catalogue this size.
    final bool hasShowableRating =
        store.avgRating != null &&
        store.avgRating! > 0 &&
        (store.ratingCount ?? 0) >= kMinRatingsToShow;

    // Not simply "!hasShowableRating": a store with 19 reviews and a 4.6 is
    // not new, it is just under the display bar. NEW is claimed only when
    // barely anyone has rated it at all.
    final bool isNew =
        (store.ratingCount ?? 0) < kNewStoreRatingCeiling &&
        (store.avgRating ?? 0) <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── NAME ───
        //
        // One line, not two. A name that needs two lines is a long one, and
        // on a browse list the tail of "Kazouza Grill House, Degla" is worth
        // less than keeping every row the same height to compare down.
        // The NEW badge rides the name's line rather than sitting under it:
        // it qualifies *this store*, and a row whose second line is already
        // conditional cannot be where the badge lives or it lands in a
        // different place on every card.
        Row(
          children: [
            Flexible(
              child: Text(
                store.name ?? '',
                style: waddyBold.copyWith(
                  fontSize: 18,
                  color: WaddyColors.ink,
                  height: 1.25,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isNew && kShowNewBadge) ...[
              const SizedBox(width: Dimensions.paddingSizeSmall),
              const _NewBadge(),
            ],
          ],
        ),

        // ─── RATING · CUISINES ───
        //
        // Collapses entirely when there is neither a trustworthy score nor a
        // cuisine to print, instead of holding open an empty line. A row with
        // nothing to say here should be shorter, not padded.
        if (hasShowableRating || _categoryLine.isNotEmpty) ...[
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          _RatingCuisineLine(
            rating: hasShowableRating ? store.avgRating : null,
            cuisines: _categoryLine,
          ),
        ],
        const SizedBox(height: Dimensions.paddingSizeSmall),

        // ─── META + OFFERS ───
        //
        // Free Delivery rides the meta line itself when it is the only chip —
        // "20-35 mins · Free Delivery" reads as one fact and costs no extra
        // height, and free delivery is exactly why the meta line has no fee
        // segment to compete with it for the width.
        //
        // Everything else stacks onto a row of its own underneath. A paid
        // fee already makes the meta line two segments ("25-40 mins ·
        // 15 LE"), and squeezing a discount chip onto that same line left too
        // little room — the fee text clipped mid-word instead of wrapping.
        // Two discount+free chips together overran the row the same way
        // ("20-35 mins · Free Delivery · 25% OFF"). Both cases alone pay for
        // a second row rather than risk the clip.
        ZoneAware(
          builder: (context) {
            if (isComingSoon) return const ComingSoonChip();

            final double? charge = store.minimumShippingCharge;
            final bool hasFreeDelivery =
                store.freeDelivery == true || charge == 0;
            final bool hasPaidFee =
                !hasFreeDelivery && charge != null && charge > 0;

            final discount = store.discount;
            final bool hasDiscount =
                discount?.discount != null && discount!.discount! > 0;

            final bool canInline =
                hasFreeDelivery && !hasDiscount && !hasPaidFee;

            if (canInline) {
              return Row(
                children: [
                  Flexible(child: _MetaLine(store: store)),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Flexible(
                    child: _OfferChips(store: store, stackedBelowMeta: false),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_MetaLine(store: store), _OfferChips(store: store)],
            );
          },
        ),
      ],
    );
  }

  /// Prefers names the store payload already carries; falls back to resolving
  /// ids against the fetched cuisine list. This used to read category names,
  /// which are empty for every food store, so every card said "Restaurant".
  ///
  /// Capped at [_maxCuisines]. Uncapped, a four-cuisine store truncated
  /// mid-word — "Egyptian, Koshary, Sandwiches, Brea…" — which spends the
  /// width on a fragment that names nothing. Cutting to a whole number of
  /// cuisines means every name on the line is readable, and the tail the
  /// ellipsis was eating was the lowest-signal one anyway: the list arrives
  /// in the order the store was tagged, so the leading entries are the ones
  /// that actually describe it.
  String get _categoryLine {
    if (store.cuisineNames != null && store.cuisineNames!.isNotEmpty) {
      return _capped(store.cuisineNames!);
    }
    final resolved = Get.find<CuisineController>().namesFor(
      store.cuisineIds,
      limit: _maxCuisines,
    );
    if (resolved.isNotEmpty) return resolved;
    // No generic fallback. When the payload carries no cuisines, a line that
    // says "Restaurant" on a list of restaurants prints a fact the section
    // header already gave and costs a whole line per row to do it. Returning
    // empty lets line 2 collapse and the meta line — the part you actually
    // compare on — move up into the space.
    return '';
  }

  /// Joins at most [_maxCuisines] names, dropping the rest silently.
  ///
  /// No "+2" counter on the end: the number of extra tags a restaurant
  /// carries is not a fact anyone browses on, and printing it would cost the
  /// same width as another real cuisine name.
  String _capped(List<String> names) {
    return names
        .where((n) => n.trim().isNotEmpty)
        .take(_maxCuisines)
        .join(', ');
  }
}

/// `★ 4.8 · Pizza, Italian` — the score and the kind of food on one line.
///
/// The score is a bare number on a mint star, not the filled teal pill it
/// used to be: a pill per row put six saturated rectangles down a list whose
/// only real accent should be the offer chips, and it forced the cuisines
/// onto a line of their own. Mint ink is the token that is legible on white
/// (5.4:1); the electric mint is a surface colour and would be invisible here.
///
/// Cuisines take the remaining width and truncate; the score never does.
class _RatingCuisineLine extends StatelessWidget {
  /// Null when too few reviews stand behind the score — the line then
  /// carries the cuisines alone rather than an unearned number.
  final double? rating;
  final String cuisines;

  const _RatingCuisineLine({required this.rating, required this.cuisines});

  @override
  Widget build(BuildContext context) {
    final double? rating = this.rating;

    return Row(
      children: [
        if (rating != null) ...[
          // 13 against the old 15: HugeIcon fills its whole size box, where a
          // Material glyph carries its own padding — see the sizing note in
          // food_home_screen's _FilterIconButton.
          const HugeIcon(
            icon: HugeIcons.strokeRoundedStar,
            size: 15,
            color: WaddyColors.mintInk,
          ),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Text(
            rating.toStringAsFixed(1),
            textDirection: TextDirection.ltr,
            style: waddyBold.copyWith(fontSize: 14, color: WaddyColors.ink),
          ),
          const _MetaDot(),
        ],
        Flexible(
          child: Text(
            cuisines,
            style: waddyMedium.copyWith(
              fontSize: 14,
              // Not inkMuted: that is the placeholder/disabled token and it is
              // 2.39:1 on white. The cuisines are content — what the place
              // actually serves — and read at 4.59:1 in inkLight instead.
              color: WaddyColors.inkLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// META LINE — fee · time · distance
// ═══════════════════════════════════════════

/// The comparison row: what delivery costs, how long it takes, how far it is.
///
/// The fee leads because it is the only one of the three that can be zero, and
/// a free delivery is the strongest reason to pick one row over its neighbour.
/// When it *is* free, the fee segment says nothing here — the mint "Free
/// Delivery" chip on the row below already carries that claim, and a struck-
/// through price beside it would just contradict the chip.
///
/// The line runs bare — no scooter or clock glyph. Two icons per row across a
/// full screen of results put a dozen grey pictograms down the left of the
/// meta block, and they labelled nothing the words did not: a duration reads
/// as a wait and a currency figure reads as a fee without being told. Dropping
/// them buys back the horizontal room the cuisine line and the offer chips
/// need, and leaves the block as plain comparable text.
///
/// Order is wait, then fee. The wait is the figure that actually varies across
/// this catalogue — every store currently charges the same delivery fee — so
/// it leads, and the fee follows as the tiebreak. Three steps of ink carry
/// that ranking: bold, full ink for the wait (the decision); medium, inkMid
/// for the fee (the tiebreak); medium, inkLight for the distance (context —
/// it settles nothing on its own).
class _MetaLine extends StatelessWidget {
  final Store store;

  const _MetaLine({required this.store});

  @override
  Widget build(BuildContext context) {
    final double? charge = store.minimumShippingCharge;
    final bool isFree = store.freeDelivery == true || charge == 0;

    final String? time = _deliveryTime;
    final String? distance = _distance;

    final children = <Widget>[];

    // Wait first — it is the number that separates these stores.
    if (time != null) {
      children.add(
        Text(
          time,
          style: waddyBold.copyWith(fontSize: 14, color: WaddyColors.ink),
        ),
      );
    }

    // Fee. Free delivery says nothing here as a number — the "Free Delivery"
    // chip on the row below carries that claim instead; a struck-through
    // price beside it would just contradict the chip.
    if (isFree) {
      // Nothing to add — the chip on the row below says it all.
    } else if (charge != null && charge > 0) {
      if (children.isNotEmpty) children.add(const _MetaDot());
      // Medium weight, not bold: the wait is the number that decides the
      // tap, the fee is the tiebreak, and giving both the same weight made
      // them read as one undifferentiated fact instead of a primary and a
      // secondary one. inkMid — a step above the grey distance takes — still
      // separates "a price" from "just context".
      children.add(
        Text(
          PriceConverter.convertPrice(charge),
          textDirection: TextDirection.ltr,
          style: waddyMedium.copyWith(fontSize: 14, color: WaddyColors.inkMid),
        ),
      );
    }
    // No charge published: say nothing rather than implying it is free.

    if (distance != null) {
      if (children.isNotEmpty) children.add(const _MetaDot());
      // inkLight, a step quieter than the fee's inkMid: three facts on this
      // line now step down in weight — bold ink (time, the decision), medium
      // inkMid (fee, the tiebreak), medium inkLight (distance, pure context).
      children.add(
        Text(
          distance,
          textDirection: TextDirection.ltr,
          style: waddyMedium.copyWith(
            fontSize: 14,
            color: WaddyColors.inkLight,
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox();

    // Shrink-wrapped: when Free Delivery rides this line, this Row and the
    // chip are two Flexibles in one Row, and a full-width Row here claimed
    // half of it — leaving the chip stranded mid-row, far from the time.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Clipping the row rather than wrapping it: these three facts belong on
        // one line, and a name long enough to squeeze them should cost the
        // distance, not a second row of meta.
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(children: children),
          ),
        ),
      ],
    );
  }

  String? get _deliveryTime {
    final raw = store.deliveryTime?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.contains('min') ? raw : '$raw ${'min'.tr}';
  }

  /// Distance, but only when it describes somewhere we could plausibly
  /// deliver from.
  ///
  /// The API returns a raw haversine against whatever coordinates the client
  /// sent, and it does not know that a 1,900km result means the device's real
  /// GPS disagreed with the selected address — a routine state while testing
  /// against a seeded zone, and a real one for anyone who picks a delivery
  /// address in another city. Printing that number tells the user the app has
  /// lost track of where they are.
  ///
  /// So the segment is dropped rather than clamped. `100+ km` is not a
  /// delivery state this product has — no rider covers it — so a capped
  /// number is just the absurd value wearing a hat. Fee and time still carry
  /// the row; the distance simply says nothing when it knows nothing.
  String? get _distance {
    final km = store.distance;
    if (km == null || km <= 0 || km > kMaxPlausibleDeliveryKm) return null;
    final text = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
    return '$text ${'km'.tr}';
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
      ),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: WaddyColors.inkMuted,
      ),
    );
  }
}

// ═══════════════════════════════════════════
// OFFER CHIPS
// ═══════════════════════════════════════════

/// Tinted chips for the promises that are worth money: a discount and free
/// delivery. Two tints only — amber for "you pay less", mint for "delivery is
/// on us" — so the eye can sort a screenful of rows by colour alone.
///
/// This is deliberately not [moduleStickersForStore]: those five rotated
/// ribbons ("Speedy", "Quick bites", "Hot deals", "Top rated"…) are decorations
/// restating facts the row already prints, and stacking them here would put
/// four badges under every popular store.
class _OfferChips extends StatelessWidget {
  final Store store;

  /// Whether this sits under the meta line (needs a gap above it) or beside
  /// it on the same row (the parent Row's own gap already separates them).
  final bool stackedBelowMeta;

  const _OfferChips({required this.store, this.stackedBelowMeta = true});

  @override
  Widget build(BuildContext context) {
    final discount = store.discount;
    final bool hasDiscount =
        discount?.discount != null && discount!.discount! > 0;
    final bool hasFreeDelivery =
        store.freeDelivery == true || store.minimumShippingCharge == 0;

    if (!hasDiscount && !hasFreeDelivery) return const SizedBox();

    // A Row, not a Wrap: there are at most two chips and they belong on one
    // line under the meta. A Wrap would silently make some rows a line taller
    // than their neighbours on a narrow screen, which is exactly the
    // ragged-height comparison this card was reshaped to avoid. Each chip is
    // Flexible instead, so a long discount label ellipses rather than wraps.
    return Padding(
      padding: EdgeInsets.only(
        top: stackedBelowMeta ? Dimensions.paddingSizeSmall : 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasDiscount)
            Flexible(
              child: OfferCollarBadge(
                label:
                    discount.discountType == 'percent'
                        ? '${discount.discount!.toInt()}% ${'off'.tr}'
                        : '${PriceConverter.convertPrice(discount.discount!)} ${'off'.tr}',
                tone: OfferCollarTone.sale,
                compact: true,
              ),
            ),
          if (hasDiscount && hasFreeDelivery)
            const SizedBox(width: Dimensions.paddingSizeSmall),
          if (hasFreeDelivery)
            Flexible(
              child: OfferCollarBadge(
                label: 'free_delivery'.tr,
                tone: OfferCollarTone.delivery,
                compact: true,
              ),
            ),
        ],
      ),
    );
  }
}

/// `NEW` — shown while a store has essentially no ratings behind it.
///
/// Mint tint, mint ink: it is the same "worth your attention" family as the
/// free-delivery chip, one step quieter because it promises nothing material.
/// It deliberately does not use the electric [WaddyColors.mint] — that colour
/// means "press this", and the badge is not a control.
class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: WaddyColors.mintSurface,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      child: Text(
        displayCaps('new'.tr),
        style: waddyBold.copyWith(
          fontSize: 10.5,
          color: WaddyColors.mintInk,
          letterSpacing: displayTracking(0.6),
        ),
      ),
    );
  }
}

/// Dims [child] for a closed store, and adds no layer for an open one.
///
/// `Opacity` renders its subtree to an offscreen buffer and composites it
/// back — at any value, including 1.0, where the result is identical to not
/// wrapping at all. In a scrolling list that is one wasted layer per visible
/// row, and the Mi 9T baseline is raster-bound (docs/performance_baseline.md
/// §9), so wasted layers are the thing to remove.
Widget _maybeDim({required bool isOpen, required Widget child}) {
  if (isOpen) return child;
  return Opacity(opacity: 0.55, child: child);
}
