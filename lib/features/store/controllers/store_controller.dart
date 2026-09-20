import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/util/parse.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/store/domain/models/cart_suggested_item_model.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/recommended_product_model.dart';
import 'package:waddy_app/features/store/domain/models/store_banner_model.dart';
import 'package:waddy_app/features/store/domain/models/store_bundle_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/review/domain/models/review_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/services/store_service_interface.dart';
import 'package:waddy_app/helper/cache_ttl_helper.dart';
import 'package:waddy_app/helper/module_helper.dart';
import 'package:waddy_app/util/app_constants.dart';

class StoreController extends GetxController implements GetxService {
  final StoreServiceInterface storeServiceInterface;
  StoreController({required this.storeServiceInterface});

  StoreModel? _storeModel;
  StoreModel? get storeModel => _storeModel;

  List<Store>? _popularStoreList;
  List<Store>? get popularStoreList => _popularStoreList;

  List<Store>? _latestStoreList;
  List<Store>? get latestStoreList => _latestStoreList;

  List<Store>? _topOfferStoreList;
  List<Store>? get topOfferStoreList => _topOfferStoreList;

  List<Store>? _featuredStoreList;
  List<Store>? get featuredStoreList => _featuredStoreList;

  List<Store>? _visitAgainStoreList;
  List<Store>? get visitAgainStoreList => _visitAgainStoreList;

  Store? _store;
  Store? get store => _store;

  ItemModel? _storeItemModel;
  ItemModel? get storeItemModel => _storeItemModel;

  ItemModel? _storeSearchItemModel;
  ItemModel? get storeSearchItemModel => _storeSearchItemModel;

  int _categoryIndex = 0;
  int get categoryIndex => _categoryIndex;

  List<CategoryModel>? _categoryList;
  List<CategoryModel>? get categoryList => _categoryList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _filterType = 'all';
  String get filterType => _filterType;

  String _storeType = 'all';
  String get storeType => _storeType;

  List<ReviewModel>? _storeReviewList;
  List<ReviewModel>? get storeReviewList => _storeReviewList;

  String _type = 'all';
  String get type => _type;

  String _searchType = 'all';
  String get searchType => _searchType;

  String _searchText = '';
  String get searchText => _searchText;

  bool _currentState = true;
  bool get currentState => _currentState;

  bool _showFavButton = true;
  bool get showFavButton => _showFavButton;

  List<XFile> _pickedPrescriptions = [];
  List<XFile> get pickedPrescriptions => _pickedPrescriptions;

  RecommendedItemModel? _recommendedItemModel;
  RecommendedItemModel? get recommendedItemModel => _recommendedItemModel;

  Map<int, List<Item>> _storeRecommendedItems = {};
  Map<int, List<Item>> get storeRecommendedItems => _storeRecommendedItems;

  CartSuggestItemModel? _cartSuggestItemModel;
  CartSuggestItemModel? get cartSuggestItemModel => _cartSuggestItemModel;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  List<StoreBannerModel>? _storeBanners;
  List<StoreBannerModel>? get storeBanners => _storeBanners;

  List<Store>? _recommendedStoreList;
  List<Store>? get recommendedStoreList => _recommendedStoreList;

  /// The dashboard's restaurant chart, ranked by how often the zone actually
  /// orders from each store. Named for the ranking because the ranking is the
  /// whole claim the numerals make.
  List<Store>? _mostOrderedFoodStores;
  List<Store>? get mostOrderedFoodStores => _mostOrderedFoodStores;

  List<Store>? _quickGroceryStores;
  List<Store>? get quickGroceryStores => _quickGroceryStores;

  String _topOfferFilter = '';
  String get topOfferFilter => _topOfferFilter;

  String _topOfferSort = '';
  String get topOfferSort => _topOfferSort;

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

  List<Store>? _similarStoreList;
  List<Store>? get similarStoreList => _similarStoreList;

  List<StoreBundleModel>? _storeBundleList;
  List<StoreBundleModel>? get storeBundleList => _storeBundleList;

  /// Kilometres between the user's saved address and [storeLatLng], or null
  /// when that cannot be computed.
  ///
  /// Two failure modes used to live on one line here: the `!` on a nullable
  /// address (absent on first run, and until the location gate resolves one)
  /// and `double.parse` on coordinate strings the server can leave null.
  /// Either threw, while building store cards.
  ///
  /// **Nullable, not a `-1` sentinel.** The delivery-charge path already
  /// carries a `-1` "not computable" marker, and §14.1 of the hardening plan
  /// records what that cost: `calculateTotal` added it blindly and knocked a
  /// pound off the displayed total. An unknown distance is absent, and the
  /// type should say so.
  double? getRestaurantDistance(LatLng storeLatLng) {
    final AddressModel? address = AddressHelper.getUserAddressFromSharedPref();
    final double? userLat = Parse.coordinate(address?.latitude);
    final double? userLng = Parse.coordinate(address?.longitude);
    if (userLat == null || userLng == null) return null;

    return Geolocator.distanceBetween(
          storeLatLng.latitude,
          storeLatLng.longitude,
          userLat,
          userLng,
        ) /
        1000;
  }

