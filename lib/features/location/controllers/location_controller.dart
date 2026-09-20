import 'dart:async';
import 'package:waddy_app/util/swallow.dart';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' hide LocationAccuracy;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/common/widgets/no_internet_screen.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/location/domain/models/prediction_model.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/location/domain/models/zone_data_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/location/domain/services/location_service_interface.dart';
import 'package:waddy_app/features/location/widgets/module_dialog_widget.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/common/widgets/custom_loader.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/location/widgets/coming_soon_delivery.dart';
import 'package:waddy_app/features/location/domain/models/zone_request_model.dart';
import 'package:waddy_app/helper/analytics_helper.dart';

class LocationController extends GetxController implements GetxService {
  final LocationServiceInterface locationServiceInterface;

  LocationController({required this.locationServiceInterface});

  Position _position = Position(
    longitude: 0,
    latitude: 0,
    timestamp: DateTime.now(),
    accuracy: 1,
    altitude: 1,
    heading: 1,
    speed: 1,
    speedAccuracy: 1,
    altitudeAccuracy: 1,
    headingAccuracy: 1,
  );
  Position get position => _position;

  Position _pickPosition = Position(
    longitude: 0,
    latitude: 0,
    timestamp: DateTime.now(),
    accuracy: 1,
    altitude: 1,
    heading: 1,
    speed: 1,
    speedAccuracy: 1,
    altitudeAccuracy: 1,
    headingAccuracy: 1,
  );
  Position get pickPosition => _pickPosition;

  // Loading is refcounted, not a bool. getCurrentLocation and updatePosition
  // can be in flight at the same time (the former animates the camera, which
  // fires onCameraIdle, which starts the latter) and both used to write the
  // same bool — so whichever finished first cleared the flag while the other
  // was still running, and the slower one then re-raised it. That handoff is
  // what left the picker spinning and re-triggering itself.
  int _loadingCount = 0;
  bool get loading => _loadingCount > 0;

  int _isLoadingCount = 0;
  bool get isLoading => _isLoadingCount > 0;

  void _beginLoading({required bool markerLoad}) {
    markerLoad ? _loadingCount++ : _isLoadingCount++;
  }

  void _endLoading({required bool markerLoad}) {
    if (markerLoad) {
      if (_loadingCount > 0) _loadingCount--;
    } else {
      if (_isLoadingCount > 0) _isLoadingCount--;
    }
  }

  // Monotonic stamp for map-driven address/zone lookups. A pan that starts
  // while an earlier lookup is still awaiting must win: the older response is
  // discarded instead of overwriting _pickAddress with a stale address.
  int _positionRequestId = 0;

  // Set around a programmatic camera move so the onCameraIdle it provokes does
  // not kick off a redundant lookup for a position we already resolved.
  int _suppressIdleCount = 0;

  String? _address = '';
  String? get address => _address;

  String? _pickAddress = '';
  String? get pickAddress => _pickAddress;

  bool _inZone = false;
  bool get inZone => _inZone;

  // ── Out-of-zone is DERIVED, never stored ──
  // The saved address always describes a real place the user is at or chose,
  // and its zoneIds say whether we serve it. Deriving the flag from that one
  // fact means it cannot go stale or disagree with the address, and it
  // survives a restart for free — the previous in-memory flag was reset on
  // every launch, which is why a fresh install looked right and every restart
  // fell back to the seed.
  bool get outOfServingZone {
    final AddressModel? saved = AddressHelper.getUserAddressFromSharedPref();
    if (saved == null) return false;
    final String? lat = saved.latitude;
    if (lat == null || lat.isEmpty || lat == 'null') return false;
    return saved.zoneIds?.isEmpty ?? true;
  }

  /// The user's real position, read straight off the saved address. Kept as
  /// getters (not fields) so they can never drift from what's on disk.
  String? get outOfZoneRealAddress => outOfServingZone ? _savedLabel : null;
  double? get outOfZoneRealLat =>
      outOfServingZone
          ? double.tryParse(
            AddressHelper.getUserAddressFromSharedPref()?.latitude ?? '',
          )
          : null;
  double? get outOfZoneRealLng =>
      outOfServingZone
          ? double.tryParse(
            AddressHelper.getUserAddressFromSharedPref()?.longitude ?? '',
          )
          : null;

  String? get _savedLabel {
    final String? label =
        AddressHelper.getUserAddressFromSharedPref()?.address?.trim();
    return (label == null || label.isEmpty) ? null : label;
  }

  /// Every `update()` on this controller also refreshes the zone-status
  /// builders ([kZoneStatusId]).
  ///
  /// [outOfServingZone] is a derived getter, not an observable, so the
  /// "Coming soon" chips that replace delivery times cannot rebuild themselves.
  /// They must not go stale — a leftover "25 min" on a store we can't deliver
  /// from is the exact bait-and-switch this feature exists to prevent.
  ///
  /// Rather than appending the id at each of the ~17 `update()` sites here (and
  /// relying on every future one remembering), this widens all of them at once.
  /// Zone changes always land in one of those paths, so nothing can be missed.
  /// Targeted ids passed by callers are honoured and simply gain this one.
  @override
  void update([List<Object>? ids, bool condition = true]) {
    // A null id list already rebuilds every builder, zone-status ones included.
    super.update(
      ids == null ? null : <Object>{...ids, kZoneStatusId}.toList(),
      condition,
    );
  }

  /// Clears the once-per-episode prompt flags when the user comes back into a
  /// serving zone, so a future out-of-zone episode shows its hints again.
  /// Callers just save an in-zone address; this keeps the side effect in one
  /// place now that the flag itself is derived.
  void onBackInServingZone() {
    try {
      final prefs = Get.find<SharedPreferences>();
      prefs.remove(AppConstants.zoneHintDismissedAt);
      prefs.remove(AppConstants.noDeliverySheetShown);
    } catch (e, s) {
      // The hint reappears next launch if this fails. Harmless, but a prefs
      // write that throws is worth knowing about.
      swallow('clear zone-hint flags on re-entering zone', e, s, true);
    }
    _resetZoneRequestState();
    update();
  }

