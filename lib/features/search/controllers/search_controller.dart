import 'dart:async';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/search/domain/models/global_search_model.dart';
import 'package:waddy_app/features/search/domain/models/popular_categories_model.dart';
import 'package:waddy_app/features/search/domain/models/search_suggestion_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/search/domain/services/search_service_interface.dart';

class SearchController extends GetxController implements GetxService {
  final SearchServiceInterface searchServiceInterface;
  SearchController({required this.searchServiceInterface});

  Timer? _searchDebounce;
  Timer? _suggestionDebounce;
  static const _debounceDuration = Duration(milliseconds: 400);

  @override
  void onClose() {
    _searchDebounce?.cancel();
    _suggestionDebounce?.cancel();
    _globalDebounce?.cancel();
    super.onClose();
  }

  List<Item>? _searchItemList;
  List<Item>? get searchItemList => _searchItemList;

  List<Item>? _allItemList;
  List<Item>? get allItemList => _allItemList;

  List<Item>? _suggestedItemList;
  List<Item>? get suggestedItemList => _suggestedItemList;

  List<Store>? _searchStoreList;
  List<Store>? get searchStoreList => _searchStoreList;

  List<Store>? _allStoreList;
  List<Store>? get allStoreList => _allStoreList;

  String? _searchText = '';
  String? get searchText => _searchText;

  String? _storeResultText = '';

  String? _itemResultText = '';

  double _lowerValue = 0;
  double get lowerValue => _lowerValue;

  double _upperValue = 0;
  double get upperValue => _upperValue;

  List<String> _historyList = [];
  List<String> get historyList => _historyList;

  bool _isSearchMode = true;
  bool get isSearchMode => _isSearchMode;

  final List<String> _sortList = [
    'price_low_to_high'.tr,
    'price_high_to_low'.tr,
    'rating'.tr,
    'popularity'.tr,
    'newest'.tr,
    'a_to_z'.tr,
    'z_to_a'.tr,
  ];
  List<String> get sortList => _sortList;

  int _sortIndex = -1;
  int get sortIndex => _sortIndex;

  int _storeSortIndex = -1;
  int get storeSortIndex => _storeSortIndex;

  static const List<String> _sortByApiValues = [
    'price_low_to_high',
    'price_high_to_low',
    'rating',
    'popularity',
    'newest',
    '', // a_to_z — client-side only
    '', // z_to_a — client-side only
  ];

  String? get _currentSortByParam {
    if (_sortIndex < 0 || _sortIndex >= _sortByApiValues.length) return null;
    final v = _sortByApiValues[_sortIndex];
    return v.isEmpty ? null : v;
  }

  int _rating = -1;
  int get rating => _rating;

  int _storeRating = -1;
  int get storeRating => _storeRating;

  bool _isStore = false;
  bool get isStore => _isStore;

  bool _isAvailableItems = false;
  bool get isAvailableItems => _isAvailableItems;

  bool _isAvailableStore = false;
  bool get isAvailableStore => _isAvailableStore;

  bool _isDiscountedItems = false;
  bool get isDiscountedItems => _isDiscountedItems;

  bool _isDiscountedStore = false;
  bool get isDiscountedStore => _isDiscountedStore;

  bool _veg = false;
  bool get veg => _veg;

  bool _storeVeg = false;
  bool get storeVeg => _storeVeg;

  bool _nonVeg = false;
  bool get nonVeg => _nonVeg;

  bool _storeNonVeg = false;
  bool get storeNonVeg => _storeNonVeg;

  String? _searchHomeText = '';
  String? get searchHomeText => _searchHomeText;

  SearchSuggestionModel? _searchSuggestionModel;
  SearchSuggestionModel? get searchSuggestionModel => _searchSuggestionModel;

  List<PopularCategoryModel?>? _popularCategoryList;
  List<PopularCategoryModel?>? get popularCategoryList => _popularCategoryList;

  void toggleVeg() {
    _veg = !_veg;
    update();
  }

  void toggleStoreVeg() {
    _storeVeg = !_storeVeg;
    update();
  }

  void toggleNonVeg() {
    _nonVeg = !_nonVeg;
    update();
  }

  void toggleStoreNonVeg() {
    _storeNonVeg = !_storeNonVeg;
    update();
  }

  void toggleAvailableItems() {
    _isAvailableItems = !_isAvailableItems;
    update();
  }

  void toggleAvailableStore() {
    _isAvailableStore = !_isAvailableStore;
    update();
  }

  void toggleDiscountedItems() {
    _isDiscountedItems = !_isDiscountedItems;
    update();
  }

  void toggleDiscountedStore() {
    _isDiscountedStore = !_isDiscountedStore;
    update();
  }

  void setStore(bool isStore) {
    _isStore = isStore;
    update();
  }