  String filteringUrl(String slug) {
    return storeServiceInterface.filterRestaurantLinkUrl(slug, _store!);
  }

  void pickPrescriptionImage({
    required bool isRemove,
    required bool isCamera,
  }) async {
    if (isRemove) {
      _pickedPrescriptions = [];
    } else {
      XFile? xFile = await ImagePicker().pickImage(
        source: isCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 50,
      );
      if (xFile != null) {
        _pickedPrescriptions.add(xFile);
      }
      update();
    }
  }

  void removePrescriptionImage(int index) {
    _pickedPrescriptions.removeAt(index);
    update();
  }

  void changeFavVisibility() {
    _showFavButton = !_showFavButton;
    update();
  }

  void hideAnimation() {
    _currentState = false;
  }

  void showButtonAnimation() {
    Future.delayed(const Duration(seconds: 3), () {
      _currentState = true;
      update();
    });
  }

  Future<void> getRestaurantRecommendedItemList(
    int? storeId,
    bool reload,
  ) async {
    if (reload) {
      _storeModel = null;
      update();
    }
    RecommendedItemModel? recommendedItemModel = await storeServiceInterface
        .getStoreRecommendedItemList(storeId);
    if (recommendedItemModel != null) {
      _recommendedItemModel = recommendedItemModel;
    }
    update();
  }

  Future<List<Item>?> fetchStoreRecommendedItems(int storeId) async {
    if (_storeRecommendedItems.containsKey(storeId)) {
      return _storeRecommendedItems[storeId];
    }

    RecommendedItemModel? recommendedItemModel = await storeServiceInterface
        .getStoreRecommendedItemList(storeId);

    if (recommendedItemModel != null && recommendedItemModel.items != null) {
      _storeRecommendedItems[storeId] = recommendedItemModel.items!;
      update();
      return recommendedItemModel.items;
    }

    return null;
  }

  Future<void> getCartStoreSuggestedItemList(int? storeId) async {
    CartSuggestItemModel? cartSuggestItemModel = await storeServiceInterface
        .getCartStoreSuggestedItemList(
          storeId,
          Get.find<LocalizationController>().locale.languageCode,
          ModuleHelper.currentModuleId(),
        );
    if (cartSuggestItemModel != null) {
      _cartSuggestItemModel = cartSuggestItemModel;
    }
    update();
  }

  Future<void> getStoreBannerList(int? storeId) async {
    List<StoreBannerModel>? storeBanners = await storeServiceInterface
        .getStoreBannerList(storeId);
    if (storeBanners != null) {
      _storeBanners = [];
      _storeBanners!.addAll(storeBanners);
    }
    update();
  }

  // Server-side browse filters set by the module home screens.
  ModuleStoreFilters _moduleFilters = const ModuleStoreFilters();
  ModuleStoreFilters get moduleFilters => _moduleFilters;

  // Monotonic sequence so a stale in-flight response (e.g. rapid chip taps)
  // can never overwrite the result of a newer request.
  int _storeListRequestSeq = 0;

  void setModuleStoreFilters(ModuleStoreFilters filters) {
    _moduleFilters = filters;
    getStoreList(1, true);
  }

  void clearModuleStoreFilters() {
    _moduleFilters = const ModuleStoreFilters();
  }

  Future<void> getStoreList(
    int offset,
    bool reload, {
    DataSourceEnum source = DataSourceEnum.local,
    int? requestSeq,
  }) async {
    final int seq = requestSeq ?? ++_storeListRequestSeq;
    if (reload) {
      _storeModel = null;
      update();
    }
    final String extraQuery = _moduleFilters.toQueryString();
    StoreModel? storeModel;
    if (source == DataSourceEnum.local && offset == 1) {
      storeModel = await storeServiceInterface.getStoreList(
        offset,
        _filterType,
        _storeType,
        source: DataSourceEnum.local,
        extraQuery: extraQuery,
      );
      if (seq == _storeListRequestSeq) {
        _prepareStoreModel(storeModel, offset);
      }
      getStoreList(
        offset,
        false,
        source: DataSourceEnum.client,
        requestSeq: seq,
      );
    } else {
      storeModel = await storeServiceInterface.getStoreList(
        offset,
        _filterType,
        _storeType,
        source: DataSourceEnum.client,
        extraQuery: extraQuery,
      );
      if (seq == _storeListRequestSeq) {
        _prepareStoreModel(storeModel, offset);
      }
    }
  }

