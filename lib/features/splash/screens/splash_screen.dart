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
  StreamSubscription<List<ConnectivityResult>>? _onConnectivityChanged;

  // Brand-constant splash: matches the native launch screens on both
  // platforms (launch_background.xml / LaunchScreen.storyboard are the same
  // mint), so the native → Flutter handoff is invisible in either app theme.
  static const Color _mintField = Color(0xFF1EF2A0);
  static const Color _tealInk = Color(0xFF134E4A);

  static const double _logoSide = 100.0;
  // Shortest time the splash stays up when everything is ready instantly,
  // so fast launches read as a beat rather than a strobe.
  static const int _minBrandBeatMs = 500;

  // The breath loops from the first frame until the route helper asks for
  // the exit (playSplashExit) — the splash never sits on a dead frame, no
  // matter how long config or navigation prep takes.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  late final Animation<double> _breathScale;
  late final Animation<double> _exitFade;
  late final Animation<double> _exitScale;

  late final DateTime _shownAt;
  bool _configSignaled = false;
  bool _reduceMotion = false;

  late final Widget _logo;

  @override
  void initState() {
    super.initState();
    _shownAt = DateTime.now();

    _logo = Image.asset(
      'assets/image/waddy.png',
      width: _logoSide,
      height: _logoSide,
      fit: BoxFit.contain,
      color: _tealInk,
      gaplessPlayback: true,
    );

    _reduceMotion =
        WidgetsBinding.instance.accessibilityFeatures.disableAnimations;

    _breathScale = Tween(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOutSine));

    // Exit is a dissolve, not a throw: the mark grows slightly while fading
    // out, then the route pushes over a clean mint field.
    _exitFade = Tween(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _exit, curve: Curves.easeInOut));
    _exitScale = Tween(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _exit, curve: Curves.easeOutCubic));

    if (!_reduceMotion) {
      _breath.repeat(reverse: true);
    }

    _setupConnectivity();
    _loadData();

    // The route helper awaits this right before pushing the next screen —
    // after all its async prep — so the dissolve is always the final beat.
    Get.find<SplashController>().registerSplashExit(_playExit);
  }

  void _checkConfigReady() {
    if (_configSignaled || !mounted) return;
    final splashController = Get.find<SplashController>();
    if (!splashController.configLoaded) return;

    // Unlock navigation. The breath keeps looping while the route helper
    // does its prep (token refresh, favourites, deep-link resolution);
    // the exit plays only when it is about to push the next screen.
    _configSignaled = true;
    splashController.markAnimationComplete();
  }

  Future<void> _playExit() async {
    if (!mounted || _reduceMotion) return;

    final elapsedMs = DateTime.now().difference(_shownAt).inMilliseconds;
    final remainingMs = _minBrandBeatMs - elapsedMs;
    if (remainingMs > 0) {
      await Future.delayed(Duration(milliseconds: remainingMs));
    }
    if (!mounted) return;

    _breath.stop();
    try {
      await _exit.forward().orCancel;
    } on TickerCanceled {
      // Disposed mid-dissolve — navigation proceeds regardless.
    }
  }

  void _setupConnectivity() {
    bool firstTime = true;
    _onConnectivityChanged = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      bool isConnected =
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile);

      if (!firstTime && isConnected) {
        Get.find<SplashController>().getConfigData(
          notificationBody: widget.body,
        );
      }
      firstTime = false;
    });
  }

  void _loadData() {
    final splashController = Get.find<SplashController>();
    splashController.resetSplashState();
    splashController.initSharedData();
    if ((AuthHelper.isLoggedIn() || AuthHelper.isGuestLoggedIn()) &&
        splashController.cacheModule != null) {
      Get.find<CartController>().getCartDataOnline();
    }
    splashController.getConfigData(notificationBody: widget.body);
  }

  @override
  void dispose() {
    _onConnectivityChanged?.cancel();
    _breath.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AddressHelper.getUserAddressFromSharedPref() != null &&
        AddressHelper.getUserAddressFromSharedPref()!.zoneIds == null) {
      Get.find<AuthController>().clearSharedAddress();
    }

    return Scaffold(
      backgroundColor: _mintField,
      body: GetBuilder<SplashController>(
        builder: (splashController) {
          if (!splashController.hasConnection) {
            return NoInternetScreen(child: SplashScreen(body: widget.body));
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkConfigReady();
          });

          return Center(
            child: FadeTransition(
              opacity: _exitFade,
              child: ScaleTransition(
                scale: _exitScale,
                child: ScaleTransition(
                  scale: _breathScale,
                  child: SizedBox.square(dimension: _logoSide, child: _logo),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
