import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/search/widgets/mint_category_grid.dart';
import 'package:waddy_app/features/search/widgets/mint_search_header.dart';
import 'package:waddy_app/features/store/widgets/store_search_result_row.dart';
import 'package:waddy_app/features/store/controllers/store_page_controller.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/util/app_design_tokens.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/paginated_list_view.dart';
import 'package:waddy_app/common/widgets/veg_filter_widget.dart';
import 'package:waddy_app/features/cart/widgets/pill_cart_bar.dart';

/// Search inside one store, following the "Mart Search" design.
///
/// Two openings, by store type:
/// - **Supermarket**: an idle surface — what you searched before, the store's
///   recommended items, its categories. A supermarket's range is too wide to
///   list, so the screen helps you start a search.
/// - **Any other store** (a butcher, a restaurant, a pet shop): the store's
///   products, listed straight away. The range is small enough to scan, so
///   typing narrows a list that is already there.
///
/// Either way the field filters live as you type, and results are the same
/// rows. Before this, an empty search said "No item available" — a verdict on
/// a search nobody had run.
class StoreItemSearchScreen extends StatefulWidget {
  final String? storeID;
  const StoreItemSearchScreen({super.key, required this.storeID});

  @override
  State<StoreItemSearchScreen> createState() => _StoreItemSearchScreenState();
}

