import 'dart:async';
import 'dart:io';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/auth/widgets/sign_in/sign_in_view.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SignInScreen extends StatefulWidget {
  final bool exitFromApp;
  final bool backFromThis;
  final bool fromNotification;
  final bool fromResetPassword;
  const SignInScreen({
    super.key,
    required this.exitFromApp,
    required this.backFromThis,
    this.fromNotification = false,
    this.fromResetPassword = false,
  });

  @override
  SignInScreenState createState() => SignInScreenState();
}

class SignInScreenState extends State<SignInScreen>
    with TickerProviderStateMixin {
  bool _canExit = GetPlatform.isWeb ? true : false;
  late AnimationController _animationController;
  late AnimationController _particleController;
  late AnimationController _slideController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _particleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _particleController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController.forward();

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.linear),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _particleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Widget _buildFloatingParticles() {
    // Icons representing grocery, food, shopping, pharmacy, and delivery
    final List<IconData> businessIcons = [
      Icons.shopping_cart,
      Icons.local_grocery_store,
      Icons.restaurant,
      Icons.local_pharmacy,
      Icons.delivery_dining,
      Icons.shopping_bag,
      Icons.fastfood,
      Icons.medical_services,
    ];

    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        return Stack(
          children: List.generate(8, (index) {
            final double progress =
                (_particleAnimation.value + index * 0.125) % 1.0;
            final double size = 20.0 + (index % 3) * 8.0;
            final double opacity = 0.15 + (index % 4) * 0.1;
            final double speed = 0.4 + (index % 3) * 0.25;
            final double rotationSpeed = 0.5 + (index % 2) * 0.3;

            return Positioned(
              left:
                  (MediaQuery.of(context).size.width * 0.1) +
                  (index % 3) * (MediaQuery.of(context).size.width * 0.3) +
                  (progress * 60 - 30),
              top: MediaQuery.of(context).size.height * progress * speed,
              child: Transform.rotate(
                angle: progress * rotationSpeed * 6.28, // Full rotation
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF0F766E).withOpacity(opacity * 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    businessIcons[index],
                    size: size * 0.6,
                    color: Color(0xFF0F766E).withOpacity(opacity + 0.3),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildHeaderSection() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Animated App Logo
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_scaleAnimation.value - 1.0) * 0.1,
                  child: Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Color(
                            0xFF0F766E,
                          ).withOpacity(0.3 * _opacityAnimation.value),
                          blurRadius: 15 + (_scaleAnimation.value * 5),
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      "assets/image/logo_no_bg.png",
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Welcome Text

            // Login Title
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) async {
        if (widget.fromNotification || widget.fromResetPassword) {
          Navigator.pushNamed(context, RouteHelper.getInitialRoute());
        } else if (widget.exitFromApp) {
          if (_canExit) {
            if (GetPlatform.isAndroid) {
              SystemNavigator.pop();
            } else if (GetPlatform.isIOS) {
              exit(0);
            } else {
              Navigator.pushNamed(context, RouteHelper.getInitialRoute());
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'back_press_again_to_exit'.tr,
                  style: const TextStyle(color: Colors.white),
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
                margin: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              ),
            );
            _canExit = true;
            Timer(const Duration(seconds: 2), () {
              _canExit = false;
            });
          }
        } else {
          if (Get.find<AuthController>().isOtpViewEnable) {
            Get.find<AuthController>().enableOtpView(enable: false);
          } else {
            Get.back();
          }
        }
      },
      child: Scaffold(
        backgroundColor:
            ResponsiveHelper.isDesktop(context)
                ? Colors.transparent
                : Theme.of(context).cardColor,
        appBar: ResponsiveHelper.isDesktop(context) ? null : null,
        endDrawer: const MenuDrawer(),
        endDrawerEnableOpenDragGesture: false,

        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFEFEFE), Color(0xFFF8FAFC)],
            ),
          ),
          child: Stack(
            children: [
              // Floating particles animation
              _buildFloatingParticles(),
              // Animated gradient circles in top right
              Positioned(
                top: -30,
                right: -30,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationAnimation.value * 3.14159,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.15 * _opacityAnimation.value),
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.05 * _opacityAnimation.value),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: -_rotationAnimation.value * 3.14159 * 0.7,
                      child: Transform.scale(
                        scale: 1.0 + (_scaleAnimation.value - 1.0) * 0.5,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.12 * _opacityAnimation.value),
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.04 * _opacityAnimation.value),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Additional animated gradient circles at top right
              Positioned(
                top: 40,
                right: -40,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationAnimation.value * 3.14159 * 1.5,
                      child: Transform.scale(
                        scale: 0.9 + (_scaleAnimation.value - 1.0) * 0.3,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.10 * _opacityAnimation.value),
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.03 * _opacityAnimation.value),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Animated gradient circles at middle left
              Positioned(
                top: MediaQuery.of(context).size.height * 0.4,
                left: -50,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: -_rotationAnimation.value * 3.14159 * 0.5,
                      child: Transform.scale(
                        scale: 1.1 + (_scaleAnimation.value - 1.0) * 0.4,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.13 * _opacityAnimation.value),
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.04 * _opacityAnimation.value),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.45,
                left: -20,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationAnimation.value * 3.14159 * 2.0,
                      child: Transform.scale(
                        scale: 0.8 + (_scaleAnimation.value - 1.0) * 0.6,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(
                                  0.1 * _opacityAnimation.value,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.4 * _opacityAnimation.value),
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.2 * _opacityAnimation.value),
                                Colors.teal.withOpacity(
                                  0.015 * _opacityAnimation.value,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: -MediaQuery.of(context).size.height * 0.70,
                right: -20,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: -_rotationAnimation.value * 3.14159 * 1.2,
                      child: Transform.scale(
                        scale: 1.0 + (_scaleAnimation.value - 1.0) * 0.7,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(
                                  0.1 * _opacityAnimation.value,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.4 * _opacityAnimation.value),
                                Color(
                                  0xFF0F766E,
                                ).withOpacity(0.2 * _opacityAnimation.value),
                                Colors.teal.withOpacity(
                                  0.015 * _opacityAnimation.value,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Main content
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Back button at the top
                        if (!widget.exitFromApp)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 10,
                              left: 0,
                              bottom: 20,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    if (widget.fromNotification ||
                                        widget.fromResetPassword) {
                                      Navigator.pushNamed(
                                        context,
                                        RouteHelper.getInitialRoute(),
                                      );
                                    } else if (Get.find<AuthController>()
                                        .isOtpViewEnable) {
                                      Get.find<AuthController>().enableOtpView(
                                        enable: false,
                                      );
                                    } else {
                                      Get.back(result: false);
                                    }
                                  },
                                  icon: Icon(
                                    Icons.arrow_back_ios_rounded,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 40),

                        // Header Section
                        _buildHeaderSection(),
                        const SizedBox(height: 40),

                        // Main Content Container with slide animation
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.5),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _slideController,
                              curve: const Interval(
                                0.3,
                                1.0,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                          ),
                          child: FadeTransition(
                            opacity: Tween<double>(
                              begin: 0.0,
                              end: 1.0,
                            ).animate(
                              CurvedAnimation(
                                parent: _slideController,
                                curve: const Interval(
                                  0.3,
                                  1.0,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 400),
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                    spreadRadius: 0,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: SignInView(
                                exitFromApp: widget.exitFromApp,
                                backFromThis: widget.backFromThis,
                                fromResetPassword: widget.fromResetPassword,
                                isOtpViewEnable: (v) {},
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
