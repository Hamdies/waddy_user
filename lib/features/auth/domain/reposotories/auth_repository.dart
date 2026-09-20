import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get_connect/connect.dart';
import 'package:get/get_utils/src/platform/platform.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/common/models/response_model.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/auth/domain/models/signup_body_model.dart';
import 'package:waddy_app/features/auth/domain/models/social_log_in_body.dart';
import 'package:waddy_app/features/auth/domain/reposotories/auth_repository_interface.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/module_helper.dart';
import 'package:waddy_app/helper/auth_token_store.dart';
import 'package:waddy_app/helper/secure_storage_helper.dart';
import 'package:waddy_app/util/app_constants.dart';

class AuthRepository implements AuthRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  AuthRepository({required this.sharedPreferences, required this.apiClient});

  @override
  bool isSharedPrefNotificationActive() {
    return sharedPreferences.getBool(AppConstants.notification) ?? true;
  }

  @override
  Future<Response> registration(SignUpBodyModel signUpBody) async {
    return await apiClient.postData(
      AppConstants.registerUri,
      signUpBody.toJson(),
      handleError: false,
    );
  }

  @override
  Future<Response> login({
    required String emailOrPhone,
    required String password,
    required String loginType,
    required String fieldType,
    bool alreadyInApp = false,
  }) async {
    String guestId = getSharedPrefGuestId();
    Map<String, String> data = {
      "email_or_phone": emailOrPhone,
      "password": password,
      "login_type": loginType,
      "field_type": fieldType,
    };
    if (guestId.isNotEmpty) {
      data.addAll({"guest_id": guestId});
    }
    return await apiClient.postData(
      AppConstants.loginUri,
      data,
      handleError: false,
    );
  }

  @override
  Future<Response> otpLogin({
    required String phone,
    required String otp,
    required String loginType,
    required String verified,
  }) async {
    String guestId = getSharedPrefGuestId();
    Map<String, String> data = {"phone": phone, "login_type": loginType};
    if (guestId.isNotEmpty) {
      data.addAll({"guest_id": guestId});
    }
    if (otp.isNotEmpty) {
      data.addAll({"otp": otp});
    }
    if (verified.isNotEmpty) {
      data.addAll({"verified": verified});
    }
    return await apiClient.postData(
      AppConstants.loginUri,
      data,
      handleError: false,
    );
  }

  @override
  Future<ResponseModel> guestLogin() async {
    ResponseModel responseModel;
    String? deviceToken = await saveDeviceToken();
    Response response = await apiClient.postData(AppConstants.guestLoginUri, {
      'fcm_token': deviceToken,
    });
    if (response.statusCode == 200) {
      await saveSharedPrefGuestId(response.body['guest_id'].toString());
      responseModel = ResponseModel(true, '${response.body['guest_id']}');
    } else {
      responseModel = ResponseModel(false, response.statusText);
    }
    return responseModel;
  }

  @override
  Future<Response> updatePersonalInfo({
    required String name,
    required String? phone,
    required String loginType,
    required String? email,
    required String? referCode,
  }) async {
    Map<String, String> data = {
      "login_type": loginType,
      "name": name,
      "ref_code": referCode ?? '',
    };
    if (phone != null && phone.isNotEmpty) {
      data.addAll({"phone": phone});
    }
    if (email != null && email.isNotEmpty) {
      data.addAll({"email": email});
    }
    return await apiClient.postData(
      AppConstants.personalInformationUri,
      data,
      handleError: false,
    );
  }

  @override
  Future<Response> loginWithSocialMedia(
    SocialLogInBody socialLogInModel,
  ) async {
    String guestId = getSharedPrefGuestId();
    Map<String, dynamic> data = socialLogInModel.toJson();
    if (guestId.isNotEmpty) {
      data.addAll({"guest_id": guestId});
    }
    return await apiClient.postData(AppConstants.loginUri, data);
  }

  @override
  Future<bool> saveUserToken(String token, {bool alreadyInApp = false}) async {
    apiClient.token = token;
    if (alreadyInApp &&
        sharedPreferences.getString(AppConstants.userAddress) != null) {
      AddressModel? addressModel = AddressModel.fromJson(
        jsonDecode(sharedPreferences.getString(AppConstants.userAddress)!),
      );
      apiClient.updateHeader(
        token,
        addressModel.zoneIds,
        addressModel.areaIds,
        sharedPreferences.getString(AppConstants.languageCode),
        ModuleHelper.getModule()?.id,
        addressModel.latitude,
        addressModel.longitude,
      );
    } else {
      apiClient.updateHeader(
        token,
        null,
        null,
        sharedPreferences.getString(AppConstants.languageCode),
        ModuleHelper.getModule()?.id,
        null,
        null,
      );
    }
    // Encrypted storage, not SharedPreferences: this is a bearer credential.
    // AuthTokenStore keeps a synchronous in-memory copy so getUserToken() and
    // the ApiClient header can stay synchronous.
    await AuthTokenStore.save(token);
    return true;
  }

  @override
  Future<Response> updateToken({String notificationDeviceToken = ''}) async {
    String? deviceToken;
    if (notificationDeviceToken.isEmpty) {
      if (GetPlatform.isIOS) {
        FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        NotificationSettings settings = await FirebaseMessaging.instance
            .requestPermission(
              alert: true,
              announcement: false,
              badge: true,
              carPlay: false,
              criticalAlert: false,
              provisional: false,
              sound: true,
            );
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          deviceToken = await saveDeviceToken();
        }
      } else {
        deviceToken = await saveDeviceToken();
      }
      FirebaseMessaging.instance.subscribeToTopic(AppConstants.topic);
      // Only subscribe to zone topic if user has an address
      if (AddressHelper.getUserAddressFromSharedPref() != null &&
          AddressHelper.getUserAddressFromSharedPref()!.zoneId != null) {
        FirebaseMessaging.instance.subscribeToTopic(
          'zone_${AddressHelper.getUserAddressFromSharedPref()!.zoneId}_customer',
        );
      }
    }
    return await apiClient.postData(AppConstants.tokenUri, {
      "_method": "put",
      "cm_firebase_token":
          notificationDeviceToken.isNotEmpty
              ? notificationDeviceToken
              : deviceToken,
    }, handleError: false);
  }

  @override
  Future<String?> saveDeviceToken() async {
    String? deviceToken = '@';
    try {
      // On iOS, we must wait for APNs token before getting FCM token
      if (GetPlatform.isIOS) {
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          // Wait and retry - APNs token may not be immediately available
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        }
        if (apnsToken == null) {
          if (kDebugMode) {
            print(
              'Warning: APNs token not available - push notifications may not work',
            );
          }
        }
      }
      deviceToken = (await FirebaseMessaging.instance.getToken())!;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting device token: $e');
      }
    }
    if (kDebugMode && deviceToken != null) {
      debugPrint('Device token retrieved successfully');
    }
    return deviceToken;
  }

  @override
  bool isLoggedIn() {
    return AuthTokenStore.hasToken;
  }

  @override
  Future<bool> setProfileIncomplete(bool value, {String? phone}) async {
    if (value) {
      if (phone != null && phone.isNotEmpty) {
        await sharedPreferences.setString(
          AppConstants.pendingProfilePhone,
          phone,
        );
      }
      return await sharedPreferences.setBool(
        AppConstants.profileIncomplete,
        true,
      );
    }
    await sharedPreferences.remove(AppConstants.pendingProfilePhone);
    return await sharedPreferences.remove(AppConstants.profileIncomplete);
  }

  @override
  bool isProfileIncomplete() {
    return sharedPreferences.getBool(AppConstants.profileIncomplete) ?? false;
  }

  @override
  String? getPendingProfilePhone() {
    return sharedPreferences.getString(AppConstants.pendingProfilePhone);
  }

  @override
  Future<bool> saveSharedPrefGuestId(String id) async {
    return await sharedPreferences.setString(AppConstants.guestId, id);
  }

  @override
  String getSharedPrefGuestId() {
    return sharedPreferences.getString(AppConstants.guestId) ?? "";
  }

  @override
  Future<bool> clearSharedPrefGuestId() async {
    return await sharedPreferences.remove(AppConstants.guestId);
  }

  @override
  bool isGuestLoggedIn() {
    // The guest_id deliberately survives login (it's sent with the login
    // request so the backend can link guest orders), so "is a guest" must
    // also mean "not actually logged in".
    return sharedPreferences.containsKey(AppConstants.guestId) && !isLoggedIn();
  }

  @override
  Future<bool> clearSharedAddress() async {
    await sharedPreferences.remove(AppConstants.userAddress);
    return true;
  }

  @override
  Future<bool> clearSharedData({bool removeToken = true}) async {
    FirebaseMessaging.instance.unsubscribeFromTopic(AppConstants.topic);
    if (AddressHelper.getUserAddressFromSharedPref() != null) {
      FirebaseMessaging.instance.unsubscribeFromTopic(
        'zone_${AddressHelper.getUserAddressFromSharedPref()!.zoneId}_customer',
      );
    }
    if (removeToken) {
      apiClient.postData(AppConstants.tokenUri, {
        "_method": "put",
        "cm_firebase_token": '@',
      }, handleError: false);
    }
    await AuthTokenStore.clear(sharedPreferences);
    sharedPreferences.remove(AppConstants.guestId);
    sharedPreferences.remove(AppConstants.profileIncomplete);
    sharedPreferences.remove(AppConstants.pendingProfilePhone);
    sharedPreferences.setStringList(AppConstants.cartList, []);
    apiClient.token = null;
    if (sharedPreferences.getString(AppConstants.userAddress) != null) {
      AddressModel? addressModel = AddressModel.fromJson(
        jsonDecode(sharedPreferences.getString(AppConstants.userAddress)!),
      );
      apiClient.updateHeader(
        null,
        addressModel.zoneIds,
        null,
        sharedPreferences.getString(AppConstants.languageCode),
        null,
        addressModel.latitude,
        addressModel.longitude,
      );
    }
    return true;
  }

  @override
  Future<void> saveUserNumberAndPassword(
    String number,
    String password,
    String countryCode,
  ) async {
    try {
      await SecureStorageHelper.savePassword(password);
      await sharedPreferences.setString(AppConstants.userNumber, number);
      await sharedPreferences.setString(
        AppConstants.userCountryCode,
        countryCode,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  String getUserNumber() {
    return sharedPreferences.getString(AppConstants.userNumber) ?? "";
  }

  @override
  String getUserCountryCode() {
    return sharedPreferences.getString(AppConstants.userCountryCode) ?? "";
  }

  @override
  String getUserPassword() {
    // Legacy fallback: migrate from SharedPreferences to secure storage
    final legacy = sharedPreferences.getString(AppConstants.userPassword) ?? "";
    if (legacy.isNotEmpty) {
      SecureStorageHelper.savePassword(legacy);
      sharedPreferences.remove(AppConstants.userPassword);
      return legacy;
    }
    // Note: This returns empty synchronously. For secure storage, callers
    // should use the async version via SecureStorageHelper.getPassword()
    return "";
  }

  @override
  Future<bool> clearUserNumberAndPassword() async {
    await SecureStorageHelper.deletePassword();
    await sharedPreferences.remove(
      AppConstants.userPassword,
    ); // Clean up legacy
    await sharedPreferences.remove(AppConstants.userCountryCode);
    return await sharedPreferences.remove(AppConstants.userNumber);
  }

  @override
  String getUserToken() {
    return AuthTokenStore.token;
  }

  @override
  Future<Response> updateZone() async {
    return await apiClient.getData(AppConstants.updateZoneUri);
  }

  @override
  Future<bool> saveGuestContactNumber(String number) async {
    return await sharedPreferences.setString(AppConstants.guestNumber, number);
  }

  @override
  String getGuestContactNumber() {
    return sharedPreferences.getString(AppConstants.guestNumber) ?? "";
  }

  @override
  Future<bool> saveDmTipIndex(String index) async {
    return await sharedPreferences.setString(AppConstants.dmTipIndex, index);
  }

  @override
  String getDmTipIndex() {
    return sharedPreferences.getString(AppConstants.dmTipIndex) ?? "";
  }

  @override
  Future<bool> saveEarningPoint(String point) async {
    return await sharedPreferences.setString(AppConstants.earnPoint, point);
  }

  @override
  String getEarningPint() {
    return sharedPreferences.getString(AppConstants.earnPoint) ?? "";
  }

  @override
  Future<void> setNotificationActive(bool isActive) async {
    if (isActive) {
      await updateToken();
    } else {
      await updateToken(notificationDeviceToken: '@');
      FirebaseMessaging.instance.unsubscribeFromTopic(AppConstants.topic);
      if (isLoggedIn()) {
        FirebaseMessaging.instance.unsubscribeFromTopic(
          'zone_${AddressHelper.getUserAddressFromSharedPref()!.zoneId}_customer',
        );
      }
    }
    sharedPreferences.setBool(AppConstants.notification, isActive);
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

  @override
  Future<Response> toggleHidePhone({required bool hidePhone}) async {
    return await apiClient.postData(AppConstants.toggleHidePhoneUri, {
      "hide_phone": hidePhone ? 1 : 0,
    }, handleError: false);
  }
}
