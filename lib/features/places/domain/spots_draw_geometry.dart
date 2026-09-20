import 'dart:ui' show Offset;

/// Where the balls sit inside the claw cabinet, and how far the claw travels.
///
/// Every number here is in the source design's coordinate space: a **350 × 342**
/// box, measured from the cabinet's inner top-left. Nothing scales itself — the
/// cabinet widget maps this space onto whatever width it actually gets, so the
/// pile keeps its arrangement on a 320px phone and a 430px one alike.
///
/// Kept out of the widget layer for the same reason as `SpotsDraw`: [pileSlot]
/// has an off-by-one that only shows up past the twelfth entrant, and that is
/// worth a unit test rather than a screenshot.
class SpotsDrawGeometry {
  const SpotsDrawGeometry._();

  /// The design-space box these coordinates live in.
  static const double gridWidth = 350;
  static const double gridHeight = 342;

  /// Ball diameter in design space.
  ///
  /// Down from the design's 62. At that size twelve balls filled the glass
  /// almost edge to edge, so the pile read as a mosaic rather than as loose
  /// objects in a box — and a claw scaled to grip one was necessarily huge.
  /// Smaller balls leave air between them, which is what makes a pile look
  /// like a pile.
  static const double ballSize = 48;

  /// Rail-to-claw cable length at rest.
  static const double hang = 116;

  /// How far above a ball's centre the cable stops paying out.
  ///
  /// The claw hangs from the underside of the glass' 40-deep rail strip, and
  /// its own body runs 101 below the end of the cable: an 11 carriage, a 48
  /// housing disc, then the 42-deep prong box. A cable of
  /// `ball.centreY − grabOffset` therefore lands the feet just past the
  /// ball's centre, which is where the hooks can curl under its edge.
  ///
  /// It tracks the claw's own length, the ball's size *and* where the claw is
  /// hung from: change any of those without changing this and the claw
  /// reaches the wrong depth.
  static const double grabOffset = 131;

  /// The claw's parked position — where it waits between runs.
  ///
  /// Centred, per the design's `left: 50%` at idle. It used to sit at 46,
  /// hard against the left wall, which is where a claw goes to be out of the
  /// way rather than where one waits to be used.
  static const double parkY = 10;
  static const double parkX = gridWidth / 2;

  /// Where the claw sweeps while scanning — the design's `left: 74%`.
  ///
  /// Deliberately not near the centre: the scan has to look like the machine
  /// considering somewhere it does not end up going.
  static const double scanX = gridWidth * 0.74;

  /// How far either side of [parkX] the claw drifts while idle.
  ///
  /// The design sways `±72px` over a 350 glass. Kept a little tighter so the
  /// claw stays clear of the glass walls at the extremes of its travel.
  static const double swayReach = 62;

  /// Where the claw delivers — the design's `left: 18%`, the chute side.
  static const double chuteX = gridWidth * 0.18;

  /// The twelve resting slots, top-left of each ball in design space.
  ///
  /// Hand-placed in the design to look like a settled pile rather than a grid:
  /// the rows interlock and no two balls share an x. Do not "tidy" these into
  /// an even distribution — the irregularity is what makes it read as loose
  /// balls in a box instead of a chessboard.
  ///
  /// Retuned for the 48 ball: the pitch came down from ~70 to ~62 and the
  /// whole pile shifted right to stay centred in the 350 glass. Kept on the
  /// original three interlocking rows — only the spacing changed.
  static const List<Offset> pile = [
    Offset(32, 252),
    Offset(94, 264),
    Offset(156, 252),
    Offset(218, 264),
    Offset(252, 198),
    Offset(190, 190),
    Offset(128, 198),
    Offset(66, 190),
    Offset(38, 136),
    Offset(100, 128),
    Offset(162, 136),
    Offset(224, 128),
  ];

  /// How many balls the cabinet can show at once.
  static int get visibleSlots => pile.length;

  /// Resting position for the entrant at [index].
  ///
  /// The design hardcodes twelve voters into twelve slots and indexes them
  /// directly. A real round has any number — `winners_per_week` alone defaults
  /// to 5 and a popular venue draws from hundreds — so this wraps instead of
  /// running off the end of the list.
  ///
  /// Wrapping means two balls can share a slot. That is fine and deliberate:
  /// the cabinet only ever *renders* [visibleSlots] of them, and the overflow
  /// is stated in copy rather than drawn as an unreadable heap.
  static Offset pileSlot(int index) {
    if (index < 0) return pile.first;
    return pile[index % pile.length];
  }

  /// Centre of the ball resting at [index] — what the claw aims at.
  static Offset pileCentre(int index) {
    final slot = pileSlot(index);
    return Offset(slot.dx + ballSize / 2, slot.dy + ballSize / 2);
  }

  /// Claw x for a grab at [index], clamped so the arm cannot leave the glass.
  static double clawXFor(int index) {
    final centre = pileCentre(index).dx;
    return centre.clamp(ballSize / 2, gridWidth - ballSize / 2);
  }

  /// Claw y for a grab at [index] — stops [grabOffset] above the ball.
  static double clawYFor(int index) => pileCentre(index).dy - grabOffset;

  /// How many entrants are in the machine but not drawn.
  ///
  /// [total] is the server's `total_entrants` where it sent one, so the copy
  /// states the real pool rather than the sampled subset. See `CLAW-Z1`.
  static int overflowCount(int total) {
    final hidden = total - visibleSlots;
    return hidden > 0 ? hidden : 0;
  }
}
