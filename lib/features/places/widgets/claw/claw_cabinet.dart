import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw_geometry.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_arm.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_ball.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_tokens.dart';

/// How the cabinet is lit. The design exposes these as an enum prop
/// (`lighting`) and cycles them for drama; `twinCones` is its default.
enum ClawLighting { twinCones, topWash, off }

/// The machine: glass, lighting rig, pile, claw.
///
/// Laid out in the design's 350×342 coordinate space
/// ([SpotsDrawGeometry.gridWidth]) and scaled to whatever width it is given,
/// so the pile keeps its arrangement on a 320px phone and a 430px one alike.
///
/// Entirely decorative: every ball's identity is in the winner list and the
/// consolation panel, both of which are real text. Wrapped in
/// [ExcludeSemantics] by the screen so a screen reader is not asked to
/// navigate a pile of circles. See `CLAW-13`.
///
/// ## v2: a lit well, not a dark one
///
/// The previous cabinet used a dark teal-grey interior and lit the pile with
/// mint cones over it. v2 inverts that: the glass is a pale mint well and the
/// *drama* comes from selectively taking light away — while the claw is
/// hunting, everything but the target dims, desaturates and shrinks, and a
/// beam follows the claw down. That reads far better on a phone, because the
/// faces are the content and pale glass shows faces.
class ClawCabinet extends StatelessWidget {
  const ClawCabinet({
    super.key,
    required this.entrants,
    this.lighting = ClawLighting.twinCones,
    this.clawX = SpotsDrawGeometry.parkX,
    this.clawY = SpotsDrawGeometry.parkY,
    this.clawOpen = 1,
    this.heldEntrantId,
    this.targetEntrantId,
    this.shake = 0,
    this.wonEntrantIds = const {},
    this.drawClosed = false,
    // `visibleSlots` is a getter, so it cannot be a default. Any value at or
    // above the slot count means "already loaded", which is what this is for.
    this.releasedCount = 1 << 20,
    this.bulbPhase = 0,
    this.totalEntrants,
    this.week,
  });

  final List<DrawEntrant> entrants;
  final ClawLighting lighting;

  /// Claw position in design space.
  final double clawX;
  final double clawY;

  /// 0 shut, 1 open.
  final double clawOpen;

  /// The ball currently in the jaws, if any.
  final int? heldEntrantId;

  /// The ball the claw is currently hunting.
  ///
  /// Distinct from [heldEntrantId]: the target is lit and ringed *while the
  /// claw is still on its way*, which is the whole tension of the run. Once
  /// it is in the jaws it is held, not targeted.
  ///
  /// Null outside a grab, which is also what puts the glass back to full
  /// brightness between pulls.
  final int? targetEntrantId;

  /// 0–1 through the cabinet's shake, fired as the prongs bite.
  ///
  /// `cabShake 380ms` in the design. A machine that grabs something without
  /// the cabinet moving is a drawing of a machine; the knock is the one cue
  /// that the claw and the glass are the same physical object.
  final double shake;

  /// Entrants the claw has pulled — drawn in mint, celebrating.
  final Set<int> wonEntrantIds;

  /// True once every pull is replayed. Until then the balls that have not been
  /// picked are simply *waiting*, not losing: the claw may still be coming for
  /// them, and greying them out early calls the result before it is in.
  final bool drawClosed;

  /// How many balls the screen has released into the glass.
  ///
  /// Ball `i` is still above the glass while `i >= releasedCount`. The screen
  /// raises this one ball at a time so the pile loads progressively; passing
  /// [SpotsDrawGeometry.visibleSlots] (the default) means "already loaded",
  /// which is what a reduced-motion run and every widget test want.
  final int releasedCount;

  /// 0–1 phase for the bulb pulse and the beam flicker. Held static under
  /// reduced motion.
  final double bulbPhase;

  /// True pool size, where the server sent one. Drives the rail readout.
  final int? totalEntrants;

  /// The round's week number, stamped on the cabinet's rail as a model
  /// number. Null falls back to an unnumbered rail rather than inventing one.
  final int? week;

  /// Whether a grab is in progress — the state the vignette keys off.
  bool get _hunting => targetEntrantId != null;

