import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/features/pets/domain/models/pet_category_model.dart';
import 'package:waddy_app/features/pets/domain/models/pet_usual_model.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/domain/models/vet_clinic_model.dart';
import 'package:waddy_app/features/pets/domain/services/pet_service_interface.dart';
import 'package:waddy_app/helper/auth_helper.dart';

/// The customer's pets and the clinics near them (Pets module).
///
/// Shops, products and the cart are not here: pet shops are ordinary
/// stores of a grocery-typed module and go through the store and cart
/// controllers like any other (PET-01, docs/pets_module_plan.md).
class PetController extends GetxController implements GetxService {
  final PetServiceInterface petServiceInterface;

  PetController({required this.petServiceInterface});

  // ─── Rebuild scopes ───
  // A plain update() would also repaint the clinic rail every time a pet is
  // edited, and the reverse. Each fetch names the section it changed.
  static const String idPets = 'pets_list';
  static const String idClinics = 'pets_clinics';
  static const String idCategories = 'pets_categories';
  static const String idUsual = 'pets_usual';

  List<UserPetModel>? _pets;
  bool _petsLoading = false;
  UserPetModel? _draft;
  bool _saving = false;

  List<PetCategoryModel>? _categories;
  bool _categoriesLoading = false;

  PetUsualModel? _usual;
  bool _reminderSaving = false;

  List<VetClinicModel>? _clinics;
  bool _clinicsLoading = false;
  bool _clinicsFailed = false;

  /// The signed-in customer's pets, primary first. Null until loaded; for a
  /// guest, a one-item list holding their onboarding draft (if any).
  List<UserPetModel>? get pets {
    if (!AuthHelper.isLoggedIn()) {
      return _draft == null ? const [] : [_draft!];
    }
    return _pets;
  }

  bool get petsLoading => _petsLoading;
  bool get saving => _saving;

  /// The pet the shop opens on and the copy is written for.
  UserPetModel? get primaryPet {
    final List<UserPetModel>? list = pets;
    if (list == null || list.isEmpty) return null;
    return list.firstWhereOrNull((p) => p.isPrimary) ?? list.first;
  }

  /// Whether to show "Meet your pet": nothing saved and nothing drafted.
  /// False while the list is still loading, so onboarding never flashes up
  /// for someone who already has a pet.
  bool get needsOnboarding {
    final List<UserPetModel>? list = pets;
    return list != null && list.isEmpty;
  }

  /// Who the pet shop page was last shopping for (its `_Shopper.key`), so
  /// switching to Cats in one shop still holds in the next. App-session
  /// only; null means "the primary pet".
  String? shopperKey;

  /// The species → needs tree. Null until loaded.
  List<PetCategoryModel>? get categories => _categories;

  /// The main category for [species], or null when the tree has none.
  PetCategoryModel? speciesCategory(PetSpecies species) =>
      _categories?.firstWhereOrNull((c) => c.code == species.wire);

  /// "All pets": bowls, carriers and the rest several species share (D3).
  PetCategoryModel? get allPetsCategory =>
      _categories?.firstWhereOrNull((c) => c.code == 'all');

  /// Whether "Meet your pet" already opened by itself on this device. It
  /// opens once; after a skip the hub keeps a card for it instead.
  bool get onboardingSeen => petServiceInterface.getOnboardingSeen();
  Future<void> markOnboardingSeen() => petServiceInterface.setOnboardingSeen();

  /// "Luna's usual": the last pet food delivered, and its reminder.
  PetUsualModel? get usual => _usual;
  bool get reminderSaving => _reminderSaving;

  List<VetClinicModel>? get clinics => _clinics;
  bool get clinicsLoading => _clinicsLoading;
  bool get clinicsFailed => _clinicsFailed;

  @override
  void onInit() {
    super.onInit();
    _draft = petServiceInterface.getDraft();
  }

  Future<void> getPets({bool reload = false}) async {
    if (!AuthHelper.isLoggedIn()) {
      _draft = petServiceInterface.getDraft();
      update([idPets]);
      return;
    }
    if (_petsLoading || (_pets != null && !reload)) return;
    _petsLoading = true;
    update([idPets]);
    try {
      await _sendDraft();
      final List<UserPetModel>? fetched = await petServiceInterface.getPets();
      // A failed fetch keeps what was on screen instead of blanking it.
      if (fetched != null) _pets = fetched;
    } finally {
      _petsLoading = false;
      update([idPets]);
    }
  }

