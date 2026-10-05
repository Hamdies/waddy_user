import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/common/models/image_variants.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/trailing_fade.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/screens/food_store_screen.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/common/widgets/staggered_entrance.dart';

// ── Design preview ───────────────────────────────────────────────────────────
// TEMPORARY. Flip to true, hot-reload, and the ranked rails fill with mock
// restaurants so the chart layout can be reviewed before the real catalogue
// reaches four. Set back to false before shipping — and note it is inert in
// release builds regardless, so a forgotten `true` cannot reach users.
//
// The mocks are deliberately awkward rather than flattering: a name long enough
// to truncate, a closed kitchen, ranks into double digits, and rows with no
// offer at all. A preview built only from tidy data hides exactly the cases
// that break a layout.
//
// Caveat: the rail's parent section returns early when the zone has no stores
// at all, so the preview needs at least one real store to render on top of.
const bool kPreviewRankedChart = false;

/// Swaps in mock stores when the preview flag is on. Returns [stores]
/// untouched in release, when the flag is off, or on unranked rails.
List<Store>? _previewOverride(List<Store>? stores, bool ranked) {
  if (!kDebugMode || !kPreviewRankedChart || !ranked) return stores;
  return _mockChartStores();
}

/// Cover photo per mock card, index-matched to [_mockNames]. Placeholder
/// services fill these in by default — swap any entry for your own image URL
/// and hot-reload; the list only needs to stay the same length as the names.
const List<String> _mockCoverUrls = [
  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRR7353yzpmgL9uLcDcKCIgj7MwO8B6mLobibBR9czHW9EEYJ6p6_m-7yw&s=10',
  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTbMAD9PxG2fK3NgUB1Es7pOBgcnRnyXmWJKGmSqIrhGbUZIwDkMr2HDyw&s=10',
  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR_MN6hAYxa0fDg0uQKKiEJFQiPxKq20UgtsHaqZvImjK58nImvOIznU6t6&s=10',
  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQSfXGgPD9yw6zlCtc6P-K0t3zapeh7gpPT04mqqwP1I_ilf87oB6i2naux&s=10',
  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcScYo4qUhZ3kfx0xYqHGHbURoy_ZioO71Gs18hPyDyoJQ&s=10',
  'https://picsum.photos/seed/waddi-spot-5/400/400',
  'https://picsum.photos/seed/waddi-spot-6/400/400',
  'https://picsum.photos/seed/waddi-spot-7/400/400',
  'https://picsum.photos/seed/waddi-spot-8/400/400',
  'https://picsum.photos/seed/waddi-spot-9/400/400',
];

/// Logo per mock card, index-matched to [_mockNames]. Same deal — replace
/// with real logo URLs whenever you have them.
const List<String> _mockLogoUrls = [
  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTBTk8bVQykaqy-nqdi2spQGlBjexcmRQelxeXeSfwTLFPLLHtMRN3bzE2I&s=10',
  'https://www.marefa.org/w/images/thumb/b/bf/KFC_logo.svg/1200px-KFC_logo.svg.png',
  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRjKBct3iWnAOUY9T_yBuoHW936J0EkSeKjC70Ynl5_xg&s=10',
  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQgvHErLD_NlgJhDuIwurMVdUaMrJJcYgnArOrZouUb2kDAwqZ-n1ebYaU&s=10',
  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQdpgGv96fXRArdkcx0WZTpkFqLEEhtU6KFaC8KbAKWikwRmHuDebjv757_&s=10',
  'https://api.dicebear.com/7.x/initials/png?seed=Mince&size=128',
  'https://api.dicebear.com/7.x/initials/png?seed=CookDoor&size=128',
  'https://api.dicebear.com/7.x/initials/png?seed=LeftBank&size=128',
  'https://api.dicebear.com/7.x/initials/png?seed=Crave&size=128',
  'https://api.dicebear.com/7.x/initials/png?seed=Tabali&size=128',
];

/// Ten fake restaurants for [kPreviewRankedChart]. Art comes from
/// [_mockCoverUrls] / [_mockLogoUrls] — edit those two lists directly to swap
/// in real images. Needs network access either way; falls back to CustomImage's
/// built-in asset placeholder if a request fails, so a flaky connection or a
/// bad URL degrades, not breaks.
List<Store> _mockChartStores() {
  const List<String> names = [
    'Zooba',
    'KFC',
    'Krispy Kreme',
    'Buffalo Burger',
    'Cilantro', // long: tests truncation
    'Mince',
    'Cook Door',
    'Left Bank',
    'Crave',
    'Tabali',
  ];
  const List<double> ratings = [
    4.9,
    4.7,
    4.6,
    4.6,
    4.5,
    4.4,
    4.3,
    4.2,
    4.1,
    3.9,
  ];
  const List<String> times = [
    '15-25 min',
    '20-30 min',
    '25-35 min',
    '20-30 min',
    '30-40 min',
    '25-35 min',
    '35-45 min',
    '30-40 min',
    '40-50 min',
    '45-60 min',
  ];
  const List<double> metres = [
    800,
    1400,
    2300,
    2900,
    3400,
    4100,
    4800,
    5600,
    6300,
    7900,
  ];

  return [
    for (int i = 0; i < names.length; i++)
      Store(
        id: -(i + 1), // negative ids so a stray tap can't open a real store
        name: names[i],
        avgRating: ratings[i],
        ratingCount: 1200 - (i * 90),
        deliveryTime: times[i],
        distance: metres[i],
        // Every third store gets money off, so both pill styles and the
        // no-perk case all appear in one screen.
        discount:
            i % 3 == 0
                ? Discount(discount: 15 + (i * 5), discountType: 'percent')
                : null,
        freeDelivery: i % 3 == 1,
        open: i == 4 ? 0 : 1, // one closed kitchen
        active: true,
        coverPhotoFullUrl: _mockCoverUrls[i],
        logoFullUrl: _mockLogoUrls[i],
      ),
  ];
}

