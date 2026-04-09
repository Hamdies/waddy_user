import 'package:get/get_connect/http/src/response/response.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/location/domain/models/zone_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/location/domain/repositories/location_repository_interface.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';

class LocationRepository implements LocationRepositoryInterface {
  final ApiClient apiClient;

  LocationRepository({required this.apiClient});

  @override
  Future<String> getAddressFromGeocode(LatLng latLng) async {
    Response response = await apiClient.getData('${AppConstants.geocodeUri}?lat=${latLng.latitude}&lng=${latLng.longitude}', handleError: false);
    String address = 'Unknown Location Found';
    if(response.statusCode == 200 && response.body['status'] == 'OK') {
      address = response.body['results'][0]['formatted_address'].toString();
    }else {
      showCustomSnackBar(response.body['error_message'] ?? response.bodyString);
    }
    return address;
  }

  @override
  Future<ZoneResponseModel> getZone(String? lat, String? lng, {bool handleError = false}) async {
    Response response = await apiClient.getData('${AppConstants.zoneUri}?lat=$lat&lng=$lng', handleError: handleError);
    if(response.statusCode == 200) {
      ZoneResponseModel responseModel;
      List<int>? zoneIds = ZoneModel.fromJson(response.body).zoneIds;
      List<ZoneData>? zoneData = ZoneModel.fromJson(response.body).zoneData;
      responseModel = ZoneResponseModel(true, '' , zoneIds ?? [], zoneData??[], [], response.statusCode);
      return responseModel;
    } else {
      return ZoneResponseModel(false, response.statusText, [], [], [], response.statusCode);
    }
  }

  @override
  Future<Response> searchLocation(String text, {double? latitude, double? longitude}) async {
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
    Response response = await apiClient.getData('${AppConstants.placeDetailsUri}?placeid=$id');
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