  _prepareStoreModel(StoreModel? storeModel, int offset) {
    if (storeModel != null) {
      if (offset == 1) {
        _storeModel = storeModel;
      } else {
        _storeModel!.totalSize = storeModel.totalSize;
        _storeModel!.offset = storeModel.offset;
        _storeModel!.stores!.addAll(storeModel.stores!);
      }
      update();
    }
  }

  void setFilterType(String type) {
    _filterType = type;
    getStoreList(1, true);
  }

  void setStoreType(String type) {
    _storeType = type;
    if (type == 'for_you') {
      _getPersonalizedStores();
    } else {
      getStoreList(1, true);
    }
  }

  Future<void> _getPersonalizedStores() async {
    _storeModel = null;
    update();

    List<Store> personalizedStores = [];

    if (_visitAgainStoreList != null && _visitAgainStoreList!.isNotEmpty) {
      personalizedStores.addAll(_visitAgainStoreList!);
    }

    if (_recommendedStoreList != null && _recommendedStoreList!.isNotEmpty) {
      for (var store in _recommendedStoreList!) {
        if (!personalizedStores.any((s) => s.id == store.id)) {
          personalizedStores.add(store);
        }
      }
    }

    if (_popularStoreList != null && _popularStoreList!.isNotEmpty) {
      for (var store in _popularStoreList!) {
        if (!personalizedStores.any((s) => s.id == store.id)) {
          personalizedStores.add(store);
        }
      }
    }

    if (personalizedStores.isEmpty) {
      getStoreList(1, true);
      return;
    }

    _storeModel = StoreModel(
      totalSize: personalizedStores.length,
      offset: 1,
      stores: personalizedStores,
    );
    update();
  }

  void resetStoreData() {
    _filterType = 'all';
    _storeType = 'all';
    _moduleFilters = const ModuleStoreFilters();
  }

