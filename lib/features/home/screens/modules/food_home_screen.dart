import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:waddy_app/common/widgets/add_to_cart_control.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/features/home/widgets/views/top_restaurants_view.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/cuisine/controllers/cuisine_controller.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_category_circles.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_list.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/ramadan_reorder_section.dart';
import 'package:waddy_app/features/banner/controllers/banner_controller.dart';
import 'package:waddy_app/features/home/widgets/banner_view.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/common/widgets/item_bottom_sheet.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_row_card.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';

// ── Filter chip metrics ──────────────────────────────────────────────────────
// Shared by the filter chips, the clear chip and the pinned header's height so
// the three can never disagree about how tall the strip is.

/// Chip visual height. The tap target is larger — see [_kChipRowHeight].
const double _kChipHeight = 34;

/// Fully rounded at this height; named so the clear chip cannot drift from the
/// filters it sits beside.
const double _kChipRadius = 30;

/// Row height, and therefore the chips' tap target. 44 is the iOS HIG minimum
/// and this strip is thumb-targeted on a moving feed.
const double _kChipRowHeight = 44;

/// Space above and below the chip row inside the pinned band.
///
/// Top matches the bind gap used elsewhere on the screen rather than going
/// tighter: the chips are their own control group, not part of the cuisine
/// strip above them, and at 8 they read as a second row of that strip.
const double _kChipStripTopPad = Dimensions.paddingSizeMedium;

/// Gap between chips and around the sort/filter hairline. The design runs a
/// single 9px rhythm across the whole strip.
const double _kChipGap = 9;
const double _kChipStripBottomPad = Dimensions.paddingSizeMedium;

// ── Section rhythm ───────────────────────────────────────────────────────────
// One gap between whole sections, one smaller gap where a section binds to the
// thing it introduces. The screen previously spaced its sections with ad-hoc
// 16 / 8 / 20 literals, so the seam between "Order again" and the ranked rail
// was half the seam between the rail and the catalogue, with nothing deciding
// which was which.

/// Between two unrelated sections.
const double _kSectionGap = Dimensions.paddingSizeExtraLarge;

/// Between a section and content that belongs to it — a header and its strip,
/// a rail and its own cards. Deliberately less than [_kSectionGap]: proximity
/// is what says "these two things are one thing".
const double _kSectionGapTight = Dimensions.paddingSizeMedium;

class FoodHomeScreen extends StatefulWidget {
  final ScrollController scrollController;
  const FoodHomeScreen({super.key, required this.scrollController});

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen> {
  /// Food filters by cuisine, not category: the Food module has no category
  /// rows, so the strip and the store query both key off cuisine ids.
  ///
  /// The filter state itself lives on [StoreController], and only there. This
  /// screen used to keep its own copy in five `setState` fields and push them
  /// into the controller without ever reading back — so the chips rendered
  /// from one copy and the list from the other. `DashboardScreen` builds its
  /// pages with a `PageView.builder` that keeps nothing alive, so a hop to the
  /// Orders tab disposed this State: the chips came back empty while the
  /// controller was still filtering the list, and the only way out was to
  /// toggle a chip on and off again.
  ModuleStoreFilters get _filters =>
      Get.find<StoreListController>().moduleFilters;

  int? get _selectedCuisineId => _filters.cuisineId;
  bool get _filterOffers => _filters.offers;
  bool get _filterUnder30 => _filters.maxDeliveryTime != null;
  bool get _filterFreeDelivery => _filters.freeDelivery;
  String get _selectedSort => _filters.sort ?? 'default';

  /// Change one filter, keeping the rest. The controller refetches and
  /// notifies; every widget that renders filter state is a `GetBuilder` on it,
  /// so nothing here calls `setState` for a filter any more.
  void _applyFilters(ModuleStoreFilters next) {
    Get.find<StoreListController>().setModuleStoreFilters(next);
  }

  /// Horizontal offset of the filter strip.
  ///
  /// Held so the strip can be sent back to its start when the clear chip
  /// appears. The chip is inserted at index 0, and a `ListView` keeps its pixel
  /// offset across a rebuild — so on a strip already scrolled past "Sort by",
  /// the new leading chip is inserted *behind* the current viewport and the
  /// control that just appeared is invisible until the user scrolls back for
  /// it.
  final ScrollController _chipScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _chipScrollController.dispose();
    super.dispose();
  }

