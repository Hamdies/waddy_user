import 'package:flutter/rendering.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/review/controllers/review_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/store/widgets/store_details_screen_shimmer_widget.dart';
import 'package:waddy_app/features/dashboard/widgets/live_cart_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';

/// Talabat-style restaurant detail screen — used only by the Food module.
/// The grocery module continues to use `StoreScreen`.
class FoodStoreScreen extends StatefulWidget {
  final Store? store;
  final bool fromModule;
  final String slug;
  const FoodStoreScreen({
    super.key,
    required this.store,
    required this.fromModule,
    this.slug = '',
  });

  @override
  State<FoodStoreScreen> createState() => _FoodStoreScreenState();
}

class _FoodStoreScreenState extends State<FoodStoreScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  bool _showLiveCart = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _initDataCall();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
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
    storeCtrl.getRestaurantRecommendedItemList(storeId, false);
    storeCtrl.getStoreItemList(storeId, 1, 'all', false);
    Get.find<ReviewController>().getStoreReviewList(storeId.toString());

    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (storeCtrl.showFavButton) {
          storeCtrl.changeFavVisibility();
          storeCtrl.hideAnimation();
        }
        if (_showLiveCart) setState(() => _showLiveCart = false);
      } else {
        if (!storeCtrl.showFavButton) {
          storeCtrl.changeFavVisibility();
          storeCtrl.showButtonAnimation();
        }
        if (!_showLiveCart) setState(() => _showLiveCart = true);
      }

      // Pagination
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 300) {
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: GetBuilder<StoreController>(
        builder: (storeController) {
          return GetBuilder<CategoryController>(
            builder: (categoryController) {
              Store? store;
              if (storeController.store != null &&
                  storeController.store!.name != null &&
                  categoryController.categoryList != null) {
                store = storeController.store;
                storeController.setCategoryList();
              }

              if (store == null) return const StoreDetailsScreenShimmerWidget();

              final allItems = storeController.storeItemModel?.items ?? [];
              final groupedItems = _groupItemsByCategory(allItems);
              final storeCategories =
                  (storeController.categoryList ?? [])
                      .where((c) => c.id != 0)
                      .toList();

              // Rebuild tab controller when categories change
              final tabCount =
                  storeCategories.length + 1; // +1 for "Picks for you"
              if (_tabController.length != tabCount) {
                _tabController.dispose();
                _tabController = TabController(length: tabCount, vsync: this);
                _tabController.addListener(() {
                  if (_tabController.indexIsChanging) {
                    setState(() => _selectedTabIndex = _tabController.index);
                  }
                });
              }

              return Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ─── HERO COVER + FLOATING INFO CARD ───
                      _buildHeroSliver(context, store),

                      // ─── DELIVERY INFO ROW ───
                      SliverToBoxAdapter(
                        child: _buildDeliveryInfoRow(context, store),
                      ),

                      // ─── DISCOUNT BANNER ───
                      if (store.discount != null &&
                          (store.discount!.discount ?? 0) > 0)
                        SliverToBoxAdapter(
                          child: _buildDiscountBanner(context, store),
                        ),

                      // ─── CATEGORY TABS ───
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyTabDelegate(
                          child: _buildCategoryTabs(context, storeCategories),
                          height: 52,
                        ),
                      ),

                      // ─── FOOD GRID ───
                      _buildFoodGrid(
                        context,
                        store,
                        storeCategories,
                        groupedItems,
                        allItems,
                      ),

                      // ─── BOTTOM SPACER ───
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),

                  // ─── LIVE CART (bottom) ───
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

  // ═══════════════════════════════════════════
  // HERO SLIVER — cover photo + floating info card
  // ═══════════════════════════════════════════
  Widget _buildHeroSliver(BuildContext context, Store store) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    final bool isOpen = store.open == 1;

    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ─── Cover photo ───
          SizedBox(
            height: 220,
            width: double.infinity,
            child: CustomImage(
              image: store.coverPhotoFullUrl ?? '',
              fit: BoxFit.cover,
            ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.15),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // ─── Back + action buttons ───
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleButton(Icons.arrow_back_rounded, () => Get.back()),
                Row(
                  children: [
                    _buildCircleButton(
                      Icons.search_rounded,
                      () => Get.toNamed(
                        RouteHelper.getSearchStoreItemRoute(store.id),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Cart button with badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildCircleButton(
                          Icons.shopping_bag_outlined,
                          () => Get.toNamed(RouteHelper.getCartRoute()),
                        ),
                        GetBuilder<CartController>(
                          builder: (cartController) {
                            if (cartController.cartList.isEmpty)
                              return const SizedBox();
                            return Positioned(
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
                                    style: robotoBold.copyWith(
                                      fontSize: 9,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ─── Floating info card ───
          Positioned(
            left: 16,
            right: 16,
            bottom: -40,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: CustomImage(
                        image: store.logoFullUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + cuisine tags + rating
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name ?? '',
                          style: robotoBold.copyWith(
                            fontSize: 17,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if ((store.avgRating ?? 0) > 0) ...[
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Colors.amber.shade600,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                store.avgRating!.toStringAsFixed(1),
                                style: robotoBold.copyWith(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                              if (store.ratingCount != null &&
                                  store.ratingCount! > 0)
                                Text(
                                  ' (${store.ratingCount! > 999 ? '${(store.ratingCount! / 1000).toStringAsFixed(1)}k+' : '${store.ratingCount}+'})',
                                  style: robotoRegular.copyWith(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isOpen ? accentColor : Colors.red.shade400,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isOpen ? 'open'.tr : 'closed'.tr,
                                style: robotoBold.copyWith(
                                  fontSize: 10,
                                  color: isOpen ? primaryColor : Colors.white,
                                ),
                              ),
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
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // DELIVERY INFO ROW
  // ═══════════════════════════════════════════
  Widget _buildDeliveryInfoRow(BuildContext context, Store store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 12),
      child: Row(
        children: [
          if (store.deliveryTime != null && store.deliveryTime!.isNotEmpty) ...[
            Icon(
              Icons.access_time_rounded,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              '${store.deliveryTime} min',
              style: robotoMedium.copyWith(fontSize: 13, color: Colors.black87),
            ),
            _buildDot(),
          ],
          Icon(
            Icons.delivery_dining_outlined,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Delivered by Waddy',
            style: robotoRegular.copyWith(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // DISCOUNT BANNER
  // ═══════════════════════════════════════════
  Widget _buildDiscountBanner(BuildContext context, Store store) {
    final discount = store.discount!;
    final String discountText =
        discount.discountType == 'percent'
            ? '${discount.discount!.toInt()}% off select items'
            : '${PriceConverter.convertPrice(discount.discount!)} off select items';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              discountText,
              style: robotoBold.copyWith(
                fontSize: 14,
                color: const Color(0xFFE65100),
              ),
            ),
          ),
          Text(
            'view_all'.tr,
            style: robotoMedium.copyWith(
              fontSize: 13,
              color: const Color(0xFFE65100),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CATEGORY TABS — scrollable horizontal tabs
  // ═══════════════════════════════════════════
  Widget _buildCategoryTabs(
    BuildContext context,
    List<CategoryModel> categories,
  ) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final tabNames = [
      'picks_for_you'.tr,
      ...categories.map((c) => c.name ?? ''),
    ];

    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: robotoBold.copyWith(fontSize: 14),
        unselectedLabelStyle: robotoMedium.copyWith(fontSize: 14),
        indicatorColor: primaryColor,
        indicatorWeight: 3,
        dividerColor: Colors.grey.shade200,
        indicatorSize: TabBarIndicatorSize.label,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        onTap: (index) => setState(() => _selectedTabIndex = index),
        tabs: tabNames.map((name) => Tab(text: name)).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // FOOD GRID — 2-column layout with + button
  // ═══════════════════════════════════════════
  Widget _buildFoodGrid(
    BuildContext context,
    Store store,
    List<CategoryModel> storeCategories,
    Map<int, List<Item>> groupedItems,
    List<Item> allItems,
  ) {
    // Determine items based on selected tab
    List<Item> displayItems;
    if (_selectedTabIndex == 0) {
      // "Picks for you" — show all items
      displayItems = allItems;
    } else {
      final categoryIndex = _selectedTabIndex - 1;
      if (categoryIndex < storeCategories.length) {
        final catId = storeCategories[categoryIndex].id;
        displayItems = groupedItems[catId] ?? [];
      } else {
        displayItems = allItems;
      }
    }

    if (displayItems.isEmpty && allItems.isEmpty) {
      // Still loading — show shimmer
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, __) => _buildFoodCardShimmer(),
            childCount: 6,
          ),
        ),
      );
    }

    if (displayItems.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.restaurant_menu_rounded,
                  size: 48,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  'No items in this category',
                  style: robotoMedium.copyWith(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildFoodCard(context, displayItems[index]),
          childCount: displayItems.length,
        ),
      ),
    );
  }

  Widget _buildFoodCard(BuildContext context, Item item) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final bool hasDiscount = item.discount != null && item.discount! > 0;
    double price = item.price ?? 0;
    double discount = item.discount ?? 0;
    double discountPrice =
        PriceConverter.convertWithDiscount(price, discount, item.discountType)!;

    return GestureDetector(
      onTap: () => Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, true)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Image with + button ───
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: CustomImage(
                        image: item.imageFullUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // + Add button
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap:
                          () => Get.find<ItemController>()
                              .itemDirectlyAddToCart(item, context),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 20,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  // Discount badge
                  if (hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
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
                          style: robotoBold.copyWith(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ─── Name + Price ───
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name ?? '',
                    style: robotoMedium.copyWith(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        PriceConverter.convertPrice(
                          hasDiscount ? discountPrice : price,
                        ),
                        style: robotoBold.copyWith(
                          fontSize: 14,
                          color: primaryColor,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text(
                          PriceConverter.convertPrice(price),
                          style: robotoRegular.copyWith(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.grey.shade500,
                          ),
                        ),
                      ],
                      Builder(builder: (context) {
                        final xpConfig = Get.find<XpController>().xpConfig;
                        if (xpConfig == null || !xpConfig.levelingEnabled) return const SizedBox.shrink();
                        final multiplier = xpConfig.multipliers[item.moduleType] ?? 1.0;
                        final xp = item.getDisplayXp(multiplier: multiplier);
                        if (xp <= 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.shade300, width: 0.5),
                            ),
                            child: Text(
                              '+$xp XP',
                              style: robotoMedium.copyWith(fontSize: 9, color: Colors.amber.shade800),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodCardShimmer() {
    return Shimmer(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 60,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
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
}

// ═══════════════════════════════════════════
// STICKY TAB DELEGATE
// ═══════════════════════════════════════════
class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyTabDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyTabDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}
