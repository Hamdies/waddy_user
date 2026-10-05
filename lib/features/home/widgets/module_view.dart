import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/common/widgets/section_error_view.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/spots_round.dart';
import 'package:waddy_app/features/places/widgets/place_vote_action.dart';
import 'package:waddy_app/common/widgets/spots/spots_marks.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/common/widgets/staggered_entrance.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/order/widgets/order_tracking_bar.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_celebrate_button_wrapper.dart';
import 'package:waddy_app/features/home/widgets/views/recommended_store_view.dart';
import 'package:waddy_app/features/home/widgets/views/top_restaurants_view.dart';
import 'package:waddy_app/features/home/widgets/views/grocery_shelf_view.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/theme/light_theme.dart';

/// Vertical rhythm for the home feed.
///
/// Three values, and each means something different. The feed used to have one
/// effective gap — everything landed between 32 and 40pt because sections each
/// carried their own trailing space *and* the parent added more on top, so the
/// gaps compounded instead of composing. With every seam the same size, nothing
/// groups: the chart and the battle read as unrelated modules even though they
/// are one thought, and the page just reads as sparse.
///
/// The rule is that a section owns none of its outer spacing. Gaps live here,
/// in one list, where they can be compared against each other.
class _Gap {
  const _Gap._();

  /// Header to the content it introduces — the tightest seam. Also the seam
  /// inside a section, never between two of them.
  static const double bind = 12;

  /// Between sections that belong to the same idea.
  static const double section = 24;

  /// Between genuinely unrelated blocks.
  static const double major = 36;

  // The two outer values went up (20→24, 28→36) and `bind` deliberately did
  // not. The feed did not need *more* space evenly — it needed more contrast
  // between its seams. At 12/20/28 the three gaps were close enough that the
  // page read as one continuous stack of same-weight blocks, which is what
  // makes a dense screen feel crowded even when nothing is actually touching.
  // Widening only the separators, and leaving the binding seam alone, buys
  // breathing room without loosening the groups that are meant to read as one
  // thought — a header still sits tight to its rail, the chart still sits tight
  // to the battle it feeds.
}

class ModuleView extends StatelessWidget {
  final SplashController splashController;
  const ModuleView({super.key, required this.splashController});

  /// Returns a SLIVER. This is the dashboard landing feed — the screen shown
  /// after splash, before a module is chosen — and it is rendered directly into
  /// the home screen's `CustomScrollView`.
  ///
  /// It was a `Column` inside a `SliverToBoxAdapter`, so all nine sections were
  /// built, laid out and painted in the first frame: the battle card, three
  /// store rails and the fallback rail all construct store cards with images,
  /// and only the first two are above the fold. Same treatment as the food and
  /// grocery homes — each section is its own sliver, so the viewport decides
  /// what exists.
  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        // The banner carries its own 12pt bottom padding, so this is the
        // remainder of the seam (36 total when a current order is showing),
        // not the whole of it. Most of the time there is no running order, so
        // this is also just "search bar to tiles" — bumped from _Gap.bind to
        // _Gap.section so that gap reads as its own breath rather than being
        // glued to the header above it.
        const SliverToBoxAdapter(child: SizedBox(height: _Gap.section)),
        // 1. Modules grid — primary action, generous top breathing room.
        //
        // Crossfaded rather than swapped. The grid is the first thing above
        // the fold, so a hard cut from placeholder to content is the most
        // visible jolt on the screen — and it's the one moment the user is
        // definitely looking. ModuleShimmer is built to the grid's exact
        // metrics, so the two states occupy identical space and the fade
        // carries no layout jump with it.
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: WaddyMotion.enter,
            switchInCurve: WaddyMotion.easeOut,
            switchOutCurve: WaddyMotion.easeOut,
            child:
                splashController.moduleList != null
                    ? splashController.moduleList!.isNotEmpty
                        ? RamadanCelebrateButtonWrapper(
                          key: const ValueKey('modules'),
                          child: _buildModuleGrid(context, splashController),
                        )
                        : Center(
                          key: const ValueKey('modules-empty'),
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: Dimensions.paddingSizeSmall,
                            ),
                            child: Text('no_module_found'.tr),
                          ),
                        )
                    : const ModuleShimmer(
                      key: ValueKey('modules-loading'),
                      isEnabled: true,
                    ),
          ),
        ),

        // _Gap.section, not .major. This used to be major on the argument that
        // tiles and battle are two different offers (browse vs. a live race)
        // and so deserve the bigger seam. Measured on device, that made every
        // seam in the top half the same: search->tiles, tiles->battle and
        // battle->chart all rendered within a few points of each other, so the
        // fold read as four unrelated blocks floating at equal distance and the
        // battle card — already the odd object here — floated hardest.
        //
        // They are different offers, but they answer the same question: which
        // lane am I in. Browsing does not start until the chart. Binding them
        // at .section and keeping .major on the seam below turns a metronome
        // into a rhythm, and lets the one boundary that marks a real change of
        // mode be the widest one on the screen.
        const SliverToBoxAdapter(child: SizedBox(height: _Gap.section)),

        // 2. Spot Battle — the live race, straight under the tiles.
        //
        // It sits above the chart, and the deciding argument is that it is the
        // only perishable thing on this screen. "Ends in 5d 7h" is worth less
        // every hour; "Fastest 10" is identical tomorrow, so the chart loses
        // nothing by being second and the battle loses its whole premise by
        // being cut in half.
        //
        // Which is what used to happen. Below the chart, only ~132pt of fold
        // was left for a 193pt card: the standings and the split bar showed,
        // the stakes line and the button did not. The most action-shaped
        // control on the screen was permanently below the fold. In this order
        // the card lands whole, and the rail's own cut falls across the store
        // *photos* — which is the ordinary "scroll for more" cue every feed
        // uses, rather than a hidden CTA.
        //
        // It also alternates modes. Categories then chart is two browse
        // surfaces stacked back to back; categories, race, chart reads as
        // three different offers.
        SliverToBoxAdapter(
          child: _BattleSection(splashController: splashController),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: _Gap.major)),

        // 3. Order Again — the repeat order is this app's highest-frequency
        // job. A Maadi regular opening the app at 6pm already knows what they
        // want, so the shortcut stays bound to the chart it introduces: your
        // usual first, then what is fastest right now. Collapses to nothing
        // when signed out or with no history.
        // const SliverToBoxAdapter(child: _OrderAgainRow()),

        // 4. The chart — the first thing on this screen you can actually order
        // from, with names, ratings and prices visible.
        const SliverToBoxAdapter(child: _QuickStoresSection.mostOrdered()),

        const SliverToBoxAdapter(child: SizedBox(height: _Gap.major)),

        // 4b. Groceries — its own band, not another rail.
        //
        // Stacked directly under the restaurant chart it used to read as one
        // continuous list of stores with a heading dropped into the middle:
        // same header, same cards, same rhythm, so nothing told the eye that
        // the second block answers a different question. It now sits on its
        // own tinted ground and renders as a shelf, which is the cheapest
        // possible signal that this is a different aisle of the app.
        const SliverToBoxAdapter(child: _GrocerySection()),

        const SliverToBoxAdapter(child: SizedBox(height: _Gap.major)),

        // 4. Food Offers — tertiary content
        const SliverToBoxAdapter(child: _FoodOffersSection()),

        // 5. Recommended stores — fallback content so the feed never runs
        // dry into empty space when offers/restaurants are sparse
        const SliverToBoxAdapter(child: _RecommendedFallbackSection()),

        // Clears the dashboard's floating nav on every device rather than on
        // the one this number was measured against.
        SliverToBoxAdapter(
          child: SizedBox(height: Dimensions.bottomNavReserve(context)),
        ),
        // The order-tracking bar stacks above the nav while an order runs.
        const SliverToBoxAdapter(child: OrderTrackingReserve()),
      ],
    );
  }

  /// The 3-column category tile grid (Grocery, Food, Pharmacy…).
  ///
  /// The Hidden Gem module is filtered out here and rendered separately by
  /// [_BattleSection], so the battle's position in the feed is a layout
  /// decision rather than a side effect of how the module list is parsed.
  /// Keeping it nested inside the grid builder is what made the fold
  /// impossible to reorder — and it has now been reordered twice.
  Widget _buildModuleGrid(
    BuildContext context,
    SplashController splashController,
  ) {
    final normalModules = _splitModules(splashController).normal;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          // Square gutters, on the token scale. 14 × 12 was off-grid in one
          // axis and unequal in both, which on a grid of square tiles reads as
          // rows sitting fractionally too far apart — the one place an uneven
          // gutter is actually visible, because the cells it separates are the
          // same size in both directions. Bumped from paddingSizeMedium (12)
          // to paddingSizeDefault (16): with the tiles now a flat fade rather
          // than a bordered chip, a tighter gutter read as three tiles fused
          // into one strip instead of three distinct tiles.
          mainAxisSpacing: Dimensions.paddingSizeDefault,
          crossAxisSpacing: Dimensions.paddingSizeDefault,
          // Must match _ModuleTile's own aspect or the tile overflows its
          // cell (below) / leaves dead space under itself (above).
          childAspectRatio: _kModuleTileAspect,
        ),
        itemCount: normalModules.length,
        // Same arrival language as the store rail below. The tiles used to
        // crossfade in as one slab while the rail cascaded card by card, so
        // the fold's two biggest objects assembled themselves in two different
        // voices — the exact inconsistency WaddyMotion exists to prevent.
        itemBuilder:
            (context, i) => StaggeredEntrance(
              group: 'home-modules',
              index: i,
              child: _ModuleTile(
                module: normalModules[i]['module'],
                onTap:
                    () => splashController.switchModule(
                      normalModules[i]['index'] as int,
                    ),
              ),
            ),
      ),
    );
  }
}

