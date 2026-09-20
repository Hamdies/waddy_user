import 'package:flutter/foundation.dart';
import 'package:waddy_app/helper/auth_token_store.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/location/domain/models/zone_data_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_request_model.dart';
import 'package:waddy_app/features/location/domain/repositories/location_repository_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

class LocationRepository implements LocationRepositoryInterface {
  final ApiClient apiClient;

  LocationRepository({required this.apiClient});

  /// Guest session id, for endpoints behind APIGuestMiddleware.
  ///
  /// Empty when logged in — the Bearer token identifies the user then, and
  /// sending both would make the server scope the row to the guest namespace
  /// instead of the account. Mirrors CartRepository._guestId.
  String get _guestId {
    try {
      final prefs = Get.find<SharedPreferences>();
      final bool loggedIn =
          AuthTokenStore.hasToken;
      if (loggedIn) return '';
      return prefs.getString(AppConstants.guestId) ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<String> getAddressFromGeocode(LatLng latLng) async {
    Response response = await apiClient.getData(
      '${AppConstants.geocodeUri}?lat=${latLng.latitude}&lng=${latLng.longitude}',
      handleError: false,
    );
    String address = 'Unknown Location Found';
    if (response.statusCode == 200 && response.body['status'] == 'OK') {
      address = response.body['results'][0]['formatted_address'].toString();
    } else {
      // Silent. This runs continuously while the user DRAGS the map pin, so a
      // toast per failed lookup buries the screen. The 'Unknown Location Found'
      // fallback above is already the user-visible signal, and every caller
      // renders it. See docs/snackbar_noise_plan.md RC3.
      debugPrint(
        'geocode failed: ${response.body?['error_message'] ?? response.statusText}',
      );
    }
    return address;
  }

  @override
  Future<ZoneResponseModel> getZone(
    String? lat,
    String? lng, {
    bool handleError = false,
  }) async {
    Response response = await apiClient.getData(
      '${AppConstants.zoneUri}?lat=$lat&lng=$lng',
      handleError: handleError,
    );
    if (response.statusCode == 200) {
      ZoneResponseModel responseModel;
      List<int>? zoneIds = ZoneModel.fromJson(response.body).zoneIds;
      List<ZoneData>? zoneData = ZoneModel.fromJson(response.body).zoneData;
      responseModel = ZoneResponseModel(
        true,
        '',
        zoneIds ?? [],
        zoneData ?? [],
        [],
        response.statusCode,
      );
      return responseModel;
    } else {
      return ZoneResponseModel(
        false,
        response.statusText,
        [],
        [],
        [],
        response.statusCode,
      );
    }
  }

  @override
  Future<List<ZoneDataModel>?> getServiceZoneList() async {
    List<ZoneDataModel>? zoneList;
    Response response = await apiClient.getData(
      AppConstants.zoneListUri,
      handleError: false,
    );
    if (response.statusCode == 200) {
      zoneList = [];
      response.body.forEach(
        (zone) => zoneList!.add(ZoneDataModel.fromJson(zone)),
      );
    }
    return zoneList;
  }

  /// Records a "launch delivery here" request.
  ///
  /// Returns null on ANY failure (network, 4xx, 5xx, missing endpoint) rather
  /// than throwing or surfacing a snackbar: the caller parks the request for
  /// replay and still shows success, because the user's tap is a promise we
  /// keep regardless of whether the server was reachable at that instant.
  @override
  Future<ZoneRequestResult?> submitZoneRequest(ZoneRequestBody body) async {
    try {
      // The APIGuestMiddleware rejects with 401 unless the caller is either
      // authenticated by Bearer token OR sends `guest_id` in the BODY — a
      // header is not enough. Same contract the cart uses; empty when logged
      // in, since the token identifies the user then.
      final Map<String, dynamic> payload = body.toJson();
      final String guestId = _guestId;
      if (guestId.isNotEmpty) payload['guest_id'] = guestId;

      Response response = await apiClient.postData(
        AppConstants.zoneRequestUri,
        payload,
        handleError: false,
      );
      if (response.statusCode == 200 && response.body is Map) {
        return ZoneRequestResult.fromJson(
          Map<String, dynamic>.from(response.body),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Response> searchLocation(
    String text, {
    double? latitude,
    double? longitude,
  }) async {
    String url = '${AppConstants.searchLocationUri}?search_text=$text';
    if (latitude != null && longitude != null) {
      url += '&lat=$latitude&lng=$longitude';
    }
    return await apiClient.getData(url);
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
  Future<Response> get(String? id) async {
    Response response = await apiClient.getData(
      '${AppConstants.placeDetailsUri}?placeid=$id',
    );
    return response;
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
