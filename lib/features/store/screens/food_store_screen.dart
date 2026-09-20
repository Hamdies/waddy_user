import 'package:flutter/rendering.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
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
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/features/store/helpers/store_delivery_fee.dart';
import 'package:waddy_app/common/widgets/animated_quantity_text.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/trailing_fade.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/common/widgets/custom_favourite_widget.dart';
import 'package:waddy_app/features/review/screens/review_screen.dart';
import 'package:waddy_app/features/location/widgets/coming_soon_delivery.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Height of the pinned category strip. Fixed, because a
/// SliverPersistentHeader must know its extent before laying the child out
/// and one line of tab labels never reflows.
const double _kTabBarHeight = 48;

/// Cover photo height, and how far the logo tile hangs below it. The header
/// block pads that overhang back, so the two numbers have to agree.
/// The add/stepper control's painted height — a badge, not a button.
///
/// Sized so the control clears the food it sits on: the earlier 48pt stepper
/// spanned 102pt and buried a third of the plate. Tap targets are restored to
/// [Dimensions.minTapTarget] with `Pressable(minSize:)`, which grows the
/// gesture box without growing the paint.
const double _kStepperHeight = 34;

const double _kCoverHeight = 220;
const double _kLogoOverhang = 34;

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

  @override
  void initState() {
    super.initState();
    _initDataCall();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _showScrolledHeader.dispose();
    super.dispose();
  }

  Future<void> _initDataCall() async {
    final storeCtrl = Get.find<StoreController>();
    storeCtrl.resetFilter(isUpdate: false);
    if (storeCtrl.isSearching) {
      storeCtrl.changeSearchStatus(isUpdate: false);
    }
    storeCtrl.hideAnimation();
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
      widget.fromModule,
      slug: widget.slug,
    );
    storeCtrl.showButtonAnimation();

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

    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (storeCtrl.showFavButton) {
          storeCtrl.changeFavVisibility();
          storeCtrl.hideAnimation();
        }
      } else {
        if (!storeCtrl.showFavButton) {
          storeCtrl.changeFavVisibility();
          storeCtrl.showButtonAnimation();
        }
      }

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
      backgroundColor: WaddyColors.surface,
      body: GetBuilder<StoreController>(
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

              if (categoryController.categoryList != null) {
                storeController.setCategoryList();
              }

              final allItems = storeController.storeItemModel?.items ?? [];
              final groupedItems = _groupItemsByCategory(allItems);
              final storeCategories =
                  (storeController.categoryList ?? [])
                      .where((c) => c.id != 0)
                      .toList();
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
                      ? 'full_menu'.tr
                      : (storeCategories[activeTab - 1].name ?? 'full_menu'.tr);

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

                        // ─── MENU LIST ───
                        if (menuItems.isEmpty && allItems.isEmpty)
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

  // ═══════════════════════════════════════════
  // HERO — cover, floating controls, logo tile
  // ═══════════════════════════════════════════
  Widget _buildHero(BuildContext context, Store store) {
    return SizedBox(
      height: _kCoverHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFFDCE7E4),
              child: CustomImage(
                image: store.coverPhotoFullUrl ?? '',
                fit: BoxFit.cover,
                height: _kCoverHeight,
                width: double.infinity,
              ),
            ),
          ),

          // Scrim over the top third so the white controls hold contrast.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _kCoverHeight * 0.34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x59134E4A), Color(0x00134E4A)],
                ),
              ),
            ),
          ),

          // ─── BACK / FAVOURITE / SEARCH ───
          Positioned(
            top: MediaQuery.paddingOf(context).top + 14,
            left: 15,
            right: 15,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _heroButton(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  tooltip: 'back'.tr,
                  onTap: () => Get.back(),
                ),
                Row(
                  children: [
                    // The shared widget owns the guest gate and the wished
                    // read; re-implementing either here would drift.
                    _heroChip(
                      tooltip: 'favourite'.tr,
                      child: GetBuilder<FavouriteController>(
                        builder: (favouriteController) {
                          return CustomFavouriteWidget(
                            isWished: favouriteController.wishStoreIdList
                                .contains(store.id),
                            isStore: true,
                            store: store,
                            storeId: store.id,
                            size: 18,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    _heroButton(
                      icon: HugeIcons.strokeRoundedSearch01,
                      tooltip: 'search_for_items'.tr,
                      onTap:
                          () => Get.toNamed(
                            RouteHelper.getSearchStoreItemRoute(store.id),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── LOGO TILE — overhangs the cover's bottom edge ───
          Positioned(
            left: 15,
            bottom: -_kLogoOverhang,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: WaddyColors.primary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: WaddyColors.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: WaddyColors.primary.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomImage(
                  image: store.logoFullUrl ?? '',
                  fit: BoxFit.cover,
                  height: 72,
                  width: 72,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A white control floating over the hero: 40×40 painted, but given the
  /// 48pt tap floor because these sit right at the screen edge.
  Widget _heroButton({
    required List<List<dynamic>> icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return _heroChip(
      tooltip: tooltip,
      onTap: onTap,
      child: HugeIcon(icon: icon, size: 19, color: WaddyColors.ink),
    );
  }

  Widget _heroChip({
    required String tooltip,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: Dimensions.minTapTarget,
        height: Dimensions.minTapTarget,
        child: Center(
          child: Material(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            shadowColor: WaddyColors.primary.withValues(alpha: 0.18),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A flat, tinted icon tile — the scrolled header's own idiom, distinct
  /// from the elevated white chips that float over the hero photo.
  Widget _flatIconTile({
    required String tooltip,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: Dimensions.minTapTarget,
        height: Dimensions.minTapTarget,
        child: Center(
          child: Material(
            color: WaddyColors.surfaceRaised,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onTap,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // SCROLLED HEADER — fixed bar once the hero clears the top
  // ═══════════════════════════════════════════
  Widget _buildScrolledHeader(BuildContext context, Store store) {
    final String? time =
        (store.deliveryTime ?? '').trim().isEmpty
            ? null
            : store.deliveryTime!.trim();

    // The bar is always built and always laid out — only its opacity changes —
    // so its height is known well before the scroll that reveals it, and the
    // tab strip's inset is correct on the very first reveal rather than one
    // frame late.
    _measureScrolledHeader();

    // Only the opacity and the pointer gate listen. The bar itself — its
    // layout, its text, its buttons — is built once per screen build and is
    // not rebuilt by a scroll.
    return ValueListenableBuilder<bool>(
      valueListenable: _showScrolledHeader,
      builder:
          (context, showing, child) => AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: showing ? 1 : 0,
            child: IgnorePointer(ignoring: !showing, child: child),
          ),
      child: Container(
        key: _scrolledHeaderKey,
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        decoration: const BoxDecoration(
          color: WaddyColors.surface,
          border: Border(bottom: BorderSide(color: WaddyColors.divider)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A134E4A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
          child: Row(
            children: [
              _flatIconTile(
                tooltip: 'back'.tr,
                onTap: () => Get.back(),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 17,
                  color: WaddyColors.ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      store.name ?? '',
                      style: waddyBold.copyWith(
                        fontSize: 16,
                        color: WaddyColors.ink,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (time != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: waddyRegular.copyWith(
                          fontSize: 12.5,
                          color: WaddyColors.inkLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GetBuilder<FavouriteController>(
                builder: (favouriteController) {
                  return _flatIconTile(
                    tooltip: 'favourite'.tr,
                    child: CustomFavouriteWidget(
                      isWished: favouriteController.wishStoreIdList.contains(
                        store.id,
                      ),
                      isStore: true,
                      store: store,
                      storeId: store.id,
                      size: 18,
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              _flatIconTile(
                tooltip: 'search_for_items'.tr,
                onTap:
                    () => Get.toNamed(
                      RouteHelper.getSearchStoreItemRoute(store.id),
                    ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  size: 18,
                  color: WaddyColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HEADER — name, rating card, stats strip, promo
  // ═══════════════════════════════════════════
  Widget _buildStoreHeader(BuildContext context, Store store) {
    final bool hasRating = (store.avgRating ?? 0) > 0;
    final String cuisines = (store.cuisineNames ?? const <String>[])
        .where((c) => c.trim().isNotEmpty)
        .join(', ');

    // "0.4 km away · Road 9, Maadi" — either half can be absent, so build the
    // parts and join rather than hardcoding the separator.
    //
    // Distance leads. The line is clamped to one row, and an Egyptian address
    // ("Road 9, Maadi Sarayat, Cairo Governorate") is long enough to eat the
    // whole row on its own — putting the address first truncated the distance
    // mid-number and rendered "… · 3143.6…". The short, high-value half is the
    // one that has to survive the ellipsis.
    //
    // The distance is also gated on the same plausibility ceiling
    // `StoreDeliveryFee` applies before it will quote a fee. A backend that
    // hands back 3143.6 km for a Maadi store is handing back garbage, and a
    // screen that refuses to price from a number should not print it either.
    final double? distanceKm =
        (store.distance ?? 0) > 0 &&
                store.distance! <= StoreDeliveryFee.maxPlausibleKm
            ? store.distance
            : null;

    final List<String> whereParts = [
      if (distanceKm != null)
        '${distanceKm.toStringAsFixed(1)} ${'km'.tr} ${'away'.tr}',
      if ((store.address ?? '').trim().isNotEmpty) store.address!.trim(),
    ];

    return Padding(
      // Top pad clears the logo tile overhanging the cover.
      padding: const EdgeInsets.fromLTRB(15, 46, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name ?? '',
                      style: waddyBold.copyWith(
                        fontSize: 26,
                        color: WaddyColors.ink,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                    if (cuisines.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        cuisines,
                        style: waddyMedium.copyWith(
                          fontSize: 14,
                          color: WaddyColors.inkMid,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (whereParts.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        whereParts.join(' · '),
                        style: waddyRegular.copyWith(
                          fontSize: 14,
                          color: WaddyColors.inkMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (hasRating) ...[
                const SizedBox(width: 12),
                _buildRatingCard(context, store),
              ],
            ],
          ),

          const SizedBox(height: 12),
          _buildStatsStrip(context, store),

          if (_hasAnyOffer(store)) ...[
            const SizedBox(height: 10),
            _buildOfferBadges(context, store),
          ],
        ],
      ),
    );
  }

  /// The rating opens the reviews screen — it is the most-tapped number on
  /// this screen, so it must not be inert.
  Widget _buildRatingCard(BuildContext context, Store store) {
    final int count = store.ratingCount ?? 0;

    return Semantics(
      button: true,
      label: '${store.avgRating!.toStringAsFixed(1)} ${'ratings'.tr}',
      child: Material(
        color: WaddyColors.primarySurface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap:
              () => Get.to(
                () => ReviewScreen(
                  storeID: store.id.toString(),
                  storeName: store.name,
                  store: store,
                ),
              ),
          child: Container(
            width: 74,
            padding: const EdgeInsets.fromLTRB(0, 9, 0, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedStar,
                      size: 15,
                      color: WaddyColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      store.avgRating!.toStringAsFixed(1),
                      style: waddyBold.copyWith(
                        fontSize: 17,
                        color: WaddyColors.primary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                if (count > 0) ...[
                  const SizedBox(height: 2),
                  // The "+" only goes on a number that has actually been
                  // rounded DOWN to a milestone. "12+ ratings" for exactly 12
                  // is a small lie told for no gain, and it is the kind a user
                  // catches by opening the reviews screen and counting.
                  Text(
                    '${count >= 50 ? '${(count ~/ 50) * 50}+' : '$count'}'
                    '\n${'ratings'.tr}',
                    textAlign: TextAlign.center,
                    style: waddyMedium.copyWith(
                      fontSize: 11,
                      color: WaddyColors.inkMid,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Delivery time · delivered by · fee.
  ///
  /// Out of zone we cannot honestly quote a time or a fee for this store, so
  /// those cells drop — this screen is the last stop before add-to-cart.
  Widget _buildStatsStrip(BuildContext context, Store store) {
    final bool freeDelivery = store.freeDelivery ?? false;
    final String? time =
        (store.deliveryTime ?? '').trim().isEmpty
            ? null
            : store.deliveryTime!.trim();

    final double minimum = store.minimumOrder ?? 0;

    // Who actually carries the order.
    //
    // `selfDeliverySystem == 1` is the store running its own fleet on its own
    // per-km rates — the checkout calculator branches on exactly this flag to
    // decide whose shipping charges to apply, so it is a real operational
    // difference and not a cosmetic one. The cell used to answer "Waddy" for
    // every store, which made it decoration; naming the restaurant when the
    // restaurant is the courier is what makes it worth its third of the row.
    //
    // It also sets expectations the two couriers genuinely differ on — live
    // tracking and support reach Waddy's riders, not a restaurant's.
    final bool selfDelivery = store.selfDeliverySystem == 1;
    final String courier =
        selfDelivery ? (store.name ?? 'restaurant'.tr) : AppConstants.appName;

    // What the fee cell can honestly claim.
    //
    // `StoreDeliveryFee` runs the same ladder checkout runs, so the number
    // quoted here is the number charged later — and it returns null instead of
    // guessing when the rates or the distance cannot be trusted. Where it
    // returns null the minimum order takes the slot, exactly as before.
    final double? fee = StoreDeliveryFee.estimate(
      store: store,
      address: AddressHelper.getUserAddressFromSharedPref(),
    );

    final List<Widget> cells = [
      if (!isComingSoon && time != null)
        _statCell(
          label: 'delivery_time'.tr,
          value: time,
          valueColor: WaddyColors.primary,
        ),
      if (!isComingSoon)
        _statCell(
          label: 'delivered_by'.tr,
          value: courier,
          valueColor: WaddyColors.ink,
          valueMaxLines: 2,
        ),
      // Free delivery strikes the fee it replaced rather than just saying
      // "Free": the struck number is what makes free read as a SAVING instead
      // of as this store's ordinary price. With no computable fee there is
      // nothing to strike, and an invented "was" price would manufacture a
      // discount that does not exist — so that case shows the word alone.
      if (!isComingSoon && (freeDelivery || fee != null))
        _feeCell(freeDelivery: freeDelivery, fee: fee),
      // The minimum is its own cell rather than the fee's fallback. Both facts
      // can be true at once — a store CAN deliver free above a minimum — and
      // the old either/or hid the minimum from exactly those stores, which are
      // the ones where knowing it matters most. It only renders when the fee
      // cell did not already fill the row, so the strip stays at three.
      if (!isComingSoon && !freeDelivery && fee == null && minimum > 0)
        _statCell(
          label: 'minimum_order'.tr,
          value: PriceConverter.convertPrice(minimum),
          valueColor: WaddyColors.ink,
        ),
    ];

    // Everything droppable dropped — an empty bordered box is worse than no
    // box.
    if (cells.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: WaddyColors.divider),
        borderRadius: BorderRadius.circular(15),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < cells.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: WaddyColors.divider,
                ),
              Expanded(child: cells[i]),
            ],
          ],
        ),
      ),
    );
  }

  /// The delivery-fee cell, which is the only one that shows two values.
  ///
  /// Free delivery is a SAVING, and a saving needs the thing it saved you from
  /// — so the fee this store would otherwise have charged is struck through
  /// beside a green "Free". The same grammar the menu rows use for a
  /// discounted price, which is why it reads instantly here.
  ///
  /// Three shapes:
  ///   • free, fee known    → `35 LE  Free`   (struck grey, then green)
  ///   • free, fee unknown  → `Free`          (nothing to strike)
  ///   • not free           → `35 LE`         (plain ink)
  Widget _feeCell({required bool freeDelivery, required double? fee}) {
    final String? feeLabel =
        fee == null ? null : PriceConverter.convertPrice(fee);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'delivery_fee'.tr,
            textAlign: TextAlign.center,
            style: waddyMedium.copyWith(
              fontSize: 11.5,
              color: WaddyColors.inkLight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Wrap, not Row: at the system's larger text sizes "35 LE Free" does
          // not fit a third of the screen on one line, and a struck price that
          // ellipsizes away leaves a bare "Free" that has lost its point.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            children: [
              if (feeLabel != null)
                Text(
                  feeLabel,
                  style: waddyBold.copyWith(
                    fontSize: 14,
                    // Struck only when something replaced it. Without free
                    // delivery this IS the price, and striking it would say
                    // the opposite of what is true.
                    color:
                        freeDelivery ? WaddyColors.inkMuted : WaddyColors.ink,
                    decoration:
                        freeDelivery ? TextDecoration.lineThrough : null,
                    decorationColor: WaddyColors.inkMuted,
                  ),
                  maxLines: 1,
                ),
              if (freeDelivery)
                Text(
                  'free'.tr,
                  style: waddyBold.copyWith(
                    fontSize: 14,
                    color: WaddyColors.mintInk,
                  ),
                  maxLines: 1,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// One cell of the stats strip.
  ///
  /// [valueMaxLines] exists for the courier cell. Every other value here is a
  /// short token ("20-35", "Free", "120 LE") that cannot overflow a third of
  /// the screen, but the courier's value is a STORE NAME — and a name clipped
  /// to "Vinny's Piz…" fails at the one job this cell has, which is saying who
  /// is carrying the order. It gets a second line; the rest stay at one so a
  /// long translation cannot silently make the strip taller.
  Widget _statCell({
    required String label,
    required String value,
    required Color valueColor,
    int valueMaxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Two lines, not one. At the system's larger text sizes a
          // single-line "Delivery Time" truncated to "Delivery T…" — the cell
          // stopped naming its own number, which is the one thing a label has
          // to do. Wrapping costs a few points of height the strip can absorb;
          // ellipsis cost the meaning.
          Text(
            label,
            textAlign: TextAlign.center,
            style: waddyMedium.copyWith(
              fontSize: 11.5,
              color: WaddyColors.inkLight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: waddyBold.copyWith(fontSize: 14, color: valueColor),
            maxLines: valueMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // OFFERS ROW — one collar badge per promise
  // ═══════════════════════════════════════════
  //
  // Promotions are CORAL in this app, not amber.
  //
  // Amber already carries three unrelated jobs — it IS `warning`, it is the
  // in-transit order status, and it is the "soon" tag. A discount is the
  // opposite of a caution, and sharing a hue with the warning token meant the
  // happiest strip on the screen wore the app's alarm colour.
  //
  // Coral is the documented "CTAs, urgency, fun" tertiary, and the menu rows
  // below ALREADY use `coralSurface` for their per-item discount ribbons, so a
  // user scanning the screen learns "coral = a saving" exactly once.
  //
  // Free delivery is mint for the same reason, and both now use
  // [OfferCollarBadge] — the shape every offer in the app wears, so this
  // screen and the browse row that led here make the same promise the same
  // way.
  //
  /// Whether this store has anything to put on the offers row.
  static bool _hasAnyOffer(Store store) =>
      (store.discount?.discount ?? 0) > 0 ||
      store.freeDelivery == true ||
      store.minimumShippingCharge == 0;

  /// Every offer the store actually has, not just the discount.
  ///
  /// This used to be a discount-only banner, so a store whose perk was free
  /// delivery showed nothing at all here — the browse row that sent the user
  /// in promised "Free delivery" and the store page it opened stayed silent
  /// about it. Both facts are the same kind of promise, so both wear the
  /// collar and both appear.
  ///
  /// Compact, and wrapped rather than rowed: two badges at full size crowded
  /// the header on a small phone, and this is a supporting line under the
  /// stats strip, not the headline of the screen.
  Widget _buildOfferBadges(BuildContext context, Store store) {
    final discount = store.discount;
    final bool hasDiscount = (discount?.discount ?? 0) > 0;
    final bool hasFreeDelivery =
        store.freeDelivery == true || store.minimumShippingCharge == 0;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (hasDiscount)
          OfferCollarBadge(
            label:
                '${discount!.discountType == 'percent' ? '${discount.discount!.toInt()}%' : PriceConverter.convertPrice(discount.discount!)} ${'off_select_items'.tr}',
            tone: OfferCollarTone.sale,
            compact: true,
          ),
        if (hasFreeDelivery)
          OfferCollarBadge(
            label: 'free_delivery'.tr,
            tone: OfferCollarTone.delivery,
            compact: true,
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // STICKY CATEGORY TABS
  // ═══════════════════════════════════════════
  Widget _buildCategoryTabs(
    BuildContext context,
    List<CategoryModel> categories,
    int activeTab, {
    required int allItemCount,
    required Map<int, List<Item>> groupedItems,
    required bool elevated,
  }) {
    final List<String> labels = [
      'full_menu'.tr,
      ...categories.map((c) => c.name ?? ''),
    ];

    return Container(
      height: _kTabBarHeight,
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        border: const Border(bottom: BorderSide(color: WaddyColors.divider)),
        // Lift it only once it is actually pinned over content; a permanent
        // shadow reads as a seam when the page is at rest.
        boxShadow:
            elevated
                ? [
                  BoxShadow(
                    color: WaddyColors.primary.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: Row(
        children: [
          // The strip cuts every label at the same hard vertical line, and a
          // cut through a WORD ("Bakery & Pas") reads as text that failed to
          // render rather than as content that continues. The fade turns the
          // same geometry into "there is more, scroll" — and is already what
          // the home rails use, so the two agree about what an edge means.
          Expanded(
            child: TrailingFade(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: labels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 20),
                itemBuilder: (_, i) {
                  final bool active = i == activeTab;
                  return Semantics(
                    button: true,
                    selected: active,
                    child: InkWell(
                      onTap: () {
                        if (_selectedTabIndex == i) return;
                        setState(() => _selectedTabIndex = i);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.only(top: 14, bottom: 11),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  active
                                      ? WaddyColors.primary
                                      : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          labels[i],
                          style: (active ? waddyBold : waddyMedium).copyWith(
                            fontSize: 15,
                            color:
                                active
                                    ? WaddyColors.primary
                                    : WaddyColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ─── MENU CATEGORIES SHEET ───
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: WaddyColors.divider)),
            ),
            child: Semantics(
              button: true,
              label: 'menu_categories'.tr,
              child: InkWell(
                onTap:
                    () => _openMenuCategoriesSheet(
                      context,
                      categories,
                      activeTab,
                      allItemCount: allItemCount,
                      groupedItems: groupedItems,
                    ),
                // Labelled, not iconographic.
                //
                // A ☰ beside a scrolling tab strip is genuinely ambiguous: it
                // could be the app's global menu, a filter, or the overflow of
                // the tabs themselves — and the icon cannot tell you which.
                // Guessing wrong costs a tap into a sheet you did not want.
                //
                // The word "All" plus a chevron says both things an icon could
                // not: that this lists the SAME categories the strip is
                // scrolling, and that it opens rather than navigates. The count
                // is what makes it worth opening — "All 9" tells you the strip
                // has more than the two labels you can see, which is exactly
                // the question a clipped tab raises.
                child: Container(
                  height: _kTabBarHeight,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${'all'.tr} ${labels.length}',
                        style: waddyBold.copyWith(
                          fontSize: 13,
                          color: WaddyColors.ink,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: WaddyColors.inkLight,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lists every tab (full menu + categories) with how many items are
  /// currently loaded under each, letting the guest jump straight to one
  /// instead of scrubbing the horizontal tab strip.
  void _openMenuCategoriesSheet(
    BuildContext context,
    List<CategoryModel> categories,
    int activeTab, {
    required int allItemCount,
    required Map<int, List<Item>> groupedItems,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.78,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: WaddyColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: WaddyColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'close'.tr,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () => Navigator.of(sheetContext).pop(),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: WaddyColors.surfaceRaised,
                                shape: BoxShape.circle,
                              ),
                              child: const HugeIcon(
                                icon: HugeIcons.strokeRoundedCancel01,
                                size: 15,
                                color: WaddyColors.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'menu_categories'.tr,
                          style: waddyBold.copyWith(
                            fontSize: 18,
                            color: WaddyColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: categories.length + 1,
                      itemBuilder: (_, i) {
                        final bool active = i == activeTab;
                        final String label =
                            i == 0
                                ? 'full_menu'.tr
                                : (categories[i - 1].name ?? '');
                        final int count =
                            i == 0
                                ? allItemCount
                                : (groupedItems[categories[i - 1].id]?.length ??
                                    0);
                        return Semantics(
                          button: true,
                          selected: active,
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedTabIndex = i);
                              Navigator.of(sheetContext).pop();
                            },
                            child: Container(
                              padding: EdgeInsets.only(
                                left: active ? 13 : 16,
                                top: 15,
                                bottom: 15,
                                right: 5,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color:
                                        active
                                            ? WaddyColors.ink
                                            : Colors.transparent,
                                    width: 3,
                                  ),
                                  bottom: const BorderSide(
                                    color: WaddyColors.divider,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    label,
                                    style: (active ? waddyBold : waddyMedium)
                                        .copyWith(
                                          fontSize: 15,
                                          color:
                                              active
                                                  ? WaddyColors.ink
                                                  : WaddyColors.inkMid,
                                        ),
                                  ),
                                  Text(
                                    '$count',
                                    style: waddyRegular.copyWith(
                                      fontSize: 15,
                                      color: WaddyColors.inkLight,
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
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // ORDER AGAIN — horizontal rail
  // ═══════════════════════════════════════════
  Widget _buildOrderAgainRail(BuildContext context, List<Item> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'order_again'.tr,
                style: waddyBold.copyWith(
                  fontSize: 20,
                  color: WaddyColors.ink,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'recommended_for_you'.tr,
                style: waddyRegular.copyWith(
                  fontSize: 13,
                  color: WaddyColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(15, 2, 15, 6),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _buildOrderAgainCard(context, items[i]),
          ),
        ),
      ],
    );
  }

  /// Compact horizontal reorder card: thumbnail, name + price, and a pill
  /// that adds the item straight back to the cart — no detail sheet detour,
  /// since "order again" already implies the guest knows what they want.
  Widget _buildOrderAgainCard(BuildContext context, Item item) {
    final bool hasDiscount = (item.discount ?? 0) > 0;
    final double price = item.price ?? 0;
    final String priceLabel = PriceConverter.convertPrice(
      hasDiscount
          ? PriceConverter.convertWithDiscount(
            price,
            item.discount ?? 0,
            item.discountType,
          )!
          : price,
    );

    return SizedBox(
      width: 240,
      child: Material(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap:
              () => Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, true)),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: WaddyColors.divider),
              boxShadow: [
                BoxShadow(
                  color: WaddyColors.primary.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ColoredBox(
                    color: const Color(0xFFF1F4F3),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      fit: BoxFit.cover,
                      height: 64,
                      width: 64,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name ?? '',
                        style: waddyMedium.copyWith(
                          fontSize: 13,
                          color: WaddyColors.ink,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        priceLabel,
                        style: waddyBold.copyWith(
                          fontSize: 13,
                          color: WaddyColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Semantics(
                  button: true,
                  label: '${'reorder'.tr} ${item.name ?? ''}',
                  child: Material(
                    color: WaddyColors.primarySurface,
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap:
                          () => Get.find<ItemController>()
                              .itemDirectlyAddToCart(item, context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          'reorder'.tr,
                          style: waddyBold.copyWith(
                            fontSize: 12.5,
                            color: WaddyColors.primary,
                          ),
                        ),
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

  // ═══════════════════════════════════════════
  // MENU ROW — text left, thumbnail + add right
  // ═══════════════════════════════════════════
  /// The store-wide promotion as a percentage, or null when the store runs
  /// none or runs a flat-amount one.
  ///
  /// Only a PERCENT promotion is comparable to a row's own derived percentage.
  /// A flat "20 LE off" applies differently to every item, so there is no
  /// single number a row could match it against — those stores get the ribbon
  /// on every discounted row, which is correct, because the row's percentage
  /// really is news the header banner did not give.
  int? _storeWidePercent(Store store) {
    final discount = store.discount;
    if (discount == null) return null;
    if (discount.discountType != 'percent') return null;
    final double value = discount.discount ?? 0;
    if (value <= 0) return null;
    return value.round();
  }

  Widget _buildMenuRow(
    BuildContext context,
    Item item, {
    required int? storeWidePercent,
  }) {
    final bool hasDiscount = (item.discount ?? 0) > 0;
    final double price = item.price ?? 0;
    final double discountedPrice =
        hasDiscount
            ? PriceConverter.convertWithDiscount(
              price,
              item.discount ?? 0,
              item.discountType,
            )!
            : price;
    final String priceLabel = PriceConverter.convertPrice(discountedPrice);
    // "Customizable" promises options on the detail sheet, so only show it
    // when the item genuinely has some.
    final bool customizable =
        (item.variations?.isNotEmpty ?? false) ||
        (item.foodVariations?.isNotEmpty ?? false) ||
        (item.addOns?.isNotEmpty ?? false);
    // A single 5-star review used to be enough to crown an item "bestseller",
    // which made the badge meaningless on a new store — the state most stores
    // are in. A floor of 10 ratings is the point where the average is saying
    // something about the item rather than about one diner.
    final bool bestseller =
        (item.avgRating ?? 0) >= 4.5 && (item.ratingCount ?? 0) >= 10;

    return InkWell(
      onTap: () => Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, true)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: WaddyColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          item.name ?? '',
                          style: waddyMedium.copyWith(
                            fontSize: 16,
                            color: WaddyColors.ink,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (bestseller) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: WaddyColors.coralSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'bestseller'.tr,
                            style: waddyBold.copyWith(
                              fontSize: 10.5,
                              color: WaddyColors.coralInk,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if ((item.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.description!.trim(),
                      style: waddyRegular.copyWith(
                        fontSize: 13,
                        color: WaddyColors.inkLight,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // The ribbon marks an EXCEPTION, not a fact already stated.
                  //
                  // When every item carries the store's own promotion, a
                  // per-row "25% OFF" repeats the amber header banner once per
                  // row and the menu becomes a wall of coral with no signal
                  // left in it. So the ribbon renders only where the row beats
                  // (or differs from) the store-wide rate — which is exactly
                  // when it is telling the user something new.
                  //
                  // The struck-through price and the mint price still mark
                  // every discounted row; they are the quiet, scannable
                  // encoding. The ribbon is the loud one, and loud has to be
                  // rare to mean anything.
                  if (hasDiscount) ...[
                    if (_ribbonEarnsItsPlace(
                      priceBefore: price,
                      priceAfter: discountedPrice,
                      storeWidePercent: storeWidePercent,
                    )) ...[
                      const SizedBox(height: 10),
                      _discountRibbon(
                        priceBefore: price,
                        priceAfter: discountedPrice,
                      ),
                    ],
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: hasDiscount ? 5 : 0,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              hasDiscount
                                  ? WaddyColors.mint
                                  : Colors.transparent,
                        ),
                        child: Text(
                          priceLabel,
                          style: waddyBold.copyWith(
                            fontSize: 15,
                            color: WaddyColors.primary,
                          ),
                        ),
                      ),
                      if (hasDiscount)
                        Text(
                          PriceConverter.convertPrice(price),
                          style: waddyMedium.copyWith(
                            fontSize: 14,
                            color: WaddyColors.inkMid,
                            decoration: TextDecoration.lineThrough,
                            // Grey, not coral. Two reds — the ribbon's and
                            // this one — fought each other in the price row and
                            // made the cheaper number harder to find, which is
                            // the opposite of what a strikethrough is for.
                            decorationColor: WaddyColors.error,
                          ),
                        ),
                      if (customizable)
                        Text(
                          'customizable'.tr,
                          style: waddyMedium.copyWith(
                            fontSize: 12.5,
                            color: WaddyColors.inkLight,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // The control sits ON the photo's bottom-right corner, and the
            // photo is what it grows from.
            //
            // An earlier pass moved it below the image because the stepper it
            // replaced was 102x48 and buried a third of the food. The fix was
            // aimed at the wrong thing: the problem was never the position,
            // it was a stepper built at button size instead of badge size.
            // Sized like a badge it clears the plate, and staying on the
            // corner keeps the control anchored to the item it belongs to
            // rather than floating in the row's whitespace.
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ColoredBox(
                      color: const Color(0xFFF1F4F3),
                      child: CustomImage(
                        image: item.imageFullUrl ?? '',
                        fit: BoxFit.cover,
                        height: 110,
                        width: 110,
                      ),
                    ),
                  ),
                  // Pinned to the corner, and pinned by its RIGHT edge — the
                  // pill expands leftward across the photo when it opens, so
                  // the `+` the finger is already on does not move out from
                  // under it.
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: _addControl(
                      context: context,
                      item: item,
                      customizable: customizable,
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

  /// Whether this row's discount is news the header banner has not given.
  ///
  /// True when the store runs no comparable store-wide percentage, or when
  /// this row's own percentage differs from it. The 1-point tolerance absorbs
  /// rounding: a 25% store promotion lands on individual prices as 24.6% or
  /// 25.4% depending on where the cents fall, and a row that is really just
  /// the store promotion must not claim to be an exception because of a
  /// half-piastre.
  bool _ribbonEarnsItsPlace({
    required double priceBefore,
    required double priceAfter,
    required int? storeWidePercent,
  }) {
    if (storeWidePercent == null) return true;
    if (priceBefore <= 0) return false;
    final int percentOff = ((1 - (priceAfter / priceBefore)) * 100).round();
    return (percentOff - storeWidePercent).abs() > 1;
  }

  /// The item-level discount call-out — distinct from the store-wide promo
  /// banner in the header, and from the strikethrough price next to it.
  ///
  /// The percentage is derived from the two real prices (`1 - after/before`),
  /// not from the raw `discount`/`discountType` fields — those can be a flat
  /// EGP amount, and showing that number with a "%" suffix would be wrong.
  Widget _discountRibbon({
    required double priceBefore,
    required double priceAfter,
  }) {
    if (priceBefore <= 0) return const SizedBox.shrink();
    final int percentOff = ((1 - (priceAfter / priceBefore)) * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: BoxDecoration(
        color: WaddyColors.coralSurface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedSaleTag01,
            size: 15,
            color: WaddyColors.coral,
          ),
          const SizedBox(width: 5),
          Text(
            '$percentOff% ${'off'.tr}',
            style: waddyMedium.copyWith(
              fontSize: 13,
              color: WaddyColors.coralDark,
            ),
          ),
        ],
      ),
    );
  }

  /// Add-to-cart for one menu row, in whichever of its two shapes applies.
  ///
  /// ```
  ///        not in cart              in cart
  ///           ╭───╮           ╭──────────────────╮
  ///           │ + │           │  🗑    2      +  │
  ///           ╰───╯           ╰──────────────────╯
  ///           white            white, full width
  /// ```
  ///
  /// The stepper is the resting state for every in-cart row, not a tap-to-open
  /// pill on a timer. It used to expand from a collapsed count badge and
  /// auto-collapse a beat later, sized against a 48pt stepper that spanned
  /// ~102pt and buried a third of the plate. At [_kStepperHeight] (34pt) the
  /// pill is ~92pt wide, which clears a 110pt photo on its own — the badge
  /// step existed to work around a size problem this control no longer has.
  /// Two rows can now show `− n +` at once, and a control the user is
  /// actively adjusting no longer removes itself while they are using it.
  ///
  /// Only [customizable] == false rows get any of this. A customizable item can
  /// occupy SEVERAL cart lines under different variations, so "the quantity of
  /// this item" is not a single number and a stepper would have to pick one
  /// line to speak for the rest. Those rows keep the `+`, which opens the
  /// options sheet — the only place the choice can be made. This is the same
  /// predicate [ItemController.itemDirectlyAddToCart] uses to decide its own
  /// fast path, so the two agree by construction.
  Widget _addControl({
    required BuildContext context,
    required Item item,
    required bool customizable,
  }) {
    // Simple items carry no variation, so the empty variation type matches the
    // one line they can occupy.
    int lineIndex(CartController cart) =>
        customizable ? -1 : cart.isExistInCart(item.id, '', false, null);

    return GetBuilder<CartController>(
      // GetBuilder stores the filter's last value in its State and does not
      // re-read it when the widget updates, so a row the sliver reuses for a
      // different item needs a fresh State, or it compares against the old
      // item's number and can skip the rebuild that shows its stepper.
      key: ValueKey<int?>(item.id),
      // Every cart change notifies every cart builder in the app, so without
      // this one tap rebuilt every visible row. Only this row's own line
      // decides what it draws. Never null: GetX treats a null first value as
      // "no filter".
      filter: (cart) {
        final int index = lineIndex(cart);
        return index == -1 ? -1 : (cart.cartList[index].quantity ?? 1);
      },
      builder: (cart) {
        final int cartIndex = lineIndex(cart);

        if (cartIndex == -1) return _addButton(context: context, item: item);

        final int quantity = cart.cartList[cartIndex].quantity ?? 1;
        return _stepperPill(context: context, item: item, quantity: quantity);
      },
    );
  }

  /// The resting `+`: a white circle on the photo's corner.
  ///
  /// White rather than mint, because it sits on a photograph — a tinted disc
  /// on food reads as part of the picture, while white reads as a control laid
  /// over it. The 48pt hit box extends past the painted circle.
  Widget _addButton({required BuildContext context, required Item item}) {
    return Pressable(
      semanticLabel: '${'add'.tr} ${item.name ?? ''}',
      minSize: Dimensions.minTapTarget,
      onTap:
          () => Get.find<ItemController>().itemDirectlyAddToCart(item, context),
      child: _disc(
        child: const Icon(
          Icons.add_rounded,
          size: 19,
          color: WaddyColors.primary,
        ),
      ),
    );
  }

  /// The `🗑 n +` pill: the resting state for every in-cart row.
  ///
  /// A TRASH icon at quantity 1, a minus above it. The difference matters: a
  /// minus at 1 silently deletes the line, and a control that deletes must say
  /// so before the tap rather than after it. Swapping the glyph is the whole
  /// warning — it costs nothing and it is read instantly.
  Widget _stepperPill({
    required BuildContext context,
    required Item item,
    required int quantity,
  }) {
    final bool deletes = quantity <= 1;

    return Material(
      color: WaddyColors.surface,
      borderRadius: BorderRadius.circular(_kStepperHeight / 2),
      elevation: 2,
      shadowColor: WaddyColors.primary.withValues(alpha: 0.18),
      child: SizedBox(
        height: _kStepperHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepperHalf(
              semantic:
                  deletes
                      ? '${'remove'.tr} ${item.name ?? ''}'
                      : '${'decrease_quantity'.tr} ${item.name ?? ''}',
              icon:
                  deletes ? Icons.delete_outline_rounded : Icons.remove_rounded,
              onTap: () {
                final cart = Get.find<CartController>();
                // Re-resolved on tap: the builder's index is a frame old, and
                // the cart can change underneath it from the cart screen.
                final int index = cart.isExistInCart(item.id, '', false, null);
                if (index == -1) return;
                if ((cart.cartList[index].quantity ?? 1) <= 1) {
                  // `decideItemQuantity` has no floor — it returns 0 and would
                  // leave a zero-quantity row in the cart — so the floor lives
                  // here.
                  cart.removeFromCart(index, item: item);
                } else {
                  cart.setQuantity(
                    false,
                    index,
                    item.stock,
                    item.quantityLimit,
                  );
                }
              },
            ),
            SizedBox(
              width: 24,
              child: AnimatedQuantityText(
                quantity: quantity,
                style: waddyBold.copyWith(fontSize: 15, color: WaddyColors.ink),
              ),
            ),
            _stepperHalf(
              semantic: '${'increase_quantity'.tr} ${item.name ?? ''}',
              icon: Icons.add_rounded,
              onTap: () {
                final cart = Get.find<CartController>();
                final int index = cart.isExistInCart(item.id, '', false, null);
                if (index == -1) return;
                cart.setQuantity(true, index, item.stock, item.quantityLimit);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// One tap half of the pill.
  ///
  /// Painted at [_kStepperHeight] but hit-tested at [Dimensions.minTapTarget]:
  /// the pill is badge-sized so it can sit on a photo, and a badge-sized target
  /// is under both Material's 48 and iOS's 44. `Pressable(minSize:)` grows the
  /// gesture box outward from the centre without redrawing anything.
  Widget _stepperHalf({
    required String semantic,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Pressable(
      semanticLabel: semantic,
      minSize: Dimensions.minTapTarget,
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: _kStepperHeight,
        child: Icon(icon, size: 18, color: WaddyColors.primary),
      ),
    );
  }

  /// The circular shell both closed states share, so `+` and the count are the
  /// same disc in the same place and only their contents change.
  Widget _disc({required Widget child, Color fill = WaddyColors.surface}) {
    return Container(
      width: _kStepperHeight,
      height: _kStepperHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: WaddyColors.primary.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildEmptyMenu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 40),
      child: Center(
        child: Column(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedRestaurant01,
              size: 48,
              color: WaddyColors.divider,
            ),
            const SizedBox(height: 12),
            Text(
              'no_item_available'.tr,
              textAlign: TextAlign.center,
              style: waddyMedium.copyWith(
                fontSize: 14,
                color: WaddyColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuRowShimmer() => _menuRowShimmer();
}

/// Shared between the live pagination shimmer and [_FoodStoreScreenShimmer]'s
/// initial-load skeleton, so both stay in sync with the real menu row shape.
Widget _menuRowShimmer() {
  Widget bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: WaddyColors.surfaceRaised,
      borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
    ),
  );

  return Shimmer(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: WaddyColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(160, 14),
                const SizedBox(height: 9),
                bar(double.infinity, 11),
                const SizedBox(height: 5),
                bar(180, 11),
                const SizedBox(height: 12),
                bar(64, 13),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: WaddyColors.surfaceRaised,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Loading skeleton for [FoodStoreScreen] — mirrors the real hero, header,
/// stats strip, tab bar, and menu rows so nothing jumps once data lands.
class _FoodStoreScreenShimmer extends StatelessWidget {
  const _FoodStoreScreenShimmer();

  Widget _bar(double w, double h, {BorderRadius? radius}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: WaddyColors.surfaceRaised,
      borderRadius:
          radius ?? BorderRadius.circular(Dimensions.radiusExtraSmall),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── HERO ───
          Shimmer(
            child: SizedBox(
              height: _kCoverHeight + _kLogoOverhang,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: _kCoverHeight,
                    color: WaddyColors.surfaceRaised,
                  ),
                  Positioned(
                    left: 15,
                    bottom: 0,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: WaddyColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: WaddyColors.surface,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── HEADER ───
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 18),
            child: Shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(180, 20),
                  const SizedBox(height: 9),
                  _bar(120, 12),
                  const SizedBox(height: 16),
                  _bar(double.infinity, 62, radius: BorderRadius.circular(15)),
                ],
              ),
            ),
          ),

          // ─── DIVIDER BAND ───
          const SizedBox(
            height: 8,
            child: ColoredBox(color: Color(0xFFF1F4F3)),
          ),

          // ─── TAB BAR ───
          SizedBox(
            height: _kTabBarHeight,
            child: Shimmer(
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  _bar(64, 15),
                  const SizedBox(width: 20),
                  _bar(64, 15),
                  const SizedBox(width: 20),
                  _bar(64, 15),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: WaddyColors.divider),

          // ─── MENU TITLE ───
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 0),
            child: Shimmer(child: _bar(140, 20)),
          ),

          // ─── MENU ROWS ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(children: List.generate(5, (_) => _menuRowShimmer())),
          ),
        ],
      ),
    );
  }
}

/// Pins the category strip. Rebuilds its child with `overlapsContent` so the
/// strip grows a shadow only once it is actually floating over the list.
///
/// [pinnedInset] is how far down from the scroll view's top edge the strip
/// should come to rest — the height of the scrolled header overlay, which is
/// painted in a [Stack] ABOVE this scroll view and would otherwise cover the
/// pinned strip completely.
///
/// It is spent as collapsed extent rather than as padding on the child: a
/// pinned header stops at `minExtent`, so growing minExtent by the inset is
/// what actually moves the resting position down. The child keeps its own
/// [height] and is pushed to the bottom of that box, so the strip's own
/// geometry is unchanged and only the gap above it grows. While the strip is
/// still scrolling toward its rest position that gap is transparent — the
/// hero and header scroll through it — so nothing is drawn in the inset here;
/// the overlay is what fills it once the two meet.
class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final double pinnedInset;
  final Widget Function(bool overlapping) builder;

  const _StickyTabDelegate({
    required this.height,
    required this.builder,
    this.pinnedInset = 0,
  });

  @override
  double get minExtent => height + pinnedInset;

  @override
  double get maxExtent => height + pinnedInset;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final Widget strip = builder(overlapsContent || shrinkOffset > 0);
    if (pinnedInset <= 0) return strip;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [SizedBox(height: pinnedInset), strip],
    );
  }

  @override
  bool shouldRebuild(_StickyTabDelegate old) =>
      old.height != height ||
      old.pinnedInset != pinnedInset ||
      old.builder != builder;
}
