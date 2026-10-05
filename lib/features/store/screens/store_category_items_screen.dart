import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/controllers/store_page_controller.dart';
import 'package:waddy_app/features/cart/widgets/pill_cart_bar.dart';
import 'package:waddy_app/features/store/widgets/filter_widget.dart';
import 'package:waddy_app/features/store/widgets/shop_product_tile.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// One category of a store, as a grid of products with the category's
/// sub-categories as text chips on top.
///
/// The category is pre-selected via `setCategoryIndex` on the store page's
/// controller before navigating here; that call also starts the first page of
/// items. This page is a view of that same visit, so it is handed the parent
/// page's [StorePageController] rather than owning one.
class StoreCategoryItemsScreen extends StatefulWidget {
  final StorePageController page;
  final int? storeId;
  final String categoryName;

  /// Opens on this sub-category's chip instead of "All" — the pets store's
  /// need tiles ("Food" under Cats) land straight on their shelf.
  final int? initialSubCategoryId;

  const StoreCategoryItemsScreen({
    super.key,
    required this.page,
    required this.storeId,
    required this.categoryName,
    this.initialSubCategoryId,
  });

  @override
  State<StoreCategoryItemsScreen> createState() =>
      _StoreCategoryItemsScreenState();
}

class _StoreCategoryItemsScreenState extends State<StoreCategoryItemsScreen> {
  final ScrollController _scrollController = ScrollController();

  /// The main category this page was opened for. Read once: the chips change
  /// which items load, never which category the page is about.
  late final int? _categoryId;

  /// Page requested and not yet landed — the scroll listener fires many times
  /// per frame near the end, and each one would otherwise request the page.
  bool _loadingMore = false;

  /// Cards per row. Three fits a phone the way the reference grocery apps do:
  /// a product is recognisable by its photo and price alone.
  static const int _kColumns = 3;

