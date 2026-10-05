import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/motion.dart';

/// How each species shows up before there is art for it (PET-15): its
/// HugeIcons glyph on the mint wash. The design's image slots are empty;
/// when real illustrations land they replace [icon] here and nowhere else.
extension PetSpeciesView on PetSpecies {
  /// HugeIcons (1.2.0+) has Cat, Bird, Fish and Rabbit but no dog in any
  /// version, so a dog is its paw print.
  List<List<dynamic>> get icon => switch (this) {
    PetSpecies.cat => HugeIcons.strokeRoundedCat,
    PetSpecies.dog => HugeIcons.strokeRoundedPawPrint,
    PetSpecies.bird => HugeIcons.strokeRoundedBird,
    PetSpecies.fish => HugeIcons.strokeRoundedFish,
    PetSpecies.small => HugeIcons.strokeRoundedRabbit,
  };

  /// "Cat", "Dog"… singular, for onboarding and copy.
  String get label => 'pet_species_$wire'.tr;

  /// The onboarding tile's one-liner ("Judges you, lovingly").
  String get joke => 'pet_joke_$wire'.tr;

  /// What bursts off the onboarding tile when it is picked. Celebration
  /// only: the species is still drawn with [icon] everywhere it is shown.
  List<String> get emojis => switch (this) {
    PetSpecies.cat => const ['🐱', '😻', '🐾', '🐈'],
    PetSpecies.dog => const ['🐶', '🦴', '🐾', '🐕'],
    PetSpecies.bird => const ['🐦', '🦜', '🐤', '🐥'],
    PetSpecies.fish => const ['🐠', '🐟', '🐡', '💧'],
    PetSpecies.small => const ['🐹', '🐰', '🥕', '🐾'],
  };
}

/// Personalised copy that has to agree with the pet's sex.
///
/// Arabic is gendered: "كل اللي لونا محتاجاه" / "كل اللي ركس محتاجه"
/// (PET-07). Every such key exists twice in en.json and ar.json, `_m` and
/// `_f`. An unknown sex reads as `_m`, Arabic's generic form.
class PetCopy {
  PetCopy._();

  static String tr(
    String key,
    UserPetModel pet, {
    Map<String, String>? params,
  }) {
    final String suffix = pet.sex == PetSex.female ? '_f' : '_m';
    return '$key$suffix'.trParams({'name': pet.name, ...?params});
  }

  /// "About 3 years old". Arabic counts 1, 2, 3–10 and 11+ differently
  /// ("سنة", "سنتين", "٣ سنين", "١١ سنة"); English rides the same keys.
  static String aboutYears(int n) => switch (n) {
    <= 0 => 'pet_about_baby'.tr,
    1 => 'pet_about_1_year'.tr,
    2 => 'pet_about_2_years'.tr,
    <= 10 => 'pet_about_years'.trParams({'n': '$n'}),
    _ => 'pet_about_years_many'.trParams({'n': '$n'}),
  };

  /// "Every 4 weeks"; two weeks is "كل أسبوعين", not "كل 2 أسابيع".
  static String everyWeeks(int weeks) =>
      weeks == 2
          ? 'pet_reminder_every_2'.tr
          : 'pet_reminder_every'.trParams({'n': '$weeks'});
}

/// A pet as a round avatar: its photo when there is one, else its species'
/// icon on the mint wash. [ringed] draws the selection ring.
class PetAvatar extends StatelessWidget {
  final PetSpecies species;
  final String? photoUrl;
  final double size;
  final bool ringed;

  const PetAvatar({
    super.key,
    required this.species,
    this.photoUrl,
    this.size = 64,
    this.ringed = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return AnimatedContainer(
      duration: WaddyMotion.fast,
      curve: WaddyMotion.easeOut,
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringed ? WaddyColors.primary : Colors.transparent,
          width: 2.5,
        ),
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: petWash),
          child:
              hasPhoto
                  ? CustomImage(
                    image: photoUrl!,
                    fit: BoxFit.cover,
                    decodeWidth: size * 3,
                    fallback: _glyph(size),
                  )
                  : _glyph(size),
        ),
      ),
    );
  }

  Widget _glyph(double size) => Center(
    child: HugeIcon(
      icon: species.icon,
      size: size * 0.42,
      color: WaddyColors.primary,
    ),
  );
}

/// The pets module's tile wash: mint 100 easing to near-white, the design's
/// `#D6F7EA → #F2FBF8`, built from the theme's mint tints.
const LinearGradient petWash = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [WaddyColors.mintSurfaceDeep, WaddyColors.mintSurface],
);
