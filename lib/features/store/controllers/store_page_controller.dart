import 'package:waddy_app/features/store/domain/models/buy_again_line.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/store/domain/models/recommended_product_model.dart';
import 'package:waddy_app/features/store/domain/models/store_banner_model.dart';
import 'package:waddy_app/features/store/domain/models/store_bundle_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/domain/services/store_service_interface.dart';
import 'package:waddy_app/helper/module_helper.dart';
import 'package:waddy_app/util/parse.dart';

/// Everything ONE store page shows: its store, categories, menu, filters,
/// rails, in-store search, banners, bundles and recommendations (ST-01,
/// ST-07, ST-08).
///
/// All of this used to live on the app-wide `StoreController` singleton, so
/// it outlived the page it was made on: a grocery aisle picked on one store
/// was sent as `category_id` for the next store's menu, which came back empty
/// ("no items"). Phase 0 papered over that with a reset on open. A page
/// controller needs no reset — each store page [open]s its own, and it is
/// deleted when the page closes. Stacked store pages (store → similar store →
/// back) each keep their own state, and `update()` here reaches only the
/// builders of this page, not the home underneath or the cart.
///
/// Pages pushed FROM a store page — the aisle page, in-store search, the
/// filter sheet — are handed this same controller: they are views of the same
/// visit, and a filter applied on the aisle page must reach its parent's
/// rails.
///
/// The members kept their `StoreController` names on purpose: the logic was
/// moved, not rewritten, so the screens changed which controller they read,
/// not what they read.
class StorePageController extends GetxController {
  StorePageController({required this.storeServiceInterface, required this.tag});

  final StoreServiceInterface storeServiceInterface;

  /// The GetX tag this instance is registered under; builders on this page
  /// pass it as `GetBuilder<StorePageController>(tag: page.tag)`.
  final String tag;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  static int _seq = 0;

  /// Store pages currently open, oldest first.
  static final List<StorePageController> _open = <StorePageController>[];

  /// The store page on top, if one is open. For the rare reader outside the
  /// page that genuinely means "the store the user is looking at" — the
  /// no-delivery sheet on a blocked add-to-cart. Never the cart's store: that
  /// is `CartController.cartStore`.
  static StorePageController? get top => _open.isEmpty ? null : _open.last;

  /// Registers a fresh controller for a store page that is opening.
  static StorePageController open() {
    final String tag = 'store_page_${++_seq}';
    final StorePageController page = Get.put(
      StorePageController(
        storeServiceInterface: Get.find<StoreServiceInterface>(),
        tag: tag,
      ),
      tag: tag,
    );
    _open.add(page);
    return page;
  }

  /// Drops this page's state. Call from the page's `dispose`.
  void close() {
    _open.remove(this);
    if (Get.isRegistered<StorePageController>(tag: tag)) {
      Get.delete<StorePageController>(tag: tag, force: true);
    }
  }

  // ── The store ─────────────────────────────────────────────────────────

  Store? _store;
  Store? get store => _store;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// The page shows open/closed, so it accepts a cached store at most this
  /// old — enough to join a fetch just made for the same store, not enough to
  /// show a stale open flag.
  static const Duration _pageStoreMaxAge = Duration(seconds: 30);

  /// Fetches this page's store.
  ///
  /// [slug] is a shared-link open: there is no id yet, it bypasses the cache,
  /// and it moves the user's saved address to the store's.
  Future<Store?> getStoreDetails(Store store, {String slug = ''}) async {
    _categoryIndex = 0;
    _isLoading = true;
    // Cleared before the await so a failed fetch cannot leave a stale store
    // on screen (a refresh of this page re-runs this).
    _store = null;

    final String languageCode =
        Get.find<LocalizationController>().locale.languageCode;
    final Store? storeDetails =
        (slug.isEmpty && store.id != null)
            ? await storeServiceInterface.getCachedStoreDetails(
              store.id!,
              languageCode: languageCode,
              moduleId: ModuleHelper.currentModuleId(),
              maxAge: _pageStoreMaxAge,
            )
            : await storeServiceInterface.getStoreDetails(
              store.id.toString(),
              false,
              slug,
              languageCode,
              ModuleHelper.currentModuleId(),
            );

    if (storeDetails != null) {
      _store = storeDetails;
      if (slug.isNotEmpty) {
        await _adoptStoreLocationAsUserAddress();
      }
    }
    // No home reload (ST-11): home loads itself when the user returns to it.

    _isLoading = false;
    update();
    return _store;
  }