  @override
  void initState() {
    super.initState();
    final StorePageController controller = widget.page;
    _categoryId =
        controller.categoryList != null &&
                controller.categoryIndex < controller.categoryList!.length
            ? controller.categoryList![controller.categoryIndex].id
            : null;
    controller.loadSubCategories(_categoryId);
    final int? sub = widget.initialSubCategoryId;
    if (sub != null) {
      // Post-frame: selecting notifies, and a notify mid-build throws.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.selectSubCategory(sub, _categoryId);
      });
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_scrollController.hasClients) return;
    final ScrollPosition p = _scrollController.position;
    if (p.pixels < p.maxScrollExtent - 400) return;

    final StorePageController c = widget.page;
    final model = c.storeItemModel;
    if (model == null || model.items == null || model.totalSize == null) return;
    if (model.items!.length >= model.totalSize!) return;

    _loadingMore = true;
    c
        .getStoreItemList(
          widget.storeId,
          (model.offset ?? 1) + 1,
          c.type,
          false,
        )
        .whenComplete(() => _loadingMore = false);
  }

  void _openFilter(StorePageController storeController) {
    final double maxPrice = (storeController.storeItemModel?.items ?? [])
        .fold<double>(
          0,
          (prev, item) => (item.price ?? 0) > prev ? item.price! : prev,
        );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => FilterWidget(
            page: widget.page,
            maxValue: maxPrice > 0 ? maxPrice : 1000,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StorePageController>(
      tag: widget.page.tag,
      builder: (storeController) {
        final List<Item>? items = storeController.storeItemModel?.items;
        final List<CategoryModel> subs =
            storeController.subCategoriesOf(_categoryId) ?? const [];

        return Scaffold(
          backgroundColor: WaddyColors.surface,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            // Mint is a light surface: dark status-bar icons over it.
            value: HomeHeroBannerWidget.overlayStyle,
            child: Column(
              children: [
                // The module hero's mint block, behind the status bar — the
                // same fill the grocery home and the store page open with.
                Container(
                  decoration: BoxDecoration(
                    gradient: HomeHeroBannerWidget.heroGradient,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        _Header(
                          title: widget.categoryName,
                          onSearch:
                              () => Get.toNamed(
                                RouteHelper.getSearchStoreItemRoute(
                                  widget.storeId,
                                ),
                              ),
                          onFilter: () => _openFilter(storeController),
                        ),
                        if (subs.isNotEmpty)
                          _SubCategoryChips(
                            subs: subs,
                            selectedId: storeController.subCategoryId,
                            allLabel: 'all'.tr,
                            onSelect:
                                (id) => storeController.selectSubCategory(
                                  id,
                                  _categoryId,
                                ),
                          ),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _buildGrid(items, storeController)),
              ],
            ),
          ),
          // The one cart surface on grocery store screens. Draws nothing
          // while the cart is empty.
          bottomNavigationBar: PillCartBar(store: storeController.store),
        );
      },
    );
  }

  Widget _buildGrid(List<Item>? items, StorePageController storeController) {
    // Null is "first page in flight"; the controller lands a failed first page
    // as an empty list, so this never shimmers with nothing outstanding.
    if (items == null) return const _GridShimmer(columns: _kColumns);
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
          child: Text(
            'no_item_available'.tr,
            textAlign: TextAlign.center,
            style: waddyMedium.copyWith(
              fontSize: 15,
              color: WaddyColors.inkLight,
            ),
          ),
        ),
      );
    }

    final bool hasMore =
        items.length < (storeController.storeItemModel?.totalSize ?? 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        const double gap = Dimensions.paddingSizeSmall;
        const double side = Dimensions.paddingSizeDefault;
        final double cardWidth =
            (constraints.maxWidth - side * 2 - gap * (_kColumns - 1)) /
            _kColumns;
        final double extent = ShopProductTile.heightFor(context, cardWidth);

        return CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(side, 8, side, 0),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _kColumns,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: Dimensions.paddingSizeMedium,
                  mainAxisExtent: extent,
                ),
                itemCount: items.length,
                itemBuilder:
                    (context, index) => ShopProductTile(item: items[index]),
              ),
            ),
            if (hasMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 56)),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onSearch;
  final VoidCallback onFilter;

  const _Header({
    required this.title,
    required this.onSearch,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeSmall,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeSmall,
      ),
      child: Row(
        children: [
          _RoundButton(
            icon: Icons.arrow_back_rounded,
            semanticLabel: 'back'.tr,
            onTap: () => Get.back(),
          ),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: waddyBold.copyWith(
                fontSize: 20,
                color: WaddyColors.ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          _RoundButton(
            icon: Icons.search_rounded,
            semanticLabel: 'search'.tr,
            onTap: onSearch,
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          _RoundButton(
            icon: Icons.tune_rounded,
            semanticLabel: 'filter'.tr,
            onTap: onFilter,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      semanticLabel: semanticLabel,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: WaddyColors.divider),
          boxShadow: [
            BoxShadow(
              color: WaddyColors.primary.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: WaddyColors.primary),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SUB-CATEGORY CHIPS — text only
// ═══════════════════════════════════════════════════════════════

/// A sideways row of text pills: "All" first, then each sub-category the
/// store stocks under this category. No images — the sub-category names are
/// the whole control, and the photos belong to the products below.
class _SubCategoryChips extends StatelessWidget {
  final List<CategoryModel> subs;
  final int selectedId;
  final String allLabel;
  final ValueChanged<int> onSelect;

  const _SubCategoryChips({
    required this.subs,
    required this.selectedId,
    required this.allLabel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final List<({int id, String label})> chips = [
      (id: 0, label: allLabel),
      for (final c in subs) (id: c.id ?? 0, label: c.name ?? ''),
    ];

    return SizedBox(
      // Tall enough for the pill at the viewer's text scale; the pill's own
      // height follows its text, this just keeps the row from clipping it.
      height:
          34 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4) +
          Dimensions.paddingSizeMedium,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
        ),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final bool selected = chip.id == selectedId;
          return Center(
            child: PressableScale(
              semanticLabel:
                  selected ? '${chip.label}, ${'selected'.tr}' : chip.label,
              onTap: () => onSelect(chip.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                height: 34,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  // White when idle: the row sits on the mint hero, where
                  // the grey raised surface read as a smudge.
                  color:
                      selected
                          ? Theme.of(context).primaryColor
                          : WaddyColors.surface,
                  borderRadius: BorderRadius.circular(30),
                  border:
                      selected ? null : Border.all(color: WaddyColors.divider),
                ),
                child: Text(
                  chip.label,
                  style: waddyMedium.copyWith(
                    fontSize: 13.5,
                    color: selected ? Colors.white : WaddyColors.ink,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LOADING
// ═══════════════════════════════════════════════════════════════

/// Card-shaped blocks while the first page loads, at the card's own
/// geometry so the real grid lands where the placeholder was.
class _GridShimmer extends StatelessWidget {
  final int columns;

  const _GridShimmer({required this.columns});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double gap = Dimensions.paddingSizeSmall;
        const double side = Dimensions.paddingSizeDefault;
        final double width =
            (constraints.maxWidth - side * 2 - gap * (columns - 1)) / columns;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(side, 8, side, 0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: gap,
            mainAxisSpacing: Dimensions.paddingSizeMedium,
            mainAxisExtent: ShopProductTile.heightFor(context, width),
          ),
          itemCount: columns * 4,
          itemBuilder: (context, _) => ShopProductTilePlaceholder(width: width),
        );
      },
    );
  }
}
