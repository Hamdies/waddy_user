import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_best_nearby_section.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_category_circles.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_ribbon_sticker.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_list.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_semantics.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/ramadan_reorder_section.dart';
import 'package:waddy_app/features/home/widgets/banner_view.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/location/widgets/coming_soon_delivery.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/home/widgets/current_order_widget.dart';

class GroceryHomeScreen extends StatefulWidget {
  final ScrollController scrollController;
  const GroceryHomeScreen({super.key, required this.scrollController});

  @override
  State<GroceryHomeScreen> createState() => _GroceryHomeScreenState();
}

class _GroceryHomeScreenState extends State<GroceryHomeScreen> {
  static const double _sectionGapXS = 8;
  static const double _sectionGapS = 12;
  static const double _sectionGapM = 16;
  static const double _sectionGapL = 24;

  /// `StoreController.moduleFilters` is the only copy of the browse filters.
  ///
  /// This screen used to keep four `setState` fields alongside it and push them
  /// in without ever reading back — `F-02`'s defect, verbatim. `DashboardScreen`
  /// builds its pages with a `PageView.builder` that keeps nothing alive, so a
  /// hop to Orders disposed this State: the chips came back empty while the
  /// controller was still filtering the list, and the only way out was to
  /// toggle a chip on and off again.
  ModuleStoreFilters get _filters => Get.find<StoreController>().moduleFilters;

  int? get _selectedCategoryId => _filters.categoryId;
  bool get _filterOffers => _filters.offers;
  bool get _filterUnder30 => _filters.maxDeliveryTime != null;
  bool get _filterFreeDelivery => _filters.freeDelivery;

  /// Change one filter, keeping the rest. The controller refetches and
  /// notifies; every surface that renders filter state is a `GetBuilder` on it,
  /// so nothing here calls `setState` for a filter any more.
  void _applyFilters(ModuleStoreFilters next) {
    Get.find<StoreController>().setModuleStoreFilters(next);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    Get.find<CategoryController>().getCategoryList(false);
    if (Get.find<AddressController>().addressList == null) {
      Get.find<AddressController>().getAddressList();
    }
  }

  // Filters are applied server-side: results cover the whole catalog,
  // not just the pages loaded so far.
  void _onCategoryTap(int? categoryId) {
    _applyFilters(
      _filters.copyWith(
        categoryId: _selectedCategoryId == categoryId ? null : categoryId,
      ),
    );
  }

  bool get _hasActiveChipFilter =>
      _filterOffers || _filterUnder30 || _filterFreeDelivery;

  bool get _hasAnyBrowseFilters =>
      _selectedCategoryId != null || _hasActiveChipFilter;

  /// Clears every browse filter. Unlike food's sheet, which owns only its own
  /// two switches, grocery's sheet owns the category tiles as well — so its
  /// reset and the header's reset clear the same four things.
  void _clearAllBrowseFilters() {
    _applyFilters(
      _filters.copyWith(
        categoryId: null,
        offers: false,
        freeDelivery: false,
        maxDeliveryTime: null,
      ),
    );
  }

  Object _storeScreenArguments(Store store) =>
      StoreScreen(store: store, fromModule: false);

