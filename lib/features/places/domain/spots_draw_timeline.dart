import 'package:flutter/animation.dart';

/// The eight steps of one grab, and where each sits on a 0–1 timeline.
///
/// The source design runs these as a chain of `setTimeout`s. That leaks on
/// unmount unless every timer is tracked and cleared, and this screen has a
/// back button, a skip control and a 15-second run — three ways to leave
/// mid-chain. One [AnimationController] is disposed correctly by construction,
/// so the timings live here as fractions instead of milliseconds.
///
/// Durations are the design's `STEPS` array, unchanged:
///
/// | ms   | step    |                                                  |
/// |------|---------|--------------------------------------------------|
/// | 520  | scan    | claw sweeps *away* to 74%, hunting               |
/// | 760  | seek    | claw crosses to the target's column              |
/// | 620  | drop    | cable pays out, claw descends onto the ball      |
/// | 520  | grab    | prongs close to ±6°, cabinet shakes              |
/// | 620  | lift    | claw retracts with the ball in its feet          |
/// | 560  | carry   | claw travels to the chute side, still holding    |
/// | 280  | release | prongs open, ball drops away, winner appended    |
/// |  700 | settle  | the beat between grabs, claw parked at the chute |
///
/// ## Why `scan` and `carry` matter
///
/// An earlier port had six steps and went straight from park to the target.
/// That reads as a machine executing a known instruction, which is exactly
/// what it must *not* look like: the whole tension of a claw machine is the
/// moment before it commits. `scan` sends the claw the wrong way first, and
/// `carry` makes it deliver the ball somewhere rather than simply vanishing
/// it. Without those two the grab has no anticipation and no follow-through.
class ClawGrabTimeline {
  const ClawGrabTimeline._();

  static const Duration scan = Duration(milliseconds: 520);
  static const Duration seek = Duration(milliseconds: 760);
  static const Duration descend = Duration(milliseconds: 620);
  static const Duration close = Duration(milliseconds: 520);
  static const Duration lift = Duration(milliseconds: 620);
  static const Duration carry = Duration(milliseconds: 560);
  static const Duration eject = Duration(milliseconds: 280);

  /// The beat between grabs.
  ///
  /// The design holds 1500ms here because a winner card is up over the glass
  /// for it. Without that card it is dead air — the claw sits at the chute
  /// doing nothing — so it comes down to the length of a pause rather than
  /// the length of a read. The chute filling below is what the eye goes to.
  static const Duration reveal = Duration(milliseconds: 700);

  /// One grab, start to start. 4.58s.
  static const int _grabMs = 520 + 760 + 620 + 520 + 620 + 560 + 280 + 700;

  static const Duration grab = Duration(milliseconds: _grabMs);

  /// Total run for [pulls] grabs. Five — the live default — is ~22.9s.
  static Duration total(int pulls) => grab * pulls;

  /// Where the claw parks between grabs, as a fraction of the glass width.
  /// The design sweeps to `74%` while scanning and delivers at `18%`.
  static const double scanX = 0.74;
  static const double chuteX = 0.18;

  // Cumulative fractions within a single grab.
  static const double _ms = 1 / _grabMs;
  static double get _t0 => 0;
  static double get _tScan => 520 * _ms;
  static double get _tSeek => 1280 * _ms;
  static double get _tDrop => 1900 * _ms;
  static double get _tGrab => 2420 * _ms;
  static double get _tLift => 3040 * _ms;
  static double get _tCarry => 3600 * _ms;
  static double get _tRelease => 3880 * _ms;

  /// Curves, ported from the design's `cubic-bezier` values.
  static const Curve travelCurve = Cubic(.4, .1, .2, 1);
  static const Curve jawCurve = Cubic(.3, 1.5, .5, 1);
  static const Curve settleCurve = Cubic(.3, 1.4, .6, 1);

