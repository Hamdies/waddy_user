import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/pets/controllers/pet_controller.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/domain/models/vet_clinic_model.dart';
import 'package:waddy_app/features/pets/widgets/clinic_tags.dart';
import 'package:waddy_app/features/pets/widgets/pet_visuals.dart';
import 'package:waddy_app/features/pets/screens/vet_clinic_screen.dart';
import 'package:waddy_app/features/pets/widgets/clinic_status.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// "Vet clinics nearby": a header, filter toggles, and a row of clinic
/// cards, each opening the clinic's page ([VetClinicScreen]).
///
/// The toggles filter on the device: a hub holds at most 30 clinics, all
/// already loaded. "Treats Luna" only appears with a pet, and a clinic that
/// hasn't said which animals it treats is never filtered out by it.
///
/// Collapses to nothing when there are no clinics near the address, or the
/// fetch failed: an empty "Vet clinics" header promises something the hub
/// can't deliver.
class VetClinicRail extends StatefulWidget {
  const VetClinicRail({super.key});

  @override
  State<VetClinicRail> createState() => _VetClinicRailState();
}

class _VetClinicRailState extends State<VetClinicRail> {
  bool _openNow = false;
  bool _allDay = false;
  bool _homeVisits = false;
  bool _forMyPet = false;

  List<VetClinicModel> _filter(List<VetClinicModel> all, UserPetModel? pet) {
    return all.where((c) {
      if (_openNow && c.isOpenNow != true) return false;
      if (_allDay && !c.is24h) return false;
      if (_homeVisits && !c.homeVisits) return false;
      if (_forMyPet && pet != null && !c.treats(pet.species)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PetController>(
      id: PetController.idClinics,
      builder: (pets) {
        final List<VetClinicModel>? clinics = pets.clinics;
        if (clinics == null && pets.clinicsLoading) return const _RailShimmer();
        if (clinics == null || clinics.isEmpty) return const SizedBox.shrink();
        final UserPetModel? pet = pets.primaryPet;
        final List<VetClinicModel> shown = _filter(clinics, pet);
        // Only offer a toggle some clinic would pass: a "24/7" chip that
        // empties the rail every time is a broken control, not a filter.
        final bool any24h = clinics.any((c) => c.is24h);
        final bool anyHome = clinics.any((c) => c.homeVisits);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'vet_clinics_nearby'.tr,
                style: waddyBold.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: WaddyColors.ink,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  _Toggle(
                    label: 'pet_filter_open_now'.tr,
                    active: _openNow,
                    onTap: () => setState(() => _openNow = !_openNow),
                  ),
                  if (any24h)
                    _Toggle(
                      label: 'clinic_filter_24h'.tr,
                      icon: HugeIcons.strokeRoundedAlarmClock,
                      active: _allDay,
                      onTap: () => setState(() => _allDay = !_allDay),
                    ),
                  if (anyHome)
                    _Toggle(
                      label: 'clinic_service_home_visit'.tr,
                      icon: HugeIcons.strokeRoundedHome01,
                      active: _homeVisits,
                      onTap: () => setState(() => _homeVisits = !_homeVisits),
                    ),
                  if (pet != null)
                    _Toggle(
                      label: 'clinic_filter_treats'.trParams({
                        'name': pet.name,
                      }),
                      icon: pet.species.icon,
                      active: _forMyPet,
                      onTap: () => setState(() => _forMyPet = !_forMyPet),
                    ),
                ],
              ),
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(
                  'clinic_filter_none'.tr,
                  style: waddyRegular.copyWith(
                    fontSize: 13,
                    color: WaddyColors.inkLight,
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < shown.length; i++) ...[
                      if (i > 0)
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                      _ClinicChip(clinic: shown[i]),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final List<List<dynamic>>? icon;
  final bool active;
  final VoidCallback onTap;

  const _Toggle({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = active ? Colors.white : WaddyColors.primary;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        end: Dimensions.paddingSizeSmall,
      ),
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        scale: WaddyMotion.pressControl,
        child: AnimatedContainer(
          duration: WaddyMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? WaddyColors.primary : WaddyColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? WaddyColors.primary : WaddyColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                HugeIcon(icon: icon!, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(label, style: waddyBold.copyWith(fontSize: 12, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One clinic as a photo card (design screen 01, revised): cover on top,
/// then name, "600 m · ★ 4.9", and the open/closed line.
class _ClinicChip extends StatelessWidget {
  static const double _width = 220;

  final VetClinicModel clinic;

  const _ClinicChip({required this.clinic});

  @override
  Widget build(BuildContext context) {
    final ClinicStatus? status = ClinicStatus.of(clinic);
    // Cover on top, logo on its edge. With only one of the two, it's the cover.
    final String? photo = clinic.coverUrl ?? clinic.imageUrl;
    final String? logo = clinic.coverUrl != null ? clinic.imageUrl : null;
    final List<String> meta = [
      if (clinic.distanceKm != null) clinicDistanceLabel(clinic.distanceKm!),
      // Only once enough reviews stand behind it (PET-11).
      if (clinic.rating != null) '★ ${clinic.rating!.toStringAsFixed(1)}',
    ];

    return Pressable(
      onTap: () => VetClinicScreen.open(clinic),
      semanticLabel: clinic.name,
      scale: WaddyMotion.pressTile,
      child: Container(
        width: _width,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge + 2),
          border: Border.all(color: WaddyColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 112,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault + 2,
                      ),
                      child:
                          photo == null
                              ? const DecoratedBox(
                                decoration: BoxDecoration(gradient: petWash),
                                child: Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedStethoscope,
                                    size: 32,
                                    color: WaddyColors.primary,
                                  ),
                                ),
                              )
                              : CustomImage(image: photo, fit: BoxFit.cover),
                    ),
                  ),
                  // The clinic's logo on the cover's edge, like a shop card's.
                  if (clinic.is24h)
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: ClinicTag(
                        icon: ClinicServiceView.icon('emergency_24h'),
                        label: 'clinic_filter_24h'.tr,
                        strong: true,
                      ),
                    ),
                  if (logo != null)
                    PositionedDirectional(
                      start: 10,
                      bottom: -16,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: WaddyColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: WaddyColors.surface,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: WaddyColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: CustomImage(image: logo, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: logo != null ? 22 : 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clinic.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyBold.copyWith(
                      fontSize: 14,
                      color: WaddyColors.ink,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta.join(' · '),
                      maxLines: 1,
                      style: waddyRegular.copyWith(
                        fontSize: 11,
                        color: WaddyColors.inkLight,
                      ),
                    ),
                  ],
                  if (status != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: status.dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            status.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: waddyMedium.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: status.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // What it treats, and home visits when it does them. The
                  // rest of the services live in the sheet.
                  if (clinic.species.isNotEmpty || clinic.homeVisits) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (clinic.species.isNotEmpty)
                          ClinicSpeciesIcons(species: clinic.species),
                        if (clinic.homeVisits)
                          ClinicTag(
                            icon: ClinicServiceView.icon('home_visit'),
                            label: ClinicServiceView.label('home_visit'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailShimmer extends StatelessWidget {
  const _RailShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 54, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: Dimensions.paddingSizeSmall),
              Container(
                width: _ClinicChip._width,
                height: 190,
                decoration: BoxDecoration(
                  color: WaddyColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
