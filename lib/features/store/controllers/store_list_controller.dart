import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/store/domain/models/cart_suggested_item_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/recommended_product_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/services/store_service_interface.dart';
import 'package:waddy_app/helper/cache_ttl_helper.dart';
import 'package:waddy_app/helper/module_helper.dart';

/// The app's store LISTS: the module homes' paginated list and its filters,
/// the dashboard rails, popular / latest / featured / top-offer / visit-again
/// / recommended, per-store recommended items and the cart's suggestions.
///
/// It was `StoreController`, which also held one store page's state and the
/// store the cart was about (ST-01, ST-02). Those moved to
/// `StorePageController` (one per open store page) and
/// `CartController.cartStore`; the rename says what is left. Every update here
/// is scoped by list id — see "Rebuild ids" below.
class StoreListController extends GetxController implements GetxService {
  final StoreServiceInterface storeServiceInterface;
  StoreListController({required this.storeServiceInterface});

  // ── Rebuild ids (ST-07, Phase 6) ──────────────────────────────────────
  //
  // Every update names the builders it concerns. A bare `update()` used to
  // rebuild every store builder on home — about 30 — for each of the ~15
  // list fetches a home load makes, which is the BUILD-bound home frames in
  // the device logs. A builder takes exactly one id, so a builder that draws
  // two lists has an id of its own that both lists' updates name.
  //
  // GetX trap (memory: getx-builder-scoping): an id builder ignores a bare
  // `update()`, and a builder without an id ignores `update([ids])`. Every
  // builder on this controller has an id, and no update here is bare — both
  // pinned by test/unit/store_list_scoping_test.dart.

  /// The module home's paginated store list and its filters (`storeModel`,
  /// `moduleFilters`, `filterType`, `storeType`).
  static const String storeListId = 'store_list';
  static const String popularId = 'popular_stores';
  static const String latestId = 'latest_stores';
  static const String topOfferId = 'top_offer_stores';
  static const String featuredId = 'featured_stores';
  static const String visitAgainId = 'visit_again_stores';
  static const String recommendedId = 'recommended_stores';

  /// The dashboard's two store rails (most-ordered food, quick grocery).
  static const String dashboardRailsId = 'dashboard_rails';

  /// Per-store recommended items on the store cards.
  static const String storeRecommendedItemsId = 'store_recommended_items';

  /// The cart screen's "complete your meal" suggestions.
  static const String cartSuggestId = 'cart_suggest';

  /// Builders that draw popular AND latest (best-nearby, top brands).
  static const String popularLatestId = 'popular_latest_stores';

  /// Builders that draw popular AND featured (best-store-nearby).
  static const String popularFeaturedId = 'popular_featured_stores';

  /// The cuisine/store-type strip: its selection is list filter state, and
  /// its tile logos come from the popular or latest list.
  static const String cuisineStripId = 'cuisine_strip';

  /// "All stores" screen: every list plus the store-list `type`.
  static const String allStoresId = 'all_stores';

  static const List<Object> _storeListIds = [storeListId, cuisineStripId];
  static const List<Object> _popularIds = [
    popularId,
    popularLatestId,
    popularFeaturedId,
    cuisineStripId,
    allStoresId,
  ];
  static const List<Object> _latestIds = [
    latestId,
    popularLatestId,
    cuisineStripId,
    allStoresId,
  ];
  static const List<Object> _topOfferIds = [topOfferId, allStoresId];
  static const List<Object> _featuredIds = [
    featuredId,
    popularFeaturedId,
    allStoresId,
  ];
  static const List<Object> _visitAgainIds = [visitAgainId];
  static const List<Object> _recommendedIds = [recommendedId, allStoresId];
  static const List<Object> _dashboardRailsIds = [dashboardRailsId];
  static const List<Object> _storeRecommendedItemsIds = [
    storeRecommendedItemsId,
  ];
  static const List<Object> _cartSuggestIds = [cartSuggestId];

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

  /// "Order again" inside a module home: that module's stores.
  List<Store>? _visitAgainStoreList;
  List<Store>? get visitAgainStoreList => _visitAgainStoreList;

  /// "Order again" on the module-less dashboard: every module's stores.
  ///
  /// Its own list, not [visitAgainStoreList]: the two used to share one field,
  /// so opening Food replaced the dashboard's row with food-only stores.
  List<Store>? _dashboardVisitAgainStoreList;
  List<Store>? get dashboardVisitAgainStoreList =>
      _dashboardVisitAgainStoreList;

  String _filterType = 'all';
  String get filterType => _filterType;

  String _storeType = 'all';
  String get storeType => _storeType;

  String _type = 'all';
  String get type => _type;

