import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/util/app_design_tokens.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Section title with the marker-highlight underline and an optional
/// "view all" pill.
class ModuleSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const ModuleSectionHeader({super.key, required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IntrinsicWidth(
            child: Stack(
              children: [
                Positioned(
                  bottom: 2,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusExtraSmall,
                      ),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: waddyBold.copyWith(
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (onViewAll != null)
            PressableScale(
              // The arrow is glyph-only; the section title is the only thing
              // that says what it opens.
              semanticLabel: '${'view_all'.tr} $title',
              onTap: onViewAll!,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeMedium,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppDesignTokens.secondaryNeon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    Dimensions.radiusExtraLarge,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'view_all'.tr,
                      style: waddyMedium.copyWith(
                        fontSize: 12,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
