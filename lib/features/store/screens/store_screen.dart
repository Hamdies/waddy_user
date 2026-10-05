import 'package:waddy_app/features/store/widgets/store_page_shimmer.dart';
import 'package:waddy_app/features/scratch_card/widgets/scratch_card_badge.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/store/controllers/store_page_controller.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/domain/models/store_bundle_model.dart';
import 'package:waddy_app/features/review/controllers/review_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/store/widgets/store_banner_widget.dart';
import 'package:waddy_app/features/store/widgets/store_best_sellers_section.dart';
import 'package:waddy_app/features/store/widgets/store_special_offer_view.dart';
import 'package:waddy_app/features/store/widgets/filter_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/store/widgets/store_ramadan_stall_view.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/store/screens/store_category_items_screen.dart';
import 'package:waddy_app/features/review/screens/review_screen.dart';
import 'package:waddy_app/features/cart/widgets/pill_cart_bar.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_category_circles.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/store/widgets/store_product_card.dart';
import 'package:waddy_app/features/store/helpers/item_count_label.dart';
import 'package:waddy_app/features/store/helpers/shelf_listings.dart';
import 'package:waddy_app/features/store/widgets/store_notices.dart';
import 'package:waddy_app/features/store/widgets/store_info_sheet.dart';
import 'package:waddy_app/features/store/widgets/store_section_header.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/motion.dart';

part 'store_aisles/store_aisles_sections.dart';

/// The aisle page: supermarkets only. Every other store gets the menu page
/// (`FoodStoreScreen`); `StoreLayout` in `store_navigator.dart` decides which,
/// before either is built. Open a store with `StoreNavigator.open`.
class StoreScreen extends StatefulWidget {
  final Store? store;
  final String slug;
  const StoreScreen({super.key, required this.store, this.slug = ''});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final ScrollController scrollController = ScrollController();

  /// This page's own state (ST-01/ST-07): opened with the page, deleted with
  /// it. The aisle page, in-store search and the filter sheet it opens are
  /// handed this same controller.
  late final StorePageController _page;

  /// Height the anchored cart bar reports, reserved as tail space so the last
  /// rail never ends up under it. See [PillCartBar.onHeightChanged].
  double _cartBarHeight = 0;

  /// Whether the mini header is down: true once the store header's search
  /// bar has scrolled away. Flips only on crossing [_kMiniHeaderAt], and
  /// rebuilds only the mini header.
  final ValueNotifier<bool> _mini = ValueNotifier<bool>(false);
  static const double _kMiniHeaderAt = 120;

  void _onScroll() {
    final bool mini =
        scrollController.hasClients && scrollController.offset > _kMiniHeaderAt;
    if (mini != _mini.value) _mini.value = mini;
  }

  @override
  void initState() {
    super.initState();
    _page = StorePageController.open();
    scrollController.addListener(_onScroll);
    _initDataCall();
  }

  @override
  void dispose() {
    _page.close();
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    _mini.dispose();
    super.dispose();
  }

  Future<void> _initDataCall() async {
    final StorePageController storeCtrl = _page;
    storeCtrl.resetFilter(isUpdate: false);
    // Also the pull-to-refresh handler: the rails refetch with it. Nothing
    // else needs resetting — this page's controller was created for it.
    storeCtrl.resetStoreRails(notify: false);
    if (storeCtrl.isSearching) {
      storeCtrl.changeSearchStatus(isUpdate: false);
    }
    await storeCtrl.getStoreDetails(
      Store(id: widget.store!.id),
      slug: widget.slug,
    );
    if (Get.find<CategoryController>().categoryList == null) {
      Get.find<CategoryController>().getCategoryList(true);
    }
    final storeId = widget.store!.id ?? storeCtrl.store!.id;
    storeCtrl.getStoreBannerList(storeId);
    storeCtrl.getRestaurantRecommendedItemList(storeId, false);
    storeCtrl.getStoreItemList(storeId, 1, 'all', false);
    storeCtrl.getStoreBundleList(storeId);
    storeCtrl.getBuyAgain(storeId);
    Get.find<ReviewController>().getStoreReviewList(storeId.toString());
    // No scroll listener. Pagination left this page when the rails started
    // fetching their own items (see `_rail`; "View all" opens the paginated
    // aisle), and the fav-button toggle it also ran drove a flag no widget
    // read — while a bare update() rebuilt every store builder in the app on
    // each scroll-direction change (ST-07).
  }