  /// Saves a pet: to the server when signed in, as the device draft for a
  /// guest. Returns whether it was stored.
  Future<bool> savePet(UserPetModel pet, {XFile? photo}) async {
    if (!AuthHelper.isLoggedIn()) {
      // A guest's photo has nowhere to upload to yet: keep a copy on the
      // device (the picker's own file is temporary) and send it with the
      // draft after sign-in.
      if (photo != null) {
        await File(photo.path).copy((await _draftPhotoFile()).path);
      }
      _draft = pet.copyWith(isPrimary: true);
      await petServiceInterface.saveDraft(_draft!);
      update([idPets]);
      return true;
    }
    _saving = true;
    update([idPets]);
    try {
      final Response response =
          pet.id == null
              ? await petServiceInterface.addPet(pet, photo: photo)
              : await petServiceInterface.updatePet(pet.id!, pet, photo: photo);
      final bool ok = response.statusCode == 200 || response.statusCode == 201;
      if (ok) await _refetch();
      return ok;
    } finally {
      _saving = false;
      update([idPets]);
    }
  }

  Future<bool> deletePet(UserPetModel pet) async {
    if (pet.id == null) {
      _draft = null;
      await petServiceInterface.clearDraft();
      await _deleteDraftPhoto();
      update([idPets]);
      return true;
    }
    final Response response = await petServiceInterface.deletePet(pet.id!);
    final bool ok = response.statusCode == 200;
    if (ok) await _refetch();
    return ok;
  }

  Future<void> setPrimary(UserPetModel pet) async {
    if (pet.isPrimary) return;
    await savePet(pet.copyWith(isPrimary: true));
  }

  /// A guest's onboarding pet, sent the first time the pets are loaded
  /// signed in. Done here rather than in each sign-in path (phone, social,
  /// the auth sheet, the name step) so none of them can forget it. The
  /// draft is dropped only once the server has it, so a failed send is
  /// retried next time instead of losing the pet.
  Future<void> _sendDraft() async {
    final UserPetModel? draft = petServiceInterface.getDraft();
    if (draft == null) return;
    final File photo = await _draftPhotoFile();
    final bool hasPhoto = await photo.exists();
    final Response response = await petServiceInterface.addPet(
      draft,
      photo: hasPhoto ? XFile(photo.path) : null,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      await petServiceInterface.clearDraft();
      await _deleteDraftPhoto();
      _draft = null;
    }
  }

  /// Where a guest's pet photo waits for sign-in.
  Future<File> _draftPhotoFile() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/pet_draft_photo.jpg');
  }

  Future<void> _deleteDraftPhoto() async {
    final File file = await _draftPhotoFile();
    if (await file.exists()) await file.delete();
  }

  Future<void> getUsual() async {
    if (!AuthHelper.isLoggedIn()) return;
    final PetUsualModel? fetched = await petServiceInterface.getUsual();
    _usual = fetched;
    update([idUsual]);
  }

  /// Sets (or changes) "remind me every N days" for the usual item; null
  /// [intervalDays] turns it off.
  Future<bool> setUsualReminder(int? intervalDays) async {
    final PetUsualModel? usual = _usual;
    if (usual == null || usual.item.id == null || _reminderSaving) return false;
    _reminderSaving = true;
    update([idUsual]);
    try {
      if (intervalDays == null) {
        final PetReminderModel? current = usual.reminder;
        if (current == null) return true;
        final bool ok = await petServiceInterface.deleteReminder(current.id);
        if (ok) _usual = usual.withReminder(null);
        return ok;
      }
      final PetReminderModel? saved = await petServiceInterface.setReminder(
        itemId: usual.item.id!,
        storeId: usual.storeId,
        intervalDays: intervalDays,
        petId: primaryPet?.id,
      );
      if (saved != null) _usual = usual.withReminder(saved);
      return saved != null;
    } finally {
      _reminderSaving = false;
      update([idUsual]);
    }
  }

  /// On logout: forget the account's pets; a guest starts from their draft.
  void clearOnLogout() {
    _usual = null;
    _pets = null;
    _draft = petServiceInterface.getDraft();
    update([idPets]);
  }

  Future<void> getCategories({bool reload = false}) async {
    if (_categoriesLoading || (_categories != null && !reload)) return;
    _categoriesLoading = true;
    try {
      final List<PetCategoryModel>? fetched =
          await petServiceInterface.getCategories();
      if (fetched != null) _categories = fetched;
    } finally {
      _categoriesLoading = false;
      update([idCategories]);
    }
  }

  Future<void> getClinics(double lat, double lng, {bool reload = false}) async {
    if (_clinicsLoading || (_clinics != null && !reload)) return;
    _clinicsLoading = true;
    _clinicsFailed = false;
    update([idClinics]);
    try {
      final List<VetClinicModel>? fetched = await petServiceInterface
          .getClinics(lat, lng);
      if (fetched != null) {
        _clinics = fetched;
      } else {
        _clinicsFailed = true;
      }
    } finally {
      _clinicsLoading = false;
      update([idClinics]);
    }
  }

  Future<void> _refetch() async {
    _pets = null;
    await getPets(reload: true);
  }
}
