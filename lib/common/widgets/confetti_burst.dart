import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waddy_app/theme/light_theme.dart';

/// A one-shot confetti shower over the whole screen, from an overlay so it
/// can fall past whatever launched it. Removes itself when done and never
/// takes a tap. Skipped when the system asks for reduced motion.
class ConfettiBurst extends StatefulWidget {
  final VoidCallback onDone;
  const ConfettiBurst({super.key, required this.onDone});

  static void show(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (_) =>
              IgnorePointer(child: ConfettiBurst(onDone: () => entry.remove())),
    );
    overlay.insert(entry);
  }

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward().whenComplete(widget.onDone);

  late final List<_Piece> _pieces = List.generate(70, _Piece.seeded);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder:
          (_, __) => CustomPaint(
            size: MediaQuery.sizeOf(context),
            painter: _ConfettiPainter(_pieces, _controller.value),
          ),
    );
  }
}

class _Piece {
  final double x, w, h, dx, dy, spin, delay, life;
  final bool round;
  final Color color;

  const _Piece(
    this.x,
    this.w,
    this.h,
    this.dx,
    this.dy,
    this.spin,
    this.delay,
    this.life,
    this.round,
    this.color,
  );

  static const List<Color> _colors = [
    WaddyColors.mint,
    WaddyColors.primary,
    WaddyColors.mintInk,
    WaddyColors.amber,
    WaddyColors.coral,
    WaddyColors.contenderCool,
  ];

  /// Deterministic pseudo-random per index, so every burst looks alike.
  factory _Piece.seeded(int i) {
    double r(int n) {
      final double v = math.sin(i * 12.9898 + n * 78.233) * 43758.5453;
      return v - v.floorToDouble();
    }

    return _Piece(
      0.1 + r(1) * 0.8,
      6 + r(2) * 5,
      9 + r(3) * 6,
      (r(5) - 0.5) * 160,
      520 + r(6) * 360,
      (r(7) * 900 - 450) * math.pi / 180,
      r(9) * 0.16,
      0.6 + r(8) * 0.36,
      r(4) > 0.6,
      _colors[i % _colors.length],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    for (final p in pieces) {
      final double local = ((t - p.delay) / p.life).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      // Ease-out: fast start, gentle landing.
      final double e = 1 - math.pow(1 - local, 2.2).toDouble();
      paint.color = p.color.withValues(alpha: 1 - local);
      canvas.save();
      canvas.translate(p.x * size.width + p.dx * e, -12 + p.dy * e);
      canvas.rotate(p.spin * e);
      final Rect rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.w,
        height: p.h,
      );
      if (p.round) {
        canvas.drawOval(rect, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
