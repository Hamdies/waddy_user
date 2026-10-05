import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/pets/controllers/pet_controller.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/screens/pet_details_screen.dart';
import 'package:waddy_app/features/pets/screens/pet_onboarding_screen.dart';
import 'package:waddy_app/features/pets/widgets/pet_visuals.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// "My pets": the household, from the menu and the hub's avatars.
class PetProfileScreen extends StatefulWidget {
  const PetProfileScreen({super.key});

  static Future<void> open() async {
    await Get.to(() => const PetProfileScreen());
  }

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  @override
  void initState() {
    super.initState();
    Get.find<PetController>().getPets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaddyColors.canvas,
      appBar: AppBar(
        backgroundColor: WaddyColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'my_pets'.tr,
          style: waddyBold.copyWith(fontSize: 17, color: WaddyColors.ink),
        ),
      ),
      body: GetBuilder<PetController>(
        id: PetController.idPets,
        builder: (pets) {
          final List<UserPetModel>? list = pets.pets;
          if (list == null) {
            return const Center(
              child: CircularProgressIndicator(color: WaddyColors.primary),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final UserPetModel pet in list) ...[
                _PetRow(pet: pet),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              Pressable(
                onTap: () => PetOnboardingScreen.open(),
                semanticLabel: 'add_another_pet'.tr,
                scale: WaddyMotion.pressCard,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                    border: Border.all(color: WaddyColors.primary, width: 1.5),
                  ),
                  child: Text(
                    list.isEmpty
                        ? 'meet_your_pet_cta'.tr
                        : 'add_another_pet'.tr,
                    style: waddyBold.copyWith(
                      fontSize: 14,
                      color: WaddyColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PetRow extends StatelessWidget {
  final UserPetModel pet;

  const _PetRow({required this.pet});

  @override
  Widget build(BuildContext context) {
    // A guest's draft has no server row yet: its details wait for sign-in.
    final bool editable = pet.id != null;
    return Pressable(
      onTap:
          editable
              ? () => PetDetailsScreen.open(pet)
              : () => PetOnboardingScreen.open(editing: pet),
      semanticLabel: pet.name,
      scale: WaddyMotion.pressCard,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(color: WaddyColors.divider),
        ),
        child: Row(
          children: [
            PetAvatar(species: pet.species, photoUrl: pet.photoUrl, size: 56),
            const SizedBox(width: Dimensions.paddingSizeMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          pet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: waddyBold.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: WaddyColors.ink,
                          ),
                        ),
                      ),
                      if (pet.isPrimary) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: WaddyColors.primarySurface,
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                          ),
                          child: Text(
                            'pet_main'.tr,
                            style: waddyBold.copyWith(
                              fontSize: 11,
                              color: WaddyColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      pet.species.label,
                      if (pet.sex != PetSex.unknown)
                        'pet_sex_${pet.sex.wire}'.tr,
                      if (pet.breed != null && pet.breed!.isNotEmpty)
                        pet.breed!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyRegular.copyWith(
                      fontSize: 12,
                      color: WaddyColors.inkLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: WaddyColors.inkLight,
            ),
          ],
        ),
      ),
    );
  }
}
