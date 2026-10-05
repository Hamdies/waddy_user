import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/widgets/pet_visuals.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// Icon and label for each clinic service key the admin can tick
/// (`Place::CLINIC_SERVICES`). An unknown key is skipped, never shown raw.
class ClinicServiceView {
  ClinicServiceView._();

  static const Map<String, List<List<dynamic>>> _icons = {
    'emergency_24h': HugeIcons.strokeRoundedAlarmClock,
    'home_visit': HugeIcons.strokeRoundedHome01,
    'vaccination': HugeIcons.strokeRoundedInjection,
    'surgery': HugeIcons.strokeRoundedScissor,
    'dental': HugeIcons.strokeRoundedDentalTooth,
    'xray': HugeIcons.strokeRoundedRadiation,
    'lab': HugeIcons.strokeRoundedTestTube,
    'grooming': HugeIcons.strokeRoundedShampoo,
    'boarding': HugeIcons.strokeRoundedBed,
    'pharmacy': HugeIcons.strokeRoundedMedicine02,
  };

  static bool known(String key) => _icons.containsKey(key);
  static List<List<dynamic>> icon(String key) => _icons[key]!;
  static String label(String key) => 'clinic_service_$key'.tr;
}

/// A small tag: icon + label on a tint, sized to its text.
class ClinicTag extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final bool strong;

  const ClinicTag({
    super.key,
    required this.icon,
    required this.label,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = strong ? WaddyColors.mint : WaddyColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? WaddyColors.primary : WaddyColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: waddyBold.copyWith(
              fontSize: 11,
              color: strong ? Colors.white : WaddyColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The species a clinic treats, as a row of small icons.
class ClinicSpeciesIcons extends StatelessWidget {
  final List<PetSpecies> species;
  final double size;

  const ClinicSpeciesIcons({super.key, required this.species, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final PetSpecies s in species)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Semantics(
              label: s.label,
              child: HugeIcon(
                icon: s.icon,
                size: size,
                color: WaddyColors.primaryLight,
              ),
            ),
          ),
      ],
    );
  }
}
