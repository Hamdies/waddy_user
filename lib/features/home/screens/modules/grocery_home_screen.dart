import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/cuisine/controllers/cuisine_controller.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_category_circles.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_list.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_row_card.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_semantics.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_top_brands_grid.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/ramadan_reorder_section.dart';
import 'package:waddy_app/features/banner/controllers/banner_controller.dart';
import 'package:waddy_app/features/home/widgets/banner_view.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/location/widgets/coming_soon_delivery.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';

// ── Filter chip metrics ──────────────────────────────────────────────────────
// Same numbers as the food home's strip, so the two module homes hold the
// same control at the same size. See food_home_screen.dart for the reasoning
// behind each.
const double _kChipHeight = 34;
const double _kChipRadius = 30;
const double _kChipRowHeight = 44;
const double _kChipStripTopPad = Dimensions.paddingSizeMedium;
const double _kChipStripBottomPad = Dimensions.paddingSizeMedium;
const double _kChipGap = 9;

// ── Section rhythm ───────────────────────────────────────────────────────────
/// Between two unrelated sections.
const double _kSectionGap = Dimensions.paddingSizeExtraLarge;

/// Between a section and the content that belongs to it.
const double _kSectionGapTight = Dimensions.paddingSizeMedium;

/// Grocery module home, laid out like the food home:
///
///   hero → banner → Top brands grid → Buy again → ─── →
///   "All stores" header → category strip → pinned chips → store rows
///
/// The category strip plays the part food's cuisine strip does ("All stores",
/// Supermarkets, Dairy, …) and filters the store list below it server-side.
class GroceryHomeScreen extends StatefulWidget {
  final ScrollController scrollController;
  const GroceryHomeScreen({super.key, required this.scrollController});

  @override
  State<GroceryHomeScreen> createState() => _GroceryHomeScreenState();
}

class _GroceryHomeScreenState extends State<GroceryHomeScreen> {
  /// `StoreController.moduleFilters` is the only copy of the browse filters.
  ///
  /// This screen used to keep four `setState` fields alongside it and push them
  /// in without ever reading back — `F-02`'s defect, verbatim. `DashboardScreen`
  /// builds its pages with a `PageView.builder` that keeps nothing alive, so a
  /// hop to Orders disposed this State: the chips came back empty while the
  /// controller was still filtering the list, and the only way out was to
  /// toggle a chip on and off again.
  ModuleStoreFilters get _filters =>
      Get.find<StoreListController>().moduleFilters;

  /// Rides the cuisine filter slot: main categories are cuisines scoped to
  /// the grocery module, so the backend's `cuisine_id` filter serves both.
  int? get _selectedMainCategoryId => _filters.cuisineId;
  bool get _filterOffers => _filters.offers;
  bool get _filterUnder30 => _filters.maxDeliveryTime != null;
  bool get _filterFreeDelivery => _filters.freeDelivery;

  /// Change one filter, keeping the rest. The controller refetches and
  /// notifies; every surface that renders filter state is a `GetBuilder` on it,
  /// so nothing here calls `setState` for a filter any more.
  void _applyFilters(ModuleStoreFilters next) {
    Get.find<StoreListController>().setModuleStoreFilters(next);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    Get.find<CuisineController>().getCuisineList(false);
    if (Get.find<AddressController>().addressList == null) {
      Get.find<AddressController>().getAddressList();
    }

    // Feeds this screen's BannerView. See the same call in FoodHomeScreen for
    // why home_screen's loadData cannot be relied on: it branches on a
    // `splashController.module` snapshot taken before `/api/v1/module` has
    // answered on a cold start, and never requests `/api/v1/banners` at all.
    Get.find<BannerController>().getBannerList(false);
  }

  // Filters are applied server-side: results cover the whole catalog,
  // not just the pages loaded so far.
  void _onMainCategoryTap(int? id) {
    _applyFilters(
      _filters.copyWith(cuisineId: _selectedMainCategoryId == id ? null : id),
    );
  }

  bool get _hasAnyBrowseFilters =>
      _selectedMainCategoryId != null ||
      _filterOffers ||
      _filterUnder30 ||
      _filterFreeDelivery;

