import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter for the Deal Rush banner decorative elements
/// Clean, modern delivery app style with subtle animated accents
class DealRushPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final double animationValue;

  DealRushPainter({
    required this.primaryColor,
    required this.accentColor,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawSoftGlow(canvas, size);
    _drawFloatingSparkles(canvas, size);
    _drawDecorativeLines(canvas, size);
  }

  /// Draw soft glowing circles in the background
  void _drawSoftGlow(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    final glow1 = Offset(size.width * 0.8, size.height * 0.3);
    glowPaint.color = accentColor.withValues(alpha: 0.15);
    canvas.drawCircle(glow1, 80, glowPaint);

    final glow2 = Offset(size.width * 0.2, size.height * 0.7);
    glowPaint.color = accentColor.withValues(alpha: 0.1);
    canvas.drawCircle(glow2, 60, glowPaint);
  }

  /// Draw small sparkles that pulse and float
  void _drawFloatingSparkles(Canvas canvas, Size size) {
    final sparklePositions = [
      Offset(size.width * 0.15, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.15),
      Offset(size.width * 0.75, size.height * 0.7),
      Offset(size.width * 0.25, size.height * 0.85),
      Offset(size.width * 0.9, size.height * 0.5),
    ];

    for (int i = 0; i < sparklePositions.length; i++) {
      final pos = sparklePositions[i];
      final phase = i * 0.8;
      final pulse = 0.5 + 0.5 * math.sin(animationValue + phase);
      final opacity = 0.3 + 0.4 * pulse;
      
      _drawSparkle(canvas, pos, 8 + 4 * pulse, accentColor.withValues(alpha: opacity));
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.lineTo(center.dx + size * 0.3, center.dy - size * 0.3);
    path.lineTo(center.dx + size, center.dy);
    path.lineTo(center.dx + size * 0.3, center.dy + size * 0.3);
    path.lineTo(center.dx, center.dy + size);
    path.lineTo(center.dx - size * 0.3, center.dy + size * 0.3);
    path.lineTo(center.dx - size, center.dy);
    path.lineTo(center.dx - size * 0.3, center.dy - size * 0.3);
    path.close();

    canvas.drawPath(path, paint);
  }

  /// Draw simple decorative curved lines
  void _drawDecorativeLines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    final path1 = Path();
    path1.moveTo(size.width * 0.6, 0);
    path1.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.3,
      size.width * 1.1,
      size.height * 0.5,
    );
    canvas.drawPath(path1, linePaint);

    final path2 = Path();
    path2.moveTo(-size.width * 0.1, size.height * 0.5);
    path2.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.7,
      size.width * 0.4,
      size.height * 1.0,
    );
    canvas.drawPath(path2, linePaint);
  }

  @override
  bool shouldRepaint(covariant DealRushPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
