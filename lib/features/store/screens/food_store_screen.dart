import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/features/store/widgets/shop_product_tile.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/scratch_card/widgets/scratch_card_badge.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/store/controllers/store_page_controller.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/cart/widgets/pill_cart_bar.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/review/controllers/review_controller.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/features/store/helpers/store_delivery_fee.dart';
import 'package:waddy_app/common/widgets/add_to_cart_control.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:waddy_app/common/widgets/trailing_fade.dart';
import 'package:waddy_app/common/widgets/custom_favourite_widget.dart';
import 'package:waddy_app/features/review/screens/review_screen.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/util/dimensions.dart';

part 'food_store/food_store_hero.dart';
part 'food_store/food_store_header.dart';
part 'food_store/food_store_tabs.dart';
part 'food_store/food_store_menu.dart';

/// Height of the pinned category strip. Fixed, because a
/// SliverPersistentHeader must know its extent before laying the child out
/// and one line of tab labels never reflows.
const double _kTabBarHeight = 48;

/// How far the menu row's add control hangs below its 110pt photo: half the
/// 48pt hit box, so the 40pt `+` / stepper straddles the photo's bottom edge
/// (docs/price_add_controls_plan.md D1).
const double _kControlOverhang = 24;

/// D2 fallback. False: every discounted row wears the sale collar. True: only
/// rows whose discount differs from the store-wide promotion do — the old rule,
/// for if a 25%-off store's menu reads as a wall of collars on device.
const bool _kCollarOnlyWhenNews = false;

/// Cover photo height, and how far the logo tile hangs below it. The header
/// block pads that overhang back, so the two numbers have to agree.
const double _kCoverHeight = 220;
const double _kLogoOverhang = 34;

/// The menu page: a store's own categories as tabs over one scrolling list.
///
/// Restaurants, and every store that is not a supermarket (butcher, dairy,
/// bakery…) — supermarkets get the aisle page, `StoreScreen`. Which page a
/// store gets is decided once, by `StoreLayout` in `store_navigator.dart`;
/// open a store with `StoreNavigator.open`, not by building this directly.
class FoodStoreScreen extends StatefulWidget {
  final Store? store;
  final String slug;
  const FoodStoreScreen({super.key, required this.store, this.slug = ''});

  @override
  State<FoodStoreScreen> createState() => _FoodStoreScreenState();
}

