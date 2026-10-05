import 'package:get/get_connect/http/src/response/response.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/features/pets/domain/models/pet_category_model.dart';
import 'package:waddy_app/features/pets/domain/models/pet_usual_model.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/domain/models/vet_clinic_model.dart';

abstract class PetServiceInterface {
  Future<List<UserPetModel>?> getPets();
  Future<Response> addPet(UserPetModel pet, {XFile? photo});
  Future<Response> updatePet(
    int id,
    UserPetModel pet, {
    XFile? photo,
    bool removePhoto = false,
  });
  Future<Response> deletePet(int id);
  Future<List<VetClinicModel>?> getClinics(double lat, double lng);
  Future<List<PetCategoryModel>?> getCategories();

  /// Null when there is nothing to show, or the fetch failed.
  Future<PetUsualModel?> getUsual();
  Future<PetReminderModel?> setReminder({
    required int itemId,
    required int storeId,
    required int intervalDays,
    int? petId,
  });
  Future<bool> deleteReminder(int id);
  bool getOnboardingSeen();
  Future<void> setOnboardingSeen();

  UserPetModel? getDraft();
  Future<void> saveDraft(UserPetModel pet);
  Future<void> clearDraft();
}
