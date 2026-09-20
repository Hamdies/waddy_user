import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw_geometry.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_tokens.dart';
import 'package:waddy_app/util/styles.dart';

/// One voter, as a ball in the machine.
///
/// Four states, and the difference between them is the whole point of the
/// screen:
///
/// * [ClawBallState.waiting] — everyone before the draw runs
/// * [ClawBallState.held] — the ball in the jaws right now
/// * [ClawBallState.won] — pulled by the claw. Celebrates.
/// * [ClawBallState.lost] — still in the machine once the draw closed.
///
/// The won/lost distinction is not cosmetic. A pulled ball is the *winner*,
/// and an earlier version marked it `lost` — greying it out and stamping it
/// with 😢 at the exact moment it should have been celebrating, while the
/// voters who genuinely missed out stayed bright. Getting these two backwards
/// inverts the meaning of the entire screen, so they are named for what
/// happened to the voter rather than for what the claw did.
enum ClawBallState { waiting, held, won, lost }

class ClawBall extends StatelessWidget {
  const ClawBall({
    super.key,
    required this.entrant,
    required this.index,
    this.state = ClawBallState.waiting,
    this.size = SpotsDrawGeometry.ballSize,
    this.spotlit = false,
    this.dimmed = false,
    this.still = false,
  });

  final DrawEntrant entrant;

  /// Position in the pile. Drives the fill colour and the resting tilt, so a
  /// given voter keeps the same ball across a rebuild.
  final int index;

  final ClawBallState state;
  final double size;

  /// The ball the claw is hunting this instant.
  ///
  /// Grows to 1.3×, straightens up and takes a mint ring. Only ever one ball
  /// at a time — this is the machine pointing at somebody.
  final bool spotlit;

  /// A ball that is *not* the target while a grab is running.
  ///
  /// Steps back: 0.42 opacity, desaturated, fractionally smaller. The design
  /// also blurs these; a blur on twelve moving widgets is the single most
  /// expensive thing this screen could do per frame, and desaturating plus
  /// fading gets ~all of the effect, so the blur is dropped deliberately.
  final bool dimmed;

  /// Skips the state transitions. Set for the held ball, which is already
  /// being moved by the claw, and under reduced motion.
  final bool still;

  /// The six ball fills, cycled by index.
  ///
  /// Full [Spots.mint] is deliberately absent. The chassis around the glass is
  /// already mint, and a mint ball on a mint machine loses its edge — the pile
  /// stopped reading as objects *inside* a box and started dissolving into the
  /// frame. Mint at full strength now belongs to one thing in this widget: a
  /// ball the claw has won. Everything waiting sits in the tints and papers,
  /// which is also what makes the winner pop when it changes.
  static const List<Color> _fills = [
    Spots.paper,
    Spots.mint200,
    Spots.paperWarm,
    Spots.mint100,
    Spots.paper,
    Spots.mint200,
  ];

