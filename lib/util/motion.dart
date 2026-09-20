import 'package:flutter/widgets.dart';

/// Motion tokens — one vocabulary for how the app moves.
///
/// The point of centralising these is cohesion, not reuse: a screen where the
/// tiles press 4% and the cards press 2%, on two different curves, reads as
/// several products stacked on top of each other. The user never names the
/// inconsistency, they just find the screen slightly harder to trust.
class WaddyMotion {
  WaddyMotion._();

  // ── Curves ────────────────────────────────────────────────────────────────
  // Flutter's built-in easings are weak — `Curves.easeOut` barely bends, so an
  // animation using it reads as "a duration happened" rather than as motion
  // with intent. These are the standard strong variants.

  /// Entering / exiting / responding to a press. Starts fast, so the interface
  /// answers the finger on the first frame.
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Something already on screen moving or morphing to a new position.
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// iOS-style sheet/drawer curve (Ionic).
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);

  // ── Durations ─────────────────────────────────────────────────────────────
  // Everything the user drives stays under 300ms. Past that the interface
  // feels like it is thinking rather than reacting.

  /// Press-down / release feedback.
  static const Duration press = Duration(milliseconds: 110);

  /// Small state flips — icon swaps, badge changes, tooltips.
  static const Duration fast = Duration(milliseconds: 160);

  /// Content appearing in place: shimmer→content, section reveals.
  static const Duration enter = Duration(milliseconds: 220);

  /// First-paint entrance of a whole rail of cards. Longer than [enter]
  /// because it is a one-off the user sees on arrival, not a response to a tap.
  static const Duration reveal = Duration(milliseconds: 360);

  // ── Stagger ───────────────────────────────────────────────────────────────

  /// Delay between neighbouring cards in a staggered entrance. Long enough to
  /// read as a cascade, short enough that the last card isn't perceptibly late.
  static const Duration stagger = Duration(milliseconds: 55);

  /// How many cards may stagger. Anything past the first screenful is built
  /// lazily *during scroll*, and an entrance animation fired then reads as the
  /// list failing to keep up rather than as polish.
  static const int maxStaggered = 3;

  // ── Press depth ───────────────────────────────────────────────────────────
  // Perceived travel is what has to match, not the percentage: 3% of a 140pt
  // card and 3% of a 38pt button are 4pt and 1pt of movement. Small controls
  // get a deeper scale so every press on the screen feels equally answered.

  /// Photo tiles, module tiles, rail cards.
  static const double pressTile = 0.97;

  /// Full-width cards, rows, panels.
  static const double pressCard = 0.98;

  /// Icon buttons and other small circular controls.
  static const double pressControl = 0.94;
}
