import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// One failed rail, in the slot that rail would have occupied.
///
/// The home feed used to have two ways of saying nothing: a section whose data
/// came back empty returned `SizedBox.shrink()`, and a section whose fetch
/// *failed* left its list null and shimmered forever. Neither told the user
/// anything, and the second is worse than blank — a permanent loading state
/// reads as an app that is still trying.
///
/// This is deliberately a row, not a card. It replaces a rail's content in
/// place, so it inherits the feed's own spacing and cannot introduce a seam:
/// it carries NO outer vertical margin. (The feed owns every gap — see `_Gap`
/// in module_view.dart, and the comment there about a section that added its
/// own 32 on top of the parent's and produced a 40pt hole where a 12 was
/// intended.)
///
/// Theme-neutral by design. The two existing error states in the app are both
/// bound to their feature's palette — `SpotsErrorCard` to the Places `Spots.*`
/// tokens, and `_ErrorState` in xp_levels_screen.dart to the XP darks, where
/// it is also private. Neither can be reused on the feed.
class SectionErrorView extends StatelessWidget {
  /// What failed, in the user's terms. Defaults to a generic "Failed to load";
  /// pass a section-specific line where the feed can be more concrete.
  final String? headline;

  final VoidCallback onRetry;

  const SectionErrorView({super.key, required this.onRetry, this.headline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Horizontal only. The vertical rhythm belongs to the feed.
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
          vertical: Dimensions.paddingSizeMedium,
        ),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(color: WaddyColors.divider),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 20,
              color: WaddyColors.inkLight,
            ),
            const SizedBox(width: Dimensions.paddingSizeMedium),
            Expanded(
              child: Text(
                headline ?? 'failed_to_load'.tr,
                style: waddyMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: WaddyColors.inkMid,
                ),
                // Two lines: Arabic runs longer than English here, and at a
                // large text scale a single line would ellipsize the only
                // explanation on offer.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Pressable(
              onTap: onRetry,
              semanticLabel: 'retry'.tr,
              // The row is short, so the label is the only thing to press.
              // minSize keeps the target at the platform floor even though the
              // text itself is smaller than that.
              minSize: Dimensions.minTapTarget,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeSmall,
                  vertical: Dimensions.paddingSizeExtraSmall,
                ),
                child: Text(
                  'retry'.tr,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: WaddyColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
