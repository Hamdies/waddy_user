import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:drift/drift.dart' as drift;
import 'package:waddy_app/helper/db_helper.dart';
import 'package:waddy_app/local/cache_response.dart';

class LocalClient {
  static Future<String?> organize(
    DataSourceEnum source,
    String cacheId,
    String? responseBody,
    Map<String, String>? header,
  ) async {
    SharedPreferences sharedPreferences = Get.find();
    switch (source) {
      case DataSourceEnum.client:
        try {
          // print('==========cache data : endpoint banner=${cacheId}, '
          //     'header= ${header.toString()}, '
          //     'response= ${responseBody}');

          // Strip sensitive headers before caching
          Map<String, String>? safeHeader;
          if (header != null) {
            safeHeader = Map<String, String>.from(header);
            safeHeader.remove('Authorization');
          }
          DbHelper.insertOrUpdate(
            id: cacheId,
            data: CacheResponseCompanion(
              endPoint: drift.Value(cacheId),
              header: drift.Value(safeHeader.toString()),
              response: drift.Value(responseBody ?? ''),
            ),
          );
        } catch (e) {
          if (kDebugMode) {
            print('=====error occure in repo api bannaer add: $e');
          }
        }
      case DataSourceEnum.local:
        try {
          {
            final CacheResponseData? cacheResponseData = await database
                .getCacheResponseById(cacheId);
            return cacheResponseData?.response;
          }
        } catch (e) {
          if (kDebugMode) {
            print('=====error occur in repo local banner: $e');
          }
        }
    }
    return null;
  }
}
