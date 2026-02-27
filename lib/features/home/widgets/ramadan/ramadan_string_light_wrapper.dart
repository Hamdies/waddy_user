import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';

enum WrapperPosition { top, middle, bottom }

class RamadanStringLightWrapper extends StatelessWidget {
  final Widget child;
  final WrapperPosition position;
  final bool showTopString;
  final bool showBottomString;
  final bool showLeftConnector;
  final bool showRightConnector;
  final bool alwaysOn;
  final Color? metalColor;
  final Color? metalShadeColor;
  final Color? lightColor;
  final Color? lightSecondaryColor;

  const RamadanStringLightWrapper({
    super.key,
    required this.child,
    this.position = WrapperPosition.middle,
    this.showTopString = true,
    this.showBottomString = true,
    this.showLeftConnector = false,
    this.showRightConnector = false,
    this.alwaysOn = false,
    this.metalColor,
    this.metalShadeColor,
    this.lightColor,
    this.lightSecondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      id: 'ramadan',
      builder: (controller) {
        if (!controller.showRamadanDecorations) {
          return child;
        }

        return GetBuilder<HomeController>(
          id: 'ramadan_lights',
          builder: (ctrl) {
            final isLit = alwaysOn ? true : ctrl.isRamadanLightsOn;
            final progress = alwaysOn ? 1.0 : ctrl.ramadanLightProgress;

            return LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    child,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _RamadanDecoPainter(
                            isLit: isLit,
                            progress: progress,
                            showTopString: showTopString,
                            showBottomString: showBottomString,
                            showLeftConnector: showLeftConnector,
                            showRightConnector: showRightConnector,
                            metalColor: metalColor,
                            metalShadeColor: metalShadeColor,
                            lightColor: lightColor,
                            lightSecondaryColor: lightSecondaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RamadanDecoPainter extends CustomPainter {
  final bool isLit;
  final double progress;
  final bool showTopString;
  final bool showBottomString;
  final bool showLeftConnector;
  final bool showRightConnector;

  // --- Brand Palette (defaults) ---
  static const Color _defDarkTeal = Color(0xFF134E4A);
  static const Color _defDeepTeal = Color(0xFF033e41);
  static const Color _defNeonGreen = Color(0xFF1EF2A0);
  static const Color _defLimeGreen = Color(0xFF09f69e);

  late final Color colorDarkTeal;
  late final Color colorDeepTeal;
  late final Color colorNeonGreen;
  late final Color colorLimeGreen;

  _RamadanDecoPainter({
    required this.isLit,
    required this.progress,
    required this.showTopString,
    required this.showBottomString,
    required this.showLeftConnector,
    required this.showRightConnector,
    Color? metalColor,
    Color? metalShadeColor,
    Color? lightColor,
    Color? lightSecondaryColor,
  }) {
    colorDarkTeal = metalColor ?? _defDarkTeal;
    colorDeepTeal = metalShadeColor ?? _defDeepTeal;
    colorNeonGreen = lightColor ?? _defNeonGreen;
    colorLimeGreen = lightSecondaryColor ?? _defLimeGreen;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Guard against invalid sizes to prevent assertion errors
    if (size.width <= 0 || size.height <= 0 || size.width.isNaN || size.height.isNaN) {
      return;
    }
    
    final anchors = _calculateAnchors(size);
    if (anchors.isEmpty) return;

    _drawWire(canvas, anchors);
    _drawDecorations(canvas, anchors);
  }

  List<Offset> _calculateAnchors(Size size) {
    final List<Offset> anchors = [];
    final width = size.width;
    final height = size.height;
    // Optimized spacing for better performance
    const itemSpacing = 60.0;

    // 1. Top String
    if (showTopString) {
      final topY = 12.0;
      final numItems = (width / itemSpacing).floor();
      for (int i = 0; i <= numItems; i++) {
        final x = 15.0 + (i * (width - 30) / numItems);
        // A graceful drape curve
        final y = topY + sin(i * 0.8) * 4;
        anchors.add(Offset(x, y));
      }
    }

    // 2. Right Connector
    if (showRightConnector && showTopString) {
      final startY = showTopString ? 15.0 : 0.0;
      final endY = height - (showBottomString ? 15.0 : 0.0);
      final numItems = ((endY - startY) / itemSpacing).floor();
      for (int i = 1; i <= numItems; i++) {
        final y = startY + (i * (endY - startY) / numItems);
        final x = width - 10 + sin(i * 0.5) * 2;
        anchors.add(Offset(x, y));
      }
    }

    // 3. Bottom String
    if (showBottomString) {
      final bottomY = height - 12.0;
      final numItems = (width / itemSpacing).floor();
      for (int i = numItems; i >= 0; i--) {
        final x = 15.0 + (i * (width - 30) / numItems);
        final y = bottomY + sin(i * 0.8) * 4;
        anchors.add(Offset(x, y));
      }
    }

    // 4. Left Connector
    if (showLeftConnector && showBottomString) {
      final startY = height - (showBottomString ? 15.0 : height);
      final endY = showTopString ? 15.0 : 0.0;
      final numItems = ((startY - endY) / itemSpacing).floor();
      for (int i = 1; i <= numItems; i++) {
        final y = startY - (i * (startY - endY) / numItems);
        final x = 10.0 + sin(i * 0.5) * 2;
        anchors.add(Offset(x, y));
      }
    }

    return anchors;
  }

  void _drawWire(Canvas canvas, List<Offset> anchors) {
    if (anchors.length < 2) return;

    final path = Path()..moveTo(anchors[0].dx, anchors[0].dy);

    for (int i = 1; i < anchors.length; i++) {
      final prev = anchors[i - 1];
      final curr = anchors[i];
      // Deep drape for a heavy, quality wire look
      final controlX = (prev.dx + curr.dx) / 2;
      final controlY = (prev.dy + curr.dy) / 2 + 8; 

      path.quadraticBezierTo(controlX, controlY, curr.dx, curr.dy);
    }

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Main Wire (Dark Teal)
    canvas.drawPath(
      path,
      Paint()
        ..color = colorDeepTeal
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawDecorations(Canvas canvas, List<Offset> anchors) {
    // Limit decorations for performance
    final maxDecorations = anchors.length > 12 ? 12 : anchors.length;
    final step = anchors.length > 12 ? (anchors.length / 12).floor() : 1;
    
    for (int i = 0; i < maxDecorations; i++) {
      final anchorIndex = i * step;
      if (anchorIndex >= anchors.length) break;
      
      final anchor = anchors[anchorIndex];
      final isItemLit = isLit;

      // Pattern: Fanous -> Crescent -> Fanous -> Crescent
      if (i % 2 == 0) {
        _drawCurvedFanous(canvas, anchor, isItemLit);
      } else {
        _drawCrescentMoon(canvas, anchor, isItemLit);
      }
    }
  }

  /// 1. The Crescent Moon (Hilal)
  /// Replaces the generic bulb/hexagon.
  void _drawCrescentMoon(Canvas canvas, Offset anchor, bool isLit) {
    final centerX = anchor.dx;
    final startY = anchor.dy + 4; // Hanging slightly lower than wire

    // Wire connecting to moon
    canvas.drawLine(
      anchor,
      Offset(centerX, startY),
      Paint()..color = colorDarkTeal..strokeWidth = 1.2,
    );

    final moonCenter = Offset(centerX, startY + 7);
    final radius = 8.0;

    // Simplified glow for performance
    if (isLit) {
      canvas.drawCircle(
        moonCenter,
        12,
        Paint()
          ..color = colorNeonGreen.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Draw Crescent Shape
    final moonPath = Path();
    // Outer circle
    moonPath.addOval(Rect.fromCircle(center: moonCenter, radius: radius));
    // Inner circle (subtraction to create crescent)
    // Shifted slightly up and right to tilt the crescent
    final cutCircle = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(moonCenter.dx + 3, moonCenter.dy - 2), 
        radius: radius * 0.85
      ));
    
    final crescentPath = Path.combine(PathOperation.difference, moonPath, cutCircle);

    // Fill
    final paint = Paint();
    if (isLit) {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, colorNeonGreen, colorLimeGreen],
      ).createShader(Rect.fromCircle(center: moonCenter, radius: radius));
    } else {
      paint.color = colorDeepTeal;
    }
    
    // Draw body
    canvas.drawPath(crescentPath, paint);
    
    // Outline
    canvas.drawPath(
      crescentPath, 
      Paint()..color = colorDarkTeal..style = PaintingStyle.stroke..strokeWidth = 1
    );
    
    // Tiny star hanging from the top tip of the crescent (optional detail)
    if (isLit) {
       canvas.drawCircle(Offset(centerX - 5, startY + 3), 1.5, Paint()..color = Colors.white);
    }
  }

  /// 2. The Traditional Fanous
  /// Replaces the hexagon/diamond. Curvier, classic look.
  void _drawCurvedFanous(Canvas canvas, Offset anchor, bool isLit) {
    final centerX = anchor.dx;
    final startY = anchor.dy + 2;

    // -- Simplified Glow for performance --
    if (isLit) {
      canvas.drawCircle(
        Offset(centerX, startY + 12),
        16,
        Paint()
          ..color = colorNeonGreen.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // -- Metal Shader (Dark Teal) --
    final metalShader = LinearGradient(
      colors: [colorDarkTeal, colorDeepTeal],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(centerX - 10, startY, 20, 30));

    final metalPaint = Paint()..shader = metalShader;

    // -- Top Dome --
    final domePath = Path();
    domePath.moveTo(centerX - 4, startY + 4); // top narrow
    domePath.quadraticBezierTo(centerX, startY, centerX + 4, startY + 4);
    domePath.lineTo(centerX + 7, startY + 8); // flares out
    domePath.lineTo(centerX - 7, startY + 8);
    domePath.close();
    canvas.drawPath(domePath, metalPaint);

    // Ring handle
    canvas.drawCircle(Offset(centerX, startY), 2.0, Paint()..color = colorDarkTeal..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // -- Glass Body (The light source) --
    // Traditional "swelling" shape (Fatimid style)
    final bodyTop = startY + 8.0;
    final bodyBot = startY + 22.0;
    
    final glassPath = Path();
    glassPath.moveTo(centerX - 7, bodyTop);
    // Curve out then in
    glassPath.cubicTo(
      centerX - 10, bodyTop + 5, // control point 1 (bulge out)
      centerX - 5, bodyBot - 2,  // control point 2 (taper in)
      centerX - 5, bodyBot       // end point
    );
    glassPath.lineTo(centerX + 5, bodyBot);
    glassPath.cubicTo(
      centerX + 5, bodyBot - 2, 
      centerX + 10, bodyTop + 5, 
      centerX + 7, bodyTop
    );
    glassPath.close();

    final glassPaint = Paint();
    if (isLit) {
      glassPaint.shader = RadialGradient(
        colors: [Colors.white, colorNeonGreen, colorNeonGreen.withValues(alpha: 0.5)],
        stops: const [0.2, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(centerX - 10, bodyTop, 20, bodyBot - bodyTop));
    } else {
      glassPaint.color = colorDeepTeal.withValues(alpha: 0.7);
    }
    canvas.drawPath(glassPath, glassPaint);

    // -- Simplified Metal Structure for performance --
    final structPaint = Paint()
      ..color = colorDarkTeal.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    
    canvas.drawPath(glassPath, structPaint);

    // -- Bottom Base --
    final basePath = Path();
    basePath.moveTo(centerX - 4, bodyBot);
    basePath.lineTo(centerX + 4, bodyBot);
    basePath.lineTo(centerX + 2, bodyBot + 3);
    basePath.lineTo(centerX - 2, bodyBot + 3);
    basePath.close();
    canvas.drawPath(basePath, metalPaint);
  }

  @override
  bool shouldRepaint(_RamadanDecoPainter oldDelegate) =>
      oldDelegate.isLit != isLit ||
      oldDelegate.showTopString != showTopString ||
      oldDelegate.showBottomString != showBottomString;
}