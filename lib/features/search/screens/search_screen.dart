import 'package:flutter/cupertino.dart';
import 'package:waddy_app/features/search/controllers/search_controller.dart' as search;
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/common/widgets/web_menu_bar.dart';
import 'package:waddy_app/features/search/widgets/search_result_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SearchScreen extends StatefulWidget {
  final String? queryText;
  final bool fromHome;
  const SearchScreen({super.key, required this.queryText, this.fromHome = false});

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  TabController? _tabController;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late bool _isLoggedIn;

  List<String> _suggestions = <String>[];
  bool _showSuggestion = false;

  // App colors from theme
  static const Color _primaryColor = Color(0xFF134E4A);
  static const Color _accentColor = Color(0xFF1EF2A0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, initialIndex: 0, vsync: this);
    _isLoggedIn = AuthHelper.isLoggedIn();
    Get.find<search.SearchController>().setSearchMode(true, canUpdate: false);
    Get.find<search.SearchController>().getPopularCategories();
    Get.find<CategoryController>().getCategoryList(false, allCategory: false);
    if(_isLoggedIn) {
      Get.find<search.SearchController>().getSuggestedItems();
    }
    Get.find<search.SearchController>().getHistoryList();
    if(widget.queryText!.isNotEmpty) {
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
      _suggestions = await Get.find<search.SearchController>().getSearchSuggestions(query);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if(Get.find<search.SearchController>().isSearchMode) {
          return;
        } else {
          Get.find<search.SearchController>().setSearchMode(true);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        appBar: ResponsiveHelper.isDesktop(context) ? const WebMenuBar() : null,
        endDrawer: const MenuDrawer(),
        endDrawerEnableOpenDragGesture: false,
        body: SafeArea(
          child: GetBuilder<search.SearchController>(builder: (searchController) {
            if(!GetPlatform.isWeb) {
              _searchController.text = searchController.searchText!;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large "Search" title with back button
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.arrow_back_ios, size: 20),
                        color: _primaryColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'search'.tr,
                        style: robotoBold.copyWith(
                          fontSize: 28,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Search Field
                _buildSearchField(context, searchController),
                
                const SizedBox(height: 8),
                
                // Content
                Expanded(
                  child: searchController.isSearchMode 
                    ? _showSuggestion 
                      ? _buildSuggestionsList(context, searchController, _suggestions)
                      : _buildSearchContent(context, searchController)
                    : SearchResultWidget(
                        searchText: _searchController.text.trim(), 
                        tabController: ResponsiveHelper.isDesktop(context) ? _tabController : null,
                      ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, search.SearchController searchController) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(CupertinoIcons.search, color: Colors.grey[500], size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: robotoRegular.copyWith(fontSize: 16, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'search_for_food_convenience'.tr,
                  hintStyle: robotoRegular.copyWith(
                    color: Colors.grey[400],
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: (text) {
                  searchController.setSearchText(text);
                  _searchSuggestions(text);
                },
                onSubmitted: (text) => _actionSearch(true, _searchController.text.trim(), false),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _showSuggestion = false;
                  searchController.setSearchMode(true);
                  searchController.clearSearchHomeText();
                  setState(() {});
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.close, color: Colors.grey[500], size: 20),
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchContent(BuildContext context, search.SearchController searchController) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FooterView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            
            // Recent Searches Section
            if (searchController.historyList.isNotEmpty) ...[
              Text(
                'recent_searches'.tr,
                style: robotoBold.copyWith(
                  fontSize: 18,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              _buildRecentSearchesList(context, searchController),
              const SizedBox(height: 28),
            ],
            
            // Top Categories Section
            Text(
              'top_categories'.tr,
              style: robotoBold.copyWith(
                fontSize: 18,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildCategoriesGrid(context),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearchesList(BuildContext context, search.SearchController searchController) {
    final historyItems = searchController.historyList.take(5).toList();
    return Column(
      children: historyItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              Icons.history,
              color: Colors.grey[500],
              size: 22,
            ),
            title: Text(
              item,
              style: robotoRegular.copyWith(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            trailing: GestureDetector(
              onTap: () => searchController.removeHistory(index),
              child: Icon(
                Icons.close,
                color: Colors.grey[400],
                size: 20,
              ),
            ),
            onTap: () {
              _searchController.text = item;
              searchController.searchData(item, false);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoriesGrid(BuildContext context) {
    return GetBuilder<CategoryController>(
      builder: (categoryController) {
        if (categoryController.categoryList == null) {
          return _buildCategoryShimmer();
        }
        
        if (categoryController.categoryList!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Text(
                'no_category_available'.tr,
                style: robotoRegular.copyWith(color: Colors.grey),
              ),
            ),
          );
        }
        
        // Filter categories to show only food module categories
        final allCategories = categoryController.categoryList!;
        final foodCategories = allCategories.where((category) {
          // Ensure we only get module-specific (food) categories
          return category.id != null;
        }).toList();
        
        final categories = foodCategories.take(10).toList();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return GestureDetector(
              onTap: () => Get.toNamed(
                RouteHelper.getCategoryItemRoute(category.id, category.name!),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _primaryColor,
                      Color(0xFF1A5D58), // Slightly lighter teal
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Category name on the left
                    Positioned(
                      left: 14,
                      top: 14,
                      child: SizedBox(
                        width: 80,
                        child: Text(
                          category.name ?? '',
                          style: robotoBold.copyWith(
                            fontSize: 14,
                            color: _accentColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Category image on the right
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomImage(
                          image: category.imageFullUrl ?? '',
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryShimmer() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionsList(BuildContext context, search.SearchController searchController, List<String> suggestions) {
    if (suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.search, size: 50, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'no_suggestions_found'.tr,
                style: robotoMedium.copyWith(color: Colors.grey[500], fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.separated(
      itemCount: suggestions.length,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey[200],
      ),
      itemBuilder: (context, index) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            CupertinoIcons.search,
            color: Colors.grey[400],
            size: 20,
          ),
          title: Text(
            suggestions[index],
            style: robotoRegular.copyWith(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          trailing: Icon(
            Icons.north_west,
            color: Colors.grey[400],
            size: 18,
          ),
          onTap: () {
            FocusScope.of(context).unfocus();
            _searchController.text = suggestions[index];
            _actionSearch(true, _searchController.text.trim(), false);
          },
        );
      },
    );
  }

  void _actionSearch(bool isSubmit, String? queryText, bool fromHome) {
    if(Get.find<search.SearchController>().isSearchMode || isSubmit) {
      if(queryText!.isNotEmpty) {
        Get.find<search.SearchController>().searchData(queryText, fromHome);
      } else {
        showCustomSnackBar('search_item_or_store'.tr);
      }
    }
  }
}
