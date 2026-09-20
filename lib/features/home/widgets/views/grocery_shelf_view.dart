import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/common/widgets/trailing_fade.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/common/widgets/staggered_entrance.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

// ── Design preview ───────────────────────────────────────────────────────────
// TEMPORARY. Flip to true, hot-reload, and the shelf fills with mock grocery
// stores so the layout can be reviewed before the real catalogue has more than
// one partner. Set back to false before shipping — and note it is inert in
// release builds regardless, so a forgotten `true` cannot reach users.
//
// Same discipline as the ranked chart's preview in top_restaurants_view.dart:
// the mocks are deliberately awkward rather than flattering. There is a name
// long enough to truncate, a closed store, a store with no rating at all, one
// with no perk, and one with no distinct logo — so the card's empty-slot paths
// and its logo-chip fallback are all on screen at once. A preview built only
// from tidy data hides exactly the cases that break a layout.
//
// Caveat: the parent section returns early when the zone has no grocery stores
// at all, so the preview needs at least one real store to render on top of.
const bool kPreviewGroceryShelf = false;

// ── Aisles vs. stores ────────────────────────────────────────────────────────
// Which question this section leads with.
//
// false (current): the grocery STORES, as cards on the shelf. This is what the
// band is for — "Groceries in minutes" over three named stores with their ETAs
// is a row the user can act on.
//
// true: the aisle grid — Fresh Produce, Milk, Deli — with the store demoted to
// a byline. The argument for it is real (groceries are chosen by need, not by
// brand) and the code is kept whole below so it can be switched back in one
// line, but it asks the catalogue for eight pieces of category art that mostly
// do not exist yet, so seven of eight tiles render as the placeholder W. A grid
// of placeholders answers neither question.
const bool kGroceryShelfAisles = false;

/// Swaps in mock stores when the preview flag is on. Returns [stores]
/// untouched in release or when the flag is off.
List<Store>? _previewOverride(List<Store>? stores) {
  if (!kDebugMode || !kPreviewGroceryShelf) return stores;
  return _mockGroceryStores();
}

/// Cover photo per mock card, index-matched to the names in
/// [_mockGroceryStores]. Swap any entry for your own image URL and hot-reload;
/// the list only needs to stay the same length as the names.
const List<String> _mockGroceryCovers = [
  'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600&q=70',
  'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=600&q=70',
  'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=600&q=70',
  'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?w=600&q=70',
  'https://images.unsplash.com/photo-1573246123716-6b1782bfc499?w=600&q=70',
  'https://images.unsplash.com/photo-1584473457406-6240486418e9?w=600&q=70',
  'https://images.unsplash.com/photo-1607349913338-fca6f7fc42d0?w=600&q=70',
];

/// Logo per mock card, index-matched to the names. Index 5 is deliberately
/// blank: that store exercises the "no distinct logo, hide the chip" path.
const List<String> _mockGroceryLogos = [
  'https://api.dicebear.com/7.x/initials/png?seed=Gourmet&backgroundColor=1D706A&size=128',
  'https://api.dicebear.com/7.x/initials/png?seed=Seoudi&backgroundColor=E84D4D&size=128',
  'https://api.dicebear.com/7.x/initials/png?seed=Metro&backgroundColor=134E4A&size=128',
  'https://api.dicebear.com/7.x/initials/png?seed=Kazyon&backgroundColor=0A7A50&size=128',
  'https://api.dicebear.com/7.x/initials/png?seed=Carrefour&backgroundColor=1D706A&size=128',
  '',
  'https://api.dicebear.com/7.x/initials/png?seed=Oscar&backgroundColor=E84D4D&size=128',
];

