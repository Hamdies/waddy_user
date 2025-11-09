import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/onboard/controllers/onboard_controller.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_button.dart';
import 'package:sixam_mart/common/widgets/web_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _jiggleController;
  late AnimationController _exitController;
  late List<Animation<double>> _jiggleAnimations;
  
  // SVG assets data
  final List<String> _svgAssets = [
    "assets/on_boarding/Asset 1.svg",
    "assets/on_boarding/Asset 2.svg",
    "assets/on_boarding/Asset 3.svg",
     "assets/on_boarding/Asset 4.svg",
  ];

  @override
  void initState() {
    super.initState();

    Get.find<OnBoardingController>().getOnBoardingList();
    
    // Jiggle animation for continuous movement
    _jiggleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    // Exit animation for convergence effect
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
    
    // Create different jiggle animations for each SVG
    _jiggleAnimations = List.generate(
      _svgAssets.length,
      (index) => CurvedAnimation(
        parent: _jiggleController,
        curve: Interval(
          index * 0.1,
          1.0,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _jiggleController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ResponsiveHelper.isDesktop(context) ? const WebMenuBar() : null,
      body: SafeArea(
        child: GetBuilder<OnBoardingController>(
          builder: (onBoardingController) {
            bool showIndicatorAndButton = onBoardingController.selectedIndex < onBoardingController.onBoardingList.length-1;
            return onBoardingController.onBoardingList.isNotEmpty ? SafeArea(
              child: Center(child: SizedBox(width: Dimensions.webMaxWidth, child: Column(children: [

                Expanded(child: PageView.builder(
                  itemCount: onBoardingController.onBoardingList.length,
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  // physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    // First screen with animated icons
                    if (index == 0) {
                      return _buildAnimatedFirstScreen(context);
                    }
                    
                    // Second screen with falling icons
                    if (index == 1) {
                      return _buildSecondScreen(context);
                    }
                    
                    // Other onboarding screens
                    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [

                      showIndicatorAndButton && onBoardingController.onBoardingList[index].imageUrl != '' ? Padding(
                        padding: EdgeInsets.all(context.height*0.05),
                        child: Image.asset(onBoardingController.onBoardingList[index].imageUrl, height: context.height*0.4),
                      ) : const SizedBox(),

                      Text(
                        onBoardingController.onBoardingList[index].title,
                        style: robotoMedium.copyWith(fontSize: context.height*0.022),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: context.height*0.025),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
                        child: Text(
                          onBoardingController.onBoardingList[index].description,
                          style: robotoRegular.copyWith(fontSize: context.height*0.015, color: Theme.of(context).disabledColor),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    ]);
                  },
                  onPageChanged: (index) {
                    onBoardingController.changeSelectIndex(index);
                    
                    // Trigger animation when moving from page 0 to page 1
                    if (index == 1 && _exitController.status != AnimationStatus.completed) {
                      _exitController.forward();
                    }
                    // Reset animation when going back to page 0
                    if (index == 0 && _exitController.status == AnimationStatus.completed) {
                      _exitController.reset();
                    }
                    
                    if(onBoardingController.selectedIndex == 3) {
                      _configureToRouteInitialPage();
                    }
                  },
                )),

                // No buttons - gesture-based navigation only
                onBoardingController.selectedIndex >= 2 && showIndicatorAndButton ? Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  child: Row(children: [
                    onBoardingController.selectedIndex == 2 ? const SizedBox() : Expanded(
                      child: CustomButton(
                        transparent: true,
                        onPressed: () {
                          _configureToRouteInitialPage();
                        },
                        buttonText: 'skip'.tr,
                      ),
                    ),
                    Expanded(
                      child: CustomButton(
                        buttonText: onBoardingController.selectedIndex != 2 ? 'next'.tr : 'get_started'.tr,
                        onPressed: () {
                          if(onBoardingController.selectedIndex != 2) {
                            _pageController.nextPage(duration: const Duration(seconds: 1), curve: Curves.ease);
                          } else {
                            _configureToRouteInitialPage();
                          }
                        },
                      ),
                    ),
                  ]),
                ) : const SizedBox(),

              ]))),
            ) : const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedFirstScreen(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final centerX = screenWidth / 2;
    final centerY = screenHeight / 2;
    
    // Define SVG positions around the edges, away from center text
    final List<Map<String, dynamic>> svgPositions = [
      {'offset': Offset(20, centerY - 260), 'rotation': -0.1},            // Top-left
      {'offset': Offset(screenWidth - 180, centerY - 220), 'rotation': 0.12}, // Top-right
      {'offset': Offset(30, centerY + 120), 'rotation': -0.08},           // Bottom-left
      {'offset': Offset(screenWidth - 190, centerY + 160), 'rotation': 0.1},  // Bottom-right
    ];
    
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Stack(
        children: [
          // Animated SVG assets
          ...List.generate(_svgAssets.length, (index) {
            return AnimatedBuilder(
              animation: Listenable.merge([_jiggleController, _exitController]),
              builder: (context, child) {
                // Jiggle effect (floating movement)
                final jiggleOffset = Offset(
                  ((_jiggleAnimations[index].value - 0.5) * 8),
                  ((_jiggleAnimations[index].value - 0.5) * 8),
                );
                
                // Rotation jiggle
                final rotationJiggle = ((_jiggleAnimations[index].value - 0.5) * 0.05);
                
                // Exit animation (move to center, shrink, fade)
                final exitProgress = _exitController.value;
                final targetX = centerX - 100;
                final targetY = screenHeight - 200;
                
                final currentX = svgPositions[index]['offset'].dx + 
                    (targetX - svgPositions[index]['offset'].dx) * exitProgress +
                    jiggleOffset.dx * (1 - exitProgress);
                    
                final currentY = svgPositions[index]['offset'].dy + 
                    (targetY - svgPositions[index]['offset'].dy) * exitProgress +
                    jiggleOffset.dy * (1 - exitProgress);
                
                final rotation = svgPositions[index]['rotation'] + 
                    rotationJiggle * (1 - exitProgress);
                    
                // Keep scale consistent - no shrinking
                final scale = 1.0;
                final opacity = 1.0 - (exitProgress * 0.9);
                
                return Positioned(
                  left: currentX,
                  top: currentY,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Transform.scale(
                        scale: scale,
                        child: SvgPicture.asset(
                          _svgAssets[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          
          // Center logo and tagline
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Waddy logo (text)
                Text(
                  'Waddy',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Tagline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'From searches to customers for life. The ultimate growth tool for local businesses.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Next button at bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedBuilder(
                animation: _jiggleController,
                builder: (context, child) {
                  final bounce = (_jiggleController.value - 0.5).abs() * 8;
                  return Transform.translate(
                    offset: Offset(0, bounce),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 80),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondScreen(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final centerX = screenWidth / 2;
    final centerY = screenHeight / 2;
    
    // Box dimensions - centered on screen
    final boxWidth = screenWidth * 0.75;
    final boxHeight = 240.0;
    final boxLeft = centerX - (boxWidth / 2);
    final boxTop = centerY - (boxHeight / 2) + 40;
    
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // Title at top
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _exitController,
              builder: (context, child) {
                final opacity = _exitController.value > 0.3 
                    ? (_exitController.value - 0.3) * 1.4 
                    : 0.0;
                return Opacity(
                  opacity: opacity,
                  child: Column(
                    children: [
                      Text(
                        'All in One Box',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: 12),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 50),
                        child: Text(
                          'Everything you need, delivered to your door',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Falling SVG assets into the box
          ...List.generate(_svgAssets.length, (index) {
            return AnimatedBuilder(
              animation: _exitController,
              builder: (context, child) {
                // Staggered delay for each SVG
                final delay = index * 0.12;
                final totalDuration = 1.0;
                final cardDuration = totalDuration - delay;
                
                // Calculate progress for this SVG
                var rawProgress = (_exitController.value - delay) / cardDuration;
                var adjustedProgress = rawProgress.clamp(0.0, 1.0);
                if (adjustedProgress < 0.0) adjustedProgress = 0.0;
                if (adjustedProgress > 1.0) adjustedProgress = 1.0;
                
                // Start from top, spread horizontally
                final startX = centerX - 150 + (index * 100.0);
                final startY = -150.0 - (index * 20.0);
                
                // End positions - inside the box, arranged in 2x2 grid
                final row = index ~/ 2;
                final col = index % 2;
                final endX = boxLeft + 60 + (col * (boxWidth - 120) / 1.5);
                final endY = boxTop + 50 + (row * 80);
                
                // Falling with gravity effect
                final fallProgress = Curves.easeIn.transform(adjustedProgress);
                final currentX = startX + (endX - startX) * fallProgress;
                final currentY = startY + (endY - startY) * fallProgress;
                
                // Rotation as they fall
                final rotation = (1 - adjustedProgress) * 0.3 * (index % 2 == 0 ? 1 : -1);
                
                // Scale - maintain size
                final scale = 1.0;
                final opacity = adjustedProgress > 0.05 ? 1.0 : adjustedProgress * 20;
                
                return Positioned(
                  left: currentX,
                  top: currentY,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Transform.scale(
                        scale: scale,
                        child: SvgPicture.asset(
                          _svgAssets[index],
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          
          // Box at bottom
          Positioned(
            left: boxLeft,
            top: boxTop,
            child: Container(
              width: boxWidth,
              height: boxHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 50,
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Delivery Box',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          // Next button at bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _exitController,
              builder: (context, child) {
                final opacity = _exitController.value > 0.7 
                    ? (_exitController.value - 0.7) * 3.33 
                    : 0.0;
                return Opacity(
                  opacity: opacity,
                  child: GestureDetector(
                    onTap: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 80),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
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

  void _configureToRouteInitialPage() async {
    Get.find<SplashController>().disableIntro();
    await Get.find<AuthController>().guestLogin();
    if (AddressHelper.getUserAddressFromSharedPref() != null) {
      Get.offNamed(RouteHelper.getInitialRoute(fromSplash: true));
    } else {
      Get.find<LocationController>().navigateToLocationScreen(RouteHelper.onBoarding, offNamed: true).then((v) {
        _pageController.jumpToPage(Get.find<OnBoardingController>().onBoardingList.length-2);
      });
    }
  }
}
