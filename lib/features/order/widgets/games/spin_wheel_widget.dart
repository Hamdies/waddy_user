import 'dart:math';
import 'package:flutter/material.dart';

class SpinWheelWidget extends StatelessWidget {
  final double size;

  const SpinWheelWidget({super.key, this.size = 280});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The wheel painter
          CustomPaint(
            size: Size(size - 24, size - 24),
            painter: _SpinWheelPainter(),
          ),
          // Center white dot with green inner
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1EF2A0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Top green pointer
          Positioned(
            top: 2,
            child: CustomPaint(
              size: const Size(20, 24),
              painter: _PointerPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpinWheelPainter extends CustomPainter {
  final List<Color> sectionColors = [
    const Color(0xFF26A675), // Green/Teal
    const Color(0xFF1976D2), // Blue
    const Color(0xFFF57C00), // Orange
    const Color(0xFF757575), // Grey
    const Color(0xFFD32F2F), // Red
    const Color(0xFF7B1FA2), // Purple
  ];

  final List<String> sectionTexts = [
    'Free\nDelivery',
    '10%\nOFF',
    '20%\nOFF',
    'Better\nLuck',
    'OFF\n5 EGP',
    'Surprise',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);
    final double sweepAngle = (2 * pi) / 6;

    // Background wheel base (light yellow border ring)
    final Paint borderRingPaint = Paint()
      ..color = const Color(0xFFD4C86A).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius + 3, borderRingPaint);

    // Draw Sections
    Rect rect = Rect.fromCircle(center: center, radius: radius);
    for (int i = 0; i < 6; i++) {
      // Rotate starting from top (startAngle = -pi/2 + sweepAngle/2)
      // Wait, let's align exactly: 
      // Top-right is Free Delivery (offset slightly by half sweep)
      final Paint paint = Paint()..color = sectionColors[i];
      final double startAngle = -pi / 2 + (i * sweepAngle);
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      // Draw text
      _drawText(canvas, size, i, startAngle, sweepAngle, radius);
    }
    
    // Draw center dark rim
    final Paint centerRimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, centerRimPaint);
  }

  void _drawText(Canvas canvas, Size size, int index, double startAngle, double sweepAngle, double radius) {
    final double textAngle = startAngle + (sweepAngle / 2);
    final double dx = radius + (radius * 0.6) * cos(textAngle);
    final double dy = radius + (radius * 0.6) * sin(textAngle);

    canvas.save();
    canvas.translate(dx, dy);
    // Rotate text to point outwards relative to center
    canvas.rotate(textAngle + pi / 2);

    final TextSpan span = TextSpan(
      text: sectionTexts[index],
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        height: 1.1,
      ),
    );

    final TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    tp.layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = const Color(0xFF1EF2A0);
    final Path path = Path();
    path.moveTo(size.width / 2, size.height); // bottom tip
    path.lineTo(0, 0); // top left
    path.lineTo(size.width, 0); // top right
    path.close();

    // Add subtle shadow
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.5), 2, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