class _StoreItemSearchScreenState extends State<StoreItemSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Recent terms for this app session. Kept in memory: a store-scoped search
  /// is a shortcut, not a history worth persisting across launches.
  static final List<String> _recent = <String>[];
  static const int _maxRecent = 5;

  /// How long the field must sit still before a keystroke becomes a request.
  static const Duration _debounce = Duration(milliseconds: 350);
  Timer? _debounceTimer;

  static const Color _ink = Color(0xFF1A1F1E);
  static const Color _inkMuted = Color(0xFF6B7876);

  /// The store page this search runs inside. Search is pushed from a store
  /// page (or its aisle page) through a named route, so that page is the one
  /// on top. A direct link with no store page open gets its own, closed with
  /// this screen.
  late final StorePageController _page;
  bool _ownsPage = false;

  /// True for every store that is not a supermarket: the screen lists the
  /// store's products instead of recents and categories. Decided once, from
  /// the store the page already holds; a store the page does not know yet
  /// (a direct link) gets the supermarket opening.
  late final bool _browseDirectly;

  @override
  void initState() {
    super.initState();
    final StorePageController? parent = StorePageController.top;
    if (parent != null) {
      _page = parent;
    } else {
      _page = StorePageController.open();
      _ownsPage = true;
    }
    _page.initSearchData();
    final store = _page.store;
    _browseDirectly =
        store != null &&
        (StoreLayout.of(store) ?? StoreLayout.fallback(store)) !=
            StoreLayout.aisles;
    if (_browseDirectly) {
      _page.getSearchBrowseItems(int.tryParse(widget.storeID ?? ''), 1);
    }
    // The idle surface offers the store's recommended items; most store pages
    // have fetched them already, a direct link has not.
    if (_page.recommendedItemModel == null) {
      _page.getRestaurantRecommendedItemList(
        int.tryParse(widget.storeID ?? ''),
        false,
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _remember(_searchController.text);
    if (_ownsPage) _page.close();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _remember(String term) {
    final String t = term.trim();
    if (t.isEmpty) return;
    _recent.remove(t);
    _recent.insert(0, t);
    if (_recent.length > _maxRecent) _recent.removeLast();
  }

  void _search(String text) {
    _page.getStoreSearchItemList(
      text.trim(),
      widget.storeID,
      1,
      _page.searchType,
    );
  }

  void _onChanged(String text) {
    _debounceTimer?.cancel();
    if (text.trim().isEmpty) {
      _resetToIdle();
      return;
    }
    _debounceTimer = Timer(_debounce, () => _search(text));
  }

  void _onSubmitted(String text) {
    _debounceTimer?.cancel();
    if (text.trim().isEmpty) return;
    _remember(text);
    _search(text);
  }

  /// Runs a term the user picked rather than typed.
  void _runTerm(String term) {
    FocusManager.instance.primaryFocus?.unfocus();
    _debounceTimer?.cancel();
    _searchController.text = term;
    _remember(term);
    _search(term);
  }

  void _resetToIdle() {
    _page.initSearchData();
    _page.update();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StorePageController>(
      tag: _page.tag,
      builder: (storeController) {
        final bool isIdle = storeController.searchText.isEmpty;
        return Scaffold(
          backgroundColor: Theme.of(context).cardColor,
          body: Column(
            children: [
              MintSearchHeader(
                controller: _searchController,
                hint: 'search_item_in_store'.tr,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: _onSubmitted,
                onClear: () {
                  _debounceTimer?.cancel();
                  _searchController.clear();
                  _resetToIdle();
                },
                trailing: VegFilterWidget(
                  type: isIdle ? null : storeController.searchType,
                  onSelected: (String type) {
                    storeController.getStoreSearchItemList(
                      storeController.searchText,
                      widget.storeID,
                      1,
                      type,
                    );
                  },
                  fromAppBar: true,
                ),
              ),

              Expanded(
                child:
                    !isIdle
                        ? _buildResults(context, storeController)
                        : _browseDirectly
                        ? _buildBrowse(context, storeController)
                        : _buildIdle(context, storeController),
              ),
            ],
          ),

          // The one cart surface on grocery store screens. Draws nothing
          // while the cart is empty.
          bottomNavigationBar: PillCartBar(store: storeController.store),
        );
      },
    );
  }

  Widget _buildResults(
    BuildContext context,
    StorePageController storeController,
  ) {
    final model = storeController.storeSearchItemModel;
    final int? total = model?.totalSize ?? model?.items?.length;
    return _itemList(
      model: model,
      countLabel:
          total == null
              ? null
              : '$total ${'results_for'.tr} “${storeController.searchText}”',
      onPaginate:
          (int? offset) => storeController.getStoreSearchItemList(
            storeController.searchText,
            widget.storeID,
            offset!,
            storeController.searchType,
          ),
    );
  }

  /// A non-supermarket's products, before anything is typed.
  Widget _buildBrowse(
    BuildContext context,
    StorePageController storeController,
  ) {
    return _itemList(
      model: storeController.searchBrowseModel,
      onPaginate:
          (int? offset) => storeController.getSearchBrowseItems(
            int.tryParse(widget.storeID ?? ''),
            offset!,
          ),
    );
  }

  Widget _itemList({
    required ItemModel? model,
    required Function(int? offset) onPaginate,
    String? countLabel,
  }) {
    return SingleChildScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeSmall,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeSmall,
      ),
      child: FooterView(
        child: SizedBox(
          width: Dimensions.maxContentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Muted, one line: the results carry the weight, not the count.
              if (countLabel != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimensions.paddingSizeSmall,
                    horizontal: Dimensions.paddingSizeExtraSmall,
                  ),
                  child: Text(
                    countLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: _inkMuted,
                    ),
                  ),
                )
              else
                const SizedBox(height: Dimensions.paddingSizeSmall),

              PaginatedListView(
                scrollController: _scrollController,
                onPaginate: onPaginate,
                totalSize: model?.totalSize,
                offset: model?.offset,
                itemView: _ResultList(items: model?.items),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Recents, the store's recommended items, then its categories. Tapping a
  /// category runs its name as the search term.
  Widget _buildIdle(BuildContext context, StorePageController storeController) {
    final List<CategoryModel> categories =
        (storeController.categoryList ?? const <CategoryModel>[])
            .where((c) => (c.id ?? 0) != 0 && (c.name ?? '').isNotEmpty)
            .take(6)
            .toList();

    final List<Item> recommended =
        (storeController.recommendedItemModel?.items ?? const <Item>[])
            .take(4)
            .toList();

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        Dimensions.paddingSizeLarge,
        Dimensions.paddingSizeLarge,
        Dimensions.paddingSizeLarge,
        Dimensions.paddingSizeExtraLarge + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (_recent.isNotEmpty) ...[
          _header(
            'recent_searches'.tr,
            actionLabel: 'clear_all'.tr,
            onAction: () => setState(_recent.clear),
          ),
          ..._recent.map(
            (term) => Pressable(
              scale: 0.99,
              alignment: AlignmentDirectional.centerStart,
              onTap: () => _runTerm(term),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.clock,
                      color: _inkMuted,
                      size: 18,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeMedium),
                    Expanded(
                      child: Text(
                        term,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraLarge + 2),
        ],

        if (recommended.isNotEmpty) ...[
          _header('recommended_for_you'.tr),
          for (final Item item in recommended) ...[
            StoreSearchResultRow(item: item),
            const SizedBox(height: Dimensions.paddingSizeSmall + 2),
          ],
          const SizedBox(height: Dimensions.paddingSizeMedium),
        ],

        if (categories.isNotEmpty) ...[
          _header('browse_categories'.tr),
          MintCategoryGrid(
            tiles:
                categories
                    .map(
                      (category) => MintCategoryTile(
                        name: category.name!,
                        imageUrl: category.imageFullUrl ?? '',
                        onTap: () => _runTerm(category.name!),
                      ),
                    )
                    .toList(),
          ),
        ],
      ],
    );
  }

  Widget _header(String title, {String? actionLabel, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeMedium - 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeDefault + 2,
                color: _ink,
              ),
            ),
          ),
          if (actionLabel != null)
            Pressable(
              minSize: Dimensions.minTapTarget,
              scale: 0.95,
              onTap: onAction,
              child: Text(
                actionLabel,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: AppDesignTokens.primaryDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The result rows, with the two states the rows cannot draw themselves: a
/// skeleton while the first page is in flight and "Nothing found" for none.
class _ResultList extends StatelessWidget {
  final List<Item?>? items;
  const _ResultList({required this.items});

  @override
  Widget build(BuildContext context) {
    final List<Item?>? list = items;
    if (list == null) {
      return Column(
        children: List.generate(
          5,
          (_) => Container(
            height: 104,
            margin: const EdgeInsets.only(
              bottom: Dimensions.paddingSizeSmall + 2,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF1FBF7),
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            ),
          ),
        ),
      );
    }
    if (list.isEmpty) {
      // The design's plain two lines, not the shared map illustration: that one
      // is sized to a third of the screen and reads as an error, for a search
      // that simply found nothing.
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeExtraOverLarge,
          vertical: 60,
        ),
        child: Column(
          children: [
            Text(
              'nothing_found'.tr,
              textAlign: TextAlign.center,
              style: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeDefault + 2,
                color: const Color(0xFF1A1F1E),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall - 2),
            Text(
              'try_another_word_or_browse'.tr,
              textAlign: TextAlign.center,
              style: waddyRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall - 1,
                color: const Color(0xFF6B7876),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final Item? item in list)
          if (item != null) ...[
            StoreSearchResultRow(item: item),
            const SizedBox(height: Dimensions.paddingSizeSmall + 2),
          ],
      ],
    );
  }
}