  /// One product rail, fed by [StorePageController.fetchStoreRail].
  ///
  /// Fetches when first built — and the category rails sit in a lazy sliver
  /// list, so that is when the rail nears the viewport, not on page load.
  /// Rebuilds only itself when its items land. Collapses when the store has
  /// nothing for it (or nothing that passes the filters). A product the store
  /// lists twice shows once ([ShelfListings.dedupe]).
  Widget _rail(
    String key, {
    int categoryId = 0,
    String? sort,
    Widget placeholder = const SizedBox.shrink(),
    required Widget Function(List<Item> items) builder,
  }) {
    return GetBuilder<StorePageController>(
      tag: _page.tag,
      id: StorePageController.storeRailId(key),
      builder: (storeController) {
        final List<Item>? items = storeController.storeRail(key);
        if (items == null) {
          // Post-frame: the fetch notifies, and a notify mid-build throws.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => storeController.fetchStoreRail(
              key,
              categoryId: categoryId,
              sort: sort,
            ),
          );
          return placeholder;
        }
        if (items.isEmpty) return const SizedBox.shrink();
        return builder(ShelfListings.dedupe(items));
      },
    );
  }

  // No layout switch here any more (ST-06). This screen used to fetch the
  // store, then return a `FoodStoreScreen` from build when it turned out to be
  // a specialty grocery store — a second page set-up for one open, and a latch
  // to survive the blank between them. The route shell picks the page first.
  @override
  Widget build(BuildContext context) => _buildAisles(context);

  Widget _buildAisles(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: WaddyColors.canvas,
      body: GetBuilder<StorePageController>(
        tag: _page.tag,
        builder: (storeController) {
          return GetBuilder<CategoryController>(
            builder: (categoryController) {
              // The gate is the store payload alone (`G-02`, `F-03`'s twin).
              // The global category list feeds exactly one thing — the categories
              // row and the per-category sections, both already behind an
              // `isNotEmpty` check — but it used to gate the *whole* screen, so a
              // slow or failed `/categories` held the search bar, banners, offers
              // and reviews behind a shimmer with the store in hand. Since `M-02`
              // clears the list on a module change, that was reliably hit when a
              // store was opened from the dashboard. This is a `GetBuilder` on the
              // category controller, so the categories appear the moment they land.
              final Store? store =
                  storeController.store?.name != null
                      ? storeController.store
                      : null;
              if (store == null) return StorePageShimmer(store: widget.store);

              if (categoryController.categoryList != null) {
                storeController.setCategoryList();
              }

              // The store's own main categories, in admin order. The
              // details payload derives `category_ids` from the items the
              // store actually holds, so each one has at least one product.
              final storeCategories = _byPriority(
                store,
                (storeController.categoryList ?? [])
                    .where((c) => c.id != 0)
                    .toList(),
              );
              final aisles = _groupAisles(storeCategories);
              final Map<int, int> itemCounts = {
                for (final c
                    in store.categoryDetails ?? const <CategoryModel>[])
                  if (c.id != null && c.itemsCount != null)
                    c.id!: c.itemsCount!,
              };

              return Stack(
                children: [
                  // No top inset here: the hero paints behind the status bar
                  // and applies the inset itself, like the module home's.
                  SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        // ─── SCROLLABLE CONTENT ───
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _initDataCall,
                            // A `CustomScrollView`, not a `ListView(children:)`
                            // (`G-03`): the aisle groups are a
                            // `SliverList.builder`, so one is constructed as
                            // it approaches the viewport — and its rail
                            // fetches then, not on page load.
                            child: CustomScrollView(
                              controller: scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                // ─── HEADER: store, search, promises ───
                                SliverToBoxAdapter(
                                  child: StoreHeroBannerWidget(
                                    store: store,
                                    onStoreTap:
                                        () =>
                                            StoreInfoSheet.show(context, store),
                                    onFilterTap:
                                        () => _openFilterSheet(
                                          context,
                                          storeController,
                                        ),
                                    trailing:
                                        ScratchCardBadge.inBags
                                            ? const ScratchCardSticker(
                                              width: 34,
                                              height: 40,
                                              flips: true,
                                            )
                                            : null,
                                  ),
                                ),

                                // ─── STORE-WIDE DISCOUNT BANNER ───
                                if (store.discount != null &&
                                    (store.discount!.discount ?? 0) > 0)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: Dimensions.paddingSizeLarge,
                                      ),
                                      child: StoreDiscountBanner(store: store),
                                    ),
                                  ),

                                // ─── SHOP BY CATEGORY ───
                                if (storeCategories.isNotEmpty)
                                  SliverToBoxAdapter(
                                    child: _buildCategoriesRow(
                                      context,
                                      storeController,
                                      storeCategories,
                                    ),
                                  ),

                                // ─── BUY AGAIN (returning customers) ───
                                SliverToBoxAdapter(child: _buildBuyAgain()),

                                // ─── BEST SELLERS ───
                                // Header + ranked hero + aisle chips + ranked
                                // cards. It decides for itself whether the
                                // sales are real enough to rank ("Top picks"
                                // otherwise) — see StoreBestSellersSection.
                                SliverToBoxAdapter(
                                  child: _rail(
                                    'popular',
                                    sort: 'popular',
                                    placeholder: const _RailPlaceholder(),
                                    builder:
                                        (items) => StoreBestSellersSection(
                                          items: items,
                                          storeName: store.name ?? '',
                                          categories: storeCategories,
                                        ),
                                  ),
                                ),

                                // ─── STORE BANNERS ───
                                SliverToBoxAdapter(
                                  child: StoreBannerWidget(
                                    storeController: storeController,
                                  ),
                                ),

                                // ─── OFFERS: Ramadan stall, else carousel ───
                                SliverToBoxAdapter(
                                  child: _rail(
                                    'discounted',
                                    sort: 'discounted',
                                    builder: (discountedItems) {
                                      final recommended =
                                          storeController
                                              .recommendedItemModel
                                              ?.items ??
                                          const <Item>[];
                                      if (Get.find<HomeController>()
                                          .showRamadanDecorations) {
                                        return StoreRamadanStallView(
                                          recommendedItems: recommended,
                                          discountedItems: discountedItems,
                                          storeName: store.name ?? '',
                                        );
                                      }
                                      if (discountedItems.length < 3) {
                                        return const SizedBox.shrink();
                                      }
                                      return StoreSpecialOfferView(
                                        items: discountedItems,
                                      );
                                    },
                                  ),
                                ),

                                // ─── AISLE GROUPS: a few aisles behind tabs,
                                // mint panel ↔ row tiles (dark is offers') ───
                                SliverList.builder(
                                  itemCount: aisles.groups.length,
                                  itemBuilder: (context, index) {
                                    final group = aisles.groups[index];
                                    return _AisleGroup(
                                      key: ValueKey<int?>(group.first.id),
                                      categories: group,
                                      style:
                                          _AisleStyle.values[index %
                                              _AisleStyle.values.length],
                                      itemCounts: itemCounts,
                                      onSeeAll:
                                          (category) => _openCategory(
                                            storeController,
                                            category,
                                          ),
                                      rail:
                                          (
                                            category, {
                                            required placeholder,
                                            required builder,
                                          }) => _rail(
                                            'category_${category.id}',
                                            categoryId: category.id ?? 0,
                                            placeholder: placeholder,
                                            builder: builder,
                                          ),
                                    );
                                  },
                                ),

                                // ─── MORE AISLES: the rest, as tiles ───
                                if (aisles.rest.isNotEmpty)
                                  SliverToBoxAdapter(
                                    child: _buildMoreAisles(
                                      storeController,
                                      aisles.rest,
                                      itemCounts,
                                    ),
                                  ),

                                // ─── STORE BUNDLES / COLLECTIONS ───
                                if (storeController.storeBundleList != null &&
                                    storeController.storeBundleList!.isNotEmpty)
                                  SliverToBoxAdapter(
                                    child: _buildStoreBundlesSection(
                                      context,
                                      storeController,
                                      primaryColor,
                                    ),
                                  ),

                                // ─── REVIEWS PREVIEW ───
                                SliverToBoxAdapter(
                                  child: _buildReviewsPreview(
                                    context,
                                    store,
                                    primaryColor,
                                  ),
                                ),

                                // ─── ANNOUNCEMENT ───
                                SliverToBoxAdapter(
                                  child: StoreAnnouncement(store: store),
                                ),

                                // ─── CAN'T FIND SOMETHING ───
                                SliverToBoxAdapter(
                                  child: _buildCantFind(store),
                                ),

                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height:
                                        _cartBarHeight +
                                        Dimensions.paddingSizeExtraLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── STATUS-BAR SCRIM ───
                  // The hero scrolls away; this keeps the clock off the
                  // content sliding under it. Same tint as the hero's first
                  // stop, so at rest the two are one surface.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.paddingOf(context).top,
                    child: ColoredBox(
                      color: HomeHeroBannerWidget.statusBarTint,
                    ),
                  ),

                  // ─── MINI HEADER ───
                  // Slides down once the store header has scrolled away, so
                  // search and the cart stay one tap off wherever you are.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _mini,
                      builder:
                          (context, visible, _) =>
                              StoreMiniHeader(store: store, visible: visible),
                    ),
                  ),

                  // ─── CART BAR (bottom) ───
                  // The one cart surface on a grocery store page. Always
                  // present — never hidden on scroll — because with no toast
                  // on add this bar IS the confirmation. It draws nothing
                  // while the cart is empty.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: PillCartBar(
                      store: store,
                      onHeightChanged: (h) {
                        if (!mounted || (h - _cartBarHeight).abs() < 0.5) {
                          return;
                        }
                        setState(() => _cartBarHeight = h);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Price-range filter for the aisles, opened from the hero's filter button.
  void _openFilterSheet(
    BuildContext context,
    StorePageController storeController,
  ) {
    final maxPrice = (storeController.storeItemModel?.items ?? []).fold<double>(
      0,
      (prev, item) => (item.price ?? 0) > prev ? item.price! : prev,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => FilterWidget(
            page: _page,
            maxValue: maxPrice > 0 ? maxPrice : 1000,
          ),
    );
  }

  /// Aisles that get a rail, at most [_kAisleGroups] groups of
  /// [_kAisleGroupSize]. Past that, aisles are tiles (`_buildMoreAisles`).
  static const int _kAisleGroupSize = 6;
  static const int _kAisleGroups = 3;

  /// Splits the store's aisles, in admin order, into evenly sized tab groups
  /// for the rails, and the rest for the tile grid. Even sizes, so no group
  /// is left holding one lonely tab: 8 aisles are 4 + 4, not 6 + 2.
  ({List<List<CategoryModel>> groups, List<CategoryModel> rest}) _groupAisles(
    List<CategoryModel> categories,
  ) {
    final int railed = categories.length.clamp(
      0,
      _kAisleGroupSize * _kAisleGroups,
    );
    if (railed == 0) return (groups: const [], rest: const []);
    final int count = (railed / _kAisleGroupSize).ceil();
    final int base = railed ~/ count;
    final int extra = railed % count;
    final List<List<CategoryModel>> groups = [];
    int start = 0;
    for (int i = 0; i < count; i++) {
      final int size = base + (i < extra ? 1 : 0);
      groups.add(categories.sublist(start, start + size));
      start += size;
    }
    return (groups: groups, rest: categories.sublist(railed));
  }

  /// [categories] in the admin's priority order, highest first.
  ///
  /// The list arrives in the order of the module-wide `/categories` call,
  /// which is priority order only while the admin's "category list default"
  /// setting is on. The store's details payload sorts its own
  /// `category_details` by priority regardless, so its order is the one to
  /// trust. Anything it doesn't list keeps its place, at the end.
  List<CategoryModel> _byPriority(Store store, List<CategoryModel> categories) {
    final List<int?> order = [
      for (final c in store.categoryDetails ?? const <CategoryModel>[]) c.id,
    ];
    if (order.isEmpty) return categories;
    int rank(CategoryModel c) {
      final int i = order.indexOf(c.id);
      return i < 0 ? order.length : i;
    }

    // `List.sort` isn't stable; sorting on (rank, original index) is.
    final List<(int, int, CategoryModel)> keyed = [
      for (int i = 0; i < categories.length; i++)
        (rank(categories[i]), i, categories[i]),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    return [for (final k in keyed) k.$3];
  }

  /// Opens one aisle's full, paginated item list.
  void _openCategory(
    StorePageController storeController,
    CategoryModel category,
  ) {
    final int index = storeController.categoryList!.indexWhere(
      (c) => c.id == category.id,
    );
    if (index < 0) return;
    storeController.setCategoryIndex(index);
    Get.to(
      () => StoreCategoryItemsScreen(
        page: _page,
        storeId: storeController.store!.id,
        categoryName: category.name ?? '',
      ),
    );
  }
}
