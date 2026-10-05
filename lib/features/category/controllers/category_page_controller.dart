import 'package:get/get.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/category/domain/services/category_service_interface.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// Everything ONE category page shows (ST-16): its sub-categories, items and
/// stores with their pagination, the items/stores tab, in-page search, the
/// item type and the filter sheet.
///
/// This lived on the app-wide `CategoryController`, so it outlived the page —
/// the same shape as the store pages' ST-01. The next category page opened
/// with the last one's item type (it was passed into the first store request),
/// its search mode and text, its filter selections, and its items/stores tab
/// flag: the body compares the visible tab with that flag, so a leftover one
/// showed the other tab's list. And with no stale-response guard, category
/// A's items could land on category B's page.
///
/// Each category page [open]s its own, and it is deleted with the page. The
/// sub-category strip and the filter sheet are handed the page's controller.
/// Member names are the old ones, so the widgets changed which controller
/// they read, not what they read. The module's category LIST stays on
/// `CategoryController`: that one is genuinely app-wide.
class CategoryPageController extends GetxController {
  CategoryPageController({
    required this.categoryServiceInterface,
    required this.tag,
  });

  final CategoryServiceInterface categoryServiceInterface;

  /// The GetX tag this instance is registered under.
  final String tag;

  static int _seq = 0;

  /// Registers a fresh controller for a category page that is opening.
  static CategoryPageController open() {
    final String tag = 'category_page_${++_seq}';
    return Get.put(
      CategoryPageController(
        categoryServiceInterface: Get.find<CategoryServiceInterface>(),
        tag: tag,
      ),
      tag: tag,
    );
  }

  /// Drops this page's state. Call from the page's `dispose`.
  void close() {
    if (Get.isRegistered<CategoryPageController>(tag: tag)) {
      Get.delete<CategoryPageController>(tag: tag, force: true);
    }
  }

  List<CategoryModel>? _subCategoryList;
  List<CategoryModel>? get subCategoryList => _subCategoryList;

  List<Item>? _categoryItemList;
  List<Item>? get categoryItemList => _categoryItemList;

  List<Store>? _categoryStoreList;
  List<Store>? get categoryStoreList => _categoryStoreList;

  List<Item>? _searchItemList = [];
  List<Item>? get searchItemList => _searchItemList;

  List<Store>? _searchStoreList = [];
  List<Store>? get searchStoreList => _searchStoreList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int? _pageSize;
  int? get pageSize => _pageSize;

  int? _restPageSize;
  int? get restPageSize => _restPageSize;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  int _subCategoryIndex = 0;
  int get subCategoryIndex => _subCategoryIndex;

  String _type = 'all';
  String get type => _type;

  bool _isStore = false;
  bool get isStore => _isStore;

  String? _searchText = '';
  String? get searchText => _searchText;

  int _offset = 1;
  int get offset => _offset;

  /// Bumped per first-page fetch; a response that started under an older
  /// value was for an earlier sub-category or type and is dropped.
  int _itemGeneration = 0;
  int _storeGeneration = 0;

  void getSubCategoryList(String? categoryID) async {
    _subCategoryIndex = 0;
    _subCategoryList = null;
    _categoryItemList = null;
    List<CategoryModel>? subCategoryList = await categoryServiceInterface
        .getSubCategoryList(categoryID);
    if (isClosed) return;
    if (subCategoryList != null) {
      _subCategoryList = [];
      _subCategoryList!.add(
        CategoryModel(id: int.parse(categoryID!), name: 'all'.tr),
      );
      _subCategoryList!.addAll(subCategoryList);
      getCategoryItemList(categoryID, 1, 'all', false);
    }
  }

  void setSubCategoryIndex(int index, String? categoryID) {
    _subCategoryIndex = index;
    if (_isStore) {
      getCategoryStoreList(
        _subCategoryIndex == 0
            ? categoryID
            : _subCategoryList![index].id.toString(),
        1,
        _type,
        true,
      );
    } else {
      getCategoryItemList(
        _subCategoryIndex == 0
            ? categoryID
            : _subCategoryList![index].id.toString(),
        1,
        _type,
        true,
      );
    }
  }