  void _showBrowseRefineSheet(BuildContext context) {
    final categoryController = Get.find<CategoryController>();
    final categories = categoryController.categoryList ?? [];
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Dimensions.radiusExtraLarge),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          // A `GetBuilder` on the store controller, not a `StatefulBuilder`:
          // the sheet renders in its own overlay route, so it subscribes to the
          // filter state itself rather than waiting for the screen behind it.
          child: GetBuilder<StoreController>(
            builder: (_) {
              Widget buildCategoryTile({
                required String label,
                String? imageUrl,
                required bool isSelected,
                required VoidCallback onTap,
              }) {
                return PressableScale(
                  semanticLabel:
                      isSelected ? '$label, ${'selected'.tr}' : label,
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 92,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeSmall,
                      vertical: Dimensions.paddingSizeSmall,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusLarge,
                      ),
                      border: Border.all(
                        color:
                            isSelected
                                ? primaryColor.withValues(alpha: 0.22)
                                : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? accentColor.withValues(alpha: 0.15)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusLarge,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusLarge,
                            ),
                            child:
                                imageUrl != null && imageUrl.isNotEmpty
                                    ? CustomImage(
                                      image: imageUrl,
                                      fit: BoxFit.cover,
                                    )
                                    : Icon(
                                      Icons.storefront_rounded,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : Colors.grey.shade500,
                                    ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: waddyMedium.copyWith(
                            fontSize: 11,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              Widget buildFilterTile({
                required String label,
                required bool isActive,
                required VoidCallback onTap,
                required IconData icon,
              }) {
                return PressableScale(
                  semanticLabel: isActive ? '$label, ${'selected'.tr}' : label,
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeMedium,
                      vertical: Dimensions.paddingSizeSmall,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? primaryColor : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusLarge,
                      ),
                      border: Border.all(
                        color: isActive ? primaryColor : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.check_circle_rounded : icon,
                          size: 16,
                          color: isActive ? accentColor : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: waddyMedium.copyWith(
                            fontSize: 12,
                            color: isActive ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'apply_filters'.tr,
                            style: waddyBold.copyWith(
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed:
                              _hasAnyBrowseFilters
                                  ? _clearAllBrowseFilters
                                  : null,
                          child: Text('reset'.tr),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'browse_all_stores'.tr,
                      style: waddyMedium.copyWith(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        buildCategoryTile(
                          label: 'all_stores'.tr,
                          isSelected: _selectedCategoryId == null,
                          onTap:
                              () => _applyFilters(
                                _filters.copyWith(categoryId: null),
                              ),
                        ),
                        ...categories.map(
                          (category) => buildCategoryTile(
                            label: category.name ?? '',
                            imageUrl: category.imageFullUrl,
                            isSelected: _selectedCategoryId == category.id,
                            onTap:
                                () => _applyFilters(
                                  _filters.copyWith(categoryId: category.id),
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'filter'.tr,
                      style: waddyMedium.copyWith(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        buildFilterTile(
                          label: 'offers'.tr,
                          isActive: _filterOffers,
                          onTap:
                              () => _applyFilters(
                                _filters.copyWith(offers: !_filterOffers),
                              ),
                          icon: Icons.local_offer_outlined,
                        ),
                        buildFilterTile(
                          label: 'under_30_mins'.tr,
                          isActive: _filterUnder30,
                          onTap:
                              () => _applyFilters(
                                _filters.copyWith(
                                  maxDeliveryTime: _filterUnder30 ? null : 30,
                                ),
                              ),
                          icon: Icons.access_time_rounded,
                        ),
                        buildFilterTile(
                          label: 'free_delivery'.tr,
                          isActive: _filterFreeDelivery,
                          onTap:
                              () => _applyFilters(
                                _filters.copyWith(
                                  freeDelivery: !_filterFreeDelivery,
                                ),
                              ),
                          icon: Icons.delivery_dining_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      buttonText: 'done'.tr,
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  /// Returns a SLIVER — see FoodHomeScreen for why. This screen is rendered
  /// directly into the home screen's `CustomScrollView`, so it belongs in
  /// `slivers:`, not inside a box.
  ///
  /// Grocery's catalogue is the longest list in the app, and as a `Column` every
  /// card in it was built and laid out in the first frame.
  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        // ── Hero banner (compact: deliver-to + cart + search) ──
        const SliverToBoxAdapter(
          child: HomeHeroBannerWidget(showBackButton: true, compact: true),
        ),

        // ── Current Order Status ──
        const SliverToBoxAdapter(child: CurrentOrderWidget()),
        const SliverToBoxAdapter(child: SizedBox(height: _sectionGapM)),

        // Re-Order (Buy Again) — first if exists
        SliverToBoxAdapter(child: _buildBuyAgainSection(context)),

        // "Big brands near you" — hero horizontal store cards
        SliverToBoxAdapter(
          child: ModuleBestNearbySection(
            title: 'best_store_nearby'.tr,
            stickerStyle: ModuleStickerStyle.grocery,
            closedLabel: 'closed'.tr.toUpperCase(),
            bottomPadding: _sectionGapL,
            shimmerBottomPadding: _sectionGapL,
            storeScreenBuilder: _storeScreenArguments,
          ),
        ),

        // Browse area is grouped as one visual band to reduce section noise.
        _buildBrowseSectionSliver(context),

        const SliverToBoxAdapter(child: SizedBox(height: _sectionGapL)),

        // Banner — single, optional, now treated as a secondary promo.
        const SliverToBoxAdapter(
          child: BannerView(isFeatured: false, showRamadanWrapper: false),
        ),

        // The banner, not the store list, is grocery's terminal element, so
        // the bottom-nav overlay is reserved here rather than inside
        // the store list. _sectionGapL alone left the banner under the bar.
        SliverToBoxAdapter(
          child: SizedBox(height: Dimensions.cartBarReserve(context)),
        ),
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

        return GetBuilder<StoreController>(
          builder: (storeController) {
            final stores = storeController.visitAgainStoreList;
            if (stores == null || stores.isEmpty) return const SizedBox();

            if (isRamadan) {
              return RamadanReorderSection(
                stores: stores,
                storeScreenBuilder: _storeScreenArguments,
                titleFontSize: 18,
                subtitleFontSize: 12,
                listHeight: 162,
                bottomPadding: _sectionGapM,
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
      padding: const EdgeInsets.only(bottom: _sectionGapM),
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
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: StoreScreen(store: store, fromModule: false),
          ),
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
  // "Browse all stores" HEADING
  // ═══════════════════════════════════════════
  Widget _buildBrowseAllStoresHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        0,
        Dimensions.paddingSizeDefault,
        10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'browse_all_stores'.tr,
              style: waddyBold.copyWith(fontSize: 18, color: Colors.black87),
            ),
          ),
          if (_hasAnyBrowseFilters)
            TextButton(
              onPressed: _clearAllBrowseFilters,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeSmall,
                  vertical: Dimensions.paddingSizeExtraSmall,
                ),
              ),
              child: Text('reset'.tr),
            ),
        ],
      ),
    );
  }

  /// The browse band, as a sliver.
  ///
  /// This used to be a `Container` with a tint and top/bottom borders wrapping
  /// a `Column` — which is exactly what forced the whole store catalogue to
  /// build up front. `DecoratedSliver` paints the same band behind a group of
  /// slivers instead, so the visual treatment survives and the list inside it
  /// stays lazy. The Container's vertical padding becomes leading and trailing
  /// spacers inside the decoration, so the tint still extends past the content
  /// the way it did.
  Widget _buildBrowseSectionSliver(BuildContext context) {
    final Color sectionTint = Theme.of(
      context,
    ).primaryColor.withValues(alpha: 0.025);
    final Color borderTint = Theme.of(
      context,
    ).secondaryHeaderColor.withValues(alpha: 0.08);

    return DecoratedSliver(
      decoration: BoxDecoration(
        color: sectionTint,
        border: Border(
          top: BorderSide(color: borderTint),
          bottom: BorderSide(color: borderTint),
        ),
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(height: Dimensions.paddingSizeMedium),
          ),
          // The three surfaces below render filter state, and the screen no
          // longer rebuilds when that changes — so each subscribes for itself:
          // the header's reset button, the selected tile's ring, and the refine
          // button's active count.
          SliverToBoxAdapter(
            child: GetBuilder<StoreController>(
              builder: (_) => _buildBrowseAllStoresHeader(context),
            ),
          ),
          SliverToBoxAdapter(
            child: GetBuilder<StoreController>(
              builder:
                  (_) => ModuleCategoryCircles(
                    selectedCategoryId: _selectedCategoryId,
                    onCategoryTap: _onCategoryTap,
                    allLabel: 'all'.tr,
                    allSemanticLabel: 'all_stores'.tr,
                    fallbackIcon: Icon(
                      Icons.storefront_rounded,
                      size: 26,
                      color: Theme.of(context).primaryColor,
                    ),
                    maxCategories: 3,
                    bottomPadding: 2,
                  ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: _sectionGapXS)),
          SliverToBoxAdapter(
            child: GetBuilder<StoreController>(
              builder: (_) => _buildRefineButton(context),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: _sectionGapS)),
          _buildStoreListSliver(context),
          const SliverToBoxAdapter(
            child: SizedBox(height: Dimensions.paddingSizeMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildRefineButton(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    final int activeFilterCount =
        (_selectedCategoryId != null ? 1 : 0) +
        (_filterOffers ? 1 : 0) +
        (_filterUnder30 ? 1 : 0) +
        (_filterFreeDelivery ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: PressableScale(
        semanticLabel: 'filter'.tr,
        onTap: () => _showBrowseRefineSheet(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeMedium,
            vertical: Dimensions.paddingSizeMedium,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.tune_rounded, size: 18, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'filter'.tr,
                      style: waddyMedium.copyWith(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeFilterCount > 0
                          ? 'apply_filters'.tr
                          : 'try_different_filters'.tr,
                      style: waddyRegular.copyWith(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (activeFilterCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeSmall,
                    vertical: Dimensions.paddingSizeExtraSmall,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    activeFilterCount.toString(),
                    style: waddyBold.copyWith(
                      fontSize: 11,
                      color: primaryColor,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STORE LIST — Talabat style vertical cards
  // ═══════════════════════════════════════════
  /// GetBuilder contributes no RenderObject of its own, so it can return a
  /// sliver directly — no adapter needed, which is the point.
  Widget _buildStoreListSliver(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<StoreController>(
      builder: (storeController) {
        final bool hasFilters =
            _selectedCategoryId != null || _hasActiveChipFilter;

        return ModuleStoreListSliver(
          scrollController: widget.scrollController,
          storeModel: storeController.storeModel,
          shimmer: _buildStoreListShimmer(),
          emptyIcon: const Icon(
            Icons.storefront_outlined,
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
              (store) =>
                  _buildStoreCard(context, store, primaryColor, accentColor),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // STORE CARD — Full-bleed cover + tilted items + sticker
  // ═══════════════════════════════════════════
  Widget _buildStoreCard(
    BuildContext context,
    Store store,
    Color primaryColor,
    Color accentColor,
  ) {
    final bool isOpen = store.open == 1;
    final stickers = moduleStickersForStore(store, ModuleStickerStyle.grocery);

    // Trigger fetch of recommended items for this store
    final storeController = Get.find<StoreController>();
    if (!storeController.storeRecommendedItems.containsKey(store.id)) {
      storeController.fetchStoreRecommendedItems(store.id!);
    }

    return PressableScale(
      semanticLabel: moduleStoreSemanticLabel(store),
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: StoreScreen(store: store, fromModule: false),
          ),
      child: Opacity(
        opacity: isOpen ? 1.0 : 0.55,
        child: Container(
          margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
            child: Stack(
              children: [
                // ── Full-bleed cover ──
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: CustomImage(
                    image: store.coverPhotoFullUrl ?? '',
                    fit: BoxFit.cover,
                  ),
                ),

                // ── Gradient overlay — bottom heavy ──
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          primaryColor.withValues(alpha: 0.6),
                          primaryColor.withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.2, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── Closed overlay ──
                if (!isOpen)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Dimensions.paddingSizeLarge,
                              vertical: Dimensions.paddingSizeSmall,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusExtraSmall,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Text(
                              'closed'.tr.toUpperCase(),
                              style: waddyBold.copyWith(
                                fontSize: 14,
                                color: Colors.black87,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Logo floating top-left ──
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                ),

                // ── Single sticker ribbon — right edge ──
                if (stickers.isNotEmpty && isOpen)
                  Positioned(
                    top: 12,
                    right: 0,
                    child: ModuleRibbonSticker(sticker: stickers.first),
                  ),

                // ── Tilted top items — bottom right ──
                if (isOpen)
                  Positioned(
                    bottom: 38,
                    right: 14,
                    child: GetBuilder<StoreController>(
                      builder: (sc) {
                        final items = sc.storeRecommendedItems[store.id];
                        if (items == null || items.isEmpty) {
                          return const SizedBox();
                        }
                        final topItems = items.take(3).toList();
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(topItems.length, (i) {
                            final angles = [-0.15, 0.1, -0.08];
                            final offsets = [6.0, 0.0, 4.0];
                            return Transform.translate(
                              offset: Offset(0, offsets[i % 3]),
                              child: Transform.rotate(
                                angle: angles[i % 3],
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusDefault,
                                    ),
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusSmall,
                                    ),
                                    child: CustomImage(
                                      image: topItems[i].imageFullUrl ?? '',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),

                // ── Bottom info overlay ──
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.name ?? '',
                                style: waddyBold.copyWith(
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              ZoneAware(
                                builder: (context) {
                                  if (isComingSoon) {
                                    return ModuleInfoPill(
                                      icon: Icons.schedule_rounded,
                                      text: 'coming_soon'.tr,
                                      bgColor: accentColor,
                                      textColor: primaryColor,
                                    );
                                  }
                                  if (store.deliveryTime == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return ModuleInfoPill(
                                    icon: Icons.schedule_rounded,
                                    text: '${store.deliveryTime}',
                                    bgColor: accentColor,
                                    textColor: primaryColor,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildStoreListShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Column(
        children: List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(
              bottom: Dimensions.paddingSizeMedium,
            ),
            child: Shimmer(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
