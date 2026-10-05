import 'package:get/get_connect/http/src/response/response.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/features/pets/domain/models/pet_category_model.dart';
import 'package:waddy_app/features/pets/domain/models/pet_usual_model.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/domain/models/vet_clinic_model.dart';
import 'package:waddy_app/features/pets/domain/repositories/pet_repository_interface.dart';
import 'package:waddy_app/features/pets/domain/services/pet_service_interface.dart';

class PetService implements PetServiceInterface {
  final PetRepositoryInterface petRepositoryInterface;

  PetService({required this.petRepositoryInterface});

  @override
  Future<List<UserPetModel>?> getPets() => petRepositoryInterface.getPets();

  @override
  Future<Response> addPet(UserPetModel pet, {XFile? photo}) =>
      petRepositoryInterface.addPet(pet, photo: photo);

  @override
  Future<Response> updatePet(
    int id,
    UserPetModel pet, {
    XFile? photo,
    bool removePhoto = false,
  }) => petRepositoryInterface.updatePet(
    id,
    pet,
    photo: photo,
    removePhoto: removePhoto,
  );

  @override
  Future<Response> deletePet(int id) => petRepositoryInterface.deletePet(id);

  @override
  Future<List<VetClinicModel>?> getClinics(double lat, double lng) =>
      petRepositoryInterface.getClinics(lat, lng);

  @override
  Future<List<PetCategoryModel>?> getCategories() =>
      petRepositoryInterface.getCategories();

  @override
  Future<PetUsualModel?> getUsual() => petRepositoryInterface.getUsual();

  @override
  Future<PetReminderModel?> setReminder({
    required int itemId,
    required int storeId,
    required int intervalDays,
    int? petId,
  }) => petRepositoryInterface.setReminder(
    itemId: itemId,
    storeId: storeId,
    intervalDays: intervalDays,
    petId: petId,
  );

  @override
  Future<bool> deleteReminder(int id) =>
      petRepositoryInterface.deleteReminder(id);

  @override
  bool getOnboardingSeen() => petRepositoryInterface.getOnboardingSeen();

  @override
  Future<void> setOnboardingSeen() =>
      petRepositoryInterface.setOnboardingSeen();

  @override
  UserPetModel? getDraft() => petRepositoryInterface.getDraft();

  @override
  Future<void> saveDraft(UserPetModel pet) =>
      petRepositoryInterface.saveDraft(pet);

  @override
  Future<void> clearDraft() => petRepositoryInterface.clearDraft();
}