  /// Where a grab is at local time [t] (0–1). Pure, so the whole sequence is
  /// testable without a ticker.
  static ClawGrabFrame frameAt(double t) {
    if (t <= _tScan) {
      // Scan: the claw sweeps the *wrong way*, out to 74%, jaws wide.
      //
      // This step exists to be misleading. A claw that goes straight to its
      // target has already told you the answer; one that hunts first is the
      // reason anybody watches a claw machine at all.
      final p = _norm(t, _t0, _tScan);
      return ClawGrabFrame(
        stage: ClawStage.scan,
        scanAway: travelCurve.transform(p),
        travel: 0,
        descend: 0,
        open: 1,
        held: false,
        ejected: 0,
      );
    }
    if (t <= _tSeek) {
      // Seek: cross from the scan position to the target's column.
      final p = _norm(t, _tScan, _tSeek);
      final eased = travelCurve.transform(p);
      return ClawGrabFrame(
        stage: ClawStage.seek,
        // Unwinds the scan sweep while winding on the approach, so the claw
        // makes one continuous move rather than snapping back to park first.
        scanAway: 1 - eased,
        travel: eased,
        descend: 0,
        open: 1,
        held: false,
        ejected: 0,
      );
    }
    if (t <= _tDrop) {
      // Drop: the cable pays out and the claw descends onto the ball.
      final p = _norm(t, _tSeek, _tDrop);
      return ClawGrabFrame(
        stage: ClawStage.drop,
        travel: 1,
        descend: travelCurve.transform(p),
        open: 1,
        held: false,
        ejected: 0,
      );
    }
    if (t <= _tGrab) {
      // Grab: prongs close. The ball becomes held at the midpoint, not at the
      // start — closing on an already-held ball reads as the claw grabbing
      // something that had jumped into it.
      final p = _norm(t, _tDrop, _tGrab);
      return ClawGrabFrame(
        stage: ClawStage.grab,
        travel: 1,
        descend: 1,
        open: 1 - jawCurve.transform(p).clamp(0.0, 1.0),
        held: p >= 0.5,
        ejected: 0,
      );
    }
    if (t <= _tLift) {
      // Lift: back up to rail height with the ball in the feet.
      final p = _norm(t, _tGrab, _tLift);
      return ClawGrabFrame(
        stage: ClawStage.lift,
        travel: 1,
        descend: 1 - travelCurve.transform(p),
        open: 0,
        held: true,
        ejected: 0,
      );
    }
    if (t <= _tCarry) {
      // Carry: travel to the chute side, still holding.
      //
      // The delivery. Without it the ball simply stops existing above the
      // pile, and the chute below fills by magic.
      final p = _norm(t, _tLift, _tCarry);
      return ClawGrabFrame(
        stage: ClawStage.carry,
        travel: 1,
        carry: travelCurve.transform(p),
        descend: 0,
        open: 0,
        held: true,
        ejected: 0,
      );
    }
    if (t <= _tRelease) {
      // Release: the prongs spring open and the ball drops away.
      final p = _norm(t, _tCarry, _tRelease);
      return ClawGrabFrame(
        stage: ClawStage.release,
        travel: 1,
        carry: 1,
        descend: 0,
        open: settleCurve.transform(p).clamp(0.0, 1.0),
        held: p < 0.25,
        ejected: p,
      );
    }
    // Settle: the claw waits at the chute, empty and open, while the ball it
    // just dropped lands in the slot below and the winner row appears.
    return const ClawGrabFrame(
      stage: ClawStage.reveal,
      travel: 1,
      carry: 1,
      descend: 0,
      open: 1,
      held: false,
      ejected: 1,
    );
  }

  static double _norm(double t, double lo, double hi) =>
      hi <= lo ? 1 : ((t - lo) / (hi - lo)).clamp(0.0, 1.0);
}

/// Which of the design's eight steps a frame belongs to.
///
/// Exposed because several things key off the step rather than off the
/// continuous values: the status line names it, the cabinet shakes only
/// during [grab], and the spotlight is on for the three steps that make up
/// the hunt and off once the ball is caught.
enum ClawStage { scan, seek, drop, grab, lift, carry, release, reveal }

/// One frame of a grab: everything the cabinet needs to draw itself.
class ClawGrabFrame {
  const ClawGrabFrame({
    required this.travel,
    required this.descend,
    required this.open,
    required this.held,
    required this.ejected,
    this.stage = ClawStage.scan,
    this.scanAway = 0,
    this.carry = 0,
  });

  final ClawStage stage;

  /// 0 at park, 1 at the scan position — the sweep *away* from the target.
  ///
  /// Separate from [travel] because it moves the claw somewhere the target is
  /// not, and blending the two is what lets the seek unwind one while winding
  /// the other into a single continuous move.
  final double scanAway;

  /// 0 at park, 1 at the target column.
  final double travel;

  /// 0 at the target column, 1 at the chute — the carry after the lift.
  final double carry;

  /// 0 at rail height, 1 at grab depth.
  final double descend;

  /// Jaw opening, 0 shut to 1 open.
  final double open;

  /// Whether the target ball is in the jaws this frame.
  final bool held;

  /// 0 before the ball leaves, 1 once it is gone.
  final double ejected;
}