  /// Returns a SLIVER — see FoodHomeScreen for why. This screen is rendered
  /// directly into the home screen's `CustomScrollView`, so it belongs in
  /// `slivers:`, not inside a box.
  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        // ── Hero (compact: deliver-to + cart + search) ──
        const SliverToBoxAdapter(
          child: HomeHeroBannerWidget(showBackButton: true, compact: true),
        ),
        // No current-order card here: grocery opens straight onto its banner.
        // Live orders stay reachable from the Orders tab and the order push.
        const SliverToBoxAdapter(child: SizedBox(height: _kSectionGapTight)),

        // ── Banner — first thing under the hero ──
        const SliverToBoxAdapter(
          child: BannerView(isFeatured: false, showRamadanWrapper: false),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: _kSectionGap)),

        // ── Top brands — 3×2 logo grid, perk collar under each ──
        SliverToBoxAdapter(child: const ModuleTopBrandsGrid()),
        const SliverToBoxAdapter(child: SizedBox(height: _kSectionGap)),

        // ── Buy again — owns its own bottom gap, collapses when empty ──
        SliverToBoxAdapter(child: _buildBuyAgainSection(context)),

        const SliverToBoxAdapter(child: _SectionDivider()),
        const SliverToBoxAdapter(child: SizedBox(height: _kSectionGap)),

        // ── Catalogue: header → category strip → pinned chips → rows ──
        SliverToBoxAdapter(child: _buildCatalogueHeader(context)),
        SliverToBoxAdapter(
          // The selected tile's ring is filter state, and the screen does not
          // rebuild when that changes — so the strip subscribes itself.
          //
          // Main categories (Supermarkets, Roasteries, …) are what a store
          // IS — the same store-level tag food uses for cuisines, scoped to
          // this module by the backend. Item categories (Fresh Milk, Frozen)
          // are the aisles inside a store and belong on the store page.
          child: GetBuilder<StoreListController>(
            id: StoreListController.cuisineStripId,
            builder:
                (_) => ModuleCuisineCircles(
                  selectedCuisineId: _selectedMainCategoryId,
                  onCuisineTap: _onMainCategoryTap,
                  // No leading tile, same as food: the header above already
                  // reads "All stores" while nothing is picked.
                  showAllTile: false,
                  allLabel: 'all_stores'.tr,
                  fallbackIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedStore01,
                    size: 26,
                    color: Theme.of(context).primaryColor,
                  ),
                  // The chip strip below supplies its own top pad.
                  bottomPadding: 0,
                ),
          ),
        ),
        // Pinned for the same reason as food's: the chips narrow a list you
        // are scrolling *through*, so they stay in reach while you do.
        SliverPersistentHeader(
          pinned: true,
          delegate: _FilterChipsHeader(child: _buildFilterChips(context)),
        ),
        // No trailing spacer: the store list is the last element and reserves
        // the cart bar's overlay itself via isLastInScrollView.
        _buildStoreListSliver(context),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // BUY AGAIN — Normal + Ramadan themed
  // ═══════════════════════════════════════════
  Widget _buildBuyAgainSection(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<HomeController>(
      builder: (homeController) {
        final bool isRamadan = homeController.showRamadanDecorations;

        return GetBuilder<StoreListController>(
          id: StoreListController.visitAgainId,
          builder: (storeController) {
            final stores = storeController.visitAgainStoreList;
            if (stores == null || stores.isEmpty) return const SizedBox();

            if (isRamadan) {
              return RamadanReorderSection(
                stores: stores,
                titleFontSize: 18,
                subtitleFontSize: 12,
                listHeight: 162,
                bottomPadding: _kSectionGap,
                subtitleGap: 12,
              );
            }
            return _buildNormalBuyAgain(
              context,
              stores,
              primaryColor,
              accentColor,
            );
          },
        );
      },
    );
  }

  // ── Normal (non-Ramadan) Buy Again ──
  Widget _buildNormalBuyAgain(
    BuildContext context,
    List<Store> stores,
    Color primaryColor,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Text(
              'buy_again'.tr,
              style: waddyBold.copyWith(fontSize: 18, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Text(
              'a_quick_way_to_find_your_go_to_items'.tr,
              style: waddyRegular.copyWith(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              itemCount: stores.length > 5 ? 5 : stores.length,
              itemBuilder: (context, index) {
                return _buildBuyAgainCard(
                  context,
                  stores[index],
                  primaryColor,
                  accentColor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyAgainCard(
    BuildContext context,
    Store store,
    Color primaryColor,
    Color accentColor,
  ) {
    final items = store.items ?? [];
    final int totalItems = store.itemCount ?? items.length;
    final displayItems = items.take(4).toList();
    final int remaining = totalItems - displayItems.length;

    return PressableScale(
      semanticLabel: moduleStoreSemanticLabel(store),
      onTap: () => StoreNavigator.open(store),
      child: Container(
        width: 168,
        margin: const EdgeInsets.only(right: Dimensions.paddingSizeMedium),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                      border: Border.all(color: Colors.grey.shade200),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                      child: CustomImage(
                        image: store.logoFullUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name ?? '',
                          style: waddyBold.copyWith(
                            fontSize: 12.5,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        ZoneAware(
                          builder: (context) {
                            if (isComingSoon) {
                              return const ComingSoonText(fontSize: 11);
                            }
                            if (store.deliveryTime == null) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              '${store.deliveryTime}',
                              style: waddyRegular.copyWith(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeSmall,
                ),
                child:
                    displayItems.isNotEmpty
                        ? GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 5,
                                crossAxisSpacing: 5,
                              ),
                          itemCount:
                              displayItems.length > 4 ? 4 : displayItems.length,
                          itemBuilder: (context, index) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                              ),
                              padding: const EdgeInsets.all(7),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                                child: CustomImage(
                                  image: displayItems[index].imageFullUrl ?? '',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        )
                        : Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
              ),
            ),
            if (remaining > 0)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: Dimensions.paddingSizeSmall,
                  top: Dimensions.paddingSizeExtraSmall,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeMedium,
                    vertical: Dimensions.paddingSizeExtraSmall,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                  ),
                  child: Text(
                    '+$remaining ${'more'.tr}',
                    style: waddyMedium.copyWith(
                      fontSize: 10.5,
                      color: primaryColor,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CATALOGUE HEADER
  // ═══════════════════════════════════════════

  /// Names what the list is showing: "All stores" when no category is picked,
  /// "Dairy · 4 stores" when one is. Same job as food's header — the strip
  /// scrolls sideways, so the selected tile can be off screen, and this is the
  /// on-screen statement of what was picked.
  ///
  /// The count is the server's total for the whole active filter set, not the
  /// pages loaded so far.
  Widget _buildCatalogueHeader(BuildContext context) {
    return GetBuilder<CuisineController>(
      builder: (cuisineController) {
        return GetBuilder<StoreListController>(
          id: StoreListController.storeListId,
          builder: (storeController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeDefault,
                0,
                Dimensions.paddingSizeDefault,
                _kSectionGapTight,
              ),
              child: Text(
                _catalogueHeadline(cuisineController, storeController),
                style: waddyBold.copyWith(fontSize: 18, color: WaddyColors.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        );
      },
    );
  }

  /// Falls back to the plain "All stores" whenever a specific claim can't be
  /// made — nothing selected, a name we can't resolve, or a list still loading.
  String _catalogueHeadline(
    CuisineController cuisineController,
    StoreListController storeController,
  ) {
    final int? id = _selectedMainCategoryId;
    if (id == null) return 'all_stores'.tr;

    final String name = cuisineController.namesFor([id]).trim();
    if (name.isEmpty) return 'all_stores'.tr;

    final int? total = storeController.storeModel?.totalSize;
    if (total == null) return name;

    return (total == 1
            ? 'category_store_count_one'
            : 'category_store_count_other')
        .trParams({'category': name, 'count': '$total'});
  }

  // ═══════════════════════════════════════════
  // FILTER CHIPS
  // ═══════════════════════════════════════════

  /// Three one-tap toggles — Offers · Under 30 mins · Free delivery. Grocery
  /// has no sort sheet, so every filter it owns fits on the strip itself and
  /// needs no sheet behind an icon.
  ///
  /// Its own `GetBuilder`: the strip lives in a pinned header whose delegate
  /// the screen's build owns, and nothing rebuilds that on a filter change.
  Widget _buildFilterChips(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.storeListId,
      builder: (_) => _filterChipsRow(context),
    );
  }

  Widget _filterChipsRow(BuildContext context) {
    final List<({String label, bool active, VoidCallback onTap})> chips = [
      (
        label: 'offers'.tr,
        active: _filterOffers,
        onTap: () => _applyFilters(_filters.copyWith(offers: !_filterOffers)),
      ),
      (
        label: 'under_30_mins'.tr,
        active: _filterUnder30,
        onTap:
            () => _applyFilters(
              _filters.copyWith(maxDeliveryTime: _filterUnder30 ? null : 30),
            ),
      ),
      (
        label: 'free_delivery'.tr,
        active: _filterFreeDelivery,
        onTap:
            () => _applyFilters(
              _filters.copyWith(freeDelivery: !_filterFreeDelivery),
            ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(
        top: _kChipStripTopPad,
        bottom: _kChipStripBottomPad,
      ),
      child: SizedBox(
        height: _kChipRowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          itemCount: chips.length,
          separatorBuilder: (_, __) => const SizedBox(width: _kChipGap),
          itemBuilder: (context, index) {
            final chip = chips[index];
            return _FilterChip(
              label: chip.label,
              active: chip.active,
              onTap: chip.onTap,
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STORE LIST
  // ═══════════════════════════════════════════

  /// GetBuilder contributes no RenderObject of its own, so it can return a
  /// sliver directly — no adapter needed, which is the point.
  Widget _buildStoreListSliver(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.storeListId,
      builder: (storeController) {
        final bool hasFilters = _hasAnyBrowseFilters;

        return ModuleStoreListSliver(
          scrollController: widget.scrollController,
          // Last element in the grocery home — reserves the cart-bar overlay.
          isLastInScrollView: true,
          storeModel: storeController.storeModel,
          shimmer: _buildStoreListShimmer(),
          emptyIcon: const HugeIcon(
            icon: HugeIcons.strokeRoundedStore01,
            size: 52,
            color: WaddyColors.inkMuted,
          ),
          emptyTitle:
              hasFilters ? 'no_stores_in_category'.tr : 'no_store_available'.tr,
          emptySubtitle:
              hasFilters
                  ? 'try_different_filters'.tr
                  : 'try_different_category'.tr,
          cardBuilder:
              (store) => ModuleStoreRowCard(
                store: store,
                onTap: () => StoreNavigator.open(store),
              ),
        );
      },
    );
  }

  /// Shaped like [ModuleStoreRowCard] — see the food home's shimmer for why
  /// the numbers are the card's, not approximations of them.
  Widget _buildStoreListShimmer() {
    Widget bar({required double width, required double height}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: WaddyColors.divider,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Column(
        children: List.generate(
          6,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Shimmer(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: WaddyColors.divider,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(width: 170, height: 18),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),
                        bar(width: 130, height: 14),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        bar(width: 120, height: 23),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One toggle pill on the chip strip. Same fill/hairline language as the food
/// home's chips: brand fill when on, raised surface + hairline when off.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PressableScale(
        semanticLabel: active ? '$label, ${'selected'.tr}' : label,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          height: _kChipHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeMedium,
          ),
          decoration: BoxDecoration(
            color:
                active
                    ? Theme.of(context).primaryColor
                    : WaddyColors.surfaceRaised,
            borderRadius: BorderRadius.circular(_kChipRadius),
            border:
                active
                    ? null
                    : Border.all(color: WaddyColors.divider, width: 1),
          ),
          child: Text(
            label,
            style: waddyMedium.copyWith(
              fontSize: 14,
              color: active ? Colors.white : WaddyColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hairline closing the top-of-page block before the catalogue starts.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      child: Divider(height: 1, thickness: 1, color: WaddyColors.divider),
    );
  }
}

/// Holds the chip strip at the top of the viewport once the category tiles
/// have scrolled past. Opaque, because it sits over the rows sliding beneath.
class _FilterChipsHeader extends SliverPersistentHeaderDelegate {
  static const double _height =
      _kChipStripTopPad + _kChipRowHeight + _kChipStripBottomPad;

  final Widget child;

  const _FilterChipsHeader({required this.child});

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(color: Theme.of(context).cardColor, child: child);
  }

  /// The strip is self-updating (its own GetBuilder); the height is fixed.
  @override
  bool shouldRebuild(_FilterChipsHeader oldDelegate) => false;
}