  @override
  Widget build(BuildContext context) {
    // Reduced motion means the pile has no transitions at all: balls are
    // simply where they belong, and a pulled one is simply gone. Leaving the
    // durations in place would keep a ticker alive after the result is
    // already on screen, which is exactly what the reduced-motion test
    // asserts against.
    final still = MediaQuery.of(context).disableAnimations;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / SpotsDrawGeometry.gridWidth;
        final height = SpotsDrawGeometry.gridHeight * scale;

        return Transform.translate(
          // `cabShake` — a four-step jitter of a couple of pixels. Applied to
          // the whole glass rather than to the claw, because what is being
          // shaken is the cabinet the claw is bolted into.
          offset: _shakeOffset(scale),
          child: Container(
            height: height,
            // The glass is the one hard-edged element on a soft shell: a window
            // cut into the front, held by an inset ring rather than an outline.
            // `inset 0 0 0 3px` plus the darkening at its foot is what gives it
            // depth without a drop shadow, which would read as a sticker lying
            // on the chassis rather than a hole in it.
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: ClawTokens.glass,
                stops: [0, 0.52, 1],
              ),
              borderRadius: BorderRadius.all(
                Radius.circular(ClawTokens.rGlass),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Order is the design's z-index ladder: the lighting sits behind
                // the pile, the vignette and beam between them and the claw,
                // and the glass' own reflections in front of everything.
                _Lighting(mode: lighting, phase: bulbPhase, scale: scale),
                ..._balls(scale, still),
                // The dimmer and the beam sit *over* the pile: the balls are
                // what is being dimmed, so a wash behind them would do nothing.
                _Vignette(active: _hunting, still: still, scale: scale),
                if (_hunting)
                  _TargetBeam(
                    clawX: clawX,
                    phase: bulbPhase,
                    scale: scale,
                    still: still,
                  ),
                _claw(scale),
                _GlassSheen(scale: scale),
                _InsetRing(scale: scale),
                _RailStrip(
                  lit: lighting != ClawLighting.off,
                  phase: bulbPhase,
                  week: week,
                  total: totalEntrants ?? entrants.length,
                  scale: scale,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// `cabShake` as a position rather than a keyframe.
  ///
  /// Four sampled offsets over the step, scaled so the knock is the same
  /// physical size on every screen width. Returns zero outside the grab,
  /// which is every frame but ~380ms of each pull.
  Offset _shakeOffset(double scale) {
    if (shake <= 0 || shake >= 1) return Offset.zero;
    // The design's 20/40/60/80% keyframes, in design units.
    const steps = <Offset>[
      Offset(-2, 1),
      Offset(2, -1),
      Offset(-1, -1),
      Offset(1, 1),
    ];
    final i = (shake * steps.length).floor().clamp(0, steps.length - 1);
    return steps[i] * scale;
  }

  /// How far above the glass ball [i] starts, in ball-heights.
  ///
  /// Deterministic rather than [Random]: a ball must start from the same place
  /// on every rebuild, or a mid-drop `setState` — and the run rebuilds ~60×/s —
  /// would teleport it. The spread is what makes the pile land like loose
  /// objects instead of a row of lifts descending in formation.
  static const List<double> _dropHeights = [
    2.4,
    5.1,
    3.2,
    6.4,
    1.9,
    4.6,
    2.8,
    5.8,
    3.7,
    6.9,
    2.2,
    4.1,
  ];

  /// Per-ball fall time, in ms. Longer falls for the balls that start higher,
  /// but not proportionally — a ball from twice the height does not take twice
  /// as long, and matching them exactly would read as a machine, not gravity.
  static const List<int> _dropDurations = [
    620,
    780,
    660,
    840,
    580,
    740,
    640,
    800,
    700,
    860,
    600,
    720,
  ];

  /// How long ball [i] takes to fall. Exposed so the screen can fire that
  /// ball's landing haptic at the moment it actually lands rather than
  /// guessing a single duration for the whole pile.
  static int dropDurationFor(int i) =>
      _dropDurations[i % _dropDurations.length];

  List<Widget> _balls(double scale, bool still) {
    final shown = entrants.take(SpotsDrawGeometry.visibleSlots).toList();
    final ballSize = SpotsDrawGeometry.ballSize * scale;

    return [
      for (var i = 0; i < shown.length; i++)
        if (shown[i].userId != heldEntrantId)
          // `Positioned` must be a direct child of `Stack`, so the fade goes
          // *inside* it rather than wrapping it.
          AnimatedPositioned(
            // The drop-in: balls fall into the glass from scattered heights.
            //
            // AnimatedPositioned has no delay, so the stagger is folded into
            // the duration — and the start heights are scattered too, because
            // twelve balls entering from one line reads as a lift arriving,
            // not as a machine being loaded.
            duration: Duration(
              milliseconds:
                  still
                      ? 0
                      : i < releasedCount
                      ? dropDurationFor(i)
                      : 0,
            ),
            // easeOutBack overshoots slightly at the end: the ball settles
            // past its slot and comes back, which is the visual residue of
            // something landing on other things rather than arriving at a
            // coordinate.
            curve: Curves.easeOutBack,
            left: SpotsDrawGeometry.pileSlot(i).dx * scale,
            top:
                wonEntrantIds.contains(shown[i].userId)
                    // Out through the top of the glass, following the claw.
                    ? -ballSize * 1.6
                    : i < releasedCount
                    ? SpotsDrawGeometry.pileSlot(i).dy * scale
                    : -ballSize * _dropHeights[i % _dropHeights.length],
            width: ballSize,
            height: ballSize,
            // A pulled ball leaves the machine — without this the claw lifts a
            // winner out and the pile immediately redraws them still sitting
            // in it, which undoes the whole grab.
            child: AnimatedOpacity(
              duration: Duration(milliseconds: still ? 0 : 380),
              curve: Curves.easeOut,
              opacity: wonEntrantIds.contains(shown[i].userId) ? 0 : 1,
              child: _Settle(
                // Each ball gets its own point in the cycle, from its index.
                // Twelve balls bobbing in unison is one sheet moving; twelve
                // on scattered phases is a pile of separate objects that
                // happen to be resting against each other.
                phase: (bulbPhase + i * 0.37) % 1.0,
                // A ball is only ever this still when nothing is happening to
                // it. Mid-hunt the spotlight and the dim are saying which one
                // matters, and a float underneath that would be noise fighting
                // signal; a pulled ball is on its way out of the glass.
                active:
                    !still &&
                    !_hunting &&
                    !wonEntrantIds.contains(shown[i].userId) &&
                    i < releasedCount,
                scale: scale,
                child: ClawBall(
                entrant: shown[i],
                index: i,
                size: ballSize,
                // The target grows and rings; everything else shrinks a
                // fraction and steps back. The design does this with a
                // `scale(1.3)` on the target against `scale(0.94)` on the
                // rest, and it is most of why the run reads as a hunt.
                spotlit: shown[i].userId == targetEntrantId,
                dimmed:
                    _hunting &&
                    shown[i].userId != targetEntrantId &&
                    !wonEntrantIds.contains(shown[i].userId),
                still: still,
                state:
                    wonEntrantIds.contains(shown[i].userId)
                        ? ClawBallState.won
                        : drawClosed
                        ? ClawBallState.lost
                        : ClawBallState.waiting,
                ),
              ),
            ),
          ),
    ];
  }

  Widget _claw(double scale) {
    final held =
        heldEntrantId == null
            ? null
            : entrants.firstWhereOrNull((e) => e.userId == heldEntrantId);
    final ballSize = SpotsDrawGeometry.ballSize * scale;
    // The design's prong box is 76 wide; the rail carriage above it is 46.
    const armWidth = ClawArm.designWidth;
    // Carriage (11) + disc (48) + prong box (46).
    const armHeight = 11.0 + 48.0 + ClawArm.prongBoxHeight;

    return Positioned(
      left: clawX * scale - (armWidth * scale) / 2,
      // Hung from the *underside* of the rail strip, per the design's
      // `top: 22px` below its own 22px rail. Anchored at 0 the carriage sat
      // behind the strip and the housing disc was sliced in half by it.
      top: ClawTokens.glassTopChrome * scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClawArm(
            openAmount: clawOpen,
            width: armWidth * scale,
            height: armHeight * scale,
            cableLength: clawY * scale,
          ),
          if (held != null)
            Transform.translate(
              // The ball rides *between* the prongs, not below them. The
              // design hangs it at `top: 14px` inside a 46-tall prong box —
              // so the feet cross its upper half and it reads as gripped
              // rather than balanced on the tips.
              offset: Offset(0, -(ClawArm.prongBoxHeight - 14) * scale),
              child: ClawBall(
                entrant: held,
                index: entrants.indexOf(held),
                size: ballSize,
                state: ClawBallState.held,
                still: true,
              ),
            ),
        ],
      ),
    );
  }
}

/// The dimmer.
///
/// `inset 22px 0 0` of `#06241B` at 34% while the claw is hunting, gone
/// otherwise. This is the single largest reason the v2 run reads better than
/// the old one: the machine does not get brighter around the target, it gets
/// *darker everywhere else*, which is how a spotlight actually works.
class _Vignette extends StatelessWidget {
  const _Vignette({
    required this.active,
    required this.still,
    required this.scale,
  });

  final bool active;
  final bool still;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: ClawTokens.glassTopChrome * scale,
      bottom: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: Duration(milliseconds: still ? 0 : 320),
          curve: Curves.easeOut,
          opacity: active ? 0.34 : 0,
          child: const ColoredBox(color: ClawTokens.deep),
        ),
      ),
    );
  }
}