// ── Card metrics ─────────────────────────────────────────────────────────────
// Square store tile, name block locked to two lines so every rating row in
// the rail sits on the same baseline.
const double _kCardWidth = 138;
const double _kTileSize = 138;
const double _kNameSize = 13;
const double _kNameHeight = 1.35;
const double _kNameBlock = _kNameSize * _kNameHeight * 2; // exactly 2 lines
const double _kRatingBlock = 18;

/// Unranked rail height. A function, like its ranked counterpart
/// [_rankRailHeight] — the two branches of this file's card shared everything
/// except this, and the ranked one was made scale-aware while the plain one
/// was left a compile-time const. At a large font setting the plain card lost
/// the second line of its name (35.1pt of box for 45.6pt of text) and clipped
/// its rating row, on the same screen where the ranked rail beside it resized
/// correctly.
///
/// Only the text blocks scale; the photo tile does not.
double _railHeight(BuildContext context) {
  final double t = _rankTextScale(context);
  return _kTileSize +
      Dimensions.paddingSizeSmall +
      _kNameBlock * t +
      6 +
      _kRatingBlock * t;
}

// ── Ranked (Top 10) card metrics ─────────────────────────────────────────────
// Compact photo carrying the chart numeral on one bottom corner and the store
// logo on the other, then three fixed-height text rows so every card in the
// rail shares baselines.
const double _kRankNameBlock = 20; // also the heart's tap target height
// Seam between the card's three text rows. Was a bare `2` written twice into
// the height formula and twice more into the card body. At 2 the name, the
// rating and the offer pill were effectively one paragraph — three different
// kinds of fact with nothing separating them, which is most of why the rail
// read as dense next to its own generous 20pt card gap.
const double _kRankRowGap = 4;

/// Fits the compact [OfferCollarBadge], whose icon disc (34pt) overhangs
/// the pill on both axes and so sets the row height — the old 17pt box was
/// sized for a flat tinted pill and clipped the disc top and bottom.
const double _kRankPromoBlock = 34;
// 13pt at the meta line's new 1.35 leading needs 17.6, so this had to follow
// it up. A fixed row block that is shorter than the text it boxes does not
// clip visibly — it silently eats the descenders.
const double _kRankMetaBlock = 18; // fits the rating badge
// Numeral font size. Stepped down from 46 to 42 to 36, and for the same
// reason each time: the numeral is a rank marker, not the subject of the card
// — the photo is. At 42 it was still the largest glyph anywhere on the home
// screen, larger than the section headline introducing it and larger than the
// greeting at the top of the page, which inverts the whole feed's hierarchy in
// service of an ordinal. The composition is unchanged: it still hangs off the
// corner, still carries its stroke, still lands in the same place on card 1
// and card 10. It just stops out-shouting the section it belongs to.
const double _kRankNumeral = 36;
// How far the numeral hangs past the tile's start edge, and how far below its
// bottom edge. Fixed values applied to every card, so the numeral lands in the
// same place on card 1 and card 10 — the offset is the composition, and it
// only reads as deliberate if it never drifts. Sized so a single digit clears
// the photo by roughly half and hooks the corner; two digits can't clear it —
// "10" is wider than any gutter this rail can afford — so they overlap further
// and lean on the stroke, which is what the stroke is for.
//
// Both follow _kRankNumeral down. They are proportions of the glyph, not fixed
// offsets: "clears the photo by roughly half" is a ratio, and at a 36pt
// numeral a 14pt overhang leaves barely a quarter of the digit on the tile,
// which reads as a number that slipped off rather than one hung deliberately.
// The drop is mostly cancelling the ~0.2em descender the text box reserves and
// digits never use (7.2pt at 36), leaving the ink a hair past the tile edge.
const double _kRankOverhang = 12;
const double _kRankDrop = 9;
const double _kRankLogo = 30;
// Gap between chart cards, and the rail's own leading inset. Both have to
// clear _kRankOverhang: the gap so a numeral hanging off card N never touches
// card N-1's photo, the inset so card 1's numeral doesn't fall off the screen.
const double _kRankGap = 20;
// Derived, not chosen: the numeral is the leftmost ink in the section, so the
// *numeral* is what has to sit on the page margin — which puts the card at
// margin + overhang. At a flat 20 the lead-in cleared the overhang by 6, so
// card 1's numeral started 6pt from the bezel while the headline above it, the
// module tiles above that and the battle card below all started at 16. That
// reads as the rail hanging off the edge of the page rather than as a numeral
// deliberately hung into the gutter. Now the "1" lands exactly under the "F" of
// the headline and the photos are what step in.
const double _kRankLeadPad = Dimensions.paddingSizeDefault + _kRankOverhang;
// Photo height as a fraction of card width — very slightly landscape, kept
// constant so the tile keeps its proportions as the card resizes.
const double _kRankTileRatio = 138 / 148;
// How much of the third card shows past the second. A peek is what tells the
// eye a rail scrolls; the exact fraction is what separates "there's more" from
// "this got cut off".
//
// Set above the 30% the eye is meant to read, because the inter-card gap sits
// inside that sliver: at a true 0.30 the third card's *content* only starts
// after 20pt of empty page, so the visible photo reads as noticeably thinner
// than the number says.
const double _kRankPeek = 0.34;

/// Ranked card width, solved from the viewport so the rail always lands on two
/// full cards plus a [_kRankPeek] sliver of the third.
///
/// A fixed width can't do that: 148pt leaves a tidy third-of-a-card peek on a
/// 390pt phone and an awkward 58% half-card on a 430pt one, which reads as a
/// clipped list rather than a scrollable one. Solving for the width instead
/// pins the composition and lets the cards flex.
double _rankCardWidth(BuildContext context) {
  // Only the leading padding sits before the first card; the trailing one is
  // off-screen at the far end of the rail.
  final double viewport = MediaQuery.sizeOf(
    context,
  ).width.clamp(0.0, Dimensions.maxContentWidth);
  final double usable = viewport - _kRankLeadPad - _kRankGap * 2;
  // Clamped ~10% tighter than the original 132–176 range: the rail's job is
  // ten cards read as a chart, and the wider end of that range was buying
  // each card size without buying the rail anything — a 176pt "Top 10" card
  // is bigger than the section headline it sits under.
  return (usable / (2 + _kRankPeek)).clamp(120.0, 160.0);
}

