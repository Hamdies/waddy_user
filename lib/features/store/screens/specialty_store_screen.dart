import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/store/widgets/store_page_shimmer.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/produce_preference.dart';
import 'package:waddy_app/features/store/domain/models/buy_again_line.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/cart/widgets/pill_cart_bar.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/scratch_card/widgets/scratch_card_badge.dart';
import 'package:waddy_app/features/store/controllers/store_page_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/screens/store_category_items_screen.dart';
import 'package:waddy_app/features/store/widgets/filter_widget.dart';
import 'package:waddy_app/features/store/widgets/store_notices.dart';
import 'package:waddy_app/features/item/screens/mart_product_screen.dart';
import 'package:waddy_app/features/store/widgets/store_info_sheet.dart';
import 'package:waddy_app/features/store/widgets/store_product_card.dart';
import 'package:waddy_app/features/store/widgets/store_section_header.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/features/store/helpers/item_count_label.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// Painted height of the pinned category strip: 12 + a 36 chip + 12.
const double _kTabBarHeight = 60;

/// Scroll distance, from the moment the strip pins, over which it slides
/// down to sit under the mini header. See the `SliverLayoutBuilder` around
/// it, and the same mechanism on `FoodStoreScreen`.
const double _kInsetRampDistance = 100;

/// The page for a grocery store that is not a supermarket — a butcher, a
/// greengrocer, a bakery, a dairy (Claude Design "Specialty Store Page",
/// layout "A · Menu list").
///
/// ```
///   header        store, search, delivery chips          (shared with
///   Buy again     what you got here last time             the supermarket)
///   Most ordered  cards, only once things have sold
///   Deals         cards, marked-down items
///   Everything    pinned category tabs that follow the scroll,
///                 one group of rows per category
///   note card     "Leave a note at checkout"
/// ```
///
/// Supermarkets get the aisle page (`StoreScreen`), restaurants and other
/// modules the menu page (`FoodStoreScreen`); `StoreLayout` decides which.
class SpecialtyStoreScreen extends StatefulWidget {
  final Store? store;
  final String slug;

  const SpecialtyStoreScreen({super.key, required this.store, this.slug = ''});

  @override
  State<SpecialtyStoreScreen> createState() => _SpecialtyStoreScreenState();
}

class _SpecialtyStoreScreenState extends State<SpecialtyStoreScreen> {
  final ScrollController _scroll = ScrollController();
  final ScrollController _tabsScroll = ScrollController();

  /// This page's own state, opened and closed with it (ST-01/ST-07).
  late final StorePageController _page;

  /// Height the cart bar reports, reserved as tail space.
  double _cartBarHeight = 0;

  /// Mini header down: true once the store header's search bar is gone.
  final ValueNotifier<bool> _mini = ValueNotifier<bool>(false);
  static const double _kMiniHeaderAt = 120;

  /// The mini header's painted height, measured — the pinned tabs sit under
  /// it, and it varies with the system inset.
  final GlobalKey _miniKey = GlobalKey();
  double _miniHeight = 0;

  /// The category group in view, which the pinned tabs highlight.
  final ValueNotifier<int> _activeGroup = ValueNotifier<int>(0);
  final List<GlobalKey> _groupKeys = [];
  final List<GlobalKey> _tabKeys = [];

  /// Set while a tab tap scrolls the page, so the scroll-spy doesn't walk the
  /// highlight through every group on the way.
  bool _jumping = false;

  @override
  void initState() {
    super.initState();
    _page = StorePageController.open();
    _scroll.addListener(_onScroll);
    _activeGroup.addListener(_revealActiveTab);
    _initDataCall();
  }

  @override
  void dispose() {
    _page.close();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _tabsScroll.dispose();
    _mini.dispose();
    _activeGroup.dispose();
    super.dispose();
  }

