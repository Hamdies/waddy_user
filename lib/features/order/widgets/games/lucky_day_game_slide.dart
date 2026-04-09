import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/order/widgets/games/game_shared_widgets.dart';
import 'package:waddy_app/util/styles.dart';

// ─── Outcome enum ────────────────────────────────────────────────────────
enum _LuckyOutcome {
  freeDelivery,
  discount5,
  bonusXP,
  nothing;

  String get title {
    switch (this) {
      case freeDelivery:
        return 'free_delivery'.tr;
      case discount5:
        return '5_egp_off'.tr;
      case bonusXP:
        return 'bonus_xp'.tr;
      case nothing:
        return 'better_luck'.tr;
    }
  }

  String get subtitle {
    switch (this) {
      case freeDelivery:
        return 'on_your_next_order'.tr;
      case discount5:
        return 'on_your_next_order'.tr;
      case bonusXP:
        return 'added_to_your_account'.tr;
      case nothing:
        return 'your_food_is_on_its_way'.tr;
    }
  }

  IconData get icon {
    switch (this) {
      case freeDelivery:
        return Icons.local_shipping_rounded;
      case discount5:
        return Icons.discount_rounded;
      case bonusXP:
        return Icons.star_rounded;
      case nothing:
        return Icons.sentiment_neutral_rounded;
    }
  }

  bool get isWin => this != nothing;

  /// First try: guaranteed win.
  static _LuckyOutcome rollFirstTry(math.Random rng) {
    final double r = rng.nextDouble();
    if (r < 0.25) return freeDelivery;
    if (r < 0.60) return discount5;
    return bonusXP;
  }

  /// Second try: might lose.
  static _LuckyOutcome rollSecondTry(math.Random rng) {
    final double r = rng.nextDouble();
    if (r < 0.10) return freeDelivery;
    if (r < 0.25) return discount5;
    if (r < 0.45) return bonusXP;
    return nothing;
  }
}

// ─── Game state ──────────────────────────────────────────────────────────
enum _GameState { idle, flipping, revealed, exhausted }

// ─── Main widget ─────────────────────────────────────────────────────────
class LuckyDayGameSlide extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onDotTap;

  const LuckyDayGameSlide({
    super.key,
    required this.currentIndex,
    required this.onDotTap,
  });

  @override
  State<LuckyDayGameSlide> createState() => _LuckyDayGameSlideState();
}

