import 'package:geolocator/geolocator.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/location/domain/services/location_service_interface.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/location_gate_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';

/// Sets up a browsable guest session from the user's REAL location.
///
/// There is no fallback "seed" address. A fabricated default (Maadi) used to
/// stand in whenever GPS was unavailable, and it caused every location bug in
/// this app: it was saved over real positions, shown in the header as if the
/// user were there, and — because the real position lived only in memory —
/// a fresh install looked correct while every restart reverted to the seed.
///
/// Now this either resolves where the user actually is, or returns false so
/// the caller can ask for permission / send them to the manual picker. An
/// address we invented is worse than no address at all.
///
/// Gated by the remote `guest_browse_status` config flag. Never throws.
/// Outcome of [GuestBootstrapHelper.bootstrapGuest].
///
/// A plain bool couldn't distinguish "failed, send them to auth" from "the
/// location gate has taken over the screen" — so callers treated the second as
/// the first and navigated to auth, wiping out the mandatory picker.
enum GuestBootstrapResult {
  /// Guest session and a real address are ready; the caller is on home.
  success,

  /// Bootstrap could not complete (guest login failed, timeout). The caller
  /// should fall back to its own auth flow.
  failed,

  /// No location available. [LocationGate] now owns navigation — it is showing
  /// the permission dialog or the mandatory picker. The caller MUST NOT
  /// navigate.
  handedToLocationGate,
}

class GuestBootstrapHelper {
  GuestBootstrapHelper._();

  static const Duration _gpsTimeout = Duration(seconds: 4);
  static const Duration _overallTimeout = Duration(seconds: 10);

  static bool get guestBrowseEnabled =>
      Get.find<SplashController>().configModelOrNull?.guestBrowseStatus == true;

  static Future<GuestBootstrapResult> bootstrapGuest({
    bool tryGps = true,
  }) async {
    if (!guestBrowseEnabled) {
      return GuestBootstrapResult.failed;
    }
    AnalyticsHelper.log('guest_bootstrap_started');
    try {
      if (tryGps) {
        // One-time soft ask, outside the timed section so the user can take
        // their time with the system dialog. (iOS/Android only ever show this
        // dialog once; later calls return the stored decision silently.)
        await _ensureLocationPermission();
      }

      // Guest login and address resolution are independent — overlap them so
      // the whole bootstrap costs roughly one round trip.
      final List<dynamic> results = await Future.wait([
        _ensureGuestSession(),
        _resolveAddress(tryGps: tryGps),
      ]).timeout(_overallTimeout);

      final bool guestOk = results[0] as bool;
      final AddressModel? resolved = results[1] as AddressModel?;

      if (!guestOk) {
        AnalyticsHelper.log('guest_bootstrap_failed', {
          'reason': 'guest_login_fail',
        });
        return GuestBootstrapResult.failed;
      }

      if (resolved == null) {
        // No location, and we refuse to invent one. Hand over to the gate: it
        // explains why location is needed, offers Settings, and falls back to a
        // mandatory picker. It owns the screen from here — callers MUST NOT
        // navigate, or they will clobber the picker.
        AnalyticsHelper.log('guest_bootstrap_failed', {
          'reason': 'no_location',
        });
        await LocationGate.ensureForEntry();
        return GuestBootstrapResult.handedToLocationGate;
      }

      await _applyAndNavigate(resolved);
      AnalyticsHelper.log('guest_bootstrap_success', {
        'in_zone': (resolved.zoneIds?.isNotEmpty ?? false).toString(),
      });
      return GuestBootstrapResult.success;
    } catch (e) {
      AnalyticsHelper.log('guest_bootstrap_failed', {'reason': 'timeout'});
      return GuestBootstrapResult.failed;
    }
  }

  static Future<bool> _ensureGuestSession() async {
    try {
      if (AuthHelper.isGuestLoggedIn()) {
        return true;
      }
      final response = await Get.find<AuthController>().guestLogin();
      return response.isSuccess;
    } catch (_) {
      return false;
    }
  }

  /// The user's real position as a saveable address, or null when we can't
  /// determine it (no permission, GPS timeout, zone lookup failed).
  ///
  /// Out of zone is a valid, saveable result: empty zoneIds mark it, the
  /// header shows the real place with the OUT OF ZONE badge, and browsing
  /// continues. Ordering is gated at checkout.
  static Future<AddressModel?> _resolveAddress({required bool tryGps}) async {
    if (!tryGps) return null;

    final LocationServiceInterface locationService =
        Get.find<LocationServiceInterface>();

    final Position? position = await _silentPosition();
    if (position == null) {
      AnalyticsHelper.log('silent_gps', {'result': 'no_permission'});
      return null;
    }

    final ZoneResponseModel zone = await _safeZoneCheck(
      locationService,
      position.latitude.toString(),
      position.longitude.toString(),
    );

    // A transient failure (network, 5xx) is not a definitive "not served" —
    // don't save an address whose zone we couldn't determine.
    if (!zone.isSuccess && zone.statusCode != 404) {
      AnalyticsHelper.log('silent_gps', {'result': 'error'});
      return null;
    }

    AnalyticsHelper.log('silent_gps', {
      'result': zone.isSuccess ? 'in_zone' : 'out_zone',
    });

    String label = '';
    try {
      final String geocoded = await locationService.getAddressFromGeocode(
        LatLng(position.latitude, position.longitude),
      );
      if (geocoded.trim().isNotEmpty && geocoded != 'Unknown Location Found') {
        label = geocoded;
      }
    } catch (_) {
      // An empty label shows a neutral "select location" prompt; a later pass
      // fills in the real name. Never substitute a made-up place name.
    }

    return AddressModel(
      latitude: position.latitude.toString(),
      longitude: position.longitude.toString(),
      addressType: 'others',
      address: label,
      zoneId: zone.zoneIds.isNotEmpty ? zone.zoneIds[0] : 0,
      zoneIds: List<int>.from(zone.zoneIds),
      zoneData: List<ZoneData>.from(zone.zoneData),
      areaIds: List<int>.from(zone.areaIds),
    );
  }

  static Future<void> _ensureLocationPermission() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e, s) {
      swallow('location permission probe', e, s, true);
    }
  }

  static Future<Position?> _silentPosition() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(_gpsTimeout);
    } catch (_) {
      return null;
    }
  }

  static Future<ZoneResponseModel> _safeZoneCheck(
    LocationServiceInterface locationService,
    String lat,
    String lng,
  ) async {
    try {
      return await locationService.getZone(lat, lng);
    } catch (_) {
      return ZoneResponseModel(false, '', [], [], [], null);
    }
  }

  /// Mirrors LocationController._saveDataAndFirebaseConfig for the guest path,
  /// without the extra zone re-check (the address is already zone-resolved
  /// here) and without its failure dialogs.
  static Future<void> _applyAndNavigate(AddressModel address) async {
    Get.find<ProfileController>().setForceFullyUserEmpty();
    Get.find<LocationServiceInterface>().configureFirebaseMessaging(address);
    await AddressHelper.saveUserAddressInSharedPref(address);
    Get.find<CheckoutController>().clearPrevData();
    HomeScreen.loadData(true);
    Get.offAllNamed(RouteHelper.getInitialRoute(fromSplash: true));
  }
}