  Future<void> _initDataCall() async {
    final StorePageController storeCtrl = _page;
    storeCtrl.resetFilter(isUpdate: false);
    storeCtrl.resetStoreRails(notify: false);
    if (storeCtrl.isSearching) storeCtrl.changeSearchStatus(isUpdate: false);
    await storeCtrl.getStoreDetails(
      Store(id: widget.store!.id),
      slug: widget.slug,
    );
    if (Get.find<CategoryController>().categoryList == null) {
      Get.find<CategoryController>().getCategoryList(true);
    }
    final int? storeId = widget.store!.id ?? storeCtrl.store?.id;
    if (storeId == null) return;
    storeCtrl.getBuyAgain(storeId);
    // First page only: the filter sheet reads its price ceiling from it.
    storeCtrl.getStoreItemList(storeId, 1, 'all', false);
  }

  // ── Scroll: mini header, scroll-spy ───────────────────────────────────

  /// Where a group's top counts as "reached": under the mini header and the
  /// pinned tabs.
  double get _readLine => _miniHeight + _kTabBarHeight;

  double? _groupTop(int index) {
    if (index >= _groupKeys.length) return null;
    final RenderObject? box =
        _groupKeys[index].currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  void _onScroll() {
    final bool mini = _scroll.offset > _kMiniHeaderAt;
    if (mini != _mini.value) _mini.value = mini;

    if (_jumping || _groupKeys.isEmpty) return;
    int active = 0;
    for (int i = 0; i < _groupKeys.length; i++) {
      final double? top = _groupTop(i);
      if (top != null && top <= _readLine + 24) active = i;
    }
    _activeGroup.value = active;
  }

  /// Scrolls the page so group [index] starts under the pinned tabs.
  Future<void> _jumpTo(int index) async {
    _activeGroup.value = index;
    _jumping = true;
    try {
      // Twice: the strip's inset ramps while the page moves, which shifts
      // everything under it, so the first landing can be short by that much.
      for (int pass = 0; pass < 2; pass++) {
        final double? top = _groupTop(index);
        if (top == null || !_scroll.hasClients) break;
        final double delta = top - _readLine - Dimensions.paddingSizeSmall;
        if (delta.abs() < 2) break;
        final ScrollPosition position = _scroll.position;
        await _scroll.animateTo(
          (_scroll.offset + delta).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
          duration: pass == 0 ? WaddyMotion.reveal : WaddyMotion.fast,
          curve: WaddyMotion.easeOut,
        );
      }
    } finally {
      _jumping = false;
    }
  }

  /// Keeps the highlighted tab on screen inside its own strip.
  void _revealActiveTab() {
    final int i = _activeGroup.value;
    if (i >= _tabKeys.length || !_tabsScroll.hasClients) return;
    final RenderObject? tab = _tabKeys[i].currentContext?.findRenderObject();
    if (tab is! RenderBox || !tab.attached) return;
    final double left = tab.localToGlobal(Offset.zero).dx;
    final double width = MediaQuery.sizeOf(context).width;
    final double centre = left + tab.size.width / 2;
    final ScrollPosition position = _tabsScroll.position;
    _tabsScroll.animateTo(
      (_tabsScroll.offset + centre - width / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: WaddyMotion.enter,
      curve: WaddyMotion.easeOut,
    );
  }

  void _measureMiniHeader() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderObject? box = _miniKey.currentContext?.findRenderObject();
      final double h = box is RenderBox ? box.size.height : 0;
      if (h > 0 && (h - _miniHeight).abs() > 0.5) {
        setState(() => _miniHeight = h);
      }
    });
  }

  // ── Data ──────────────────────────────────────────────────────────────

  /// One product rail, fed by [StorePageController.fetchStoreRail]: fetched
  /// when first built, rebuilt alone when its items land, collapsed when the
  /// store has nothing for it.
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
        return builder(items);
      },
    );
  }

  void _openCategory(StorePageController storeController, CategoryModel c) {
    final int index =
        storeController.categoryList?.indexWhere((x) => x.id == c.id) ?? -1;
    if (index < 0) return;
    storeController.setCategoryIndex(index);
    Get.to(
      () => StoreCategoryItemsScreen(
        page: _page,
        storeId: storeController.store!.id,
        categoryName: c.name ?? '',
      ),
    );
  }

  void _openFilterSheet(BuildContext context, StorePageController ctrl) {
    final double maxPrice = (ctrl.storeItemModel?.items ?? []).fold<double>(
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

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _measureMiniHeader();
    return Scaffold(
      backgroundColor: WaddyColors.canvas,
      body: GetBuilder<StorePageController>(
        tag: _page.tag,
        builder: (storeController) {
          return GetBuilder<CategoryController>(
            builder: (_) {
              final Store? store =
                  storeController.store?.name != null
                      ? storeController.store
                      : null;
              if (store == null)
                return StorePageShimmer(
                  layout: StorePageShimmerLayout.specialty,
                  store: widget.store,
                );

              // A specialty store's tabs are its own categories, from its
              // details payload, in admin order.
              storeController.setCategoryList();
              final List<CategoryModel> categories =
                  (storeController.categoryList ?? const <CategoryModel>[])
                      .where((c) => c.id != 0)
                      .toList();
              // No categories: one group holding everything.
              final List<CategoryModel> groups =
                  categories.isEmpty
                      ? [CategoryModel(id: 0, name: 'all_products'.tr)]
                      : categories;
              while (_groupKeys.length < groups.length) {
                _groupKeys.add(GlobalKey());
                _tabKeys.add(GlobalKey());
              }
              if (_groupKeys.length > groups.length) {
                _groupKeys.removeRange(groups.length, _groupKeys.length);
                _tabKeys.removeRange(groups.length, _tabKeys.length);
              }

              return Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _initDataCall,
                    child: CustomScrollView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // ─── HEADER: store, search, promises ───
                        SliverToBoxAdapter(
                          child: StoreHeroBannerWidget(
                            store: store,
                            onStoreTap:
                                () => StoreInfoSheet.show(context, store),
                            onFilterTap:
                                () =>
                                    _openFilterSheet(context, storeController),
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

                        // ─── DISCOUNT + ANNOUNCEMENT ───
                        SliverToBoxAdapter(
                          child: StoreAnnouncement(store: store),
                        ),

                        // ─── BUY AGAIN ───
                        SliverToBoxAdapter(child: _buildBuyAgain()),

                        // ─── MOST ORDERED ───
                        SliverToBoxAdapter(
                          child: _rail(
                            'popular',
                            sort: 'popular',
                            builder: (items) {
                              // Only what has actually sold, and only once
                              // there's enough of it to call it a pattern.
                              final List<Item> sold =
                                  items
                                      .where((i) => (i.orderCount ?? 0) > 0)
                                      .toList();
                              if (sold.length < 3) {
                                return const SizedBox.shrink();
                              }
                              return _cardSection(
                                title: 'most_ordered'.tr,
                                subtitle: 'most_ordered_at_sub'.trParams({
                                  'store': store.name ?? '',
                                }),
                                items: sold,
                              );
                            },
                          ),
                        ),

                        // ─── DEALS ───
                        SliverToBoxAdapter(
                          child: _rail(
                            'discounted',
                            sort: 'discounted',
                            builder:
                                (items) => _cardSection(
                                  title: 'deals_right_now'.tr,
                                  subtitle: 'deals_at_store_sub'.trParams({
                                    'store': store.name ?? '',
                                  }),
                                  items: items,
                                ),
                          ),
                        ),

                        // ─── EVERYTHING: title, pinned tabs, groups ───
                        SliverToBoxAdapter(
                          child: StoreSectionHeader(
                            title: 'everything_at_store'.trParams({
                              'store': store.name ?? '',
                            }),
                            subtitle: 'tap_for_options_sub'.tr,
                            padding: EdgeInsetsDirectional.fromSTEB(
                              20,
                              32,
                              20,
                              groups.length > 1 ? 0 : 8,
                            ),
                          ),
                        ),
                        if (groups.length > 1)
                          SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final double t = ((constraints.scrollOffset -
                                          constraints.precedingScrollExtent) /
                                      _kInsetRampDistance)
                                  .clamp(0.0, 1.0);
                              return SliverPersistentHeader(
                                pinned: true,
                                delegate: _PinnedTabsDelegate(
                                  inset: _miniHeight * t,
                                  child: _buildTabs(groups),
                                ),
                              );
                            },
                          ),
                        // Every group is built up front, not lazily: a tab
                        // can only scroll to a group that has been laid out,
                        // and a specialty store holds a handful of them.
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              for (int i = 0; i < groups.length; i++)
                                KeyedSubtree(
                                  key: _groupKeys[i],
                                  child: _buildGroup(
                                    storeController,
                                    groups[i],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // ─── NOTE CARD ───
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

                  // ─── STATUS-BAR SCRIM ───
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
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _mini,
                      builder:
                          (context, visible, _) => StoreMiniHeader(
                            key: _miniKey,
                            store: store,
                            visible: visible,
                          ),
                    ),
                  ),

                  // ─── CART BAR ───
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

  // ── Sections ──────────────────────────────────────────────────────────

  Widget _buildBuyAgain() {
    return GetBuilder<StorePageController>(
      tag: _page.tag,
      id: StorePageController.buyAgainId,
      builder: (storeController) {
        final buyAgain = storeController.buyAgain;
        if (buyAgain == null || buyAgain.lines.isEmpty) {
          return const SizedBox.shrink();
        }
        final int orders = buyAgain.orderCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreSectionHeader(
              title: 'buy_again'.tr,
              subtitle:
                  orders > 1
                      ? 'from_your_last_n_orders_here'.trParams({
                        'n': '$orders',
                      })
                      : 'from_your_last_order_here'.tr,
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 12),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
              child: Row(
                children: [
                  for (int i = 0; i < buyAgain.lines.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    _buyAgainRow(buyAgain.lines[i]),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// One Buy again row: "Tomatoes · 2 kg · For salad", whose "+" puts that
  /// same line in the cart again. When last time no longer resolves — the
  /// weight is gone, or the answer wasn't recorded — "+" opens the sheet.
  Widget _buyAgainRow(BuyAgainLine line) {
    final Item item = line.item;
    final Variation? variation =
        line.variationType == null
            ? null
            : (item.variations ?? const <Variation>[]).firstWhereOrNull(
              (v) => v.type == line.variationType,
            );
    final bool asks = ProducePreference.asks(item.prepOption);
    final String? answer =
        asks ? ProducePreference.label(line.preference) : null;
    final bool repeatable =
        ((item.variations?.isEmpty ?? true) || variation != null) &&
        (!asks || answer != null);
    final String spec = [
      if (variation?.type != null) variation!.type!.replaceAll('-', ' · '),
      if (answer != null) answer,
    ].join(' · ');

    return StoreCompactRow(
      key: ValueKey<int?>(item.id),
      item: item,
      spec: spec.isEmpty ? null : spec,
      onOpen: () => MartProductScreen.open(item),
      onAdd:
          repeatable
              ? () async {
                if (await Get.find<CartController>().blockedOutOfZone()) {
                  return;
                }
                Get.find<ItemController>().addLineToCart(
                  item,
                  variation: variation,
                  preference: asks ? line.preference : null,
                );
              }
              : () => MartProductScreen.open(item),
    );
  }

  /// A titled rail of photo cards — Most ordered, Deals.
  Widget _cardSection({
    required String title,
    required String subtitle,
    required List<Item> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StoreSectionHeader(title: title, subtitle: subtitle),
        // A Row, not a fixed-height ListView: the cards size to their text
        // at the viewer's text scale, and a rail holds at most a dozen.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  StoreProductCard(
                    key: ValueKey<int?>(items[i].id),
                    item: items[i],
                    fit: BoxFit.cover,
                    perUnit: true,
                    onOpen: () => MartProductScreen.open(items[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(List<CategoryModel> groups) {
    return ValueListenableBuilder<int>(
      valueListenable: _activeGroup,
      builder: (context, active, _) {
        return ListView(
          controller: _tabsScroll,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            for (int i = 0; i < groups.length; i++) ...[
              if (i > 0) const SizedBox(width: Dimensions.paddingSizeSmall),
              KeyedSubtree(
                key: _tabKeys[i],
                child: _CounterTab(
                  label: groups[i].name ?? '',
                  selected: i == active,
                  onTap: () => _jumpTo(i),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// One category's rows: label and count, up to a page of rows, and a
  /// "See all" when the category holds more than that.
  Widget _buildGroup(StorePageController storeController, CategoryModel c) {
    final int? total = c.itemsCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: _rail(
        'category_${c.id}',
        categoryId: c.id ?? 0,
        placeholder: const _GroupPlaceholder(),
        builder: (items) {
          final int count = total ?? items.length;
          final bool more = total != null && total > items.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        c.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyBold.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: displayTracking(-0.3),
                          color: WaddyColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeMedium),
                    Text(
                      itemCountLabel(count),
                      style: waddyRegular.copyWith(
                        fontSize: 12,
                        color: WaddyColors.inkLight,
                      ),
                    ),
                  ],
                ),
              ),
              for (final Item item in items) ...[
                const SizedBox(height: 10),
                StoreMenuRow(
                  key: ValueKey<int?>(item.id),
                  item: item,
                  onOpen: () => MartProductScreen.open(item),
                ),
              ],
              if (more && c.id != 0)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Pressable(
                    onTap: () => _openCategory(storeController, c),
                    semanticLabel: 'store_see_all_n'.trParams({'n': '$total'}),
                    scale: WaddyMotion.pressControl,
                    minSize: Dimensions.minTapTarget,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'store_see_all_n'.trParams({'n': '$total'}),
                        style: waddyBold.copyWith(
                          fontSize: 13,
                          color: WaddyColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Checkout takes an order note; this says so where the question comes
  /// up — when what you want isn't quite on the counter.
  Widget _buildNoteCard(Store store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(color: WaddyColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: WaddyColors.primarySurface,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: WaddyColors.primary,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'need_something_specific'.tr,
                    style: waddyBold.copyWith(
                      fontSize: 14,
                      color: WaddyColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'leave_note_at_checkout'.trParams({
                      'store': store.name ?? '',
                    }),
                    style: waddyRegular.copyWith(
                      fontSize: 12,
                      color: WaddyColors.inkLight,
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

// ═══════════════════════════════════════════════════════════════
// PINNED TABS
// ═══════════════════════════════════════════════════════════════

/// The category strip, pinned. [inset] grows it from the top while it is
/// pinned so it rests under the mini header instead of beneath it.
class _PinnedTabsDelegate extends SliverPersistentHeaderDelegate {
  final double inset;
  final Widget child;

  const _PinnedTabsDelegate({required this.inset, required this.child});

  @override
  double get minExtent => _kTabBarHeight + inset;

  @override
  double get maxExtent => _kTabBarHeight + inset;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Column(
      children: [
        SizedBox(height: inset),
        Container(
          height: _kTabBarHeight,
          decoration: BoxDecoration(
            color: WaddyColors.canvas,
            border:
                overlaps || shrinkOffset > 0
                    ? const Border(
                      bottom: BorderSide(color: WaddyColors.divider),
                    )
                    : null,
          ),
          child: child,
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_PinnedTabsDelegate old) =>
      old.inset != inset || old.child != child;
}

class _CounterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CounterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      onTap: onTap,
      child: AnimatedContainer(
        duration: WaddyMotion.fast,
        curve: WaddyMotion.easeOut,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? WaddyColors.primary : WaddyColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? WaddyColors.primary : WaddyColors.divider,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: waddyBold.copyWith(
            fontSize: 13,
            color: selected ? Colors.white : WaddyColors.primary,
          ),
        ),
      ),
    );
  }
}

/// A group's header and three row-sized blocks while its rows load.
class _GroupPlaceholder extends StatelessWidget {
  const _GroupPlaceholder();

  @override
  Widget build(BuildContext context) {
    Widget block(double? width, double height, double radius) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: block(120, 18, Dimensions.radiusExtraSmall),
          ),
          for (int i = 0; i < 3; i++) ...[
            const SizedBox(height: 10),
            block(double.infinity, 102, Dimensions.radiusLarge),
          ],
        ],
      ),
    );
  }
}