  /// The address to SHOW in the "deliver to" header — the single source of
  /// truth for every header, so they can't drift apart. The saved address is
  /// always a real place now (the fabricated seed is gone), so this simply
  /// prefers it and falls back to a freshly resolved GPS label.
  /// null → callers show a neutral "select location" prompt.
  String? get displayAddress => _savedLabel ?? _gpsAddress;

  // ---------------------------------------------------------------------------
  // Demand capture — "notify me when you launch here"
  // ---------------------------------------------------------------------------

  bool _zoneRequestSubmitted = false;

  /// True once this user has asked us to launch in their area. Persisted, so
  /// the ask is never repeated across restarts.
  bool get zoneRequestSubmitted => _zoneRequestSubmitted;

  int? _requestsInArea;

  /// "47 people here are waiting too". Null means unknown — the UI must then
  /// omit the line entirely rather than show 0, which would read as
  /// "nobody else wants this", the opposite of the intended message.
  int? get requestsInArea => _requestsInArea;

  bool _submittingZoneRequest = false;
  bool get submittingZoneRequest => _submittingZoneRequest;

  /// Restores the submitted flag and replays any request that failed to reach
  /// the server. Called once on home load.
  Future<void> initZoneRequestState() async {
    try {
      final prefs = Get.find<SharedPreferences>();
      _zoneRequestSubmitted =
          prefs.getBool(AppConstants.zoneRequestSubmitted) ?? false;
      update([kZoneStatusId]);

      final String? pending = prefs.getString(AppConstants.zoneRequestPending);
      if (pending == null || pending.isEmpty) return;

      // Replay. The server dedupes on identity, so a retry that races a
      // silently-succeeded original is harmless.
      final ZoneRequestBody body = ZoneRequestBody.fromJson(
        jsonDecode(pending),
      );
      final ZoneRequestResult? result = await locationServiceInterface
          .submitZoneRequest(body);
      if (result != null) {
        await prefs.remove(AppConstants.zoneRequestPending);
        _requestsInArea = result.totalRequestsInArea;
        // Deliberately NOT 'zone_request_submitted' — that already fired at tap
        // time. Re-firing it here would double-count the very funnel metric
        // used to judge this feature.
        AnalyticsHelper.log('zone_request_retry_succeeded', {
          'source': body.source,
        });
        update([kZoneStatusId]);
      }
    } catch (_) {
      // A malformed or unreadable queue must never block home load.
    }
  }

  /// Records a "launch delivery here" request for the user's current position.
  ///
  /// Always reports success to the caller when we have a position: the tap is a
  /// promise to remember them, and a network failure is our problem, not
  /// theirs. Unreachable requests are parked and replayed on next launch, and
  /// the analytics event fires regardless — so the expansion signal survives
  /// even a total backend outage.
  ///
  /// [storeId] should be passed when the prompt came from add-to-cart: knowing
  /// WHICH store someone wanted is the most actionable column in the table.
  Future<bool> submitZoneRequest({
    required String source,
    int? storeId,
    int? moduleId,
  }) async {
    if (_submittingZoneRequest) return _zoneRequestSubmitted;

    final double? lat = outOfZoneRealLat;
    final double? lng = outOfZoneRealLng;
    // No position means no demand signal worth recording — and nothing honest
    // to show the user either.
    if (lat == null || lng == null) return false;

    _submittingZoneRequest = true;
    update([kZoneStatusId]);

    // Push is the only delivery channel (there's no contact field by design),
    // so whether we can actually reach this person is part of the record.
    final String? token = await _resolveFcmToken();

    final ZoneRequestBody body = ZoneRequestBody(
      latitude: lat,
      longitude: lng,
      source: source,
      address: outOfZoneRealAddress,
      storeId: storeId,
      moduleId: moduleId ?? Get.find<SplashController>().module?.id,
      fcmToken: token,
      hasPush: token != null && token.isNotEmpty,
    );

    // Fires exactly once, here, whether or not the network call lands.
    AnalyticsHelper.log('zone_request_submitted', {
      'source': source,
      'has_push': body.hasPush,
      if (storeId != null) 'store_id': storeId,
    });

    final ZoneRequestResult? result = await locationServiceInterface
        .submitZoneRequest(body);

    try {
      final prefs = Get.find<SharedPreferences>();
      await prefs.setBool(AppConstants.zoneRequestSubmitted, true);
      if (result == null) {
        // Park for replay rather than dropping the user's request.
        await prefs.setString(
          AppConstants.zoneRequestPending,
          jsonEncode(body.toJson()),
        );
        AnalyticsHelper.log('zone_request_failed', {'source': source});
      } else {
        await prefs.remove(AppConstants.zoneRequestPending);
      }
    } catch (e, s) {
      swallow('persist pending zone request', e, s, true);
    }

    _requestsInArea = result?.totalRequestsInArea;
    _zoneRequestSubmitted = true;
    _submittingZoneRequest = false;
    update([kZoneStatusId]);
    return true;
  }