  /// Luminance-preserving greyscale. A passed-over face goes grey rather than
  /// disappearing: the point of the losing balls is that you can still see who
  /// is still in the machine.
  static const List<double> _greyscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// `saturate(0.35)` — the design's dimming filter, as a colour matrix.
  ///
  /// Each output channel is 35% of its own value plus 65% of the luminance,
  /// so colour drains toward grey while brightness is preserved. A dimmed
  /// ball must still show a recognisable face: the point of the pile is that
  /// you can see who is still in the machine, even while the claw looks
  /// elsewhere.
  static const List<double> _desaturate = <double>[
    0.7591, 0.4647, 0.0469, 0, 0, //
    0.1381, 0.8157, 0.0469, 0, 0, //
    0.1381, 0.4647, 0.3979, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// A static per-index tilt. Real balls in a box do not share an axis.
  /// Deterministic rather than random so nothing shifts between frames.
  static const List<double> _tilts = [
    -0.10,
    0.06,
    -0.04,
    0.12,
    -0.08,
    0.03,
    0.09,
    -0.12,
    0.05,
    -0.06,
    0.11,
    -0.03,
  ];

  @override
  Widget build(BuildContext context) {
    final lost = state == ClawBallState.lost;
    final held = state == ClawBallState.held;
    final won = state == ClawBallState.won;

    // Empty strings are as common as nulls here — `pickImageUrl` returns null
    // for an unusable candidate, but a demo or a hand-built entrant can still
    // carry ''. Both mean "no face", so both fall through to initials.
    final photo =
        (entrant.image != null && entrant.image!.trim().isNotEmpty)
            ? entrant.image!
            : null;

    final fill =
        lost
            ? Spots.paperSunk
            : won
            ? Spots.mint
            : _fills[index % _fills.length];
    final tilt = _tilts[index % _tilts.length];

    // The held and spotlit balls straighten up: both are the subject of the
    // moment, and a tilt reads as "resting in the pile", which neither is.
    final rotation = held || spotlit ? 0.0 : tilt;

    // The design's `scale(1.3)` on the target against `scale(0.94)` on
    // everything else. The gap between them is what makes the machine look
    // like it has singled somebody out.
    final targetScale =
        spotlit
            ? 1.3
            : dimmed
            ? 0.94
            : 1.0;

    final duration = Duration(milliseconds: still ? 0 : 340);

    final ball = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
          // The spotlit ball's ring is the machine's own mint, not the ink
          // border: it is being *lit*, and a target picked out in the same
          // colour as every other ball's outline is not picked out at all.
          color: spotlit ? ClawTokens.mint : ClawTokens.deep,
          width: spotlit ? ClawTokens.bw2 : ClawTokens.bw1,
        ),
        // The drop shadow under the ball is removed on request. The target's
        // halo — `0 0 0 10px rgba(34,239,161,0.28)` — stays: it is the
        // hunt's targeting cue, not decoration.
        boxShadow:
            held || !spotlit
                ? null
                : [
                  BoxShadow(
                    color: ClawTokens.mint.withValues(alpha: 0.28),
                    spreadRadius: size * 0.16,
                  ),
                ],
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // The face. This is the joke — a machine full of actual people,
          // and the claw reaches in and picks one up. Initials are the
          // fallback, not the design: a pile of grey monograms is a list
          // with extra steps.
          if (photo != null)
            ClipOval(
              child: SizedBox(
                width: size,
                height: size,
                child: ColorFiltered(
                  // A passed-over ball desaturates along with everything
                  // else on it, so "spent" reads at a glance across the
                  // whole pile rather than one badge at a time.
                  colorFilter:
                      lost
                          ? const ColorFilter.matrix(_greyscale)
                          : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.dst,
                          ),
                  child: CustomImage(image: photo, fit: BoxFit.cover),
                ),
              ),
            )
          else
            Text(
              entrant.initials,
              maxLines: 1,
              // The initials are the only text on the ball and the ball
              // cannot grow, so at a large text scale they must shrink
              // rather than wrap or clip. See `CLAW-13`.
              textScaler: TextScaler.noScaling,
              style: Spots.display(
                size * 0.32,
                color: lost ? Spots.ink3 : Spots.teal,
              ),
            ),
          // The design pins the tag inside the ball as a bordered white
          // disc, not a bare emoji floating off the edge — on a pile where
          // balls overlap, an unbacked glyph lands on whatever is behind it.
          if (lost || won)
            PositionedDirectional(
              // Clear of the monogram underneath: at the previous inset the
              // badge sat directly on top of two-letter initials like "AM".
              // Overlapping the ball's border is fine; overlapping the face
              // is what made those balls look broken rather than tagged.
              bottom: -size * 0.02,
              end: -size * 0.02,
              child: Container(
                width: size * 0.31,
                height: size * 0.31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Spots.paper,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Spots.border,
                    width: ClawTokens.bw1 * 0.5,
                  ),
                ),
                child: Text(
                  won ? '🎉' : '😢',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontSize: size * 0.16, height: 1),
                ),
              ),
            ),
        ],
      ),
    );

    // Scale, fade and desaturate as one move. The design animates these on
    // `transform`/`opacity`/`filter` with a single 340ms overshoot curve, and
    // keeping them on one implicit animation is what stops a dimmed ball from
    // arriving at its new size before it has finished fading.
    return AnimatedScale(
      scale: targetScale,
      duration: duration,
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.42 : 1,
        duration: duration,
        curve: Curves.easeOut,
        child: Transform.rotate(
          angle: rotation,
          child:
              dimmed
                  // Desaturation is the third of the design's three dimming
                  // moves. It is a colour filter over the whole ball rather
                  // than only the photo, so the fill and the ring step back
                  // with the face instead of staying bright around a grey
                  // portrait.
                  ? ColorFiltered(
                    colorFilter: const ColorFilter.matrix(_desaturate),
                    child: ball,
                  )
                  : ball,
        ),
      ),
    );
  }
}

/// The overflow plate — "+N MORE IN THE MACHINE".
///
/// The cabinet renders at most [SpotsDrawGeometry.visibleSlots] balls, but a
/// real round draws from a pool that can run to hundreds. Stating the rest in
/// copy is honest; drawing three hundred overlapping circles is not.
class ClawOverflowPlate extends StatelessWidget {
  const ClawOverflowPlate({super.key, required this.hidden});

  final int hidden;

  @override
  Widget build(BuildContext context) {
    if (hidden <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spots.s8,
        vertical: Spots.s4,
      ),
      decoration: BoxDecoration(
        color: Spots.panel,
        borderRadius: BorderRadius.circular(ClawTokens.rSm),
        border: Border.all(color: Spots.border, width: ClawTokens.bw1),
        boxShadow: ClawTokens.hard(2),
      ),
      child: Text(
        displayCaps('spots_claw_overflow'.trParams({'count': '$hidden'})),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Spots.kicker(9, color: Spots.mint),
      ),
    );
  }
}
