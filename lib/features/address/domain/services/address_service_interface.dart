import 'package:waddy_app/common/models/response_model.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';

abstract class AddressServiceInterface {
  Future<List<AddressModel>?> getAllAddress();
  Future<ResponseModel> removeAddressByID(int? id);
  Future<ResponseModel> addAddress(AddressModel addressModel);
  Future<ResponseModel> updateAddress(
    AddressModel addressModel,
    int? addressId,
  );
}
