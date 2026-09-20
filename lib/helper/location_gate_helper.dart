import 'package:flutter/material.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/location/widgets/permission_dialog_widget.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';

/// The single place that answers "do we have a usable location, and what do we
/// do if we don't?".
///
/// The app cannot function without a delivery location: modules, stores and
/// prices are all zone-scoped. Rather than invent a fallback address — which is
/// what the old browsing "seed" did, and what caused a long tail of bugs where
/// the header showed a place the user had never been — this gate insists on a
/// real one, either from GPS or from the user's own finger on the map.
///
/// Two entry points, deliberately different:
///  - [ensureForEntry] blocks app entry until a location exists. Declining the
///    permission prompt routes to a mandatory picker; there is no way past it.
///  - [ensureForAction] guards in-app "use my location" buttons. Non-blocking:
///    it nudges and returns, because the user already has a working address and
///    is only trying to refine it.
class LocationGate {
  LocationGate._();

  /// True when a real position is stored. Empty `zoneIds` (out of zone) still
  /// counts — that is a genuine place we simply don't deliver to yet, and the
  /// user is allowed to browse from it. Only the ABSENCE of a location is a
  /// blocker.
  static bool hasUsableAddress() {
    final AddressModel? saved = AddressHelper.getUserAddressFromSharedPref();
    bool valid(String? v) =>
        v != null && v.isNotEmpty && v != 'null' && double.tryParse(v) != null;
    return valid(saved?.latitude) && valid(saved?.longitude);
  }

  static Future<bool> _hasPermission() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Blocks app entry until a usable location exists.
  ///
  /// Returns true when the caller may proceed to home. Returns false when the
  /// user has been routed to the mandatory picker — the caller must NOT
  /// navigate, because the picker owns the screen until a location is saved.
  static Future<bool> ensureForEntry({String page = 'home'}) async {
    if (hasUsableAddress()) return true;

    // Ask once. iOS/Android only ever show the system sheet a single time;
    // later calls return the stored decision without prompting.
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (e, s) {
      swallow('location permission probe', e, s, true);
    }

    if (await _hasPermission()) {
      final bool resolved = await _resolveFromGps();
      if (resolved) {
        AnalyticsHelper.log('location_gate', {'result': 'gps'});
        return true;
      }
      // Permission is granted but the fix failed (GPS off, timeout, zone
      // lookup unreachable). Falling through to the picker is better than
      // stalling on a splash screen with no explanation.
      AnalyticsHelper.log('location_gate', {'result': 'gps_failed_to_picker'});
      _toMandatoryPicker(page);
      return false;
    }

    // Denied, or permanently denied. Explain, offer Settings, and if they
    // decline send them to the picker — every restart repeats this until a
    // location exists.
    AnalyticsHelper.log('location_gate', {'result': 'denied'});
    await _showPermissionDialog();

    // They may have granted it in Settings and come back.
    if (await _hasPermission() && await _resolveFromGps()) {
      AnalyticsHelper.log('location_gate', {'result': 'granted_via_settings'});
      return true;
    }

    _toMandatoryPicker(page);
    return false;
  }

  /// Guards an in-app "use my current location" action. Runs [onGranted] when
  /// permission is available; otherwise explains why it can't. Never forces
  /// navigation — the user already has a working address here and is only
  /// trying to refine it.
  ///
  /// Behaviour is deliberately identical to the six hand-rolled copies this
  /// replaced: a soft snackbar on a plain decline (they can retry), the
  /// Settings dialog once the OS stops asking.
  static Future<void> ensureForAction(VoidCallback onGranted) async {
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {
      return;
    }

    if (permission == LocationPermission.denied) {
      showCustomSnackBar('you_have_to_allow'.tr);
    } else if (permission == LocationPermission.deniedForever) {
      Get.dialog(const PermissionDialogWidget());
    } else {
      onGranted();
    }
  }

  static Future<void> _showPermissionDialog() async {
    await WidgetsBinding.instance.endOfFrame;
    await Get.dialog(const PermissionDialogWidget(), barrierDismissible: false);
  }

  static void _toMandatoryPicker(String page) {
    Get.offAllNamed(RouteHelper.getPickMapRoute(page, false, mandatory: true));
  }

  /// Resolves the current position into a saved address. Out of zone is a
  /// SUCCESS: empty zoneIds mark it, the header shows the real place with the
  /// OUT OF ZONE badge, and browsing continues. Only a failure to determine
  /// where the user is counts as failure.
  static Future<bool> _resolveFromGps() async {
    try {
      final AddressModel? address =
          await Get.find<LocationController>().resolveCurrentAddress();
      if (address == null) return false;
      await AddressHelper.saveUserAddressInSharedPref(address);
      return true;
    } catch (_) {
      return false;
    }
  }
}