double _rankTileHeight(BuildContext context) =>
    _rankCardWidth(context) * _kRankTileRatio;

/// How much the fixed text blocks grow with the user's font-size setting.
///
/// The rows below are deliberately fixed-height so ten cards in a rail line
/// up — but "fixed" was measured at 1.0x, and the type inside them still
/// scales. At the system's large accessibility sizes the name row needed 26pt
/// of a 22pt box and the meta row 22.8 of 18, so the first thing to go was the
/// store name's descenders, then the rating line entirely.
///
/// Clamped at 1.3 rather than left open: the rail is horizontal and its height
/// is shared by every card, so unbounded growth would push the photos off the
/// fold to serve a setting most users never reach. 1.3 covers the common large
/// sizes and keeps the rail on screen; past that the rows ellipsize, which is
/// the honest failure for a browse surface.
double _rankTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3);

double _rankRailHeight(BuildContext context) {
  final double t = _rankTextScale(context);
  return _rankTileHeight(context) +
      Dimensions.paddingSizeSmall +
      _kRankNameBlock * t +
      _kRankRowGap +
      _kRankMetaBlock * t +
      _kRankRowGap +
      _kRankPromoBlock * t;
}

const Color _kTileBg = WaddyColors.mintSurface; // #F5F7F6 product plate
// Ink, not the pressed-surface step: this colour is only ever a glyph on
// coralSurface, and coralDark there is 3.34:1 at the 12sp these labels render
// at. coralInk is 5.01:1 on the same ground.
const Color _kSale = WaddyColors.coralInk; // badge + price
const Color _kNameInk = WaddyColors.ink;
const Color _kMetaInk = WaddyColors.inkLight; // secondary meta text

/// Horizontal store rail: a plain chunky headline, then square store
/// photos with logos, favorite hearts, and ratings. Each card shows a store
/// with its cover photo, logo badge, and star rating with review count.
///
/// [stores] null means still loading (shimmer); empty hides the whole rail.
///
/// Chart dress ([ranked]) is a claim about depth, not just a look: numerals and
/// a "Top 10" heading promise a field of contenders. Below [kMinRanked] stores
/// that promise is one the catalogue can't keep — a "#1" on a rail of one reads
/// as broken or rigged — so the rail drops to [thinHeadline] and switches to
/// full-width rows. A lone 164px card stranded in a 390px scroller looks like a
/// list that failed to load; a full-width row looks like a deliberate one.
class StoreRailView extends StatelessWidget {
  /// Stores needed before a rail may wear chart dress.
  static const int kMinRanked = 4;

  final List<Store>? stores;
  final String headline;

  /// Small line under the headline. Null keeps the header a single line.
  final String? subtitle;

  /// Shows a circular arrow button in the header when non-null.
  final VoidCallback? onSeeAll;

  /// Chart mode: bigger photos, each carrying its 1..n position numeral.
  final bool ranked;

  /// Cap on how many cards the rail renders.
  final int maxItems;

  /// Headline used instead of [headline] when a ranked rail is too thin to
  /// carry a chart. Falls back to [headline] when the caller has nothing
  /// honester to say.
  final String? thinHeadline;
  final String? thinSubtitle;

