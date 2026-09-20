import 'dart:convert';
import 'package:waddy_app/helper/auth_token_store.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/util/app_constants.dart';

class AddressHelper {
  /// Saves the user's delivery address. The address is always a real place —
  /// somewhere they are or deliberately chose. Empty `zoneIds` mean we don't
  /// serve it, which is what [LocationController.outOfServingZone] derives
  /// from; there is no separate flag to keep in sync.
  static Future<bool> saveUserAddressInSharedPref(AddressModel address) async {
    SharedPreferences sharedPreferences = Get.find<SharedPreferences>();
    String userAddress = jsonEncode(address.toJson());
    // Prime the memo alongside the write so the two never disagree, not even
    // for the microtask before setString completes.
    _cachedRaw = userAddress;
    _cachedModel = address;
    Get.find<ApiClient>().updateHeader(
      AuthTokenStore.token,
      address.zoneIds,
      [],
      sharedPreferences.getString(AppConstants.languageCode),
      Get.find<SplashController>().module?.id,
      address.latitude,
      address.longitude,
    );
    return await sharedPreferences.setString(
      AppConstants.userAddress,
      userAddress,
    );
  }

  /// Memo for [getUserAddressFromSharedPref], keyed on the exact stored string.
  ///
  /// Keyed on the raw value rather than invalidated by hand on purpose: two
  /// places outside this class touch the pref directly (AuthRepository clears
  /// it on sign-out and reads it during login), so a manually-invalidated cache
  /// would go stale the moment one of them ran. Comparing against whatever is
  /// stored right now cannot drift, whoever wrote it.
  static String? _cachedRaw;
  static AddressModel? _cachedModel;

  /// The saved delivery address.
  ///
  /// Called from 93 places, most of them inside `build` — so before the memo
  /// below, every rebuild of every widget showing the delivery address ran a
  /// full `jsonDecode` plus `AddressModel.fromJson`.
  ///
  /// The returned instance is SHARED. Callers that mutate it (there are three,
  /// all in LocationController) must follow the existing read-mutate-save
  /// contract and call [saveUserAddressInSharedPref] straight after, which is
  /// what makes the shared instance and the stored string agree again.
  static AddressModel? getUserAddressFromSharedPref() {
    SharedPreferences sharedPreferences = Get.find<SharedPreferences>();
    // Having no saved address is a NORMAL state (first run, and every launch
    // until the location gate resolves one) — not an error. The old `!` threw
    // on every read in that state, filling the log with "Null check operator
    // used on a null value" and burying real failures.
    final String? raw = sharedPreferences.getString(AppConstants.userAddress);
    if (raw == null || raw.isEmpty) {
      _cachedRaw = null;
      _cachedModel = null;
      return null;
    }
    // getString is an in-memory map lookup; the decode below is the expensive
    // part, and this is what skips it.
    if (raw == _cachedRaw) return _cachedModel;
    try {
      final AddressModel model = AddressModel.fromJson(jsonDecode(raw));
      _cachedRaw = raw;
      _cachedModel = model;
      return model;
    } catch (e) {
      debugPrint('Address parse failed: $e');
      _cachedRaw = null;
      _cachedModel = null;
      return null;
    }
  }

  static bool clearAddressFromSharedPref() {
    SharedPreferences sharedPreferences = Get.find<SharedPreferences>();
    _cachedRaw = null;
    _cachedModel = null;
    sharedPreferences.remove(AppConstants.userAddress);
    sharedPreferences.remove(AppConstants.addressIsSeed);
    return true;
  }
}
