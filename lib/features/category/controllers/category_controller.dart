import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/category/domain/services/category_service_interface.dart';
import 'package:waddy_app/helper/cache_ttl_helper.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/common/models/module_model.dart';

/// The module's category list (and the dashboard's grocery aisles, and the
/// interest picker) — app-wide state. One category PAGE's state is on
/// `CategoryPageController` (ST-16).
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

  List<bool>? _interestSelectedList;
  List<bool>? get interestSelectedList => _interestSelectedList;

  /// The interest picker's save in flight. (A category page's own loading
  /// state is on `CategoryPageController` since ST-16.)
  bool _isLoading = false;
  bool get isLoading => _isLoading;

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
}