/// Seven fake grocery partners for [kPreviewGroceryShelf], named after chains
/// that actually trade in Maadi so the card widths are tested against real
/// name lengths rather than lorem.
///
/// The awkward cases are spread on purpose:
///   index 2 — name long enough to truncate at 150pt
///   index 3 — no rating (meta line falls back to the ETA alone)
///   index 4 — closed store (scrim, no perk, no badge)
///   index 5 — no logo (chip hidden) and no perk at all (empty perk row)
///   index 6 — rating but no ETA
List<Store> _mockGroceryStores() {
  const List<String> names = [
    'Gourmet Egypt',
    'Seoudi Market',
    'Metro Market Degla', // long: tests truncation
    'Kazyon',
    'Carrefour Maadi',
    'Zahran Market',
    'Oscar Grocery',
  ];
  const List<double> ratings = [4.8, 4.6, 4.4, 0, 4.5, 4.2, 4.7];
  const List<String> times = [
    '20-30 min',
    '25-35 min',
    '30-45 min',
    '15-25 min',
    '35-50 min',
    '30-40 min',
    '',
  ];
  const List<double> metres = [900, 1600, 2400, 700, 3800, 2100, 1300];

  return [
    for (int i = 0; i < names.length; i++)
      Store(
        id: -(i + 101), // negative ids so a stray tap can't open a real store
        name: names[i],
        avgRating: ratings[i],
        ratingCount: 640 - (i * 70),
        deliveryTime: times[i],
        distance: metres[i],
        // Every third store gets money off and the next one free delivery, so
        // both pill styles and the bare-distance perk all appear in one screen.
        discount:
            i % 3 == 0
                ? Discount(discount: 10 + (i * 5), discountType: 'percent')
                : null,
        freeDelivery: i % 3 == 1,
        open: i == 4 ? 0 : 1, // one closed store
        active: true,
        coverPhotoFullUrl: _mockGroceryCovers[i],
        logoFullUrl: _mockGroceryLogos[i],
      ),
  ];
}

/// "Groceries in minutes" — the aisles, not the aisles' owner.
///
/// The section spent several passes as a rail of store cards, and every pass
/// hit the same wall: the chart directly above it is *also* a rail of store
/// cards, so the two read as one long list with a heading dropped in the
/// middle. Decoration could not fix that — a mint band, a teal plank and a set
/// of animated bolts were each in turn asked to make a duplicate feel like a
/// distinct section, and each just added noise on top of the duplication.
///
/// The fix was to change the question. Restaurants are chosen by brand, so a
/// ranking of places is the right shape for the chart. Groceries are chosen by
/// *need* — milk, bread, eggs — so this section leads with aisles and demotes
/// the store to a byline under the headline. Same catalogue underneath, but the
/// user answers "what do I need" before "from where", which is the order they
/// were already thinking in.
///
/// That is the design [kGroceryShelfAisles] turns on, and it is currently off:
/// the aisle art the grid needs is missing for all but one category, so the
/// stores lead instead. Either way the store cards also carry the zone with no
/// category data at all — a grid of nothing is worse than a rail of something.
///
/// [stores] null means loading (shimmer); empty hides the section entirely.
class GroceryShelfView extends StatelessWidget {
  final List<Store>? stores;
  final String headline;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final int maxItems;

  const GroceryShelfView({
    super.key,
    required this.stores,
    required this.headline,
    this.subtitle,
    this.onSeeAll,
    this.maxItems = 10,
  });

