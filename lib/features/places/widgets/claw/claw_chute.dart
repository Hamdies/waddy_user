import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_tokens.dart';
import 'package:waddy_app/util/styles.dart';

/// The prize chute — where the balls land after the claw drops them.
///
/// One slot per pull, dark on the shell, filling left to right as the run
/// goes. Empty slots are drawn as outlined circles labelled `PICK 2`, `PICK
/// 3` and so on, so the machine states up front how many winners there will
/// be rather than revealing the count only once it has finished.
///
/// ## Why this is worth the space
///
/// Without it the run has no running score anywhere near the machine: a ball
/// leaves the glass and the only evidence is a row appearing in a list far
/// below the fold. The chute is the scoreboard *on the cabinet*, which is
/// what makes "2 of 3 pulled" mean something while you are watching rather
/// than after you have scrolled.
///
/// Decorative, like the cabinet: every name here is repeated as real text in
/// the winner list, so the screen wraps this in [ExcludeSemantics].
class ClawChute extends StatelessWidget {
  const ClawChute({
    super.key,
    required this.winners,
    required this.totalPulls,
  });

  /// The entrants pulled so far, in pull order.
  final List<DrawEntrant> winners;

  /// How many slots the chute has — the round's pull count.
  final int totalPulls;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;

    // The outcome line that used to sit here is gone: the control deck now
    // states it ("YOU WON" / "NOT THIS WEEK"), which is the better position
    // for it, and repeating it on the chute header would say the same thing
    // twice on one cabinet. The filled slots carry the machine's own state.

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: ClawTokens.deep,
        borderRadius: BorderRadius.circular(ClawTokens.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayCaps('spots_claw_chute'.tr),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Spots.kicker(
                    8,
                    color: ClawTokens.mint.withValues(alpha: 0.6),
                    tracking: 0.24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spots.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < totalPulls; i++) ...[
                // Wider than the design's 10: the rings spread outward from
                // each slot's box, so the gap has to clear two of them.
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: _Slot(
                    entrant: i < winners.length ? winners[i] : null,
                    index: i,
                    still: still,
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

class _Slot extends StatelessWidget {
  const _Slot({
    required this.entrant,
    required this.index,
    required this.still,
  });

  final DrawEntrant? entrant;
  final int index;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final filled = entrant != null;
    final photo =
        (entrant?.image != null && entrant!.image!.trim().isNotEmpty)
            ? entrant!.image!
            : null;

    final hasName = filled && entrant!.name.trim().isNotEmpty;

    // What the slot *says* and what it *announces* are deliberately not the
    // same string. The slot is ~56pt wide and clamps a long first name
    // (see `DrawEntrant.shortName`); a screen reader has no such limit, so
    // it gets the masked name whole. Reading "Mariam ellipsis A." aloud
    // would export a layout constraint into audio, where it means nothing.
    final spoken =
        hasName ? entrant!.name.trim() : 'spots_a_waddi_voter'.tr;
    final name =
        filled
            ? (hasName ? entrant!.shortName : 'spots_a_waddi_voter'.tr)
            : displayCaps(
              'spots_claw_chute_slot'.trParams({'n': '${index + 1}'}),
            );

    // A filled slot announces as one node — "pick 2, Aya M." — rather than a
    // circle and a name read as two unrelated stops. An empty slot is
    // decorative and says nothing: "pick 3, waiting" repeated down the row is
    // noise, and the count is already on the header strip.
    return Semantics(
      label:
          filled
              ? 'spots_claw_winner_a11y'.trParams({
                'rank': '${index + 1}',
                'name': spoken,
              })
              : null,
      excludeSemantics: true,
      child: _body(filled: filled, photo: photo, name: name),
    );
  }

  Widget _body({
    required bool filled,
    required String? photo,
    required String name,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The slot keeps its footprint whether or not it is filled, so the
        // chute does not reflow as balls land in it — a row that jumps every
        // three seconds is harder to read than one that simply lights up.
        ConstrainedBox(
          // The design's own 66. The ring spreads outward from this box, so
          // the drawn circle runs a few pixels wider.
          constraints: const BoxConstraints(maxWidth: 66),
          child: AspectRatio(
            aspectRatio: 1,
            child: AnimatedScale(
              // `cabDropIn` — the ball arrives with a small overshoot, the
              // residue of something dropping into a cup.
              scale: filled ? 1 : 0.86,
              duration: Duration(milliseconds: still ? 0 : 420),
              curve: Curves.easeOutBack,
              // The ring is a `boxShadow` spread, not a `Border`.
              //
              // A border insets its child, so a clipped photo inside one left
              // a band of the mint fill showing between the face and the ring
              // — the face never actually reached the edge. Spreading the ring
              // outward instead lets the image fill the whole circle.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // [Spots.mint100], not `mint200`.
                  //
                  // This fill is only ever *seen* on a winner with no photo:
                  // a face covers it entirely. So in practice it is the
                  // "no avatar" colour, and at `mint200` those slots read as
                  // brighter — therefore more important — than the winners
                  // beside them who happen to have a profile picture. Two
                  // mint plates next to three photographs looked like a
                  // ranking, when the only thing it encodes is missing data.
                  //
                  // One step down sits the plate below the ring's neon
                  // without competing with it, so the row reads as five
                  // equals in two skins rather than a podium.
                  color:
                      filled
                          ? Spots.mint100
                          : Colors.white.withValues(alpha: 0.07),
                  boxShadow: [
                    BoxShadow(
                      color:
                          filled
                              ? ClawTokens.mint
                              : ClawTokens.mint.withValues(alpha: 0.2),
                      spreadRadius: filled ? 2.5 : 1.5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: SizedBox.expand(
                    child:
                        !filled
                            ? const SizedBox.shrink()
                            : photo != null
                            ? CustomImage(image: photo, fit: BoxFit.cover)
                            : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  entrant!.initials,
                                  maxLines: 1,
                                  textScaler: TextScaler.noScaling,
                                  style: Spots.display(
                                    16,
                                    color: ClawTokens.deep,
                                  ),
                                ),
                              ),
                            ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style:
              filled
                  ? waddyBold.copyWith(fontSize: 10, color: Colors.white)
                  : Spots.kicker(
                    9,
                    color: Colors.white.withValues(alpha: 0.3),
                    tracking: 0.06,
                  ),
        ),
      ],
    );
  }
}
