import 'package:get/get_connect/http/src/response/response.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/features/location/domain/models/zone_data_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_request_model.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class LocationRepositoryInterface<T> implements RepositoryInterface {
  Future<String> getAddressFromGeocode(LatLng latLng);
  Future<ZoneResponseModel> getZone(
    String? lat,
    String? lng, {
    bool handleError = false,
  });
  Future<Response> searchLocation(
    String text, {
    double? latitude,
    double? longitude,
  });
  Future<List<ZoneDataModel>?> getServiceZoneList();
  Future<ZoneRequestResult?> submitZoneRequest(ZoneRequestBody body);
}
