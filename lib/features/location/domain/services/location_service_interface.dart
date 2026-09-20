import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/features/location/domain/models/prediction_model.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_data_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_request_model.dart';

abstract class LocationServiceInterface {
  Future<List<ZoneDataModel>?> getServiceZoneList();
  Future<ZoneRequestResult?> submitZoneRequest(ZoneRequestBody body);

  Future<Position> getPosition(LatLng? defaultLatLng, LatLng configLatLng);
  void handleMapAnimation(
    GoogleMapController? mapController,
    Position myPosition,
  );
  Future<String> getAddressFromGeocode(LatLng latLng);
  Future<ZoneResponseModel> getZone(
    String? lat,
    String? lng, {
    bool handleError = false,
  });
  Map<String, String> prepareHeader(List<int>? zoneIds);
  void configureFirebaseMessaging(AddressModel address);
  void handleRoute(bool fromSignUp, String? route, bool canRoute);
  Future<LatLng> getLatLng(String? id);
  Future<List<PredictionModel>> searchLocation(
    String text, {
    double? latitude,
    double? longitude,
  });
  void checkLocationPermission(Function onTap);
  Future<void> authorizeNavigation(
    String page,
    List<AddressModel>? addressList,
    GoogleMapController? mapController, {
    bool offNamed = false,
    bool offAll = false,
  });
  void defaultNavigation(String page, GoogleMapController? mapController);
}