  /// Moves the user's saved location to the store's.
  ///
  /// Only on a slug link — a shared store URL can arrive before the user has
  /// ever set an address, and without one nothing downstream can price
  /// delivery.
  Future<void> _adoptStoreLocationAsUserAddress() async {
    final double? storeLat = Parse.coordinate(_store?.latitude);
    final double? storeLng = Parse.coordinate(_store?.longitude);
    if (storeLat == null || storeLng == null) return;

    await Get.find<LocationController>().setStoreAddressToUserAddress(
      LatLng(storeLat, storeLng),
      moduleId: _store?.moduleId,
    );
  }

  // ── Categories ────────────────────────────────────────────────────────

  int _categoryIndex = 0;
  int get categoryIndex => _categoryIndex;

  List<CategoryModel>? _categoryList;
  List<CategoryModel>? get categoryList => _categoryList;

  void setCategoryList() {
    // A specialty grocery store's categories are its own — the backend keeps
    // them out of the module-wide `/categories` list, so intersecting with
    // that list would leave the store with no tabs at all. Its details
    // payload carries the rows (already in admin order); use them directly.
    final List<CategoryModel>? own = _store?.categoryDetails;
    if (_store?.isSupermarket == false && own != null && own.isNotEmpty) {
      _categoryList = [CategoryModel(id: 0, name: 'all'.tr), ...own];
      return;
    }
    if (Get.find<CategoryController>().categoryList != null && _store != null) {
      _categoryList = [];
      _categoryList!.add(CategoryModel(id: 0, name: 'all'.tr));
      for (var category in Get.find<CategoryController>().categoryList!) {
        if (_store!.categoryIds!.contains(category.id)) {
          _categoryList!.add(category);
        }
      }
    }
  }

  /// Uses [categories] as this page's category list instead of deriving it
  /// from the store. The pets store browses the module's shared species tree
  /// (Cats, Dogs…), which its details payload does not carry, and the
  /// category page it opens reads the list from here.
  void useCategories(List<CategoryModel> categories) {
    _categoryList = [CategoryModel(id: 0, name: 'all'.tr), ...categories];
  }

  void setCategoryIndex(int index, {bool itemSearching = false}) {
    _categoryIndex = index;
    // A new main category starts on "all"; a previous sub pick is stale.
    _itemsCategoryOverride = null;
    _subCategoryId = 0;
    if (itemSearching) {
      _storeSearchItemModel = null;
      getStoreSearchItemList(_searchText, _store!.id.toString(), 1, _type);
    } else {
      _storeItemModel = null;
      getStoreItemList(_store!.id, 1, _type, false);
    }
    update();
  }

  /// The category the menu is showing, as sent to the server.
  int get _selectedCategoryId =>
      (_store != null && _store!.categoryIds!.isNotEmpty && _categoryIndex != 0)
          ? _categoryList![_categoryIndex].id ?? 0
          : 0;

  // ── The menu (paginated items) ────────────────────────────────────────

  ItemModel? _storeItemModel;
  ItemModel? get storeItemModel => _storeItemModel;

  /// The menu's item type (all / veg / non-veg). Page-owned since ST-08: it
  /// used to be `StoreController.type`, which the home's store lists also
  /// wrote.
  String _type = 'all';
  String get type => _type;

  /// Bumped per first-page fetch; a response that started under an older
  /// value was for an earlier category or filter set and is dropped.
  int _itemListGeneration = 0;