  /// The device's FCM token, but only if notifications are actually permitted.
  ///
  /// Returns null when permission is denied, which makes the caller show
  /// count-only copy instead of a notification promise. Promising an alert we
  /// have no channel to deliver is worse for trust than not offering one.
  Future<String?> _resolveFcmToken() async {
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
      final bool granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return null;
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Clears demand-capture state when the user comes back into a serving zone —
  /// a future out-of-zone episode elsewhere is a genuinely new request.
  void _resetZoneRequestState() {
    _zoneRequestSubmitted = false;
    _requestsInArea = null;
    try {
      final prefs = Get.find<SharedPreferences>();
      prefs.remove(AppConstants.zoneRequestSubmitted);
      prefs.remove(AppConstants.zoneRequestPending);
    } catch (e, s) {
      swallow('clear zone-request flags', e, s);
    }
  }

  List<ZoneDataModel>? _serviceZoneList;
  List<ZoneDataModel>? get serviceZoneList => _serviceZoneList;

  Future<List<ZoneDataModel>?> getServiceZoneList({bool reload = false}) async {
    if (_serviceZoneList == null || reload) {
      _serviceZoneList = await locationServiceInterface.getServiceZoneList();
      update();
    }
    return _serviceZoneList;
  }

  /// Name of the serving zone nearest to the user's real (out-of-zone) GPS
  /// position — used for the module header's "Coming soon! Closest zone: X"
  /// banner. Returns null when we don't know the real position, the zone list
  /// hasn't loaded, or no zone has usable coordinates. Distance is measured to
  /// each zone's nearest polygon vertex (good enough to name the closest zone
  /// without point-in-polygon math). Loads the zone list lazily on first call.
  String? get closestZoneName {
    final double? lat = outOfZoneRealLat;
    final double? lng = outOfZoneRealLng;
    if (lat == null || lng == null) return null;

    final List<ZoneDataModel>? zones = _serviceZoneList;
    if (zones == null || zones.isEmpty) {
      // Kick off a lazy load so the banner can fill in on the next rebuild.
      getServiceZoneList();
      return null;
    }

    String? nearestName;
    double nearestMeters = double.infinity;
    for (final ZoneDataModel zone in zones) {
      final coords = zone.formatedCoordinates;
      if (zone.name == null || coords == null || coords.isEmpty) continue;
      for (final c in coords) {
        if (c.lat == null || c.lng == null) continue;
        final double d = Geolocator.distanceBetween(lat, lng, c.lat!, c.lng!);
        if (d < nearestMeters) {
          nearestMeters = d;
          nearestName = zone.name;
        }
      }
    }
    return nearestName;
  }

  // ── GPS position as a signal distinct from the delivery address ──
  // The saved address is where we deliver; it changes only when the user says
  // so. These hold where the user actually IS, resolved by
  // refreshOutOfZoneStatus. Keeping them apart is what lets us ASK about a
  // mismatch ("You're a bit far away from your address!") instead of silently
  // moving someone's delivery address out from under them.
  List<int>? _gpsZoneIds;
  String? _gpsAddress;
  String? get gpsAddress => _gpsAddress;

  /// True when the user's real position resolved INSIDE a serving zone that
  /// the saved delivery address does not belong to — i.e. they're somewhere
  /// genuinely different, and we should ask which address they meant.
  ///
  /// False when zones overlap, when either side is unknown, and deliberately
  /// when GPS is out of zone entirely (empty zoneIds): that case has its own
  /// treatment (OUT OF ZONE stamp + "No delivery there"), so routing it here
  /// too would double up on the user.
  bool get gpsZoneDiverges {
    final List<int>? gpsZones = _gpsZoneIds;
    if (gpsZones == null || gpsZones.isEmpty) return false;

    final AddressModel? saved = AddressHelper.getUserAddressFromSharedPref();
    final List<int>? savedZones = saved?.zoneIds;
    if (saved == null || savedZones == null || savedZones.isEmpty) return false;

    return !_hasIntersection(gpsZones, savedZones);
  }

  /// Identifies the current GPS zone for once-per-zone prompt suppression, so
  /// answering "Keep this address" doesn't re-ask on every home load.
  String? get gpsZoneKey {
    final List<int>? gpsZones = _gpsZoneIds;
    if (gpsZones == null || gpsZones.isEmpty) return null;
    final List<int> sorted = List<int>.from(gpsZones)..sort();
    return sorted.join(',');
  }

  DateTime? _lastOutOfZoneCheckAt;

  /// Silently re-checks whether the user's real position is inside a serving
  /// zone, so the out-of-zone hint stays current across launches/refreshes.
  /// Never prompts: runs only when location permission is already granted.
  /// Transient zone-check failures leave the current flag untouched.
  /// Completed GPS checks are throttled to one per few minutes (home reload,
  /// app resume, and pull-to-refresh all call this); permission-denied exits
  /// don't count, so the first check after a grant always runs.
  // The check that is currently running, if any. Splash fires this
  // fire-and-forget and home awaits it moments later; without sharing the
  // in-flight future the second caller would hit the throttle below, return
  // instantly, and read a STALE flag while the real answer was still in
  // flight — which is exactly how an out-of-zone user kept seeing the
  // in-zone seed address on the header after a restart.
  Future<void>? _outOfZoneCheckInFlight;

  Future<void> refreshOutOfZoneStatus() {
    final Future<void>? inFlight = _outOfZoneCheckInFlight;
    if (inFlight != null) return inFlight;
    final Future<void> run = _refreshOutOfZoneStatus().whenComplete(
      () => _outOfZoneCheckInFlight = null,
    );
    _outOfZoneCheckInFlight = run;
    return run;
  }

  Future<void> _refreshOutOfZoneStatus() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
      if (_lastOutOfZoneCheckAt != null &&
          DateTime.now().difference(_lastOutOfZoneCheckAt!) <
              const Duration(minutes: 3)) {
        return;
      }
      _lastOutOfZoneCheckAt = DateTime.now();
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 4));
      ZoneResponseModel response = await _zoneLookup(
        position.latitude.toString(),
        position.longitude.toString(),
      );
      // Where the user actually is, resolved once and reused by both branches.
      final String? label = await _resolveLabel(
        position.latitude,
        position.longitude,
      );

      // Record where the user is. The saved delivery address is NOT touched:
      // GuestGate compares the two and ASKS if they diverge, rather than
      // silently moving an address the user deliberately chose.
      if (response.isSuccess) {
        _gpsZoneIds = List<int>.from(response.zoneIds);
        _gpsAddress = label ?? _gpsAddress;
        update();
      } else if (response.statusCode == 404) {
        _gpsZoneIds = <int>[];
        _gpsAddress = label ?? _gpsAddress;
        update();
      }
    } catch (e) {
      // Never swallow silently — a bare empty catch here hid a hanging zone
      // lookup for a long time. Failures leave the previous flag intact.
      debugPrint('refreshOutOfZoneStatus: $e');
    }
  }

  /// Resolves the device's current position into a saveable [AddressModel],
  /// or null when we can't determine where the user is.
  ///
  /// An out-of-zone result is NOT a failure: the address comes back with empty
  /// zoneIds, which is exactly how out-of-zone is represented now. Only a
  /// missing fix or an unreachable zone lookup returns null — we never
  /// substitute a made-up location.
  Future<AddressModel?> resolveCurrentAddress() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));

      final ZoneResponseModel zone = await _zoneLookup(
        position.latitude.toString(),
        position.longitude.toString(),
      );
      // A transient failure is not a definitive "not served" — don't persist an
      // address whose zone we couldn't establish.
      if (!zone.isSuccess && zone.statusCode != 404) return null;

      final String? label = await _resolveLabel(
        position.latitude,
        position.longitude,
      );

      return AddressModel(
        latitude: position.latitude.toString(),
        longitude: position.longitude.toString(),
        addressType: 'others',
        address: label ?? '',
        zoneId: zone.zoneIds.isNotEmpty ? zone.zoneIds[0] : 0,
        zoneIds: List<int>.from(zone.zoneIds),
        zoneData: List<ZoneData>.from(zone.zoneData),
        areaIds: List<int>.from(zone.areaIds),
      );
    } catch (e) {
      debugPrint('resolveCurrentAddress: $e');
      return null;
    }
  }

  /// Reverse-geocodes a position to a display label, or null when we genuinely
  /// don't know. Never invents a location: callers keep their previous value
  /// rather than showing a placeholder as if it were the user's address.
  Future<String?> _resolveLabel(double lat, double lng) async {
    try {
      final String label = await _geocode(LatLng(lat, lng));
      if (label.isEmpty || label == 'Unknown Location Found') return null;
      return label;
    } catch (_) {
      return null;
    }
  }

  // ── Coordinate-keyed request coalescing ──
  // Boot runs several flows that geocode/zone-check the same fix (out-of-zone
  // hint, dashboard address suggestion, saved-address sync). These helpers
  // collapse identical concurrent requests into one, and short-cache the
  // answer so back-to-back flows don't repeat the network call.
  final Map<String, Future<String>> _geocodeInFlight = {};
  final Map<String, String> _geocodeCache = {};
  final Map<String, DateTime> _geocodeCacheAt = {};
  final Map<String, Future<ZoneResponseModel>> _zoneInFlight = {};
  final Map<String, ZoneResponseModel> _zoneCache = {};
  final Map<String, DateTime> _zoneCacheAt = {};

  Future<String> _geocode(LatLng latLng) {
    final String key =
        '${latLng.latitude.toStringAsFixed(5)},${latLng.longitude.toStringAsFixed(5)}';
    final DateTime? at = _geocodeCacheAt[key];
    final String? cached = _geocodeCache[key];
    // Same guard as _zoneLookup: a timestamp without an entry must not hand
    // back a null typed as non-nullable String.
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 3)) {
      return Future.value(cached);
    }
    return _geocodeInFlight[key] ??= locationServiceInterface
        .getAddressFromGeocode(latLng)
        .then((address) {
          if (address.isNotEmpty && address != 'Unknown Location Found') {
            _geocodeCache[key] = address;
            _geocodeCacheAt[key] = DateTime.now();
          }
          return address;
        })
        .whenComplete(() {
          // Block body, NOT an arrow: `=> map.remove(key)` returned the removed
          // value — this very future — and whenComplete AWAITS a returned future,
          // so the chain deadlocked on itself and no awaiter ever resumed.
          _geocodeInFlight.remove(key);
        });
  }

  Future<ZoneResponseModel> _zoneLookup(
    String? lat,
    String? lng, {
    bool handleError = false,
  }) {
    // Round the key: raw GPS jitters in the 12th decimal, so full-precision
    // keys NEVER repeat and both the cache and the in-flight coalescing were
    // dead code. ~1m of precision is far finer than any zone boundary.
    final String key = '${_round5(lat)},${_round5(lng)}';

    final DateTime? at = _zoneCacheAt[key];
    final ZoneResponseModel? cached = _zoneCache[key];
    // Require BOTH the timestamp and the entry. Checking only the timestamp
    // could return Future.value(null) typed as non-nullable, and the null blew
    // up at the first `.isSuccess` on the caller's side.
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 2)) {
      return Future.value(cached);
    }

    final Future<ZoneResponseModel>? inFlight = _zoneInFlight[key];
    if (inFlight != null) return inFlight;

    final Future<ZoneResponseModel> run = locationServiceInterface
        .getZone(lat, lng, handleError: handleError)
        .then((response) {
          // Cache only definitive answers (in zone / definitely not) —
          // transient failures must stay retryable.
          if (response.statusCode == 200 || response.statusCode == 404) {
            _zoneCache[key] = response;
            _zoneCacheAt[key] = DateTime.now();
          }
          return response;
        })
        .whenComplete(() {
          // Block body, NOT an arrow — see _geocode: returning the removed future
          // from whenComplete made the chain await itself and deadlock.
          _zoneInFlight.remove(key);
        });
    // Store the SAME future callers receive, so a second caller awaits the
    // real result instead of a detached one.
    _zoneInFlight[key] = run;
    return run;
  }

  static String _round5(String? value) {
    final double? d = double.tryParse(value ?? '');
    return d == null ? (value ?? '') : d.toStringAsFixed(5);
  }

  int _zoneID = 0;
  int get zoneID => _zoneID;

  bool _buttonDisabled = true;
  bool get buttonDisabled => _buttonDisabled;

  bool _showLocationSuggestion = true;
  bool get showLocationSuggestion => _showLocationSuggestion;

  bool _changeAddress = true;

  int _addressTypeIndex = 0;
  int get addressTypeIndex => _addressTypeIndex;

  final List<String?> _addressTypeList = ['home', 'office', 'others'];
  List<String?> get addressTypeList => _addressTypeList;

  GoogleMapController? _mapController;
  GoogleMapController? get mapController => _mapController;

  List<PredictionModel> _predictionList = [];
  List<PredictionModel> get predictionList => _predictionList;

  void showSuggestedLocation(bool status) {
    _showLocationSuggestion = status;
  }

  void setAddressTypeIndex(int index, {bool isUpdate = true}) {
    _addressTypeIndex = index;
    if (isUpdate) {
      update();
    }
  }

  void disableButton() {
    _buttonDisabled = true;
    _inZone = true;
    update();
  }

  void setAddAddressData() {
    _position = _pickPosition;
    _address = _pickAddress;
    // The add-address map opens centred on the position just picked, which
    // fires one onCameraIdle for a location whose address we already hold.
    _suppressIdleCount++;
    update();
  }

  void setUpdateAddress(AddressModel address) {
    _position = Position(
      latitude: double.parse(address.latitude!),
      longitude: double.parse(address.longitude!),
      timestamp: DateTime.now(),
      altitude: 1,
      heading: 1,
      speed: 1,
      speedAccuracy: 1,
      floor: 1,
      accuracy: 1,
      altitudeAccuracy: 1,
      headingAccuracy: 1,
    );
    _address = address.address;
    _addressTypeIndex = _addressTypeList.indexOf(address.addressType);
  }

  void setPickData() {
    _pickPosition = _position;
    _pickAddress = _address;
  }

  void setMapController(GoogleMapController mapController) {
    _mapController = mapController;
  }

  Future<AddressModel> getCurrentLocation(
    bool fromAddress, {
    GoogleMapController? mapController,
    LatLng? defaultLatLng,
    bool notify = true,
  }) async {
    _beginLoading(markerLoad: true);
    // This lookup owns the camera; any pan-driven lookup already queued is
    // superseded by it.
    final int requestId = ++_positionRequestId;
    if (notify) {
      update();
    }
    // Every await below must funnel through the finally: an exception that
    // skipped _endLoading left the refcount stranded above zero, so the pin
    // spinner ran forever and the confirm button never enabled.
    try {
      AddressModel addressModel;
      Position myPosition = await locationServiceInterface.getPosition(
        defaultLatLng,
        LatLng(
          double.parse(
            Get.find<SplashController>().configModel.defaultLocation?.lat ??
                '0',
          ),
          double.parse(
            Get.find<SplashController>().configModel.defaultLocation?.lng ??
                '0',
          ),
        ),
      );
      fromAddress ? _position = myPosition : _pickPosition = myPosition;

      // Moving the camera ourselves fires onCameraIdle for a position we are
      // already resolving right here. Swallow that one idle event so it does not
      // start a duplicate lookup that races this one.
      if (mapController != null) {
        _suppressIdleCount++;
      }
      locationServiceInterface.handleMapAnimation(mapController, myPosition);
      String addressFromGeocode = await getAddressFromGeocode(
        LatLng(myPosition.latitude, myPosition.longitude),
      );
      fromAddress
          ? _address = addressFromGeocode
          : _pickAddress = addressFromGeocode;
      ZoneResponseModel responseModel = await getZone(
        myPosition.latitude.toString(),
        myPosition.longitude.toString(),
        true,
      );
      // Only the newest lookup may publish zone/button state. A pan that started
      // after us has already written fresher values; overwriting them here is
      // what made the picker disagree with the pin under it.
      if (requestId == _positionRequestId) {
        _buttonDisabled = !responseModel.isSuccess;
        _inZone = responseModel.isSuccess;
      }

      addressModel = AddressModel(
        latitude: myPosition.latitude.toString(),
        longitude: myPosition.longitude.toString(),
        addressType: 'others',
        zoneId: responseModel.isSuccess ? responseModel.zoneIds[0] : 0,
        zoneIds: responseModel.zoneIds,
        address: addressFromGeocode,
        zoneData: responseModel.zoneData,
        areaIds: responseModel.areaIds,
      );
      return addressModel;
    } catch (e) {
      debugPrint('[Waddy] getCurrentLocation failed: $e');
      rethrow;
    } finally {
      _endLoading(markerLoad: true);
      update();
    }
  }

  Future<String> getAddressFromGeocode(LatLng latLng) async {
    return await _geocode(latLng);
  }

  Future<ZoneResponseModel> getZone(
    String? lat,
    String? lng,
    bool markerLoad, {
    bool updateInAddress = false,
    bool handleError = false,
  }) async {
    _beginLoading(markerLoad: markerLoad);
    try {
      // update() rebuilds listeners synchronously — inside the try, so a build
      // exception cannot skip the finally and strand the loading refcount.
      if (!updateInAddress) {
        update();
      }
      ZoneResponseModel responseModel = await _zoneLookup(
        lat,
        lng,
        handleError: handleError,
      );
      _inZone = responseModel.isSuccess;
      _zoneID = responseModel.zoneIds.isNotEmpty ? responseModel.zoneIds[0] : 0;
      if (updateInAddress && responseModel.isSuccess) {
        AddressModel address = AddressHelper.getUserAddressFromSharedPref()!;
        address.zoneData = responseModel.zoneData;
        AddressHelper.saveUserAddressInSharedPref(address);
      }
      return responseModel;
    } catch (e) {
      // A thrown zone lookup (network error, bad response) must not leave the
      // button spinning forever. Treat it as "not in zone" and fall through to
      // the finally so the loading flag always resets. Previously, an exception
      // here skipped the `_loading = false` line and the confirm button stuck
      // on "Loading…" indefinitely (e.g. after selecting an out-of-zone area).
      debugPrint('[Waddy] getZone threw: $e');
      _inZone = false;
      return ZoneResponseModel(false, '', [], [], [], null);
    } finally {
      _endLoading(markerLoad: markerLoad);
      update();
    }
  }

  Future<void> syncZoneData() async {
    bool hasInternet = await checkInternet();
    if (!hasInternet) {
      return;
    }

    ZoneResponseModel response = await getZone(
      AddressHelper.getUserAddressFromSharedPref()!.latitude,
      AddressHelper.getUserAddressFromSharedPref()!.longitude,
      false,
      updateInAddress: true,
    );
    if (response.zoneIds.isEmpty) {
      // Only a definitive 404 means the saved location is genuinely outside
      // every serving zone. Transient failures (network blip, 5xx, timeout)
      // also come back with empty zoneIds — evicting the address on those
      // would kick users to the location wizard for no reason.
      if (response.statusCode == 404) {
        // The saved address is a real place the user is at or chose, and we
        // simply don't serve it. Persist the empty zoneIds — that IS the
        // out-of-zone state now — and let them keep browsing behind the OUT OF
        // ZONE badge. Never evict to the picker: doing so trapped users whose
        // real home is outside every zone in an inescapable map loop.
        // Ordering is gated later by GuestGate.checkoutGuard.
        final AddressModel address =
            AddressHelper.getUserAddressFromSharedPref()!;
        address.zoneId = 0;
        address.zoneIds = <int>[];
        address.zoneData = <ZoneData>[];
        address.areaIds = <int>[];
        await AddressHelper.saveUserAddressInSharedPref(address);
      }
    } else {
      final bool wasOutOfZone = outOfServingZone;
      AddressModel address = AddressHelper.getUserAddressFromSharedPref()!;
      address.zoneId = response.zoneIds[0];
      address.zoneIds = [];
      address.zoneIds!.addAll(response.zoneIds);
      address.zoneData = [];
      address.zoneData!.addAll(response.zoneData);
      address.areaIds = [];
      address.areaIds!.addAll(response.areaIds);
      await AddressHelper.saveUserAddressInSharedPref(address);
      // Saving non-empty zoneIds is what clears the derived flag; this only
      // resets the once-per-episode prompts.
      if (wasOutOfZone) onBackInServingZone();
    }
    update();
  }

  void updatePosition(CameraPosition? position, bool fromAddress) async {
    if (position == null) {
      return;
    }
    // A camera move we made ourselves (getCurrentLocation's animation, or the
    // add-address screen seeding the map) is not a user pan — the position it
    // settles on is already being resolved by whoever moved it.
    if (_suppressIdleCount > 0) {
      _suppressIdleCount--;
      return;
    }
    _beginLoading(markerLoad: true);
    final int requestId = ++_positionRequestId;
    update();

    // Same rule as getCurrentLocation: every exit — early return, thrown zone
    // or geocode lookup — must release the loading refcount, or the pin
    // spinner runs forever.
    try {
      final Position panned = Position(
        latitude: position.target.latitude,
        longitude: position.target.longitude,
        timestamp: DateTime.now(),
        heading: 1,
        accuracy: 1,
        altitude: 1,
        speedAccuracy: 1,
        speed: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      );
      fromAddress ? _position = panned : _pickPosition = panned;

      ZoneResponseModel responseModel = await getZone(
        position.target.latitude.toString(),
        position.target.longitude.toString(),
        true,
      );
      // A newer pan superseded us while the zone call was in flight — its
      // answer describes where the pin actually is, so drop ours rather than
      // overwriting it.
      if (requestId != _positionRequestId) {
        return;
      }
      // Keep the in-zone flag in step with the answer we just got. Only
      // _buttonDisabled was updated here, so the picker's label could keep
      // claiming "Service not available in this area" while standing on a
      // perfectly served address.
      _inZone = responseModel.isSuccess;
      _buttonDisabled = !responseModel.isSuccess;
      if (_changeAddress) {
        String addressFromGeocode = await getAddressFromGeocode(
          LatLng(position.target.latitude, position.target.longitude),
        );
        // Same guard after the geocode await: the address shown under the pin
        // must come from the last pan, not an earlier one that resolved late.
        if (requestId == _positionRequestId) {
          fromAddress
              ? _address = addressFromGeocode
              : _pickAddress = addressFromGeocode;
        }
      } else {
        _changeAddress = true;
      }
    } catch (e) {
      debugPrint('[Waddy] updatePosition failed: $e');
    } finally {
      _endLoading(markerLoad: true);
      update();
    }
  }

  void saveAddressAndNavigate(
    AddressModel? address,
    bool fromSignUp,
    String? route,
    bool canRoute,
    bool isDesktop,
  ) {
    _prepareZoneData(address!, fromSignUp, route, canRoute, isDesktop);
  }

  void _prepareZoneData(
    AddressModel address,
    bool fromSignUp,
    String? route,
    bool canRoute,
    bool isDesktop,
  ) async {
    bool hasInternet = await checkInternet();
    if (!hasInternet) {
      return;
    }

    getZone(address.latitude, address.longitude, false).then((response) async {
      if (response.isSuccess) {
        Get.find<CartController>().getCartDataOnline();
        address.zoneId = response.zoneIds[0];
        address.zoneIds = [];
        address.zoneIds!.addAll(response.zoneIds);
        address.zoneData = [];
        address.zoneData!.addAll(response.zoneData);
        address.areaIds = [];
        address.areaIds!.addAll(response.areaIds);
        autoNavigate(address, fromSignUp, route, canRoute, isDesktop);
      } else {
        if (response.statusCode == 404) {
          // Outside every serving zone. Don't trap the user in the picker —
          // that made their real home un-selectable and looped them straight
          // back to the map. Save the address they actually chose, flag the
          // zone honestly (header shows OUT OF ZONE + the coming-soon banner),
          // and let them browse. Ordering is still gated at checkout by
          // GuestGate.checkoutGuard, which is the right place to stop them.
          // Empty zoneIds on the saved address IS the out-of-zone state.
          address.zoneId = 0;
          address.zoneIds = <int>[];
          address.zoneData = <ZoneData>[];
          address.areaIds = <int>[];
          autoNavigate(address, fromSignUp, route, canRoute, isDesktop);
        } else {
          Get.back();
          showCustomSnackBar(response.message);
          if (route == 'splash') {
            Get.toNamed(RouteHelper.getPickMapRoute(route, false));
          }
        }
      }
    });
  }

  void autoNavigate(
    AddressModel? address,
    bool fromSignUp,
    String? route,
    bool canRoute,
    bool isDesktop,
  ) async {
    if (isDesktop &&
        Get.find<SplashController>().module ==
            null /* && Get.find<SplashController>().configModel!.module == null*/ ) {
      List<int>? zoneIds = address!.zoneIds;
      Map<String, String> header = locationServiceInterface.prepareHeader(
        zoneIds,
      );
      await Get.find<SplashController>().getModules(headers: header);
      if (Get.isDialogOpen!) {
        Get.back();
      }
      Get.dialog(
        ModuleDialogWidget(
          callback: () {
            _saveDataAndFirebaseConfig(
              address,
              fromSignUp,
              route,
              canRoute,
              isDesktop,
            );
          },
        ),
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.7),
      );
    } else {
      _saveDataAndFirebaseConfig(
        address!,
        fromSignUp,
        route,
        canRoute,
        isDesktop,
      );
    }
  }

  void _saveDataAndFirebaseConfig(
    AddressModel address,
    bool fromSignUp,
    String? route,
    bool canRoute,
    bool isDesktop,
  ) async {
    locationServiceInterface.configureFirebaseMessaging(address);

    await AddressHelper.saveUserAddressInSharedPref(address);
    if (AuthHelper.isLoggedIn()) {
      if (Get.find<SplashController>().module != null) {
        await Get.find<FavouriteController>().getFavouriteList();
      } else {
        Get.find<SplashController>().getConfigData();
      }
      Get.find<AuthController>().updateZone();
    }
    HomeScreen.loadData(true);
    Get.find<CheckoutController>().clearPrevData();

    locationServiceInterface.handleRoute(fromSignUp, route, canRoute);
  }

  bool _hasIntersection(List<int> list1, List<int> list2) {
    return list1.toSet().intersection(list2.toSet()).isNotEmpty;
  }

  Future<AddressModel> setLocation(
    String? placeID,
    String? address,
    GoogleMapController? mapController,
  ) async {
    _beginLoading(markerLoad: true);
    // A search result supersedes any pan still resolving, and the camera move
    // below is ours — this lookup owns both.
    final int requestId = ++_positionRequestId;
    update();

    LatLng latLng;
    // Same rule as getCurrentLocation/updatePosition: a thrown place lookup
    // must not skip _endLoading, or the pin spinner stays up forever.
    try {
      latLng = await locationServiceInterface.getLatLng(placeID);

      _pickPosition = Position(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 1,
        heading: 1,
        speed: 1,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      );

      _pickAddress = address;
      _changeAddress = false;

      if (mapController != null) {
        // Our own camera move; the getZone below already resolves this target,
        // so the idle event it fires must not start a competing lookup.
        _suppressIdleCount++;
        try {
          await mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 17),
            ),
          );
        } catch (e) {
          // Map controller may not be ready yet, ignore animation error
        }
      }
    } catch (e) {
      debugPrint('[Waddy] setLocation failed: $e');
      return AddressModel(
        latitude: _pickPosition.latitude.toString(),
        longitude: _pickPosition.longitude.toString(),
        addressType: 'others',
        address: _pickAddress,
      );
    } finally {
      _endLoading(markerLoad: true);
      update();
    }

    // Resolve the zone for the selected place directly, rather than depending on
    // the map's onCameraIdle callback firing after the programmatic camera
    // animation. On a distant target (e.g. searching an out-of-zone area like
    // El Marg) onCameraIdle can fail to fire, so updatePosition never runs and
    // the confirm button — disabled by onCameraMoveStarted → disableButton() —
    // stays stuck on "Loading…"/disabled forever. Running getZone here makes the
    // button reflect the real in-zone/out-of-zone result every time.
    final ZoneResponseModel zoneResponse = await getZone(
      latLng.latitude.toString(),
      latLng.longitude.toString(),
      true,
    );
    // Only publish if the user hasn't panned or searched again since.
    if (requestId == _positionRequestId) {
      _inZone = zoneResponse.isSuccess;
      _buttonDisabled = !zoneResponse.isSuccess;
    }
    update();

    return AddressModel(
      latitude: _pickPosition.latitude.toString(),
      longitude: _pickPosition.longitude.toString(),
      addressType: 'others',
      address: _pickAddress,
    );
  }

  Future<List<PredictionModel>> searchLocation(
    BuildContext context,
    String text, {
    double? latitude,
    double? longitude,
  }) async {
    if (text.isNotEmpty) {
      _predictionList = await locationServiceInterface.searchLocation(
        text,
        latitude: latitude,
        longitude: longitude,
      );
    }
    return _predictionList;
  }

  void setPlaceMark(String address) {
    _address = address;
  }

  void checkPermission(Function onTap) async {
    locationServiceInterface.checkLocationPermission(onTap);
  }

  Future<bool> checkLocationActive() async {
    bool isActiveLocation = await Geolocator.isLocationServiceEnabled();

    if (isActiveLocation) {
      Position myPosition = await locationServiceInterface.getPosition(
        null,
        LatLng(
          double.parse(
            Get.find<SplashController>().configModel.defaultLocation?.lat ??
                '0',
          ),
          double.parse(
            Get.find<SplashController>().configModel.defaultLocation?.lng ??
                '0',
          ),
        ),
      );

      double distance =
          Geolocator.distanceBetween(
            double.parse(
              AddressHelper.getUserAddressFromSharedPref()!.latitude!,
            ),
            double.parse(
              AddressHelper.getUserAddressFromSharedPref()!.longitude!,
            ),
            myPosition.latitude,
            myPosition.longitude,
          ) /
          1000;

      if (kDebugMode) {
        print('======== distance is : $distance');
      }
      if (distance > 1) {
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  }

  Future<void> navigateToLocationScreen(
    String page, {
    bool offNamed = false,
    bool offAll = false,
  }) async {
    bool fromSignup = page == RouteHelper.signUp;
    bool fromHome = page == 'home';

    if (!fromHome && AddressHelper.getUserAddressFromSharedPref() != null) {
      Get.dialog(const CustomLoaderWidget(), barrierDismissible: false);
      autoNavigate(
        AddressHelper.getUserAddressFromSharedPref(),
        fromSignup,
        null,
        false,
        false,
      );
    } else if (AuthHelper.isLoggedIn()) {
      Get.dialog(const CustomLoaderWidget(), barrierDismissible: false);
      await Get.find<AddressController>().getAddressList();
      Get.back();
      locationServiceInterface.authorizeNavigation(
        page,
        Get.find<AddressController>().addressList,
        mapController,
        offNamed: offNamed,
        offAll: offAll,
      );
    } else {
      // locationServiceInterface.defaultNavigation(page, mapController);
      _checkPermission(page);
    }
  }

  void _checkPermission(String page) async {
    bool hasInternet = await checkInternet();
    if (!hasInternet) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      Get.toNamed(RouteHelper.getPickMapRoute(page, false));
    } else {
      if (page == 'home') {
        Get.toNamed(RouteHelper.getPickMapRoute(page, false));
      } else if (await _locationCheck()) {
        Get.dialog(const CustomLoaderWidget(), barrierDismissible: false);
        await Get.find<LocationController>().getCurrentLocation(false).then((
          value,
        ) {
          if (value.latitude != null) {
            _onPickAddressButtonPressed(Get.find<LocationController>(), page);
          }
        });
      } else {
        Get.toNamed(RouteHelper.getPickMapRoute(page, false));
      }
    }
  }

  Future<bool> _locationCheck() async {
    Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
    }
    return serviceEnabled;
  }

  void _onPickAddressButtonPressed(
    LocationController locationController,
    String page,
  ) {
    if (locationController.pickPosition.latitude != 0 &&
        locationController.pickAddress!.isNotEmpty) {
      AddressModel address = AddressModel(
        latitude: locationController.pickPosition.latitude.toString(),
        longitude: locationController.pickPosition.longitude.toString(),
        addressType: 'others',
        address: locationController.pickAddress,
      );
      locationController.saveAddressAndNavigate(
        address,
        false,
        page,
        false,
        false,
      );
    } else {
      showCustomSnackBar('pick_an_address'.tr);
    }
  }

  Future<void> setStoreAddressToUserAddress(LatLng storeAddress) async {
    Position storePosition = Position(
      latitude: storeAddress.latitude,
      longitude: storeAddress.longitude,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 1,
      heading: 1,
      speed: 1,
      speedAccuracy: 1,
      altitudeAccuracy: 1,
      headingAccuracy: 1,
    );
    String addressFromGeocode = await getAddressFromGeocode(
      LatLng(storeAddress.latitude, storeAddress.longitude),
    );
    ZoneResponseModel responseModel = await getZone(
      storePosition.latitude.toString(),
      storePosition.longitude.toString(),
      true,
    );
    _buttonDisabled = !responseModel.isSuccess;
    AddressModel addressModel = AddressModel(
      latitude: storePosition.latitude.toString(),
      longitude: storePosition.longitude.toString(),
      addressType: 'others',
      zoneId: responseModel.isSuccess ? responseModel.zoneIds[0] : 0,
      zoneIds: responseModel.zoneIds,
      address: addressFromGeocode,
      zoneData: responseModel.zoneData,
      areaIds: responseModel.areaIds,
    );
    await AddressHelper.saveUserAddressInSharedPref(addressModel);

    await Get.find<SplashController>().getModules();
    // The zone changed under an open store, so re-adopt that store's module
    // from the new zone's list. It may not be served here at all, in which case
    // activateModuleFor does nothing — which is the honest outcome, and better
    // than the old loop, which kept scanning after a match and could set the
    // module twice.
    await Get.find<SplashController>().activateModuleFor(
      Get.find<StoreController>().store!.moduleId,
    );
  }

  Future<bool> checkInternet() async {
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());
    bool isConnected =
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile);
    if (!isConnected && !Platform.isIOS) {
      Get.offAll(() => const NoInternetScreen());
      return false;
    }
    return true;
  }
}
