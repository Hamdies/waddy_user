import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';

class LetterDialogWidget extends StatefulWidget {
  const LetterDialogWidget({super.key});

  @override
  State<LetterDialogWidget> createState() => _LetterDialogWidgetState();
}

class _LetterDialogWidgetState extends State<LetterDialogWidget>
    with TickerProviderStateMixin {
  // ── Shake idle loop ──
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // ── "Tap to open" hint fade-in after 2nd shake ──
  late AnimationController _hintController;
  late Animation<double> _hintOpacity;
  int _shakeCount = 0;

  // ── Seal pulse glow ──
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  // ── Open transition ──
  late AnimationController _openController;
  late Animation<double> _envelopeFade;
  late Animation<double> _letterAppear;
  late Animation<Offset> _letterSlide;

  // ── Confetti burst on reveal ──
  late AnimationController _confettiController;
  late List<_ConfettiParticle> _particles;

  bool _isOpening = false;
  bool _showFullLetter = false;

  static const _flapHeight = 0.0;
  static const _paperColor = Color(0xFFFCF8F3);
  static const _paperDarker = Color(0xFFF0E8DD);
  static const _borderColor = Color(0xFFDDD4C8);

  @override
  void initState() {
    super.initState();

    // Shake
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 480),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.032), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.032, end: -0.032), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.032, end: 0.018), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.018, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    // Hint fade-in (appears after 2nd shake)
    _hintController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _hintOpacity = CurvedAnimation(parent: _hintController, curve: Curves.easeIn);

    // Seal pulse
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat(reverse: true);
    _pulseScale = Tween(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Open
    _openController = AnimationController(
      duration: const Duration(milliseconds: 560),
      vsync: this,
    );
    _envelopeFade = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _openController, curve: const Interval(0.0, 0.55, curve: Curves.easeIn)),
    );
    _letterAppear = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _openController, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );
    _letterSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _openController, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );

    _openController.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showFullLetter = true);
        _confettiController.forward();
      }
    });

    // Confetti
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _particles = List.generate(22, (_) => _ConfettiParticle());

    _startShakeLoop();
  }

  void _startShakeLoop() async {
    await Future.delayed(const Duration(milliseconds: 700));
    while (mounted && !_isOpening) {
      _shakeController.forward(from: 0);
      _shakeCount++;
      if (_shakeCount == 2 && mounted) {
        _hintController.forward();
      }
      await Future.delayed(const Duration(milliseconds: 2200));
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _hintController.dispose();
    _pulseController.dispose();
    _openController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _openEnvelope() {
    if (_isOpening || _showFullLetter) return;
    setState(() => _isOpening = true);
    _shakeController.stop();
    _pulseController.stop();
    _hintController.reverse();
    _openController.forward();
  }

  void _dismiss() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      child: GestureDetector(
        // Tap background to dismiss at any stage
        onTap: _dismiss,
        child: Center(
          child: _showFullLetter
              ? _buildLetterWithConfetti(context)
              : AnimatedBuilder(
                  animation: Listenable.merge([
                    _shakeController,
                    _openController,
                    _pulseController,
                    _hintOpacity,
                  ]),
                  builder: (context, _) {
                    if (!_isOpening) {
                      final sw = MediaQuery.of(context).size.width;
                      final envW = (sw - 48).clamp(0.0, 340.0);
                      final envH = envW * 0.59;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.rotate(
                            angle: _shakeAnimation.value,
                            child: GestureDetector(
                              onTap: _openEnvelope,
                              child: _buildEnvelopeCore(context, envW, envH),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FadeTransition(
                            opacity: _hintOpacity,
                            child: _buildTapHint(context),
                          ),
                        ],
                      );
                    }
                    return _buildOpeningSequence(context);
                  },
                ),
        ),
      ),
    );
  }

  // ── Tap-to-open hint ──

  Widget _buildTapHint(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, color: Colors.white.withValues(alpha: 0.85), size: 16),
          const SizedBox(width: 6),
          Text(
            'letter_tap_to_open'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Opening animation ──

  Widget _buildOpeningSequence(BuildContext context) {
    final envOpacity = _envelopeFade.value.clamp(0.0, 1.0);
    final letOpacity = _letterAppear.value.clamp(0.0, 1.0);
    final sw = MediaQuery.of(context).size.width;
    final envW = (sw - 48).clamp(0.0, 340.0);
    final envH = envW * 0.59;

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: envOpacity,
          child: Transform.scale(
            scale: 1 - (letOpacity * 0.05),
            child: _buildEnvelopeCore(context, envW, envH),
          ),
        ),
        if (letOpacity > 0)
          Opacity(
            opacity: letOpacity,
            child: SlideTransition(
              position: _letterSlide,
              child: Transform.scale(
                scale: 0.94 + (letOpacity * 0.06),
                child: _buildLetterCard(context),
              ),
            ),
          ),
      ],
    );
  }

  // ── Envelope core ──

  Widget _buildEnvelopeCore(BuildContext context, [double? envW, double? envH]) {
    final primaryColor = Theme.of(context).primaryColor;
    final dateStr = DateFormat('dd.MM.yy').format(DateTime.now());
    final sw = MediaQuery.of(context).size.width;
    final envelopeWidth = envW ?? (sw - 48).clamp(0.0, 340.0);
    final bodyHeight = envH ?? envelopeWidth * 0.59;

    return SizedBox(
      width: envelopeWidth,
      height: bodyHeight + _flapHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Flap
          Positioned(
            top: 0, left: 0, right: 0,
            child: CustomPaint(
              size: Size(envelopeWidth, _flapHeight),
              painter: _FlapPainter(color: _paperColor, borderColor: _borderColor, shadowColor: _paperDarker),
            ),
          ),

          // Body
          Positioned(
            top: _flapHeight - 2, left: 0, right: 0,
            child: Container(
              height: bodyHeight,
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
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),

          // Airmail stripes
          Positioned(
            top: _flapHeight - 1, left: 0, right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
              child: SizedBox(
                height: bodyHeight,
                width: envelopeWidth,
                child: CustomPaint(painter: _AirmailStripePainter()),
              ),
            ),
          ),

          // V-fold
          Positioned(
            top: _flapHeight - 1, left: 0, right: 0,
            child: SizedBox(
              height: bodyHeight,
              child: CustomPaint(painter: _VFoldPainter(color: _borderColor)),
            ),
          ),

          // To: Name
          Positioned(
            top: _flapHeight + 24, left: 18, right: 86,
            child: GetBuilder<ProfileController>(
              builder: (pc) {
                final name = pc.userInfoModel?.fName ?? 'friend'.tr;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'To'.tr}:',
                      style: TextStyle(
                        fontSize: 10,
                        color: primaryColor.withValues(alpha: 0.38),
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

          // Stamps
          Positioned(
            bottom: _flapHeight + 20, right: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stamp("assets/image/mail1.png", 0.05),
                const SizedBox(width: 3),
                _stamp("assets/image/mail2.png", -0.08),
              ],
            ),
          ),

          // Date + From
          Positioned(
            bottom: 18, left: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 9, color: primaryColor, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${'From'.tr}: ${'letter_love_team'.tr}',
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

          // Wax seal with pulse glow
          Positioned(
            top: _flapHeight - 22,
            left: envelopeWidth / 2 - 28,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow ring
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Opacity(
                      opacity: _isOpening ? 0 : _pulseOpacity.value,
                      child: Transform.scale(
                        scale: _isOpening ? 1.0 : _pulseScale.value,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withValues(alpha: 0.22),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Seal
                  Container(
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
                      border: Border.all(
                        color: Theme.of(context).secondaryHeaderColor,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        "assets/on_boarding/Asset 11.svg",
                        height: 22,
                        width: 22,
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).colorScheme.secondary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ],
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
      child: Image.asset(asset, height: 35, width: 35, fit: BoxFit.cover),
    );
  }

  // ── Confetti overlay ──

  Widget _buildLetterWithConfetti(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: () {}, // block dismiss tap from reaching background on letter
          child: _buildLetterCard(context),
        ),
        // Confetti burst — non-interactive overlay
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _confettiController,
            builder: (_, __) {
              if (_confettiController.value == 0) return const SizedBox.shrink();
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ConfettiPainter(
                  progress: _confettiController.value,
                  particles: _particles,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Full letter card ──

  Widget _buildLetterCard(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    // Fluid spacing: shrinks on short screens (iPhone SE ~667px), full on tall
    final sp = (screenH / 812).clamp(0.65, 1.0); // scale factor vs iPhone 14 Pro

    return GetBuilder<ProfileController>(
      builder: (pc) {
        final name = pc.userInfoModel?.fName ?? 'friend'.tr;

        return GestureDetector(
          onTap: () {},
          child: Container(
            key: const ValueKey('letter'),
            width: screenW * 0.88,
            constraints: BoxConstraints(
              maxHeight: screenH * 0.78,
              maxWidth: 420,
            ),
            margin: EdgeInsets.symmetric(horizontal: screenW * 0.06),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFCF8F3), Color(0xFFF5EDE0)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 40,
                  spreadRadius: 2,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Ruled lines
                  Positioned.fill(
                    child: CustomPaint(painter: _RuledLinePainter()),
                  ),
                  // Airmail band — 7px stripe + close button row, total 44px
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: SizedBox(
                      height: 44,
                      child: CustomPaint(painter: _AirmailTopBandPainter()),
                    ),
                  ),

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Close button sits inside the airmail band row
                      SizedBox(
                        height: 44,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: SizedBox(
                            width: 48,
                            height: 44,
                            child: IconButton(
                              onPressed: _dismiss,
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withValues(alpha: 0.75),
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),

                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(24, 4, 24, 24 * sp),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              // Logo
                              Image.asset(
                                'assets/image/waddy.png',
                                height: 48 * sp,
                                width: 48 * sp,
                              ),
                              SizedBox(height: 14 * sp),

                              // Salutation
                              Text(
                                '${'letter_welcome_title_emoji'.tr} $name',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                  letterSpacing: 0.1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 14 * sp),

                              // Divider
                              const Row(
                                children: [
                                  Expanded(child: Divider(color: _borderColor, thickness: 0.8)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Text('✉️', style: TextStyle(fontSize: 13)),
                                  ),
                                  Expanded(child: Divider(color: _borderColor, thickness: 0.8)),
                                ],
                              ),
                              SizedBox(height: 14 * sp),

                              // Body 1 — headline
                              Text(
                                'letter_body_1'.tr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.55,
                                  color: Color(0xFF2A2A2A),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 10 * sp),

                              // Body 2
                              Text(
                                'letter_body_2'.tr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.55,
                                  color: Color(0xFF3D3D3D),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 10 * sp),

                              // Body 3
                              Text(
                                'letter_body_3'.tr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.55,
                                  color: Color(0xFF3D3D3D),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 10 * sp),

                              // Highlight callout
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10 * sp,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF134E4A).withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF134E4A).withValues(alpha: 0.12),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'letter_body_highlight'.tr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.55,
                                    color: Color(0xFF134E4A),
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 24 * sp),

                              // Sign-off
                              Text(
                                '${'letter_with_love'.tr} ❤️ ,',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF555555),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'letter_love_team'.tr,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -0.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 20 * sp),

                              // CTA
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _dismiss,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF134E4A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  child: Text('letter_lets_go'.tr),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Custom Painters
// ═══════════════════════════════════════════════════════════

/// Envelope flap triangle
class _FlapPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final Color shadowColor;
  _FlapPainter({required this.color, required this.borderColor, required this.shadowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w / 2, h + 12)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, shadowColor],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
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

/// Airmail stripes along edges
class _AirmailStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const bw = 5.0;
    const sw = 6.0;
    const gap = 6.0;
    final red = Paint()..color = const Color(0xFFD94B4B).withValues(alpha: 0.5);
    final blue = Paint()..color = const Color(0xFF3B6BA5).withValues(alpha: 0.5);

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

    drawEdge(Rect.fromLTWH(0, h - bw, w, bw), true);
    drawEdge(Rect.fromLTWH(0, 0, bw, h), false);
    drawEdge(Rect.fromLTWH(w - bw, 0, bw, h), false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Airmail top band for the letter card header
class _AirmailTopBandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const h = 7.0;
    const sw = 8.0;
    const gap = 8.0;
    final red = Paint()..color = const Color(0xFFD94B4B).withValues(alpha: 0.55);
    final blue = Paint()..color = const Color(0xFF3B6BA5).withValues(alpha: 0.55);

    final clip = Rect.fromLTWH(0, 0, w, h);
    canvas.save();
    canvas.clipRect(clip);
    final count = (w / (sw + gap) * 2).ceil() + 4;
    for (int i = -2; i < count; i++) {
      final p = i.isEven ? red : blue;
      final o = i * (sw + gap);
      canvas.drawPath(
        Path()
          ..moveTo(o, 0)
          ..lineTo(o + sw, 0)
          ..lineTo(o + sw - h, h)
          ..lineTo(o - h, h)
          ..close(),
        p,
      );
    }
    canvas.restore();

    // Thin border under band
    canvas.drawLine(
      Offset(0, h),
      Offset(w, h),
      Paint()
        ..color = const Color(0xFFDDD4C8)
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// V-fold crease lines
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

/// Subtle horizontal ruled lines for the letter body
class _RuledLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDDD4C8).withValues(alpha: 0.35)
      ..strokeWidth = 0.5;
    const lineSpacing = 28.0;
    const startY = 120.0; // below header band
    var y = startY;
    while (y < size.height) {
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), paint);
      y += lineSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Confetti burst particle
class _ConfettiParticle {
  final double x;
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double rotationSpeed;

  _ConfettiParticle()
      : x = math.Random().nextDouble(),
        angle = (math.Random().nextDouble() - 0.5) * math.pi * 0.9,
        speed = 0.5 + math.Random().nextDouble() * 0.5,
        size = 5 + math.Random().nextDouble() * 5,
        color = [
          const Color(0xFF1EF2A0),
          const Color(0xFF134E4A),
          const Color(0xFFFFBE0B),
          const Color(0xFFFF6B6B),
          const Color(0xFF3B6BA5),
          Colors.white,
        ][math.Random().nextInt(6)],
        rotationSpeed = (math.Random().nextDouble() - 0.5) * 10;
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOut.transform(progress);
    for (final p in particles) {
      final x = size.width * p.x;
      final yStart = size.height * 0.45;
      final yEnd = yStart - size.height * 0.55 * p.speed;
      final y = yStart + (yEnd - yStart) * eased;
      final opacity = (1.0 - (progress * 1.2)).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * eased);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