class _LuckyDayGameSlideState extends State<LuckyDayGameSlide>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late final AnimationController _pulseController;
  late final AnimationController _glowController;
  late final AnimationController _shimmerController;
  late final AnimationController _winController;
  late final Animation<double> _flipAnimation;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _shimmerAnimation;
  late final Animation<double> _winBounceAnimation;
  final math.Random _rng = math.Random();

  _GameState _state = _GameState.idle;
  _LuckyOutcome? _outcome;
  int _tries = 0;
  static const int _maxTries = 2;

  // Confetti particles
  List<_ConfettiParticle>? _confetti;

  @override
  void initState() {
    super.initState();

    // Flip animation
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
    _flipController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _state =
              _tries >= _maxTries ? _GameState.exhausted : _GameState.revealed;
        });
        // Trigger win celebration
        if (_outcome != null && _outcome!.isWin) {
          _triggerWinCelebration();
        }
      }
    });

    // Pulse (breathing) animation for idle card
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Glow border animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Shimmer sweep animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Win bounce animation
    _winController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _winBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.05), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _winController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _flipController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _shimmerController.dispose();
    _winController.dispose();
    super.dispose();
  }

  void _triggerWinCelebration() {
    HapticFeedback.heavyImpact();
    _winController.forward(from: 0);

    // Generate confetti
    final particles = <_ConfettiParticle>[];
    for (int i = 0; i < 30; i++) {
      particles.add(_ConfettiParticle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * 0.3,
        vx: (_rng.nextDouble() - 0.5) * 3,
        vy: -(_rng.nextDouble() * 4 + 2),
        color: [
          const Color(0xFF1EF2A0),
          const Color(0xFFFFB100),
          Colors.white,
          const Color(0xFF00D4FF),
          const Color(0xFFFF6B6B),
        ][_rng.nextInt(5)],
        size: 3 + _rng.nextDouble() * 5,
        rotation: _rng.nextDouble() * math.pi * 2,
      ));
    }
    setState(() => _confetti = particles);

    // Clear confetti after animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _confetti = null);
    });
  }

  void _reveal() {
    if (_state == _GameState.flipping || _state == _GameState.exhausted) return;

    if (_state == _GameState.revealed) {
      _flipController.reverse().then((_) {
        if (mounted) {
          setState(() => _state = _GameState.idle);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _doFlip();
          });
        }
      });
      return;
    }

    _doFlip();
  }

  void _doFlip() {
    _tries++;
    _outcome = _tries == 1
        ? _LuckyOutcome.rollFirstTry(_rng)
        : _LuckyOutcome.rollSecondTry(_rng);

    setState(() => _state = _GameState.flipping);
    HapticFeedback.lightImpact();
    _flipController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).primaryColor;
    final Color accent = Theme.of(context).secondaryHeaderColor;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primary,
              mixColor(primary, Colors.black, 0.22),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated floating particles background
            CustomPaint(
              painter: _AnimatedParticlesPainter(
                accent: accent,
                progress: _glowAnimation.value,
              ),
              size: Size.infinite,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Banner ──
                  LuckySpinBanner(
                    label: 'is_it_your_lucky_day'.tr.toUpperCase(),
                    primaryColor: primary,
                    accentColor: accent,
                  ),
                  const SizedBox(height: 10),

                  // ── Flip card with glow ──
                  GestureDetector(
                    onTap: _state != _GameState.flipping &&
                            _state != _GameState.exhausted
                        ? _reveal
                        : null,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _flipAnimation,
                        _winBounceAnimation,
                        _glowAnimation,
                      ]),
                      builder: (context, child) {
                        final double angle = _flipAnimation.value;
                        final bool showBack = angle > math.pi / 2;
                        final double winScale =
                            _winController.isAnimating ? _winBounceAnimation.value : 1.0;

                        return Transform.scale(
                          scale: winScale,
                          child: SizedBox(
                            width: 180,
                            height: 130,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Radial glow behind card
                                if (_state == _GameState.idle ||
                                    _state == _GameState.flipping)
                                  Positioned.fill(
                                    child: Center(
                                      child: AnimatedBuilder(
                                        animation: _glowAnimation,
                                        builder: (context, _) {
                                          return Container(
                                            width: 200,
                                            height: 150,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: accent.withValues(
                                                      alpha: 0.15 +
                                                          _glowAnimation.value *
                                                              0.2),
                                                  blurRadius: 40 +
                                                      _glowAnimation.value * 20,
                                                  spreadRadius:
                                                      _glowAnimation.value * 8,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                // The card itself
                                Positioned.fill(
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..rotateY(angle),
                                    child: showBack
                                        ? Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..rotateY(math.pi),
                                            child:
                                                _buildBackFace(primary, accent),
                                          )
                                        : _buildFrontFace(primary, accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Tries indicator ──
                  Text(
                    '$_tries / $_maxTries',
                    style: robotoMedium.copyWith(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── CTA ──
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final bool shouldPulse =
                          _state == _GameState.idle ||
                          _state == _GameState.revealed;
                      return Transform.scale(
                        scale: shouldPulse ? _pulseAnimation.value : 1.0,
                        child: child,
                      );
                    },
                    child: ShowcaseCta(
                      label: _ctaLabel,
                      icon: _ctaIcon,
                      backgroundColor: accent,
                      foregroundColor: primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      onTap: _state != _GameState.flipping &&
                              _state != _GameState.exhausted
                          ? _reveal
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Dots ──
                  SlideDots(
                    currentIndex: widget.currentIndex,
                    onDotTap: widget.onDotTap,
                    activeColor: accent,
                    inactiveColor: Colors.white,
                  ),
                ],
              ),
            ),

            // ── Confetti overlay ──
            if (_confetti != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: _ConfettiOverlay(
                    particles: _confetti!,
                    accent: accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _ctaLabel {
    switch (_state) {
      case _GameState.idle:
        return 'reveal_your_luck'.tr.toUpperCase();
      case _GameState.flipping:
        return '...';
      case _GameState.revealed:
        return 'try_again'.tr.toUpperCase();
      case _GameState.exhausted:
        return 'come_back_next_order'.tr.toUpperCase();
    }
  }

  IconData? get _ctaIcon {
    switch (_state) {
      case _GameState.idle:
        return Icons.auto_awesome_rounded;
      case _GameState.revealed:
        return Icons.refresh_rounded;
      default:
        return null;
    }
  }

  Widget _buildFrontFace(Color primary, Color accent) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _shimmerAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _state == _GameState.idle ? _pulseAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  mixColor(primary, Colors.white, 0.14),
                  primary,
                  mixColor(primary, Colors.black, 0.12),
                ],
              ),
              border: Border.all(
                color: accent.withValues(
                    alpha: 0.4 + _glowAnimation.value * 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(
                      alpha: 0.15 + _glowAnimation.value * 0.25),
                  blurRadius: 30 + _glowAnimation.value * 15,
                  spreadRadius: _glowAnimation.value * 4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Shimmer sweep
                  Positioned.fill(
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment(_shimmerAnimation.value - 1, 0),
                          end: Alignment(_shimmerAnimation.value, 0),
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcATop,
                      child: Container(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                  ),
                  // Content
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Radial glow behind icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                accent.withValues(alpha: 0.25),
                                accent.withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                          child: Icon(
                            Icons.help_rounded,
                            size: 48,
                            color: accent.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'tap_to_reveal'.tr.toUpperCase(),
                          style: robotoBold.copyWith(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.82),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackFace(Color primary, Color accent) {
    final outcome = _outcome;
    if (outcome == null) return const SizedBox.shrink();

    final bool win = outcome.isWin;
    const Color gold = Color(0xFFFFB100);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: win
              ? [accent, mixColor(accent, primary, 0.4)]
              : [
                  mixColor(primary, Colors.black, 0.15),
                  mixColor(primary, Colors.black, 0.30),
                ],
        ),
        border: Border.all(
          color: win ? accent : Colors.white.withValues(alpha: 0.15),
          width: win ? 2.5 : 2,
        ),
        boxShadow: [
          if (win) ...[
            BoxShadow(
              color: accent.withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: gold.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with glow
            Container(
              width: 56,
              height: 56,
              decoration: win
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.15),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: Icon(
                outcome.icon,
                size: 36,
                color: win ? primary : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              outcome.title,
              textAlign: TextAlign.center,
              style: robotoBold.copyWith(
                fontSize: 17,
                color: win ? primary : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              outcome.subtitle,
              textAlign: TextAlign.center,
              style: robotoRegular.copyWith(
                fontSize: 11,
                color: win
                    ? primary.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
            if (win) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '+10 XP',
                  style: robotoBold.copyWith(fontSize: 11, color: gold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Confetti particle data ─────────────────────────────────────────────
class _ConfettiParticle {
  final double x, y, vx, vy, size, rotation;
  final Color color;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
  });
}

// ─── Confetti overlay widget ────────────────────────────────────────────
class _ConfettiOverlay extends StatefulWidget {
  final List<_ConfettiParticle> particles;
  final Color accent;

  const _ConfettiOverlay({required this.particles, required this.accent});

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ConfettiPainter(
            particles: widget.particles,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress;
    final double opacity = t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3);

    for (final p in particles) {
      final double px = (p.x + p.vx * t * 0.15) * size.width;
      final double py =
          (p.y + p.vy * t * 0.15 + 2.0 * t * t) * size.height * 0.5 +
              size.height * 0.3;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity * 0.85)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + t * 6);
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
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}

// ─── Background painter: animated floating particles ────────────────────
class _AnimatedParticlesPainter extends CustomPainter {
  final Color accent;
  final double progress;

  _AnimatedParticlesPainter({required this.accent, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);

    // Floating particles that move slightly with animation
    for (int i = 0; i < 25; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final r = 2 + rng.nextDouble() * 5;
      final offset = math.sin(progress * math.pi + i) * 4;

      final paint = Paint()
        ..color = accent.withValues(alpha: 0.04 + progress * 0.04);
      canvas.drawCircle(
        Offset(baseX + offset, baseY + offset * 0.5),
        r,
        paint,
      );
    }

    // Subtle diagonal lines
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    for (int i = 0; i < 8; i++) {
      final y = size.height * (i / 8);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y - 40),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedParticlesPainter old) =>
      old.progress != progress;
}