/// Result of separating the Hidden Gem module from the ordinary tile modules.
class _SplitModules {
  final List<Map<String, dynamic>> normal;
  final dynamic hiddenGem;
  final int hiddenGemIndex;

  const _SplitModules(this.normal, this.hiddenGem, this.hiddenGemIndex);
}

_SplitModules _splitModules(SplashController splashController) {
  final modules = splashController.moduleList ?? const [];
  final normal = <Map<String, dynamic>>[];
  dynamic hiddenGem;
  int hiddenGemIndex = -1;

  for (int i = 0; i < modules.length; i++) {
    final module = modules[i];
    final isHiddenGem =
        module.moduleName?.toLowerCase().contains('hidden') == true ||
        module.moduleName?.toLowerCase().contains('gem') == true;

    if (isHiddenGem) {
      hiddenGem = module;
      hiddenGemIndex = i;
    } else {
      normal.add({'module': module, 'index': i});
    }
  }
  return _SplitModules(normal, hiddenGem, hiddenGemIndex);
}

/// The Spot Battle card in its own slot in the feed, so its position is a
/// layout decision rather than a side effect of how the module list is parsed.
class _BattleSection extends StatelessWidget {
  final SplashController splashController;
  const _BattleSection({required this.splashController});

  @override
  Widget build(BuildContext context) {
    final split = _splitModules(splashController);
    if (split.hiddenGem == null) return const SizedBox.shrink();

    // Horizontal inset only. Vertical spacing belongs to the feed (see [_Gap])
    // so this card cannot silently widen its own seams.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _PlacesTicketCard(
        module: split.hiddenGem,
        onTap: () => splashController.switchModule(split.hiddenGemIndex),
      ),
    );
  }
}

/// Category tile proportions. The artwork is laid out `contain`, so a
/// shorter box scales it down rather than cropping it — height comes out of
/// the tile, nothing is lost from the picture.
///
/// Slightly landscape rather than square. Three square tiles across a phone
/// are ~107pt tall each, and stacked under a mint hero and above a dark
/// battle card that made the fold read as three hero sections in a row before
/// a single orderable thing appeared. 1.1 gives back ~10pt of fold at the one
/// price a `contain` layout charges: the artwork renders 10% smaller. The
/// label is top-anchored and already auto-scales, so it is unaffected.
const double _kModuleTileAspect = 1.1;

/// Category tile — design's 3-up grid cell: a rounded photo (mint placeholder
/// wash), an optional bottom badge (e.g. "Coming soon" for empty modules),
/// and a chunky centered label below.
class _ModuleTile extends StatelessWidget {
  final dynamic module;
  final VoidCallback onTap;

