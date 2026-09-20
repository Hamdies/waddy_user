import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_tokens.dart';
import 'package:waddy_app/util/styles.dart';

/// "VOTER DRAW — 1 OF 3 PULLED" — the mint brow across the top of the shell.
///
/// The count lives here rather than under the cabinet because it is a readout
/// *on the machine*, the way a real cabinet prints credits on its marquee. It
/// also puts the one number that changes during the run at the top of the
/// object the user is already staring at.
///
/// The pips beside it are the same fact as a shape. A number has to be read;
/// three bars, one of them filled, is legible in the half-second between two
/// grabs, which is the only time anybody actually looks at it.
class ClawHeaderStrip extends StatelessWidget {
  const ClawHeaderStrip({super.key, required this.pulled, required this.total});

  final int pulled;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spots.s16, vertical: 11),
      decoration: const BoxDecoration(
        // The one gradient in the system, and the design is explicit about
        // it: the brow is a lit strip, not a flat panel, and the two mints
        // are what make it read as a curved surface catching light.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ClawTokens.mint, ClawTokens.mintDeep],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ClawTokens.rLg),
          topRight: Radius.circular(ClawTokens.rLg),
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: Row(
        children: [
          // The title takes the room, the pips take what they need.
          //
          // The "N OF M PULLED" readout that used to sit between these two is
          // gone: the pips are the same fact as a shape, and a strip carrying
          // a number, a bar chart of that number and a title was three things
          // competing in one 13pt row — which is what truncated the title to
          // "VOTER DRA…" at default text scale.
          Expanded(
            child: Text(
              displayCaps('spots_claw_panel_title'.tr),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Spots.kicker(13, color: ClawTokens.deep, tracking: 0.16),
            ),
          ),
          const SizedBox(width: Spots.s12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                AnimatedContainer(
                  duration: Duration(
                    milliseconds:
                        MediaQuery.of(context).disableAnimations ? 0 : 280,
                  ),
                  curve: Curves.easeOut,
                  width: 13,
                  height: 5,
                  decoration: BoxDecoration(
                    color:
                        i < pulled
                            ? ClawTokens.deep
                            : ClawTokens.deep.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
