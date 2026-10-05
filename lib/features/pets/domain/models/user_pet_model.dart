/// The kinds of pet the Pets module knows. [wire] is the backend's
/// `user_pets.species` value, and also the `code` of that species' main
/// category in the pets category tree (PET-02), which is how the store
/// switcher maps a pet to its aisle.
enum PetSpecies {
  cat('cat'),
  dog('dog'),
  bird('bird'),
  fish('fish'),
  small('small');

  const PetSpecies(this.wire);

  final String wire;

  static PetSpecies? of(String? value) {
    for (final PetSpecies species in PetSpecies.values) {
      if (species.wire == value) return species;
    }
    return null;
  }
}

/// Needed for every personalised string: Arabic is gendered
/// ("لونا محتاجة" / "ركس محتاج"), and English pushes say "her" or "his"
/// (PET-07).
enum PetSex {
  male('male'),
  female('female'),
  unknown('unknown');

  const PetSex(this.wire);

  final String wire;

  static PetSex of(String? value) {
    for (final PetSex sex in PetSex.values) {
      if (sex.wire == value) return sex;
    }
    return PetSex.unknown;
  }
}

enum PetAgeBand {
  baby('baby'),
  adult('adult'),
  senior('senior');

  const PetAgeBand(this.wire);

  final String wire;

  static PetAgeBand? of(String? value) {
    for (final PetAgeBand band in PetAgeBand.values) {
      if (band.wire == value) return band;
    }
    return null;
  }
}

enum PetDiet {
  dry('dry'),
  wet('wet'),
  both('both'),
  picky('picky');

  const PetDiet(this.wire);

  final String wire;

  static PetDiet? of(String? value) {
    for (final PetDiet diet in PetDiet.values) {
      if (diet.wire == value) return diet;
    }
    return null;
  }
}

/// One of the customer's pets (`/api/v1/customer/pets`).
///
/// [id] is null for a guest's draft: the pet entered during onboarding
/// before sign-in, kept on the device and sent once they log in.
class UserPetModel {
  final int? id;
  final String name;
  final PetSpecies species;
  final PetSex sex;
  final PetAgeBand? ageBand;

  /// Where the pet is today. The server derives it from [birthDate] when
  /// there is one, so it moves on its own; otherwise it is [ageBand].
  final PetAgeBand? lifeStage;
  final DateTime? birthDate;
  final bool birthDateIsEstimate;
  final PetDiet? diet;
  final String? breed;
  final double? weightKg;
  final bool isPrimary;

  /// The pet's own off switch for lifecycle pushes (food running low,
  /// birthday, life stage).
  final bool notify;
  final String? photoUrl;

  const UserPetModel({
    this.id,
    required this.name,
    required this.species,
    this.sex = PetSex.unknown,
    this.ageBand,
    this.lifeStage,
    this.birthDate,
    this.birthDateIsEstimate = false,
    this.diet,
    this.breed,
    this.weightKg,
    this.isPrimary = false,
    this.notify = true,
    this.photoUrl,
  });

  /// Null when the row has no species this build knows; the caller drops it
  /// rather than guessing a cat.
  static UserPetModel? fromJson(Map<String, dynamic> json) {
    final PetSpecies? species = PetSpecies.of(json['species']?.toString());
    if (species == null) return null;
    return UserPetModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}'),
      name: '${json['name'] ?? ''}',
      species: species,
      sex: PetSex.of(json['sex']?.toString()),
      ageBand: PetAgeBand.of(json['age_band']?.toString()),
      lifeStage: PetAgeBand.of(json['life_stage']?.toString()),
      birthDate:
          json['birth_date'] == null
              ? null
              : DateTime.tryParse('${json['birth_date']}'),
      birthDateIsEstimate:
          json['birth_date_is_estimate'] == true ||
          json['birth_date_is_estimate'] == 1,
      diet: PetDiet.of(json['diet']?.toString()),
      breed: json['breed']?.toString(),
      weightKg:
          json['weight_kg'] == null
              ? null
              : double.tryParse('${json['weight_kg']}'),
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
      // Absent on a guest draft and on older rows: on.
      notify:
          json['notify'] == null ||
          json['notify'] == true ||
          json['notify'] == 1,
      photoUrl: json['photo_full_url']?.toString(),
    );
  }

  /// The fields the API accepts, as multipart-safe strings. Null fields are
  /// left out so an update only changes what was set.
  Map<String, String> toRequest() {
    final String? date =
        birthDate == null
            ? null
            : '${birthDate!.year.toString().padLeft(4, '0')}-'
                '${birthDate!.month.toString().padLeft(2, '0')}-'
                '${birthDate!.day.toString().padLeft(2, '0')}';
    return <String, String>{
      'name': name,
      'species': species.wire,
      'sex': sex.wire,
      if (ageBand != null) 'age_band': ageBand!.wire,
      if (date != null) 'birth_date': date,
      if (date != null)
        'birth_date_is_estimate': birthDateIsEstimate ? '1' : '0',
      if (diet != null) 'diet': diet!.wire,
      if (breed != null) 'breed': breed!,
      if (weightKg != null) 'weight_kg': '$weightKg',
      if (isPrimary) 'is_primary': '1',
      'notify': notify ? '1' : '0',
    };
  }

  /// For the guest draft kept in prefs: [toRequest] plus nothing else, so a
  /// draft can never carry a stale id or photo URL.
  Map<String, dynamic> toDraftJson() => toRequest();

  static UserPetModel? fromDraftJson(Map<String, dynamic> json) =>
      fromJson(json);

  /// [birthDate] can't be cleared through here; nothing needs to yet.
  UserPetModel copyWith({
    String? name,
    PetSpecies? species,
    PetSex? sex,
    PetAgeBand? ageBand,
    DateTime? birthDate,
    bool? birthDateIsEstimate,
    PetDiet? diet,
    String? breed,
    double? weightKg,
    bool? isPrimary,
    bool? notify,
  }) {
    return UserPetModel(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      sex: sex ?? this.sex,
      ageBand: ageBand ?? this.ageBand,
      lifeStage: lifeStage,
      birthDate: birthDate ?? this.birthDate,
      birthDateIsEstimate: birthDateIsEstimate ?? this.birthDateIsEstimate,
      diet: diet ?? this.diet,
      breed: breed ?? this.breed,
      weightKg: weightKg ?? this.weightKg,
      isPrimary: isPrimary ?? this.isPrimary,
      notify: notify ?? this.notify,
      photoUrl: photoUrl,
    );
  }
}