  const _ModuleTile({required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: module.moduleName ?? '',
      scale: WaddyMotion.pressTile,
      // No wrapping Column: it held the tile and a caption beneath it until
      // the caption moved inside the artwork, and a Column of one child is
      // just a layout node that implies siblings which aren't coming.
      child: AspectRatio(
        aspectRatio: _kModuleTileAspect,
        child: DecoratedBox(
          // Same top-to-bottom fade as the home hero banner
          // (HomeHeroBannerWidget), so the tiles read as a
          // continuation of the banner's mint.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            // Same fade as the home hero banner — statusBarTint → mint
            // → mint → a mint/surface blend → surface — with no border
            // or shadow on top of it. The old 6-stop gradient plus a
            // 25%-alpha ink border plus a blurred drop shadow read as a
            // raised, floating chip; the hero banner it's meant to echo
            // is just a flat fade, so the tile now is too.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                HomeHeroBannerWidget.statusBarTint,
                WaddyColors.mint,
                WaddyColors.mint,
                Color.lerp(WaddyColors.mint, WaddyColors.mintSurface, 0.55)!,
                WaddyColors.surface,
              ],
              stops: const [0.0, 0.22, 0.74, 0.92, 1.0],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Dimensions.paddingSizeSmall,
                        0,
                        Dimensions.paddingSizeSmall,
                        Dimensions.paddingSizeExtraSmall,
                      ),
                      // Transparent while loading and no fade: the default grey
                      // tile with the Waddy mark painted a box and a "W" over
                      // the gradient, right under the title, on every visit
                      // until the picture arrived. The tile is already a
                      // finished gradient; the artwork just lands on it.
                      child: CustomImage(
                        image: '${module.iconFullUrl}',
                        fit: BoxFit.contain,
                        width: double.infinity,
                        fallback: const SizedBox.shrink(),
                        fadeInDuration: Duration.zero,
                      ),
                    ),
                  ),
                ),

                // Title lives inside the tile now — top-anchored label,
                // matching the design's baked-in caption.
                //
                // Scaled down rather than ellipsised. The tile is fluid
                // ((width - 56) / 3) but this label was not: at 21sp
                // "Groceries" already fills the cell on a 393pt phone, so
                // a 360pt one truncated it to "Grocerie…" and any text
                // scale above 1.0 truncated it everywhere. A category
                // name is the entire content of the tile — it is the one
                // string on this screen that must never be cut. A word a
                // point or two smaller than its neighbours is a far
                // cheaper inconsistency than a word missing its end.
                Positioned(
                  left: Dimensions.paddingSizeSmall,
                  right: Dimensions.paddingSizeSmall,
                  top: Dimensions.paddingSizeMedium,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      module.moduleName ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: waddyBold.copyWith(
                        fontSize: 18,
                        color: WaddyColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a store from the aggregated dashboard: the target module must be
/// activated first (dashboard has none selected), then route to the store.
void _openStoreFromDashboard(Store store) {
  StoreNavigator.open(store, page: 'module');
}

/// A section that has no content: an error row if the fetch failed, nothing at
/// all if it simply came back empty.
///
/// The two cases are indistinguishable at the call site — both are a null or
/// empty list — but they must not look the same to the user. An empty zone is
/// a fact and should stay quiet; a failed fetch is a thing the user can act on
/// and needs a Retry. Only [HomeController.hasError] can tell them apart.
///
/// Scoped to its own section id so a failure in one rail repaints that rail
/// and not the whole feed.
class _SectionErrorSlot extends StatelessWidget {
  const _SectionErrorSlot({required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      id: section,
      builder: (homeController) {
        if (!homeController.hasError(section)) return const SizedBox.shrink();
        return SectionErrorView(onRetry: () => HomeScreen.loadData(true));
      },
    );
  }
}

/// The restaurant chart — the zone's most-ordered places, rendered through
/// [StoreRailView] in ranked dress (big photo carrying its 1..10 position).
///
/// Groceries used to ride the same widget on the compact plate; it now has its
/// own furniture in [_GrocerySection], which is what stops the two from
/// reading as one long list.
class _QuickStoresSection extends StatelessWidget {
  const _QuickStoresSection.mostOrdered();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.dashboardRailsId,
      builder: (storeController) {
        final stores = storeController.mostOrderedFoodStores;
        if (stores == null || stores.isEmpty) {
          // Empty and failed look identical from here — both are "no stores".
          // Only the failed one gets a row: a zone with genuinely nothing open
          // should stay quiet, not apologise.
          return const _SectionErrorSlot(section: HomeSection.fastest);
        }

        // No trailing SizedBox: the feed owns the gaps (see [_Gap]). This used
        // to add 32 on top of StoreRailView's own 8pt bottom padding and the
        // parent's spacing, which is how a 40pt seam appeared where a 12 was
        // intended.
        return StoreRailView(
          stores: stores,
          headline: 'most_popular'.tr,
          // Headline and sort finally agree. This rail has been through two
          // orderings that the numerals misdescribed — nearest-first, then
          // fastest-first — and a ranking chart is read as a claim about which
          // places are *best*, not which are closest to the user standing
          // still. The list is now ordered by how many orders each store has
          // actually taken, and the subtitle says so, so a regular who finds
          // their favourite at #8 is reading a fact rather than catching the
          // app out.
          subtitle: 'most_ordered_first'.tr,
          // Too few restaurants to chart: name what's there rather than
          // promising a top ten.
          thinHeadline: 'restaurants_in_zone'.trParams({
            'zone': 'nearest_zone_maadi'.tr,
          }),
          thinSubtitle: 'most_ordered_first'.tr,
          ranked: true,
          maxItems: 10,
          onSeeAll: () => Get.toNamed(RouteHelper.getAllStoreRoute('featured')),
        );
      },
    );
  }
}

/// Groceries in minutes — the shelf band.
///
/// Wrapped in its own tinted ground with rounded ends so it reads as a
/// separate surface of the feed rather than as the next paragraph of the
/// restaurant chart. The tint is the mint wash, the same one the module tiles
/// use, so the band still belongs to the page it interrupts.
class _GrocerySection extends StatelessWidget {
  const _GrocerySection();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.dashboardRailsId,
      builder: (storeController) {
        final stores = storeController.quickGroceryStores;
        if (stores == null || stores.isEmpty) {
          return const _SectionErrorSlot(section: HomeSection.grocery);
        }

        return Container(
          width: double.infinity,
          // Tighter than the old 20pt: the band's job is to separate this
          // section from the chart above, and with 1-5 stores the extra air
          // only made the wash look emptier than the content warranted.
          padding: const EdgeInsets.only(
            top: Dimensions.paddingSizeDefault,
            bottom: Dimensions.paddingSizeLarge,
          ),
          decoration: const BoxDecoration(
            color: WaddyColors.mintSurface,

            // Rounded ends, square sides: the band is full-bleed horizontally,
            // so only the top and bottom edges are ever seen as edges. Curving
            // them is what makes this read as a separate surface laid onto the
            // feed rather than a colour change that happens to start here.
          ),
          child: GroceryShelfView(
            stores: stores,
            headline: 'groceries_in_minutes'.tr,
            subtitle: 'groceries_shelf_subtitle'.tr,
            // Serves the header arrow and the grid's own trailing "all" tile.
            // Routes to the store list rather than the grocery module home:
            // both entry points sit at the end of a set of shortcuts, and what
            // the user asked for is the rest of the catalogue, not a module
            // landing page with its own banners.
            onSeeAll:
                () => Get.toNamed(RouteHelper.getAllStoreRoute('grocery')),
            // Only reached by the no-category fallback rail; the aisle grid
            // caps itself at eight tiles.
            maxItems: 10,
          ),
        );
      },
    );
  }
}

