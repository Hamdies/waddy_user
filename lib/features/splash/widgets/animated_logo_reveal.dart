import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedLogoReveal extends StatefulWidget {
  const AnimatedLogoReveal({Key? key}) : super(key: key);

  @override
  State<AnimatedLogoReveal> createState() => _AnimatedLogoRevealState();
}

class _AnimatedLogoRevealState extends State<AnimatedLogoReveal>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _backgroundController;
  late AnimationController _particleController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _iconConvergeAnimation;

  @override
  void initState() {
    super.initState();

    // Main logo animation controller - extended duration
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    );

    // Background gradient animation controller - extended duration
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    );

    // Particle animation controller - extended duration
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    );

    // Logo scale animation with smoother bounce effect
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    // Logo fade animation - smoother and longer
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOutCubic),
      ),
    );

    // Subtle rotation animation - smoother curve
    _rotationAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutQuart),
      ),
    );

    // Background gradient animation - smoother curve
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _backgroundController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Particle animation - smoother curve
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _particleController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Pulse animation for glow effect - gentler pulsing
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeInOutSine),
    );

    // Icon converge animation - smoother convergence with extended timing
    _iconConvergeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.95, curve: Curves.easeInOutQuart),
      ),
    );

    // Start animations with extended staggered timing
    _backgroundController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      _particleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      _mainController.forward();
    });

    // Repeat background and particle animations
    _backgroundController.repeat(reverse: true);
    _particleController.repeat();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _backgroundController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // Clean background without gradients
          Container(color: Colors.transparent),

          // Floating icons that orbit around logo and converge
          Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: Stack(
                children: List.generate(6, (index) {
                  final icons = [
                    Icons.restaurant,
                    Icons.delivery_dining,
                    Icons.shopping_cart,
                    Icons.favorite,
                    Icons.star,
                    Icons.local_offer,
                  ];

                  return AnimatedBuilder(
                    animation: Listenable.merge([
                      _particleAnimation,
                      _iconConvergeAnimation,
                    ]),
                    builder: (context, child) {
                      // Calculate orbit position
                      final angle =
                          (index * math.pi * 2 / 6) +
                          (_particleAnimation.value * math.pi * 2);
                      final orbitRadius = 120.0;
                      final orbitX = 200 + math.cos(angle) * orbitRadius;
                      final orbitY = 200 + math.sin(angle) * orbitRadius;

                      // Calculate center position (logo center)
                      final centerX = 200.0;
                      final centerY = 200.0;

                      // Interpolate between orbit and center based on converge animation
                      final currentX =
                          orbitX +
                          (centerX - orbitX) *
                              (1 - _iconConvergeAnimation.value);
                      final currentY =
                          orbitY +
                          (centerY - orbitY) *
                              (1 - _iconConvergeAnimation.value);

                      return Positioned(
                        left: currentX - 12,
                        top: currentY - 12,
                        child: AnimatedBuilder(
                          animation: _mainController,
                          builder: (context, child) {
                            if (_mainController.value < 0.3)
                              return const SizedBox.shrink();

                            // Scale down icons as they converge
                            final iconScale =
                                0.5 + (_iconConvergeAnimation.value * 0.5);
                            // Fade out icons as they reach center
                            final iconOpacity =
                                _iconConvergeAnimation.value * 0.8;

                            return Transform.scale(
                              scale: iconScale,
                              child: Transform.rotate(
                                angle: _particleAnimation.value * math.pi * 2,
                                child: Opacity(
                                  opacity: iconOpacity * _fadeAnimation.value,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.9),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.primaryColor.withOpacity(
                                            0.3,
                                          ),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      icons[index],
                                      size: 14,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ),

          // Main logo with animations
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _scaleAnimation,
                _fadeAnimation,
                _rotationAnimation,
                _pulseAnimation,
              ]),
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/image/logo_no_bg.png',
                          width: 160,
                          height: 160,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
