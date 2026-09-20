import 'dart:convert';
import 'package:waddy_app/util/swallow.dart';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/util/app_constants.dart';

class HeaderHelper {
  /// Headers for a request that names its own module, rather than inheriting
  /// whichever one the app happens to be in.
  ///
  /// This is what the aggregated dashboard needs: it is module-less by
  /// definition and its rails each ask about a specific module, so the module
  /// id has to be an argument rather than ambient state.
  ///
  /// [moduleId] used to be a local variable that was declared, never assigned,
  /// and then read:
  ///
  /// ```dart
  /// int? moduleID;
  /// ...
  /// moduleID != null ? AppConstants.moduleId: '\$moduleID' : '',
  /// ```
  ///
  /// which Dart parses as the map KEY `(moduleID != null ? 'moduleId' :
  /// '\$moduleID')` with the value `''` — so every caller sent a header
  /// literally named `null`, and the module id this helper exists to send
  /// could never be sent. That is why each caller spread the result and then
  /// appended `AppConstants.moduleId` by hand. Now it is a parameter, and
  /// omitting it means what it says: no module.
  static Map<String, String> featuredHeader({int? moduleId}) {
    SharedPreferences sharedPreferences = Get.find<SharedPreferences>();
    AddressModel? addressModel;
    try {
      addressModel = AddressModel.fromJson(
        jsonDecode(sharedPreferences.getString(AppConstants.userAddress)!),
      );
    } catch (e, s) {
      // No saved address yet is the normal first-run state, not an error: the
      // headers simply go out without zone or coordinates.
      swallow('no stored address when building headers', e, s);
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      AppConstants.zoneId:
          addressModel?.zoneIds != null
              ? jsonEncode(addressModel?.zoneIds)
              : '',
      if (moduleId != null) AppConstants.moduleId: '$moduleId',
      AppConstants.localizationKey:
          sharedPreferences.getString(AppConstants.languageCode) ??
          AppConstants.languages[0].languageCode!,
      AppConstants.latitude:
          addressModel?.latitude != null
              ? jsonEncode(addressModel?.latitude)
              : '',
      AppConstants.longitude:
          addressModel?.longitude != null
              ? jsonEncode(addressModel?.longitude)
              : '',
      // 'Authorization': 'Bearer $token'
    };
  }
}
