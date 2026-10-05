import 'package:get/get_connect/connect.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/common/models/response_model.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/address/domain/repositories/address_repository_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

class AddressRepository implements AddressRepositoryInterface<AddressModel> {
  final ApiClient apiClient;

  AddressRepository({required this.apiClient});

  /// Carries a local voice recording through the generic `update(body, id)`
  /// interface; stripped out of the body before it is sent.
  static const String voicePathKey = '_voice_instruction_path';

  /// Multipart when a voice file rides along — the address endpoints take it
  /// as `voice_instruction`, like order placement does. Lists and nulls are
  /// dropped: multipart fields are strings, and the endpoints read none of
  /// the list fields.
  Future<Response> _send(
    String uri,
    Map<String, dynamic> body, {
    required String? voicePath,
    bool isUpdate = false,
  }) {
    if (voicePath == null) {
      return isUpdate
          ? apiClient.putData(uri, body)
          : apiClient.postData(uri, body, handleError: false);
    }
    final Map<String, String> fields = {
      for (final e in body.entries)
        if (e.value != null && e.value is! List) e.key: e.value.toString(),
      // PHP only parses multipart bodies on POST; Laravel routes it as PUT.
      if (isUpdate) '_method': 'put',
    };
    return apiClient.postMultipartData(uri, fields, [
      MultipartBody('voice_instruction', XFile(voicePath)),
    ], handleError: false);
  }

  @override
  Future add(AddressModel addressModel) async {
    return await _addAddress(addressModel);
  }

  Future<ResponseModel> _addAddress(AddressModel addressModel) async {
    Response response = await _send(
      AppConstants.addAddressUri,
      addressModel.toJson(),
      voicePath: addressModel.voiceInstructionPath,
    );
    if (response.statusCode == 200) {
      String? message = response.body["message"];
      List<int> zoneIds = [];
      response.body['zone_ids'].forEach((z) => zoneIds.add(z));
      return ResponseModel(true, message, zoneIds: zoneIds);
    } else {
      return ResponseModel(
        false,
        response.statusText == 'Out of coverage!'
            ? 'service_not_available_in_this_area'.tr
            : response.statusText,
      );
    }
  }

  @override
  Future delete(int? id) async {
    return await _removeAddressByID(id);
  }

  Future<ResponseModel> _removeAddressByID(int? id) async {
    Response response = await apiClient.postData(
      '${AppConstants.removeAddressUri}$id',
      {"_method": "delete"},
      handleError: false,
    );
    if (response.statusCode == 200) {
      return ResponseModel(true, response.body['message']);
    } else {
      return ResponseModel(false, response.statusText);
    }
  }

  @override
  Future get(String? id) {
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset}) async {
    return await _getAllAddress();
  }

  Future<List<AddressModel>?> _getAllAddress() async {
    List<AddressModel>? addressList;
    Response response = await apiClient.getData(AppConstants.addressListUri);
    if (response.statusCode == 200) {
      addressList = [];
      response.body['addresses'].forEach((address) {
        addressList!.add(AddressModel.fromJson(address));
      });
    }
    return addressList;
  }

  @override
  Future update(Map<String, dynamic> body, int? id) async {
    return await _updateAddress(body, id);
  }

  Future<ResponseModel> _updateAddress(
    Map<String, dynamic> addressBody,
    int? addressId,
  ) async {
    final Map<String, dynamic> body = Map.of(addressBody);
    final String? voicePath = body.remove(voicePathKey) as String?;
    Response response = await _send(
      '${AppConstants.updateAddressUri}$addressId',
      body,
      voicePath: voicePath,
      isUpdate: true,
    );
    if (response.statusCode == 200) {
      return ResponseModel(true, response.body["message"]);
    } else {
      return ResponseModel(false, response.statusText);
    }
  }
}
