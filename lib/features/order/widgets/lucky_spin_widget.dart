import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/util/styles.dart';

/// Zomato-style "Lucky Spin" wheel shown while waiting for an order.
class LuckySpinWidget extends StatefulWidget {
  final double height;
  const LuckySpinWidget({super.key, this.height = 280});

  @override
  State<LuckySpinWidget> createState() => _LuckySpinWidgetState();
}

class _LuckySpinWidgetState extends State<LuckySpinWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _currentAngle = 0;
  bool _isSpinning = false;
  bool _hasSpun = false;
  int? _winIndex;

  static const List<_Segment> _segments = [
    _Segment('Free\nDelivery', Color(0xFF1BA672), Icons.delivery_dining),
    _Segment('10%\nOFF', Color(0xFF1565C0), Icons.discount),
    _Segment('20%\nOFF', Color(0xFFEF6C00), Icons.local_offer),
    _Segment('Better\nLuck', Color(0xFF757575), Icons.sentiment_satisfied_alt),
    _Segment('5 EGP\nOFF', Color(0xFFC62828), Icons.money_off),
    _Segment('Surprise\n🎁', Color(0xFF7B1FA2), Icons.card_giftcard),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning || _hasSpun) return;
    setState(() => _isSpinning = true);

    final random = Random();
    final spins = 5 + random.nextInt(4); // 5-8 full rotations
    final winIdx = random.nextInt(_segments.length);
    final segAngle = 2 * pi / _segments.length;
    // Land on the center of winIdx segment (pointer at top = -π/2)
    final targetAngle = -(winIdx * segAngle + segAngle / 2) - pi / 2;
    final totalAngle = spins * 2 * pi + (targetAngle % (2 * pi));

    final animation = Tween<double>(
      begin: _currentAngle,
      end: _currentAngle + totalAngle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    animation.addListener(() {
      if (mounted) setState(() => _currentAngle = animation.value);
    });

    _controller.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _isSpinning = false;
          _hasSpun = true;
          _winIndex = winIdx;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final Color primary = Theme.of(context).primaryColor;
    const double wheelSize = 190;

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primary, primary.withValues(alpha: 0.85)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Subtle vertical stripes ────────────────────────────────
          ...List.generate(12, (i) => Positioned(
            left: (screenWidth / 12) * i + screenWidth / 24,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          )),

          // ── Main content ──────────────────────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 32),

              // Title banner with light dots
              _buildTitleBanner(),
              const SizedBox(height: 12),

              // Wheel + pointer
              SizedBox(
                width: wheelSize + 12,
                height: wheelSize + 12,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    Container(
                      width: wheelSize + 12,
                      height: wheelSize + 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),

                    // Spinning wheel
                    Transform.rotate(
                      angle: _currentAngle,
                      child: CustomPaint(
                        size: const Size(wheelSize, wheelSize),
                        painter: _WheelPainter(_segments),
                      ),
                    ),

                    // Center hub
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Color(0xFFE0E0E0)],
                        ),
                        border: Border.all(
                          color: const Color(0xFF1EF2A0),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),

                    // Top pointer (teardrop)
                    Positioned(
                      top: -2,
                      child: CustomPaint(
                        size: const Size(22, 20),
                        painter: _PointerPainter(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // SPIN button or result
              if (!_hasSpun)
                _buildSpinButton()
              else
                _buildResultBadge(),
            ],
          ),

          // ── Light dots around edges ────────────────────────────────
          ..._buildLightDots(screenWidth),
        ],
      ),
    );
  }

  Widget _buildTitleBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨ ', style: TextStyle(fontSize: 12)),
          Text(
            'lucky_spin'.tr.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const Text(' ✨', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSpinButton() {
    return GestureDetector(
      onTap: _spin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFFC107)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFC107).withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          _isSpinning ? '...' : 'SPIN',
          style: robotoBold.copyWith(
            fontSize: 16,
            color: const Color(0xFF5D4037),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildResultBadge() {
    if (_winIndex == null) return const SizedBox.shrink();
    final seg = _segments[_winIndex!];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(seg.icon, size: 16, color: seg.color),
          const SizedBox(width: 6),
          Text(
            seg.label.replaceAll('\n', ' '),
            style: robotoBold.copyWith(
              fontSize: 12,
              color: seg.color,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLightDots(double width) {
    final List<Widget> dots = [];
    // Top row of light dots
    for (int i = 0; i < 16; i++) {
      dots.add(Positioned(
        top: 24,
        left: (width / 17) * (i + 1),
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i % 2 == 0
                ? const Color(0xFFFFD54F).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.4),
            boxShadow: [
              if (i % 2 == 0)
                BoxShadow(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
            ],
          ),
        ),
      ));
    }
    return dots;
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _Segment {
  final String label;
  final Color color;
  final IconData icon;
  const _Segment(this.label, this.color, this.icon);
}

// ─── Wheel Painter ────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  final List<_Segment> segments;
  const _WheelPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segAngle = 2 * pi / segments.length;

    for (int i = 0; i < segments.length; i++) {
      final startAngle = i * segAngle - pi / 2;

      // Segment fill
      final paint = Paint()
        ..color = segments[i].color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segAngle,
        true,
        paint,
      );

      // Segment border
      final border = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segAngle,
        true,
        border,
      );

      // Segment text
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + segAngle / 2);

      final tp = TextPainter(
        text: TextSpan(
          text: segments[i].label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.2,
            shadows: [
              Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      tp.layout(maxWidth: 58);
      tp.paint(canvas, Offset(radius * 0.5 - tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Outer white ring
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, ring);

    // Inner accent ring
    final innerRing = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius * 0.3, innerRing);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Pointer Painter (teardrop pointing down) ────────────────────────────────

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1EF2A0)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..quadraticBezierTo(size.width / 2, 4, size.width, 0)
      ..close();

    // Shadow
    canvas.drawShadow(path, Colors.black, 3, true);
    canvas.drawPath(path, paint);

    // Highlight
    final highlight = Paint()
      ..color = const Color(0xFF1EF2A0).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(path, highlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