/// Order Again — compact chips of recently-ordered stores, the shortcut for
/// the repeat order. Header stays quiet (eyebrow only); this row just has to
/// be findable in a glance.
class _OrderAgainRow extends StatelessWidget {
  const _OrderAgainRow();

  @override
  Widget build(BuildContext context) {
    if (!AuthHelper.isLoggedIn()) return const SizedBox.shrink();
    return GetBuilder<StoreListController>(
      id: StoreListController.visitAgainId,
      builder: (storeController) {
        // The dashboard's own list: every module's stores, not whichever
        // module home loaded last.
        final stores =
            storeController.dashboardVisitAgainStoreList ?? <Store>[];
        if (stores.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 12),
              child: Text(
                displayCaps('order_again'.tr),
                style: TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: displayTracking(0.8),
                  color: WaddyColors.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeMedium,
                ),
                itemCount: stores.length > 8 ? 8 : stores.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder:
                    (context, index) => _OrderAgainChip(
                      store: stores[index],
                      onTap: () => _openStoreFromDashboard(stores[index]),
                    ),
              ),
            ),
            // Trails into the chart below it, which is the section this one
            // sets up — the feed owns the outer gaps, this is only the seam
            // between "your usual" and "what's fastest right now".
            const SizedBox(height: _Gap.section),
          ],
        );
      },
    );
  }
}