  void _loadData() {
    Get.find<CuisineController>().getCuisineList(false);
    if (Get.find<AddressController>().addressList == null) {
      Get.find<AddressController>().getAddressList();
    }
    // Feeds TopRestaurantsView's ranked rail. Nothing else fetches this for
    // the Food module: home_screen.dart only calls it for the no-module
    // dashboard and for pharmacy, and splash_controller only refetches it on
    // module exit — so without this call the rail is stuck on stale data
    // from whatever module was open before, or null forever.
    Get.find<StoreListController>().getFeaturedStoreList();

    // Feeds this screen's BannerView, for the same reason as the rail above.
    //
    // home_screen's loadData reads `splashController.module` once, at the top,
    // and picks its branch from that snapshot: the module-scoped banner fetch
    // sits behind `module != null`, the featured one behind `module == null`.
    // On a cold start into a restored module, `/api/v1/module` has not
    // answered yet when that snapshot is taken, so the no-module branch wins
    // and `/api/v1/banners` is never requested. The load cannot simply be run
    // again either — `_loadInFlight` swallows a concurrent call and the
    // two-minute quiet window swallows a later one — so the module's own home
    // asks for what it renders, on mount, when the module is known for certain.
    Get.find<BannerController>().getBannerList(false);
  }

  // Chips/sort/cuisine are applied server-side: results cover the whole
  // catalogue, not just the pages loaded so far.
  void _onCuisineTap(int? cuisineId) {
    _applyFilters(
      _filters.copyWith(
        cuisineId: _selectedCuisineId == cuisineId ? null : cuisineId,
      ),
    );
  }

