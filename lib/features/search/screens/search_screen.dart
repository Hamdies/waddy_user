import 'package:flutter/cupertino.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/util/app_design_tokens.dart';
import 'package:waddy_app/features/cuisine/controllers/cuisine_controller.dart';
import 'package:waddy_app/features/search/controllers/search_controller.dart'
    as search;
import 'package:waddy_app/features/search/domain/models/global_search_model.dart';
import 'package:waddy_app/features/search/domain/models/popular_categories_model.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/search/widgets/global_search_results.dart';
import 'package:waddy_app/features/search/widgets/mint_category_grid.dart';
import 'package:waddy_app/features/search/widgets/mint_search_header.dart';
import 'package:waddy_app/features/search/widgets/search_result_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Search — the screen you land on with an empty query and a keyboard already up.
///
/// Follows the "Mart Search" design: a mint header carrying a round back
/// button and a white teal-outlined pill, then an idle surface in three tiers —
/// what you searched before, trending terms as chips, and a three-up category
/// grid. `popularCategoryList` was already being fetched in `initState` and
/// thrown away; the grid is what that call was for.
///
/// Opened from the module-less Home dashboard it becomes the global search
/// ("Mart Global Search"): live as you type, across restaurants, groceries and
/// shops at once, results grouped by store — see [GlobalSearchResults]. The
/// module-scoped endpoints 403 without a module, so that mode never calls them.
///
/// Inside a module, results are still [SearchResultWidget]: it owns the item/store tabs and the
/// filter sheet, which the design's single-list results state does not cover.
class SearchScreen extends StatefulWidget {
  final String? queryText;
  final bool fromHome;
  const SearchScreen({
    super.key,
    required this.queryText,
    this.fromHome = false,
  });

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late bool _isLoggedIn;

  /// Latched at open. Tapping a result switches module underneath this screen,
  /// so asking again on return would flip a global search into a module one.
  late final bool _isGlobal;

  /// The Restaurants home's search ("Mart Restaurant Search"): the same live,
  /// store-by-store search as [_isGlobal], scoped by the module header to
  /// restaurants and without the kind tabs. Latched for the same reason.
  late final bool _isRestaurant;

  /// Both modes search live through `/search/global` rather than the
  /// module's item / store endpoints.
  late final bool _isGroceryLive;

  bool get _live => _isGlobal || _isRestaurant || _isGroceryLive;

  SearchScope get _scope =>
      _isRestaurant
          ? SearchScope.restaurants
          : _isGroceryLive
          ? SearchScope.groceries
          : SearchScope.all;

  List<String> _suggestions = <String>[];
  bool _showSuggestion = false;

  /// How many recents fit before the surface stops being a shortcut and starts
  /// being a log. Five is the point at which the grid below falls off-screen.
  static const int _maxRecent = 5;

  static const Color _primaryColor = AppDesignTokens.primaryDark;
  static const Color _mintFill = Color(0xFFE6F4F3);
  static const Color _mintBorder = Color(0xFFB9ECDD);
  static const Color _fieldFill = Color(0xFFF1F4F3);
  static const Color _ink = Color(0xFF1A1F1E);
  static const Color _inkMuted = Color(0xFF6B7876);
  static const Color _inkFaint = Color(0xFF9EAAA8);