  const StoreRailView({
    super.key,
    required this.stores,
    required this.headline,
    this.subtitle,
    this.onSeeAll,
    this.ranked = false,
    this.maxItems = 8,
    this.thinHeadline,
    this.thinSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final List<Store>? source = _previewOverride(stores, ranked);

    if (source != null && source.isEmpty) {
      return const SizedBox.shrink();
    }

    final double railHeight =
        ranked ? _rankRailHeight(context) : _railHeight(context);
    final int count =
        source == null
            ? 0
            : (source.length > maxItems ? maxItems : source.length);

    // Loading still shows the optimistic heading — the shimmer already says
    // "counting"; swapping to the thin copy mid-load would flicker.
    final bool chartMode = source == null || count >= kMinRanked;
    final bool thin = ranked && !chartMode;

    // No outer padding. Whatever places this rail owns the space around it —
    // an 8pt bottom here stacked under the feed's own section gap, and two
    // sources of truth for one seam is how the gaps drifted apart.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeRailHeader(
          headline: thin ? (thinHeadline ?? headline) : headline,
          subtitle: thin ? thinSubtitle : subtitle,
          // A see-all arrow onto a list of one or two is a dead end.
          onSeeAll: thin ? null : onSeeAll,
        ),
        if (source == null)
          _CardsShimmer(ranked: ranked)
        else if (thin)
          for (int i = 0; i < count; i++)
            StaggeredEntrance(
              group: 'home-rail-list',
              index: i,
              child: _StoreListRow(store: source[i]),
            )
        else
          TrailingFade(
            child: SizedBox(
              height: railHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                // No forced physics: BouncingScrollPhysics was an iOS-style
                // overscroll bounce on every platform, including Android,
                // where it reads as off. Leaving this unset lets each platform
                // use its own native feel (clamped fling on Android, bounce
                // on iOS) via the ambient ScrollConfiguration.
                clipBehavior: Clip.none,
                // Ranked rails start 4pt further in than the header so the
                // first card's numeral has page to hang onto — small enough
                // that the headline and card one still read as aligned.
                padding: EdgeInsetsDirectional.fromSTEB(
                  ranked ? _kRankLeadPad : Dimensions.paddingSizeDefault,
                  0,
                  Dimensions.paddingSizeDefault,
                  0,
                ),
                itemCount: count,
                separatorBuilder:
                    (_, __) => SizedBox(
                      width: ranked ? _kRankGap : Dimensions.paddingSizeMedium,
                    ),
                itemBuilder: (context, index) {
                  return StaggeredEntrance(
                    group: 'home-rail-cards',
                    index: index,
                    child:
                        ranked
                            ? _RankedStoreCard(
                              store: source[index],
                              rank: index + 1,
                            )
                            : _ProductCard(store: source[index]),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Exposed for test: the ranking is the claim the numerals make, so it is
/// worth asserting rather than eyeballing.
@visibleForTesting
List<Store> rankFeaturedForTest(List<Store> stores) => _rankFeatured(stores);

/// [_rankFeatured] for the other rails fed by the admin's featured flag
/// (grocery's top-brands grid).
List<Store> rankFeaturedStores(List<Store> stores) => _rankFeatured(stores);

/// Puts the chart in the order someone actually chose.
///
/// The server already sorts by `featured_order`, so on a fresh payload this
/// changes nothing — it is here because the same list is served from the drift
/// cache, written before the field existed, and because the dashboard variant
/// of this rail merges stores from several requests. A ranking that is only
/// correct when the response is fresh is not a ranking.
///
/// Ranked stores first, in their given order; unranked featured stores keep
/// their relative order behind them. Stable by construction: equal ranks fall
/// back to the position the server sent, never to something arbitrary.
List<Store> _rankFeatured(List<Store> stores) {
  final List<MapEntry<int, Store>> indexed = [
    for (int i = 0; i < stores.length; i++) MapEntry(i, stores[i]),
  ];
  indexed.sort((a, b) {
    final int? rankA = a.value.featuredOrder;
    final int? rankB = b.value.featuredOrder;
    if (rankA != rankB) {
      // Unranked sorts last, never first — the trap MySQL sets with NULLs in
      // an ascending sort, and the same one here.
      if (rankA == null) return 1;
      if (rankB == null) return -1;
      return rankA.compareTo(rankB);
    }
    return a.key.compareTo(b.key);
  });
  return [for (final MapEntry<int, Store> entry in indexed) entry.value];
}

class TopRestaurantsView extends StatelessWidget {
  const TopRestaurantsView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.featuredId,
      builder: (storeController) {
        List<Store>? allStores = storeController.featuredStoreList;
        List<Store>? restaurantList;

        if (allStores != null) {
          final splashController = Get.find<SplashController>();
          final modules = splashController.moduleList;

          int? foodModuleId;
          if (modules != null) {
            for (var module in modules) {
              if (module.moduleType?.toLowerCase() ==
                  AppConstants.food.toLowerCase()) {
                foodModuleId = module.id;
                break;
              }
            }
          }

          // Narrow to restaurants — but only on evidence. Inside the Food
          // module the request already carries the module-id header, so the
          // payload is food-only before this runs; the filter is here for the
          // aggregated dashboard, where the featured list spans every module.
          //
          // A store whose payload omitted `module_id` is therefore *not* a
          // reason to drop it: it is far likelier to be a thin payload than a
          // grocer smuggled into a food-scoped response. Dropping those was
          // one of the two ways this rail could resolve to an empty list and
          // erase itself — StoreRailView hides on empty, so a filter that
          // matches nothing looks exactly like a section that doesn't exist.
          final List<Store> matched =
              foodModuleId == null
                  ? allStores
                  : allStores
                      .where(
                        (store) =>
                            store.moduleId == null ||
                            store.moduleId == foodModuleId,
                      )
                      .toList();

          // If nothing matched, the module id we resolved disagrees with every
          // store the backend sent. Trust the server's scoping over our own
          // bookkeeping rather than showing a blank page.
          restaurantList = _rankFeatured(matched.isEmpty ? allStores : matched);
        }

        return StoreRailView(
          stores: restaurantList,
          headline: 'top_10_maadi_spots'.tr,
          // The numerals are the strongest thing on this screen, so the
          // subtitle has to name what they are. It used to read "most ordered
          // this week" over the featured flag in whatever order the query
          // returned — nothing computed an order count and nothing computed a
          // week, so the ranking looked like a judgement and was an accident.
          // It is a judgement now: a human sets the position (Store
          // .featuredOrder), and this says so.
          subtitle: 'ranked_by_us'.tr,
          thinHeadline: 'restaurants_in_zone'.trParams({
            'zone': 'nearest_zone_maadi'.tr,
          }),
          thinSubtitle: 'ranked_by_us'.tr,
          ranked: true,
          maxItems: 10,
          onSeeAll: () => Get.toNamed(RouteHelper.getAllStoreRoute('featured')),
        );
      },
    );
  }
}

/// Section header: one chunky sentence-case headline in near-black ink, an
/// optional quiet subtitle, and an optional circular "see all" arrow.
///
/// Public so the grocery home's "Top brands" grid wears the same header as
/// food's ranked rail — two module homes, one section voice.
class HomeRailHeader extends StatelessWidget {
  final String headline;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  const HomeRailHeader({
    super.key,
    required this.headline,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      // 12 below, not 20: a headline binds to the content it introduces more
      // tightly than sections bind to each other, and at 20 this seam was the
      // same size as the gap between whole sections.
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        0,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
            // Was an InkWell: its ripple paints on the Material *behind* this
            // opaque filled circle, so the splash was drawn and then hidden.
            // The arrow was the one control in the header that looked
            // interactive and behaved like a picture of a button.
            Pressable(
              onTap: onSeeAll,
              semanticLabel: 'see_all'.tr,
              scale: WaddyMotion.pressControl,
              // The circle stays 40 — it is sized to the header's optical
              // weight, not to the thumb. The hit box grows to the platform
              // minimum underneath it, which is the only part that was wrong:
              // this is the sole entry point to each full category listing and
              // it is thumb-targeted on a moving feed.
              minSize: Dimensions.minTapTarget,
              child: Container(
                width: 40,
                height: 40,
                // Without this the arrow is stretched to the full 40pt
                // circle: a sized Container with a child and no alignment
                // forces tight constraints onto it, and HugeIcon's
                // SvgPicture scales to fill rather than centring itself.
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _kTileBg,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon:
                      isRtl
                          ? HugeIcons.strokeRoundedArrowLeft02
                          : HugeIcons.strokeRoundedArrowRight02,
                  size: 20,
                  color: _kNameInk,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What a single card renders, resolved once from the store so the widget
/// tree stays free of null juggling.
class _CardData {
  final String image;
  final String name;
  final String? logo;
  final double rating;
  final int reviewCount;
  final bool isPro;
  final Store store;

  const _CardData({
    required this.image,
    required this.name,
    required this.logo,
    required this.rating,
    required this.reviewCount,
    required this.isPro,
    required this.store,
  });
}

class _ProductCard extends StatefulWidget {
  final Store store;
  const _ProductCard({required this.store});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final data = _resolve(widget.store);

    return Pressable(
      onTap: () => _navigateToStore(),
      semanticLabel:
          '${data.name}, ${data.rating} stars, ${data.reviewCount} reviews',
      scale: WaddyMotion.pressTile,
      child: SizedBox(
        width: _kCardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StoreImageTile(
              image: data.image,
              logo: data.logo,
              imageVariants: widget.store.coverPhotoVariants,
              logoVariants: widget.store.logoVariants,
              isPro: data.isPro,
              isFavorite: _isFavorite,
              onFavoriteToggle:
                  () => setState(() => _isFavorite = !_isFavorite),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            SizedBox(
              height: _kNameBlock * _rankTextScale(context),
              width: double.infinity,
              child: Text(
                data.name,
                style: waddyMedium.copyWith(
                  fontSize: _kNameSize,
                  height: _kNameHeight,
                  color: _kNameInk,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: _kRatingBlock * _rankTextScale(context),
              child: Row(
                children: [
                  // Heavier stroke than the default: the free HugeIcons set
                  // has no filled star, and a 1.5 outline reads noticeably
                  // lighter than the solid glyph this replaced.
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedStar,
                    size: 14,
                    strokeWidth: 2.4,
                    color: Color(0xFFFFA500),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${data.rating} (${data.reviewCount})',
                      style: waddyBold.copyWith(
                        fontSize: 13,
                        color: _kNameInk,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _CardData _resolve(Store store) {
    return _CardData(
      image: store.coverPhotoFullUrl ?? '',
      name: store.name ?? '',
      logo: store.logoFullUrl,
      rating: store.avgRating?.toDouble() ?? 4.5,
      reviewCount: store.ratingCount ?? 0,
      isPro: (store.discount?.discount ?? 0) > 0,
      store: store,
    );
  }

  void _navigateToStore() => _openStore(widget.store);
}

/// Store image tile with logo badge, rating, and favorite button.
class _StoreImageTile extends StatelessWidget {
  final String image;
  final String? logo;

  /// Right-sized WebP rungs for [image] / [logo] when the payload carries
  /// them. Without these the card downloads whatever the merchant uploaded —
  /// a full-resolution cover for a 150pt tile — on every cold cache.
  final ImageVariants? imageVariants;
  final ImageVariants? logoVariants;
  final bool isPro;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _StoreImageTile({
    required this.image,
    required this.logo,
    this.imageVariants,
    this.logoVariants,
    required this.isPro,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      child: Container(
        width: _kTileSize,
        height: _kTileSize,
        color: _kTileBg,
        child: Stack(
          children: [
            CustomImage(
              image: image,
              variants: imageVariants,
              // The tile is a fixed _kTileSize square; `width` is infinity
              // here, so without this the decode is solved against the whole
              // screen width.
              decodeWidth: _kTileSize,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
            if (logo != null)
              PositionedDirectional(
                top: Dimensions.paddingSizeSmall,
                start: Dimensions.paddingSizeSmall,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CustomImage(
                      image: logo!,
                      variants: logoVariants,
                      decodeWidth: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            PositionedDirectional(
              top: Dimensions.paddingSizeSmall,
              end: Dimensions.paddingSizeSmall,
              // 44pt target around a 36pt visual (HIG 44 / Material 48). The
              // OverflowBox lets the larger hit box spill past the 36pt slot
              // so it does not push the badge off the photo corner.
              //
              // `toggled` rather than a plain label: this control's entire
              // meaning is its state, and the state is carried only by a
              // filled-vs-outline heart. A screen reader reading "Favourite"
              // for both cannot tell the user whether tapping adds or removes.
              child: Semantics(
                button: true,
                toggled: isFavorite,
                label: 'favourite'.tr,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onFavoriteToggle,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: OverflowBox(
                      minWidth: 44,
                      minHeight: 44,
                      maxWidth: 44,
                      maxHeight: 44,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        // One stroke glyph for both states: the free HugeIcons
                        // set ships no filled heart, so "favourited" is carried
                        // by the red and a heavier stroke than by a fill.
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedFavourite,
                          size: 15,
                          strokeWidth: isFavorite ? 2.6 : 1.5,
                          color:
                              isFavorite ? const Color(0xFFE84D4D) : _kNameInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (isPro)
              PositionedDirectional(
                bottom: Dimensions.paddingSizeSmall,
                start: Dimensions.paddingSizeSmall,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  ),
                  child: Text(
                    'PRO',
                    style: waddyBold.copyWith(
                      fontSize: 10,
                      height: 1.2,
                      color: Colors.white,
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

// ── Ranked (Top 10) card ─────────────────────────────────────────────────────

/// A chart entry: store photo with its position numeral on the bottom-start
/// corner and the store logo on the other, then name + heart, the rating/ETA
/// meta row and a perk line. Every text row has a fixed height so the whole
/// rail lines up.
class _RankedStoreCard extends StatelessWidget {
  final Store store;
  final int rank;

  const _RankedStoreCard({required this.store, required this.rank});

  @override
  Widget build(BuildContext context) {
    final String name = store.name ?? '';
    final double rating = store.avgRating?.toDouble() ?? 0;
    final _Perk? perk = _perk(store);
    final bool isOpen = store.open == 1 && store.active == true;

    return Pressable(
      onTap: _navigateToStore,
      semanticLabel: '#$rank, $name, $rating stars',
      scale: WaddyMotion.pressTile,
      child: SizedBox(
        width: _rankCardWidth(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RankedTile(
              image: store.coverPhotoFullUrl ?? '',
              logo: store.logoFullUrl,
              imageVariants: store.coverPhotoVariants,
              logoVariants: store.logoVariants,
              rank: rank,
              isOpen: isOpen,
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),

            SizedBox(
              height: _kRankNameBlock * _rankTextScale(context),
              width: double.infinity,
              child: Text(
                name,
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  // w700, not w800. w800 is the section headline's weight, and
                  // a card title is not a peer of the headline that introduces
                  // it — at the same weight the rail read as ten small
                  // headings under one big one. One step down restores the
                  // relationship without making the name quiet: it is still
                  // the heaviest thing on its own card.
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.25,
                  // -0.3 is display tracking. At 16pt it stops being optical
                  // correction and starts being compression — the letters of
                  // "Zooba" were touching at w800.
                  letterSpacing: -0.15,
                  color: _kNameInk,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: _kRankRowGap),

            // "★ 4.4 • 30-35 mins" — the badge carries the only colour, and
            // the line itself is the card's quietest ink.
            SizedBox(
              height: _kRankMetaBlock * _rankTextScale(context),
              child: Row(
                children: [
                  if (rating > 0) ...[
                    const _RatingBadge(),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      _metaLine(store, rating),
                      style: const TextStyle(
                        fontFamily: AppConstants.fontFamily,
                        // w600, not w700: hierarchy on this card has to come
                        // from the *contrast* between the name and its meta,
                        // and at w800/w700 the two lines were a step apart on
                        // a nine-step scale. Everything shouting is the same
                        // as nothing shouting.
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        // Leading and tracking both open up as the size comes
                        // down. Negative tracking belongs to display sizes; at
                        // 13pt it just crowds the glyphs.
                        height: 1.35,
                        letterSpacing: 0,
                        // The weight step alone was doing all the work here,
                        // and one step on a nine-step scale is not much
                        // contrast to hang a hierarchy on — the rating and the
                        // store name were the same near-black, so both read as
                        // primary and the card had no quiet register at all.
                        // _kMetaInk is what this token exists for; it was
                        // declared for exactly this line and then not used.
                        color: _kMetaInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _kRankRowGap),

            // Perk line: the reason to pick this spot over the next one.
            // Offers wear a brand-tinted pill; plain facts stay quiet.
            SizedBox(
              height: _kRankPromoBlock * _rankTextScale(context),
              child:
                  perk == null
                      ? null
                      : Align(
                        alignment: AlignmentDirectional.centerStart,
                        // Money-off perks wear the collar; plain facts
                        // (distance, minimum order) stay quiet icon+text.
                        child:
                            perk.collarTone != null
                                ? OfferCollarBadge(
                                  label: perk.label,
                                  tone: perk.collarTone!,
                                  compact: true,
                                )
                                : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    HugeIcon(
                                      icon: perk.icon,
                                      size: 11,
                                      color: perk.color,
                                    ),
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
          ],
        ),
      ),
    );
  }

  /// "4.4 • 30-35 mins" — the two numbers that decide the tap, each part
  /// dropped when the backend didn't send it. Distance and review count live
  /// on the perk line so this row stays short enough never to truncate.
  String _metaLine(Store store, double rating) {
    final parts = <String>[];

    if (rating > 0) parts.add(rating.toStringAsFixed(1));

    final String? time = store.deliveryTime;
    if (time != null && time.isNotEmpty) {
      parts.add(time.contains('min') ? time : '$time ${'min'.tr}');
    }

    return parts.join(' • ');
  }

  /// The single perk worth a line, best offer first: percentage discount,
  /// then free delivery, then how far the kitchen actually is, then the
  /// minimum order the basket has to clear.
  _Perk? _perk(Store store) {
    final double discount = store.discount?.discount ?? 0;
    if (discount > 0 && store.discount?.discountType == 'percent') {
      return _Perk(
        icon: HugeIcons.strokeRoundedFire,
        label: '${discount.toInt()}% ${'off'.tr}',
        color: _kSale,
        bg: WaddyColors.coralSurface,
        collarTone: OfferCollarTone.sale,
      );
    }
    if (store.freeDelivery == true) {
      return _Perk(
        icon: HugeIcons.strokeRoundedMotorbike02,
        label: 'free_delivery'.tr,
        color: WaddyColors.primary,
        bg: WaddyColors.mintSurface,
        collarTone: OfferCollarTone.delivery,
      );
    }
    final double km = (store.distance ?? 0) / 1000;
    if (km > 0) {
      return _Perk(
        icon: HugeIcons.strokeRoundedLocation01,
        label: '${km.toStringAsFixed(km < 10 ? 1 : 0)} ${'km'.tr}',
        color: WaddyColors.primaryLight,
      );
    }
    final double minOrder = store.minimumOrder ?? 0;
    if (minOrder > 0) {
      return _Perk(
        icon: HugeIcons.strokeRoundedShoppingBasket03,
        label: '${'min_order'.tr}: ${PriceConverter.convertPrice(minOrder)}',
        color: WaddyColors.primaryLight,
      );
    }
    return null;
  }

  void _navigateToStore() => _openStore(store);
}

/// Store photo carrying its chart position: a mint numeral outlined in deep
/// teal, hung so roughly half of it clears the tile's bottom-start corner, with
/// the store logo riding the opposite corner in a teal-bordered white chip.
///
/// Half-out is the whole trick. A numeral set large and mostly *inside* the
/// photo competes with the photo and reads as an overlay dropped on top; the
/// same numeral smaller and hung off the corner reads as a chart position the
/// card is sitting in.
///
/// The outline is not decoration — it's what lets one glyph cross two
/// backgrounds. The numeral is part on the (scrimmed, dark) photo and part on
/// the white page, so neither a light fill nor a dark one works alone: mint
/// reads on the photo and vanishes on the page, deep teal does the reverse.
/// The stroke gives whichever half is losing an edge to sit against.
///
/// Which way round follows where the glyph mostly lives. It used to sit mostly
/// on the photo, so it was mint filled and teal stroked. Now that it hangs
/// clear of the corner it is mostly on white — so the fill went teal and the
/// stroke mint. Same trick, inverted, and the read changes with it: a solid
/// dark numeral on the page is a badge the card is sitting in, where a bright
/// one lying across the photo was a label printed on top of it.
class _RankedTile extends StatelessWidget {
  final String image;
  final String? logo;
  final ImageVariants? imageVariants;
  final ImageVariants? logoVariants;
  final int rank;
  final bool isOpen;

  const _RankedTile({
    required this.image,
    required this.logo,
    this.imageVariants,
    this.logoVariants,
    required this.rank,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    final double width = _rankCardWidth(context);
    final double height = _rankTileHeight(context);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: width,
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: WaddyColors.primarySurface,
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              border: Border.all(
                color: WaddyColors.primary.withValues(alpha: 0.10),
              ),
              boxShadow: [
                const BoxShadow(
                  color: WaddyColors.shadowTeal,
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
                // Soft glow gathered under the card's bottom edge, negative
                // spread so it reads as light pooling under the tile rather
                // than a shadow on all sides.
                BoxShadow(
                  color: WaddyColors.primary.withValues(alpha: 0.14),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: Stack(
              children: [
                CustomImage(
                  image: image,
                  variants: imageVariants,
                  decodeWidth: width,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                // Scrim: the numeral's guaranteed dark bed. Without it a light
                // numeral is at the mercy of whatever the store uploaded —
                // and a chart position that disappears on bright photos is
                // worse than no chart at all.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        WaddyColors.primary.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: const SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                if (!isOpen)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: WaddyColors.primary.withValues(alpha: 0.55),
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(
                      top: Dimensions.paddingSizeSmall,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: WaddyColors.mint,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                      ),
                      child: Text(
                        'closed'.tr,
                        style: waddyBold.copyWith(
                          fontSize: 10,
                          height: 1.3,
                          color: WaddyColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (logo != null && logo!.isNotEmpty)
            PositionedDirectional(
              end: Dimensions.paddingSizeSmall,
              bottom: Dimensions.paddingSizeSmall,
              child: Container(
                width: _kRankLogo,
                height: _kRankLogo,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
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
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  child: CustomImage(
                    image: logo!,
                    variants: logoVariants,
                    decodeWidth: _kRankLogo,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

          PositionedDirectional(
            start: -_kRankOverhang,
            // Digits have no descender, but the text box still reserves ~0.2em
            // for one (~9pt here), so most of this drop is spent cancelling
            // that: the glyph's ink lands just past the tile's bottom edge
            // rather than floating inside it.
            bottom: -_kRankDrop,
            child: Stack(
              children: [
                Text('$rank', style: _rankStyle(stroke: true)),
                Text('$rank', style: _rankStyle(stroke: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _rankStyle({required bool stroke}) => TextStyle(
    // Display face: a chart numeral is the loudest glyph on the rail and
    // has no business being the body typeface at w900.
    fontFamily: AppConstants.displayFontFamily,
    fontSize: _kRankNumeral,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -1.5,
    color: stroke ? null : WaddyColors.primary,
    foreground:
        stroke
            ? (Paint()
              ..style = PaintingStyle.stroke
              // Kept sub-proportional to the glyph — scaling the stroke with
              // the type would tip it from chart numeral into cartoon
              // lettering.
              ..strokeWidth = 3
              ..strokeJoin = StrokeJoin.round
              ..color = WaddyColors.mint)
            : null,
    // No drop shadow. The stroke already separates the glyph from both
    // backgrounds it crosses; the shadow only added the "stuck on top of
    // the photo afterwards" look the numeral is trying to avoid.
  );
}

// ── Full-width store row (thin supply) ───────────────────────────────────────

/// The layout a short restaurant list deserves. Same data as the chart card,
/// re-weighted for a vertical read: the delivery estimate is promoted out of
/// the middle of a "5.0 • 20-30 min" string into a pill of its own, because on
/// an everyday order that number decides the tap — the rating only breaks ties.
/// A square thumbnail (rather than a cropped banner) keeps logo-style cover art
/// intact, which is what most stores upload before they have food photography.
class _StoreListRow extends StatelessWidget {
  final Store store;
  const _StoreListRow({required this.store});

  static const double _photo = 92;

  @override
  Widget build(BuildContext context) {
    final String name = store.name ?? '';
    final double rating = store.avgRating?.toDouble() ?? 0;
    final double km = (store.distance ?? 0) / 1000;
    final bool isOpen = store.open == 1 && store.active == true;
    final String? eta = store.deliveryTime;
    final _Perk? offer = _offerPerk(store);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        0,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeMedium,
      ),
      child: Pressable(
        onTap: () => _openStore(store),
        semanticLabel: '$name, $rating stars, ${eta ?? ''}',
        scale: WaddyMotion.pressCard,
        child: Container(
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            border: Border.all(color: WaddyColors.divider),
            boxShadow: const [
              BoxShadow(
                color: WaddyColors.shadowTeal,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RowPhoto(
                image: store.coverPhotoFullUrl ?? '',
                logo: store.logoFullUrl,
                imageVariants: store.coverPhotoVariants,
                logoVariants: store.logoVariants,
                isOpen: isOpen,
                size: _photo,
              ),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: AppConstants.fontFamily,
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                        height: 1.2,
                        letterSpacing: -0.3,
                        color: _kNameInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),

                    // Rating and distance are the tie-breakers, so they sit
                    // quiet under the name rather than competing with it.
                    Row(
                      children: [
                        if (rating > 0) ...[
                          const _RatingBadge(),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: waddyBold.copyWith(
                              fontSize: 13,
                              height: 1.2,
                              color: _kNameInk,
                            ),
                          ),
                        ],
                        if (rating > 0 && km > 0)
                          Text(
                            '  ·  ',
                            style: waddyRegular.copyWith(
                              fontSize: 13,
                              color: _kMetaInk,
                            ),
                          ),
                        if (km > 0)
                          Flexible(
                            child: Text(
                              '${km.toStringAsFixed(km < 10 ? 1 : 0)} ${'km'.tr}',
                              style: waddyRegular.copyWith(
                                fontSize: 13,
                                height: 1.2,
                                color: _kMetaInk,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),

                    // Speed first, offer second — and both wrap rather than
                    // truncate, since a clipped "30% of…" is worse than a
                    // second line.
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (eta != null && eta.isNotEmpty)
                          _MetaPill(
                            icon: HugeIcons.strokeRoundedMotorbike02,
                            label:
                                eta.contains('min') ? eta : '$eta ${'min'.tr}',
                            fg: WaddyColors.primary,
                            bg: WaddyColors.mintSurface,
                          ),
                        if (offer != null)
                          OfferCollarBadge(
                            label: offer.label,
                            tone: offer.collarTone ?? OfferCollarTone.delivery,
                            compact: true,
                          ),
                      ],
                    ),
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

/// Square thumbnail with the logo chip riding its corner, dimmed and stamped
/// when the kitchen is shut.
class _RowPhoto extends StatelessWidget {
  final String image;
  final String? logo;
  final ImageVariants? imageVariants;
  final ImageVariants? logoVariants;
  final bool isOpen;
  final double size;

  const _RowPhoto({
    required this.image,
    required this.logo,
    this.imageVariants,
    this.logoVariants,
    required this.isOpen,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: WaddyColors.primarySurface,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            ),
            child: Stack(
              children: [
                CustomImage(
                  image: image,
                  variants: imageVariants,
                  decodeWidth: size,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                if (!isOpen)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: WaddyColors.primary.withValues(alpha: 0.55),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: WaddyColors.mint,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                      ),
                      child: Text(
                        'closed'.tr,
                        style: waddyBold.copyWith(
                          fontSize: 10,
                          height: 1.3,
                          color: WaddyColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (logo != null && logo!.isNotEmpty)
            PositionedDirectional(
              end: 4,
              bottom: 4,
              child: Container(
                width: 26,
                height: 26,
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  boxShadow: const [
                    BoxShadow(
                      color: WaddyColors.shadowDeep,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: CustomImage(
                    image: logo!,
                    variants: logoVariants,
                    decodeWidth: 26,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tinted icon + label pill. Carries the two facts worth a glance on a row:
/// how fast it gets here, and whether there's money off.
class _MetaPill extends StatelessWidget {
  /// A HugeIcons glyph, not an [IconData] — see [_Perk.icon].
  final List<List<dynamic>> icon;
  final String label;
  final Color fg;
  final Color bg;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: waddyBold.copyWith(fontSize: 11.5, height: 1.2, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Money-off perks only. Distance and ETA have their own slots on a row, so
/// repeating them here would just be the same fact twice.
_Perk? _offerPerk(Store store) {
  final double discount = store.discount?.discount ?? 0;
  if (discount > 0 && store.discount?.discountType == 'percent') {
    return _Perk(
      icon: HugeIcons.strokeRoundedFire,
      label: '${discount.toInt()}% ${'off'.tr}',
      color: _kSale,
      bg: WaddyColors.coralSurface,
      collarTone: OfferCollarTone.sale,
    );
  }
  if (store.freeDelivery == true) {
    return _Perk(
      icon: HugeIcons.strokeRoundedMotorbike02,
      label: 'free_delivery'.tr,
      color: WaddyColors.primary,
      bg: WaddyColors.mintSurface,
      collarTone: OfferCollarTone.delivery,
    );
  }
  return null;
}

/// Switches the active module to the store's before routing — a store opened
/// from home otherwise lands in whatever module the user last browsed.
///
/// This rail is the *restaurant* chart, so a tap has to land on
/// [FoodStoreScreen] — the menu-first layout with category tabs, item rows and
/// the cart bar. The generic [StoreScreen] is the grocery/pharmacy shape, and
/// routing there gave a restaurant a shelf-browser it has no shelves for.
void _openStore(Store store) {
  StoreNavigator.open(store, page: 'module');
}

/// Filled mint disc with a white star — the rating row's only splash of
/// colour, so "4.4 • 30-35 mins" can stay one solid line of ink.
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
      child: const HugeIcon(
        icon: HugeIcons.strokeRoundedStar,
        size: 9,
        strokeWidth: 2.6,
        color: WaddyColors.mint,
      ),
    );
  }
}

/// One perk line: icon + label in the colour that says what kind of perk it
/// is. [bg] turns it into a tinted pill — offers get one, plain facts don't.
class _Perk {
  /// A HugeIcons glyph, not an [IconData]: the package ships path data
  /// rather than font codepoints.
  final List<List<dynamic>> icon;
  final String label;
  final Color color;
  final Color? bg;

  /// Set only on money-off perks — the ones that render as an
  /// [OfferCollarBadge]. Plain facts (distance, minimum order) leave it null
  /// and stay quiet text.
  final OfferCollarTone? collarTone;

  const _Perk({
    required this.icon,
    required this.label,
    required this.color,
    this.bg,
    this.collarTone,
  });
}

// ── Staggered entrance: fade + slide-up per card index ───────────────────────

/// One-time arrival animation for the cards that are on screen when the rail
/// first paints.
///
/// The index gate is the whole point. This rail is a lazy `ListView.builder`,
/// so cards past the first screenful are constructed *while the user is
/// scrolling toward them* — and an entrance animation fired at that moment
/// doesn't read as polish, it reads as the list failing to keep up: the card
/// the thumb is dragging into view arrives late, dim, and sliding. Only the
/// cards the user sees at rest get an entrance; the rest are simply there.

class _CardsShimmer extends StatelessWidget {
  final bool ranked;

  const _CardsShimmer({this.ranked = false});

  Widget _bar({required double width, required double height}) => Shimmer(
    duration: const Duration(seconds: 2),
    child: Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: _kTileBg,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final double tileWidth = ranked ? _rankCardWidth(context) : _kCardWidth;
    final double tileHeight = ranked ? _rankTileHeight(context) : _kTileSize;

    return SizedBox(
      height: ranked ? _rankRailHeight(context) : _railHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
        ),
        itemCount: 4,
        separatorBuilder:
            (_, __) => SizedBox(
              width: ranked ? _kRankGap : Dimensions.paddingSizeMedium,
            ),
        itemBuilder: (context, index) {
          return SizedBox(
            width: tileWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer(
                  duration: const Duration(seconds: 2),
                  child: Container(
                    height: tileHeight,
                    width: tileWidth,
                    decoration: BoxDecoration(
                      color: _kTileBg,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusLarge,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                _bar(width: double.infinity, height: 11),
                const SizedBox(height: 6),
                _bar(width: 84, height: 11),
                const SizedBox(height: 8),
                _bar(width: 64, height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}