  void _showSortBottomSheet() {
    Get.bottomSheet(
      _DesignSheet(
        title: 'sort_by'.tr,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeSmall,
            0,
            Dimensions.paddingSizeSmall,
            Dimensions.paddingSizeMedium,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSortOption('default', 'recommended'.tr),
              _buildSortOption('rating', 'top_rated'.tr),
              _buildSortOption('distance', 'nearest_first'.tr),
              _buildSortOption('a_z', 'a_z'.tr),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildSortOption(String value, String title) {
    final bool isSelected = _selectedSort == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Get.back();
          _applyFilters(
            _filters.copyWith(sort: value == 'default' ? null : value),
          );
        },
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeMedium,
            vertical: 15,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: waddyMedium.copyWith(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color:
                        isSelected
                            ? Theme.of(context).primaryColor
                            : WaddyColors.ink,
                  ),
                ),
              ),
              if (isSelected)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTick02,
                  color: Theme.of(context).primaryColor,
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Opens the item sheet (handles variations/addons) instead of blind
  // cart insertion — same pattern as cart_item_widget.
  void _openItemSheet(BuildContext context, Items item) {
    if (item.id == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (con) => ItemBottomSheet(itemId: item.id!),
    );
  }

  /// Returns a SLIVER, not a box. This screen is rendered directly into the
  /// home screen's `CustomScrollView`, so it must be placed in `slivers:`.
  ///
  /// It used to return a flat `Column` of the sections below, which the home
  /// screen then wrapped in a single `SliverToBoxAdapter`. A `Column` has no
  /// viewport awareness, so every rail, card, shimmer and image — the whole
  /// restaurant catalogue included — was built, laid out and painted in the
  /// first frame and rebuilt on every controller update, however far below the
  /// fold it sat. The lazy-loading machinery was present and defeated by one
  /// wrapper.
  ///
  /// `SliverMainAxisGroup` lets the sections become real slivers without moving
  /// this widget's state (`_selectedCuisineId`, the category fade) up to the
  /// parent. The section widgets themselves are unchanged; only the store list
  /// swapped to a builder, because it is the one with an unbounded item count.
  bool get _hasActiveChipFilter =>
      _filterOffers ||
      _filterUnder30 ||
      _filterFreeDelivery ||
      _selectedSort != 'default';

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: HomeHeroBannerWidget(showBackButton: true, compact: true),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: _kSectionGap)),
        SliverToBoxAdapter(child: _buildOrderAgainSection(context)),
        const SliverToBoxAdapter(child: SizedBox(height: _kSectionGapTight)),
        const SliverToBoxAdapter(child: TopRestaurantsView()),
        const SliverToBoxAdapter(
          child: BannerView(isFeatured: false, showRamadanWrapper: false),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: _kSectionGap)),
        // A hairline, not just the gap above: when there is no active banner
        // the rail and "All restaurants" were separated by nothing but
        // whitespace, which reads as a soft pause rather than a section
        // ending. The rule gives the eye an actual edge to land on before the
        // catalogue starts.
        const SliverToBoxAdapter(child: _SectionDivider()),
        const SliverToBoxAdapter(child: SizedBox(height: _kSectionGap)),
        SliverToBoxAdapter(child: _buildCatalogueHeader(context)),
        SliverToBoxAdapter(
          // Same reason as the chip strip: the selected tile's ring is filter
          // state, and the screen no longer rebuilds when that changes.
          child: GetBuilder<StoreListController>(
            id: StoreListController.cuisineStripId,
            builder:
                (_) => ModuleCuisineCircles(
                  selectedCuisineId: _selectedCuisineId,
                  onCuisineTap: _onCuisineTap,
                  // No leading "all" tile: the section header directly above the
                  // strip already reads "All restaurants" whenever nothing is
                  // selected, and says it in words rather than as a logo slideshow
                  // wearing a selected ring. See [ModuleCuisineCircles.showAllTile].
                  showAllTile: false,
                  allLabel: 'all'.tr,
                  allSemanticLabel: 'all_restaurants'.tr,
                  fallbackIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedRestaurant02,
                    size: 26,
                    color: Theme.of(context).primaryColor,
                  ),
                  // 0: the chip strip below supplies its own top pad, and the strip
                  // box now ends at the label rather than at a two-line reservation,
                  // so anything here lands on top of that and re-opens the gap this
                  // pass closed.
                  bottomPadding: 0,
                ),
          ),
        ),
        // Pinned, not scrolled away with the cuisines above it. The chips are
        // how you narrow a catalogue you are scrolling *through* — leaving
        // them at the top meant scrolling back to the cuisine strip to change
        // your mind about free delivery. The cuisine tiles keep scrolling:
        // they are a starting point, the chips are a running control.
        SliverPersistentHeader(
          pinned: true,
          // No filter signature any more. The delegate used to be handed a
          // hash of the five local filter fields so it would repaint when one
          // changed; the strip inside it now subscribes to the controller
          // directly, so the delegate has nothing left to compare — its size
          // is fixed and its child is self-updating.
          delegate: _FilterChipsHeader(child: _buildFilterChips(context)),
        ),
        // No trailing SizedBox: the store list reserves the bottom-nav overlay
        // itself via isLastInScrollView.
        _buildStoreListSliver(context),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // ORDER AGAIN
  // ═══════════════════════════════════════════
  Widget _buildOrderAgainSection(BuildContext context) {
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
                titleFontSize: 20,
                subtitleFontSize: 13,
                listHeight: 170,
                bottomPadding: 20,
                subtitleGap: 14,
              );
            }
            return _buildNormalOrderAgain(
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

  Widget _buildNormalOrderAgain(
    BuildContext context,
    List<Store> stores,
    Color primaryColor,
    Color accentColor,
  ) {
    // Flatten stores into individual item entries
    final List<_OrderAgainItemData> allItems = [];
    for (final store in stores) {
      if (store.items != null) {
        for (final item in store.items!.take(3)) {
          allItems.add(_OrderAgainItemData(store: store, item: item));
        }
      }
    }
    if (allItems.isEmpty) return const SizedBox();
    final displayItems = allItems.take(10).toList();

    return Padding(
      // No bottom pad of its own: the slivers list places the gap after this
      // section. Both was how the Order Again → rail seam ended up larger than
      // the gap between the rail and the catalogue below it.
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Section header ───
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Row(
              children: [
                IntrinsicWidth(
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: 2,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusExtraSmall,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'order_again'.tr,
                        style: waddyBold.copyWith(
                          fontSize: 18,
                          color: WaddyColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _kSectionGapTight),
          // ─── Compact horizontal item cards ───
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              itemCount: displayItems.length,
              itemBuilder:
                  (context, index) => _buildCompactItemCard(
                    context,
                    displayItems[index],
                    primaryColor,
                    accentColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactItemCard(
    BuildContext context,
    _OrderAgainItemData data,
    Color primaryColor,
    Color accentColor,
  ) {
    final store = data.store;
    final item = data.item;
    final double originalPrice = item.price ?? 0;
    final ItemPrice price = ItemPrice.from(
      now:
          PriceConverter.convertWithDiscount(
            originalPrice,
            item.discount ?? 0,
            item.discountType,
          ) ??
          originalPrice,
      was: originalPrice,
      flat: item.discountType == 'amount',
    );
    final String formattedPrice = PriceConverter.convertPrice(price.now);

    return PressableScale(
      // Item first: this card leads with the dish, the store is context.
      semanticLabel: [
        item.name?.trim(),
        store.name?.trim(),
        formattedPrice,
      ].whereType<String>().where((e) => e.isNotEmpty).join(', '),
      onTap: () => StoreNavigator.open(store),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: Dimensions.paddingSizeMedium),
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(color: WaddyColors.divider),
          boxShadow: const [
            // shadowTeal, not black-at-6%: every other elevated surface in the
            // app casts a teal-tinted shadow, and a neutral one here read as a
            // slightly colder card in a warm-tinted feed.
            BoxShadow(
              color: WaddyColors.shadowTeal,
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // ─── Square image with discount badge ───
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    // Same mint plate the store thumbnails sit on while their
                    // photo loads, rather than a cold grey hole.
                    color: WaddyColors.mintSurface,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // The app's sale collar, solid for the photo.
                if (price.onSale)
                  PositionedDirectional(
                    top: -4,
                    start: -4,
                    child:
                        OfferCollarBadge.forPrice(
                          price,
                          compact: true,
                          onPhoto: true,
                        )!,
                  ),
              ],
            ),
            const SizedBox(width: 10),
            // ─── Info column ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Item name
                  Text(
                    item.name ?? '',
                    style: waddyBold.copyWith(
                      fontSize: 13,
                      color: WaddyColors.ink,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Store name with logo
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusExtraSmall,
                          ),
                          border: Border.all(
                            color: WaddyColors.divider,
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusExtraSmall,
                          ),
                          child: CustomImage(
                            image: store.logoFullUrl ?? '',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          store.name ?? '',
                          style: waddyRegular.copyWith(
                            fontSize: 11,
                            // grey.shade500 on white is 2.68:1 — below AA for
                            // text this size. inkLight is 4.59:1 and reads as
                            // the same weight of "secondary".
                            color: WaddyColors.inkLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Price + add button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: PriceTag(price: price)),
                      // The app's add square. Opens the sheet — this rail's
                      // lightweight `Items` cannot tell a simple dish from one
                      // with options — and counts what is already in the cart.
                      // Its own Pressable wins the arena over the card's
                      // store-navigation tap.
                      GetBuilder<CartController>(
                        filter: (cart) => cart.cartQuantity(item.id ?? -1),
                        builder:
                            (cart) => AddToCartSquare(
                              inCart: cart.cartQuantity(item.id ?? -1),
                              semanticLabel: item.name ?? '',
                              onTap: () => _openItemSheet(context, item),
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
    );
  }

  // ═══════════════════════════════════════════
  // CATALOGUE HEADER
  // ═══════════════════════════════════════════

  /// Names what the list below is currently showing: "All restaurants" when
  /// nothing is filtered, "Pizza · 4 restaurants" when something is.
  ///
  /// This is the cuisine strip's only strong feedback. Selection was carried
  /// by a 2pt ring on a 76pt tile and by the list silently changing beneath
  /// it — on a strip that scrolls horizontally, the selected tile can be off
  /// screen entirely, so the user had no on-screen statement of what they had
  /// picked. Naming it here also explains a thin result *before* the user
  /// scrolls into it and wonders whether the app is broken.
  ///
  /// The count is [StoreModel.totalSize] — the server's total for the whole
  /// active filter set, not the cuisine's own catalogue size and not the
  /// number of rows loaded so far. That matters twice over: pagination means
  /// `stores.length` is only the first page, and the chips narrow the result
  /// too, so a count taken from the cuisine alone would disagree with the list
  /// the moment "Under 30 mins" is also on.
  Widget _buildCatalogueHeader(BuildContext context) {
    return GetBuilder<CuisineController>(
      builder: (cuisineController) {
        return GetBuilder<StoreListController>(
          id: StoreListController.storeListId,
          builder: (storeController) {
            return Padding(
              // No top pad: the section gap above already placed this header.
              // Bottom binds it to the cuisine strip it labels — the header and
              // the tiles are one unit, so this seam stays tighter than the one
              // that separated it from the rail above.
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

  /// The headline string. Falls back to the unqualified "All restaurants" in
  /// every case where a specific claim can't be made — no cuisine selected, a
  /// cuisine whose name we can't resolve, or a list still loading (null
  /// `totalSize`). A header that printed "Pizza · 0 restaurants" while the
  /// shimmer was still running would be wrong for the half-second that matters
  /// most.
  String _catalogueHeadline(
    CuisineController cuisineController,
    StoreListController storeController,
  ) {
    final int? cuisineId = _selectedCuisineId;
    if (cuisineId == null) return 'all_restaurants'.tr;

    final String cuisineName = cuisineController.namesFor([cuisineId]);
    if (cuisineName.isEmpty) return 'all_restaurants'.tr;

    final int? total = storeController.storeModel?.totalSize;
    if (total == null) return cuisineName;

    return (total == 1
            ? 'cuisine_restaurant_count_one'
            : 'cuisine_restaurant_count_other')
        .trParams({'cuisine': cuisineName, 'count': '$total'});
  }

  // ═══════════════════════════════════════════
  // FILTER CHIPS
  // ═══════════════════════════════════════════
  //
  // Two fixed icon buttons (sort · filters), a hairline, then a horizontally
  // scrolling row of one-tap quick chips (Hot Deals · Nearest · Best Seller).
  //
  // The two full-option controls — the sort sheet's "Recommended"/"A-Z" and
  // the filters sheet's "Under 30 mins"/"Free delivery" — moved off the
  // scrolling strip and behind icons so the strip's remaining chips could be
  // the ones people actually reach for one-tap: Nearest and Best Seller are
  // promoted straight out of the sort sheet into the strip because they are
  // the two most common intents on a food list, and hiding them a tap deeper
  // than "Sort by" cost most users a step they took every session. "Hot
  // Deals" replaces the flatter "Offers" label — same filter, warmer name.
  /// Wrapped in its own `GetBuilder`, because the strip lives inside a pinned
  /// `SliverPersistentHeader` whose delegate is built by the screen's `build`
  /// — and nothing rebuilds that when a filter changes now that the state
  /// lives on the controller. Subscribing here is also the narrower repaint:
  /// toggling a chip redraws the strip, not the page.
  Widget _buildFilterChips(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.storeListId,
      builder: (_) => _filterChipsRow(context),
    );
  }

  Widget _filterChipsRow(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    // Single-select against each other and against "no sort": tapping one
    // while another quick-sort chip is active swaps the sort rather than
    // combining it, because a list can only be ordered one way at a time.
    final quickChips = [
      {
        'label': 'hot_deals'.tr,
        'active': _filterOffers,
        'onTap': () => _applyFilters(_filters.copyWith(offers: !_filterOffers)),
      },
      {
        'label': 'nearest'.tr,
        'active': _selectedSort == 'distance',
        'onTap':
            () => _applyFilters(
              _filters.copyWith(
                sort: _selectedSort == 'distance' ? null : 'distance',
              ),
            ),
      },
      {
        'label': 'best_seller'.tr,
        'active': _selectedSort == 'rating',
        'onTap':
            () => _applyFilters(
              _filters.copyWith(
                sort: _selectedSort == 'rating' ? null : 'rating',
              ),
            ),
      },
    ];
    // No clear chip. Every filter on this strip is a toggle that stays on
    // screen wearing its own on-state, so the row already shows what is on and
    // tapping a chip again turns it off. A dedicated reset only restated that,
    // and it was inserted at the head of the strip — so switching one filter
    // on shoved the rest of the chips out of view, which cost more than the
    // reset ever bought. Clearing is tapping the lit chips off.

    return Padding(
      padding: const EdgeInsets.only(
        top: _kChipStripTopPad,
        bottom: _kChipStripBottomPad,
        left: Dimensions.paddingSizeDefault,
      ),
      child: SizedBox(
        height: _kChipRowHeight,
        child: Row(
          children: [
            _FilterIconButton(
              icon: HugeIcons.strokeRoundedArrowUpDown,
              // The sheet still owns Recommended/Top rated/A-Z; only its
              // Nearest and Best seller entries have quick-chip twins, so the
              // icon is "on" only for the one sheet option nothing else
              // represents on the strip.
              active: _selectedSort == 'a_z',
              semanticLabel: 'sort_by'.tr,
              onTap: _showSortBottomSheet,
            ),
            const SizedBox(width: _kChipGap),
            _FilterIconButton(
              icon: HugeIcons.strokeRoundedFilterHorizontal,
              active: _filterUnder30 || _filterFreeDelivery,
              semanticLabel: 'filters'.tr,
              onTap: _showFiltersBottomSheet,
            ),
            const SizedBox(width: _kChipGap),
            Container(width: 1, height: 20, color: WaddyColors.divider),
            const SizedBox(width: _kChipGap),
            Expanded(
              child: ListView.builder(
                controller: _chipScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                // Padding on the list, not the parent: the trailing inset has
                // to be *inside* the scrollable or the last chip ends flush
                // against the screen edge when the strip is scrolled to its
                // end.
                padding: const EdgeInsets.only(
                  right: Dimensions.paddingSizeDefault,
                ),
                itemCount: quickChips.length,
                itemBuilder: (context, index) {
                  final filter = quickChips[index];
                  final bool isActive = filter['active'] as bool;
                  final VoidCallback onTap = filter['onTap'] as VoidCallback;
                  final String filterLabel = (filter['label'] as String?) ?? '';
                  final bool isLast = index == quickChips.length - 1;
                  return Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : _kChipGap),
                    child: PressableScale(
                      semanticLabel:
                          isActive
                              ? '$filterLabel, ${'selected'.tr}'
                              : filterLabel,
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
                              isActive
                                  ? primaryColor
                                  : WaddyColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(_kChipRadius),
                          // Matches _FilterIconButton's inactive hairline —
                          // see the comment there.
                          border:
                              isActive
                                  ? null
                                  : Border.all(
                                    color: WaddyColors.divider,
                                    width: 1,
                                  ),
                        ),
                        child: Text(
                          filterLabel,
                          style: waddyMedium.copyWith(
                            fontSize: 14,
                            color: isActive ? Colors.white : WaddyColors.ink,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Under 30 mins" and "Free delivery" — the two hard constraints, moved off
  /// the visible strip and into a sheet behind the filters icon so the strip
  /// itself stays three quick chips wide.
  ///
  /// A `GetBuilder` on the store controller, not a `StatefulBuilder`: the
  /// sheet renders in its own overlay route, so it has to subscribe to the
  /// filter state itself rather than wait for the screen behind it to rebuild.
  /// It also gets the live result count in the footer for free, which used to
  /// be read once when the sheet opened and never updated as switches moved.
  void _showFiltersBottomSheet() {
    Get.bottomSheet(
      GetBuilder<StoreListController>(
        id: StoreListController.storeListId,
        builder: (storeController) {
          final ModuleStoreFilters filters = storeController.moduleFilters;
          final int? total = storeController.storeModel?.totalSize;

          return _DesignSheet(
            title: 'filters'.tr,
            body: Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeLarge,
                0,
                Dimensions.paddingSizeLarge,
                Dimensions.paddingSizeMedium,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetSection(
                    title: 'delivery_time'.tr,
                    chips: [
                      _SheetChip(
                        label: 'under_30_mins'.tr,
                        selected: filters.maxDeliveryTime != null,
                        onTap:
                            () => _applyFilters(
                              filters.copyWith(
                                maxDeliveryTime:
                                    filters.maxDeliveryTime != null ? null : 30,
                              ),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  _SheetSection(
                    title: 'offers'.tr,
                    chips: [
                      _SheetChip(
                        label: 'free_delivery'.tr,
                        selected: filters.freeDelivery,
                        onTap:
                            () => _applyFilters(
                              filters.copyWith(
                                freeDelivery: !filters.freeDelivery,
                              ),
                            ),
                      ),
                      _SheetChip(
                        label: 'hot_deals'.tr,
                        selected: filters.offers,
                        onTap:
                            () => _applyFilters(
                              filters.copyWith(offers: !filters.offers),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            footer: _SheetFooter(
              resultCount: total,
              // Resets what this sheet owns. The cuisine and the sort are set
              // elsewhere on the screen and stay put — a reset button clears
              // the panel it sits in, not the whole screen behind it.
              onReset:
                  () => _applyFilters(
                    filters.copyWith(
                      maxDeliveryTime: null,
                      freeDelivery: false,
                      offers: false,
                    ),
                  ),
              onApply: () => Get.back(),
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildStoreListSliver(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.storeListId,
      builder: (storeController) {
        final bool hasFilters =
            _selectedCuisineId != null || _hasActiveChipFilter;
        return ModuleStoreListSliver(
          scrollController: widget.scrollController,
          // Last element in the food home — reserves the bottom-nav overlay.
          isLastInScrollView: true,
          storeModel: storeController.storeModel,
          shimmer: _buildStoreListShimmer(),
          emptyIcon: const HugeIcon(
            icon: HugeIcons.strokeRoundedChefHat,
            size: 52,
            color: WaddyColors.inkMuted,
          ),
          emptyTitle:
              hasFilters
                  ? 'no_restaurants_in_category'.tr
                  : 'no_restaurant_available'.tr,
          emptySubtitle: 'try_different_category'.tr,
          cardBuilder: (store) => _buildStoreCard(context, store),
        );
      },
    );
  }

  /// Browse row for one restaurant. See [ModuleStoreRowCard] for why the card
  /// is a row rather than a hero.
  Widget _buildStoreCard(BuildContext context, Store store) {
    return ModuleStoreRowCard(
      store: store,
      onTap: () => StoreNavigator.open(store),
    );
  }

  /// Placeholder shaped like [ModuleStoreRowCard]: 84pt square, then three
  /// text bars and a chip row. A shimmer that does not match the real card
  /// makes the list jump when data lands — so the square, its radius and the
  /// 20pt row gutter are the card's numbers, not approximations of them.
  Widget _buildStoreListShimmer() {
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
                      color: WaddyColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBar(width: 170, height: 18),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),
                        _shimmerBar(width: 130, height: 14),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),
                        _shimmerBar(width: 150, height: 14),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        _shimmerBar(width: 120, height: 23),
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

  Widget _shimmerBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Warm-tinted, matching the rails' shimmer. grey.shade200 is a cold
        // neutral and read as a different loading state to the one directly
        // above it on the same screen.
        color: WaddyColors.surfaceRaised,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// FILTER STRIP ICON BUTTON
// ═══════════════════════════════════════════

/// One of the two fixed circles at the head of the filter strip (sort ·
/// filters). Plain grey at rest, filled with the brand colour once the sheet
/// behind it has something switched on — the only feedback available once
/// that state is a sheet's worth of controls away and not itself on screen.
class _FilterIconButton extends StatelessWidget {
  /// A HugeIcons glyph (`HugeIcons.strokeRounded*`), not an [IconData]: the
  /// package ships icons as path data rather than a font codepoint.
  final List<List<dynamic>> icon;
  final bool active;
  final String semanticLabel;
  final VoidCallback onTap;

  const _FilterIconButton({
    required this.icon,
    required this.active,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      semanticLabel:
          active ? '$semanticLabel, ${'selected'.tr}' : semanticLabel,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 34,
        height: 34,
        // Required, and not cosmetic: a sized Container with a child but no
        // alignment passes its own tight constraints straight down, so the
        // icon is stretched to the full 34pt circle and its `size` is
        // ignored. `Icon` hid this by centring its glyph itself; HugeIcon
        // paints an SvgPicture, which simply scales to fill what it is given.
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              active
                  ? Theme.of(context).primaryColor
                  : WaddyColors.surfaceRaised,
          shape: BoxShape.circle,
          // Same hairline as the quick chips' inactive state (see
          // _buildFilterChips) — one border language across every control on
          // the strip, circle and pill alike, so the divider in between reads
          // as a seam inside one group rather than a line between two.
          border:
              active ? null : Border.all(color: WaddyColors.divider, width: 1),
        ),
        child: HugeIcon(
          icon: icon,
          size: 16,
          color: active ? Colors.white : WaddyColors.ink,
        ),
      ),
    );
  }
}

/// A single hairline marking the end of the "Top 10" block, page-margin to
/// page-margin. Its own top/bottom gap comes from the [_kSectionGap]
/// [SizedBox]es placed around it, not internal padding — one seam owns the
/// spacing, this rule just gives it an edge to break on.
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

// ═══════════════════════════════════════════
// ORDER AGAIN ITEM DATA MODEL
// ═══════════════════════════════════════════
class _OrderAgainItemData {
  final Store store;
  final Items item;

  const _OrderAgainItemData({required this.store, required this.item});
}

// ═══════════════════════════════════════════
// PINNED FILTER CHIPS
// ═══════════════════════════════════════════

/// Holds the filter strip at the top of the viewport once the cuisine tiles
/// have scrolled past it.
///
/// The band is a fixed height and does not collapse: a shrinking filter row
/// is harder to hit than a still one, and there is nothing in it worth
/// reclaiming 20pt for. It paints an opaque background because a pinned
/// header sits *over* the store rows sliding beneath it — without one the
/// restaurant names read straight through the chips.
class _FilterChipsHeader extends SliverPersistentHeaderDelegate {
  /// Derived from the same constants `_buildFilterChips` lays out with, rather
  /// than a hand-added total. The two were separately maintained numbers that
  /// had to agree exactly — a pinned header shorter than its child clips it,
  /// taller leaves a band of dead colour — so the sum is computed once here.
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

  /// Never, on its own account. The strip is a `GetBuilder` on the store
  /// controller, so it repaints itself when a filter changes; the delegate's
  /// only other input is a fixed height. Returning true here would repaint the
  /// header on every parent build — a `Widget` field compares by identity, so
  /// "did the child change" is always yes.
  @override
  bool shouldRebuild(_FilterChipsHeader oldDelegate) => false;
}

/// Shared chrome for the sort and filters sheets: grab handle, title row with
/// a close button, scrollable body and an optional pinned footer. Content
/// sizes the sheet; the cap only matters once the body outgrows the screen.
class _DesignSheet extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? footer;

  const _DesignSheet({required this.title, required this.body, this.footer});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: WaddyColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: waddyBold.copyWith(
                    fontSize: 18,
                    color: WaddyColors.ink,
                  ),
                ),
                InkWell(
                  onTap: () => Get.back(),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: WaddyColors.surfaceRaised,
                      shape: BoxShape.circle,
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 14,
                      color: WaddyColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: SingleChildScrollView(child: body)),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// One labelled group of filter chips inside a sheet.
class _SheetSection extends StatelessWidget {
  final String title;
  final List<Widget> chips;

  const _SheetSection({required this.title, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title.toUpperCase(),
          style: waddyMedium.copyWith(
            fontSize: 13,
            color: WaddyColors.inkLight,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: _kChipGap, runSpacing: _kChipGap, children: chips),
      ],
    );
  }
}

/// Selectable pill inside a sheet — same fill/radius language as the strip.
class _SheetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kChipRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color:
                selected
                    ? Theme.of(context).primaryColor
                    : WaddyColors.surfaceRaised,
            borderRadius: BorderRadius.circular(_kChipRadius),
          ),
          child: Text(
            label,
            style: waddyMedium.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : WaddyColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reset / apply pair pinned to the bottom of the filters sheet.
class _SheetFooter extends StatelessWidget {
  final int? resultCount;
  final VoidCallback onReset;
  final VoidCallback onApply;

  const _SheetFooter({
    required this.resultCount,
    required this.onReset,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final int? count = resultCount;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: WaddyColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(_kChipRadius),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_kChipRadius),
                  border: Border.all(color: WaddyColors.divider),
                ),
                child: Text(
                  'reset'.tr,
                  style: waddyMedium.copyWith(
                    fontSize: 15,
                    color: WaddyColors.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: onApply,
              borderRadius: BorderRadius.circular(_kChipRadius),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(_kChipRadius),
                ),
                child: Text(
                  // Falls back to a plain apply label until the server has
                  // reported a total, so the button never reads "Show null".
                  count == null
                      ? 'apply'.tr
                      : '${'show'.tr} $count ${'restaurants'.tr}',
                  style: waddyBold.copyWith(fontSize: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