  void setSearchMode(bool isSearchMode, {bool canUpdate = true}) {
    _isSearchMode = isSearchMode;
    if (isSearchMode) {
      _searchText = '';
      _itemResultText = '';
      _storeResultText = '';
      _allStoreList = null;
      _allItemList = null;
      _searchItemList = null;
      _searchStoreList = null;
      _sortIndex = -1;
      _storeSortIndex = -1;
      _isDiscountedItems = false;
      _isDiscountedStore = false;
      _isAvailableItems = false;
      _isAvailableStore = false;
      _veg = false;
      _storeVeg = false;
      _nonVeg = false;
      _storeNonVeg = false;
      _rating = -1;
      _storeRating = -1;
      _upperValue = 0;
      _lowerValue = 0;
      resetGlobal(canUpdate: false);
    }
    if (_isStore) {
      _isStore = !_isStore;
    }
    if (canUpdate) {
      update();
    }
  }

  void setLowerAndUpperValue(double lower, double upper) {
    _lowerValue = lower;
    _upperValue = upper;
    update();
  }

  void sortItemSearchList() {
    _searchItemList = searchServiceInterface.sortItemSearchList(
      _allItemList,
      _upperValue,
      _lowerValue,
      _rating,
      _veg,
      _nonVeg,
      _isAvailableItems,
      _isDiscountedItems,
      _sortIndex,
    );
    update();
  }

  void sortStoreSearchList() {
    _searchStoreList = searchServiceInterface.sortStoreSearchList(
      _allStoreList,
      _storeRating,
      _storeVeg,
      _storeNonVeg,
      _isAvailableStore,
      _isDiscountedStore,
      _storeSortIndex,
    );
    update();
  }

  void setSearchText(String text) {
    _searchText = text;
    update();
  }

  void getSuggestedItems() async {
    List<Item>? suggestedItemList =
        await searchServiceInterface.getSuggestedItems();
    if (suggestedItemList != null) {
      _suggestedItemList = [];
      _suggestedItemList!.addAll(suggestedItemList);
    }
    update();
  }

  void searchData(String? query, bool fromHome) {
    if (query == null || query.isEmpty) return;
    _searchDebounce?.cancel();
    if (fromHome) {
      _executeSearch(query, fromHome);
    } else {
      _searchDebounce = Timer(_debounceDuration, () {
        _executeSearch(query, fromHome);
      });
    }
  }

  void _executeSearch(String query, bool fromHome) async {
    if ((_isStore && query.isNotEmpty && query != _storeResultText) ||
        (!_isStore &&
            query.isNotEmpty &&
            (query != _itemResultText || fromHome))) {
      _searchHomeText = query;
      _searchText = query;
      _rating = -1;
      _storeRating = -1;
      _upperValue = 0;
      _lowerValue = 0;
      if (_isStore) {
        _searchStoreList = null;
        _allStoreList = null;
      } else {
        _searchItemList = null;
        _allItemList = null;
      }
      if (!_historyList.contains(query)) {
        _historyList.insert(0, query);
      }
      searchServiceInterface.saveSearchHistory(_historyList);
      _isSearchMode = false;
      if (!fromHome) {
        update();
      }

      Response response = await searchServiceInterface.getSearchData(
        query,
        _isStore,
        sortBy: _currentSortByParam,
      );
      if (response.statusCode == 200) {
        if (query.isEmpty) {
          if (_isStore) {
            _searchStoreList = [];
          } else {
            _searchItemList = [];
          }
        } else {
          if (_isStore) {
            _storeResultText = query;
            _searchStoreList = [];
            _allStoreList = [];
            _searchStoreList!.addAll(
              StoreModel.fromJson(response.body).stores!,
            );
            _allStoreList!.addAll(StoreModel.fromJson(response.body).stores!);
          } else {
            _itemResultText = query;
            _searchItemList = [];
            _allItemList = [];
            _searchItemList!.addAll(ItemModel.fromJson(response.body).items!);
            _allItemList!.addAll(ItemModel.fromJson(response.body).items!);
          }
        }
      }
      update();
    }
  }

  void getHistoryList() {
    _isSearchMode = true;
    _searchText = '';
    _historyList = [];
    _historyList.addAll(searchServiceInterface.getSearchAddress());
  }

  void removeHistory(int index) {
    _historyList.removeAt(index);
    searchServiceInterface.saveSearchHistory(_historyList);
    update();
  }

  void clearSearchHistory() async {
    searchServiceInterface.clearSearchHistory();
    _historyList = [];
    update();
  }

  void setRating(int rate) {
    _rating = rate;
    update();
  }

  void setStoreRating(int rate) {
    _storeRating = rate;
    update();
  }

  void setSortIndex(int index) {
    _sortIndex = index;
    update();
  }

  void setStoreSortIndex(int index) {
    _storeSortIndex = index;
    update();
  }

  void resetFilter() {
    _rating = -1;
    _upperValue = 0;
    _lowerValue = 0;
    _isAvailableItems = false;
    _isDiscountedItems = false;
    _veg = false;
    _nonVeg = false;
    _sortIndex = -1;
    update();
  }

