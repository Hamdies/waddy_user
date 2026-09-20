import 'dart:convert';
import 'package:waddy_app/helper/module_helper.dart';

import 'package:get/get.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/api/local_client.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/brands/domain/models/brands_model.dart';
import 'package:waddy_app/features/brands/domain/repositories/brands_repository_interface.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/util/app_constants.dart';

class BrandsRepository implements BrandsRepositoryInterface {
  final ApiClient apiClient;
  BrandsRepository({required this.apiClient});

  @override
  Future<List<BrandModel>?> getBrandList({
    required DataSourceEnum source,
  }) async {
    List<BrandModel>? brandList;
    String cacheId =
        '${AppConstants.brandListUri}-${ModuleHelper.currentModuleId() ?? 'none'}';

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(AppConstants.brandListUri);
        if (response.statusCode == 200) {
          brandList = [];
          response.body.forEach(
            (brand) => brandList!.add(BrandModel.fromJson(brand)),
          );
          LocalClient.organize(
            source,
            cacheId,
            jsonEncode(response.body),
            apiClient.getHeader(),
          );
        }

      case DataSourceEnum.local:
        String? cacheResponseData = await LocalClient.organize(
          source,
          cacheId,
          null,
          null,
        );
        if (cacheResponseData != null) {
          brandList = [];
          jsonDecode(
            cacheResponseData,
          ).forEach((brand) => brandList!.add(BrandModel.fromJson(brand)));
        }
    }

    return brandList;
  }

  @override
  Future<ItemModel?> getBrandItemList({
    required int brandId,
    int? offset,
  }) async {
    ItemModel? brandItemModel;
    Response response = await apiClient.getData(
      '${AppConstants.brandItemUri}/$brandId?offset=$offset&limit=12',
    );
    if (response.statusCode == 200) {
      brandItemModel = ItemModel.fromJson(response.body);
    }
    return brandItemModel;
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

  @override
  Future getList({int? offset}) {
    // TODO: implement getList
    throw UnimplementedError();
  }
}
