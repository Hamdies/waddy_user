import 'package:flutter/material.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// A store page's section header (Mart Store Page v4): 20/800 title, an
/// optional subtitle, and an optional "See all >" at the end.
class StoreSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  /// White type and a mint action, for the dark aisle panel.
  final bool onDark;

  /// Teal title, for the mint aisle panel.
  final bool onMint;
  final EdgeInsetsGeometry padding;

  const StoreSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
    this.onDark = false,
    this.onMint = false,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 32, 20, 12),
  });

  @override
  Widget build(BuildContext context) {
    final Color titleColor =
        onDark
            ? Colors.white
            : onMint
            ? WaddyColors.primary
            : WaddyColors.ink;
    final Color subtitleColor =
        onDark
            ? Colors.white.withValues(alpha: 0.78)
            : onMint
            ? WaddyColors.inkMid
            : WaddyColors.inkLight;
    final Color actionColor = onDark ? WaddyColors.mint : WaddyColors.primary;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBold.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: displayTracking(-0.4),
                    color: titleColor,
                  ),
                ),
                
              ],
            ),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(width: Dimensions.paddingSizeMedium),
            Pressable(
              onTap: onAction,
              semanticLabel: action,
              scale: WaddyMotion.pressControl,
              minSize: Dimensions.minTapTarget,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action!,
                    maxLines: 1,
                    style: waddyBold.copyWith(fontSize: 13, color: actionColor),
                  ),
                  Icon(
                    rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                    color: actionColor,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
