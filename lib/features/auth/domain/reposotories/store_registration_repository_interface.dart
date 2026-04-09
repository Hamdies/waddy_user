import 'package:get/get_connect.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/auth/domain/models/store_body_model.dart';
import 'package:waddy_app/features/business/domain/models/package_model.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class StoreRegistrationRepositoryInterface extends RepositoryInterface{
  Future<Response> registerStore(StoreBodyModel store, XFile? logo, XFile? cover, List<MultipartDocument> tinFiles);
  Future<bool> checkInZone(String? lat, String? lng, int zoneId);
  Future<PackageModel?> getPackageList({int? moduleId});
}