import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/item/domain/produce_preference.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// The produce question on an item: "Ripeness" (ready to eat / ripe in 2–3
/// days) or "Use it for" (salad / cooking), as two answer cards side by side.
///
/// Required: nothing is preselected, and the add button refuses until one
/// is picked. Used by the item page and the item sheet.
class ProducePreferencePicker extends StatelessWidget {
  /// `ripeness` or `use` — `Item.prepOption`.
  final String option;

  /// The picked answer code, or null.
  final String? selected;
  final ValueChanged<String> onSelect;
  final EdgeInsetsGeometry margin;

  const ProducePreferencePicker({
    super.key,
    required this.option,
    required this.selected,
    required this.onSelect,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> answers = ProducePreference.answersFor(option);
    if (answers.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(
          // Amber until answered, so a refused add points at what's missing.
          color: selected == null ? WaddyColors.amber : WaddyColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ProducePreference.title(option),
                  style: waddyBold.copyWith(
                    fontSize: 14,
                    color: WaddyColors.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeSmall,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color:
                      selected == null
                          ? WaddyColors.amberSurface
                          : WaddyColors.primarySurface,
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                ),
                child: Text(
                  selected == null ? 'required'.tr : 'selected'.tr,
                  style: waddyMedium.copyWith(
                    fontSize: 10,
                    color:
                        selected == null
                            ? WaddyColors.amberInk
                            : WaddyColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeMedium),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < answers.length; i++) ...[
                  if (i > 0) const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(
                    child: _AnswerCard(
                      code: answers[i],
                      selected: selected == answers[i],
                      onTap: () => onSelect(answers[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final String code;
  final bool selected;
  final VoidCallback onTap;

  const _AnswerCard({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String label = ProducePreference.label(code) ?? code;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      child: AnimatedContainer(
        duration: WaddyMotion.fast,
        curve: WaddyMotion.easeOut,
        padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
        decoration: BoxDecoration(
          color: selected ? WaddyColors.primarySurface : WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            color: selected ? WaddyColors.primary : WaddyColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: waddyBold.copyWith(
                      fontSize: 13,
                      color: WaddyColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: WaddyMotion.fast,
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? WaddyColors.primary : Colors.transparent,
                    border: Border.all(
                      color:
                          selected ? WaddyColors.primary : WaddyColors.inkMuted,
                      width: 1.5,
                    ),
                  ),
                  child:
                      selected
                          ? const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: WaddyColors.mint,
                          )
                          : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              ProducePreference.hint(code),
              style: waddyRegular.copyWith(
                fontSize: 11,
                height: 1.35,
                color: WaddyColors.inkLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