  Future<void> getPopularStoreList(
    bool reload,
    String type,
    bool notify, {
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    _type = type;
    if (reload) {
      _popularStoreList = null;
    }
    if (notify) {
      update();
    }
    if (_popularStoreList == null || reload || fromRecall) {
      if (dataSource == DataSourceEnum.local &&
          CacheTtlHelper.isStale(
            'popular_store_list',
            ttl: CacheTtlHelper.groceryTtl,
          )) {
        dataSource = DataSourceEnum.client;
      }
      List<Store>? popularStoreList;
      if (dataSource == DataSourceEnum.local) {
        popularStoreList = await storeServiceInterface.getPopularStoreList(
          type,
          source: DataSourceEnum.local,
        );
        if (popularStoreList != null) {
          _popularStoreList = [];
          _popularStoreList!.addAll(popularStoreList);
        }
        update();
        // No unconditional re-fetch here. This branch only runs when
        // CacheTtlHelper said the cached list is still fresh, so following the
        // local read with a network read spent two requests to end up with the
        // data we already had — on the screen that already fires ~25 of them.
        // Staleness is the trigger for going to the network, and the check
        // above already made that decision.
      } else {
        popularStoreList = await storeServiceInterface.getPopularStoreList(
          type,
          source: DataSourceEnum.client,
        );
        if (popularStoreList != null) {
          _popularStoreList = [];
          _popularStoreList!.addAll(popularStoreList);
        }
        CacheTtlHelper.markFresh('popular_store_list');
        update();
      }
    }
  }

  Future<void> getLatestStoreList(
    bool reload,
    String type,
    bool notify, {
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    _type = type;
    if (reload) {
      _latestStoreList = null;
    }
    if (notify) {
      update();
    }
    if (_latestStoreList == null || reload || fromRecall) {
      if (dataSource == DataSourceEnum.local &&
          CacheTtlHelper.isStale(
            'latest_store_list',
            ttl: CacheTtlHelper.groceryTtl,
          )) {
        dataSource = DataSourceEnum.client;
      }
      List<Store>? latestStoreList;
      if (dataSource == DataSourceEnum.local) {
        latestStoreList = await storeServiceInterface.getLatestStoreList(
          type,
          source: DataSourceEnum.local,
        );
        if (latestStoreList != null) {
          _latestStoreList = [];
          _latestStoreList!.addAll(latestStoreList);
        }
        update();
        // No unconditional re-fetch here. This branch only runs when
        // CacheTtlHelper said the cached list is still fresh, so following the
        // local read with a network read spent two requests to end up with the
        // data we already had — on the screen that already fires ~25 of them.
        // Staleness is the trigger for going to the network, and the check
        // above already made that decision.
      } else {
        latestStoreList = await storeServiceInterface.getLatestStoreList(
          type,
          source: DataSourceEnum.client,
        );
        if (latestStoreList != null) {
          _latestStoreList = [];
          _latestStoreList!.addAll(latestStoreList);
        }
        CacheTtlHelper.markFresh('latest_store_list');
        update();
      }
    }
  }

  Future<void> getTopOfferStoreList(
    bool reload,
    bool notify, {
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (reload) {
      _topOfferStoreList = null;
    }
    if (notify) {
      update();
    }
    if (_topOfferStoreList == null || reload || fromRecall) {
      if (dataSource == DataSourceEnum.local &&
          CacheTtlHelper.isStale('top_offer_store_list')) {
        dataSource = DataSourceEnum.client;
      }
      List<Store>? latestStoreList;
      if (dataSource == DataSourceEnum.local) {
        latestStoreList = await storeServiceInterface.getTopOfferStoreList(
          source: DataSourceEnum.local,
          filterBy: _topOfferFilter,
          sortBy: _topOfferSort,
        );
        if (latestStoreList != null) {
          _topOfferStoreList = [];
          _topOfferStoreList!.addAll(latestStoreList);
        }
        update();
        // No un-awaited re-fetch: the TTL check above already decided whether
        // the network is needed, and firing one here meant home's Future.wait
        // completed while this request was still outstanding.
      } else {
        latestStoreList = await storeServiceInterface.getTopOfferStoreList(
          source: DataSourceEnum.client,
          filterBy: _topOfferFilter,
          sortBy: _topOfferSort,
        );
        if (latestStoreList != null) {
          _topOfferStoreList = [];
          _topOfferStoreList!.addAll(latestStoreList);
        }
        CacheTtlHelper.markFresh('top_offer_store_list');
        update();
      }
    }
  }

  void setTopOfferFilter(String type) {
    _topOfferFilter = type;
    getTopOfferStoreList(true, false);
  }

  void setTopOfferSort(String sort) {
    _topOfferSort = sort;
    getTopOfferStoreList(true, false);
  }

  Future<void> getFeaturedStoreList({
    DataSourceEnum dataSource = DataSourceEnum.local,
  }) async {
    List<Store>? stores;
    if (dataSource == DataSourceEnum.local) {
      stores = await storeServiceInterface.getFeaturedStoreList(
        source: dataSource,
      );
      _prepareFeaturedStore(stores);
      // Awaited so callers that chain on the featured list (the dashboard's
      // per-store recommended-items fan-out) see the fresh list, not just
      // whatever the cache held. The cache render above already painted.
      await getFeaturedStoreList(dataSource: DataSourceEnum.client);
    } else {
      stores = await storeServiceInterface.getFeaturedStoreList(
        source: dataSource,
      );
      _prepareFeaturedStore(stores);
    }
  }

  /// Dashboard-only: the two store rails on the aggregated home — the
  /// restaurant chart (ranked by orders) and the grocery shelf (ranked by
  /// delivery time). One call, because they load and fail together.
  ///
  /// One failing rail no longer takes the other down — both are awaited and
  /// whatever arrived is painted — but the failure is no longer swallowed
  /// either. It used to be, and the two rails render nothing when their list
  /// is empty, so a failed fetch was indistinguishable from a zone with no
  /// stores: the chart simply wasn't there, with no error row and no retry.
  /// Rethrowing hands the failure to HomeScreen's `_safe`, which is what puts
  /// the retry row in the rail's slot.
  Future<void> getDashboardQuickStoreLists({bool reload = false}) async {
    final modules = Get.find<SplashController>().moduleList;
    if (modules == null) return;

    int? foodId, groceryId;
    for (final module in modules) {
      if (module.type == ModuleType.food) foodId = module.id;
      if (module.type == ModuleType.grocery) groceryId = module.id;
    }

    Object? failure;
    Future<void> fetch(
      int moduleId, {
      required bool mostOrdered,
      required void Function(List<Store>?) assign,
    }) async {
      // Cache-first, like every other list on this screen. These two rails
      // were the last network-only ones: home's initState fires on every
      // remount (tab hops, module resume, the PageView rebuilding), so each
      // return to the dashboard re-requested both of them, replaced both store
      // lists with freshly parsed objects, and rebuilt every card and every
      // image widget in them — to paint the same stores in the same order.
      // Inside the TTL the cached rows are served from disk and nothing goes
      // out at all; pull-to-refresh still passes reload and goes to the wire.
      final String ttlKey =
          'dashboard_rail_${mostOrdered ? 'most_ordered' : 'quick'}_$moduleId';
      DataSourceEnum source =
          (reload || CacheTtlHelper.isStale(ttlKey))
              ? DataSourceEnum.client
              : DataSourceEnum.local;
      try {
        List<Store>? stores = await storeServiceInterface
            .getDashboardRailStoreList(
              moduleId: moduleId,
              mostOrdered: mostOrdered,
              source: source,
            );
        // A fresh stamp is not proof the row is there — the cache write is
        // fire-and-forget and the store can be cleared under us. An empty
        // local read falls through to the network rather than blanking a rail
        // that has data waiting for it.
        if (source == DataSourceEnum.local && stores == null) {
          source = DataSourceEnum.client;
          stores = await storeServiceInterface.getDashboardRailStoreList(
            moduleId: moduleId,
            mostOrdered: mostOrdered,
            source: source,
          );
        }
        if (source == DataSourceEnum.client && stores != null) {
          CacheTtlHelper.markFresh(ttlKey);
        }
        // Two rails, two rankings: the chart is ordered by how often the zone
        // orders from each store, the shelf by how fast it arrives.
        assign(
          mostOrdered ? _rankByOrders(stores) : _sortByDeliveryTime(stores),
        );
      } catch (e) {
        failure ??= e;
      }
    }

    await Future.wait([
      if (foodId != null)
        fetch(
          foodId,
          mostOrdered: true,
          assign: (stores) => _mostOrderedFoodStores = stores,
        ),
      if (groceryId != null)
        fetch(
          groceryId,
          mostOrdered: false,
          assign: (stores) => _quickGroceryStores = stores,
        ),
    ]);
    update();
    if (failure != null) throw failure!;
  }

  /// The chart's ranking: open first, then most-ordered, then best-rated,
  /// then whatever order the server sent.
  ///
  /// The order count is the server's ranking already, so re-applying it here
  /// changes nothing on a live catalogue — it is the two tiebreaks that earn
  /// this. A brand-new zone has no order history at all (every store comes
  /// back with `orders_count: 0`), and a chart that falls back to row order
  /// under a "most ordered" subtitle is a list of numerals with nothing behind
  /// them. Rating is the next-best evidence of the same thing, and it is
  /// deterministic — the same stores rank the same way on every load.
  ///
  /// Closed stores drop to the bottom rather than out: they are still the
  /// zone's most-ordered places, they just should not hold the top of a list
  /// the user can't order from tonight.
  List<Store>? _rankByOrders(List<Store>? stores) {
    if (stores == null) return null;
    // Only rank on the count when the payload actually carries it — an older
    // backend that doesn't send `orders_count` would otherwise score every
    // store 0 and hand the whole ranking to the rating tiebreak.
    final bool hasCounts = stores.any((store) => store.ordersCount != null);
    final List<MapEntry<int, Store>> ranked = [
      for (int i = 0; i < stores.length; i++) MapEntry(i, stores[i]),
    ];
    ranked.sort((a, b) {
      final int openCmp = ((b.value.open ?? 0) > 0 ? 1 : 0).compareTo(
        (a.value.open ?? 0) > 0 ? 1 : 0,
      );
      if (openCmp != 0) return openCmp;
      if (hasCounts) {
        final int orderCmp = (b.value.ordersCount ?? 0).compareTo(
          a.value.ordersCount ?? 0,
        );
        if (orderCmp != 0) return orderCmp;
      }
      final int ratingCmp = (b.value.avgRating ?? 0).compareTo(
        a.value.avgRating ?? 0,
      );
      if (ratingCmp != 0) return ratingCmp;
      // Dart's sort is not documented as stable; the original index keeps the
      // server's order as the last word instead of leaving it to chance.
      return a.key.compareTo(b.key);
    });
    return [for (final entry in ranked) entry.value];
  }

  List<Store>? _sortByDeliveryTime(List<Store>? stores) {
    if (stores == null) return null;
    int minutes(Store store) =>
        int.tryParse(
          RegExp(r'\d+').firstMatch(store.deliveryTime ?? '')?.group(0) ?? '',
        ) ??
        999;
    return List<Store>.of(stores)
      ..sort((a, b) => minutes(a).compareTo(minutes(b)));
  }

  /// Keeps the featured stores the user's address can actually order from.
  ///
  /// The zone-module pivot is the filter, but it is only *evidence* — the
  /// pivot rows come from the address cached in shared prefs, so they are
  /// missing entirely before the first zone fetch, after a cache clear, and
  /// on any payload the backend sends without a nested `pivot`. This used to
  /// dereference `module.pivot!` and match on it unconditionally, which meant
  /// a thin or stale cache didn't degrade the list — it emptied it, and every
  /// rail fed by featured stores rendered as nothing at all. A store shown
  /// that the user can't order from is a bad row; a home screen with no rows
  /// looks broken.
  ///
  /// So: filter only when there is something to filter with. Stores whose
  /// module has no pivot data are kept, and a filter that would reject
  /// everything is treated as bad evidence and discarded.
  _prepareFeaturedStore(List<Store>? stores) {
    if (stores != null) {
      final List<Modules> moduleList = storeServiceInterface.moduleList();

      // Zones served per module, from whatever pivot rows the cache holds.
      // A module absent from this map has no zone evidence at all.
      final Map<int, Set<int>> zonesByModule = {};
      for (final module in moduleList) {
        final int? moduleId = module.id;
        final int? zoneId = module.pivot?.zoneId;
        if (moduleId == null || zoneId == null) continue;
        zonesByModule.putIfAbsent(moduleId, () => <int>{}).add(zoneId);
      }

      final List<Store> inZone = [];
      for (final Store store in stores) {
        final Set<int>? zones = zonesByModule[store.moduleId];
        // No pivot rows for this module, or the store didn't say which zone
        // it belongs to — nothing to check against, so keep it rather than
        // dropping it on an unproven mismatch.
        if (zones == null || store.zoneId == null) {
          inZone.add(store);
        } else if (zones.contains(store.zoneId)) {
          inZone.add(store);
        }
      }

      // The backend already scopes this endpoint by zone header. If the local
      // pivot data disagrees with every single store it is the local data that
      // is stale, not the whole catalogue that is out of zone.
      _featuredStoreList = inZone.isEmpty ? stores : inZone;
    }
    update();
  }

  Future<void> getVisitAgainStoreList({
    bool fromModule = false,
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (fromModule && !fromRecall) {
      _visitAgainStoreList = null;
    }
    // Serve the cache only while it is fresh; otherwise fall through to the
    // network. The re-fetch that used to follow the local read was NOT awaited,
    // so home's Future.wait reported the whole batch complete while this call
    // was still in flight — which is why the load summary printed a request
    // count lower than the log showed, and why the quiet-window stamp could be
    // set on data that had not arrived.
    if (dataSource == DataSourceEnum.local &&
        CacheTtlHelper.isStale('visit_again_store_list')) {
      dataSource = DataSourceEnum.client;
    }
    List<Store>? stores;
    if (dataSource == DataSourceEnum.local) {
      stores = await storeServiceInterface.getVisitAgainStoreList(
        source: DataSourceEnum.local,
      );
      _prepareVisitAgainStore(stores);
    } else {
      stores = await storeServiceInterface.getVisitAgainStoreList(
        source: DataSourceEnum.client,
      );
      _prepareVisitAgainStore(stores);
      CacheTtlHelper.markFresh('visit_again_store_list');
    }
  }

  _prepareVisitAgainStore(List<Store>? stores) {
    if (stores != null) {
      _visitAgainStoreList = [];
      List<Modules> moduleList = [];
      moduleList.addAll(storeServiceInterface.moduleList());
      for (var store in stores) {
        for (var module in moduleList) {
          if (module.id == store.moduleId) {
            if (module.pivot!.zoneId == store.zoneId) {
              _visitAgainStoreList!.add(store);
            }
          }
        }
      }
    }
    update();
  }

  void setCategoryList() {
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

  Future<Store?> getStoreDetails(
    Store store,
    bool fromModule, {
    bool fromCart = false,
    String slug = '',
  }) async {
    _categoryIndex = 0;
    if (store.name != null) {
      _store = store;
    } else {
      _isLoading = true;
      _store = null;
      Store? storeDetails = await storeServiceInterface.getStoreDetails(
        store.id.toString(),
        fromCart,
        slug,
        Get.find<LocalizationController>().locale.languageCode,
        ModuleHelper.currentModuleId(),
      );
      if (storeDetails != null) {
        _store = storeDetails;
        Get.find<CheckoutController>().initializeTimeSlot(_store!);
        if (!fromCart && slug.isEmpty) {
          Get.find<CheckoutController>().getDistanceInKM(
            LatLng(
              double.parse(
                AddressHelper.getUserAddressFromSharedPref()!.latitude!,
              ),
              double.parse(
                AddressHelper.getUserAddressFromSharedPref()!.longitude!,
              ),
            ),
            LatLng(
              double.parse(_store!.latitude!),
              double.parse(_store!.longitude!),
            ),
          );
        }
        if (slug.isNotEmpty) {
          await Get.find<LocationController>().setStoreAddressToUserAddress(
            LatLng(
              double.parse(_store!.latitude!),
              double.parse(_store!.longitude!),
            ),
          );
        }
        if (fromModule) {
          HomeScreen.loadData(true);
        } else {
          Get.find<CheckoutController>().clearPrevData();
        }
      }
      Get.find<CheckoutController>().setOrderType(
        _store != null
            ? _store!.delivery!
                ? 'delivery'
                : 'take_away'
            : 'delivery',
        notify: false,
      );
      _isLoading = false;
      update();
    }
    return _store;
  }

  Future<void> getRecommendedStoreList({
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (!fromRecall) {
      _recommendedStoreList = null;
    }
    if (dataSource == DataSourceEnum.local &&
        CacheTtlHelper.isStale('recommended_store_list')) {
      dataSource = DataSourceEnum.client;
    }
    List<Store>? recommendedStoreList;
    if (dataSource == DataSourceEnum.local) {
      recommendedStoreList = await storeServiceInterface
          .getRecommendedStoreList(source: DataSourceEnum.local);
      _prepareRecommendedStores(recommendedStoreList);
    } else {
      recommendedStoreList = await storeServiceInterface
          .getRecommendedStoreList(source: DataSourceEnum.client);
      _prepareRecommendedStores(recommendedStoreList);
      CacheTtlHelper.markFresh('recommended_store_list');
    }
  }

  _prepareRecommendedStores(List<Store>? recommendedStoreList) {
    if (recommendedStoreList != null) {
      _recommendedStoreList = [];
      _recommendedStoreList!.addAll(recommendedStoreList);
    }
    update();
  }

  Future<void> getStoreItemList(
    int? storeID,
    int offset,
    String type,
    bool notify,
  ) async {
    if (offset == 1 || _storeItemModel == null) {
      _type = type;
      _storeItemModel = null;
      if (notify) {
        update();
      }
    }
    ItemModel? storeItemModel = await storeServiceInterface.getStoreItemList(
      storeID: storeID,
      offset: offset,
      categoryID:
          (_store != null &&
                  _store!.categoryIds!.isNotEmpty &&
                  _categoryIndex != 0)
              ? _categoryList![_categoryIndex].id
              : 0,
      type: type,
      filter: _filter,
      rating: _rating == -1 ? null : _rating,
      lowerValue: _lowerValue == 0 ? null : _lowerValue,
      upperValue: _upperValue == 0 ? null : _upperValue,
    );
    if (storeItemModel != null) {
      if (offset == 1) {
        _storeItemModel = storeItemModel;
      } else {
        _storeItemModel!.items!.addAll(storeItemModel.items!);
        _storeItemModel!.totalSize = storeItemModel.totalSize;
        _storeItemModel!.offset = storeItemModel.offset;
      }
    }
    update();
  }

  Future<void> getStoreSearchItemList(
    String searchText,
    String? storeID,
    int offset,
    String type,
  ) async {
    if (searchText.isEmpty) {
      showCustomSnackBar('write_item_name'.tr);
    } else {
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
            (_store != null &&
                    _store!.categoryIds!.isNotEmpty &&
                    _categoryIndex != 0)
                ? _categoryList![_categoryIndex].id
                : 0,
          );
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
  }

  void changeSearchStatus({bool isUpdate = true}) {
    _isSearching = !_isSearching;
    if (isUpdate) {
      update();
    }
  }

  void initSearchData() {
    _storeSearchItemModel = ItemModel(items: []);
    _searchText = '';
  }

  void setCategoryIndex(int index, {bool itemSearching = false}) {
    _categoryIndex = index;
    if (itemSearching) {
      _storeSearchItemModel = null;
      getStoreSearchItemList(_searchText, _store!.id.toString(), 1, type);
    } else {
      _storeItemModel = null;
      getStoreItemList(_store!.id, 1, Get.find<StoreController>().type, false);
    }
    update();
  }

  bool isStoreClosed(bool today, bool active, List<Schedules>? schedules) {
    if (!active) {
      return true;
    }
    DateTime date = DateTime.now();
    if (!today) {
      date = date.add(const Duration(days: 1));
    }
    int weekday = date.weekday;
    if (weekday == 7) {
      weekday = 0;
    }
    for (int index = 0; index < schedules!.length; index++) {
      if (weekday == schedules[index].day) {
        return false;
      }
    }
    return true;
  }

  bool isStoreOpenNow(bool active, List<Schedules>? schedules) {
    if (isStoreClosed(true, active, schedules)) {
      return false;
    }
    int weekday = DateTime.now().weekday;
    if (weekday == 7) {
      weekday = 0;
    }
    for (int index = 0; index < schedules!.length; index++) {
      if (weekday == schedules[index].day &&
          DateConverter.isAvailable(
            schedules[index].openingTime,
            schedules[index].closingTime,
          )) {
        return true;
      }
    }
    return false;
  }

  bool isOpenNow(Store store) => store.open == 1 && store.active!;

  double? getDiscount(Store store) =>
      store.discount != null ? store.discount!.discount : 0;

  String? getDiscountType(Store store) =>
      store.discount != null ? store.discount!.discountType : 'percent';

  void shareStore() {
    String shareUrl =
        '${AppConstants.webHostedUrl}${filteringUrl(store!.slug ?? '')}';
    Share.share(shareUrl);
  }

  void setRating(int rate) {
    _rating = rate;
    update();
  }

  void setLowerValue(double value) {
    _lowerValue = value;
    update();
  }

  void setUpperValue(double value) {
    _upperValue = value;
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

  Future<void> getSimilarStoreList(int? storeId) async {
    _similarStoreList = null;
    List<Store>? list = await storeServiceInterface.getSimilarStoreList(
      storeId,
    );
    if (list != null) {
      _similarStoreList = [];
      _similarStoreList!.addAll(list);
    }
    update();
  }

  Future<void> getStoreBundleList(int? storeId) async {
    _storeBundleList = null;
    List<StoreBundleModel>? list = await storeServiceInterface
        .getStoreBundleList(storeId);
    if (list != null) {
      _storeBundleList = [];
      _storeBundleList!.addAll(list);
    }
    update();
  }
}

/// Server-side browse filters for module home screens; rendered into the
/// get-stores query string (backend: filter/sort/category_id/max_delivery_time).
class ModuleStoreFilters {
  final bool offers;
  final bool freeDelivery;
  final int? maxDeliveryTime;
  final String? sort; // rating | distance | a_z
  final int? categoryId;

  /// Food groups stores by cuisine rather than category; the two never apply
  /// at once, but the field is separate because the query params differ.
  final int? cuisineId;

  const ModuleStoreFilters({
    this.offers = false,
    this.freeDelivery = false,
    this.maxDeliveryTime,
    this.sort,
    this.categoryId,
    this.cuisineId,
  });

  /// Sentinel for [copyWith]: distinguishes "leave this field alone" from
  /// "set this field to null", which a plain nullable parameter cannot.
  static const Object _unchanged = Object();

  /// One field changed, the rest carried over.
  ///
  /// The food home used to rebuild this object from five `setState` fields it
  /// kept alongside the controller's copy — which is exactly how the two came
  /// to disagree. Handlers now start from the current filters and change the
  /// one thing they are about.
  ModuleStoreFilters copyWith({
    bool? offers,
    bool? freeDelivery,
    Object? maxDeliveryTime = _unchanged,
    Object? sort = _unchanged,
    Object? categoryId = _unchanged,
    Object? cuisineId = _unchanged,
  }) {
    return ModuleStoreFilters(
      offers: offers ?? this.offers,
      freeDelivery: freeDelivery ?? this.freeDelivery,
      maxDeliveryTime:
          identical(maxDeliveryTime, _unchanged)
              ? this.maxDeliveryTime
              : maxDeliveryTime as int?,
      sort: identical(sort, _unchanged) ? this.sort : sort as String?,
      categoryId:
          identical(categoryId, _unchanged)
              ? this.categoryId
              : categoryId as int?,
      cuisineId:
          identical(cuisineId, _unchanged) ? this.cuisineId : cuisineId as int?,
    );
  }

  bool get isActive =>
      offers ||
      freeDelivery ||
      maxDeliveryTime != null ||
      sort != null ||
      categoryId != null ||
      cuisineId != null;

  String toQueryString() {
    if (!isActive) return '';
    final parts = <String>[];
    final filters = <String>[
      if (offers) 'discounted',
      if (freeDelivery) 'free_delivery',
    ];
    if (filters.isNotEmpty) parts.add('filter=[${filters.join(',')}]');
    if (maxDeliveryTime != null)
      parts.add('max_delivery_time=$maxDeliveryTime');
    if (sort != null) parts.add('sort=$sort');
    if (categoryId != null) parts.add('category_id=$categoryId');
    if (cuisineId != null) parts.add('cuisine_id=$cuisineId');
    return '&${parts.join('&')}';
  }
}