class _OrderAgainChip extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;
  const _OrderAgainChip({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: '${'order_again'.tr}: ${store.name ?? ''}',
      scale: WaddyMotion.pressTile,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 14, 8),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: WaddyColors.divider),
          boxShadow: const [
            BoxShadow(
              color: WaddyColors.shadowTeal,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WaddyColors.surfaceRaised,
                border: Border.all(
                  color: WaddyColors.primarySurface,
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: CustomImage(
                  image: store.logoFullUrl ?? '',
                  fit: BoxFit.cover,
                  width: 44,
                  height: 44,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name ?? '',
                    // No height override: waddyBold already carries 1.3, and
                    // the only reason to reach past it here would be to fit a
                    // box this text comfortably fits anyway.
                    style: waddyBold.copyWith(
                      fontSize: 12.5,
                      color: WaddyColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (store.deliveryTime != null &&
                      store.deliveryTime!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      store.deliveryTime!,
                      style: waddyRegular.copyWith(
                        fontSize: 11,
                        color: WaddyColors.inkLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Places to Visit — live 1v1 panel. One dark teal plate, one inset, and three
/// beats down it: an inline LIVE eyebrow, the head-to-head, and a mint button.
///
/// The head-to-head itself was never the problem — a two-sided race is exactly
/// what this card is about. What made the earlier version feel wrong were four
/// things around it, worth recording because they are easy to reintroduce:
///
/// 1. Five stacked bands — panel, teal strip, panel, mint slab, panel — in
///    ~150pt of height. The card oscillated between the same two colours four
///    times and so never established a ground, which is what made it read as a
///    foreign object rather than a card on this page.
/// 2. No single inset. The strips were full-bleed and the content was inset
///    12, so the card's left margin moved three times going down it.
/// 3. Inverted hierarchy. The mint slab was the largest, brightest area and
///    the button inside it was dark — loud container, quiet control. Mint is
///    now the smallest bright thing on the card, and it is the action.
/// 4. A match layout running a one-sided race. With a single entrant the third
///    column was a ghost "+" tile that read as a failed image load, and the
///    caption and the button then each restated the same fact.
///
/// (4) is fixed by picking the shape from the data instead of forcing one
/// shape onto every case: two entrants get the 1v1, one entrant gets a single
/// standing row, and no state has to draw a placeholder standing in for an
/// opponent that doesn't exist.
///
/// The 1v1 is one line tall — logos flanking, names leading in from each side,
/// scoreline between them, one split bar underneath carrying the balance. Two
/// stacked standings with a bar each said the same thing in twice the height.
///
/// Data binds to PlacesController.liveStandings (leaderboard-first,
/// vote-sorted).
class _PlacesTicketCard extends StatefulWidget {
  final dynamic module;
  final VoidCallback onTap;

  const _PlacesTicketCard({required this.module, required this.onTap});

  @override
  State<_PlacesTicketCard> createState() => _PlacesTicketCardState();
}

/// Contender thumbnail edge. These photos are identification, not content —
/// they only have to say "this one, not that one" next to a name.
///
/// In the 1v1 row they are the tallest thing in the line, so this number *is*
/// the height of the card's body: every point here is a point of card. 36 is
/// the floor at which a logo mark is still recognisable at arm's length.
const double _kSpotTile = 32;

/// Internal seam between the card's three beats (standings / stakes / button).
///
/// Was 8. On a dark panel every seam has to work harder than it does on white —
/// there is no page showing through to separate the rows, so the only thing
/// holding them apart is the gap itself, and at 8 the card read as one dense
/// block rather than three beats. 12 matches the seam above it.
const double _kCardSeam = Dimensions.paddingSizeMedium;

/// Skeleton fill for this card only.
///
/// [SpotsSkeleton] is the app's Spots loading language, but it is built for the
/// light Spots screens — a `canvasDot` box on this dark teal panel would be the
/// brightest thing on the card and read as arrived content rather than as an
/// absence. A low-alpha white is the same idea rendered for a dark ground.
const Color _kSkeletonFill = Color(0x14FFFFFF);

/// Width reserved for the centred scoreline.
///
/// Fixed, and the scoreline scales down inside it rather than pushing outward.
/// That inversion is what makes a centred score survivable here: this layout
/// was rejected once because a centred score is fixed-width and cannot shrink,
/// so a four-digit tally ate the names from the middle out and eventually
/// overflowed the row. Capping the column and letting the *type* shrink means
/// the names lose a flat 22pt versus the outward-tally layout (108pt each on a
/// 393pt phone, down from 130) and lose nothing further no matter how large
/// the counts get. Every child in the row is now fixed-width or ellipsised.
const double _kScoreCol = 64;

class _PlacesTicketCardState extends State<_PlacesTicketCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStandings());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _loadStandings() {
    try {
      if (!Get.isRegistered<PlacesController>()) return;
      final c = Get.find<PlacesController>();
      // liveStandings prefers the leaderboard; make sure both are primed.
      // Skip anything already being fetched — at boot another caller has
      // usually started the same request a frame earlier.
      if ((c.leaderboard == null || c.leaderboard!.isEmpty) &&
          !c.isLeaderboardLoading) {
        c.getLeaderboard(limit: 3, reload: true);
      }
      if ((c.places == null || c.places!.isEmpty) && !c.isPlacesLoading) {
        c.getPlaces(reload: true);
      }
    } catch (e) {
      debugPrint('Error loading places standings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Honor the OS reduce-motion setting: freeze the LIVE pulse.
    if (MediaQuery.of(context).disableAnimations) {
      if (_pulse.isAnimating) {
        _pulse.stop();
        _pulse.value = 1.0;
      }
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }

    return Pressable(
      onTap: widget.onTap,
      semanticLabel: 'places_to_visit'.tr,
      // PlacesController only ever calls id-scoped update([...]), and a
      // GetBuilder without an id is not in any id's listener group — so the
      // un-id'd builder that used to sit here never rebuilt after its first
      // frame. The card was built while the leaderboard was in flight, painted
      // the skeleton, and stayed there until something unrelated happened to
      // plain-update the controller (a manual pull-to-refresh did). The card
      // reads both the leaderboard and the places list (liveStandings falls
      // back to the second), so it listens on both ids.
      child: GetBuilder<PlacesController>(
        id: PlacesController.idLeaderboard,
        builder:
            (_) => GetBuilder<PlacesController>(
              id: PlacesController.idPlaces,
              builder: (c) {
                final standings = c.liveStandings;
                // Loading is not the same fact as "nobody has entered", and this card
                // used to state the second while the first was true. On every cold
                // start the standings are empty for as long as the leaderboard is in
                // flight, so the most prominent card in the fold greeted the user
                // with "Be the first to make a move." — and then, a beat later,
                // replaced it with a live 1v1 that had been running all week. The
                // one card whose entire job is to say "this is happening right now"
                // opened by claiming nothing was happening.
                if (standings.isEmpty &&
                    (c.isLeaderboardLoading || c.isPlacesLoading)) {
                  return _matchCard(null, null, loading: true);
                }
                final leader = standings.isNotEmpty ? standings[0] : null;
                final runner = standings.length > 1 ? standings[1] : null;
                return _matchCard(leader, runner, fieldSize: c.contenderTotal);
              },
            ),
      ),
    );
  }

  /// Always shown; the copy carries the low-activity framing instead of hiding
  /// the card.
  Widget _matchCard(
    Place? leader,
    Place? runner, {
    int? fieldSize,
    bool loading = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // The module tiles above are a flat fade with no shadow of their own,
        // so this card does not match an elevation — it reads as a distinct
        // dark panel dropped onto a light page, not a tile among tiles.
        color: Spots.panel,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      ),
      // The single inset. Everything inside lines up to it — no full-bleed
      // children, so the card has exactly one left edge.
      padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(),
          // _kCardSeam, not paddingSizeLarge (20): this seam and the one below
          // the standings were asymmetric for no documented reason — 20 above,
          // 12 below — which is also 8pt this card doesn't need. Matching them
          // buys back that height without touching the button (fixed at the
          // 44pt touch-target floor) or the feed's own gaps around the card.
          const SizedBox(height: _kCardSeam),
          if (loading) _standingsSkeleton() else _standings(leader, runner),
          // The stakes line only earns its place in a real race, where it says
          // something the numbers don't ("one vote flips this"). Against a
          // single entrant it could only paraphrase the row above it or the
          // button below it, so it is dropped rather than padded out.
          // The stakes line binds tighter to the bar above it than to the
          // button below — it explains the standing, it does not introduce the
          // action. Taking these two gaps from 12 to 8 is also where the card
          // gives back height; the button stays at 44 because that is the
          // touch-target floor, and shrinking a control to save 3pt is the
          // wrong place to find it.
          // No stakes line. It existed to say what the numbers meant for the
          // next tap ("tied", "leads by 3") back when the tallies sat apart
          // under their own names and the reader had to compare them. A
          // centred `1 : 1` states the whole standing in one glance, so the
          // sentence could only paraphrase the row above it — and it was the
          // most expensive row on the card at 29pt with its seam.
          const SizedBox(height: _kCardSeam),
          if (loading)
            _buttonSkeleton()
          else
            _actionButton(runner, fieldSize, empty: leader == null),
        ],
      ),
    );
  }

  // ── ● LIVE · MAADI SPOT BATTLE ················· 🏆 ──
  //
  // An inline eyebrow rather than a full-bleed strip. As a band it was a
  // separate surface for a label — a whole background colour spent on four
  // words, and one only 6% off the panel it sat on, so it separated the card
  // into two pieces without ever looking like a deliberate division.
  //
  // The type carries the split instead: LIVE in mint (it is a status), the
  // subject in dim white (it is a name). The trophy moves to the far end,
  // where it reads as a mark on the row rather than as a glyph jammed into the
  // middle of letter-spaced caps.
  Widget _eyebrow() {
    // Backend zone lookup (_zoneLabel) is unreliable right now and we only
    // serve Maadi, so show it directly instead of the fetched zone name.
    final String subject =
        '${displayCaps('nearest_zone_maadi'.tr)} ${displayCaps('spot_battle'.tr)}';

    // A LIVE badge with no clock is a claim with nothing behind it — the card
    // asserted urgency and then gave the user no reason to act now rather than
    // Thursday. The trophy that used to sit at this end was decoration; the
    // deadline is the thing that actually earns the far edge.
    final Duration left = SpotsRound.remaining();
    final bool urgent = SpotsRound.isUrgent(left);

    return Row(
      children: [
        FadeTransition(
          // Eased rather than linear: a linear ramp between two opacities
          // strobes, an eased one breathes. This is the one piece of
          // permanent motion on the screen, so it has to be the calm kind.
          opacity: Tween(
            begin: 1.0,
            end: 0.3,
          ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Spots.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Text(
          'live'.tr,
          style: Spots.kicker(11, color: Spots.mint, tracking: 0.1),
        ),
        Expanded(
          child: Padding(
            // The subject is centred on the row, but the row's two ends are
            // different widths (LIVE is shorter than the countdown), so
            // centring inside the leftover space lands the title off the
            // card's true centre. Equal insets here make the available box
            // symmetric before the text is centred in it.
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeSmall,
            ),
            child: Text(
              subject,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Spots.kicker(14, color: Colors.white),
            ),
          ),
        ),
        Text(
          // `short`, not `countdown`. The full clock ends in seconds, and
          // nothing on this card ever rebuilds it: `left` is read once during
          // build, and the only animation here is a FadeTransition driven by
          // _pulse, which repaints without re-running this method. So the
          // seconds were frozen — two screenshots of the same session showed
          // "2d 9h 14:55" and "2d 5h 26:22", a clock that visibly disagrees
          // with itself and is wrong the moment it is painted.
          //
          // The honest options were a 1Hz Timer or a coarser unit. `short`
          // was written for exactly this call site ("Deliberately not
          // second-accurate… the user is not watching it tick, they are
          // deciding what to eat") and had no callers. A stale "2d 9h" stays
          // true for an hour; a stale "14:55" is a lie every second.
          SpotsRound.short(left),
          maxLines: 1,
          // Mint, matching LIVE at the other end of the row. The two together
          // bracket the eyebrow in the card's status colour and leave the
          // subject between them in plain dim white — status, name, status.
          // At 75% white the deadline was the same colour as ordinary copy,
          // which is a strange way to render the one fact on the card with an
          // expiry on it. Red still wins in the last day; that is a different
          // claim ("now or never") and it should not share mint's voice.
          style: Spots.kicker(
            10,
            color: urgent ? Spots.red : Spots.mint,
            tracking: 0.06,
          ),
        ),
      ],
    );
  }

  // ── the standings themselves ──
  //
  // Two shapes, picked by how many entrants there actually are, because that
  // is the thing the old scoreboard got wrong: it had one shape and forced the
  // other case into it.
  //
  //   two entrants → a real 1v1. Logos flank, names lead in from each side,
  //                  and the scoreline sits between them.
  //   one entrant  → a single standing row. No opponent column to leave empty,
  //                  so nothing has to be drawn as a ghost.
  Widget _standings(Place? leader, Place? runner) {
    if (leader == null) return _noEntrants();
    if (runner == null) return _soloRow(leader);

    // liveStandings sorts by votes and tie-breaks on *rating*, so position 0
    // is not necessarily the side that is ahead — at level votes it is just
    // the better-rated place. Accenting it anyway crowned an arbitrary winner
    // and made the card contradict its own "every vote can change it" line.
    // Level votes means no leader, so both sides stay at full brightness.
    final bool tied = leader.votesCount == runner.votesCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_versusRow(leader, runner, tied: tied)],
    );
  }

  /// The scoreboard line: two contenders facing each other across a centred
  /// score, the way a football board reads.
  ///
  ///     [◉] Starbucks        1 : 1        Dunkin [◉]
  ///
  /// The per-side tallies that used to sit under each name are gone — the
  /// score states the same fact once, in the middle, where a score belongs.
  /// That removes a whole text row from the card and is most of where the
  /// card's height came down.
  ///
  /// The unit rides under the colon rather than beside each number. "1" with
  /// no unit anywhere leaves a first-timer unable to tell votes from wins from
  /// rounds, but the label only has to appear once, and the score column is
  /// shorter than the logos flanking it — so this line costs no height at all.
  ///
  /// When [tied] both sides are drawn identically — a genuine mirror. Level
  /// votes mean no leader, and accenting position 0 anyway crowned whichever
  /// side happened to be better rated.
  ///
  /// Each side is its own tap target, and tapping it votes for that side.
  /// There is no single "vote" action on a 1v1 — a vote needs a side — so the
  /// contenders are the affordance, not the button underneath.
  Widget _versusRow(Place leader, Place runner, {required bool tied}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _contenderSide(
            leader,
            ahead: true,
            align: TextAlign.start,
            side: WaddyColors.contenderWarm,
          ),
        ),
        _scoreColumn(leader, runner, tied: tied),
        Expanded(
          child: _contenderSide(
            runner,
            ahead: tied,
            align: TextAlign.end,
            side: WaddyColors.contenderCool,
          ),
        ),
      ],
    );
  }

  /// `1 : 1` over a single VOTES label, each numeral in its own side's colour
  /// so the score can be read without tracing back to a name.
  Widget _scoreColumn(Place leader, Place runner, {required bool tied}) {
    return SizedBox(
      width: _kScoreCol,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _scoreText(leader),
                  style: Spots.display(26, color: WaddyColors.mint),
                ),
                Text(
                  ' : ',
                  style: Spots.display(
                    16,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                Text(
                  _scoreText(runner),
                  style: Spots.display(26, color: WaddyColors.mint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'spots_votes_label_other'.tr,
            maxLines: 1,
            style: Spots.kicker(
              13,
              color: Colors.white.withValues(alpha: 0.45),
              tracking: 0.14,
            ),
          ),
        ],
      ),
    );
  }

  /// Logo + name for one side, wrapped in its own press target.
  Widget _contenderSide(
    Place place, {
    required bool ahead,
    required TextAlign align,
    required Color side,
  }) {
    final bool leading = align == TextAlign.start;
    final logo = _contenderLogo(place, side: side);
    final name = Flexible(
      child: Text(
        place.title,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Spots.display(
          18,
          color: ahead ? Colors.white : Colors.white.withValues(alpha: 0.8),
        ).copyWith(height: 1.1),
      ),
    );

    return Pressable(
      onTap: () => openVoteSheet(place.id),
      semanticLabel: 'places_vote_for'.trParams({'name': place.title}),
      scale: WaddyMotion.pressTile,
      child: Row(
        mainAxisAlignment:
            leading ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children:
            leading
                ? [
                  logo,
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  name,
                ]
                : [
                  name,
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  logo,
                ],
      ),
    );
  }

  /// Compact tally for the scoreline: 1284 -> 1.3k.
  ///
  /// The grouped form ("1,284") is right in a table and wrong on a board — it
  /// is three glyphs longer, and every one of them comes out of the names.
  String _scoreText(Place? place) {
    final n = place?.votesCount ?? 0;
    if (n < 1000) return '$n';
    final double k = n / 1000;
    return k >= 10 ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
  }

  Widget _contenderLogo(Place place, {required Color side}) {
    return Container(
      width: _kSpotTile,
      height: _kSpotTile,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        // The edge names the side, it does not rank it. Marking "who is ahead"
        // here duplicated what the tally and the bar already said, and in a tie
        // it had to be switched on for both sides to avoid crowning an
        // arbitrary winner — a signal that has to be disabled to stay honest is
        // not carrying information.
        border: Border.all(color: WaddyColors.mint, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
        child: _photo(place.image),
      ),
    );
  }

  /// One entrant, no opponent: logo, name, tally. No bar — a lone bar filled
  /// to 100% reads as a completed progress bar ("this is over"), which is the
  /// opposite of what a card asking for a challenger should say.
  Widget _soloRow(Place place) {
    final int count = place.votesCount;
    return Pressable(
      onTap: () => openVoteSheet(place.id),
      semanticLabel: 'places_vote_for'.trParams({'name': place.title}),
      scale: WaddyMotion.pressTile,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _contenderLogo(place, side: WaddyColors.contenderWarm),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          Expanded(
            child: Text(
              place.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Spots.display(
                15,
                color: Colors.white,
              ).copyWith(height: 1.1),
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Text(
            _voteText(place),
            style: Spots.display(16, color: WaddyColors.contenderWarm),
          ),
          const SizedBox(width: 3),
          Text(
            count == 1
                ? 'spots_votes_label_one'.tr
                : 'spots_votes_label_other'.tr,
            style: Spots.kicker(
              10,
              color: Colors.white.withValues(alpha: 0.65),
              tracking: 0.06,
            ),
          ),
        ],
      ),
    );
  }

  /// The 1v1 row's own shape, drawn empty, while the standings load.
  ///
  /// Built from the same constants as the real row — [_kSpotTile], the same
  /// gaps, the same bar height — so the card does not resize when the data
  /// lands. That is the whole point of a skeleton: if it occupies different
  /// space than the thing it stands in for, it has traded a lie about the
  /// content for a jolt in the layout.
  Widget _standingsSkeleton() {
    return _shimmer(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _sideSkeleton(leading: true)),
              const SizedBox(width: _kScoreCol),
              Expanded(child: _sideSkeleton(leading: false)),
            ],
          ),
        ],
      ),
    );
  }

  /// One sweep for the whole skeleton rather than one per box: several shimmers
  /// running side by side on independent clocks reads as flicker, not loading.
  Widget _shimmer(Widget child) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return Shimmer(duration: const Duration(seconds: 2), child: child);
  }

  Widget _sideSkeleton({required bool leading}) {
    final logo = Container(
      width: _kSpotTile,
      height: _kSpotTile,
      decoration: BoxDecoration(
        color: _kSkeletonFill,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
    );
    // One bar, matching the one line of name the real row now has.
    final lines = Flexible(child: _skeletonBar(width: 72, height: 13));

    return Row(
      mainAxisAlignment:
          leading ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children:
          leading
              ? [
                logo,
                const SizedBox(width: Dimensions.paddingSizeSmall),
                lines,
              ]
              : [
                lines,
                const SizedBox(width: Dimensions.paddingSizeSmall),
                logo,
              ],
    );
  }

  Widget _skeletonBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _kSkeletonFill,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
    );
  }

  /// The button's footprint, held open while loading. Its label depends on the
  /// standings ("Add a rival" vs "See all 12"), so it cannot be drawn honestly
  /// yet — but leaving it out entirely would collapse the card and then push
  /// everything below it down when the data arrives.
  Widget _buttonSkeleton() {
    return _shimmer(
      Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          color: _kSkeletonFill,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        ),
      ),
    );
  }

  /// Nobody has entered yet. One quiet line — the button underneath is the
  /// whole call to action, so this only has to set it up.
  ///
  /// The live Rive trophy sits centred above the line: an empty board is an open
  /// crown, and a bare sentence on a dark panel read as a broken card rather
  /// than an invitation. The whole card (and the button) lead into the Places
  /// module, where the user picks the spot to put the first vote on.
  Widget _noEntrants() {
    // Full width on purpose: a shrink-wrapped Column is as wide as its text and
    // the parent pins it to the start edge, so "centred" meant centred over the
    // text, which sat on the left of the card.
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SpotsTrophyGlyph(size: 64),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            'places_first_votes'.tr,
            textAlign: TextAlign.center,
            style: waddyRegular.copyWith(
              fontSize: 13,
              height: 1.3,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  // ── the mint button ──
  //
  // Mint is now the smallest bright area on the card and it is the control, so
  // the loudest thing the eye lands on is the thing to press. Previously the
  // mint was a full-bleed slab with a *dark* pill inside it: the biggest,
  // brightest region was decoration, and the button read as a hole punched in
  // it rather than as a raised control.
  Widget _actionButton(Place? runner, int? fieldSize, {bool empty = false}) {
    // The label now names where the button actually goes.
    //
    // It used to read "Settle it" and then open the standings table, because a
    // 1v1 has no single vote to cast — a vote needs a side. So the loudest,
    // most action-shaped control on the home screen performed navigation while
    // promising an action, and the user arrived at a table still looking for
    // the vote. Voting moved onto the contenders themselves (see
    // [_contenderSide]), which is where people aim anyway, and this button went
    // back to being what it always was: the way into the full table.
    //
    // "Add a rival" still lands on the submission form — with one entrant there
    // is no table worth opening.
    final bool countable = fieldSize != null && fieldSize > 2;
    final String label =
        empty
            ? 'spots_crown_open_cta'.tr
            : runner == null
            ? 'places_add_rival'.tr
            : countable
            ? 'places_see_all_count'.trParams({'count': '$fieldSize'})
            : 'places_see_all'.tr;
    // Filled mint only when this button is genuinely the primary action, which
    // is now just the one-entrant case ("Add a rival" — there is no table worth
    // opening yet). In a live 1v1 the primary actions are the two contenders
    // above, so this drops to a ghost: still obviously pressable, no longer
    // the brightest object on the card competing with the thing it introduces.
    final bool primary = runner == null;

    // The nested detector wins the hit test over the card-wide Pressable, so
    // without a press state of its own the card's single loudest button was
    // the one control on the screen that answered a tap with nothing.
    return Pressable(
      onTap:
          primary && !empty
              ? () => Get.toNamed(RouteHelper.placeSubmit)
              : widget.onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressCard,
      child: Container(
        width: double.infinity,
        // Clears Apple's 44pt minimum on its own, so the button does not need
        // the card behind it to be a usable target.
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeMedium,
        ),
        decoration: BoxDecoration(
          color: primary ? Spots.mint : Colors.transparent,
          border:
              primary
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Spots.kicker(
                  primary ? 14 : 12,
                  color: primary ? Spots.panel : Colors.white,
                  tracking: 0.03,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '→',
              style: Spots.display(
                primary ? 14 : 12,
                color: primary ? Spots.panel : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const _PlacePhotoFallback();
    }
    // Contain, not cover: these are venue logos/marks — cropping their edges
    // off makes them look broken. The white tile behind keeps odd aspect
    // ratios and transparent PNGs presentable.
    return Padding(
      padding: const EdgeInsets.all(0),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        placeholder: (_, __) => const _PlacePhotoFallback(),
        errorWidget: (_, __, ___) => const _PlacePhotoFallback(),
      ),
    );
  }

  String _voteText(Place? place) {
    final n = place?.votesCount ?? 0;
    // Group thousands: 1284 -> 1,284
    return n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
  }
}

/// Photo fallback while places load (or have no image) — flat, quiet.
class _PlacePhotoFallback extends StatelessWidget {
  const _PlacePhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WaddyColors.surfaceRaised,
      child: Icon(
        Icons.explore_rounded,
        size: 22,
        color: WaddyColors.ink.withValues(alpha: 0.35),
      ),
    );
  }
}

/// Fallback content so the dashboard never dead-ends into empty space —
/// renders only when the store's recommended list actually has stores;
/// stays hidden otherwise (RecommendedStoreView already handles that gate).
class _RecommendedFallbackSection extends StatelessWidget {
  const _RecommendedFallbackSection();

  /// Vertical inset [RecommendedStoreView] applies to itself.
  ///
  /// It is shared with the shop and pharmacy home screens, whose convention is
  /// the opposite of this feed's — there every section carries its own spacing
  /// and the parent Column adds none — so it cannot simply be stripped. This
  /// section absorbs it instead, and the subtraction lives here, next to the
  /// reason, rather than as a bare number in the feed's gap list.
  static const double _ownInset = Dimensions.paddingSizeDefault;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.recommendedId,
      builder: (storeController) {
        final stores = storeController.recommendedStoreList;
        if (stores == null || stores.isEmpty) {
          return const _SectionErrorSlot(section: HomeSection.recommended);
        }
        // The feed deliberately emits no gap before this section: the seam is
        // made up here so it comes out at _Gap.major like every other one. It
        // used to be the widget's own 16 alone — the narrowest seam in the
        // bottom half of the feed, directly after the widest.
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: _Gap.major - _ownInset),
            RecommendedStoreView(),
          ],
        );
      },
    );
  }
}

