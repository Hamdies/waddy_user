import 'dart:convert';

import 'package:get/get.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/api/local_client.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/cuisine/domain/models/cuisine_model.dart';
import 'package:waddy_app/features/cuisine/domain/repositories/cuisine_repository_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

class CuisineRepository implements CuisineRepositoryInterface {
  final ApiClient apiClient;
  CuisineRepository({required this.apiClient});

  @override
  Future getList({int? offset, DataSourceEnum? source}) async {
    return await _getCuisineList(source ?? DataSourceEnum.client);
  }

  Future<List<CuisineModel>?> _getCuisineList(DataSourceEnum source) async {
    List<CuisineModel>? cuisineList;

    // Cuisines are global, not per-module, so the cache id carries no module
    // suffix the way the category one does.
    const String cacheId = AppConstants.cuisineUri;

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(AppConstants.cuisineUri);
        if (response.statusCode == 200) {
          cuisineList = _parse(response.body);
          LocalClient.organize(
            DataSourceEnum.client,
            cacheId,
            jsonEncode(response.body),
            apiClient.getHeader(),
          );
        }

      case DataSourceEnum.local:
        String? cached = await LocalClient.organize(
          DataSourceEnum.local,
          cacheId,
          null,
          null,
        );
        if (cached != null) {
          cuisineList = _parse(jsonDecode(cached));
        }
    }

    return cuisineList;
  }

  /// The endpoint returns a bare JSON array. Some deployments wrap it in a
  /// `cuisines` key, so accept either rather than rendering an empty strip
  /// against a response that actually carried data.
  List<CuisineModel>? _parse(dynamic body) {
    dynamic rows = body;
    if (rows is Map) {
      rows = rows['cuisines'] ?? rows['data'];
    }
    if (rows is! List) return null;
    return rows
        .whereType<Map<String, dynamic>>()
        .map((cuisine) => CuisineModel.fromJson(cuisine))
        .toList();
  }

  @override
  Future add(value) => throw UnimplementedError();

  @override
  Future delete(int? id) => throw UnimplementedError();

  @override
  Future get(String? id) => throw UnimplementedError();

  @override
  Future update(Map<String, dynamic> body, int? id) =>
      throw UnimplementedError();
}
