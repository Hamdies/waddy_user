import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/pets/widgets/pet_visuals.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// "−  About 3 years old  +": a rough age when the birthday isn't known.
///
/// [years] null means nothing picked yet: the counter shows its starting
/// value muted, and the first tap on either side picks it. 0 is "under a
/// year"; the top is [max].
class PetAgeCounter extends StatelessWidget {
  final int? years;
  final ValueChanged<int> onChanged;
  final int max;

  const PetAgeCounter({
    super.key,
    required this.years,
    required this.onChanged,
    this.max = 25,
  });

  static const int _start = 1;

  @override
  Widget build(BuildContext context) {
    final bool active = years != null;
    final int value = years ?? _start;
    return AnimatedContainer(
      duration: WaddyMotion.fast,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? WaddyColors.primarySurface : WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(
          color: active ? WaddyColors.primary : WaddyColors.divider,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            semanticLabel: 'decrease'.tr,
            enabled: !active || value > 0,
            onTap: () => onChanged(active ? value - 1 : value),
          ),
          Expanded(
            child: Text(
              active ? PetCopy.aboutYears(value) : 'pet_age_counter_hint'.tr,
              textAlign: TextAlign.center,
              style: waddyBold.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: active ? WaddyColors.primary : WaddyColors.inkLight,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            semanticLabel: 'increase'.tr,
            enabled: !active || value < max,
            onTap: () => onChanged(active ? value + 1 : value),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? onTap : null,
      semanticLabel: semanticLabel,
      scale: WaddyMotion.pressControl,
      minSize: Dimensions.minTapTarget,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? WaddyColors.primary : WaddyColors.divider,
        ),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? WaddyColors.mint : WaddyColors.inkMuted,
        ),
      ),
    );
  }
}
