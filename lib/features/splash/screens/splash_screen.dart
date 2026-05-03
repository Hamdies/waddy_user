import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/common/widgets/no_internet_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  final NotificationBodyModel? body;
  const SplashScreen({super.key, required this.body});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _globalKey = GlobalKey();
  StreamSubscription<List<ConnectivityResult>>? _onConnectivityChanged;

  static const _brandTeal = Color(0xFF134E4A);

  // Phase 1: Scale in (720ms, once)
  late AnimationController _introController;
  late Animation<double> _scaleIn;

  // Phase 2: Breathe while waiting (loops)
  late AnimationController _breatheController;
  late Animation<double> _breatheScale;

  // Phase 3: Logo scale-out reveal (700ms, once)
  late AnimationController _revealController;
  late Animation<double> _logoScaleOut;
  late Animation<double> _logoFadeOut;
  late Animation<double> _textFadeOut;
  late Animation<double> _bgFadeOut;

  // Bottom "product by" fade in
  late Animation<double> _bottomFadeIn;

  // Staggered text entrance
  late Animation<double> _nameFadeIn;
  late Animation<Offset> _nameSlide;
  late Animation<double> _taglineFadeIn;
  late Animation<Offset> _taglineSlide;

  // Ambient particles (first launch only)
  late AnimationController _particleController;

  bool _readyToReveal = false;
  bool _revealing = false;
  bool _reduceMotion = false;
  bool _skipIntro = false;

  late final Widget _wImage;
  late final Widget _hsImage;

  @override
  void initState() {
    super.initState();

    _wImage = Image.asset(
      'assets/image/waddy.png',
      width: 100,
      height: 100,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    _hsImage = Image.asset(
      'assets/image/hs.png',
      width: 24,
      height: 24,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );

    _reduceMotion = WidgetsBinding.instance.accessibilityFeatures.disableAnimations;
    final prefs = Get.find<SharedPreferences>();
    _skipIntro = prefs.getBool(AppConstants.splashAnimationShown) ?? false;

    _setupAnimations();
    _setupConnectivity();
    _loadData();

    if (!_skipIntro) {
      prefs.setBool(AppConstants.splashAnimationShown, true);
    }
    if (_reduceMotion) {
      _introController.value = 1.0;
    } else if (_skipIntro) {
      // Returning user: skip intro animation, go straight to breathe
      _introController.value = 1.0;
      _breatheController.repeat(reverse: true);
    } else {
      _introController.forward();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/image/waddy.png'), context);
      precacheImage(const AssetImage('assets/image/hs.png'), context);
    });
  }

  void _setupAnimations() {
    // Phase 1: Intro — instant logo appearance, X-style
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleIn = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutQuart),
    );
    _bottomFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    // Name and tagline simply fade in with the logo, no slide
    _nameFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );
    _nameSlide = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_introController);
    _taglineFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_introController);
    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_reduceMotion) return;
        if (_readyToReveal) {
          _startReveal();
        } else {
          _breatheController.repeat(reverse: true);
          if (!_skipIntro) _particleController.repeat();
        }
      }
    });

    // Phase 2: Subtle breathe while waiting for config
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _breatheScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    // Phase 3: Logo scale-out reveal — X/Twitter style: fast punch outward
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    // Aggressive accelerating zoom — shoots outward like X
    _logoScaleOut = Tween<double>(begin: 1.0, end: 30.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeInQuint),
    );

    // Logo fades in the second half of the zoom
    _logoFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeIn),
      ),
    );

    // Text disappears immediately — gone before you notice
    _textFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // Background cuts away immediately at reveal start
    _bgFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Get.find<SplashController>().markAnimationComplete();
      }
    });

    // Ambient particles for first-launch delight
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  void _checkConfigReady() {
    if (_revealing) return;
    final splashController = Get.find<SplashController>();
    if (splashController.configLoaded && !_readyToReveal) {
      _readyToReveal = true;
      if (_reduceMotion) {
        splashController.markAnimationComplete();
      } else if (_introController.isCompleted) {
        _startReveal();
      }
    }
  }

  void _startReveal() {
    if (_revealing) return;
    _revealing = true;
    _breatheController.stop();
    _particleController.stop();
    _revealController.forward();
  }

  void _setupConnectivity() {
    bool firstTime = true;
    _onConnectivityChanged = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> result) {
        bool isConnected = result.contains(ConnectivityResult.wifi) ||
            result.contains(ConnectivityResult.mobile);

        if (!firstTime) {
          if (isConnected) {
            ScaffoldMessenger.of(Get.context!).hideCurrentSnackBar();
          }
          ScaffoldMessenger.of(Get.context!).showSnackBar(
            SnackBar(
              backgroundColor: isConnected ? Colors.green : Colors.red,
              duration: Duration(seconds: isConnected ? 3 : 86400),
              content: Text(
                isConnected ? 'connected'.tr : 'no_connection'.tr,
                textAlign: TextAlign.center,
              ),
            ),
          );
          if (isConnected) {
            Get.find<SplashController>().getConfigData(
              notificationBody: widget.body,
            );
          }
        }
        firstTime = false;
      },
    );
  }

  void _loadData() {
    final splashController = Get.find<SplashController>();
    splashController.resetSplashState();
    splashController.initSharedData();
    if (AuthHelper.isLoggedIn() &&
        splashController.cacheModule != null) {
      Get.find<CartController>().getCartDataOnline();
    }
    splashController.getConfigData(notificationBody: widget.body);
  }

  @override
  void dispose() {
    _onConnectivityChanged?.cancel();
    _introController.dispose();
    _breatheController.dispose();
    _revealController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AddressHelper.getUserAddressFromSharedPref() != null &&
        AddressHelper.getUserAddressFromSharedPref()!.zoneIds == null) {
      Get.find<AuthController>().clearSharedAddress();
    }

    final bgColor = Theme.of(context).secondaryHeaderColor;

    return Scaffold(
      key: _globalKey,
      backgroundColor: bgColor,
      body: GetBuilder<SplashController>(
        builder: (splashController) {
          if (!splashController.hasConnection) {
            return NoInternetScreen(
                child: SplashScreen(body: widget.body));
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkConfigReady();
          });

          return Stack(
            children: [
              // Layer 1: Final background
              ColoredBox(color: bgColor, child: const SizedBox.expand()),

              // Layer 2: Teal background (fades out during reveal)
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _revealController,
                  builder: (context, child) {
                    if (!_revealing) return child!;
                    final opacity = _bgFadeOut.value;
                    if (opacity <= 0.0) return const SizedBox.shrink();
                    return Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: child,
                    );
                  },
                  child: const ColoredBox(
                    color: _brandTeal,
                    child: SizedBox.expand(),
                  ),
                ),
              ),

              // Layer 2.5: Ambient particles (first launch only)
              if (!_reduceMotion && !_skipIntro)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _particleController,
                      builder: (context, _) {
                        if (!_breatheController.isAnimating || _revealing) {
                          return const SizedBox.shrink();
                        }
                        return CustomPaint(
                          painter: _ParticlePainter(t: _particleController.value),
                        );
                      },
                    ),
                  ),
                ),

              // Layer 3: Center logo + app name
              Center(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _introController,
                      _breatheController,
                      _revealController,
                    ]),
                    builder: (context, _) => _buildCenterContent(),
                  ),
                ),
              ),

              // Layer 4: Bottom "A product by Hamdies Solutions"
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _introController,
                      _revealController,
                    ]),
                    builder: (context, _) => _buildBottomBranding(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCenterContent() {
    final double introScale = _scaleIn.value;
    final double breathe = _breatheController.isAnimating
        ? _breatheScale.value
        : 1.0;

    // Base scale: intro scale × breathe (or × logo bloom during reveal)
    final double logoScale = _revealing
        ? introScale * _logoScaleOut.value
        : introScale * breathe;

    // Logo fades as it blooms; text fades independently and earlier
    final double logoOpacity = _revealing
        ? _logoFadeOut.value.clamp(0.0, 1.0)
        : 1.0;
    final double textOpacity = _revealing
        ? _textFadeOut.value.clamp(0.0, 1.0)
        : 1.0;

    // Once both are fully transparent, remove from tree
    if (logoOpacity <= 0.0 && textOpacity <= 0.0) return const SizedBox.shrink();

    Widget logo = Transform.scale(
      scale: logoScale.clamp(0.0, 50.0),
      child: SizedBox(
        width: 100,
        height: 100,
        child: _wImage,
      ),
    );
    if (logoOpacity < 1.0) {
      logo = Opacity(opacity: logoOpacity, child: logo);
    }

    Widget nameWidget = SlideTransition(
      position: _nameSlide,
      child: FadeTransition(
        opacity: _nameFadeIn,
        child: const Text(
          'Waddi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );

    Widget taglineWidget = SlideTransition(
      position: _taglineSlide,
      child: FadeTransition(
        opacity: _taglineFadeIn,
        child: const Text(
          'Fresh groceries, delivered',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );

    Widget textGroup = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        nameWidget,
        const SizedBox(height: 8),
        taglineWidget,
      ],
    );
    if (textOpacity < 1.0) {
      textGroup = Opacity(opacity: textOpacity, child: textGroup);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        textGroup,
      ],
    );
  }

  Widget _buildBottomBranding() {
    final double fadeIn = _bottomFadeIn.value;

    double opacity;
    if (_revealing) {
      opacity = (fadeIn * _logoFadeOut.value).clamp(0.0, 1.0);
    } else {
      opacity = fadeIn.clamp(0.0, 1.0);
    }

    if (opacity <= 0.0) return const SizedBox.shrink();

    Widget branding = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'A product by',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: _hsImage,
            ),
            const SizedBox(width: 8),
            const Text(
              'Hamdies Solutions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );

    if (opacity < 1.0) {
      branding = Opacity(opacity: opacity, child: branding);
    }

    return branding;
  }
}

class _ParticleData {
  final double phase;
  final double startAngle;
  final double orbitRadius;
  final double size;

  const _ParticleData({
    required this.phase,
    required this.startAngle,
    required this.orbitRadius,
    required this.size,
  });
}

class _ParticlePainter extends CustomPainter {
  final double t;

  _ParticlePainter({required this.t});

  static const _particles = [
    _ParticleData(phase: 0.00, startAngle: 0.52, orbitRadius: 55, size: 2.5),
    _ParticleData(phase: 0.17, startAngle: 1.57, orbitRadius: 68, size: 2.0),
    _ParticleData(phase: 0.33, startAngle: 2.79, orbitRadius: 48, size: 3.0),
    _ParticleData(phase: 0.50, startAngle: 3.67, orbitRadius: 62, size: 2.0),
    _ParticleData(phase: 0.66, startAngle: 4.71, orbitRadius: 52, size: 2.5),
    _ParticleData(phase: 0.83, startAngle: 5.76, orbitRadius: 72, size: 2.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Position relative to where the logo lives (above the text)
    final cy = size.height / 2 - 40;

    for (final p in _particles) {
      final animT = (t + p.phase) % 1.0;
      // Fade in and out smoothly via a sine curve over one full cycle
      final opacity = math.sin(animT * math.pi) * 0.45;
      if (opacity <= 0.01) continue;

      // Drift upward; sway gently side to side
      final yDrift = -70.0 * animT;
      final xDrift = math.sin(p.startAngle + animT * math.pi) * 12.0;

      // Spawn from just outside the logo boundary
      final startX = cx + math.cos(p.startAngle) * p.orbitRadius * 0.4;
      final startY = cy + math.sin(p.startAngle) * p.orbitRadius * 0.4;

      canvas.drawCircle(
        Offset(startX + xDrift, startY + yDrift),
        p.size,
        Paint()
          ..color = Colors.white.withOpacity(opacity.clamp(0.0, 0.45))
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
