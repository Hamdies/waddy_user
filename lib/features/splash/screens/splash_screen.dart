import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  // Phase 3: Logo scale-out reveal (500ms, once)
  late AnimationController _revealController;
  late Animation<double> _logoScaleOut;
  late Animation<double> _logoFadeOut;
  late Animation<double> _bgFadeOut;

  // Bottom "product by" fade in
  late Animation<double> _bottomFadeIn;

  bool _readyToReveal = false;
  bool _revealing = false;

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
      width: 32,
      height: 32,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );

    _setupAnimations();
    _setupConnectivity();
    _loadData();
    _introController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/image/waddy.png'), context);
      precacheImage(const AssetImage('assets/image/hs.png'), context);
    });
  }

  void _setupAnimations() {
    // Phase 1: Intro scale in
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _scaleIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );
    _bottomFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_readyToReveal) {
          _startReveal();
        } else {
          _breatheController.repeat(reverse: true);
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

    // Phase 3: Logo scale-out reveal
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _logoScaleOut = Tween<double>(begin: 1.0, end: 25.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeIn),
    );

    _logoFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _bgFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.15, 0.7, curve: Curves.easeOut),
      ),
    );

    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Get.find<SplashController>().markAnimationComplete();
      }
    });
  }

  void _checkConfigReady() {
    if (_revealing) return;
    final splashController = Get.find<SplashController>();
    if (splashController.configLoaded && !_readyToReveal) {
      _readyToReveal = true;
      if (_introController.isCompleted) {
        _startReveal();
      }
    }
  }

  void _startReveal() {
    if (_revealing) return;
    _revealing = true;
    _breatheController.stop();
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
              duration: Duration(seconds: isConnected ? 3 : 6000),
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

    double logoScale;
    double masterOpacity;

    if (_revealing) {
      logoScale = introScale * _logoScaleOut.value;
      masterOpacity = _logoFadeOut.value.clamp(0.0, 1.0);
    } else {
      logoScale = introScale * breathe;
      masterOpacity = 1.0;
    }

    if (masterOpacity <= 0.0) return const SizedBox.shrink();

    Widget content = Transform.scale(
      scale: logoScale.clamp(0.0, 50.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // W logo
          SizedBox(
            width: 100,
            height: 100,
            child: _wImage,
          ),

          const SizedBox(height: 16),

          // App name
          const Text(
            'Waddi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );

    if (masterOpacity < 1.0) {
      content = Opacity(opacity: masterOpacity, child: content);
    }

    return content;
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
            color: Colors.white.withValues(alpha: 0.6),
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