class _FoodStoreScreenState extends State<FoodStoreScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Measured height of the anchored cart bar, used to reserve exactly that
  /// much tail space. The bar's height varies (pill only / strip only / both),
  /// so a fixed worst-case reserve would burn scroll space on every load for a
  /// strip that is usually absent. Seeded so the first frame is not short.
  double _cartBarHeight = 0;

  /// Index into the tab strip. 0 is the synthetic "full menu" tab; 1..n map
  /// to the store's categories.
  int _selectedTabIndex = 0;

  /// The floating hero buttons carry the header until the hero has fully
  /// scrolled past — then this bar takes over so name/back/search stay put.
  static const double _kHeaderRevealOffset = 170;

  /// Whether the scrolled header is showing.
  ///
  /// A `ValueNotifier` rather than a `setState` field, for the same reason the
  /// dashboard's status-bar scrim is one: this flips while the user is
  /// dragging, and the only thing that has to change is one bar's opacity.
  /// Through `setState` it rebuilt this entire screen — hero, store header,
  /// rating card, stats strip, tab strip, cart bar and every menu-row builder
  /// — mid-scroll, to fade in a widget that was already laid out.
  final ValueNotifier<bool> _showScrolledHeader = ValueNotifier<bool>(false);

  /// Scroll distance, starting the instant the sticky tab strip pins to the
  /// viewport top, over which its reserved inset grows from 0 to
  /// [_scrolledHeaderHeight]. See the `SliverLayoutBuilder` around the strip's
  /// `SliverPersistentHeader` for how the pin point itself is found — it is
  /// read from real sliver geometry (`precedingScrollExtent`), not guessed
  /// from a constant, so the growth never starts before the strip is actually
  /// stuck at the top.
  static const double _kInsetRampDistance = 100;

  /// Painted height of the scrolled header, including its top system inset.
  ///
  /// The header is an overlay in the same [Stack] as the scroll view, so a
  /// sliver that pins to the scroll view's own top edge pins UNDERNEATH it.
  /// The category strip did exactly that: once the hero cleared the top, the
  /// bar drew over the pinned tabs and the only way to change category was to
  /// scroll back up to a strip you could no longer see. The strip is pushed
  /// down by this measurement instead of by a guessed constant, because the
  /// bar's height varies with the system inset and with whether the store
  /// reports a delivery time.
  double _scrolledHeaderHeight = 0;

  /// Identifies the scrolled header's box so it can be measured after layout,
  /// the same way [PillCartBar] reports its own footprint.
  final GlobalKey _scrolledHeaderKey = GlobalKey();

  /// Measured after layout, never during it.
  void _measureScrolledHeader() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _scrolledHeaderKey.currentContext;
      final double h =
          (ctx?.findRenderObject() as RenderBox?)?.size.height ?? 0;
      if (h > 0 && (h - _scrolledHeaderHeight).abs() > 0.5) {
        setState(() => _scrolledHeaderHeight = h);
      }
    });
  }

  /// This page's own state (ST-01/ST-07): opened with the page, deleted with
  /// it, so a new store never inherits the last one's category pick.
  late final StorePageController _page;

  /// Selects a category tab. The one `setState` the tab strip and the
  /// categories sheet need, kept on the State: `setState` is protected, and
  /// both live in a part-file extension (food_store/food_store_tabs.dart).
  void _selectTab(int i) => setState(() => _selectedTabIndex = i);

  @override
  void initState() {
    super.initState();
    _page = StorePageController.open();
    _initDataCall();
  }

  @override
  void dispose() {
    _page.close();
    _scrollController.dispose();
    _showScrolledHeader.dispose();
    super.dispose();
  }

  Future<void> _initDataCall() async {
    final StorePageController storeCtrl = _page;
    storeCtrl.resetFilter(isUpdate: false);
    if (storeCtrl.isSearching) {
      storeCtrl.changeSearchStatus(isUpdate: false);
    }
    // The item list, recommendations and reviews are all keyed on the store id
    // we already have from the caller — none of them needs the store *detail*
    // response. They used to wait for it anyway, so opening a store cost the
    // detail round trip and only then started the other three.
    //
    // They are fired first and the detail fetch runs alongside them, so the
    // menu can paint as soon as its own response lands.
    final int? storeId = widget.store!.id;
    if (storeId != null) {
      storeCtrl.getRestaurantRecommendedItemList(storeId, false);
      storeCtrl.getStoreItemList(storeId, 1, 'all', false);
      Get.find<ReviewController>().getStoreReviewList(storeId.toString());
    }
    if (Get.find<CategoryController>().categoryList == null) {
      Get.find<CategoryController>().getCategoryList(true);
    }

    await storeCtrl.getStoreDetails(
      Store(id: widget.store!.id),
      slug: widget.slug,
    );

    // Only reachable when the caller had no id — a slug-based deep link. The
    // detail response is the only thing that can supply one, so these three
    // genuinely do have to wait for it.
    if (storeId == null) {
      final int? resolvedId = storeCtrl.store?.id;
      if (resolvedId != null) {
        storeCtrl.getRestaurantRecommendedItemList(resolvedId, false);
        storeCtrl.getStoreItemList(resolvedId, 1, 'all', false);
        Get.find<ReviewController>().getStoreReviewList(resolvedId.toString());
      }
    }

    // The fav-button toggle that used to open this listener drove a flag no
    // widget read, and its bare update() rebuilt every store builder in the
    // app on each scroll-direction change (ST-07).
    _scrollController.addListener(() {
      // Assigning an unchanged value to a ValueNotifier is already a no-op,
      // but the comparison keeps the intent visible: this is a threshold
      // crossing, not a per-pixel value.
      final bool pastHero =
          _scrollController.position.pixels > _kHeaderRevealOffset;
      if (pastHero != _showScrolledHeader.value) {
        _showScrolledHeader.value = pastHero;
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

  /// Buckets items under the tab they belong to.
  ///
  /// An item's `categoryId` is its most specific category. For restaurants and
  /// specialty grocery stores that IS a tab. But a grocery item can still sit
  /// in a sub-category while the tabs are its parents (a store not yet moved
  /// onto its own categories) — so when the direct id isn't a tab, the item's
  /// `categoryIds` chain is searched for one that is. Without this such a
  /// store rendered every tab empty.
  /// This screen also serves specialty grocery stores (dairy, butcher,
  /// roastery…), where "Full menu" / "Menu categories" read as a restaurant.
  ///
  /// D3 (decided 09-30, revised the same day): the page's SHOP variant — every
  /// store it serves that is not a restaurant. The same page, header and
  /// category tabs; only the items differ, as a 2-column product tile grid,
  /// plus shop wording. A store whose module is not known yet keeps the
  /// restaurant rows.
  bool get _isShop {
    final ModuleType? type =
        Get.find<SplashController>().moduleById(_page.store?.moduleId)?.type;
    return type != null && type != ModuleType.food;
  }

  String get _allTabLabel => _isShop ? 'all_products'.tr : 'full_menu'.tr;

  String get _categoriesLabel =>
      _isShop ? 'categories'.tr : 'menu_categories'.tr;

  Map<int, List<Item>> _groupItemsByCategory(
    List<Item> items,
    Set<int> tabIds,
  ) {
    final Map<int, List<Item>> grouped = {};
    for (final item in items) {
      int catId = item.categoryId ?? 0;
      if (!tabIds.contains(catId)) {
        for (final CategoryIds link in item.categoryIds ?? const []) {
          if (link.id != null && tabIds.contains(link.id)) {
            catId = link.id!;
            break;
          }
        }
      }
      grouped.putIfAbsent(catId, () => []);
      grouped[catId]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaddyColors.surface,
      body: GetBuilder<StorePageController>(
        tag: _page.tag,
        builder: (storeController) {
          return GetBuilder<CategoryController>(
            builder: (categoryController) {
              // The store payload is the only thing this screen waits for.
              //
              // It used to wait for the global category list as well, and that
              // list is needed for exactly one thing: `setCategoryList()`
              // intersects it with `store.categoryIds` to build the tab strip.
              // The gate covered everything else too — hero, name, rating,
              // menu rows, prices, the cart bar — so a slow `/categories` held
              // the whole restaurant behind a shimmer with its menu already in
              // hand, and a failed one held it there indefinitely.
              //
              // The strip degrades on its own: with no categories there is one
              // tab, "full menu", which is the tab that shows everything
              // anyway. Tabs appear when their data does — this is a
              // GetBuilder on the category controller, so its arrival rebuilds
              // us.
              final Store? store =
                  storeController.store?.name != null
                      ? storeController.store
                      : null;
              if (store == null) return const _FoodStoreScreenShimmer();

              // Unconditional: a specialty grocery store's tabs come from its
              // own payload, not the global list, so they must not wait for
              // it. setCategoryList guards the global-list path itself.
              storeController.setCategoryList();

              // `storeItemModel` is null ONLY while the first page is in
              // flight — `getStoreItemList` clears it before its await and
              // assigns it on response. So it, not `items.isEmpty`, is what
              // separates "still loading" from "loaded, and there is nothing".
              // Keying the shimmer off emptiness instead meant a store that
              // legitimately returns no items — or one whose fetch failed —
              // shimmered forever, with no error and nothing to retry.
              final bool menuLoading = storeController.storeItemModel == null;
              final allItems = storeController.storeItemModel?.items ?? [];
              final storeCategories =
                  (storeController.categoryList ?? [])
                      .where((c) => c.id != 0)
                      .toList();
              final groupedItems = _groupItemsByCategory(allItems, {
                for (final c in storeCategories)
                  if (c.id != null) c.id!,
              });
              final recommendedItems =
                  storeController.recommendedItemModel?.items ?? [];

              // Tab 0 is the synthetic "full menu"; the rest are categories,
              // offset by one. Clamp, because the category list can shrink
              // between builds while the selection sits on a tail tab.
              final int tabCount = storeCategories.length + 1;
              final int activeTab =
                  _selectedTabIndex >= tabCount ? 0 : _selectedTabIndex;
              final List<Item> menuItems =
                  activeTab == 0
                      ? allItems
                      : (groupedItems[storeCategories[activeTab - 1].id] ??
                          const <Item>[]);
              final String menuTitle =
                  activeTab == 0
                      ? _allTabLabel
                      : (storeCategories[activeTab - 1].name ?? _allTabLabel);

              return Stack(
                children: [
                  // The cover runs under the status bar, so the scroll view
                  // is deliberately not wrapped in SafeArea — the floating
                  // controls carry their own top inset instead.
                  RefreshIndicator(
                    onRefresh: _initDataCall,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // ─── HERO: cover, controls, logo ───
                        SliverToBoxAdapter(child: _buildHero(context, store)),

                        // ─── NAME, RATING, STATS, PROMO ───
                        SliverToBoxAdapter(
                          child: _buildStoreHeader(context, store),
                        ),

                        // ─── 8px divider band ───
                        const SliverToBoxAdapter(
                          child: SizedBox(
                            height: 8,
                            child: ColoredBox(color: Color(0xFFF1F4F3)),
                          ),
                        ),

                        // ─── STICKY CATEGORY TABS ───
                        // Pinned BELOW the scrolled header, not under it.
                        //
                        // A pinned sliver always paints at exactly its
                        // `minExtent` once stuck to the viewport top, so
                        // resting it below y=0 (clear of the fixed header
                        // overlay) has no substitute for growing
                        // `minExtent` by the header's height. The earlier
                        // attempts got the WHEN wrong: toggling that growth
                        // off a `setState` boolean jumped it in one frame;
                        // ramping it off raw scroll pixels grew it smoothly
                        // but too early — while the strip was still inline,
                        // above the viewport top, so the growing box visibly
                        // pushed the menu down in its wake before there was
                        // any header to clear.
                        //
                        // `SliverLayoutBuilder` gives the one number that
                        // actually marks "inline" vs "pinned":
                        // `precedingScrollExtent`, the scroll distance
                        // consumed by every sliver above this one. Until
                        // `scrollOffset` reaches it, this sliver hasn't
                        // scrolled to the viewport top yet — no inset is
                        // added, so nothing grows while still inline. Past
                        // it, the sliver IS pinned, and growing minExtent
                        // over the following `_kInsetRampDistance` pixels
                        // reads as the strip sliding down to meet the
                        // header, because that's the only thing on screen
                        // still capable of moving at that point.
                        SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final double pinStart =
                                constraints.precedingScrollExtent;
                            final double t = ((constraints.scrollOffset -
                                        pinStart) /
                                    _kInsetRampDistance)
                                .clamp(0.0, 1.0);
                            return SliverPersistentHeader(
                              pinned: true,
                              delegate: _StickyTabDelegate(
                                height: _kTabBarHeight,
                                pinnedInset: _scrolledHeaderHeight * t,
                                builder:
                                    (overlapping) => _buildCategoryTabs(
                                      context,
                                      storeCategories,
                                      activeTab,
                                      allItemCount: allItems.length,
                                      groupedItems: groupedItems,
                                      elevated: overlapping,
                                    ),
                              ),
                            );
                          },
                        ),

                        // ─── ORDER AGAIN RAIL ───
                        if (recommendedItems.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildOrderAgainRail(
                              context,
                              recommendedItems,
                            ),
                          ),

                        // ─── MENU SECTION TITLE ───
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(15, 14, 15, 0),
                            child: Text(
                              menuTitle,
                              style: waddyBold.copyWith(
                                fontSize: 20,
                                color: WaddyColors.ink,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),

                        // ─── MENU LIST — a product grid for a shop ───
                        if (_isShop)
                          _buildShopGrid(menuLoading ? null : menuItems)
                        else if (menuLoading)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            sliver: SliverList.builder(
                              itemCount: 5,
                              itemBuilder: (_, __) => _buildMenuRowShimmer(),
                            ),
                          )
                        else if (menuItems.isEmpty)
                          SliverToBoxAdapter(child: _buildEmptyMenu())
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            sliver: SliverList.builder(
                              itemCount: menuItems.length,
                              itemBuilder:
                                  (context, index) => _buildMenuRow(
                                    context,
                                    menuItems[index],
                                    storeWidePercent: _storeWidePercent(store),
                                  ),
                            ),
                          ),

                        // Room for the cart bar's ACTUAL height. The bar
                        // carries the bottom system inset INSIDE its own
                        // ground and reports its badge overhang along with it,
                        // so the measured height is the whole footprint — the
                        // inset must not be added again, and the 16 here is
                        // clearance, not a correction.
                        SliverToBoxAdapter(
                          child: SizedBox(height: _cartBarHeight + 16),
                        ),
                      ],
                    ),
                  ),

                  // ─── SCROLLED HEADER — replaces the floating hero
                  // controls once the cover has scrolled past ───
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildScrolledHeader(context, store),
                  ),

                  // ─── CART BAR (bottom) ───
                  // Always present — never hidden on scroll. With the
                  // add-to-cart toast gone this bar IS the confirmation, so
                  // hiding it would remove the only feedback channel.
                  // Anchored to the screen's own bottom edge, NOT at
                  // bottomNavReserve: this is a PUSHED route, so the
                  // dashboard's nav is not behind it. Reserving for a nav that
                  // is not there left the bar floating mid-menu.
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
}