  @override
  Widget build(BuildContext context) {
    final List<Store>? source = _previewOverride(stores);
    if (source != null && source.isEmpty) return const SizedBox.shrink();

    final List<Store> shown =
        source == null ? const <Store>[] : source.take(maxItems).toList();
    final int count = source == null ? _kShimmerUnits : shown.length;

    return GetBuilder<CategoryController>(
      builder: (categoryController) {
        // groceryAisles, never categoryList. The dashboard has no module
        // selected, so categoryList holds whatever module the user last
        // visited — after one trip into Food this grid was a wall of Pasta,
        // Pizza and Desserts under a "Groceries in minutes" headline, and
        // every tile opened a food category from a screen that is not in the
        // food module. This list is fetched with the grocery module id pinned
        // in the header, so it can only ever be grocery.
        final List<CategoryModel> aisles =
            categoryController.groceryAisles ?? const <CategoryModel>[];
        final int? aisleModuleId = categoryController.groceryModuleId;
        final bool showAisles = kGroceryShelfAisles && aisles.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShelfHeader(
              headline: headline,
              // Under the aisle grid the header is the only place the store
              // is named, so it carries the story line — "Snack Wagon · 30-60
              // min" is a fact the user can act on. Over the store rail that
              // same line only counts the cards sitting directly beneath it,
              // so the section's own tagline is worth more.
              subtitle: showAisles ? _storyLine(shown, subtitle) : subtitle,
              onSeeAll: onSeeAll,
            ),
            if (showAisles)
              _AisleGrid(
                categories: aisles,
                moduleId: aisleModuleId,
                onSeeAll: onSeeAll,
              )
            else
              // The stores themselves. Same trailing softener the restaurant
              // chart uses. Without it
              // this rail cut the third card's *name* at the screen edge
              // ("Metro M…") while the rail directly above faded — two rails
              // on one screen disagreeing about whether an edge means "more"
              // or "broken".
              TrailingFade(
                child: SizedBox(
                  height: _shelfHeight(context),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                    ),
                    itemCount: count,
                    separatorBuilder:
                        (_, __) => const SizedBox(width: _kUnitGap),
                    itemBuilder:
                        (context, index) =>
                            source == null
                                ? const _ShelfUnitShimmer()
                                : StaggeredEntrance(
                                  index: index,
                                  child: _ShelfUnit(store: shown[index]),
                                ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "Snack Wagon · 30-60 min", or the count when several stores are stocking.
/// Falls back to [fallback] before the store list has arrived.
String? _storyLine(List<Store> stores, String? fallback) {
  if (stores.isEmpty) return fallback;
  if (stores.length > 1) {
    return '${stores.length} ${'stores'.tr}';
  }
  final Store store = stores.first;
  final String name = store.name ?? '';
  final String? time =
      (store.deliveryTime?.isNotEmpty ?? false) ? store.deliveryTime : null;
  if (name.isEmpty) return fallback;
  if (time == null) return name;
  // Same unit fix-up the card's meta line does: the backend writes the ETA
  // both as "30-60 min" and as a bare "30-60", and a duration with no unit
  // under a headline that promises minutes is a number the reader has to
  // guess at.
  return '$name · ${time.contains('min') ? time : '$time ${'min'.tr}'}';
}

// ── Shelf metrics ────────────────────────────────────────────────────────────
// One "unit" is a whole store card — photo tile *and* its text — standing on
// the board as a single object.
//
// The board used to run between the tile and the text, which is the one place
// it must never go: a shelf drawn through the middle of a card cuts the name
// and rating away from the photo they describe, and the text below it then
// reads as loose type lying on the page rather than as part of the card. The
// plank belongs under the card's feet, not through its waist.
//
// Every height below is fixed rather than intrinsic, because the board is
// painted once behind the whole row: a card that sized itself to its content
// would stand at its own height and the plank would meet each card at a
// different point. Fixed blocks are what keep every card's base on one line.
// How much of the third unit shows past the second — the same fraction the
// ranked rail solves for, so the two rails on one screen agree about what a
// peek looks like.
const double _kUnitPeek = 0.34;
const double _kUnitGap = Dimensions.paddingSizeMedium;
const double _kTileSize = 122; // the "product" — store photo tile
const double _kTextTop = 9; // tile to the card's text block
// 22, following the name up from 15 to 16pt. At 16/1.25 the line box is
// exactly 20 — the same as the old block — and a fixed row that is exactly as
// tall as the text it boxes does not clip visibly, it silently shaves the
// descenders off every 'g' and 'y' in the rail. Matches the chart's
// _kRankNameBlock, which boxes the identical type.
const double _kNameBlock = 22;
const double _kRowGap = 5;
const double _kMetaBlock = 18;
const double _kPerkBlock = 17;
// Card base to board face. Zero on purpose: the plank is what the card stands
// *on*, and any gap here reads as the board floating below the stock rather
// than carrying it. The visual separation comes from the board's own colour
// against the wash, not from air.
const double _kProductLift = 0;
const double _kBoardHeight = 9; // the plank itself
const double _kBoardLip = 3; // front edge, darker — reads as thickness
const double _kBoardTotal = _kBoardHeight + _kBoardLip;

/// Unit width, solved from the viewport so the rail always lands on two full
/// cards plus a [_kUnitPeek] sliver of the third.
///
/// This used to be a flat 150, which was tuned on a ~390pt phone and only
/// looked deliberate there. Measured across the range the app actually ships
/// on, a fixed 150 gives a 0.11 peek at 360pt — a sliver so thin it reads as a
/// card that got clipped — and 0.57 at 430pt, a half-card that reads as a
/// layout bug. Solving for the width instead pins the composition and lets the
/// card flex, exactly as `_rankCardWidth` does for the restaurant rail.
///
/// The clamp is what stops the solve from going silly on a tablet or a narrow
/// phone; inside the clamp the peek is exact.
double _unitWidth(BuildContext context) {
  final double viewport = MediaQuery.sizeOf(
    context,
  ).width.clamp(0.0, Dimensions.maxContentWidth);
  // Leading padding only — the trailing one is off-screen at the far end.
  final double usable =
      viewport - Dimensions.paddingSizeDefault - _kUnitGap * 2;
  return (usable / (2 + _kUnitPeek)).clamp(132.0, 176.0);
}

/// How much the fixed text blocks grow with the user's font-size setting.
///
/// The blocks above are measured at 1.0x, but the type inside them scales with
/// the OS setting — so at a large accessibility size the name needs 24.4pt of
/// a 20pt box and the meta row 21.9 of 18, and the first things to go are the
/// store name's descenders and then the perk row entirely.
///
/// Ceiling of 1.3 matches the restaurant rail's `_rankTextScale`, for the same
/// reason stated there: the rail is horizontal and every card shares one
/// height, so unbounded growth would push the shelf off the fold to serve a
/// setting most users never reach. Past 1.3 the rows ellipsize, which is the
/// honest failure for a browse surface.
double _shelfTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3);

/// Full height of one card, tile through perk row. The board hangs directly
/// beneath this, so the whole card stands on the plank.
///
/// A function rather than a const because the three text blocks have to follow
/// the user's font size. The photo tile and the row gaps deliberately do not:
/// scaling the *image* with the type would shrink the number of cards on
/// screen for no legibility gain.
double _cardHeight(BuildContext context) {
  final double t = _shelfTextScale(context);
  return _kTileSize +
      _kTextTop +
      (_kNameBlock + _kMetaBlock + _kPerkBlock) * t +
      _kRowGap * 2;
}

/// Where the board's top edge sits inside the shelf stack — under the card's
/// base, so the card appears to rest on it.
///
/// This is why the heights above cannot simply be left fixed and allowed to
/// clip: the plank is painted at this offset behind the whole row, so if the
/// cards grow and the board does not, every card floats above its own shelf.
double _boardTop(BuildContext context) => _cardHeight(context) + _kProductLift;

double _shelfHeight(BuildContext context) => _boardTop(context) + _kBoardTotal;

// Palette — Waddi tokens only. The board is the teal pair (400 face over the
// deeper primary lip). It deliberately does *not* use WaddyColors.mint: that
// electric mint is the CTA colour, and spending it on decorative furniture
// makes the plank read as a control the user could press.
const Color _kPlateBg = WaddyColors.mintSurface;
const Color _kTileBorder = WaddyColors.divider;
const Color _kNameInk = WaddyColors.ink;
// inkLightOnMint, not inkLight: every card in this shelf sits inside
// _GrocerySection's mintSurface band (module_view.dart), and inkLight only
// clears WCAG AA (4.5:1) on plain white — on mintSurface it drops to 4.28:1.
const Color _kMetaInk = WaddyColors.inkLightOnMint;
// Ink, not the pressed-surface step — see the same constant in
// top_restaurants_view.dart. coralDark on coralSurface is 3.34:1 at 12sp.
const Color _kSale = WaddyColors.coralInk;

const int _kShimmerUnits = 3;

/// Section header: title, the store the aisles belong to, and the way through
/// to everything else.
///
/// The animated bolts that used to sit between the title and the arrow are
/// gone. They were decoration filling a gap rather than information: three
/// low-contrast marks on a mint wash, restating in a weak medium exactly what
/// the words "in minutes" already said outright. A header earns motion when the
/// motion carries something the type cannot, and this one never did.
class _ShelfHeader extends StatelessWidget {
  final String headline;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  const _ShelfHeader({required this.headline, this.subtitle, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        0,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeMedium,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headline,
                  style: waddyRailHeadline.copyWith(color: _kNameInk),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: kRailSubtitleGap),
                  Text(
                    subtitle!,
                    style: waddyRailSubtitle.copyWith(color: _kMetaInk),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null) ...[
            const SizedBox(width: Dimensions.paddingSizeMedium),
            Pressable(
              onTap: onSeeAll,
              semanticLabel: 'see_all'.tr,
              scale: WaddyMotion.pressControl,
              // The circle stays 40 — sized to the header's optical weight,
              // not to the thumb — and the hit box grows to the platform
              // minimum underneath it. Same treatment the chart's arrow
              // already had; this one was left an under-sized target on the
              // sole entry point to the grocery catalogue.
              minSize: Dimensions.minTapTarget,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: WaddyColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRtl
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  size: 20,
                  color: WaddyColors.ink,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The aisle grid: what the user is actually shopping for.
///
/// This is the section's whole reason to exist. Everything above it on the feed
/// is a *ranking of places* — the chart asks "who is best", and rendering
/// grocery the same way asked the same question twice, which is why the section
/// read as filler no matter how it was decorated. Nobody opens an app for
/// groceries thinking "which supermarket"; they think "milk, bread, eggs".
/// Aisles answer that question, and a store card cannot.
///
/// So the store stops being the subject and becomes the byline: it is named
/// once, quietly, under the headline, and the aisles get the space. The tap
/// still lands in the same catalogue either way — this only changes which
/// question the user answers first.
///
/// Two rows of four on a fixed grid rather than a scrolling rail, because a
/// short closed set is exactly what makes this scannable: eight aisles the eye
/// takes in at once beat twenty that have to be dragged past. The eighth tile
/// is always the way through to the rest.
class _AisleGrid extends StatelessWidget {
  final List<CategoryModel> categories;

  /// The module these aisles belong to, so a tap can switch into it first.
  final int? moduleId;
  final VoidCallback? onSeeAll;

  const _AisleGrid({required this.categories, this.moduleId, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    // Seven aisles plus an "all" tile. Fewer is fine — the grid simply gets
    // shorter — but the all-tile is always last so the way out never moves.
    final int shown =
        categories.length > _kAisleMax ? _kAisleMax : categories.length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double tile =
              (constraints.maxWidth - (_kAisleGap * (_kAisleCols - 1))) /
              _kAisleCols;

          return Wrap(
            spacing: _kAisleGap,
            runSpacing: _kAisleGap,
            children: [
              for (int i = 0; i < shown; i++)
                StaggeredEntrance(
                  index: i,
                  child: _AisleTile(
                    category: categories[i],
                    moduleId: moduleId,
                    width: tile,
                  ),
                ),
              if (onSeeAll != null)
                StaggeredEntrance(
                  index: shown,
                  child: _AisleAllTile(width: tile, onTap: onSeeAll!),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One aisle: its picture on a white plate, its name underneath.
///
/// White plate on the mint wash, not mint on mint. The old cards were white
/// bordered in mint sitting on a mint band, so nothing in the section had any
/// edge and the whole thing read as one soft rectangle; the plate has to be the
/// lightest thing here for the grid to have any structure at all.
class _AisleTile extends StatelessWidget {
  final CategoryModel category;
  final int? moduleId;
  final double width;

  const _AisleTile({
    required this.category,
    required this.moduleId,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final String name = category.name ?? '';

    return Pressable(
      onTap: () => _openAisle(category, name, moduleId),
      semanticLabel: name,
      scale: WaddyMotion.pressTile,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: width,
              height: width,
              padding: const EdgeInsets.all(_kAislePad),
              decoration: BoxDecoration(
                color: WaddyColors.surface,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                boxShadow: const [
                  BoxShadow(
                    color: WaddyColors.shadowTeal,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              // `contain`: category art is packshots and illustrations on their
              // own ground, and cropping one to fill a square cuts the product
              // in half.
              child: CustomImage(
                image: category.imageFullUrl ?? '',
                variants: category.imageVariants,
                decodeWidth: width,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: _kAisleLabelGap),
            SizedBox(
              height: _kAisleLabel * _shelfTextScale(context),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: waddyBold.copyWith(
                  fontSize: 11.5,
                  height: 1.2,
                  color: WaddyColors.ink,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The last tile: everything the grid did not have room for. Deliberately not a
/// picture — an arrow on a tinted plate reads as a door rather than as a ninth
/// aisle the user might mistake for a product.
class _AisleAllTile extends StatelessWidget {
  final double width;
  final VoidCallback onTap;

  const _AisleAllTile({required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    return Pressable(
      onTap: onTap,
      semanticLabel: 'see_all'.tr,
      scale: WaddyMotion.pressTile,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: width,
              height: width,
              decoration: BoxDecoration(
                color: WaddyColors.surface,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                border: Border.all(color: WaddyColors.primary, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                isRtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                size: 22,
                color: WaddyColors.primary,
              ),
            ),
            const SizedBox(height: _kAisleLabelGap),
            SizedBox(
              height: _kAisleLabel * _shelfTextScale(context),
              child: Text(
                'see_all'.tr,
                textAlign: TextAlign.center,
                style: waddyBold.copyWith(
                  fontSize: 11.5,
                  height: 1.2,
                  color: WaddyColors.primary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Aisle grid metrics ───────────────────────────────────────────────────────
const int _kAisleCols = 4;
const int _kAisleMax = 7; // + the all-tile makes two full rows
// Both on the 4pt grid (see [Dimensions]). They were 10 and 10 — a value that
// belongs to no scale in the app, sitting inside the one section that already
// borrows the module grid's plate, radius and shadow. A gutter half a step off
// the grid is not visible on its own; it is visible as this band never quite
// lining up with the tiles above it.
const double _kAisleGap = Dimensions.paddingSizeMedium;
const double _kAislePad =
    Dimensions.paddingSizeMedium; // art never touches its own plate edge
const double _kAisleLabel = 28; // two lines at 11.5/1.2, fixed so rows align
/// Plate to its own label — the tightest seam in the section, and deliberately
/// tighter than [_kAisleGap] between tiles. A label sitting closer to its own
/// picture than to the neighbouring tile is the only thing telling the eye
/// which of four captions belongs to which of four plates.
const double _kAisleLabelGap = Dimensions.paddingSizeSmall;

/// One store standing on the shelf: photo tile, then the same three text rows
/// the restaurant chart uses — name, `★ rating • time`, perk.
///
/// Tile and text are one object sitting on the plank. The text is not a price
/// tag hanging off the board and not a caption printed under it: a tag holds
/// two short lines, and a store needs four facts. Keeping the rows attached to
/// their own photo is what makes the name and rating read as *this store's*
/// rather than as loose type the shelf happens to sit above.
class _ShelfUnit extends StatelessWidget {
  final Store store;

  const _ShelfUnit({required this.store});

  @override
  Widget build(BuildContext context) {
    final String name = store.name ?? '';
    final double rating = store.avgRating?.toDouble() ?? 0;
    final bool closed = store.open == 0 || store.active == false;
    final _Perk? perk = _perkFor(store);

    return Pressable(
      onTap: () => _openStore(store),
      semanticLabel: _semantics(store, name, rating, closed, perk),
      scale: WaddyMotion.pressTile,
      child: SizedBox(
        width: _unitWidth(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _kTileSize,
              child: _ProductTile(store: store, closed: closed),
            ),
            const SizedBox(height: _kTextTop),

            SizedBox(
              height: _kNameBlock * _shelfTextScale(context),
              width: double.infinity,
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  // w700 matches the chart's card title: heaviest thing on its
                  // own card, one step below the section headline above it.
                  fontWeight: FontWeight.w700,
                  // 16, matching the chart's card title. Both rails solve for
                  // the same card width (same peek fraction, same clamp), so
                  // the cards come out identically wide — the 15 here was not
                  // compensating for a tighter box, it was just drift, and it
                  // put two different title sizes in two equal-width cards a
                  // section apart on one screen.
                  fontSize: 16,
                  height: 1.25,
                  letterSpacing: -0.15,
                  color: closed ? _kMetaInk : _kNameInk,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: _kRowGap),

            // "★ 4.6 • 30-60 min" — the two numbers that decide the tap. The
            // badge carries the only colour so the line stays one solid ink.
            SizedBox(
              height: _kMetaBlock * _shelfTextScale(context),
              child: Row(
                children: [
                  if (rating > 0 && !closed) ...[
                    const _RatingBadge(),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      closed ? 'closed_now'.tr : _metaLine(store, rating),
                      style: const TextStyle(
                        fontFamily: AppConstants.fontFamily,
                        fontWeight: FontWeight.w600,
                        // 13, matching the chart's meta line. _kMetaBlock (18)
                        // was already sized for 13/1.35 = 17.6, so the box was
                        // built for this size and only the type had drifted.
                        fontSize: 13,
                        height: 1.35,
                        letterSpacing: 0,
                        color: _kMetaInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _kRowGap),

            // Perk line: the reason to pick this store over the next one.
            // Money-off perks wear a tinted pill; plain facts stay quiet.
            SizedBox(
              height: _kPerkBlock * _shelfTextScale(context),
              child:
                  (perk == null || closed)
                      ? null
                      : Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          padding:
                              perk.bg == null
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                          decoration:
                              perk.bg == null
                                  ? null
                                  : BoxDecoration(
                                    color: perk.bg,
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusSmall,
                                    ),
                                  ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(perk.icon, size: 12, color: perk.color),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  perk.label,
                                  style: waddyBold.copyWith(
                                    fontSize: 11,
                                    height: 1.3,
                                    color: perk.color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The standing product: the store's photo on a plate with a contact shadow,
/// so it reads as resting on the board rather than pasted over it.
///
/// Cover photo leads, logo rides the bottom-start corner — the chart's own
/// arrangement. The earlier shelf led with the logo and dropped the cover
/// entirely, which is why every unit looked like an app icon in a row of app
/// icons instead of a shop.
class _ProductTile extends StatelessWidget {
  final Store store;
  final bool closed;

  const _ProductTile({required this.store, required this.closed});

  @override
  Widget build(BuildContext context) {
    final String cover = store.coverPhotoFullUrl ?? '';
    final String? logo = store.logoFullUrl;

    return SizedBox(
      width: _unitWidth(context),
      height: _kTileSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _kPlateBg,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                border: Border.all(color: _kTileBorder),
                boxShadow: const [
                  // Tight and low: a contact shadow, not a drop shadow. It only
                  // has to say "this object is sitting on that plank".
                  BoxShadow(
                    color: WaddyColors.shadowTeal,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge - 1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomImage(
                      image: cover,
                      // The right-sized WebP rung instead of whatever the
                      // merchant uploaded. The tile is ~150pt wide; without
                      // this it pulls the full-resolution original.
                      variants: store.coverPhotoVariants,
                      decodeWidth: _unitWidth(context),
                      fit: BoxFit.cover,
                    ),
                    if (closed)
                      Container(
                        color: WaddyColors.ink.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: Text(
                          'closed_now'.tr,
                          style: waddyBold.copyWith(
                            fontSize: 11,
                            color: WaddyColors.surface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Logo chip on the bottom-start corner — the chart's placement, so a
          // grocery tile and a restaurant tile are read the same way.
          //
          // Dropped entirely when the store has no distinct logo. Falling back
          // to the cover put the same artwork on the tile twice, once large and
          // once as a 32pt thumbnail of itself, which reads as a rendering bug
          // rather than as branding.
          if (logo != null && logo.isNotEmpty && logo != cover)
            PositionedDirectional(
              bottom: Dimensions.paddingSizeSmall,
              start: Dimensions.paddingSizeSmall,
              child: Container(
                width: _kLogoChip,
                height: _kLogoChip,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: WaddyColors.surface,
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  // Teal hairline, not white-on-white. The old border was the
                  // chip's own fill colour, which draws nothing and only acted
                  // as 1.5pt of extra padding — so the shelf's chip had no edge
                  // while the chart's chip 200pt above it had a crisp one. A
                  // white mark on a pale cover photo needs the edge to stay a
                  // chip rather than dissolving into the artwork.
                  border: Border.all(color: WaddyColors.primary, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: WaddyColors.shadowDeep,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    Dimensions.radiusDefault - 2,
                  ),
                  // `contain`, not `cover`: grocery partners brand themselves
                  // with square marks whose type runs to the artwork's own edge,
                  // and cropping one to fill eats the wordmark.
                  child: CustomImage(
                    image: logo,
                    variants: store.logoVariants,
                    decodeWidth: _kLogoChip,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Matches the chart's [_kRankLogo]. The two chips sit one section apart on
/// the same screen and are the same object — a store's mark on a store's
/// photo — so a 2pt difference reads as one of them being slightly wrong
/// rather than as two sizes chosen for two purposes.
const double _kLogoChip = 30;

/// Filled mint disc with a white star — the meta row's only splash of colour,
/// so "4.6 • 30-60 min" can stay one solid line of ink. Matches the chart's
/// badge exactly; the two sections have to agree on what a rating looks like.
class _RatingBadge extends StatelessWidget {
  const _RatingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      decoration: const BoxDecoration(
        color: WaddyColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.star_rounded, size: 11, color: WaddyColors.mint),
    );
  }
}

/// One perk line: icon + label in the colour that says what kind of perk it is.
/// [bg] turns it into a tinted pill — offers get one, plain facts don't.
class _Perk {
  final IconData icon;
  final String label;
  final Color color;
  final Color? bg;

  const _Perk({
    required this.icon,
    required this.label,
    required this.color,
    this.bg,
  });
}

/// "4.6 • 30-60 min" — the two numbers that decide the tap, each part dropped
/// when the backend didn't send it.
String _metaLine(Store store, double rating) {
  final parts = <String>[];
  if (rating > 0) parts.add(rating.toStringAsFixed(1));

  final String? time = store.deliveryTime;
  if (time != null && time.isNotEmpty) {
    parts.add(time.contains('min') ? time : '$time ${'min'.tr}');
  }
  // A grocery store with neither rating nor ETA still has to say something,
  // and "fast delivery" is the section's own promise rather than a blank row.
  if (parts.isEmpty) return 'groceries_fast'.tr;
  return parts.join(' • ');
}

/// The single perk worth a line, best offer first: percentage discount, then
/// free delivery, then how far the store actually is.
_Perk? _perkFor(Store store) {
  final double discount = store.discount?.discount ?? 0;
  if (discount > 0 && store.discount?.discountType == 'percent') {
    return _Perk(
      icon: Icons.local_offer_rounded,
      label: '${discount.toInt()}% ${'off'.tr}',
      color: _kSale,
      bg: WaddyColors.coralSurface,
    );
  }
  if (store.freeDelivery == true) {
    // No `bg` here, unlike the discount above. This section's whole band is
    // painted mintSurface (see _GrocerySection in module_view.dart), so a
    // mintSurface pill is the band's own colour on the band — a 1.0:1 pill
    // that renders and cannot be seen. The perk read as bare text next to an
    // identical-class coral pill on the neighbouring card, which teaches the
    // eye that the pill styling means nothing.
    //
    // mintInk on the band is 5.37:1 and is the token's documented job
    // (light_theme.dart) — mint as a glyph on paper rather than mint as a
    // surface. A white plate would also clear the band, but on a mint wash a
    // pill that has to be white to exist is fighting the surface it sits on.
    return _Perk(
      icon: Icons.delivery_dining_rounded,
      label: 'free_delivery'.tr,
      color: WaddyColors.mintInk,
    );
  }
  final double km = (store.distance ?? 0) / 1000;
  if (km > 0) {
    return _Perk(
      icon: Icons.place_rounded,
      label: '${km.toStringAsFixed(km < 10 ? 1 : 0)} ${'km'.tr}',
      color: WaddyColors.primaryLight,
    );
  }
  return null;
}

/// Screen readers get the perk too. On the card it is a pill the eye skims;
/// spoken, it has to be part of the same sentence or it is lost.
String _semantics(
  Store store,
  String name,
  double rating,
  bool closed,
  _Perk? perk,
) {
  final parts = <String>[name];
  if (closed) {
    parts.add('closed_now'.tr);
  } else {
    parts.add(_metaLine(store, rating));
    if (perk != null) parts.add(perk.label);
  }
  return parts.join(', ');
}

/// Loading state built to the shelf's exact metrics — the board is drawn for
/// real even while stock is loading, because an empty shelf is a truthful
/// picture of "still stocking" and a grey rectangle is not.
class _ShelfUnitShimmer extends StatelessWidget {
  const _ShelfUnitShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _unitWidth(context),
      child: Shimmer(
        duration: const Duration(seconds: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _unitWidth(context),
              height: _kTileSize,
              decoration: BoxDecoration(
                color: _kPlateBg,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              ),
            ),
            const SizedBox(height: _kTextTop),
            Container(
              height: 13,
              width: 104,
              decoration: BoxDecoration(
                color: _kPlateBg,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
            ),
            SizedBox(
              height: _kNameBlock * _shelfTextScale(context) - 13 + _kRowGap,
            ),
            Container(
              height: 11,
              width: 78,
              decoration: BoxDecoration(
                color: _kPlateBg,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens one aisle, in its own module.
///
/// The module has to be set first for the same reason [_openStore] sets it:
/// the dashboard has none, and the category-items screen fetches with
/// whatever module id the client header carries. Without this the tile either
/// came back empty or — worse, while these tiles were being fed from the last
/// visited module's list — quietly answered with that module's catalogue.
void _openAisle(CategoryModel category, String name, int? moduleId) {
  Get.find<SplashController>().activateModuleFor(moduleId);
  Get.toNamed(RouteHelper.getCategoryItemRoute(category.id, name));
}

/// Same module-activation dance the rails do: the dashboard has no module
/// selected, so one has to be set before the store route will resolve.
void _openStore(Store store) {
  Get.find<SplashController>().activateModuleFor(store.moduleId);
  Get.toNamed(
    RouteHelper.getStoreRoute(id: store.id, page: 'module'),
    arguments: StoreScreen(store: store, fromModule: true),
  );
}