  /// Sub-section title size — one step above body, not on the type scale.
  static double get _titleSize => Dimensions.fontSizeDefault + 2;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = AuthHelper.isLoggedIn();
    final ModuleModel? module = Get.find<SplashController>().module;
    _isGlobal = module == null;
    _isRestaurant = module?.type == ModuleType.food;
    _isGroceryLive = module?.type == ModuleType.grocery;
    Get.find<search.SearchController>().setSearchMode(true, canUpdate: false);
    // Both are module-scoped endpoints: without a module they only 403, and
    // the live modes have no use for them. Restaurants show cuisines instead.
    if (_isRestaurant) {
      Get.find<CuisineController>().getCuisineList(false);
    }
    if (!_live) {
      Get.find<search.SearchController>().getPopularCategories();
    }
    // The grocery idle surface keeps its "Popular searches" chips.
    if (!_live || _isGroceryLive) {
      if (_isLoggedIn) {
        Get.find<search.SearchController>().getSuggestedItems();
      }
    }
    Get.find<search.SearchController>().getHistoryList();
    if (widget.queryText!.isNotEmpty) {
      _actionSearch(true, widget.queryText, true);
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchSuggestions(String query) async {
    if (query.isEmpty) {
      _showSuggestion = false;
      _suggestions = [];
    } else {
      _showSuggestion = true;
      _suggestions = await Get.find<search.SearchController>()
          .getSearchSuggestions(query);
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Runs a term the user picked rather than typed — a recent, a trending row,
  /// a suggestion. Puts it in the field first so the field never disagrees with
  /// the results below it.
  void _runTerm(String term) {
    _searchFocusNode.unfocus();
    _searchController.text = term;
    _showSuggestion = false;
    Get.find<search.SearchController>().setSearchText(term);
    _actionSearch(true, term, false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (Get.find<search.SearchController>().isSearchMode) {
          return;
        } else {
          Get.find<search.SearchController>().setSearchMode(true);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        body: GetBuilder<search.SearchController>(
          builder: (searchController) {
            _searchController.text = searchController.searchText!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(context, searchController),

                Expanded(
                  child: SafeArea(
                    top: false,
                    child:
                        searchController.isSearchMode
                            ? _showSuggestion
                                ? _buildSuggestionsList(context, _suggestions)
                                : _buildBrowseContent(context, searchController)
                            : _live
                            ? GlobalSearchResults(
                              scope: _scope,
                              controller: searchController,
                              query: _searchController.text.trim(),
                              onRetry:
                                  () => searchController.searchGlobal(
                                    _searchController.text,
                                    immediate: true,
                                  ),
                            )
                            // Food, grocery and the dashboard search live; the
                            // other modules keep the item / store tabs and the
                            // filter sheet.
                            : SearchResultWidget(
                              searchText: _searchController.text.trim(),
                              tabController: null,
                            ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    search.SearchController searchController,
  ) {
    final moduleType =
        Get.find<SplashController>().module?.type ?? ModuleType.unknown;

    return MintSearchHeader(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: widget.queryText!.isEmpty,
      hint:
          _isRestaurant
              ? 'gs_restaurant_search_hint'.tr
              : _isGroceryLive
              ? 'gs_grocery_search_hint'.tr
              : _isGlobal
              ? 'gs_search_hint'.tr
              : moduleType == ModuleType.grocery
              ? 'search_groceries_snacks'.tr
              : 'search_restaurants_cuisines'.tr,
      onChanged: (text) {
        // Live search: the results are the suggestions.
        if (_live) {
          searchController.searchGlobal(text);
          return;
        }
        searchController.setSearchText(text);
        _searchSuggestions(text);
      },
      onSubmitted:
          (text) => _actionSearch(true, _searchController.text.trim(), false),
      onClear: () {
        _searchController.clear();
        _showSuggestion = false;
        _suggestions = [];
        searchController.setSearchMode(true);
        searchController.clearSearchHomeText();
        _searchFocusNode.requestFocus();
        setState(() {});
      },
    );
  }

  /// The idle surface: recents, trending chips, the category grid.
  Widget _buildBrowseContent(
    BuildContext context,
    search.SearchController searchController,
  ) {
    final categories = searchController.popularCategoryList;
    final trending = searchController.suggestedItemList;
    final List<ModuleModel> modules = _isGlobal ? _shoppingModules() : const [];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        Dimensions.paddingSizeLarge,
        0,
        Dimensions.paddingSizeExtraLarge + MediaQuery.paddingOf(context).bottom,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (searchController.historyList.isNotEmpty) ...[
          _hPad(
            Column(
              children: [
                _SectionHeader(
                  title: 'recent_searches'.tr,
                  actionLabel: 'clear_all'.tr,
                  onAction: searchController.clearSearchHistory,
                ),
                _buildRecentList(searchController),
              ],
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraLarge + 2),
        ],

        if (_isRestaurant) ...[
          _hPad(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'gs_popular_cuisines'.tr),
                _buildCuisineChips(),
              ],
            ),
          ),
        ] else if (trending != null && trending.isNotEmpty) ...[
          _hPad(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title:
                      _isGroceryLive
                          ? 'gs_popular_searches'.tr
                          : 'trending_now'.tr,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(
                    spacing: Dimensions.paddingSizeSmall,
                    runSpacing: Dimensions.paddingSizeSmall,
                    children:
                        trending
                            .map((item) => item.name ?? '')
                            .where((name) => name.isNotEmpty)
                            .take(7)
                            .map(
                              (name) => _TrendingChip(
                                label: name,
                                onTap: () => _runTerm(name),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraLarge + 2),
        ],

        if (_isRestaurant || _isGroceryLive)
          const SizedBox.shrink()
        else if (_isGlobal && modules.isNotEmpty)
          _hPad(
            Column(
              children: [
                _SectionHeader(title: 'browse'.tr),
                _buildModuleGrid(modules),
              ],
            ),
          )
        else if (!_live && (categories == null || categories.isNotEmpty))
          _hPad(
            Column(
              children: [
                _SectionHeader(title: 'browse_categories'.tr),
                _buildCategoryGrid(context, categories),
              ],
            ),
          ),
      ],
    );
  }

  Widget _hPad(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: Dimensions.paddingSizeLarge,
    ),
    child: child,
  );

  Widget _buildRecentList(search.SearchController searchController) {
    final items = searchController.historyList.take(_maxRecent).toList();
    return Column(
      children:
          items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Pressable(
              scale: 0.99,
              alignment: AlignmentDirectional.centerStart,
              onTap: () => _runTerm(item),
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
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: _ink,
                        ),
                      ),
                    ),

                    // Removing one recent stays available beside "Clear all": the
                    // header action is all-or-nothing, and one stale term should
                    // not cost the other four.
                    Pressable(
                      minSize: Dimensions.minTapTarget,
                      scale: 0.9,
                      onTap: () => searchController.removeHistory(index),
                      child: const Icon(
                        Icons.close,
                        color: _inkFaint,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  /// Cuisine names as mint chips; a tap runs the search. Fed by the same list
  /// the Restaurants home strip reads, so it is usually already loaded.
  Widget _buildCuisineChips() {
    return GetBuilder<CuisineController>(
      builder: (cuisines) {
        final names = (cuisines.cuisineList ?? const [])
            .map((c) => c.name ?? '')
            .where((n) => n.isNotEmpty)
            .take(8);
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: Dimensions.paddingSizeSmall,
            runSpacing: Dimensions.paddingSizeSmall,
            children:
                names
                    .map(
                      (name) => _TrendingChip(
                        label: name,
                        onTap: () => _runTerm(name),
                      ),
                    )
                    .toList(),
          ),
        );
      },
    );
  }

  /// The modules a shopper can search into — everything but parcel and the
  /// places guide, which have no products to match.
  List<ModuleModel> _shoppingModules() {
    return (Get.find<SplashController>().moduleList ?? const <ModuleModel>[])
        .where(
          (m) => m.type != ModuleType.parcel && m.type != ModuleType.places,
        )
        .toList();
  }

  /// The idle "Browse" of the global search: one tile per module, straight
  /// into it. Same tile as the category grid, so the surface does not change
  /// language between the two modes.
  Widget _buildModuleGrid(List<ModuleModel> modules) {
    return MintCategoryGrid(
      tiles:
          modules
              .take(6)
              .map(
                (module) => MintCategoryTile(
                  name: module.moduleName ?? '',
                  imageUrl: module.iconFullUrl ?? module.thumbnailFullUrl ?? '',
                  onTap: () {
                    Get.back();
                    Get.find<SplashController>().enterModule(module);
                  },
                ),
              )
              .toList(),
    );
  }

  /// Three-up category tiles — see [MintCategoryGrid].
  Widget _buildCategoryGrid(
    BuildContext context,
    List<PopularCategoryModel?>? categories,
  ) {
    final List<PopularCategoryModel?> items =
        categories == null
            ? List<PopularCategoryModel?>.filled(6, null)
            : categories.take(6).toList();
    return MintCategoryGrid(
      tiles:
          items
              .map(
                (category) =>
                    category == null
                        ? null
                        : MintCategoryTile(
                          name: category.name ?? '',
                          imageUrl: category.imageFullUrl ?? '',
                          onTap:
                              () => Get.toNamed(
                                RouteHelper.getCategoryItemRoute(
                                  category.id,
                                  category.name ?? '',
                                ),
                              ),
                        ),
              )
              .toList(),
    );
  }

  Widget _buildSuggestionsList(BuildContext context, List<String> suggestions) {
    if (suggestions.isEmpty) {
      return _EmptyState(
        title: '${'no_matches_for'.tr} "${_searchController.text.trim()}"',
        body: 'try_another_spot_or_cuisine'.tr,
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeSmall,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeExtraLarge + MediaQuery.paddingOf(context).bottom,
      ),
      itemBuilder: (context, index) {
        return Pressable(
          scale: 0.99,
          alignment: AlignmentDirectional.centerStart,
          onTap: () => _runTerm(suggestions[index]),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: Dimensions.paddingSizeMedium,
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.search, color: _inkFaint, size: 17),
                const SizedBox(width: Dimensions.paddingSizeMedium),

                Expanded(
                  child: Text(
                    suggestions[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: _ink,
                    ),
                  ),
                ),

                // Points up-and-out: tapping fills the field with this term
                // rather than navigating straight to a result.
                Transform.rotate(
                  angle: -0.785398,
                  child: const Icon(
                    Icons.arrow_forward,
                    color: _inkFaint,
                    size: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _actionSearch(bool isSubmit, String? queryText, bool fromHome) {
    if (_live) {
      final String q = queryText?.trim() ?? '';
      if (q.isEmpty) {
        showCustomSnackBar('gs_search_hint'.tr);
      } else {
        Get.find<search.SearchController>().searchGlobal(
          q,
          immediate: true,
          saveHistory: true,
        );
      }
      return;
    }
    if (Get.find<search.SearchController>().isSearchMode || isSubmit) {
      if (queryText!.isNotEmpty) {
        Get.find<search.SearchController>().searchData(queryText, fromHome);
      } else {
        showCustomSnackBar('search_item_or_store'.tr);
      }
    }
  }
}

/// A sentence-case section title with an optional trailing action.
///
/// The design drops the old uppercase eyebrow: with three tiers on one scroll
/// each needs to read as a heading in its own right, and 16sp bold ink does
/// that without the caps-and-tracking Arabic cannot use anyway.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
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
                fontSize: SearchScreenState._titleSize,
                color: SearchScreenState._ink,
              ),
            ),
          ),

          if (actionLabel != null)
            Pressable(
              minSize: Dimensions.minTapTarget,
              scale: 0.95,
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: SearchScreenState._primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A trending term as a mint pill — tap runs the search.
class _TrendingChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TrendingChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.96,
      minSize: Dimensions.minTapTarget,
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeMedium + 2,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: SearchScreenState._mintFill,
          border: Border.all(color: SearchScreenState._mintBorder),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: waddyMedium.copyWith(
            fontSize: Dimensions.fontSizeSmall - 1,
            color: SearchScreenState._primaryColor,
          ),
        ),
      ),
    );
  }
}

/// "No matches for X" — the query is echoed back so the user can see *what* was
/// searched, which is most of the diagnosis when the answer is a typo.
class _EmptyState extends StatelessWidget {
  final String title;
  final String body;

  const _EmptyState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeExtraOverLarge,
        70,
        Dimensions.paddingSizeExtraOverLarge,
        Dimensions.paddingSizeExtraLarge,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: SearchScreenState._fieldFill,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.search,
              color: SearchScreenState._inkFaint,
              size: 26,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Text(
            title,
            textAlign: TextAlign.center,
            style: waddyBold.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              color: SearchScreenState._ink,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          Text(
            body,
            textAlign: TextAlign.center,
            style: waddyRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: SearchScreenState._inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
