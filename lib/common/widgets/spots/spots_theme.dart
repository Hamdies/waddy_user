import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/util/styles.dart';

/// ─── WADDI Spots design tokens ──────────────────────────────────────────────
/// Ported verbatim from the "WADDI Spots Design System" (Claude Design project
/// bb4b3c6b). Neubrutalism, light-mode only. The border is deep TEAL, never
/// black; panels are deep teal; the neon is electric mint; shadows are hard,
/// zero-blur offsets (teal by default, mint under the leader / hero).
class Spots {
  Spots._();

  // ── Base palette ──
  static const Color mint = Color(0xFF1EF2A0); // electric mint — neon accent
  static const Color teal = Color(0xFF134E4A); // deep teal — ink, borders
  static const Color teal900 = Color(0xFF0C3532); // pressed / deep shadow
  static const Color red = Color(0xFFFF3B30); // live / urgent / slipping
  static const Color green = Color(0xFF22C55E); // rising / positive delta
  static const Color panel = Color(0xFF0E3532); // dark teal panels

  /// Third place on the voter podium. Was [red] — but red is the semantic
  /// colour for live/urgent/slipping in this system, and third place is a
  /// standing, not an alarm. A muted bronze reads as a medal and leaves red
  /// meaning only one thing.
  static const Color bronze = Color(0xFFB0764A);

  // ── Ink & paper ──
  static const Color ink = Color(0xFF10312E); // primary text
  static const Color ink2 = Color(0xFF3F5754); // secondary text
  static const Color ink3 = Color(0xFF6E8481); // tertiary / meta
  static const Color paper = Color(0xFFFFFFFF); // card / surface

  /// Warm off-white — quiet surfaces that must sit *behind* a [paper] card
  /// without reading as another card: stat boxes, empty states, icon plates.
  /// Was a private constant in place_details_screen; promoted here so the two
  /// surface whites are one decision rather than a per-file invention.
  static const Color paperWarm = Color(0xFFF4F3EE);
  static const Color border = Color(0xFF134E4A); // neubrutalist border (teal)

  // ── Canvas — dot-grid off-white ──
  static const Color canvas = Color(0xFFDDE4E2);
  static const Color canvasDot = Color(0xFFC7D1CE);

  // Softened one step in Sept 2026. The system stays neubrutalist — visible
  // borders, offset shadows, no gradients — but at 3px borders / 4px hard
  // shadows / 8px radii everything on a dense screen shouted at the same
  // volume, and nothing could be emphasised because everything already was.
  // Rounder corners and a lighter default weight give the loud elements
  // somewhere to be loud *against*.
  static const double radiusSm = 6; // chips, pills
  static const double radiusMd = 12; // buttons, inputs
  static const double radiusLg = 16; // cards, panels — the maximum
  static const double radiusPill = 10; // "pills" are still boxy, not oval

  // ── Spacing (4pt grid) ──
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  /// The single horizontal screen gutter — masthead and body must agree.
  static const double gutter = s16;

  /// Vertical rhythm between home sections.
  static const double sectionGap = s32;

  // ── Border widths — only two exist in this system ──
  //
  // Thick dropped 3 → 2.5 and thin 2 → 1.5: still unmistakably a drawn border,
  // but it stops reading as a cage around every element.
  static const double borderThin = 1.5; // chips, badges, quiet cards
  static const double borderThick = 2.5; // hero cards, masthead rule

  /// The "sticker" drop.
  ///
  /// Still an offset shadow, but 3px instead of 4 and at 80% rather than a
  /// solid slab of teal — at full opacity every card looked like it had a
  /// second card behind it. A hair of blur takes the saw-tooth off the
  /// diagonal without turning it into a Material elevation.
  static List<BoxShadow> shadow({
    double dx = 3,
    double dy = 3,
    Color color = border,
    double opacity = 0.8,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: opacity),
      offset: Offset(dx, dy),
      blurRadius: 0.5,
    ),
  ];

  /// Card / panel decoration: fill + teal border + hard offset shadow.
  static BoxDecoration card({
    Color fill = paper,
    double radius = radiusLg,
    double borderWidth = borderThick,
    double dx = 3,
    double dy = 3,
    Color shadowColor = border,
  }) => BoxDecoration(
    color: fill,
    border: Border.all(color: border, width: borderWidth),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: shadow(dx: dx, dy: dy, color: shadowColor),
  );

  // ── Type helpers — display face (Alexandria), not the body face ──
  //
  // These were built on `waddyBlack`, i.e. the body family at w900. That made
  // a scoreline and a paragraph the same typeface at different weights, which
  // is why the battle card had to lean on a dark plate and neon to feel
  // distinct — the type was doing none of the work.

  /// LOUD display / score — black weight, tight optical tracking.
  static TextStyle display(
    double size, {
    Color color = ink,
    double tracking = -0.02,
  }) => waddyDisplayFace(
    size,
    weight: FontWeight.w900,
    color: color,
    tracking: tracking,
    height: 0.95,
  );

  /// ALL-CAPS kicker / label — wide tracking.
  static TextStyle kicker(
    double size, {
    Color color = ink3,
    double tracking = 0.12,
  }) => waddyKicker(
    size,
    color: color,
    tracking: tracking,
    weight: FontWeight.w900,
  );
}

/// Neubrutalist press feedback: the card sits over a static shadow plate and
/// slides onto it while pressed, so the hard shadow collapses under the
/// finger. Build the child with `Spots.card(dx: 0, dy: 0)` — the plate here
/// replaces the card's own shadow.
///
/// dx/dy stay physical (down-right) in RTL: the shadow is a light-source
/// convention, not a reading-direction one.
class SpotsPressable extends StatefulWidget {
  const SpotsPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.dx = 4,
    this.dy = 4,
    this.shadowColor = Spots.border,
    this.radius = Spots.radiusLg,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double dx;
  final double dy;
  final Color shadowColor;
  final double radius;
  final bool enabled;

  @override
  State<SpotsPressable> createState() => _SpotsPressableState();
}

class _SpotsPressableState extends State<SpotsPressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final Duration duration =
        MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 90);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) {
        _set(false);
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: widget.dx,
            top: widget.dy,
            right: -widget.dx,
            bottom: -widget.dy,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.shadowColor,
                borderRadius: BorderRadius.circular(widget.radius),
              ),
            ),
          ),
          AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(
              _down ? widget.dx : 0,
              _down ? widget.dy : 0,
              0,
            ),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// The one loading language for Spots: an outlined canvas-dot box with the
/// app-standard shimmer sweep. Static when the user has reduced motion on.
class SpotsSkeleton extends StatelessWidget {
  const SpotsSkeleton({
    super.key,
    this.height,
    this.width,
    this.radius = Spots.radiusLg,
  });

  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Widget box = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Spots.canvasDot,
        border: Border.all(
          color: Spots.border.withValues(alpha: 0.25),
          width: Spots.borderThin,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (MediaQuery.of(context).disableAnimations) return box;
    return Shimmer(child: box);
  }
}