  Future<void> getStoreItemList(
    int? storeID,
    int offset,
    String type,
    bool notify,
  ) async {
    if (offset == 1 || _storeItemModel == null) {
      _type = type;
      _storeItemModel = null;
      _itemListGeneration++;
      if (notify) {
        update();
      }
    }
    final int generation = _itemListGeneration;
    ItemModel? storeItemModel = await storeServiceInterface.getStoreItemList(
      storeID: storeID,
      offset: offset,
      categoryID: _itemsCategoryOverride ?? _selectedCategoryId,
      type: type,
      filter: _filter,
      rating: _rating == -1 ? null : _rating,
      lowerValue: _lowerValue == 0 ? null : _lowerValue,
      upperValue: _upperValue == 0 ? null : _upperValue,
    );
    // An old category's page landing after a new tab would otherwise
    // overwrite — or append to — the list now on screen.
    if (generation != _itemListGeneration || isClosed) return;
    if (storeItemModel != null) {
      if (offset == 1) {
        _storeItemModel = storeItemModel;
      } else {
        _storeItemModel!.items!.addAll(storeItemModel.items!);
        _storeItemModel!.totalSize = storeItemModel.totalSize;
        _storeItemModel!.offset = storeItemModel.offset;
      }
    } else if (offset == 1) {
      // A failed FIRST page must still land somewhere: the screen reads
      // `storeItemModel == null` as "first page in flight", and leaving it
      // null shimmered forever with nothing outstanding. An empty model is
      // the truthful "loaded, nothing to show", with pull-to-refresh.
      // Only for offset 1: a failed LATER page must not wipe earlier pages.
      _storeItemModel = ItemModel(items: [], totalSize: 0, offset: 1);
    }
    update();
  }

  // ── In-store search ───────────────────────────────────────────────────

  ItemModel? _storeSearchItemModel;
  ItemModel? get storeSearchItemModel => _storeSearchItemModel;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  String _searchType = 'all';
  String get searchType => _searchType;

  String _searchText = '';
  String get searchText => _searchText;

  Future<void> getStoreSearchItemList(
    String searchText,
    String? storeID,
    int offset,
    String type,
  ) async {
    if (searchText.isEmpty) {
      showCustomSnackBar('write_item_name'.tr);
      return;
    }
    _isSearching = true;
    _searchText = searchText;
    _type = type;
    if (offset == 1 || _storeSearchItemModel == null) {
      _searchType = type;
      _storeSearchItemModel = null;
      update();
    }
    ItemModel? storeSearchItemModel = await storeServiceInterface
        .getStoreSearchItemList(
          searchText,
          storeID,
          offset,
          type,
          _selectedCategoryId,
        );
    if (isClosed) return;
    // The field filters live, so a slow answer for "mil" can land after the one
    // for "milk". Only the term currently in the field may write results.
    if (_searchText != searchText) return;
    if (storeSearchItemModel != null) {
      if (offset == 1) {
        _storeSearchItemModel = storeSearchItemModel;
      } else {
        _storeSearchItemModel!.items!.addAll(storeSearchItemModel.items!);
        _storeSearchItemModel!.totalSize = storeSearchItemModel.totalSize;
        _storeSearchItemModel!.offset = storeSearchItemModel.offset;
      }
    }
    update();
  }

  void changeSearchStatus({bool isUpdate = true}) {
    _isSearching = !_isSearching;
    if (isUpdate) {
      update();
    }
  }

  // ── In-store search: the store's products, listed before anything is typed

  ItemModel? _searchBrowseModel;
  ItemModel? get searchBrowseModel => _searchBrowseModel;

  /// The store's whole range, for a search screen that opens on products
  /// rather than on recents (every store that is not a supermarket).
  ///
  /// Its own model, not [storeItemModel]: that one follows the store page's
  /// selected category and filters, and reloading it from here would blank the
  /// page underneath. Always the unfiltered range, first page cached for the
  /// life of the page.
  Future<void> getSearchBrowseItems(int? storeId, int offset) async {
    if (storeId == null) return;
    if (offset == 1 && _searchBrowseModel != null) return;
    final ItemModel? page = await storeServiceInterface.getStoreItemList(
      storeID: storeId,
      offset: offset,
      categoryID: 0,
      type: 'all',
    );
    if (isClosed) return;
    if (page == null) {
      // Same rule as the menu: a failed first page lands as empty so the
      // screen stops shimmering; a failed later page keeps what is shown.
      if (offset == 1) {
        _searchBrowseModel = ItemModel(items: [], totalSize: 0, offset: 1);
        update();
      }
      return;
    }
    if (offset == 1 || _searchBrowseModel == null) {
      _searchBrowseModel = page;
    } else {
      _searchBrowseModel!.items!.addAll(page.items ?? const []);
      _searchBrowseModel!.totalSize = page.totalSize;
      _searchBrowseModel!.offset = page.offset;
    }
    update();
  }

  void initSearchData() {
    _storeSearchItemModel = ItemModel(items: []);
    _searchText = '';
  }

