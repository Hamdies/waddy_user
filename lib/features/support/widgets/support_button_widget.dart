import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:flutter/material.dart';

/// A tappable support-channel row (address / call / email).
///
/// Styled on Waddy's surface-tint + ink-glyph pattern (see [WaddyColors]):
/// the badge wears a tinted surface, never a full-saturation fill, and the
/// icon/title read in that colour's ink step so contrast holds.
class SupportButtonWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? info;
  final Color surfaceColor;
  final Color inkColor;
  final VoidCallback onTap;

  const SupportButtonWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.info,
    required this.surfaceColor,
    required this.inkColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WaddyColors.surface,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: Container(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: WaddyColors.divider),
            boxShadow: const [
              BoxShadow(
                color: WaddyColors.shadowTeal,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: surfaceColor,
                ),
                child: Icon(icon, color: inkColor, size: 22),
              ),
              const SizedBox(width: Dimensions.paddingSizeDefault),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: waddyMedium.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: WaddyColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info ?? '',
                      style: waddyRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: WaddyColors.inkLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: WaddyColors.inkMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
