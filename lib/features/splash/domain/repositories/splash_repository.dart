import 'package:flutter/material.dart';
import 'package:waddy_app/helper/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/api/local_client.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/common/models/response_model.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/splash/domain/models/landing_model.dart';
import 'dart:convert';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/splash/domain/repositories/splash_repository_interface.dart';

/// Cache id for the module list, and the stem of its freshness key.
///
/// Zone ids, not the address: two addresses in the same zone are served the
/// same modules, so keying on the address alone would throw away a usable
/// cache on every move down the street.
///
/// Top-level so SplashController can derive the identical string for its TTL
/// stamp without reaching through the service layer for it. A stamp that names
/// a different payload than the row it vouches for is how a cache serves the
/// wrong zone's data and reports itself fresh.
String moduleCacheId() {
  final List<int>? zoneIds =
      AddressHelper.getUserAddressFromSharedPref()?.zoneIds;
  final String zoneKey =
      (zoneIds == null || zoneIds.isEmpty)
          ? 'none'
          : (List<int>.of(zoneIds)..sort()).join('-');
  return '${AppConstants.moduleUri}-z$zoneKey';
}

class SplashRepository implements SplashRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  SplashRepository({required this.apiClient, required this.sharedPreferences});

  @override
  Future<Response> getConfigData({required DataSourceEnum source}) async {
    Response responseData = Response(
      statusCode: 00,
      body: ApiClient.noInternetMessage,
    );
    String cacheId = AppConstants.configUri;

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(AppConstants.configUri);
        if (response.statusCode == 200) {
          responseData = Response(statusCode: 200, body: response.body);
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
          responseData = Response(
            statusCode: 200,
            body: jsonDecode(cacheResponseData),
          );
        }
    }
    return responseData;
  }

  @override
  Future<LandingModel?> getLandingPageData({
    required DataSourceEnum source,
  }) async {
    LandingModel? landingModel;
    String cacheId = AppConstants.landingPageUri;

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          AppConstants.landingPageUri,
        );
        if (response.statusCode == 200) {
          landingModel = LandingModel.fromJson(response.body);
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
          landingModel = LandingModel.fromJson(jsonDecode(cacheResponseData));
        }
    }
    return landingModel;
  }

  @override
  Future<void> initSharedData() async {
    if (!sharedPreferences.containsKey(AppConstants.theme)) {
      sharedPreferences.setBool(AppConstants.theme, false);
    }
    if (!sharedPreferences.containsKey(AppConstants.countryCode)) {
      sharedPreferences.setString(
        AppConstants.countryCode,
        AppConstants.languages[0].countryCode!,
      );
    }
    if (!sharedPreferences.containsKey(AppConstants.languageCode)) {
      sharedPreferences.setString(
        AppConstants.languageCode,
        AppConstants.languages[0].languageCode!,
      );
    }
    if (!sharedPreferences.containsKey(AppConstants.cartList)) {
      sharedPreferences.setStringList(AppConstants.cartList, []);
    }
    if (!sharedPreferences.containsKey(AppConstants.searchHistory)) {
      sharedPreferences.setStringList(AppConstants.searchHistory, []);
    }
    if (!sharedPreferences.containsKey(AppConstants.notification)) {
      sharedPreferences.setBool(AppConstants.notification, true);
    }
    if (!sharedPreferences.containsKey(AppConstants.intro)) {
      sharedPreferences.setBool(AppConstants.intro, true);
    }
    if (!sharedPreferences.containsKey(AppConstants.notificationCount)) {
      sharedPreferences.setInt(AppConstants.notificationCount, 0);
    }
    if (!sharedPreferences.containsKey(AppConstants.suggestedLocation)) {
      sharedPreferences.setBool(AppConstants.suggestedLocation, false);
    }
    if (sharedPreferences.containsKey(AppConstants.referBottomSheet)) {
      sharedPreferences.setBool(AppConstants.referBottomSheet, true);
    }
    if (!sharedPreferences.containsKey(AppConstants.welcomeLetterShown)) {
      sharedPreferences.setBool(AppConstants.welcomeLetterShown, false);
    }
  }

  @override
  void disableIntro() {
    sharedPreferences.setBool(AppConstants.intro, false);
  }

  @override
  bool? showIntro() {
    return sharedPreferences.getBool(AppConstants.intro);
  }

  @override
  Future<void> setStoreCategory(int storeCategoryID) async {
    AddressModel? addressModel;
    try {
      addressModel = AddressModel.fromJson(
        jsonDecode(sharedPreferences.getString(AppConstants.userAddress)!),
      );
    } catch (e) {
      debugPrint('Did not get shared Preferences address . Note: $e');
    }
    apiClient.updateHeader(
      AuthTokenStore.token,
      addressModel?.zoneIds,
      addressModel?.areaIds,
      sharedPreferences.getString(AppConstants.languageCode),
      storeCategoryID,
      addressModel?.latitude,
      addressModel?.longitude,
    );
  }

  @override
  Future<List<ModuleModel>?> getModules({
    Map<String, String>? headers,
    required DataSourceEnum source,
  }) async {
    List<ModuleModel>? moduleList;
    // Keyed by zone. The module list is zone-scoped — the response depends on
    // the zoneId header — and this used to cache every zone's answer under one
    // id. It was survivable only because the local read was always chased by a
    // network read that overwrote it a moment later; the moment the cache is
    // allowed to actually serve (SplashController TTL-gates it now), one key
    // for all zones means a customer who changes address is shown the modules
    // of the zone they left. SplashController._moduleTtlKey derives the same
    // string for the freshness stamp — change one, change the other.
    String cacheId = moduleCacheId();

    switch (source) {
      case DataSourceEnum.client:
        Response response = await apiClient.getData(
          AppConstants.moduleUri,
          headers: headers,
        );
        if (response.statusCode == 200) {
          moduleList = [];
          response.body.forEach(
            (storeCategory) =>
                moduleList!.add(ModuleModel.fromJson(storeCategory)),
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
          moduleList = [];
          jsonDecode(cacheResponseData).forEach(
            (storeCategory) =>
                moduleList!.add(ModuleModel.fromJson(storeCategory)),
          );
        }
    }

    return moduleList;
  }

  /// Points the API header at [module], or at no module when it is null.
  ///
  /// Named for what it does. It used to be `setModule`, and it also wrote the
  /// `moduleId` pref — a third persisted copy of the current module that was
  /// **written by this line and read by nobody**: the two places that loaded it
  /// (`initSharedData` and `getModule`) both threw the value away, because the
  /// app deliberately starts on the module picker rather than restoring the
  /// last module. Both are gone; the header is the point.
  @override
  void updateModuleHeader(ModuleModel? module) {
    AddressModel? addressModel;
    try {
      addressModel = AddressModel.fromJson(
        jsonDecode(sharedPreferences.getString(AppConstants.userAddress)!),
      );
    } catch (e) {
      debugPrint('Did not get shared Preferences address . Note: $e');
    }
    apiClient.updateHeader(
      AuthTokenStore.token,
      addressModel?.zoneIds,
      addressModel?.areaIds,
      sharedPreferences.getString(AppConstants.languageCode),
      module?.id,
      addressModel?.latitude,
      addressModel?.longitude,
    );
  }

  @override
  Future<ModuleModel?> setCacheModule(ModuleModel? module) async {
    if (module != null) {
      await sharedPreferences.setString(
        AppConstants.cacheModuleId,
        jsonEncode(module.toJson()),
      );
      return module;
    } else {
      await sharedPreferences.remove(AppConstants.cacheModuleId);
      return null;
    }
  }

  @override
  ModuleModel? getCacheModule() {
    ModuleModel? module;
    if (sharedPreferences.containsKey(AppConstants.cacheModuleId)) {
      try {
        module = ModuleModel.fromJson(
          jsonDecode(sharedPreferences.getString(AppConstants.cacheModuleId)!),
        );
      } catch (e) {
        debugPrint('Did not get shared Preferences cache module. Note: $e');
      }
    }
    return module;
  }

  @override
  Future<ResponseModel> subscribeEmail(String email) async {
    ResponseModel responseModel;
    Response response = await apiClient.postData(AppConstants.subscriptionUri, {
      'email': email,
    }, handleError: false);
    if (response.statusCode == 200) {
      responseModel = ResponseModel(true, 'subscribed_successfully'.tr);
    } else {
      responseModel = ResponseModel(false, response.statusText);
    }
    return responseModel;
  }

  @override
  bool getSuggestedLocationStatus() {
    return sharedPreferences.getBool(AppConstants.suggestedLocation)!;
  }

  @override
  Future<void> saveSuggestedLocationStatus(bool data) async {
    try {
      await sharedPreferences.setBool(AppConstants.suggestedLocation, data);
    } catch (e) {
      rethrow;
    }
  }

  @override
  bool getReferBottomSheetStatus() {
    return sharedPreferences.getBool(AppConstants.referBottomSheet) ?? true;
  }

  @override
  Future<void> saveReferBottomSheetStatus(bool data) async {
    try {
      await sharedPreferences.setBool(AppConstants.referBottomSheet, data);
    } catch (e) {
      rethrow;
    }
  }

  @override
  bool getWelcomeLetterShownStatus() {
    return sharedPreferences.getBool(AppConstants.welcomeLetterShown) ?? false;
  }

  @override
  Future<void> saveWelcomeLetterShownStatus(bool data) async {
    try {
      await sharedPreferences.setBool(AppConstants.welcomeLetterShown, data);
    } catch (e) {
      rethrow;
    }
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
  Future getList({int? offset}) {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int? id) {
    throw UnimplementedError();
  }
}