  void getCategoryItemList(
    String? categoryID,
    int offset,
    String type,
    bool notify,
  ) async {
    _offset = offset;
    if (offset == 1) {
      if (_type == type) {
        _isSearching = false;
      }
      _type = type;
      _itemGeneration++;
      if (notify) {
        update();
      }
      _categoryItemList = null;
    }
    final int generation = _itemGeneration;
    ItemModel? categoryItem = await categoryServiceInterface
        .getCategoryItemList(categoryID, offset, type);
    if (generation != _itemGeneration || isClosed) return;
    if (categoryItem != null) {
      if (offset == 1) {
        _categoryItemList = [];
      }
      _categoryItemList!.addAll(categoryItem.items!);
      _pageSize = categoryItem.totalSize;
      _isLoading = false;
    }
    update();
  }

  void getCategoryStoreList(
    String? categoryID,
    int offset,
    String type,
    bool notify,
  ) async {
    _offset = offset;
    if (offset == 1) {
      if (_type == type) {
        _isSearching = false;
      }
      _type = type;
      _storeGeneration++;
      if (notify) {
        update();
      }
      _categoryStoreList = null;
    }
    final int generation = _storeGeneration;
    StoreModel? categoryStore = await categoryServiceInterface
        .getCategoryStoreList(categoryID, offset, type);
    if (generation != _storeGeneration || isClosed) return;
    if (categoryStore != null) {
      if (offset == 1) {
        _categoryStoreList = [];
      }
      _categoryStoreList!.addAll(categoryStore.stores!);
      _restPageSize = categoryStore.totalSize;
      _isLoading = false;
    }
    update();
  }

  void searchData(String? query, String? categoryID, String type) async {
    if ((_isStore && query!.isNotEmpty) ||
        (!_isStore && query!.isNotEmpty /*&& query != _itemResultText*/ )) {
      _searchText = query;
      _type = type;
      _isStore ? _searchStoreList = null : _searchItemList = null;
      _isSearching = true;
      update();

      Response response = await categoryServiceInterface.getSearchData(
        query,
        categoryID,
        _isStore,
        type,
      );
      if (isClosed) return;
      if (response.statusCode == 200) {
        if (query.isEmpty) {
          _isStore ? _searchStoreList = [] : _searchItemList = [];
        } else {
          if (_isStore) {
            _searchStoreList = [];
            _searchStoreList!.addAll(
              StoreModel.fromJson(response.body).stores!,
            );
            update();
          } else {
            _searchItemList = [];
            _searchItemList!.addAll(ItemModel.fromJson(response.body).items!);
          }
        }
      }
      update();
    }
  }

  void toggleSearch() {
    _isSearching = !_isSearching;
    _searchItemList = [];
    if (_categoryItemList != null) {
      _searchItemList!.addAll(_categoryItemList!);
    }
    update();
  }

  void showBottomLoader() {
    _isLoading = true;
    update();
  }

  void setRestaurant(bool isRestaurant) {
    _isStore = isRestaurant;
    update();
  }

  // ─── Filter State ───

  int _rating = -1;
  int get rating => _rating;

  double _lowerValue = 0;
  double get lowerValue => _lowerValue;

  double _upperValue = 0;
  double get upperValue => _upperValue;

  int? _sortIndex;
  int? get sortIndex => _sortIndex;

  bool _isAvailableItems = false;
  bool get isAvailableItems => _isAvailableItems;

  bool _isDiscountedItems = false;
  bool get isDiscountedItems => _isDiscountedItems;

  void setRating(int rate) {
    _rating = rate;
    update();
  }

  void setLowerAndUpperValue(double lower, double upper) {
    _lowerValue = lower;
    _upperValue = upper;
    update();
  }

  void setSortIndex(int index) {
    _sortIndex = index;
    update();
  }

  void toggleAvailableItems() {
    _isAvailableItems = !_isAvailableItems;
    update();
  }

  void toggleDiscountedItems() {
    _isDiscountedItems = !_isDiscountedItems;
    update();
  }

  void resetFilter({bool isUpdate = true}) {
    _rating = -1;
    _lowerValue = 0;
    _upperValue = 0;
    _sortIndex = null;
    _isAvailableItems = false;
    _isDiscountedItems = false;
    if (isUpdate) {
      update();
    }
  }
}
