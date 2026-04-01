import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';

class LetterDialogWidget extends StatefulWidget {
  const LetterDialogWidget({super.key});

  @override
  State<LetterDialogWidget> createState() => _LetterDialogWidgetState();
}

class _LetterDialogWidgetState extends State<LetterDialogWidget>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Simple open animation
  late AnimationController _openController;
  late Animation<double> _envelopeFade;
  late Animation<double> _letterAppear;

  bool _isOpening = false;
  bool _showFullLetter = false;

  static const _envelopeWidth = 350.0;
  static const _bodyHeight = 200.0;
  static const _flapHeight = 0.0;
  static const _paperColor = Color(0xFFFCF8F3);
  static const _paperDarker = Color(0xFFF3EDE4);
  static const _borderColor = Color(0xFFDDD4C8);

  @override
  void initState() {
    super.initState();

    // Shake loop
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.035), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.035, end: -0.035), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.035, end: 0.02), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.02, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
    _startShakeLoop();

    // Open animation: envelope fades out while letter fades/scales in.
    _openController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _envelopeFade = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _openController,
        curve: Curves.easeIn,
      ),
    );

    _letterAppear = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _openController,
        curve: Curves.easeOut,
      ),
    );

    _openController.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showFullLetter = true);
      }
    });
  }

  void _startShakeLoop() async {
    await Future.delayed(const Duration(milliseconds: 700));
    while (mounted && !_isOpening) {
      _shakeController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 2200));
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _openController.dispose();
    super.dispose();
  }

  void _openEnvelope() {
    if (_isOpening || _showFullLetter) return;
    setState(() => _isOpening = true);
    _shakeController.stop();
    _openController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: GestureDetector(
        onTap: _showFullLetter ? () => Navigator.of(context).pop() : null,
        child: Center(
          child: _showFullLetter
              ? _buildLetterDialog(context)
              : AnimatedBuilder(
                  animation: Listenable.merge([
                    _shakeController,
                    _openController,
                  ]),
                  builder: (context, _) {
                    if (!_isOpening) {
                      // Idle envelope with shake
                      return Transform.rotate(
                        angle: _shakeAnimation.value,
                        child: _buildClosedEnvelope(context),
                      );
                    }
                    // Opening sequence
                    return _buildOpeningSequence(context);
                  },
                ),
        ),
      ),
    );
  }

  // ── Opening animation ──

  Widget _buildOpeningSequence(BuildContext context) {
    final envelopeOpacity = _envelopeFade.value.clamp(0.0, 1.0);
    final letterOpacity = _letterAppear.value.clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: envelopeOpacity,
          child: Transform.scale(
            scale: 1 - (letterOpacity * 0.06),
            child: _buildEnvelopeCore(context),
          ),
        ),
        if (letterOpacity > 0)
          Opacity(
            opacity: letterOpacity,
            child: Transform.scale(
              scale: 0.92 + (letterOpacity * 0.08),
              child: _buildLetterDialog(context),
            ),
          ),
      ],
    );
  }

  // ── Closed envelope (idle state) ──

  Widget _buildClosedEnvelope(BuildContext context) {
    return GestureDetector(
      onTap: _openEnvelope,
      child: _buildEnvelopeCore(context),
    );
  }

  Widget _buildEnvelopeCore(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final dateStr = DateFormat('dd.MM.yy').format(DateTime.now());

    return SizedBox(
      width: _envelopeWidth,
      height: _bodyHeight + _flapHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Flap (behind body when closed, rotates open) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(_envelopeWidth, _flapHeight),
              painter: _FlapPainter(
                color: _paperColor,
                borderColor: _borderColor,
                shadowColor: _paperDarker,
              ),
            ),
          ),

          // ── Main envelope body ──
          Positioned(
            top: _flapHeight - 2,
            left: 0,
            right: 0,
            child: Container(
              height: _bodyHeight,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_paperColor, _paperDarker],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
                border: Border.all(color: _borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),

          // ── Airmail stripes ──
          Positioned(
            top: _flapHeight - 1,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
              child: SizedBox(
                height: _bodyHeight,
                width: _envelopeWidth,
                child: CustomPaint(
                  painter: _AirmailStripePainter(),
                ),
              ),
            ),
          ),

          // ── Inner V-fold on body ──
          Positioned(
            top: _flapHeight - 1,
            left: 0,
            right: 0,
            child: SizedBox(
              height: _bodyHeight,
              child: CustomPaint(
                painter: _VFoldPainter(color: _borderColor),
              ),
            ),
          ),

          // ── To: Name ──
          Positioned(
            top: _flapHeight + 28,
            left: 22,
            right: 90,
            child: GetBuilder<ProfileController>(
              builder: (pc) {
                final name = pc.userInfoModel?.fName ?? 'Friend';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'To'.tr}:',
                      style: TextStyle(
                        fontSize: 10,
                        color: primaryColor.withValues(alpha: 0.35),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Stamps ──
          Positioned(
            bottom: _flapHeight + 24,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stamp("assets/image/mail1.png", 0.05),
                const SizedBox(width: 3),
                _stamp("assets/image/mail2.png", -0.08),
              ],
            ),
          ),

          // ── Date + From ──
          Positioned(
            bottom: 18,
            left: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 9,
                    color: primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${'From'.tr}: ${'Waddy Team'.tr}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // ── Wax seal ──
          Positioned(
            top: _flapHeight - 22,
            left: _envelopeWidth / 2 - 22,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor,
                    primaryColor.withValues(alpha: 0.85),
                  ],
                ),
                border: Border.all(color: Theme.of(context).secondaryHeaderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                  "assets/on_boarding/Asset 11.svg",
                  height: 22,
                  width: 22,
                  colorFilter:  ColorFilter.mode(
                    Theme.of(context).colorScheme.secondary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stamp(String asset, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.all(2),
      
        child: Image.asset(asset, height: 35, width: 35, fit: BoxFit.cover),
      ),
    );
  }

  // ── Full letter dialog ──

  Widget _buildLetterDialog(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final screenH = MediaQuery.of(context).size.height;

    return GetBuilder<ProfileController>(
      builder: (pc) {
        final name = pc.userInfoModel?.fName ?? 'friend';

        return GestureDetector(
          onTap: () {},
          child: Container(
            key: const ValueKey('letter'),
            width: MediaQuery.of(context).size.width * 0.88,
            constraints: BoxConstraints(
              maxHeight: screenH * 0.78,
              maxWidth: 420,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F6),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 36,
                  spreadRadius: 1,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.black.withValues(alpha: 0.3),
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 0, 26, 28),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/image/waddy.png',
                          height: 50,
                          width: 50,
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'Welcome👋, $name',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                            fontFamily: 'monospace',
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Waddy was built here — for Maadi.',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF1F1F1F),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Not for everyone. Just for this place.',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF1F1F1F),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'For your streets. Your places.\nYour people.',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF1F1F1F),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'With your support, we grow faster.\nEvery order means more than you think.',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF1F1F1F),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 56),
                        const Text(
                          'With love ❤️ ,',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1F1F1F),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Waddy Team',
                          style: TextStyle(
                            fontSize: 16,
                            height: 0.95,
                            fontWeight: FontWeight.w500,
                            color: primaryColor,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Custom Painters ──

/// Envelope flap triangle (point at bottom center)
class _FlapPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final Color shadowColor;

  _FlapPainter({
    required this.color,
    required this.borderColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 👇 هنا السر
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w / 2, h + 12) // 🔥 زودنا العمق
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, shadowColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, fillPaint);

    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _FlapPainter old) => false;
}

