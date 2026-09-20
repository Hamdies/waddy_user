import 'package:flutter/material.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// The repeated section header — an uppercase kicker, a loud title, and either
/// a right-aligned text link (`actionLabel` + `onAction`) or a non-interactive
/// stat (`stat`). Mirrors `.headrow` / `.k` / `.h1` / `.link` from
/// templates/home/Home.dc.html.
class SpotsSectionHeader extends StatelessWidget {
  final String kicker;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Kicker-styled, non-tappable trailing stat (e.g. "12 spots"). Ignored when
  /// [actionLabel] is set.
  final String? stat;

  const SpotsSectionHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.stat,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayCaps(kicker),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Spots.kicker(10),
              ),
              const SizedBox(height: Spots.s4),
              Text(
                title,
                style: waddyBlack.copyWith(
                  fontSize: 23,
                  color: Spots.ink,
                  height: 0.95,
                  letterSpacing: displayTracking(-0.005 * 23),
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            // Fixed 44px hit box, label bottom-aligned so it keeps sitting on
            // the title baseline while the touch target grows upward.
            child: Container(
              height: 44,
              alignment: AlignmentDirectional.bottomEnd,
              padding: const EdgeInsetsDirectional.only(
                start: Spots.s8,
                bottom: 2,
              ),
              child: Text(
                '${displayCaps(actionLabel!)} ${isLtr ? '→' : '←'}',
                style: waddyBlack.copyWith(fontSize: 12, color: Spots.ink),
              ),
            ),
          )
        else if (stat != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Spots.s8,
              bottom: 2,
            ),
            child: Text(displayCaps(stat!), style: Spots.kicker(10)),
          ),
      ],
    );
  }
}
