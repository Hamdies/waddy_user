import 'dart:convert';

import 'package:get/get.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/api/local_client.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/item/domain/models/basic_medicine_model.dart';
import 'package:waddy_app/features/item/domain/models/common_condition_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/item/domain/repositories/item_repository_interface.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/util/app_constants.dart';

class ItemRepository implements ItemRepositoryInterface {
  final ApiClient apiClient;
  ItemRepository({required this.apiClient});

  @override
  Future<BasicMedicineModel?> getBasicMedicine(DataSourceEnum source) async {
    BasicMedicineModel? basicMedicineModel;

    // Use module ID if available, otherwise use empty string for cache key
    final module = Get.find<SplashController>().module;
    final moduleId = module?.id?.toString() ?? '';

    String cacheId =
        '${AppConstants.basicMedicineUri}?offset=1&limit=50-$moduleId';

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          '${AppConstants.basicMedicineUri}?offset=1&limit=50',
        );
        if (response.statusCode == 200) {
          basicMedicineModel = BasicMedicineModel.fromJson(response.body);
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
          basicMedicineModel = BasicMedicineModel.fromJson(
            jsonDecode(cacheResponseData),
          );
        }
    }
    return basicMedicineModel;
  }

  @override
  Future get(String? id, {bool isConditionWiseItem = false}) async {
    if (isConditionWiseItem) {
      return await _getConditionsWiseItems(int.parse(id!));
    } else {
      return await _getItemDetails(int.parse(id!));
    }
  }

  Future<Item?> _getItemDetails(int? itemID) async {
    Item? item;
    Response response = await apiClient.getData(
      '${AppConstants.itemDetailsUri}$itemID',
    );
    if (response.statusCode == 200) {
      item = Item.fromJson(response.body);
    }
    return item;
  }

  Future<List<Item>?> _getConditionsWiseItems(int id) async {
    List<Item>? conditionWiseProduct;
    Response response = await apiClient.getData(
      '${AppConstants.conditionWiseItemUri}$id?limit=15&offset=1',
    );
    if (response.statusCode == 200) {
      conditionWiseProduct = [];
      conditionWiseProduct.addAll(ItemModel.fromJson(response.body).items!);
    }
    return conditionWiseProduct;
  }

  @override
  Future getList({
    int? offset,
    String? type,
    bool isPopularItem = false,
    bool isReviewedItem = false,
    bool isFeaturedCategoryItems = false,
    bool isRecommendedItems = false,
    bool isCommonConditions = false,
    bool isDiscountedItems = false,
    DataSourceEnum? source,
    String? search,
    List<int>? categoryIds,
    List<String>? filter,
    int? rating,
    double? minPrice,
    double? maxPrice,
  }) async {
    if (isPopularItem) {
      return await _getPopularItemList(
        type: type!,
        source: source ?? DataSourceEnum.client,
        offset: offset!,
        search: search,
        categoryIds: categoryIds,
        filter: filter,
        rating: rating,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
    } else if (isReviewedItem) {
      return await _getReviewedItemList(
        type: type!,
        source: source ?? DataSourceEnum.client,
        offset: offset!,
        search: search,
        categoryIds: categoryIds,
        filter: filter,
        rating: rating,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
    } else if (isFeaturedCategoryItems) {
      return await _getFeaturedCategoriesItemList(
        source: source ?? DataSourceEnum.client,
      );
    } else if (isRecommendedItems) {
      return await _getRecommendedItemList(
        type!,
        source: source ?? DataSourceEnum.client,
      );
    } else if (isCommonConditions) {
      return await _getCommonConditions();
    } else if (isDiscountedItems) {
      return await _getDiscountedItemList(
        type: type!,
        source: source ?? DataSourceEnum.client,
        offset: offset!,
        search: search,
        categoryIds: categoryIds,
        filter: filter,
        rating: rating,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
    }
  }

  Future<ItemModel?> _getPopularItemList({
    required String type,
    required DataSourceEnum source,
    required int offset,
    String? search,
    List<int>? categoryIds,
    List<String>? filter,
    int? rating,
    double? minPrice,
    double? maxPrice,
  }) async {
    ItemModel? popularItemList;

    // Use module ID if available, otherwise use empty string for cache key
    final module = Get.find<SplashController>().module;
    final moduleId = module?.id?.toString() ?? '';

    String cacheId = '${AppConstants.popularItemUri}?type=$type-$moduleId';

    final filterString = filter != null ? jsonEncode(filter) : [];
    final categoryIdsString =
        categoryIds != null ? jsonEncode(categoryIds) : [];

    Map<String, dynamic>? query = {
      'type': type,
      'offset': offset.toString(),
      'limit': '25',
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryIds != null && categoryIds.isNotEmpty)
        'category_ids': categoryIdsString,
      if (filter != null && filter.isNotEmpty) 'filter': filterString,
      if (rating != null) 'rating_count': rating.toString(),
      if (minPrice != null) 'min_price': minPrice.toString(),
      if (maxPrice != null) 'max_price': maxPrice.toString(),
    };

    String uri =
        Uri.parse(
          AppConstants.popularItemUri,
        ).replace(queryParameters: query).toString();

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(uri);
        if (response.statusCode == 200) {
          popularItemList = ItemModel.fromJson(response.body);
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body),
            apiClient.getHeader(),
          );
        }
        break;

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          popularItemList = ItemModel.fromJson(jsonDecode(cacheResponseData));
        }
        break;
    }

    return popularItemList;
  }

  Future<ItemModel?> _getReviewedItemList({
    required String type,
    required DataSourceEnum source,
    required int offset,
    String? search,
    List<int>? categoryIds,
    List<String>? filter,
    int? rating,
    double? minPrice,
    double? maxPrice,
  }) async {
    ItemModel? itemModel;

    // Use module ID if available, otherwise use empty string for cache key
    final module = Get.find<SplashController>().module;
    final moduleId = module?.id?.toString() ?? '';

    String cacheId = '${AppConstants.reviewedItemUri}?type=$type$moduleId';

    final filterString = filter != null ? jsonEncode(filter) : [];
    final categoryIdsString =
        categoryIds != null ? jsonEncode(categoryIds) : [];

    Map<String, dynamic>? query = {
      'type': type,
      'offset': offset.toString(),
      'limit': '25',
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryIds != null && categoryIds.isNotEmpty)
        'category_ids': categoryIdsString,
      if (filter != null && filter.isNotEmpty) 'filter': filterString,
      if (rating != null) 'rating_count': rating.toString(),
      if (minPrice != null) 'min_price': minPrice.toString(),
      if (maxPrice != null) 'max_price': maxPrice.toString(),
    };

    String uri =
        Uri.parse(
          AppConstants.reviewedItemUri,
        ).replace(queryParameters: query).toString();

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(uri);
        if (response.statusCode == 200) {
          itemModel = ItemModel.fromJson(response.body);
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body),
            apiClient.getHeader(),
          );
        }
        break;

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          itemModel = ItemModel.fromJson(jsonDecode(cacheResponseData));
        }
        break;
    }

    return itemModel;
  }

  Future<ItemModel?> _getDiscountedItemList({
    required String type,
    required DataSourceEnum source,
    required int offset,
    String? search,
    List<int>? categoryIds,
    List<String>? filter,
    int? rating,
    double? minPrice,
    double? maxPrice,
  }) async {
    ItemModel? discountedItem;

    // Use module ID if available, otherwise use empty string for cache key
    final module = Get.find<SplashController>().module;
    final moduleId = module?.id?.toString() ?? '';

    String cacheId =
        '${AppConstants.discountedItemsUri}?type=$type&offset=1&limit=50$moduleId';

    final filterString = filter != null ? jsonEncode(filter) : [];
    final categoryIdsString =
        categoryIds != null ? jsonEncode(categoryIds) : [];

    Map<String, dynamic>? query = {
      'type': type,
      'offset': offset.toString(),
      'limit': '25',
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryIds != null && categoryIds.isNotEmpty)
        'category_ids': categoryIdsString,
      if (filter != null && filter.isNotEmpty) 'filter': filterString,
      if (rating != null) 'rating_count': rating.toString(),
      if (minPrice != null) 'min_price': minPrice.toString(),
      if (maxPrice != null) 'max_price': maxPrice.toString(),
    };

    String uri =
        Uri.parse(
          AppConstants.discountedItemsUri,
        ).replace(queryParameters: query).toString();

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(uri);
        if (response.statusCode == 200) {
          discountedItem = ItemModel.fromJson(response.body);
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body),
            apiClient.getHeader(),
          );
        }
        break;

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          discountedItem = ItemModel.fromJson(jsonDecode(cacheResponseData));
        }
        break;
    }

    return discountedItem;
  }

  Future<ItemModel?> _getFeaturedCategoriesItemList({
    required DataSourceEnum source,
  }) async {
    ItemModel? featuredCategoriesItem;

    // Use module ID if available, otherwise use empty string for cache key
    final module = Get.find<SplashController>().module;
    final moduleId = module?.id?.toString() ?? '';

    String cacheId =
        '${AppConstants.featuredCategoriesItemsUri}?limit=30&offset=1$moduleId';

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          '${AppConstants.featuredCategoriesItemsUri}?limit=30&offset=1',
        );
        if (response.statusCode == 200) {
          featuredCategoriesItem = ItemModel.fromJson(response.body);
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
          featuredCategoriesItem = ItemModel.fromJson(
            jsonDecode(cacheResponseData),
          );
        }
    }

    return featuredCategoriesItem;
  }

  Future<List<Item>?> _getRecommendedItemList(
    String type, {
    required DataSourceEnum source,
  }) async {
    List<Item>? recommendedItemList;

    // Use module ID if available, otherwise use empty string for cache key
    final module = Get.find<SplashController>().module;
    final moduleId = module?.id?.toString() ?? '';

    String cacheId =
        '${AppConstants.recommendedItemsUri}$type&limit=30$moduleId';

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          '${AppConstants.recommendedItemsUri}$type&limit=30',
        );
        if (response.statusCode == 200) {
          recommendedItemList = [];
          recommendedItemList.addAll(ItemModel.fromJson(response.body).items!);
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
          recommendedItemList = [];
          recommendedItemList.addAll(
            ItemModel.fromJson(jsonDecode(cacheResponseData)).items!,
          );
        }
    }

    return recommendedItemList;
  }

  Future<List<Item>?> getRamadanFeaturedItemList({
    required DataSourceEnum source,
  }) async {
    List<Item>? ramadanItems;

    final module = Get.find<SplashController>().module;
    final moduleId = module?.id?.toString() ?? '';

    String cacheId =
        '${AppConstants.ramadanFeaturedItemsUri}?limit=20$moduleId';

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          '${AppConstants.ramadanFeaturedItemsUri}?limit=20',
        );
        if (response.statusCode == 200) {
          ramadanItems = [];
          ramadanItems.addAll(ItemModel.fromJson(response.body).items!);
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
          ramadanItems = [];
          ramadanItems.addAll(
            ItemModel.fromJson(jsonDecode(cacheResponseData)).items!,
          );
        }
    }

    return ramadanItems;
  }

  Future<List<CommonConditionModel>?> _getCommonConditions() async {
    List<CommonConditionModel>? commonConditions;
    Response response = await apiClient.getData(
      AppConstants.commonConditionUri,
    );
    if (response.statusCode == 200) {
      commonConditions = [];
      response.body.forEach(
        (condition) =>
            commonConditions!.add(CommonConditionModel.fromJson(condition)),
      );
    }
    return commonConditions;
  }

  @override
  Future update(Map<String, dynamic> body, int? id) {
    throw UnimplementedError();
  }

  @override
  Future add(value) {
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    throw UnimplementedError();
  }
}
