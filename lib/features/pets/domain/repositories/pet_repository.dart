import 'dart:convert';

import 'package:get/get_connect/http/src/response/response.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/pets/domain/models/pet_category_model.dart';
import 'package:waddy_app/features/pets/domain/models/pet_usual_model.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/domain/models/vet_clinic_model.dart';
import 'package:waddy_app/features/pets/domain/repositories/pet_repository_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

class PetRepository implements PetRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;

  PetRepository({required this.apiClient, required this.sharedPreferences});

  @override
  Future<List<UserPetModel>?> getPets() async {
    final Response response = await apiClient.getData(
      AppConstants.petsListUri,
      handleError: false,
    );
    if (response.statusCode != 200 || response.body is! List) return null;
    return (response.body as List)
        .whereType<Map>()
        .map((e) => UserPetModel.fromJson(Map<String, dynamic>.from(e)))
        .whereType<UserPetModel>()
        .toList();
  }

  @override
  Future<Response> addPet(UserPetModel pet, {XFile? photo}) {
    // handleError: false — the API answers a new pet with 201, and the
    // shared handler treats anything but 200 as a failure: it showed an error
    // and returned an empty response for a pet that HAD been saved, so every
    // retry created another one. The caller checks the status itself.
    return apiClient.postMultipartData(
      AppConstants.petsAddUri,
      pet.toRequest(),
      [if (photo != null) MultipartBody('photo', photo)],
      handleError: false,
    );
  }

  @override
  Future<Response> updatePet(
    int id,
    UserPetModel pet, {
    XFile? photo,
    bool removePhoto = false,
  }) {
    return apiClient.postMultipartData(
      '${AppConstants.petsUpdateUri}$id',
      {...pet.toRequest(), if (removePhoto) 'remove_photo': '1'},
      [if (photo != null) MultipartBody('photo', photo)],
      handleError: false,
    );
  }

  @override
  Future<Response> deletePet(int id) {
    return apiClient.deleteData('${AppConstants.petsDeleteUri}$id');
  }

  @override
  Future<List<VetClinicModel>?> getClinics(double lat, double lng) async {
    // In the URI: ApiClient.getData takes a `query:` argument but never
    // sends it, and without lat/lng the request was redirected to an HTML
    // page (a 200 the list parser rejected, so the clinic rail hid itself).
    final Response response = await apiClient.getData(
      '${AppConstants.petsClinicsUri}?lat=$lat&lng=$lng',
      handleError: false,
    );
    if (response.statusCode != 200 || response.body is! List) return null;
    return (response.body as List)
        .whereType<Map>()
        .map((e) => VetClinicModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<PetCategoryModel>?> getCategories() async {
    final Response response = await apiClient.getData(
      AppConstants.petsCategoriesUri,
      handleError: false,
    );
    if (response.statusCode != 200 || response.body is! List) return null;
    return (response.body as List)
        .whereType<Map>()
        .map((e) => PetCategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .whereType<PetCategoryModel>()
        .toList();
  }

  @override
  Future<PetUsualModel?> getUsual() async {
    final Response response = await apiClient.getData(
      AppConstants.petsUsualUri,
      handleError: false,
    );
    if (response.statusCode != 200) return null;
    return PetUsualModel.fromJson(response.body);
  }

  @override
  Future<PetReminderModel?> setReminder({
    required int itemId,
    required int storeId,
    required int intervalDays,
    int? petId,
  }) async {
    final Response response = await apiClient
        .postData(AppConstants.petsRemindersUri, {
          'item_id': itemId,
          'store_id': storeId,
          'interval_days': intervalDays,
          if (petId != null) 'user_pet_id': petId,
        });
    if (response.statusCode != 200) return null;
    return PetReminderModel.fromJson(response.body);
  }

  @override
  Future<bool> deleteReminder(int id) async {
    final Response response = await apiClient.deleteData(
      '${AppConstants.petsRemindersUri}/$id',
    );
    return response.statusCode == 200;
  }

  @override
  bool getOnboardingSeen() =>
      sharedPreferences.getBool(AppConstants.petOnboardingSeen) ?? false;

  @override
  Future<void> setOnboardingSeen() async {
    await sharedPreferences.setBool(AppConstants.petOnboardingSeen, true);
  }

  @override
  UserPetModel? getDraft() {
    final String? raw = sharedPreferences.getString(AppConstants.petDraft);
    if (raw == null) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      return decoded is Map
          ? UserPetModel.fromDraftJson(Map<String, dynamic>.from(decoded))
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDraft(UserPetModel pet) async {
    await sharedPreferences.setString(
      AppConstants.petDraft,
      jsonEncode(pet.toDraftJson()),
    );
  }

  @override
  Future<void> clearDraft() async {
    await sharedPreferences.remove(AppConstants.petDraft);
  }
}
