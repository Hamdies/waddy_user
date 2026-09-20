import 'package:waddy_app/common/models/module_model.dart';
import 'package:flutter/foundation.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/category/widgets/category_filter_widget.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/cart_widget.dart';
import 'package:waddy_app/common/widgets/item_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/category/widgets/subcategory_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CategoryItemScreen extends StatefulWidget {
  final String? categoryID;
  final String categoryName;
  const CategoryItemScreen({
    super.key,
    required this.categoryID,
    required this.categoryName,
  });

  @override
  CategoryItemScreenState createState() => CategoryItemScreenState();
}

class CategoryItemScreenState extends State<CategoryItemScreen>
    with TickerProviderStateMixin {
  final ScrollController scrollController = ScrollController();
  final ScrollController storeScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  TabController? _tabController;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    final bool isGrocery =
        Get.find<SplashController>().module?.type == ModuleType.grocery;
    _tabController = TabController(
      length: 2,
      initialIndex: isGrocery ? 1 : 0,
      vsync: this,
    );
    Get.find<CategoryController>().getSubCategoryList(widget.categoryID);

    Get.find<CategoryController>().getCategoryStoreList(
      widget.categoryID,
      1,
      Get.find<CategoryController>().type,
      false,
    );

    if (isGrocery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<CategoryController>().setRestaurant(true);
      });
    }

    scrollController.addListener(() {
      if (scrollController.position.pixels ==
              scrollController.position.maxScrollExtent &&
          Get.find<CategoryController>().categoryItemList != null &&
          !Get.find<CategoryController>().isLoading) {
        int pageSize = (Get.find<CategoryController>().pageSize! / 10).ceil();
        if (Get.find<CategoryController>().offset < pageSize) {
          if (kDebugMode) {
            print('end of the page');
          }
          Get.find<CategoryController>().showBottomLoader();
          Get.find<CategoryController>().getCategoryItemList(
            Get.find<CategoryController>().subCategoryIndex == 0
                ? widget.categoryID
                : Get.find<CategoryController>()
                    .subCategoryList![Get.find<CategoryController>()
                        .subCategoryIndex]
                    .id
                    .toString(),
            Get.find<CategoryController>().offset + 1,
            Get.find<CategoryController>().type,
            false,
          );
        }
      }
    });
    storeScrollController.addListener(() {
      if (storeScrollController.position.pixels ==
              storeScrollController.position.maxScrollExtent &&
          Get.find<CategoryController>().categoryStoreList != null &&
          !Get.find<CategoryController>().isLoading) {
        int pageSize =
            (Get.find<CategoryController>().restPageSize! / 10).ceil();
        if (Get.find<CategoryController>().offset < pageSize) {
          if (kDebugMode) {
            print('end of the page');
          }
          Get.find<CategoryController>().showBottomLoader();
          Get.find<CategoryController>().getCategoryStoreList(
            Get.find<CategoryController>().subCategoryIndex == 0
                ? widget.categoryID
                : Get.find<CategoryController>()
                    .subCategoryList![Get.find<CategoryController>()
                        .subCategoryIndex]
                    .id
                    .toString(),
            Get.find<CategoryController>().offset + 1,
            Get.find<CategoryController>().type,
            false,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilter(CategoryController catController) {
    double maxPrice = 1000;
    if (catController.categoryItemList != null &&
        catController.categoryItemList!.isNotEmpty) {
      maxPrice = catController.categoryItemList!.fold<double>(
        0,
        (prev, item) => (item.price ?? 0) > prev ? item.price! : prev,
      );
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => CategoryFilterWidget(
            maxValue: maxPrice > 0 ? maxPrice : 1000,
            categoryID: widget.categoryID,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return GetBuilder<CategoryController>(
      builder: (catController) {
        List<Item>? item;
        List<Store>? stores;
        if (catController.isSearching
            ? catController.searchItemList != null
            : catController.categoryItemList != null) {
          item = [];
          if (catController.isSearching) {
            item.addAll(catController.searchItemList!);
          } else {
            item.addAll(catController.categoryItemList!);
          }
        }
        if (catController.isSearching
            ? catController.searchStoreList != null
            : catController.categoryStoreList != null) {
          stores = [];
          if (catController.isSearching) {
            stores.addAll(catController.searchStoreList!);
          } else {
            stores.addAll(catController.categoryStoreList!);
          }
        }

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            if (catController.isSearching) {
              catController.toggleSearch();
            } else {
              return;
            }
          },
          child: Scaffold(
            appBar: null,
            endDrawer: const MenuDrawer(),
            endDrawerEnableOpenDragGesture: false,
            body: _buildMobileBody(catController, item, stores, primaryColor),
          ),
        );
      },
    );
  }

  Widget _buildMobileBody(
    CategoryController catController,
    List<Item>? item,
    List<Store>? stores,
    Color primaryColor,
  ) {
    return SafeArea(
      child: Column(
        children: [
          // ─── Custom App Bar ───
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    if (catController.isSearching) {
                      catController.toggleSearch();
                      _searchController.clear();
                    } else {
                      Get.back();
                    }
                  },
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  child: Container(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.categoryName,
                    style: waddyBold.copyWith(
                      fontSize: 20,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Get.toNamed(RouteHelper.getCartRoute()),
                  icon: CartWidget(color: primaryColor, size: 25),
                ),
              ],
            ),
          ),

          // ─── Search Bar + Filter ───
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '${'search'.tr}...',
                        hintStyle: waddyRegular.copyWith(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: Colors.grey.shade400,
                        ),
                        suffixIcon:
                            catController.isSearching
                                ? IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.grey.shade500,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    catController.toggleSearch();
                                  },
                                )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: Dimensions.paddingSizeSmall,
                        ),
                      ),
                      style: waddyRegular.copyWith(fontSize: 14),
                      onSubmitted: (String query) {
                        if (query.isNotEmpty) {
                          if (!catController.isSearching)
                            catController.toggleSearch();
                          catController.searchData(
                            query,
                            catController.subCategoryIndex == 0
                                ? widget.categoryID
                                : catController
                                    .subCategoryList![catController
                                        .subCategoryIndex]
                                    .id
                                    .toString(),
                            catController.type,
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _openFilter(catController),
                  child: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Sub-categories ───
          SubcategoryListWidget(
            catController: catController,
            categoryID: widget.categoryID,
            scaffoldKey: scaffoldKey,
          ),

          // ─── Tabs ───
          Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Theme.of(context).disabledColor,
              unselectedLabelStyle: waddyRegular.copyWith(
                color: Theme.of(context).disabledColor,
                fontSize: Dimensions.fontSizeSmall,
              ),
              labelStyle: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).primaryColor,
              ),
              tabs: [
                Tab(text: 'item'.tr),
                Tab(
                  text:
                      Get.find<SplashController>()
                              .configModel
                              .moduleConfig!
                              .module!
                              .showRestaurantText ??
                                  false
                          ? 'restaurants'.tr
                          : 'stores'.tr,
                ),
              ],
            ),
          ),

          // ─── Tab Content ───
          Expanded(
            child: NotificationListener(
              onNotification: (dynamic scrollNotification) {
                if (scrollNotification is ScrollEndNotification) {
                  if ((_tabController!.index == 1 && !catController.isStore) ||
                      _tabController!.index == 0 && catController.isStore) {
                    catController.setRestaurant(_tabController!.index == 1);
                    if (catController.isSearching) {
                      catController.searchData(
                        catController.searchText,
                        catController.subCategoryIndex == 0
                            ? widget.categoryID
                            : catController
                                .subCategoryList![catController
                                    .subCategoryIndex]
                                .id
                                .toString(),
                        catController.type,
                      );
                    } else {
                      if (_tabController!.index == 1) {
                        catController.getCategoryStoreList(
                          catController.subCategoryIndex == 0
                              ? widget.categoryID
                              : catController
                                  .subCategoryList![catController
                                      .subCategoryIndex]
                                  .id
                                  .toString(),
                          1,
                          catController.type,
                          false,
                        );
                      } else {
                        catController.getCategoryItemList(
                          catController.subCategoryIndex == 0
                              ? widget.categoryID
                              : catController
                                  .subCategoryList![catController
                                      .subCategoryIndex]
                                  .id
                                  .toString(),
                          1,
                          catController.type,
                          false,
                        );
                      }
                    }
                  }
                }
                return false;
              },
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    controller: scrollController,
                    child: ItemsView(
                      isStore: false,
                      items: item,
                      stores: null,
                      noDataText: 'no_category_item_found'.tr,
                    ),
                  ),
                  SingleChildScrollView(
                    controller: storeScrollController,
                    child: ItemsView(
                      isStore: true,
                      items: null,
                      stores: stores,
                      noDataText:
                          Get.find<SplashController>()
                                  .configModel
                                  .moduleConfig!
                                  .module!
                                  .showRestaurantText ??
                                      false
                              ? 'no_category_restaurant_found'.tr
                              : 'no_category_store_found'.tr,
                    ),
                  ),
                ],
              ),
            ),
          ),

          catController.isLoading
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              )
              : const SizedBox(),
        ],
      ),
    );
  }
}