  Map<int, List<Item>> _storeRecommendedItems = {};
  Map<int, List<Item>> get storeRecommendedItems => _storeRecommendedItems;

  CartSuggestItemModel? _cartSuggestItemModel;
  CartSuggestItemModel? get cartSuggestItemModel => _cartSuggestItemModel;

  List<Store>? _recommendedStoreList;
  List<Store>? get recommendedStoreList => _recommendedStoreList;

  /// The dashboard's restaurant chart, ranked by how often the zone actually
  /// orders from each store. Named for the ranking because the ranking is the
  /// whole claim the numerals make.
  List<Store>? _mostOrderedFoodStores;
  List<Store>? get mostOrderedFoodStores => _mostOrderedFoodStores;

  List<Store>? _quickGroceryStores;
  List<Store>? get quickGroceryStores => _quickGroceryStores;

  Future<List<Item>?> fetchStoreRecommendedItems(int storeId) async {
    if (_storeRecommendedItems.containsKey(storeId)) {
      return _storeRecommendedItems[storeId];
    }

    RecommendedItemModel? recommendedItemModel = await storeServiceInterface
        .getStoreRecommendedItemList(storeId);

    if (recommendedItemModel != null && recommendedItemModel.items != null) {
      _storeRecommendedItems[storeId] = recommendedItemModel.items!;
      update(_storeRecommendedItemsIds);
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
    update(_cartSuggestIds);
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
      update(_storeListIds);
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
        // `resolveEmpty` on the client leg only. A `reload` nulls the model to
        // raise the shimmer, and _prepareStoreModel ignores a null response —
        // so a client read that came back empty (or was dropped) left the list
        // null and shimmering with nothing else on the way. The local leg must
        // NOT resolve: a cache miss there is answered by the client call it
        // chains into, and painting "no stores" first would flash an empty
        // list on every cold start.
        _prepareStoreModel(storeModel, offset, resolveEmpty: true);
      }
    }
  }

  _prepareStoreModel(
    StoreModel? storeModel,
    int offset, {
    bool resolveEmpty = false,
  }) {
    if (storeModel == null) {
      // The list widget reads a null model as "still loading". Leaving it null
      // after the call that was meant to fill it is what keeps a shimmer up
      // for the life of the screen; an empty model renders the empty state.
      if (resolveEmpty && offset == 1 && _storeModel == null) {
        _storeModel = StoreModel(totalSize: 0, offset: 1, stores: []);
        update(_storeListIds);
      }
      return;
    }
    if (offset == 1) {
      _storeModel = storeModel;
    } else {
      _storeModel!.totalSize = storeModel.totalSize;
      _storeModel!.offset = storeModel.offset;
      _storeModel!.stores!.addAll(storeModel.stores!);
    }
    update(_storeListIds);
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
    update(_storeListIds);

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
    update(_storeListIds);
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
      update(_popularIds);
    }
    if (_popularStoreList == null || reload || fromRecall) {
      if (dataSource == DataSourceEnum.local &&
          CacheTtlHelper.isStale(
            _moduleTtlKey('popular_store_list'),
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
        update(_popularIds);
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
        CacheTtlHelper.markFresh(_moduleTtlKey('popular_store_list'));
        update(_popularIds);
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
      update(_latestIds);
    }
    if (_latestStoreList == null || reload || fromRecall) {
      if (dataSource == DataSourceEnum.local &&
          CacheTtlHelper.isStale(
            _moduleTtlKey('latest_store_list'),
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
        update(_latestIds);
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
        CacheTtlHelper.markFresh(_moduleTtlKey('latest_store_list'));
        update(_latestIds);
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
      update(_topOfferIds);
    }
    if (_topOfferStoreList == null || reload || fromRecall) {
      if (dataSource == DataSourceEnum.local &&
          CacheTtlHelper.isStale(_moduleTtlKey('top_offer_store_list'))) {
        dataSource = DataSourceEnum.client;
      }
      List<Store>? latestStoreList;
      if (dataSource == DataSourceEnum.local) {
        latestStoreList = await storeServiceInterface.getTopOfferStoreList(
          source: DataSourceEnum.local,
          filterBy: '',
          sortBy: '',
        );
        if (latestStoreList != null) {
          _topOfferStoreList = [];
          _topOfferStoreList!.addAll(latestStoreList);
        }
        update(_topOfferIds);
        // No un-awaited re-fetch: the TTL check above already decided whether
        // the network is needed, and firing one here meant home's Future.wait
        // completed while this request was still outstanding.
      } else {
        latestStoreList = await storeServiceInterface.getTopOfferStoreList(
          source: DataSourceEnum.client,
          filterBy: '',
          sortBy: '',
        );
        if (latestStoreList != null) {
          _topOfferStoreList = [];
          _topOfferStoreList!.addAll(latestStoreList);
        }
        CacheTtlHelper.markFresh(_moduleTtlKey('top_offer_store_list'));
        update(_topOfferIds);
      }
    }
  }

  /// Coalesces concurrent featured-store fetches.
  ///
  /// The cold-load trace showed `/api/v1/stores/get-stores/all` going out three
  /// times for 91.7 KB. Several rails want this list and each asked for it; a
  /// caller arriving while a fetch is in flight now joins it.
  ///
  /// Same pattern as `CartController.getCartDataOnline` and
  /// `SplashController.getModules`.
  Future<void>? _featuredFetchInFlight;

  Future<void> getFeaturedStoreList({
    DataSourceEnum dataSource = DataSourceEnum.local,
  }) {
    final Future<void>? inFlight = _featuredFetchInFlight;
    if (inFlight != null) return inFlight;

    late final Future<void> fetch;
    fetch = _getFeaturedStoreList(dataSource: dataSource).whenComplete(() {
      if (identical(_featuredFetchInFlight, fetch)) {
        _featuredFetchInFlight = null;
      }
    });
    _featuredFetchInFlight = fetch;
    return fetch;
  }

  Future<void> _getFeaturedStoreList({
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
      //
      // Straight to `_getFeaturedStoreList`, NOT back through the coalescing
      // wrapper: that wrapper's in-flight future is *this* call, which has not
      // completed, so going through it returned this same future and awaited
      // it — a fetch waiting on itself. The client request was never sent and
      // the rails sat on whatever the cache held, or on null forever when it
      // held nothing.
      await _getFeaturedStoreList(dataSource: DataSourceEnum.client);
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
    update(_dashboardRailsIds);
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
      _featuredStoreList = _inServedZones(stores);
    }
    update(_featuredIds);
  }

  /// [stores] that the user's address can order from, by the zone-module
  /// pivot rows cached with the address.
  ///
  /// The pivot is only *evidence*: it is missing before the first zone fetch,
  /// after a cache clear, and on payloads without a nested `pivot`. So a store
  /// whose module has no zone evidence is kept, and a filter that would
  /// reject every store is treated as stale evidence and dropped — the
  /// backend already scopes these endpoints by the zone header. Shared by the
  /// featured and "Order again" lists; the latter used to dereference
  /// `module.pivot!` and, on a missing pivot, threw inside a swallowed home
  /// section, so the rail silently never appeared.
  List<Store> _inServedZones(List<Store> stores) {
    final List<Modules> moduleList = storeServiceInterface.moduleList();
    final Map<int, Set<int>> zonesByModule = {};
    for (final module in moduleList) {
      final int? moduleId = module.id;
      final int? zoneId = module.pivot?.zoneId;
      if (moduleId == null || zoneId == null) continue;
      zonesByModule.putIfAbsent(moduleId, () => <int>{}).add(zoneId);
    }
    final List<Store> inZone = [
      for (final Store store in stores)
        if (zonesByModule[store.moduleId] == null ||
            store.zoneId == null ||
            zonesByModule[store.moduleId]!.contains(store.zoneId))
          store,
    ];
    return inZone.isEmpty ? stores : inZone;
  }

  /// A freshness stamp scoped to the module whose payload it describes.
  ///
  /// Every store cache in StoreRepository is keyed per module, so a stamp that
  /// is not keyed the same way lets one module's fresh stamp send another
  /// module down the local branch — to a cache entry that was never written
  /// for it. The read returns null, the `_prepare*` methods ignore null, and
  /// the rail stays null with nothing on the way to correct it.
  ///
  /// Read through `ModuleHelper.currentModuleId()` so it matches the
  /// repository's own key exactly, including the fallback to the last module
  /// in play when the dashboard has no module of its own.
  static String _moduleTtlKey(String base) =>
      '${base}_${ModuleHelper.currentModuleId() ?? 'none'}';

  Future<void> getVisitAgainStoreList({
    bool fromModule = false,
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    // Which list this load fills is decided now, from the module the request
    // will carry: a reply that lands after the user has switched still
    // belongs to the screen it was asked for.
    final bool dashboard = ModuleHelper.getModule() == null;
    if (fromModule && !fromRecall) {
      if (dashboard) {
        _dashboardVisitAgainStoreList = null;
      } else {
        _visitAgainStoreList = null;
      }
    }
    // Serve the cache only while it is fresh; otherwise fall through to the
    // network. The re-fetch that used to follow the local read was NOT awaited,
    // so home's Future.wait reported the whole batch complete while this call
    // was still in flight — which is why the load summary printed a request
    // count lower than the log showed, and why the quiet-window stamp could be
    // set on data that had not arrived.
    // The cached payload is keyed per module (see StoreRepository, which keys
    // it on `ModuleHelper.currentModuleId()`), so the freshness stamp has to
    // be keyed the same way and from the same source. A single global key let
    // a fresh stamp written under one module — including the `none` of a
    // module-less dashboard load — send the next module down the local branch,
    // where it read a cache entry that was never written for it. The local
    // read returns null, _prepareVisitAgainStore ignores null, and the rail
    // stays null with no network call on the way to correct it: Order Again
    // silently never appears. Same bug the category list already fixed.
    //
    // Keyed like the repository's cache entry: on the module the request
    // carries (`none` on the dashboard), not `currentModuleId()`'s fallback.
    final String ttlKey =
        'visit_again_store_list_${ModuleHelper.getModule()?.id ?? 'none'}';
    if (dataSource == DataSourceEnum.local && CacheTtlHelper.isStale(ttlKey)) {
      dataSource = DataSourceEnum.client;
    }
    List<Store>? stores;
    if (dataSource == DataSourceEnum.local) {
      stores = await storeServiceInterface.getVisitAgainStoreList(
        source: DataSourceEnum.local,
      );
      _prepareVisitAgainStore(stores, dashboard: dashboard);
    } else {
      stores = await storeServiceInterface.getVisitAgainStoreList(
        source: DataSourceEnum.client,
      );
      _prepareVisitAgainStore(stores, dashboard: dashboard);
      // Only stamp a fetch that actually produced a payload to cache. Stamping
      // a failed call would mark an entry fresh that was never written.
      if (stores != null) CacheTtlHelper.markFresh(ttlKey);
    }
  }

  _prepareVisitAgainStore(List<Store>? stores, {required bool dashboard}) {
    if (stores != null) {
      final List<Store> served = _inServedZones(stores);
      if (dashboard) {
        _dashboardVisitAgainStoreList = served;
      } else {
        _visitAgainStoreList = served;
      }
    }
    update(_visitAgainIds);
  }

  Future<void> getRecommendedStoreList({
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (!fromRecall) {
      _recommendedStoreList = null;
    }
    if (dataSource == DataSourceEnum.local &&
        CacheTtlHelper.isStale(_moduleTtlKey('recommended_store_list'))) {
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
      CacheTtlHelper.markFresh(_moduleTtlKey('recommended_store_list'));
    }
  }

  _prepareRecommendedStores(List<Store>? recommendedStoreList) {
    if (recommendedStoreList != null) {
      _recommendedStoreList = [];
      _recommendedStoreList!.addAll(recommendedStoreList);
    }
    update(_recommendedIds);
  }
}

/// Server-side browse filters for module home screens; rendered into the
/// get-stores query string (backend: filter/sort/category_id/max_delivery_time).
class ModuleStoreFilters {
  final bool offers;
  final bool freeDelivery;
  final int? maxDeliveryTime;

  /// rating | distance | a_z, or `fastest` (sent as the `fast_delivery`
  /// filter, which is how get-stores orders by delivery time).
  final String? sort;
  final int? categoryId;

  /// Only stores open right now (`filter=[currently_open]`). Pets hub.
  final bool openNow;

  /// Minimum average rating (`rating_count`), e.g. 4.7. Pets hub.
  final double? minRating;

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
    this.openNow = false,
    this.minRating,
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
    bool? openNow,
    Object? minRating = _unchanged,
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
      openNow: openNow ?? this.openNow,
      minRating:
          identical(minRating, _unchanged)
              ? this.minRating
              : minRating as double?,
    );
  }

  bool get isActive =>
      offers ||
      freeDelivery ||
      maxDeliveryTime != null ||
      sort != null ||
      categoryId != null ||
      cuisineId != null ||
      openNow ||
      minRating != null;

  String toQueryString() {
    if (!isActive) return '';
    final parts = <String>[];
    final filters = <String>[
      if (offers) 'discounted',
      if (freeDelivery) 'free_delivery',
      if (openNow) 'currently_open',
      if (sort == 'fastest') 'fast_delivery',
    ];
    if (filters.isNotEmpty) parts.add('filter=[${filters.join(',')}]');
    if (maxDeliveryTime != null)
      parts.add('max_delivery_time=$maxDeliveryTime');
    if (sort != null && sort != 'fastest') parts.add('sort=$sort');
    if (minRating != null) parts.add('rating_count=$minRating');
    if (categoryId != null) parts.add('category_id=$categoryId');
    if (cuisineId != null) parts.add('cuisine_id=$cuisineId');
    return '&${parts.join('&')}';
  }
}