  // ── Filter sheet ──────────────────────────────────────────────────────

  bool _isAvailableItems = false;
  bool get isAvailableItems => _isAvailableItems;

  bool _isDiscountedItems = false;
  bool get isDiscountedItems => _isDiscountedItems;

  List<String>? _filter = [];
  List<String>? get filter => _filter;

  int _rating = -1;
  int get rating => _rating;

  double _lowerValue = 0;
  double get lowerValue => _lowerValue;

  double _upperValue = 0;
  double get upperValue => _upperValue;

  int? _sortIndex;
  int? get sortIndex => _sortIndex;

  void setRating(int rate) {
    _rating = rate;
    update();
  }

  void toggleAvailableItems() {
    _isAvailableItems = !_isAvailableItems;
    if (_isAvailableItems) {
      _filter!.add("available_now");
    } else {
      _filter!.remove("available_now");
    }
    update();
  }

  void toggleDiscountedItems() {
    _isDiscountedItems = !_isDiscountedItems;
    if (_isDiscountedItems) {
      _filter!.add("discounted");
    } else {
      _filter!.remove("discounted");
    }
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

  void resetFilter({bool isUpdate = true}) {
    _isAvailableItems = false;
    _isDiscountedItems = false;
    _rating = -1;
    _lowerValue = 0;
    _upperValue = 0;
    _sortIndex = null;
    _filter = [];
    if (isUpdate) {
      update();
    }
  }

  // ── Sub-categories on a category page ─────────────────────────────────

  final Map<int, List<CategoryModel>> _subCategories = {};

  /// Which sub-category chip is picked (0 = all of the category).
  int _subCategoryId = 0;
  int get subCategoryId => _subCategoryId;

  /// Category to fetch items for instead of the picked main category.
  int? _itemsCategoryOverride;

  /// The sub-categories this store stocks under [categoryId]; null until
  /// fetched, empty when there are none (or the request failed).
  List<CategoryModel>? subCategoriesOf(int? categoryId) =>
      _subCategories[categoryId];

  Future<void> loadSubCategories(int? categoryId) async {
    _subCategoryId = 0;
    // Called from initState: nothing to notify before the first build has
    // read the state, and update() here is a setState-during-build. Only the
    // fetch below, which lands after an await, needs to notify.
    if (categoryId == null || _subCategories.containsKey(categoryId)) return;
    final int? storeId = _store?.id;
    final List<CategoryModel>? list = await storeServiceInterface
        .getStoreSubCategories(storeId, categoryId);
    if (isClosed) return;
    _subCategories[categoryId] = list ?? const [];
    update();
  }

  /// Picks a sub-category chip and reloads the items under it. 0 goes back to
  /// the whole category ([categoryId]).
  void selectSubCategory(int subId, int? categoryId) {
    if (_subCategoryId == subId) return;
    _subCategoryId = subId;
    _storeItemModel = null;
    _itemsCategoryOverride = subId == 0 ? null : subId;
    getStoreItemList(_store!.id, 1, _type, false);
    update();
  }

  // ── Aisle page rails ──────────────────────────────────────────────────
  //
  // A supermarket's aisle page is a stack of product rails — best sellers,
  // offers, then one per category. Each rail fetches its own first page when
  // it nears the viewport.

  final Map<String, List<Item>> _storeRails = {};
  final Set<String> _storeRailsInFlight = {};

  /// Bumped by [resetStoreRails]; a fetch that started under an older value
  /// was for the old filters and is dropped.
  int _storeRailsGeneration = 0;

  /// GetBuilder id for one rail, so a rail landing rebuilds only itself.
  static String storeRailId(String key) => 'store_rail_$key';

  /// Null until fetched; empty when the store has nothing for it.
  List<Item>? storeRail(String key) => _storeRails[key];

  final Set<String> _storeRailsFailed = {};
  final Map<String, int> _storeRailTotals = {};

  /// Whether [key]'s last fetch failed (it then reads as empty).
  bool storeRailFailed(String key) => _storeRailsFailed.contains(key);

  /// How many items the backend holds for [key], beyond the first page;
  /// null when unknown.
  int? storeRailTotal(String key) => _storeRailTotals[key];

  /// Drops [key] and fetches it again, for a rail's retry row.
  void retryStoreRail(String key, {int categoryId = 0, String? sort}) {
    _storeRails.remove(key);
    _storeRailsFailed.remove(key);
    update([storeRailId(key)]);
    fetchStoreRail(key, categoryId: categoryId, sort: sort);
  }

  /// Fetches one rail's first page with the filter sheet's current values.
  /// [sort] is an extra backend filter (`popular`, `discounted`).
  Future<void> fetchStoreRail(
    String key, {
    int categoryId = 0,
    String? sort,
  }) async {
    final int? storeId = _store?.id;
    if (storeId == null ||
        _storeRails.containsKey(key) ||
        !_storeRailsInFlight.add(key)) {
      return;
    }
    final int generation = _storeRailsGeneration;
    final ItemModel? model = await storeServiceInterface.getStoreItemList(
      storeID: storeId,
      offset: 1,
      categoryID: categoryId,
      type: _type,
      filter: {...?_filter, if (sort != null) sort}.toList(),
      rating: _rating == -1 ? null : _rating,
      lowerValue: _lowerValue == 0 ? null : _lowerValue,
      upperValue: _upperValue == 0 ? null : _upperValue,
    );
    if (generation != _storeRailsGeneration || isClosed) return;
    _storeRailsInFlight.remove(key);
    // A failed fetch lands as empty: the rail collapses rather than
    // shimmering with nothing outstanding. Pull-to-refresh retries it.
    _storeRails[key] = model?.items ?? const [];
    if (model == null) {
      _storeRailsFailed.add(key);
    } else if (model.totalSize != null) {
      _storeRailTotals[key] = model.totalSize!;
    }
    update([storeRailId(key)]);
  }

  /// Drops every rail so each refetches on its next build. Call when the
  /// filters change or the page refreshes.
  void resetStoreRails({bool notify = true}) {
    _storeRails.clear();
    _storeRailsInFlight.clear();
    _storeRailsFailed.clear();
    _storeRailTotals.clear();
    _storeRailsGeneration++;
    if (notify) update();
  }

  // ── Banners, bundles, recommendations ─────────────────────────────────

  List<StoreBannerModel>? _storeBanners;
  List<StoreBannerModel>? get storeBanners => _storeBanners;

  List<StoreBundleModel>? _storeBundleList;
  List<StoreBundleModel>? get storeBundleList => _storeBundleList;

  RecommendedItemModel? _recommendedItemModel;
  RecommendedItemModel? get recommendedItemModel => _recommendedItemModel;

  Future<void> getStoreBannerList(int? storeId) async {
    List<StoreBannerModel>? storeBanners = await storeServiceInterface
        .getStoreBannerList(storeId);
    if (isClosed) return;
    if (storeBanners != null) {
      _storeBanners = [];
      _storeBanners!.addAll(storeBanners);
    }
    update();
  }

  Future<void> getStoreBundleList(int? storeId) async {
    _storeBundleList = null;
    List<StoreBundleModel>? list = await storeServiceInterface
        .getStoreBundleList(storeId);
    if (isClosed) return;
    if (list != null) {
      _storeBundleList = [];
      _storeBundleList!.addAll(list);
    }
    update();
  }

  // ── Buy again ─────────────────────────────────────────────────────────

  static const String buyAgainId = 'store_buy_again';

  /// Null until fetched, and stays null for guests or on failure — the rail
  /// is drawn only from a real order history.
  ({int orderCount, List<BuyAgainLine> lines})? _buyAgain;
  ({int orderCount, List<BuyAgainLine> lines})? get buyAgain => _buyAgain;

  Future<void> getBuyAgain(int? storeId) async {
    _buyAgain = null;
    if (storeId == null || !Get.find<AuthController>().isLoggedIn()) {
      update([buyAgainId]);
      return;
    }
    final result = await storeServiceInterface.getBuyAgainItems(storeId);
    if (isClosed) return;
    _buyAgain = result;
    update([buyAgainId]);
  }

  Future<void> getRestaurantRecommendedItemList(
    int? storeId,
    bool reload,
  ) async {
    if (reload) {
      _recommendedItemModel = null;
      update();
    }
    RecommendedItemModel? recommendedItemModel = await storeServiceInterface
        .getStoreRecommendedItemList(storeId);
    if (isClosed) return;
    if (recommendedItemModel != null) {
      _recommendedItemModel = recommendedItemModel;
    }
    update();
  }
}