/// Food Offers section — shows discounted food items only (not grocery)
class _FoodOffersSection extends StatelessWidget {
  const _FoodOffersSection();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ItemController>(
      builder: (itemController) {
        final allItems = itemController.popularItemList;
        if (allItems == null || allItems.isEmpty) {
          return const _SectionErrorSlot(section: HomeSection.offers);
        }

        // Filter: only food module items with discounts
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

        List<Item> offerItems;
        if (foodModuleId != null) {
          offerItems =
              allItems
                  .where(
                    (item) =>
                        item.moduleId == foodModuleId &&
                        item.discount != null &&
                        item.discount! > 0,
                  )
                  .toList();
        } else {
          // Fallback: show all items with discounts
          offerItems =
              allItems
                  .where((item) => item.discount != null && item.discount! > 0)
                  .toList();
        }

        if (offerItems.isEmpty) return const SizedBox.shrink();

        // No outer padding: the feed owns the gap above this section (see
        // [_Gap]). The 16pt top that used to live here stacked on _Gap.major
        // for a 44pt seam — the widest on the page — and the header's own 8pt
        // top pushed it to 52.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // Header binds to the rail it introduces at _Gap.bind, the
              // same seam every other section header on this page uses
              // (_RailHeader). It was 8, so this one header sat tighter to
              // its content than any other.
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeDefault,
                0,
                Dimensions.paddingSizeDefault,
                _Gap.bind,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: WaddyColors.coral,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'food_offers'.tr,
                    style: waddyBold.copyWith(
                      fontSize: 16,
                      color: WaddyColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 175,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  left: Dimensions.paddingSizeDefault,
                ),
                itemCount: offerItems.length > 10 ? 10 : offerItems.length,
                itemBuilder:
                    (_, index) => Padding(
                      padding: const EdgeInsets.only(
                        right: Dimensions.paddingSizeMedium,
                      ),
                      child: _FoodOfferCard(item: offerItems[index]),
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FoodOfferCard extends StatelessWidget {
  final Item item;
  const _FoodOfferCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = item.discount != null && item.discount! > 0;

    return Pressable(
      onTap: () => Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, false)),
      semanticLabel: item.name ?? '',
      scale: WaddyMotion.pressTile,
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 105,
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                color: WaddyColors.surfaceRaised,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomImage(
                      image: '${item.imageFullUrl}',
                      fit: BoxFit.cover,
                    ),
                    if (hasDiscount)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.paddingSizeSmall,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: WaddyColors.coral,
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                          ),
                          child: Text(
                            item.discountType == 'percent'
                                ? '${item.discount!.toInt()}% ${'off'.tr.toUpperCase()}'
                                : '${PriceConverter.convertPrice(item.discount)} ${'off'.tr.toUpperCase()}',
                            style: waddyBold.copyWith(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name ?? '',
              style: waddyMedium.copyWith(fontSize: 13, color: WaddyColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.storeName ?? '',
                    style: waddyRegular.copyWith(
                      fontSize: 11,
                      color: WaddyColors.inkLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.price != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: WaddyColors.mintSurface,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusSmall,
                      ),
                    ),
                    child: Text(
                      PriceConverter.convertPrice(item.price),
                      style: waddyBold.copyWith(
                        fontSize: 11,
                        color: WaddyColors.primary,
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

/// Loading state for the module grid.
///
/// Every metric here is deliberately copied from [_ModuleTile]'s grid — three
/// columns, the same spacings, padding, aspect and radius — so the placeholder
/// and the real content are the same shape and the same height. That is what
/// lets the swap be a fade instead of a reflow: a shimmer of six squares
/// followed by a row of three is a layout change dressed up as a loading state,
/// and the page visibly jumps under the user's thumb the moment data lands.
class ModuleShimmer extends StatelessWidget {
  final bool isEnabled;
  const ModuleShimmer({super.key, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          // Matches the real grid's gutters exactly (see _buildModuleGrid) —
          // otherwise the crossfade between shimmer and content jumps layout.
          mainAxisSpacing: Dimensions.paddingSizeDefault,
          crossAxisSpacing: Dimensions.paddingSizeDefault,
          childAspectRatio: _kModuleTileAspect,
        ),
        padding: EdgeInsets.zero,
        itemCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Shimmer(
            duration: const Duration(seconds: 2),
            enabled: isEnabled,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                // The tile's own resting plate, not a grey box: the fade then
                // resolves mint-into-mint instead of grey-into-mint, and the
                // eye reads one element arriving rather than two swapping.
                // No border — flat, matching the tile it stands in for.
                color: WaddyColors.mintSurface,
              ),
            ),
          );
        },
      ),
    );
  }
}

class AddressShimmer extends StatelessWidget {
  final bool isEnabled;
  const AddressShimmer({super.key, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: Dimensions.paddingSizeSmall),

        SizedBox(
          height: 70,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: 5,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeSmall,
            ),
            itemBuilder: (context, index) {
              return Container(
                width: 300,
                padding: const EdgeInsets.only(
                  right: Dimensions.paddingSizeSmall,
                ),
                child: Container(
                  padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 40,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Expanded(
                        child: Shimmer(
                          duration: const Duration(seconds: 2),
                          enabled: isEnabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 15,
                                width: 100,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(
                                height: Dimensions.paddingSizeExtraSmall,
                              ),
                              Container(
                                height: 10,
                                width: 150,
                                color: Colors.grey[300],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
