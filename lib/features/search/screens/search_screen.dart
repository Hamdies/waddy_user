import 'package:flutter/cupertino.dart';
import 'package:waddy_app/features/search/controllers/search_controller.dart'
    as search;
import 'package:waddy_app/features/search/domain/models/popular_categories_model.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/search/widgets/search_result_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Search — the screen you land on with an empty query and a keyboard already up.
///
/// The old layout opened with a 28sp "Search" title and a back chevron above a
/// 52pt bordered field: three rows of chrome before the first thing you can act
/// on, on a screen whose entire job is one input. The title also duplicated the
/// field's own placeholder, and the field's border drew a box around white on
/// white. This opens straight into a filled 44pt field with an inline Cancel —
/// the title *is* the cursor.
///
/// The idle state is a browse surface rather than a blank page, in three tiers:
/// what you searched before, what the neighbourhood searches, and what is
/// trending right now. `popularCategoryList` was already being fetched in
/// `initState` and thrown away — the category grid is what that call was for.
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

  List<String> _suggestions = <String>[];
  bool _showSuggestion = false;

  /// How many recents fit before the surface stops being a shortcut and starts
  /// being a log. Five is the point at which the grid below falls off-screen.
  static const int _maxRecent = 5;

  static const Color _primaryColor = Color(0xFF134E4A);
  static const Color _fieldFill = Color(0xFFF1F4F3);
  static const Color _ink = Color(0xFF1A1F1E);
  static const Color _inkMuted = Color(0xFF6B7876);
  static const Color _inkFaint = Color(0xFF9EAAA8);

  @override
  void initState() {
    super.initState();
    _isLoggedIn = AuthHelper.isLoggedIn();
    Get.find<search.SearchController>().setSearchMode(true, canUpdate: false);
    Get.find<search.SearchController>().getPopularCategories();
    if (_isLoggedIn) {
      Get.find<search.SearchController>().getSuggestedItems();
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
        body: SafeArea(
          child: GetBuilder<search.SearchController>(
            builder: (searchController) {
              _searchController.text = searchController.searchText!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(context, searchController),

                  Expanded(
                    child:
                        searchController.isSearchMode
                            ? _showSuggestion
                                ? _buildSuggestionsList(context, _suggestions)
                                : _buildBrowseContent(context, searchController)
                            : SearchResultWidget(
                              searchText: _searchController.text.trim(),
                              tabController: null,
                            ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The field and its Cancel, on one row.
  ///
  /// Cancel rather than a back chevron: on a screen reached from a tap on the
  /// home field, "leave search" is the *word* people look for, and the chevron
  /// cost a 48pt target at the far edge of the thumb's reach for the same act.
  Widget _buildSearchBar(
    BuildContext context,
    search.SearchController searchController,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeMedium,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeMedium,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              decoration: BoxDecoration(
                color: _fieldFill,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.search,
                    color: Color(0xFF3D4744),
                    size: 18,
                  ),
                  const SizedBox(width: Dimensions.paddingSizeMedium),

                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: widget.queryText!.isEmpty,
                      textInputAction: TextInputAction.search,
                      style: waddyRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: _ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'search_restaurants_cuisines'.tr,
                        hintStyle: waddyRegular.copyWith(
                          color: _inkFaint,
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (text) {
                        searchController.setSearchText(text);
                        _searchSuggestions(text);
                      },
                      onSubmitted:
                          (text) => _actionSearch(
                            true,
                            _searchController.text.trim(),
                            false,
                          ),
                    ),
                  ),

                  // The clear affordance is a filled disc, not a bare glyph: at 20pt
                  // on a filled field a lone × reads as part of the text.
                  if (_searchController.text.isNotEmpty)
                    Pressable(
                      minSize: Dimensions.minTapTarget,
                      scale: 0.9,
                      onTap: () {
                        _searchController.clear();
                        _showSuggestion = false;
                        _suggestions = [];
                        searchController.setSearchMode(true);
                        searchController.clearSearchHomeText();
                        _searchFocusNode.requestFocus();
                        setState(() {});
                      },
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCE4E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFF3D4744),
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: Dimensions.paddingSizeMedium),
          Pressable(
            minSize: Dimensions.minTapTarget,
            scale: 0.95,
            onTap: () => Get.back(),
            child: Text(
              'cancel'.tr,
              style: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: _primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The idle surface: recents, the category grid, trending.
  Widget _buildBrowseContent(
    BuildContext context,
    search.SearchController searchController,
  ) {
    final categories = searchController.popularCategoryList;
    final trending = searchController.suggestedItemList;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeSmall,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeExtremeLarge +
            MediaQuery.paddingOf(context).bottom,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (searchController.historyList.isNotEmpty) ...[
          _SectionHeader(
            title: 'recent_searches'.tr,
            actionLabel: 'clear'.tr,
            onAction: searchController.clearSearchHistory,
          ),
          _buildRecentList(searchController),
          const SizedBox(height: Dimensions.paddingSizeExtraLarge),
        ],

        if (categories == null || categories.isNotEmpty) ...[
          _SectionHeader(title: 'popular_near_you'.tr),
          _buildCategoryGrid(context, categories),
          const SizedBox(height: Dimensions.paddingSizeExtraLarge),
        ],

        if (trending != null && trending.isNotEmpty) ...[
          _SectionHeader(title: 'trending_now'.tr),
          ...trending
              .take(4)
              .toList()
              .asMap()
              .entries
              .map(
                (entry) => _TrendingRow(
                  rank: entry.key + 1,
                  label: entry.value.name ?? '',
                  onTap: () => _runTerm(entry.value.name ?? ''),
                ),
              ),
        ],
      ],
    );
  }

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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: Dimensions.paddingSizeMedium,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: _inkFaint, size: 18),
                    const SizedBox(width: Dimensions.paddingSizeMedium),

                    Expanded(
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: _ink,
                        ),
                      ),
                    ),

                    // Removing one recent stays available beside "Clear": the header
                    // action is all-or-nothing, and one stale term should not cost the
                    // other four.
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

  /// Four-up category tiles on a mint wash.
  ///
  /// The old grid was two-up dark-teal cards with the label in neon on top of a
  /// photo — heavy enough that ten of them read as the destination rather than
  /// a shortcut *to* one. Mint is the app's dominant surface colour, so the
  /// tiles sit back and the photography does the identifying.
  Widget _buildCategoryGrid(
    BuildContext context,
    List<PopularCategoryModel?>? categories,
  ) {
    final isLoading = categories == null;
    final items =
        isLoading
            ? List<PopularCategoryModel?>.filled(8, null)
            : categories.take(8).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: Dimensions.paddingSizeSmall,
        mainAxisSpacing: Dimensions.paddingSizeDefault,
        childAspectRatio: 0.74,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final category = items[index];
        final tile = Column(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFD3F6E8),
                        Color(0xFFEAFBF4),
                        Color(0xFFF9FEFC),
                      ],
                      stops: [0, 0.55, 1],
                    ),
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  ),
                  child:
                      category == null
                          ? const SizedBox()
                          : ClipRRect(
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                            child: CustomImage(
                              image: category.imageFullUrl ?? '',
                              fit: BoxFit.contain,
                              fallback: const SizedBox(),
                            ),
                          ),
                ),
              ),
            ),

            const SizedBox(height: Dimensions.paddingSizeSmall - 1),
            SizedBox(
              height: 16,
              child:
                  category == null
                      ? Container(
                        width: 40,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _fieldFill,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusExtraSmall,
                          ),
                        ),
                      )
                      : Text(
                        category.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: waddyBold.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: _ink,
                        ),
                      ),
            ),
          ],
        );

        if (category == null) {
          return tile;
        }
        return Pressable(
          scale: 0.96,
          onTap:
              () => Get.toNamed(
                RouteHelper.getCategoryItemRoute(
                  category.id,
                  category.name ?? '',
                ),
              ),
          child: tile,
        );
      },
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
    if (Get.find<search.SearchController>().isSearchMode || isSubmit) {
      if (queryText!.isNotEmpty) {
        Get.find<search.SearchController>().searchData(queryText, fromHome);
      } else {
        showCustomSnackBar('search_item_or_store'.tr);
      }
    }
  }
}

/// An uppercase eyebrow with an optional trailing action.
///
/// Uppercase at 13sp in the muted ink, not a 18sp bold teal heading: these
/// label three stacked lists on one scroll, and a heading that competes with
/// the list items makes the surface read as three screens spliced together.
/// Caps collapse to plain text under Arabic — `displayCaps` handles that.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeMedium),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayCaps(title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: SearchScreenState._inkMuted,
                letterSpacing: displayTracking(
                  0.03 * Dimensions.fontSizeExtraSmall,
                ),
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

/// A ranked trending row — the numeral is the ornament, so it is drawn in the
/// palest ink on the screen and the term keeps the reading weight.
class _TrendingRow extends StatelessWidget {
  final int rank;
  final String label;
  final VoidCallback onTap;

  const _TrendingRow({
    required this.rank,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.99,
      alignment: AlignmentDirectional.centerStart,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeMedium - 1,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                rank.toString(),
                textDirection: TextDirection.ltr,
                style: waddyBlack.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: const Color(0xFFDCE4E2),
                ),
              ),
            ),

            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: waddyMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: SearchScreenState._ink,
                ),
              ),
            ),
          ],
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