  void resetStoreFilter() {
    _storeRating = -1;
    _isAvailableStore = false;
    _isDiscountedStore = false;
    _storeVeg = false;
    _storeNonVeg = false;
    _storeSortIndex = -1;
    update();
  }

  void clearSearchHomeText() {
    _searchHomeText = '';
    update();
  }

  Future<List<String>> getSearchSuggestions(String searchText) {
    final completer = Completer<List<String>>();
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(_debounceDuration, () async {
      List<String> items = <String>[];
      _searchSuggestionModel = await searchServiceInterface
          .getSearchSuggestions(searchText);
      if (_searchSuggestionModel != null) {
        for (var item in _searchSuggestionModel!.items!) {
          items.add(item.name ?? '');
        }
        for (var store in _searchSuggestionModel!.stores!) {
          items.add(store.name ?? '');
        }
      }
      completer.complete(items);
    });
    return completer.future;
  }

  Future<void> getPopularCategories() async {
    _popularCategoryList = null;
    _popularCategoryList = await searchServiceInterface.getPopularCategories();
    update();
  }

  // ---- Global search (the module-less Home dashboard) -------------------

  /// Null while a search is in flight, empty for "no matches".
  List<GlobalSearchStore>? _globalStores;
  List<GlobalSearchStore>? get globalStores => _globalStores;

  bool _globalFailed = false;
  bool get globalFailed => _globalFailed;

  /// The active tab; null is "All".
  SearchKind? _globalKind;
  SearchKind? get globalKind => _globalKind;

  bool _globalOffersOnly = false;
  bool get globalOffersOnly => _globalOffersOnly;

  bool _globalFreeOnly = false;
  bool get globalFreeOnly => _globalFreeOnly;

  bool _globalTopOnly = false;
  bool get globalTopOnly => _globalTopOnly;

  /// Bumped per request so a slow answer to "pi" cannot land over "pizza".
  int _globalRequest = 0;
  Timer? _globalDebounce;

  /// Runs the live search. Typed text is debounced; a picked term or a submit
  /// ([immediate]) goes straight out. History only records terms the user
  /// committed to — not every prefix passed on the way to one.
  void searchGlobal(
    String query, {
    bool immediate = false,
    bool saveHistory = false,
  }) {
    final String q = query.trim();
    _globalDebounce?.cancel();
    // The field is rewritten from this on every rebuild, so it keeps what was
    // typed — trailing space included — rather than the trimmed query.
    _searchText = query;
    if (q.isEmpty) {
      resetGlobal();
      return;
    }
    _isSearchMode = false;
    _globalStores = null;
    _globalFailed = false;
    update();

    Future<void> run() async {
      final int request = ++_globalRequest;
      if (saveHistory) {
        _historyList.remove(q);
        _historyList.insert(0, q);
        searchServiceInterface.saveSearchHistory(_historyList);
      }
      final List<GlobalSearchStore>? stores = await searchServiceInterface
          .getGlobalSearch(q);
      if (request != _globalRequest) return;
      _globalFailed = stores == null;
      _globalStores = stores ?? <GlobalSearchStore>[];
      update();
    }

    if (immediate) {
      run();
    } else {
      _globalDebounce = Timer(_debounceDuration, run);
    }
  }

  void resetGlobal({bool canUpdate = true}) {
    _globalDebounce?.cancel();
    _globalRequest++;
    _globalStores = null;
    _globalFailed = false;
    _globalKind = null;
    _globalOffersOnly = false;
    _globalFreeOnly = false;
    _globalTopOnly = false;
    if (canUpdate) {
      _isSearchMode = true;
      update();
    }
  }

  void setGlobalKind(SearchKind? kind) {
    _globalKind = kind;
    update();
  }

  void toggleGlobalOffers() {
    _globalOffersOnly = !_globalOffersOnly;
    update();
  }

  void toggleGlobalTop() {
    _globalTopOnly = !_globalTopOnly;
    update();
  }

  void toggleGlobalFree() {
    _globalFreeOnly = !_globalFreeOnly;
    update();
  }

  /// Stores passing the filter chips, before the tab narrows them: the tab
  /// counts are computed from this so they stay honest as chips change.
  List<GlobalSearchStore> get globalFiltered =>
      (_globalStores ?? const <GlobalSearchStore>[])
          .where(
            (s) =>
                (!_globalOffersOnly || s.hasOffer) &&
                (!_globalFreeOnly || s.freeDelivery) &&
                (!_globalTopOnly || s.isTopRated),
          )
          .toList();

  List<GlobalSearchStore> get globalVisible =>
      globalFiltered
          .where((s) => _globalKind == null || s.kind == _globalKind)
          .toList();

  int globalCount(SearchKind? kind) =>
      globalFiltered.where((s) => kind == null || s.kind == kind).length;
}
