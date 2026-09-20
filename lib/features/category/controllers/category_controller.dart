import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/category/domain/services/category_service_interface.dart';
import 'package:waddy_app/helper/cache_ttl_helper.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/common/models/module_model.dart';

class CategoryController extends GetxController implements GetxService {
  final CategoryServiceInterface categoryServiceInterface;
  CategoryController({required this.categoryServiceInterface});

  List<CategoryModel>? _categoryList;
  List<CategoryModel>? get categoryList => _categoryList;

  /// Grocery aisles for the aggregated dashboard, pinned to the grocery
  /// module rather than to whichever module is selected.
  ///
  /// Deliberately *not* [_categoryList]: that list belongs to the module the
  /// user is currently in and is cleared on every switch, so the dashboard —
  /// which has no module at all — was reading Food's menu as grocery aisles
  /// after a single visit to Food. Kept across module switches because it is
  /// pinned by module id, so it can never be about the wrong one.
  List<CategoryModel>? _groceryAisles;
  List<CategoryModel>? get groceryAisles => _groceryAisles;

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

  List<bool>? _interestSelectedList;
  List<bool>? get interestSelectedList => _interestSelectedList;

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

  void clearCategoryList() {
    _categoryList = null;
    // A module switch invalidates whatever fetch is still in flight: it is
    // filling the list for the module we just left. Drop it so the next
    // caller starts a fetch for the new module instead of joining that one.
    _listFetchInFlight = null;
  }

  /// Mirrors the cache id CategoryRepository writes under, so the freshness
  /// stamp and the cached row it vouches for always refer to the same payload.
  String _categoryTtlKey(bool allCategory) {
    final String moduleId =
        Get.find<SplashController>().module?.id?.toString() ?? '';
    return 'category_list_${allCategory ? 'all' : moduleId}';
  }

  // Home's loadData and the module screens' initState both request
  // categories in the same frame (the list is null right after a module
  // switch clears it) — join the in-flight fetch instead of fetching twice.
  Future<void>? _listFetchInFlight;

  Future<void> getCategoryList(
    bool reload, {
    bool allCategory = false,
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) {
    if (fromRecall || allCategory) {
      // Internal client-refresh recursion and the all-category variant
      // (different payload) must never join the shared fetch.
      return _fetchCategoryList(
        reload,
        allCategory: allCategory,
        dataSource: dataSource,
        fromRecall: fromRecall,
      );
    }
    if (!reload && _listFetchInFlight != null) return _listFetchInFlight!;
    late final Future<void> fetch;
    fetch = _fetchCategoryList(
      reload,
      allCategory: allCategory,
      dataSource: dataSource,
      fromRecall: fromRecall,
    ).whenComplete(() {
      if (identical(_listFetchInFlight, fetch)) _listFetchInFlight = null;
    });
    _listFetchInFlight = fetch;
    return fetch;
  }

  Future<void> _fetchCategoryList(
    bool reload, {
    bool allCategory = false,
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (_categoryList == null || reload || fromRecall) {
      if (reload) {
        _categoryList = null;
      }

      // The cached payload is keyed per module (see CategoryRepository), so the
      // freshness stamp has to be too. A single global key let a fresh stamp
      // from the previous module send this module down the local branch, where
      // it read a cache entry that was never written and left the list null.
      final String ttlKey = _categoryTtlKey(allCategory);

      if (dataSource == DataSourceEnum.local &&
          CacheTtlHelper.isStale(ttlKey, ttl: CacheTtlHelper.groceryTtl)) {
        dataSource = DataSourceEnum.client;
      }

      List<CategoryModel>? categoryList;
      if (dataSource == DataSourceEnum.local) {
        categoryList = await categoryServiceInterface.getCategoryList(
          allCategory,
          source: DataSourceEnum.local,
        );
        // A fresh stamp is not proof the row exists: the drift write is fire
        // and forget, and the cache can be cleared under us. An empty local
        // read must fall through to the network or the list stays null and the
        // category strip shimmers forever.
        if (categoryList == null) {
          dataSource = DataSourceEnum.client;
        } else {
          _prepareCategoryList(categoryList);
          // Reaching here means CacheTtlHelper judged the cached list fresh, so
          // the network re-call that used to follow spent a second request to
          // arrive at data we already had. Staleness drives the fetch; the check
          // above already made that call.
        }
      }

      if (dataSource == DataSourceEnum.client) {
        categoryList = await categoryServiceInterface.getCategoryList(
          allCategory,
          source: DataSourceEnum.client,
        );
        _prepareCategoryList(categoryList);
        if (categoryList != null) {
          CacheTtlHelper.markFresh(ttlKey);
        }
      }
    }
  }

  /// Dashboard-only: the grocery module's categories, whatever module is
  /// selected. Resolves the module id from the splash module list, so it is a
  /// no-op until that list has arrived (home's loadData fetches it first).
  Future<void> getGroceryAisles() async {
    final splashController = Get.find<SplashController>();
    if (splashController.moduleList == null) {
      await splashController.getModules();
    }
    int? groceryId;
    for (final ModuleModel module
        in splashController.moduleList ?? <ModuleModel>[]) {
      if (module.type == ModuleType.grocery) {
        groceryId = module.id;
        break;
      }
    }
    if (groceryId == null) return;
    _groceryModuleId = groceryId;
    final List<CategoryModel>? aisles = await categoryServiceInterface
        .getModuleCategoryList(groceryId);
    if (aisles != null) {
      _groceryAisles = aisles;
      update();
    }
  }

  /// The module the aisles above belong to — the shelf needs it to switch the
  /// app into grocery before opening one, the same dance its store cards do.
  int? _groceryModuleId;
  int? get groceryModuleId => _groceryModuleId;

  _prepareCategoryList(List<CategoryModel>? categoryList) {
    if (categoryList != null) {
      _categoryList = [];
      _interestSelectedList = [];
      _categoryList!.addAll(categoryList);
      for (int i = 0; i < _categoryList!.length; i++) {
        _interestSelectedList!.add(false);
      }
    }
    update();
  }

  void getSubCategoryList(String? categoryID) async {
    _subCategoryIndex = 0;
    _subCategoryList = null;
    _categoryItemList = null;
    List<CategoryModel>? subCategoryList = await categoryServiceInterface
        .getSubCategoryList(categoryID);
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
      if (notify) {
        update();
      }
      _categoryItemList = null;
    }
    ItemModel? categoryItem = await categoryServiceInterface
        .getCategoryItemList(categoryID, offset, type);
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
      if (notify) {
        update();
      }
      _categoryStoreList = null;
    }
    StoreModel? categoryStore = await categoryServiceInterface
        .getCategoryStoreList(categoryID, offset, type);
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

  Future<bool> saveInterest(List<int?> interests) async {
    _isLoading = true;
    update();
    bool isSuccess = await categoryServiceInterface.saveUserInterests(
      interests,
    );
    _isLoading = false;
    update();
    return isSuccess;
  }

  void addInterestSelection(int index) {
    _interestSelectedList![index] = !_interestSelectedList![index];
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
