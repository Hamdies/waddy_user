import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';

/// A one-shot confetti burst in the Spots palette.
///
/// Casting a vote is the core act of the whole feature and it used to land
/// with no acknowledgement at all beyond a number changing somewhere off
/// screen — the vote sheet even returned `true` "so the opener can celebrate",
/// and no opener ever did.
///
/// Drawn as flat rectangles in the system's own four colours rather than the
/// usual multicolour party confetti, which would be the same foreign visual
/// system the emoji were removed for.
/// Pass [from] — the calling widget's own `context` — wherever there is one.
///
/// ## Why this argument had to exist
///
/// This function used to find its own context through `Get.context`, and it
/// never once worked: no confetti has appeared on any screen since it was
/// written. `Get.context` is the **`GetMaterialApp`'s** context, which sits
/// *above* the `Navigator`, and the `Overlay` lives inside it — so
/// `Overlay.maybeOf` returned null and the function bailed on its own guard
/// clause, silently, every time.
///
/// `Get.overlayContext` is no better: it is an overlay *entry's* context and
/// has no `Overlay` ancestor of its own.
///
/// A widget's own context is below the navigator and therefore below the
/// overlay, so the lookup succeeds. The Get contexts stay as a fallback for
/// callers that genuinely have none, which is better than nothing but is the
/// path that was broken.
///
/// [originY] is where the burst is fired from, as a fraction of screen height.
/// The default sits low, where a vote bar is; a screen whose celebration
/// happens higher up — the claw's prize chute, say — passes its own, because
/// a burst launched from under the fold is one the user never sees.
void showSpotsConfetti({BuildContext? from, double originY = 0.86}) {
  final context = from ?? Get.overlayContext ?? Get.context;
  if (context == null) return;
  // Respect the OS reduce-motion switch: a burst is decoration, and decoration
  // is exactly what that setting is asking us not to fling across the screen.
  if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;

  // Falling back to the navigator's own overlay when the context has none
  // above it.
  //
  // `Get.context` is the `GetMaterialApp`'s context, which sits above the
  // `Navigator`, so an `Overlay.maybeOf` from there finds nothing — that is
  // the bug this whole function shipped with. Every caller passing its own
  // context is the clean fix, but callers that genuinely have none (the vote
  // action is a top-level function reached from six places) still need to
  // work, and `Navigator.maybeOf(...).overlay` reaches the same overlay from
  // above rather than below it.
  final overlay =
      Overlay.maybeOf(context, rootOverlay: true) ??
      Navigator.maybeOf(context, rootNavigator: true)?.overlay;
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder:
        (_) => _ConfettiBurst(originY: originY, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst({required this.onDone, required this.originY});

  final VoidCallback onDone;
  final double originY;

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  static const _colors = [Spots.mint, Spots.teal, Spots.green, Spots.paperWarm];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _pieces = List.generate(28, (i) {
      // Fired upward in a fan from just above the vote bar, then let fall.
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.5;
      final speed = 260 + rng.nextDouble() * 260;
      return _Piece(
        dx: math.cos(angle) * speed,
        dy: math.sin(angle) * speed,
        color: _colors[i % _colors.length],
        size: 6 + rng.nextDouble() * 6,
        spin: (rng.nextDouble() - 0.5) * 10,
        delay: rng.nextDouble() * 0.15,
      );
    });

    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Purely decorative and non-interactive — it must never eat a tap meant
    // for the button underneath it.
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder:
              (_, __) => CustomPaint(
                size: size,
                painter: _ConfettiPainter(
                  pieces: _pieces,
                  progress: _controller.value,
                  origin: Offset(
                    size.width / 2,
                    size.height * widget.originY,
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.dx,
    required this.dy,
    required this.color,
    required this.size,
    required this.spin,
    required this.delay,
  });

  final double dx;
  final double dy;
  final Color color;
  final double size;
  final double spin;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.pieces,
    required this.progress,
    required this.origin,
  });

  final List<_Piece> pieces;
  final double progress;
  final Offset origin;

  static const double _gravity = 900;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      // Ballistic path: constant horizontal drift, gravity on the vertical.
      final x = origin.dx + p.dx * t;
      final y = origin.dy + p.dy * t + 0.5 * _gravity * t * t;

      // Fade only over the last third, so the burst reads as solid first.
      final opacity = t < 0.66 ? 1.0 : (1 - (t - 0.66) / 0.34).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
