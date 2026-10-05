import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:waddy_app/theme/light_theme.dart';

/// The 56px circle that overhangs the top edge of a bottom bar — shared by
/// `PillCartBar` and `OrderTrackingBar` so the two read as one family.
///
/// `margin-top: -32px` in the design's terms, which is a NEGATIVE top margin:
/// the circle's upper 32px sit outside the bar. Flutter has no negative
/// margin, so the equivalent here is a [Transform.translate] on a box that
/// reserves only the visible remainder — that way the row's height is the 24px
/// of in-bar circle, and the rest paints over whatever is above.
///
/// The design's `box-shadow: 0 0 0 5px #fff` is a hard 5px spread with no blur:
/// a solid ring, not a shadow. That is a [Border], not a [BoxShadow] — using a
/// blurred shadow here would smear the punch-through effect the ring creates.
class OverhangBadge extends StatelessWidget {
  final String asset;
  final Color fill;

  static const double _diameter = 56;

  /// How far the badge circle rises above the bar's top edge.
  ///
  /// Painted, not reserved — so a bar's height report adds it back when
  /// telling a scrolling caller how much room to leave.
  static const double overhang = 32;
  static const double _ring = 5;

  const OverhangBadge({super.key, required this.asset, required this.fill});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _diameter,
      // Only the part of the circle that sits INSIDE the bar occupies layout
      // space; the overhang is painted, not reserved.
      height: _diameter - overhang,
      child: OverflowBox(
        maxHeight: _diameter + _ring * 4,
        alignment: Alignment.topCenter,
        child: Transform.translate(
          offset: const Offset(0, -overhang),
          child: Container(
            width: _diameter,
            height: _diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              // The white ring that makes the badge read as punched through
              // the bar's edge.
              border: Border.all(color: WaddyColors.surface, width: _ring),
            ),
            // The ring is drawn INSIDE the 56px box, so the animation gets the
            // remaining room; a little extra inset keeps the artwork off the
            // ring rather than touching it.
            padding: const EdgeInsets.all(4),
            child: Lottie.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
