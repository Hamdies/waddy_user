import 'dart:convert';
import 'package:waddy_app/helper/auth_token_store.dart';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/api/local_client.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/models/cart_suggested_item_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/store/domain/models/recommended_product_model.dart';
import 'package:waddy_app/features/store/domain/models/store_banner_model.dart';
import 'package:waddy_app/features/store/domain/models/store_bundle_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/store/domain/repositories/store_repository_interface.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/header_helper.dart';
import 'package:waddy_app/util/app_constants.dart';

class StoreRepository implements StoreRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  StoreRepository({required this.apiClient, required this.sharedPreferences});

  @override
  Future getList({
    int? offset,
    bool isStoreList = false,
    String? filterBy,
    bool isPopularStoreList = false,
    String? type,
    bool isLatestStoreList = false,
    bool isFeaturedStoreList = false,
    bool isVisitAgainStoreList = false,
    bool isStoreRecommendedItemList = false,
    int? storeId,
    bool isStoreBannerList = false,
    bool isRecommendedStoreList = false,
    bool isTopOfferStoreList = false,
    DataSourceEnum? source,
    String extraQuery = '',
  }) async {
    if (isStoreList) {
      return await _getStoreList(
        offset!,
        filterBy!,
        type!,
        source: source ?? DataSourceEnum.client,
        extraQuery: extraQuery,
      );
    } else if (isPopularStoreList) {
      return await _getPopularStoreList(
        type!,
        source: source ?? DataSourceEnum.client,
      );
    } else if (isLatestStoreList) {
      return await _getLatestStoreList(
        type!,
        source: source ?? DataSourceEnum.client,
      );
    } else if (isFeaturedStoreList) {
      return await _getFeaturedStoreList(
        source: source ?? DataSourceEnum.client,
      );
    } else if (isVisitAgainStoreList) {
      return await _getVisitAgainStoreList(
        source: source ?? DataSourceEnum.client,
      );
    } else if (isStoreRecommendedItemList) {
      return await _getStoreRecommendedItemList(storeId);
    } else if (isStoreBannerList) {
      return await _getStoreBannerList(storeId);
    } else if (isRecommendedStoreList) {
      return await _getRecommendedStoreList(
        source: source ?? DataSourceEnum.client,
      );
    } else if (isTopOfferStoreList) {
      return await _getTopOfferStoreList(
        source: source ?? DataSourceEnum.client,
        filterBy: filterBy,
        sortBy: type,
      );
    }
  }

  Future<StoreModel?> _getStoreList(
    int offset,
    String filterBy,
    String storeType, {
    required DataSourceEnum source,
    String extraQuery = '',
  }) async {
    StoreModel? storeModel;
    // extraQuery is part of the cache key so a cached response from a
    // different filter combination can never be served.
    String cacheId =
        '${AppConstants.storeUri}/$filterBy?store_type=$storeType&offset=$offset&limit=12$extraQuery-${Get.find<SplashController>().module!.id!}';

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          '${AppConstants.storeUri}/$filterBy?store_type=$storeType&offset=$offset&limit=12$extraQuery',
        );
        if (response.statusCode == 200) {
          storeModel = StoreModel.fromJson(response.body);
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body),
            apiClient.getHeader(),
          );
        }

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          storeModel = StoreModel.fromJson(jsonDecode(cacheResponseData));
        }
    }
    return storeModel;
  }

  Future<List<Store>?> _getPopularStoreList(
    String type, {
    required DataSourceEnum source,
  }) async {
    List<Store>? popularStoreList;
    String cacheId =
        '${AppConstants.popularStoreUri}?type=$type}-${Get.find<SplashController>().module!.id!}';

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          '${AppConstants.popularStoreUri}?type=$type',
        );
        if (response.statusCode == 200) {
          popularStoreList = [];
          response.body['stores'].forEach(
            (store) => popularStoreList!.add(Store.fromJson(store)),
          );
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body['stores']),
            apiClient.getHeader(),
          );
        }

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          popularStoreList = [];
          jsonDecode(
            cacheResponseData,
          ).forEach((store) => popularStoreList!.add(Store.fromJson(store)));
        }
    }
    return popularStoreList;
  }

  Future<List<Store>?> _getLatestStoreList(
    String type, {
    required DataSourceEnum source,
  }) async {
    List<Store>? latestStoreList;
    // Must key off latestStoreUri, not popularStoreUri: the two lists share a
    // module id and `type`, so a popular-prefixed key made popular and latest
    // collide — whichever fetched first served its blob to the other.
    String cacheId =
        '${AppConstants.latestStoreUri}?type=$type-${Get.find<SplashController>().module!.id!}';

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          '${AppConstants.latestStoreUri}?type=$type',
        );
        if (response.statusCode == 200) {
          latestStoreList = [];
          response.body['stores'].forEach(
            (store) => latestStoreList!.add(Store.fromJson(store)),
          );
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body['stores']),
            apiClient.getHeader(),
          );
        }

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          latestStoreList = [];
          jsonDecode(
            cacheResponseData,
          ).forEach((store) => latestStoreList!.add(Store.fromJson(store)));
        }
    }

    return latestStoreList;
  }

  Future<List<Store>?> _getTopOfferStoreList({
    required DataSourceEnum source,
    String? filterBy,
    String? sortBy,
  }) async {
    List<Store>? topOfferStoreList;
    String cacheId =
        '${AppConstants.topOfferStoreUri}-${Get.find<SplashController>().module!.id!}';

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          '${AppConstants.topOfferStoreUri}?sort_by=$sortBy&${filterBy == '1'
              ? 'halal=1'
              : filterBy == 'veg'
              ? 'type=veg'
              : filterBy == 'non_veg'
              ? 'type=non_veg'
              : 'type='}',
        );
        if (response.statusCode == 200) {
          topOfferStoreList = [];
          response.body['stores'].forEach(
            (store) => topOfferStoreList!.add(Store.fromJson(store)),
          );
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body['stores']),
            apiClient.getHeader(),
          );
        }

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          topOfferStoreList = [];
          jsonDecode(
            cacheResponseData,
          ).forEach((store) => topOfferStoreList!.add(Store.fromJson(store)));
        }
    }
    return topOfferStoreList;
  }

  Future<List<Store>?> _getFeaturedStoreList({
    required DataSourceEnum source,
  }) async {
    List<Store>? featuredStoreList;
    String cacheId =
        '${AppConstants.storeUri}/all?featured=1&offset=1&limit=50-${Get.find<SplashController>().module?.id ?? ''}';
    Map<String, String> header =
        (Get.find<SplashController>().module == null &&
                Get.find<SplashController>().configModel.module == null)
            ? HeaderHelper.featuredHeader()
            : apiClient.getHeader();

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          '${AppConstants.storeUri}/all?featured=1&offset=1&limit=50',
          headers:
              Get.find<SplashController>().module == null &&
                      Get.find<SplashController>().configModel.module == null
                  ? HeaderHelper.featuredHeader()
                  : null,
        );
        if (response.statusCode == 200) {
          featuredStoreList = [];
          response.body['stores'].forEach(
            (store) => featuredStoreList!.add(Store.fromJson(store)),
          );
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body['stores']),
            header,
          );
        }

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          featuredStoreList = [];
          jsonDecode(
            cacheResponseData,
          ).forEach((store) => featuredStoreList!.add(Store.fromJson(store)));
        }
    }
    return featuredStoreList;
  }

  Future<List<Store>?> _getVisitAgainStoreList({
    required DataSourceEnum source,
  }) async {
    List<Store>? visitAgainStoreList;
    // Module-scoped like every sibling key: without it, food and grocery share
    // one entry and each renders the other's visit-again stores.
    String cacheId =
        '${AppConstants.visitAgainStoreUri}-${Get.find<SplashController>().module!.id!}';

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          AppConstants.visitAgainStoreUri,
        );
        if (response.statusCode == 200) {
          visitAgainStoreList = [];
          response.body.forEach(
            (store) => visitAgainStoreList!.add(Store.fromJson(store)),
          );
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body),
            apiClient.getHeader(),
          );
        }

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          visitAgainStoreList = [];
          jsonDecode(
            cacheResponseData,
          ).forEach((store) => visitAgainStoreList!.add(Store.fromJson(store)));
        }
    }
    return visitAgainStoreList;
  }

  @override
  /// [moduleId] is the module this store belongs to, resolved by the caller.
  ///
  /// It used to be three parameters — the active `ModuleModel`, the cached
  /// module's id and the active module's id — so that the line below could
  /// pick between them with `module == null ? cacheModuleId : moduleId`. Every
  /// caller passed the same three expressions, and the ternary always came out
  /// as `activeModule?.id ?? cacheModule?.id`. Three identities travelled four
  /// layers to express one number.
  Future<Store?> getStoreDetails(
    String storeID,
    bool fromCart,
    String slug,
    String languageCode,
    int? moduleId,
  ) async {
    Store? store;
    Map<String, String>? header;
    if (fromCart) {
      AddressModel? addressModel = AddressHelper.getUserAddressFromSharedPref();
      header = apiClient.updateHeader(
        AuthTokenStore.token,
        addressModel?.zoneIds,
        addressModel?.areaIds,
        languageCode,
        moduleId,
        addressModel?.latitude,
        addressModel?.longitude,
        setHeader: false,
      );
    }
    if (slug.isNotEmpty) {
      header = apiClient.updateHeader(
        AuthTokenStore.token,
        [],
        [],
        languageCode,
        0,
        '',
        '',
        setHeader: false,
      );
    }
    Response response = await apiClient.getData(
      '${AppConstants.storeDetailsUri}${slug.isNotEmpty ? slug : storeID}',
      headers: header,
    );
    if (response.statusCode == 200) {
      store = Store.fromJson(response.body);
    }
    return store;
  }

  @override
  Future<ItemModel?> getStoreItemList({
    int? storeID,
    required int offset,
    int? categoryID,
    String? type,
    List<String>? filter,
    int? rating,
    double? lowerValue,
    double? upperValue,
  }) async {
    ItemModel? storeItemModel;
    final filterString = filter != null ? jsonEncode(filter) : null;
    Response response = await apiClient.getData(
      '${AppConstants.storeItemUri}?store_id=$storeID&category_id=$categoryID&offset=$offset&limit=13&type=$type&filter=$filterString&rating_count=${rating ?? ''}&min_price=${lowerValue ?? ''}&max_price=${upperValue ?? ''}',
    );
    if (response.statusCode == 200) {
      storeItemModel = ItemModel.fromJson(response.body);
    }
    return storeItemModel;
  }

  @override
  Future<ItemModel?> getStoreSearchItemList(
    String searchText,
    String? storeID,
    int offset,
    String type,
    int? categoryID,
  ) async {
    ItemModel? storeSearchItemModel;
    Response response = await apiClient.getData(
      '${AppConstants.searchUri}items/search?store_id=$storeID&name=$searchText&offset=$offset&limit=10&type=$type&category_id=${categoryID ?? ''}',
    );
    if (response.statusCode == 200) {
      storeSearchItemModel = ItemModel.fromJson(response.body);
    }
    return storeSearchItemModel;
  }

  Future<RecommendedItemModel?> _getStoreRecommendedItemList(
    int? storeId,
  ) async {
    RecommendedItemModel? recommendedItemModel;
    Response response = await apiClient.getData(
      '${AppConstants.storeRecommendedItemUri}?store_id=$storeId&offset=1&limit=50',
    );
    if (response.statusCode == 200) {
      recommendedItemModel = RecommendedItemModel.fromJson(response.body);
    }
    return recommendedItemModel;
  }

  @override
  Future<CartSuggestItemModel?> getCartStoreSuggestedItemList(
    int? storeId,
    String languageCode,
    int? moduleId,
  ) async {
    CartSuggestItemModel? cartSuggestItemModel;
    AddressModel? addressModel = AddressHelper.getUserAddressFromSharedPref();
    Map<String, String> header = apiClient.updateHeader(
      AuthTokenStore.token,
      addressModel?.zoneIds,
      addressModel?.areaIds,
      languageCode,
      moduleId,
      addressModel?.latitude,
      addressModel?.longitude,
      setHeader: false,
    );
    Response response = await apiClient.getData(
      '${AppConstants.cartStoreSuggestedItemsUri}?recommended=1&store_id=$storeId&offset=1&limit=50',
      headers: header,
    );
    if (response.statusCode == 200) {
      cartSuggestItemModel = CartSuggestItemModel.fromJson(response.body);
    }
    return cartSuggestItemModel;
  }

  Future<List<StoreBannerModel>?> _getStoreBannerList(int? storeId) async {
    List<StoreBannerModel>? storeBanners;
    Response response = await apiClient.getData(
      '${AppConstants.storeBannersUri}$storeId',
    );
    if (response.statusCode == 200) {
      storeBanners = [];
      response.body.forEach(
        (banner) => storeBanners!.add(StoreBannerModel.fromJson(banner)),
      );
    }
    return storeBanners;
  }

  Future<List<Store>?> _getRecommendedStoreList({
    required DataSourceEnum source,
  }) async {
    List<Store>? recommendedStoreList;
    // Must NOT share the featured list's cache key — with a shared key each
    // endpoint overwrites the other's cache, so the featured list could boot
    // from an empty "recommended" blob (hiding Steal of the Day) and the
    // recommended section could flash stale featured stores.
    String cacheId =
        '${AppConstants.recommendedStoreUri}-${Get.find<SplashController>().module?.id ?? ''}';

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          AppConstants.recommendedStoreUri,
        );
        if (response.statusCode == 200) {
          recommendedStoreList = [];
          response.body['stores'].forEach(
            (store) => recommendedStoreList!.add(Store.fromJson(store)),
          );
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body['stores']),
            apiClient.getHeader(),
          );
        }

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          recommendedStoreList = [];
          jsonDecode(cacheResponseData).forEach(
            (store) => recommendedStoreList!.add(Store.fromJson(store)),
          );
        }
    }

    return recommendedStoreList;
  }

  @override
  Future<List<Store>?> getSimilarStoreList(
    int? storeId, {
    int offset = 1,
    int limit = 10,
  }) async {
    List<Store>? similarStoreList;
    Response response = await apiClient.getData(
      '${AppConstants.similarStoresUri}?store_id=$storeId&limit=$limit&offset=$offset',
    );
    if (response.statusCode == 200) {
      similarStoreList = [];
      response.body['stores'].forEach(
        (store) => similarStoreList!.add(Store.fromJson(store)),
      );
    }
    return similarStoreList;
  }

  @override
  Future<List<Store>?> getDashboardRailStoreList({
    required int moduleId,
    required bool mostOrdered,
    int limit = 6,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    List<Store>? stores;

    // Cached per module AND per ranking: the two rails ask the same endpoint
    // different questions, and one key for both would have the chart reading
    // back the shelf's answer.
    final String cacheId =
        'dashboard_rail_${mostOrdered ? 'most_ordered' : 'quick'}_$moduleId';

    // Two different questions, deliberately asked of the same endpoint.
    //
    // `mostOrdered` is the restaurant chart: `store_type=popular` orders by
    // the store's order count, and — this is the part that matters — it is
    // the only ordering here that does NOT reach for distance. The obvious
    // candidate, /stores/popular, sorts `open, distance, orders_count` under
    // the default priority settings, so it is a nearest-first list wearing a
    // popularity label; ranking numerals over that promise "most ordered" and
    // deliver "closest to you". Sending `filter=["popular"]` instead is the
    // same trap from the other side: get-stores prepends an `orderBy(distance)`
    // whenever `store_type=all` is sent with any filter, which demotes the
    // order count to a tiebreaker.
    //
    // Everything else is the grocery shelf, where speed IS the promise
    // ("Groceries in minutes"). `fast_delivery` orders by delivery time.
    // A `max_delivery_time` cap used to be sent instead, which is a promise
    // about the catalogue rather than a question about it: a zone whose
    // fastest grocer is 35 minutes out answered with nothing and the shelf
    // hid itself rather than showing the fastest stores that do exist.
    final String query =
        mostOrdered
            ? 'store_type=popular'
            : 'store_type=all&filter=["fast_delivery"]';

    switch (source) {
      case DataSourceEnum.client:
        // Explicit per-module header so this works on the aggregated dashboard
        // where SplashController.module == null (same trick as featured
        // stores).
        final Map<String, String> headers = HeaderHelper.featuredHeader(
          moduleId: moduleId,
        );
        Response response = await apiClient.getData(
          '${AppConstants.storeUri}/all?$query&offset=1&limit=$limit',
          headers: headers,
          handleError: false,
        );
        if (response.statusCode == 200) {
          stores = [];
          response.body['stores'].forEach(
            (store) => stores!.add(Store.fromJson(store)),
          );
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body['stores']),
            headers,
          );
        }

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          stores = [];
          jsonDecode(
            cacheResponseData,
          ).forEach((store) => stores!.add(Store.fromJson(store)));
        }
    }
    return stores;
  }

  @override
  Future<List<StoreBundleModel>?> getStoreBundleList(
    int? storeId, {
    int offset = 1,
    int limit = 10,
  }) async {
    List<StoreBundleModel>? bundleList;
    Response response = await apiClient.getData(
      '${AppConstants.storeBundlesUri}$storeId/bundles?limit=$limit&offset=$offset',
    );
    if (response.statusCode == 200) {
      bundleList = [];
      response.body['bundles'].forEach(
        (bundle) => bundleList!.add(StoreBundleModel.fromJson(bundle)),
      );
    }
    return bundleList;
  }

  @override
  Future add(value) {
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    throw UnimplementedError();
  }

  @override
  Future get(String? id) {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int? id) {
    throw UnimplementedError();
  }
}
