import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/spots/spots_marks.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// One vote per week — confirm moving it to a new spot.
/// Returns true when the user chooses to switch.
///
/// Was drawn in pure black borders and black offset shadows with an emoji
/// ballot-box glyph and hardcoded English labels: harsher than anything else
/// on screen, off-palette, and untranslated. Now in the Spots system.
Future<bool?> showVoteSwitchDialog(String currentPlaceTitle) {
  return Get.dialog<bool>(
    Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: Spots.s32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Spots.s20,
          Spots.s20,
          Spots.s20,
          Spots.s16,
        ),
        decoration: Spots.card(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SpotsGlyph(SpotsMark.flame, size: 26, color: Spots.teal),
            const SizedBox(height: Spots.s12),
            Text(
              displayCaps('move_your_weekly_vote'.tr),
              style: Spots.display(17, color: Spots.ink),
            ),
            const SizedBox(height: Spots.s8),
            Text(
              currentPlaceTitle.trim().isNotEmpty
                  ? 'move_vote_body'.trParams({
                    'place': currentPlaceTitle.toUpperCase(),
                  })
                  : 'move_vote_body_generic'.tr,
              style: waddyRegular.copyWith(
                fontSize: 12,
                color: Spots.ink2,
                height: 1.45,
              ),
            ),
            const SizedBox(height: Spots.s20),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'keep_it'.tr,
                    onTap: () => Get.back(result: false),
                  ),
                ),
                const SizedBox(width: Spots.s12),
                Expanded(
                  child: _DialogButton(
                    label: 'move_my_vote'.tr,
                    primary: true,
                    onTap: () => Get.back(result: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: true,
  );
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? Spots.mint : Spots.paper,
          border: Border.all(color: Spots.border, width: Spots.borderThin),
          borderRadius: BorderRadius.circular(Spots.radiusMd),
          boxShadow: primary ? Spots.shadow(dx: 2, dy: 2) : null,
        ),
        child: Text(
          displayCaps(label),
          textAlign: TextAlign.center,
          style: Spots.kicker(
            11,
            color: primary ? Spots.teal : Spots.ink3,
            tracking: 0.06,
          ),
        ),
      ),
    );
  }
}