/// The beam that follows the claw down onto its target.
///
/// A mint trapezoid, narrow at the rail and wide at the floor, fading out as
/// it falls — `clip-path: polygon(34% 0, 66% 0, 100% 100%, 0 100%)` over a
/// vertical mint gradient. It tracks [clawX] on the same curve as the claw
/// itself, so the light arrives with the machine rather than chasing it.
class _TargetBeam extends StatelessWidget {
  const _TargetBeam({
    required this.clawX,
    required this.phase,
    required this.scale,
    required this.still,
  });

  final double clawX;
  final double phase;
  final double scale;
  final bool still;

  /// A 0–1 triangle wave — the shape of every `0%,100%{a} 50%{b}` keyframe in
  /// the design.
  static double _wave(double t) {
    final p = t % 1.0;
    return p < 0.5 ? p * 2 : (1 - p) * 2;
  }

  @override
  Widget build(BuildContext context) {
    const width = 150.0;
    final top = ClawTokens.glassTopChrome * scale;
    // `cabBeam 700ms` — 0.55 to 0.9 and back. Held at its midpoint when the
    // user has asked for less motion, so the beam is present but not pulsing.
    final glow = still ? 0.72 : 0.55 + _wave(phase * 4) * 0.35;

    return Positioned(
      left: clawX * scale - (width * scale) / 2,
      top: top,
      width: width * scale,
      bottom: 0,
      child: IgnorePointer(
        child: ClipPath(
          clipper: const _BeamClipper(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ClawTokens.mint.withValues(alpha: glow),
                  ClawTokens.mint.withValues(alpha: glow * 0.24),
                  ClawTokens.mint.withValues(alpha: 0),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `polygon(34% 0, 66% 0, 100% 100%, 0 100%)` — the spread of a beam from a
/// point source at the rail.
class _BeamClipper extends CustomClipper<Path> {
  const _BeamClipper();

  @override
  Path getClip(Size size) =>
      Path()
        ..moveTo(size.width * 0.34, 0)
        ..lineTo(size.width * 0.66, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();

  @override
  bool shouldReclip(_BeamClipper old) => false;
}

/// The barely-there settle a resting ball has in the glass.
///
/// ## What this is for
///
/// Before anyone presses anything, the pile is twelve photographs sitting at
/// exact coordinates — and that is what it looked like: a printed picture of
/// a claw machine rather than a machine with things in it. The sway gave the
/// *claw* life while idle and the pile underneath it stayed perfectly rigid,
/// which made the stillness more obvious rather than less.
///
/// ## Why it is this small
///
/// The motion is roughly a pixel and a half at the default scale, on a slow
/// cycle, with each ball on its own phase. That is deliberately below the
/// threshold where anyone can point at it: balls in a real machine are not
/// bobbing, they are *settled*, and anything you can actually see reads as
/// floating in liquid. The intent is that the pile feels like it has weight
/// resting on weight, and that nobody can say why.
///
/// ## Why it is a transform, not a position
///
/// The slot coordinates belong to [AnimatedPositioned], which owns the
/// drop-in. Writing to `left`/`top` from here would fight it mid-fall. A
/// `Transform.translate` composites on the GPU, changes no layout, and stacks
/// cleanly on top of whatever the drop is doing.
class _Settle extends StatelessWidget {
  const _Settle({
    required this.phase,
    required this.active,
    required this.scale,
    required this.child,
  });

  /// 0–1, already offset per ball by the caller.
  final double phase;

  /// False whenever something more important is happening to this ball, and
  /// under reduced motion.
  final bool active;

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    // A sine, so the ball eases through both ends of the travel instead of
    // turning on the spot — the same reason the claw's drift is a sine.
    final dy = math.sin(phase * 2 * math.pi) * 1.5 * scale;
    return Transform.translate(offset: Offset(0, dy), child: child);
  }
}

/// The ambient lighting in the glass, before anything is targeted.
///
/// Much weaker than the v1 cones: the v2 well is already pale, so this is a
/// soft top wash that suggests bulbs above the pile rather than two hard
/// spotlights fighting the daylight the glass is full of.
class _Lighting extends StatelessWidget {
  const _Lighting({
    required this.mode,
    required this.phase,
    required this.scale,
  });

  final ClawLighting mode;
  final double phase;
  final double scale;

  static double _wave(double t) {
    final p = t % 1.0;
    return p < 0.5 ? p * 2 : (1 - p) * 2;
  }

  @override
  Widget build(BuildContext context) {
    if (mode == ClawLighting.off) return const SizedBox.shrink();

    final top = ClawTokens.glassTopChrome * scale;
    // `twinCones` is the hunting look and `topWash` the resting one; at v2's
    // brightness the difference is a matter of degree, not of shape.
    final strength = mode == ClawLighting.twinCones ? 0.22 : 0.14;

    return Positioned(
      left: 0,
      right: 0,
      top: top,
      bottom: 0,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: strength + _wave(phase) * 0.06),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The glass' own surface: one diagonal highlight down each edge.
///
/// `linear-gradient(102deg, …)` in the design — a bright band at the left
/// edge and a narrower one at the right, with nothing across the middle,
/// because a reflection over the middle of the glass hides the faces that are
/// the entire point of the machine.
class _GlassSheen extends StatelessWidget {
  const _GlassSheen({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              // 102° from vertical in CSS ≈ a shallow left-to-right diagonal.
              begin: const Alignment(-1, -0.85),
              end: const Alignment(1, 0.85),
              colors: [
                Colors.white.withValues(alpha: 0.6),
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.4),
              ],
              stops: const [0, 0.26, 0.72, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring that holds the glass in the shell.
///
/// `inset 0 0 0 3px rgba(6,36,27,0.9)` plus `inset 0 -24px 34px -18px` at the
/// foot. Painted rather than set as a `Border`, because a border would inset
/// the glass' own contents and shift the pile by three pixels.
class _InsetRing extends StatelessWidget {
  const _InsetRing({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _InsetRingPainter(scale: scale)),
      ),
    );
  }
}

class _InsetRingPainter extends CustomPainter {
  const _InsetRingPainter({required this.scale});

  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // The darkening at the foot of the well — the floor of the glass is
    // further from the lights than its brow.
    canvas.drawRect(
      Rect.fromLTRB(0, size.height - 34 * scale, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ClawTokens.deep.withValues(alpha: 0),
            ClawTokens.deep.withValues(alpha: 0.28),
          ],
        ).createShader(
          Rect.fromLTRB(0, size.height - 34 * scale, size.width, size.height),
        ),
    );

    final w = ClawTokens.bw3 * scale;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(w / 2),
        const Radius.circular(ClawTokens.rGlass),
      ),
      Paint()
        ..color = ClawTokens.deep.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w,
    );
  }

  @override
  bool shouldRepaint(_InsetRingPainter old) => old.scale != scale;
}

/// The dark strip across the glass' brow — model number, pool size, bulbs.
///
/// The design prints `RAIL · MDL-38` and `+1,000 IN THE MACHINE` here. That
/// second number is the one honest way to show a pool of hundreds inside a
/// twelve-ball machine, and it replaces v1's floating overflow plate, which
/// sat over the pile and covered a face to say so.
class _RailStrip extends StatelessWidget {
  const _RailStrip({
    required this.lit,
    required this.phase,
    required this.week,
    required this.total,
    required this.scale,
  });

  final bool lit;
  final double phase;
  final int? week;
  final int total;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: ClawTokens.glassTopChrome * scale,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: ClawTokens.deep)),
          // Four bulbs chasing along the rail, behind the text — a rail of
          // lights all pulsing together reads as a warning, not a show.
          Positioned(
            left: 0,
            right: 0,
            bottom: 4 * scale,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 6; i++)
                  _Bulb(
                    lit: lit,
                    phase: (phase + i * 0.16) % 1.0,
                    size: 4 * scale,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bulb extends StatelessWidget {
  const _Bulb({required this.lit, required this.phase, required this.size});

  final bool lit;
  final double phase;
  final double size;

  @override
  Widget build(BuildContext context) {
    // A triangle wave: bright at the middle of the phase, dim at both ends.
    final t = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    final on = lit ? 0.2 + t * 0.8 : 0.15;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color.lerp(ClawTokens.deep, ClawTokens.mint, on),
        shape: BoxShape.circle,
      ),
    );
  }
}
