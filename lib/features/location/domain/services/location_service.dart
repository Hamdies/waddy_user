import 'dart:convert';
import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/features/location/domain/models/prediction_model.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_data_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_request_model.dart';
import 'package:waddy_app/features/location/domain/repositories/location_repository_interface.dart';
import 'package:waddy_app/features/location/domain/services/location_service_interface.dart';
import 'package:waddy_app/features/location/widgets/permission_dialog_widget.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';

class LocationService implements LocationServiceInterface {
  final LocationRepositoryInterface locationRepoInterface;
  LocationService({required this.locationRepoInterface});

  @override
  Future<String> getAddressFromGeocode(LatLng latLng) async {
    return await locationRepoInterface.getAddressFromGeocode(latLng);
  }

  @override
  Future<ZoneResponseModel> getZone(
    String? lat,
    String? lng, {
    bool handleError = false,
  }) async {
    return await locationRepoInterface.getZone(
      lat,
      lng,
      handleError: handleError,
    );
  }

  @override
  Future<List<ZoneDataModel>?> getServiceZoneList() async {
    return await locationRepoInterface.getServiceZoneList();
  }

  @override
  Future<ZoneRequestResult?> submitZoneRequest(ZoneRequestBody body) async {
    return await locationRepoInterface.submitZoneRequest(body);
  }

  @override
  Future<Position> getPosition(
    LatLng? defaultLatLng,
    LatLng configLatLng,
  ) async {
    Position myPosition;
    try {
      // Without a timeout, a denied/blocked permission can leave this await
      // hanging forever on iOS — the pick-map then spins indefinitely because
      // the fallback below is never reached.
      Position newLocalData = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 5));
      myPosition = newLocalData;
      log(
        '[Waddy] getPosition: GPS ok ${myPosition.latitude},${myPosition.longitude}',
      );
    } catch (e) {
      log('[Waddy] getPosition: GPS failed ($e), using fallback');
      myPosition = Position(
        latitude:
            defaultLatLng != null
                ? defaultLatLng.latitude
                : configLatLng.latitude,
        longitude:
            defaultLatLng != null
                ? defaultLatLng.longitude
                : configLatLng.longitude,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 1,
        heading: 1,
        speed: 1,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      );
    }
    return myPosition;
  }

  @override
  void handleMapAnimation(
    GoogleMapController? mapController,
    Position myPosition,
  ) {
    if (mapController != null) {
      // This future was fired unawaited: a platform-side rejection became an
      // UNHANDLED async error (routed through PlatformDispatcher.onError →
      // Crashlytics) at the exact moment the caller sat parked on its next
      // await. Swallow it here — a failed camera animation is cosmetic.
      mapController
          .animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(myPosition.latitude, myPosition.longitude),
                zoom: 16,
              ),
            ),
          )
          .catchError((e) {
            log('[Waddy] animateCamera error: $e');
          });
    }
  }

  @override
  Map<String, String> prepareHeader(List<int>? zoneIds) {
    Map<String, String> header = {
      'Content-Type': 'application/json; charset=UTF-8',
      AppConstants.zoneId: zoneIds != null ? jsonEncode(zoneIds) : '',
    };
    return header;
  }

  @override
  void configureFirebaseMessaging(AddressModel address) {
    if (Get.find<SplashController>().configModel.demo!) {
      FirebaseMessaging.instance.subscribeToTopic('demo_reset');
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic('demo_reset');
    }
    if (AddressHelper.getUserAddressFromSharedPref() != null) {
      if (AddressHelper.getUserAddressFromSharedPref()!.zoneIds != null) {
        for (int zoneID
            in AddressHelper.getUserAddressFromSharedPref()!.zoneIds!) {
          FirebaseMessaging.instance.unsubscribeFromTopic(
            'zone_${zoneID}_customer',
          );
        }
      } else {
        FirebaseMessaging.instance.unsubscribeFromTopic(
          'zone_${AddressHelper.getUserAddressFromSharedPref()!.zoneId}_customer',
        );
      }
    } else {
      FirebaseMessaging.instance.subscribeToTopic(
        'zone_${address.zoneId}_customer',
      );
    }
    if (address.zoneIds != null) {
      for (int zoneID in address.zoneIds!) {
        FirebaseMessaging.instance.subscribeToTopic('zone_${zoneID}_customer');
      }
    } else {
      FirebaseMessaging.instance.subscribeToTopic(
        'zone_${address.zoneId}_customer',
      );
    }
  }

  @override
  void handleRoute(bool fromSignUp, String? route, bool canRoute) {
    if (route != null && canRoute) {
      Get.offAllNamed(route);
    } else {
      Get.offAllNamed(RouteHelper.getInitialRoute());
    }
  }

  @override
  Future<LatLng> getLatLng(String? id) async {
    LatLng latLng = const LatLng(0, 0);
    Response? response = await locationRepoInterface.get(id);
    if (response?.statusCode == 200) {
      final data = response?.body;
      final location = data['location'];
      final double lat = location['latitude'];
      final double lng = location['longitude'];
      latLng = LatLng(lat, lng);
    }
    return latLng;
  }

  @override
  Future<List<PredictionModel>> searchLocation(
    String text, {
    double? latitude,
    double? longitude,
  }) async {
    List<PredictionModel> predictionList = [];
    Response response = await locationRepoInterface.searchLocation(
      text,
      latitude: latitude,
      longitude: longitude,
    );
    if (response.statusCode == 200) {
      predictionList = [];
      try {
        response.body['suggestions'].forEach(
          (prediction) =>
              predictionList.add(PredictionModel.fromJson(prediction)),
        );
      } catch (e) {
        log('$e');
      }
    } else {
      showCustomSnackBar(
        response.body?['error_message'] ?? response.bodyString,
      );
    }
    return predictionList;
  }

  @override
  void checkLocationPermission(Function onTap) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      showCustomSnackBar('you_have_to_allow'.tr);
    } else if (permission == LocationPermission.deniedForever) {
      Get.dialog(const PermissionDialogWidget());
    } else {
      onTap();
    }
  }

  @override
  Future<void> authorizeNavigation(
    String page,
    List<AddressModel>? addressList,
    GoogleMapController? mapController, {
    bool offNamed = false,
    bool offAll = false,
  }) async {
    if (addressList != null && addressList.isEmpty) {
      Get.toNamed(RouteHelper.getPickMapRoute(page, false));
    } else {
      if (offNamed) {
        Get.offNamed(RouteHelper.getAccessLocationRoute(page));
      } else if (offAll) {
        Get.offAllNamed(RouteHelper.getAccessLocationRoute(page));
      } else {
        Get.toNamed(RouteHelper.getAccessLocationRoute(page));
      }
    }
  }

  @override
  void defaultNavigation(String page, GoogleMapController? mapController) {
    Get.toNamed(RouteHelper.getPickMapRoute(page, false));
  }
}