/// Airmail red/blue diagonal stripes along all four edges
class _AirmailStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const bw = 5.0; // border width
    const sw = 6.0; // stripe width
    const gap = 6.0; // gap between stripes

    final red = Paint()..color = const Color(0xFFD94B4B).withValues(alpha: 0.5);
    final blue =
        Paint()..color = const Color(0xFF3B6BA5).withValues(alpha: 0.5);

    void drawEdge(Rect clip, bool horizontal) {
      canvas.save();
      canvas.clipRect(clip);
      final len = horizontal ? w : h;
      final count = (len / (sw + gap) * 2).ceil() + 6;
      for (int i = -3; i < count; i++) {
        final p = i.isEven ? red : blue;
        final o = i * (sw + gap);
        if (horizontal) {
          canvas.drawPath(
            Path()
              ..moveTo(clip.left + o, clip.top)
              ..lineTo(clip.left + o + sw, clip.top)
              ..lineTo(clip.left + o + sw - bw, clip.bottom)
              ..lineTo(clip.left + o - bw, clip.bottom)
              ..close(),
            p,
          );
        } else {
          canvas.drawPath(
            Path()
              ..moveTo(clip.left, clip.top + o)
              ..lineTo(clip.left, clip.top + o + sw)
              ..lineTo(clip.right, clip.top + o + sw + bw)
              ..lineTo(clip.right, clip.top + o + bw)
              ..close(),
            p,
          );
        }
      }
      canvas.restore();
    }

    // Bottom
    drawEdge(Rect.fromLTWH(0, h - bw, w, bw), true);
    // Left
    drawEdge(Rect.fromLTWH(0, 0, bw, h), false);
    // Right
    drawEdge(Rect.fromLTWH(w - bw, 0, bw, h), false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Subtle V-fold lines from bottom corners to center of body
class _VFoldPainter extends CustomPainter {
  final Color color;
  _VFoldPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawLine(Offset(6, h - 6), Offset(w / 2, h * 0.20), paint);
    canvas.drawLine(Offset(w - 6, h - 6), Offset(w / 2, h * 0.20), paint);
  }

  @override
  bool shouldRepaint(covariant _VFoldPainter old) => old.color != color;
}
