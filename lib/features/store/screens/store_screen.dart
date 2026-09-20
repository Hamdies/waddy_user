import 'package:flutter/rendering.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/domain/models/store_bundle_model.dart';
import 'package:waddy_app/features/review/controllers/review_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/store/widgets/store_banner_widget.dart';
import 'package:waddy_app/features/store/widgets/store_special_offer_view.dart';
import 'package:waddy_app/features/store/widgets/filter_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/store/widgets/store_details_screen_shimmer_widget.dart';
import 'package:waddy_app/features/store/widgets/store_ramadan_stall_view.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/store/screens/store_category_items_screen.dart';
import 'package:waddy_app/features/review/screens/review_screen.dart';
import 'package:waddy_app/features/dashboard/widgets/live_cart_widget.dart';

class StoreScreen extends StatefulWidget {
  final Store? store;
  final bool fromModule;
  final String slug;
  const StoreScreen({
    super.key,
    required this.store,
    required this.fromModule,
    this.slug = '',
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final ScrollController scrollController = ScrollController();
  bool _showLiveCart = true;

  @override
  void initState() {
    super.initState();
    _initDataCall();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _initDataCall() async {
    final storeCtrl = Get.find<StoreController>();
    storeCtrl.resetFilter(isUpdate: false);
    if (storeCtrl.isSearching) {
      storeCtrl.changeSearchStatus(isUpdate: false);
    }
    storeCtrl.hideAnimation();
    await storeCtrl
        .getStoreDetails(
          Store(id: widget.store!.id),
          widget.fromModule,
          slug: widget.slug,
        )
        .then((_) {
          storeCtrl.showButtonAnimation();
        });
    if (Get.find<CategoryController>().categoryList == null) {
      Get.find<CategoryController>().getCategoryList(true);
    }
    final storeId = widget.store!.id ?? storeCtrl.store!.id;
    storeCtrl.getStoreBannerList(storeId);
    storeCtrl.getRestaurantRecommendedItemList(storeId, false);
    storeCtrl.getStoreItemList(storeId, 1, 'all', false);
    storeCtrl.getSimilarStoreList(storeId);
    storeCtrl.getStoreBundleList(storeId);
    Get.find<ReviewController>().getStoreReviewList(storeId.toString());

    scrollController.addListener(() {
      if (scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (storeCtrl.showFavButton) {
          storeCtrl.changeFavVisibility();
          storeCtrl.hideAnimation();
        }
        if (_showLiveCart) {
          setState(() => _showLiveCart = false);
        }
      } else {
        if (!storeCtrl.showFavButton) {
          storeCtrl.changeFavVisibility();
          storeCtrl.showButtonAnimation();
        }
        if (!_showLiveCart) {
          setState(() => _showLiveCart = true);
        }
      }

      if (scrollController.position.pixels >
          scrollController.position.maxScrollExtent - 300) {
        final model = storeCtrl.storeItemModel;
        if (model != null && model.totalSize != null && model.items != null) {
          int currentOffset = model.offset ?? 1;
          int totalPages = (model.totalSize! / 10).ceil();
          if (currentOffset < totalPages && !storeCtrl.isLoading) {
            storeCtrl.getStoreItemList(
              widget.store!.id ?? storeCtrl.store!.id,
              currentOffset + 1,
              storeCtrl.type,
              false,
            );
          }
        }
      }
    });
  }

  Map<int, List<Item>> _groupItemsByCategory(List<Item> items) {
    final Map<int, List<Item>> grouped = {};
    for (final item in items) {
      final catId = item.categoryId ?? 0;
      grouped.putIfAbsent(catId, () => []);
      grouped[catId]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: GetBuilder<StoreController>(
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
              if (store == null) return const StoreDetailsScreenShimmerWidget();

              if (categoryController.categoryList != null) {
                storeController.setCategoryList();
              }

              final allItems = storeController.storeItemModel?.items ?? [];
              final groupedItems = _groupItemsByCategory(allItems);
              final storeCategories =
                  (storeController.categoryList ?? [])
                      .where((c) => c.id != 0)
                      .toList();
              final discountedItems =
                  allItems
                      .where((i) => i.discount != null && i.discount! > 0)
                      .toList();
              // Only the categories this store actually stocks get a rail (`G-03`).
              // Filtering here rather than returning a shrunk box from the builder
              // keeps the sliver dense, so its index is the rail's index and the
              // viewport does not have to walk past empty slots to find content.
              final stockedCategories =
                  storeCategories
                      .where(
                        (c) =>
                            (groupedItems[c.id] ?? const <Item>[]).isNotEmpty,
                      )
                      .toList();
              return Stack(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        // ─── APP BAR ───
                        _buildAppBar(
                          context,
                          store,
                          storeController,
                          primaryColor,
                        ),

                        // ─── SCROLLABLE CONTENT ───
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _initDataCall,
                            // A `CustomScrollView`, not a `ListView(children:)`
                            // (`G-03`). A children list is built in full before the
                            // list sees it, so a store stocking 20 categories
                            // constructed 20 horizontal rails and every product
                            // card in them on *every* build — and this screen
                            // rebuilds on each `StoreController` update, which
                            // includes each page of paginated items arriving. The
                            // rails are a `SliverList.builder` now, so one is
                            // constructed as it approaches the viewport. The
                            // section widgets themselves are unchanged; only how
                            // they are delivered is.
                            child: CustomScrollView(
                              controller: scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 12),
                                ),

                                // ─── SEARCH BAR + FILTER ───
                                SliverToBoxAdapter(
                                  child: _buildSearchBar(
                                    context,
                                    store,
                                    storeController,
                                    primaryColor,
                                  ),
                                ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 16),
                                ),

                                // ─── STORE-WIDE DISCOUNT BANNER ───
                                if (store.discount != null &&
                                    (store.discount!.discount ?? 0) > 0)
                                  SliverToBoxAdapter(
                                    child: _buildStoreDiscountBanner(
                                      context,
                                      store,
                                      primaryColor,
                                    ),
                                  ),

                                // ─── STORE BANNERS ───
                                SliverToBoxAdapter(
                                  child: StoreBannerWidget(
                                    storeController: storeController,
                                  ),
                                ),

                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 8),
                                ),

                                // ─── SHOP BY CATEGORIES ───
                                if (storeCategories.isNotEmpty)
                                  SliverToBoxAdapter(
                                    child: _buildCategoriesRow(
                                      context,
                                      storeController,
                                      storeCategories,
                                      primaryColor,
                                    ),
                                  ),

                                // ─── RAMADAN STALL — mixed offers + recommended ───
                                if (Get.find<HomeController>()
                                        .showRamadanDecorations &&
                                    ((storeController.recommendedItemModel !=
                                                null &&
                                            storeController
                                                .recommendedItemModel!
                                                .items!
                                                .isNotEmpty) ||
                                        discountedItems.isNotEmpty))
                                  SliverToBoxAdapter(
                                    child: StoreRamadanStallView(
                                      recommendedItems:
                                          storeController
                                              .recommendedItemModel
                                              ?.items ??
                                          [],
                                      discountedItems: discountedItems,
                                      storeName:
                                          storeController.store!.name ?? '',
                                    ),
                                  ),

                                // ─── SPECIAL OFFERS CAROUSEL ───
                                if (discountedItems.length >= 3)
                                  SliverToBoxAdapter(
                                    child: StoreSpecialOfferView(
                                      items: discountedItems,
                                    ),
                                  ),

                                // ─── PER-CATEGORY PRODUCT SECTIONS ───
                                SliverList.builder(
                                  itemCount: stockedCategories.length,
                                  itemBuilder: (context, index) {
                                    final category = stockedCategories[index];
                                    return _buildHorizontalProductSection(
                                      context: context,
                                      title: category.name ?? '',
                                      items: groupedItems[category.id]!,
                                      primaryColor: primaryColor,
                                      onViewAll: () {
                                        final fullIndex = storeController
                                            .categoryList!
                                            .indexWhere(
                                              (c) => c.id == category.id,
                                            );
                                        if (fullIndex >= 0) {
                                          storeController.setCategoryIndex(
                                            fullIndex,
                                          );
                                          Get.to(
                                            () => StoreCategoryItemsScreen(
                                              storeId:
                                                  storeController.store!.id,
                                              categoryName: category.name ?? '',
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
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

                                // ─── SIMILAR STORES ───
                                if (storeController.similarStoreList != null &&
                                    storeController
                                        .similarStoreList!
                                        .isNotEmpty)
                                  SliverToBoxAdapter(
                                    child: _buildSimilarStoresSection(
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
                                if (store.announcementActive ?? false)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: primaryColor.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Image.asset(
                                              Images.announcement,
                                              height: 20,
                                              width: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              child: Text(
                                                store.announcementMessage ?? '',
                                                style: waddyRegular.copyWith(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 100),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── FLOATING LIVE CART (bottom) — hides on scroll ───
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: 0,
                    right: 0,
                    bottom: _showLiveCart ? 16 : -80,
                    child: SafeArea(
                      child: GetBuilder<CartController>(
                        builder: (cartController) {
                          if (cartController.cartList.isEmpty)
                            return const SizedBox.shrink();
                          return const LiveCartWidget();
                        },
                      ),
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

  // ═══════════════════════════════════════════════════════════════
  // APP BAR — clean white, brand accents (matches grocery home style)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAppBar(
    BuildContext context,
    Store store,
    StoreController storeController,
    Color primaryColor,
  ) {
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    final bool isOpen = store.open == 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // ─── BACK BUTTON ───
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Get.back(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // ─── STORE LOGO ───
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: CustomImage(
                image: '${store.logoFullUrl}',
                height: 40,
                width: 40,
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ─── NAME + STATUS + META ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        store.name ?? '',
                        style: waddyBold.copyWith(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        if (store.schedules != null &&
                            store.schedules!.isNotEmpty) {
                          _showStoreHoursSheet(context, store, primaryColor);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isOpen ? accentColor : Colors.red.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOpen ? 'open'.tr : 'closed'.tr,
                          style: waddyBold.copyWith(
                            fontSize: 9,
                            color: isOpen ? primaryColor : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (store.deliveryTime != null &&
                        store.deliveryTime!.isNotEmpty) ...[
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        store.deliveryTime!,
                        style: waddyRegular.copyWith(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                    if ((store.avgRating ?? 0) > 0) ...[
                      if (store.deliveryTime != null &&
                          store.deliveryTime!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: Colors.amber.shade600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        store.avgRating!.toStringAsFixed(1),
                        style: waddyMedium.copyWith(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ─── INFO BUTTON ───
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap:
                  () => _showStoreInfoDialog(
                    context,
                    store,
                    storeController,
                    primaryColor,
                  ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ─── CART BUTTON ───
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Get.toNamed(RouteHelper.getCartRoute()),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 21,
                        color: primaryColor,
                      ),
                    ),
                    GetBuilder<CartController>(
                      // Shows the line count only; quantity taps on the list
                      // below should not rebuild it.
                      filter: (cart) => cart.cartList.length,
                      builder: (cartController) {
                        return cartController.cartList.isNotEmpty
                            ? Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                height: 18,
                                width: 18,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    cartController.cartList.length.toString(),
                                    style: waddyBold.copyWith(
                                      fontSize: 9,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            : const SizedBox();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SEARCH BAR — matches grocery home screen style
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSearchBar(
    BuildContext context,
    Store store,
    StoreController storeController,
    Color primaryColor,
  ) {
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap:
                  () => Get.toNamed(
                    RouteHelper.getSearchStoreItemRoute(store.id),
                  ),
              child: Container(
                height: 50,
                padding: const EdgeInsets.only(left: 5, right: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'search_for_items'.tr,
                        style: waddyRegular.copyWith(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              final maxPrice = (storeController.storeItemModel?.items ?? [])
                  .fold<double>(
                    0,
                    (prev, item) =>
                        (item.price ?? 0) > prev ? item.price! : prev,
                  );
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder:
                    (_) =>
                        FilterWidget(maxValue: maxPrice > 0 ? maxPrice : 1000),
              );
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Icon(Icons.tune_rounded, size: 20, color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CATEGORIES — 4-column grid (matches grocery home screen style)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCategoriesRow(
    BuildContext context,
    StoreController storeController,
    List<CategoryModel> categories,
    Color primaryColor,
  ) {
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    final displayCategories =
        categories.length > 8 ? categories.sublist(0, 8) : categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // Header row with "View all" pill
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '${'shop_by'.tr} ${'category'.tr}',
                    style: waddyBold.copyWith(
                      fontSize: 17,
                      color: Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              if (categories.length > 4)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      storeController.setCategoryIndex(0);
                      Get.to(
                        () => StoreCategoryItemsScreen(
                          storeId: storeController.store!.id,
                          categoryName: 'all'.tr,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'view_all'.tr,
                            style: waddyMedium.copyWith(
                              fontSize: 12,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4-column grid
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.62,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
            ),
            itemCount: displayCategories.length,
            itemBuilder: (context, index) {
              final category = displayCategories[index];
              final fullIndex = storeController.categoryList!.indexWhere(
                (c) => c.id == category.id,
              );

              return GestureDetector(
                onTap: () {
                  if (fullIndex >= 0) {
                    storeController.setCategoryIndex(fullIndex);
                    Get.to(
                      () => StoreCategoryItemsScreen(
                        storeId: storeController.store!.id,
                        categoryName: category.name ?? '',
                      ),
                    );
                  }
                },
                child: Column(
                  children: [
                    // Category image
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade100,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: CustomImage(
                              image: category.imageFullUrl ?? '',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Category name
                    SizedBox(
                      height: 30,
                      child: Text(
                        category.name ?? '',
                        style: waddyMedium.copyWith(
                          fontSize: 11,
                          color: Colors.black87,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HORIZONTAL PRODUCT SECTION — title + "View all" + horizontal cards
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHorizontalProductSection({
    required BuildContext context,
    required String title,
    required List<Item> items,
    required Color primaryColor,
    VoidCallback? onViewAll,
    IconData? icon,
  }) {
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: primaryColor),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        style: waddyBold.copyWith(
                          fontSize: 17,
                          color: Colors.black87,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              if (onViewAll != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onViewAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'view_all'.tr,
                            style: waddyMedium.copyWith(
                              fontSize: 12,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 10),
                child: _buildProductCard(context, items[index], primaryColor),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PRODUCT CARD — matches StoreSpecialOfferView style
  // ═══════════════════════════════════════════════════════════════
  Widget _buildProductCard(
    BuildContext context,
    Item item,
    Color primaryColor,
  ) {
    final Color accentGreen = Theme.of(context).secondaryHeaderColor;
    final bool hasDiscount = item.discount != null && item.discount! > 0;
    double price = item.price ?? 0;
    double discount = item.discount ?? 0;
    double discountPrice =
        PriceConverter.convertWithDiscount(price, discount, item.discountType)!;
    String originalPriceDisplay = PriceConverter.convertPrice(price);
    String discountPriceDisplay = PriceConverter.convertPrice(discountPrice);

    return GestureDetector(
      onTap: () => Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, false)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  height: 90,
                  decoration: BoxDecoration(
                    color: accentGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      fit: BoxFit.contain,
                      height: 90,
                      width: double.infinity,
                    ),
                  ),
                ),
                if (hasDiscount)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.discountType == 'percent'
                            ? '-${item.discount?.toInt()}%'
                            : '-${PriceConverter.convertPrice(item.discount ?? 0)}',
                        style: waddyBold.copyWith(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.name ?? '',
              style: waddyBold.copyWith(fontSize: 14, color: primaryColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasDiscount)
                  Text(
                    originalPriceDisplay,
                    style: waddyMedium.copyWith(
                      fontSize: 11,
                      color: Colors.grey[600],
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.grey[600],
                    ),
                  ),
                if (hasDiscount) const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasDiscount ? discountPriceDisplay : originalPriceDisplay,
                    style: waddyBold.copyWith(fontSize: 16, color: accentGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap:
                  () => Get.find<ItemController>().itemDirectlyAddToCart(
                    item,
                    context,
                  ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: accentGreen,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: accentGreen.withValues(alpha: 0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'add'.tr,
                    style: waddyBold.copyWith(
                      fontSize: 14,
                      color: primaryColor,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STORE-WIDE DISCOUNT BANNER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStoreDiscountBanner(
    BuildContext context,
    Store store,
    Color primaryColor,
  ) {
    final discount = store.discount!;
    final Color accent = Theme.of(context).secondaryHeaderColor;
    final isPercent = discount.discountType == 'percent';
    final discountText =
        isPercent
            ? '${discount.discount!.toStringAsFixed(0)}% ${'off'.tr}'
            : '${PriceConverter.convertPrice(discount.discount)} ${'off'.tr}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.local_offer_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  discountText,
                  style: waddyBold.copyWith(fontSize: 15, color: Colors.white),
                ),
                if ((discount.minPurchase ?? 0) > 0)
                  Text(
                    '${'min_purchase'.tr}: ${PriceConverter.convertPrice(discount.minPurchase)}',
                    style: waddyRegular.copyWith(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          if ((discount.maxDiscount ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${'up_to'.tr} ${PriceConverter.convertPrice(discount.maxDiscount)}',
                style: waddyBold.copyWith(fontSize: 10, color: primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: waddyRegular.copyWith(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: waddyMedium.copyWith(fontSize: 11, color: primaryColor),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STORE INFO DIALOG — triggered by info icon in app bar
  // ═══════════════════════════════════════════════════════════════
  void _showStoreInfoDialog(
    BuildContext context,
    Store store,
    StoreController storeController,
    Color primaryColor,
  ) {
    final bool hasRating = (store.avgRating ?? 0) > 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Store logo + name
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: CustomImage(
                        image: '${store.logoFullUrl}',
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name ?? '',
                          style: waddyBold.copyWith(
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        if (hasRating) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${store.avgRating!.toStringAsFixed(1)} (${store.ratingCount ?? 0})',
                                style: waddyMedium.copyWith(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              // Address
              if (store.address != null && store.address!.isNotEmpty)
                _buildInfoRow(
                  Icons.location_on_outlined,
                  store.address!,
                  primaryColor,
                ),
              // Phone
              if (store.phone != null && store.phone!.isNotEmpty)
                _buildInfoRow(Icons.phone_outlined, store.phone!, primaryColor),
              // Delivery time
              if (store.deliveryTime != null && store.deliveryTime!.isNotEmpty)
                _buildInfoRow(
                  Icons.delivery_dining_rounded,
                  store.deliveryTime!,
                  primaryColor,
                ),
              // Delivery fee
              if (store.freeDelivery == true)
                _buildInfoRow(
                  Icons.local_shipping_outlined,
                  'free_delivery'.tr,
                  primaryColor,
                )
              else if ((store.minimumShippingCharge ?? 0) > 0)
                _buildInfoRow(
                  Icons.local_shipping_outlined,
                  '${'from'.tr} ${PriceConverter.convertPrice(store.minimumShippingCharge)}',
                  primaryColor,
                ),
              // Min order
              if ((store.minimumOrder ?? 0) > 0)
                _buildInfoRow(
                  Icons.shopping_basket_outlined,
                  '${'min'.tr} ${PriceConverter.convertPrice(store.minimumOrder)}',
                  primaryColor,
                ),
              const SizedBox(height: 8),
              // Feature badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (store.delivery == true)
                    _buildFeatureBadge(
                      Icons.delivery_dining_rounded,
                      'delivery'.tr,
                      primaryColor,
                    ),
                  if (store.takeAway == true)
                    _buildFeatureBadge(
                      Icons.shopping_bag_outlined,
                      'take_away'.tr,
                      primaryColor,
                    ),
                  if (store.scheduleOrder == true)
                    _buildFeatureBadge(
                      Icons.schedule_rounded,
                      'schedule_order'.tr,
                      primaryColor,
                    ),
                ],
              ),
              // Store hours link
              if (store.schedules != null && store.schedules!.isNotEmpty) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _showStoreHoursSheet(context, store, primaryColor);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'store_hours'.tr,
                          style: waddyMedium.copyWith(
                            fontSize: 13,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STORE HOURS BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════
  void _showStoreHoursSheet(
    BuildContext context,
    Store store,
    Color primaryColor,
  ) {
    final dayNames = [
      'monday'.tr,
      'tuesday'.tr,
      'wednesday'.tr,
      'thursday'.tr,
      'friday'.tr,
      'saturday'.tr,
      'sunday'.tr,
    ];
    final int todayWeekday =
        DateTime.now().weekday == 7 ? 0 : DateTime.now().weekday;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'store_hours'.tr,
                style: waddyBold.copyWith(fontSize: 17, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              ...List.generate(7, (dayIndex) {
                final daySchedules =
                    store.schedules!.where((s) => s.day == dayIndex).toList();
                final isToday = dayIndex == todayWeekday;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color:
                        isToday
                            ? primaryColor.withValues(alpha: 0.06)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          dayNames[dayIndex],
                          style: (isToday ? waddyBold : waddyMedium).copyWith(
                            fontSize: 13,
                            color: isToday ? primaryColor : Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          daySchedules.isEmpty
                              ? 'closed'.tr
                              : daySchedules
                                  .map(
                                    (s) =>
                                        '${s.openingTime} - ${s.closingTime}',
                                  )
                                  .join(', '),
                          style: waddyRegular.copyWith(
                            fontSize: 13,
                            color:
                                daySchedules.isEmpty
                                    ? Colors.red.shade600
                                    : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'today'.tr,
                            style: waddyBold.copyWith(
                              fontSize: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // REVIEWS PREVIEW — shows first 3 reviews + "See all" link
  // ═══════════════════════════════════════════════════════════════
  Widget _buildReviewsPreview(
    BuildContext context,
    Store store,
    Color primaryColor,
  ) {
    return GetBuilder<ReviewController>(
      builder: (reviewController) {
        final reviews = reviewController.storeReviewList;
        if (reviews == null || reviews.isEmpty) return const SizedBox.shrink();

        final previewReviews =
            reviews.length > 3 ? reviews.sublist(0, 3) : reviews;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'reviews'.tr,
                          style: waddyBold.copyWith(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if ((store.avgRating ?? 0) > 0) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            store.avgRating!.toStringAsFixed(1),
                            style: waddyBold.copyWith(
                              fontSize: 13,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          Text(
                            ' (${store.ratingCount ?? 0})',
                            style: waddyRegular.copyWith(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap:
                        () => Get.to(
                          () => ReviewScreen(
                            storeID: store.id.toString(),
                            storeName: store.name,
                            store: store,
                          ),
                        ),
                    child: Text(
                      'view_all'.tr,
                      style: waddyMedium.copyWith(
                        fontSize: 12,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (store.ratings != null && store.ratings!.length >= 5)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRatingBars(store, primaryColor),
                ),
              ...previewReviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < (review.rating ?? 0)
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 14,
                                color: Colors.amber.shade600,
                              ),
                            ),
                            const Spacer(),
                            if (review.customerName != null)
                              Text(
                                review.customerName!,
                                style: waddyMedium.copyWith(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        if (review.comment != null &&
                            review.comment!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            review.comment!,
                            style: waddyRegular.copyWith(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (review.itemName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            review.itemName!,
                            style: waddyRegular.copyWith(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SIMILAR STORES — full-bleed cover cards (matches grocery Big Brands style)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSimilarStoresSection(
    BuildContext context,
    StoreController storeController,
    Color primaryColor,
  ) {
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    final stores = storeController.similarStoreList!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          child: Row(
            children: [
              Icon(Icons.storefront_rounded, size: 18, color: primaryColor),
              const SizedBox(width: 6),
              Text(
                'similar_stores'.tr,
                style: waddyBold.copyWith(
                  fontSize: 17,
                  color: Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 185,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: stores.length,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final s = stores[index];
              final bool isOpen = s.open == 1;
              final bool hasDiscount =
                  s.discount != null && (s.discount!.discount ?? 0) > 0;
              return GestureDetector(
                onTap:
                    () => Get.toNamed(
                      RouteHelper.getStoreRoute(id: s.id, page: 'store'),
                    ),
                child: Container(
                  width: 210,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // ── Full-bleed cover image ──
                        Positioned.fill(
                          child: CustomImage(
                            image: s.coverPhotoFullUrl ?? s.logoFullUrl ?? '',
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
                                stops: const [0.0, 0.3, 0.70, 1.0],
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
                                      horizontal: 20,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'CLOSED',
                                      style: waddyBold.copyWith(
                                        fontSize: 16,
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
                              borderRadius: BorderRadius.circular(12),
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
                              borderRadius: BorderRadius.circular(10),
                              child: CustomImage(
                                image: s.logoFullUrl ?? '',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        // ── Open badge top-right ──
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isOpen ? accentColor : Colors.red.shade400,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              isOpen ? 'open'.tr : 'closed'.tr,
                              style: waddyBold.copyWith(
                                fontSize: 9,
                                color: isOpen ? primaryColor : Colors.white,
                              ),
                            ),
                          ),
                        ),

                        // ── Discount ribbon — right edge ──
                        if (hasDiscount && isOpen)
                          Positioned(
                            top: 44,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE84D4F),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                s.discount!.discountType == 'percent'
                                    ? '${s.discount!.discount!.toStringAsFixed(0)}% ${'off'.tr}'
                                    : '${PriceConverter.convertPrice(s.discount!.discount)} ${'off'.tr}',
                                style: waddyBold.copyWith(
                                  fontSize: 9,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                        // ── Bottom info overlay ──
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name ?? '',
                                  style: waddyBold.copyWith(
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    // Rating pill
                                    if ((s.avgRating ?? 0) > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.star_rounded,
                                              size: 12,
                                              color: Colors.amber.shade300,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              s.avgRating!.toStringAsFixed(1),
                                              style: waddyBold.copyWith(
                                                fontSize: 10,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if ((s.avgRating ?? 0) > 0 &&
                                        s.deliveryTime != null)
                                      const SizedBox(width: 6),
                                    // Delivery time pill
                                    if (s.deliveryTime != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.schedule_rounded,
                                              size: 11,
                                              color: primaryColor,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              s.deliveryTime!,
                                              style: waddyBold.copyWith(
                                                fontSize: 10,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ],
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STORE BUNDLES / COLLECTIONS — horizontal scrollable bundle cards
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStoreBundlesSection(
    BuildContext context,
    StoreController storeController,
    Color primaryColor,
  ) {
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    final bundles = storeController.storeBundleList!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2_rounded, size: 18, color: primaryColor),
              const SizedBox(width: 6),
              Text(
                'bundles'.tr,
                style: waddyBold.copyWith(
                  fontSize: 17,
                  color: Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: bundles.length,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final bundle = bundles[index];
              final itemCount = bundle.items?.length ?? 0;
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bundle image or item thumbnails grid
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child:
                          bundle.imageFullUrl != null &&
                                  bundle.imageFullUrl!.isNotEmpty
                              ? CustomImage(
                                image: bundle.imageFullUrl!,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                              : Container(
                                height: 100,
                                width: double.infinity,
                                color: primaryColor.withValues(alpha: 0.06),
                                child: _buildBundleItemThumbnails(
                                  bundle,
                                  primaryColor,
                                ),
                              ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                      child: Text(
                        bundle.name ?? '',
                        style: waddyBold.copyWith(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (bundle.description != null &&
                        bundle.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          bundle.description!,
                          style: waddyRegular.copyWith(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: Row(
                        children: [
                          if (bundle.price != null && bundle.price! > 0)
                            Text(
                              PriceConverter.convertPrice(bundle.price),
                              style: waddyBold.copyWith(
                                fontSize: 14,
                                color: primaryColor,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$itemCount ${'items'.tr}',
                              style: waddyMedium.copyWith(
                                fontSize: 10,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBundleItemThumbnails(
    StoreBundleModel bundle,
    Color primaryColor,
  ) {
    final items = bundle.items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Icon(
          Icons.inventory_2_rounded,
          size: 40,
          color: primaryColor.withValues(alpha: 0.3),
        ),
      );
    }
    final displayItems = items.length > 4 ? items.sublist(0, 4) : items;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children:
            displayItems
                .map(
                  (item) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      height: 42,
                      width: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildRatingBars(Store store, Color primaryColor) {
    final ratings = store.ratings!;
    final total = ratings.fold<int>(0, (sum, r) => sum + r);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: List.generate(5, (index) {
        final starNum = 5 - index;
        final count = starNum <= ratings.length ? ratings[starNum - 1] : 0;
        final fraction = count / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Text(
                '$starNum',
                style: waddyMedium.copyWith(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(primaryColor),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  '$count',
                  style: waddyRegular.copyWith(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
