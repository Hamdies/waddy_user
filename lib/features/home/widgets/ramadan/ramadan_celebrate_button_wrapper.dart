import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Wraps content with bottom light string and Celebrate Ramadan button
class RamadanCelebrateButtonWrapper extends StatelessWidget {
  final Widget child;

  const RamadanCelebrateButtonWrapper({super.key, required this.child});

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
            final isLit = ctrl.isRamadanLightsOn;
            final progress = ctrl.ramadanLightProgress;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Wrapped child content
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 90,
                  ), // Reserved space for button
                  child: child,
                ),

                // Bottom light string overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 120, // Increased height for larger decorations
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _BottomLightStringPainter(
                        isLit: isLit,
                        progress: progress,
                      ),
                    ),
                  ),
                ),

                // Celebrate Ramadan Button - positioned below content
                Positioned(
                  right: 16,
                  bottom: 15,
                  child: _CelebrateRamadanButton(
                    isLit: isLit,
                    onTap: () => ctrl.celebrateRamadan(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BottomLightStringPainter extends CustomPainter {
  final bool isLit;
  final double progress;

  // --- Brand Palette ---
  static const Color colorDarkTeal = Color(0xFF134E4A);
  static const Color colorDeepTeal = Color(0xFF033e41);
  static const Color colorNeonGreen = Color(0xFF1EF2A0);
  static const Color colorLimeGreen = Color(0xFF09f69e);

  _BottomLightStringPainter({required this.isLit, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final anchors = _calculateAnchors(size);
    if (anchors.isEmpty) return;

    // Draw wire
    _drawWire(canvas, anchors);

    // Draw decorations
    _drawDecorations(canvas, anchors);
  }

  List<Offset> _calculateAnchors(Size size) {
    final List<Offset> anchors = [];
    final width = size.width;
    const bulbSpacing = 55.0; // Wider spacing for detailed items
    const yPos = 15.0;

    final numBulbs = (width / bulbSpacing).floor();
    for (int i = 0; i <= numBulbs; i++) {
      final x = 20.0 + (i * (width - 40) / numBulbs);
      // Gentle curve upwards at ends
      final y = yPos + sin(i * 0.7) * 4;
      anchors.add(Offset(x, y));
    }

    return anchors;
  }

  void _drawWire(Canvas canvas, List<Offset> anchors) {
    if (anchors.length < 2) return;

    final path = Path()..moveTo(anchors[0].dx, anchors[0].dy);

    for (int i = 1; i < anchors.length; i++) {
      final prev = anchors[i - 1];
      final curr = anchors[i];
      final controlX = (prev.dx + curr.dx) / 2;
      final controlY = (prev.dy + curr.dy) / 2 + 8; // Deep drape
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

    // Wire
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
    for (int i = 0; i < anchors.length; i++) {
      final anchor = anchors[i];
      final bulbThreshold = i / anchors.length;
      final isBulbLit = isLit && progress > bulbThreshold;

      // Alternate: Fanous -> Crescent -> Fanous
      if (i % 2 == 0) {
        _drawCurvedFanous(canvas, anchor, isBulbLit);
      } else {
        _drawCrescentMoon(canvas, anchor, isBulbLit);
      }
    }
  }

  // --- 1. Crescent Moon (Hilal) ---
  void _drawCrescentMoon(Canvas canvas, Offset anchor, bool isLit) {
    final centerX = anchor.dx;
    final startY = anchor.dy + 4;

    // Wire
    canvas.drawLine(
      anchor,
      Offset(centerX, startY),
      Paint()
        ..color = colorDarkTeal
        ..strokeWidth = 1.5,
    );

    final moonCenter = Offset(centerX, startY + 8);
    final radius = 9.0;

    // Glow
    if (isLit) {
      canvas.drawCircle(
        moonCenter,
        14,
        Paint()
          ..color = colorNeonGreen.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Shape
    final moonPath =
        Path()..addOval(Rect.fromCircle(center: moonCenter, radius: radius));
    final cutCircle =
        Path()..addOval(
          Rect.fromCircle(
            center: Offset(moonCenter.dx + 3, moonCenter.dy - 2),
            radius: radius * 0.85,
          ),
        );
    final crescentPath = Path.combine(
      PathOperation.difference,
      moonPath,
      cutCircle,
    );

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

    canvas.drawPath(crescentPath, paint);
    canvas.drawPath(
      crescentPath,
      Paint()
        ..color = colorDarkTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  // --- 2. Traditional Fanous ---
  void _drawCurvedFanous(Canvas canvas, Offset anchor, bool isLit) {
    final centerX = anchor.dx;
    final startY = anchor.dy + 2;

    if (isLit) {
      canvas.drawCircle(
        Offset(centerX, startY + 14),
        20,
        Paint()
          ..color = colorNeonGreen.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      );
    }

    final metalPaint =
        Paint()
          ..shader = LinearGradient(
            colors: [colorDarkTeal, colorDeepTeal],
          ).createShader(Rect.fromLTWH(centerX - 10, startY, 20, 30));

    // Dome
    final domePath = Path();
    domePath.moveTo(centerX - 4, startY + 4);
    domePath.quadraticBezierTo(centerX, startY, centerX + 4, startY + 4);
    domePath.lineTo(centerX + 7, startY + 8);
    domePath.lineTo(centerX - 7, startY + 8);
    domePath.close();
    canvas.drawPath(domePath, metalPaint);

    // Ring
    canvas.drawCircle(
      Offset(centerX, startY),
      2.0,
      Paint()
        ..color = colorDarkTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Body
    final bodyTop = startY + 8.0;
    final bodyBot = startY + 22.0;
    final glassPath = Path();
    glassPath.moveTo(centerX - 7, bodyTop);
    glassPath.cubicTo(
      centerX - 10,
      bodyTop + 5,
      centerX - 5,
      bodyBot - 2,
      centerX - 5,
      bodyBot,
    );
    glassPath.lineTo(centerX + 5, bodyBot);
    glassPath.cubicTo(
      centerX + 5,
      bodyBot - 2,
      centerX + 10,
      bodyTop + 5,
      centerX + 7,
      bodyTop,
    );
    glassPath.close();

    final glassPaint = Paint();
    if (isLit) {
      glassPaint.shader = RadialGradient(
        colors: [
          Colors.white,
          colorNeonGreen,
          colorNeonGreen.withValues(alpha: 0.5),
        ],
        stops: const [0.2, 0.6, 1.0],
      ).createShader(
        Rect.fromLTWH(centerX - 10, bodyTop, 20, bodyBot - bodyTop),
      );
    } else {
      glassPaint.color = colorDeepTeal.withValues(alpha: 0.7);
    }
    canvas.drawPath(glassPath, glassPaint);

    // Structure
    final structPaint =
        Paint()
          ..color = colorDarkTeal.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
    canvas.drawPath(glassPath, structPaint);
    canvas.drawLine(
      Offset(centerX, bodyTop),
      Offset(centerX, bodyBot),
      structPaint,
    );

    // Base
    final basePath = Path();
    basePath.moveTo(centerX - 5, bodyBot);
    basePath.lineTo(centerX + 5, bodyBot);
    basePath.lineTo(centerX + 3, bodyBot + 4);
    basePath.lineTo(centerX - 3, bodyBot + 4);
    basePath.close();
    canvas.drawPath(basePath, metalPaint);
    canvas.drawCircle(Offset(centerX, bodyBot + 5), 1.5, metalPaint);
  }

  @override
  bool shouldRepaint(_BottomLightStringPainter oldDelegate) =>
      oldDelegate.isLit != isLit || oldDelegate.progress != progress;
}

class _CelebrateRamadanButton extends StatefulWidget {
  final bool isLit;
  final VoidCallback onTap;

  const _CelebrateRamadanButton({required this.isLit, required this.onTap});

  @override
  State<_CelebrateRamadanButton> createState() =>
      _CelebrateRamadanButtonState();
}

class _CelebrateRamadanButtonState extends State<_CelebrateRamadanButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GestureDetector(
      onTapDown: (_) {
        _pressController.forward();
      },
      onTapUp: (_) {
        _pressController.reverse();
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () {
        _pressController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeMedium,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: widget.isLit ? Colors.white : primaryColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
            border: Border.all(
              color:
                  widget.isLit
                      ? primaryColor.withValues(alpha: 0.15)
                      : accentColor.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    widget.isLit
                        ? Colors.black.withValues(alpha: 0.06)
                        : primaryColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isLit
                    ? Icons.lightbulb_outline_rounded
                    : Icons.celebration_outlined,
                color: widget.isLit ? primaryColor : accentColor,
                size: 15,
              ),
              const SizedBox(width: 6),

              Text(
                widget.isLit ? 'turn_off'.tr : 'ramadan_kareem'.tr,
                style: waddyMedium.copyWith(
                  fontSize: 12,
                  color: widget.isLit ? primaryColor : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),

              if (!widget.isLit) ...[
                const SizedBox(width: 5),
                const Text('🌙', style: TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
