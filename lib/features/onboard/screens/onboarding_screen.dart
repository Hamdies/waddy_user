import 'dart:math';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/onboard/controllers/onboard_controller.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_button.dart';
import 'package:sixam_mart/common/widgets/web_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _jiggleController;
  late AnimationController _exitController;

  late List<Map<String, double>> _cardIntervals; // Pre-calculated intervals

  // Media assets data (4 items): supports .png/.jpg/.jpeg and .svg
  final List<String> _svgAssets = [
    "assets/on_boarding/grocery.png",
    "assets/on_boarding/Asset 11.png",

    "assets/on_boarding/pizza_ranch.png",
    "assets/on_boarding/Asset 1offer.png",
  ];

  // Card labels - dynamically localized
  List<String> get _cardLabels {
    final isArabic = Get.locale?.languageCode == 'ar';
    return isArabic
        ? [
          "مستلزمات المطبخ",
          "مستلزمات الحيوانات الأليفة",
          "أكلك المفضل",
          "عروض وخصومات",
        ]
        : [
          "Kitchen Essentials",
          "Pet Essentials",
          "Your Favorite Food",
          "Deals & Discounts",
        ];
  }

  // Cohesive pastel color scheme with consistent saturation
  final List<Color> _cardColors = [
    Color(0xFFE0F7F4), // Soft mint
    Color(0xFFffec9e), // Soft peach
    Color(0xFFF9D8FA),
    Color(0xFFD3E6FF), // Soft lime
  ];

  final List<Color> _textColors = [
    Color(0xFF00A896), // Teal
    Color(0xFF99450e), // Orange
    Color(0xFFe91fb0), // Blue
    Color(0xff273b71), // Green
  ];

  @override
  void initState() {
    super.initState();

    Get.find<OnBoardingController>().getOnBoardingList();

    // Smooth floating animation with gentle jiggle effect
    _jiggleController = AnimationController(
      duration: const Duration(milliseconds: 3500), // Slower, more relaxing
      vsync: this,
    )..repeat(reverse: true);

    // Cards shrink and fall into box animation
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    // Pre-calculate animation intervals for second screen
    _cardIntervals = List.generate(4, (index) {
      final cardAppearStart = index * 0.2;
      final cardAppearEnd = cardAppearStart + 0.15;
      final cardFallStart = cardAppearEnd;
      final cardFallEnd = cardFallStart + 0.45;
      return {
        'appearStart': cardAppearStart,
        'appearEnd': cardAppearEnd,
        'fallStart': cardFallStart,
        'fallEnd': cardFallEnd,
      };
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache images for smooth loading without lag
    for (String asset in _svgAssets) {
      precacheImage(AssetImage(asset), context);
    }
    precacheImage(const AssetImage("assets/on_boarding/Asset 11.png"), context);
    precacheImage(const AssetImage("assets/on_boarding/stroke.png"), context);
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
      backgroundColor: Colors.white,
      appBar: ResponsiveHelper.isDesktop(context) ? const WebMenuBar() : null,
      body: SafeArea(
        child: GetBuilder<OnBoardingController>(
          builder: (onBoardingController) {
            bool showIndicatorAndButton =
                onBoardingController.selectedIndex <
                onBoardingController.onBoardingList.length - 1;
            return onBoardingController.onBoardingList.isNotEmpty
                ? SafeArea(
                  child: Center(
                    child: SizedBox(
                      width: Dimensions.webMaxWidth,
                      child: Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              itemCount:
                                  onBoardingController.onBoardingList.length,
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

                                // Third screen with falling box and Lottie
                                if (index == 2) {
                                  return _buildThirdScreen(context);
                                }

                                // Other onboarding screens
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    showIndicatorAndButton &&
                                            onBoardingController
                                                    .onBoardingList[index]
                                                    .imageUrl !=
                                                ''
                                        ? Padding(
                                          padding: EdgeInsets.all(
                                            context.height * 0.05,
                                          ),
                                          child: Image.asset(
                                            onBoardingController
                                                .onBoardingList[index]
                                                .imageUrl,
                                            height: context.height * 0.4,
                                          ),
                                        )
                                        : const SizedBox(),

                                    Text(
                                      onBoardingController
                                          .onBoardingList[index]
                                          .title,
                                      style: robotoMedium.copyWith(
                                        fontSize: context.height * 0.022,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: context.height * 0.025),

                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Dimensions.paddingSizeLarge,
                                      ),
                                      child: Text(
                                        onBoardingController
                                            .onBoardingList[index]
                                            .description,
                                        style: robotoRegular.copyWith(
                                          fontSize: context.height * 0.015,
                                          color:
                                              Theme.of(context).disabledColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                );
                              },
                              onPageChanged: (index) {
                                onBoardingController.changeSelectIndex(index);

                                // Trigger animation when moving to page 1
                                if (index == 1) {
                                  // Reset and start animation quickly
                                  _exitController.reset();
                                  Future.delayed(
                                    Duration(milliseconds: 80),
                                    () {
                                      if (_exitController.status !=
                                          AnimationStatus.completed) {
                                        _exitController.forward();
                                      }
                                    },
                                  );
                                }
                                // Reset animation when going back to page 0
                                if (index == 0 &&
                                    _exitController.status ==
                                        AnimationStatus.completed) {
                                  _exitController.reset();
                                }
                                // Trigger box fall animation on page 2
                                if (index == 2) {
                                  _jiggleController.reset();
                                  Future.delayed(
                                    Duration(milliseconds: 100),
                                    () {
                                      if (_jiggleController.status !=
                                          AnimationStatus.completed) {
                                        _jiggleController.forward();
                                      }
                                    },
                                  );
                                }

                                if (onBoardingController.selectedIndex == 3) {
                                  _configureToRouteInitialPage();
                                }
                              },
                            ),
                          ),

                          // No buttons on page 2 (third screen) - only show for other screens
                          onBoardingController.selectedIndex >= 2 &&
                                  onBoardingController.selectedIndex != 2 &&
                                  showIndicatorAndButton
                              ? Padding(
                                padding: const EdgeInsets.all(
                                  Dimensions.paddingSizeSmall,
                                ),
                                child: Row(
                                  children: [
                                    onBoardingController.selectedIndex == 2
                                        ? const SizedBox()
                                        : Expanded(
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
                                        buttonText:
                                            onBoardingController
                                                        .selectedIndex !=
                                                    2
                                                ? 'next'.tr
                                                : 'get_started'.tr,
                                        onPressed: () {
                                          if (onBoardingController
                                                  .selectedIndex !=
                                              2) {
                                            _pageController.nextPage(
                                              duration: const Duration(
                                                milliseconds: 700,
                                              ),
                                              curve: Curves.ease,
                                            );
                                          } else {
                                            _configureToRouteInitialPage();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : const SizedBox(),
                        ],
                      ),
                    ),
                  ),
                )
                : const SizedBox();
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

    // SVG size and margin used for placing items near the edges
    const double svgSize = 100.0; // matches SvgPicture width/height below
    const double edgeMargin = 8.0; // bring slightly inside so fully visible

    // Position cards with uniform sizing and better logo spacing
    final List<Map<String, dynamic>> svgPositions = [
      // Top right - moved higher for logo breathing room
      {'offset': Offset(200, 35), 'rotation': 0.02},
      // Left middle - moved higher for logo breathing room
      {'offset': Offset(20, 115), 'rotation': -0.05},
      // Right lower middle
      {'offset': Offset(screenWidth - 180, centerY + 100), 'rotation': 0.06},
      // Bottom left
      {'offset': Offset(10, screenHeight - 260), 'rotation': 0.0},
    ];

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // Soft gradient overlays in corners
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.2),
                    Color(0xFF00ff9d).withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.topRight,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.2),
                    Color(0xFF00ff9d).withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.4),
                    Color(0xFF00ff9d).withOpacity(0.03),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.topLeft,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.3),
                    Color(0xFF00ff9d).withOpacity(0.03),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Animated SVG assets (4 items at corners)
          ...List.generate(4, (index) {
            return AnimatedBuilder(
              animation: Listenable.merge([_jiggleController, _exitController]),
              builder: (context, child) {
                // GENTLE SMOOTH FLOAT EFFECT
                final animValue = _jiggleController.value;

                // Smooth eased vertical floating only - no jitter
                final easedValue = Curves.easeInOut.transform(animValue);
                final floatOffset =
                    sin(easedValue * pi * 2) * 5.0; // Gentle +/- 5 pixels

                final baseRotation = svgPositions[index]['rotation'] as double;

                final currentX = svgPositions[index]['offset'].dx;
                final currentY = svgPositions[index]['offset'].dy + floatOffset;

                final scale = 1.0;
                final rotation = baseRotation;
                final opacity = 1.0;

                return Positioned(
                  left: currentX,
                  top: currentY,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 200,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _cardColors[index % _cardColors.length]
                                .withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _textColors[index % _textColors.length]
                                    .withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.7),
                                    Colors.white.withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Circular icon container with frosted effect
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.4),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        _svgAssets[index % _svgAssets.length],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  // Text
                                  Expanded(
                                    child: Text(
                                      _cardLabels[index % _cardLabels.length],
                                      style: TextStyle(
                                        color:
                                            _textColors[index %
                                                _textColors.length],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                SvgPicture.asset(
                  "assets/on_boarding/Asset 11.svg",
                  fit: BoxFit.contain,
                  width: 200,
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Column(
                    children: [
                      Text(
                        'onboarding_page1_title1'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xff2D3748),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 5),
                      Column(
                        children: [
                          Text(
                            'onboarding_page1_title2'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xff00C78C),
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Image.asset(
                            "assets/on_boarding/stroke.png",
                            width: 100,
                            color: Theme.of(context).secondaryHeaderColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Simple Next button at bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 250),
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
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).secondaryHeaderColor.withOpacity(0.4),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).secondaryHeaderColor,
                            blurRadius: 0,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'onboarding_next'.tr,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_downward,
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

    // All cards start from the same position (center top) and fall one over the other
    final startX = centerX - 100; // Center horizontally
    final startY = 50.0; // Start from top
    final List<Map<String, dynamic>> svgPositions = [
      {'offset': Offset(startX, startY), 'rotation': 0.02},
      {'offset': Offset(startX, startY), 'rotation': -0.05},
      {'offset': Offset(startX, startY), 'rotation': 0.06},
      {'offset': Offset(startX, startY), 'rotation': -0.03},
    ];

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // Animated cards that shrink and fall into box
          ...List.generate(4, (index) {
            return AnimatedBuilder(
              animation: _exitController,
              builder: (context, child) {
                // Cards shrink and fall INTO the centered orange box
                final exitProgress = _exitController.value;
                final intervals = _cardIntervals[index];

                final cardAppearStart = intervals['appearStart']!;
                final cardAppearEnd = intervals['appearEnd']!;
                final cardFallStart = intervals['fallStart']!;
                final cardFallEnd = intervals['fallEnd']!;

                // Calculate appearance and fall progress
                double appearProgress = 0.0;
                double fallProgress = 0.0;

                if (exitProgress >= cardAppearStart) {
                  if (exitProgress >= cardAppearEnd) {
                    appearProgress = 1.0;
                    // Start falling after appearing
                    if (exitProgress >= cardFallStart) {
                      if (exitProgress >= cardFallEnd) {
                        fallProgress = 1.0;
                      } else {
                        fallProgress =
                            (exitProgress - cardFallStart) /
                            (cardFallEnd - cardFallStart);
                      }
                    }
                  } else {
                    appearProgress =
                        (exitProgress - cardAppearStart) /
                        (cardAppearEnd - cardAppearStart);
                  }
                }

                // Softer fall with deceleration at the end
                final smoothFallProgress = Curves.easeInOutCubic.transform(
                  fallProgress,
                );

                // Target: exact center of the orange box
                final boxCenterX = centerX - 100; // Adjust for card width
                final boxCenterY = centerY - 40; // Adjust for card height

                final currentX =
                    svgPositions[index]['offset'].dx +
                    (boxCenterX - svgPositions[index]['offset'].dx) *
                        smoothFallProgress;

                final currentY =
                    svgPositions[index]['offset'].dy +
                    (boxCenterY - svgPositions[index]['offset'].dy) *
                        smoothFallProgress;

                // Rotate while falling
                final rotation =
                    svgPositions[index]['rotation'] +
                    (smoothFallProgress * 0.4 * (index % 2 == 0 ? 1 : -1));

                // SHRINK dramatically as cards fall into box
                final scale = (1.0 - (smoothFallProgress * 0.88)).clamp(
                  0.05,
                  1.0,
                ); // Shrink to 12%, min 5%

                // Fade based on appearance and fall progress
                final opacity =
                    appearProgress > 0
                        ? (1.0 - (smoothFallProgress * 1.0))
                        : 0.0;

                return Positioned(
                  left: currentX,
                  top: currentY,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 200,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _cardColors[index % _cardColors.length]
                                .withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _textColors[index % _textColors.length]
                                    .withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.7),
                                    Colors.white.withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.4),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        _svgAssets[index % _svgAssets.length],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _cardLabels[index % _cardLabels.length],
                                      style: TextStyle(
                                        color:
                                            _textColors[index %
                                                _textColors.length],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Soft gradient overlays in corners (same as page 0)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.2),
                    Color(0xFF00ff9d).withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.topRight,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.2),
                    Color(0xFF00ff9d).withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.4),
                    Color(0xFF00ff9d).withOpacity(0.03),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.topLeft,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.3),
                    Color(0xFF00ff9d).withOpacity(0.03),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // Centered delivery box with text below
          Center(
            child: AnimatedBuilder(
              animation: _exitController,
              builder: (context, child) {
                final contentOpacity =
                    _exitController.value > 0.4
                        ? ((_exitController.value - 0.4) / 0.4).clamp(0.0, 1.0)
                        : 0.0;

                return GestureDetector(
                  onTap: () {
                    if (_exitController.value == 0) {
                      _exitController.forward();
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomPaint(
                        painter: DeliveryBoxPainter(
                          primaryColor: Theme.of(context).primaryColor,
                          accentColor: Theme.of(context).secondaryHeaderColor,
                          contentOpacity: contentOpacity,
                          svgAssetPath: 'assets/on_boarding/Asset 11.svg',
                          isArabic: Get.locale?.languageCode == 'ar',
                        ),
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 60),
                          width: MediaQuery.of(context).size.width - 120,
                          height: 220,
                          child: Stack(
                            children: [
                              // SVG icon positioned in the icon area
                              Positioned(
                                top: 40,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: SvgPicture.asset(
                                    'assets/on_boarding/Asset 11.svg',
                                    width: 30,
                                    height: 30,
                                    colorFilter: ColorFilter.mode(
                                      Theme.of(context).secondaryHeaderColor,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                      // Text under the box
                      Opacity(
                        opacity: contentOpacity,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            children: [
                              Text(
                                'onboarding_page2_title1'.tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    'onboarding_page2_title2'.tr,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  Image.asset(
                                    "assets/on_boarding/stroke.png",
                                    width: 120,
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                'onboarding_page2_description'.tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Next button at bottom (appears after animation completes)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _exitController,
              builder: (context, child) {
                // Button appears after animation is mostly complete (adjusted for faster animation)
                final buttonOpacity =
                    _exitController.value > 0.6
                        ? ((_exitController.value - 0.6) / 0.25).clamp(0.0, 1.0)
                        : 0.0;

                return Opacity(
                  opacity: buttonOpacity,
                  child: GestureDetector(
                    onTap: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 80),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).secondaryHeaderColor.withOpacity(0.4),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).secondaryHeaderColor,
                            blurRadius: 0,
                            offset: Offset(0, 2),
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
                            Icons.arrow_downward,
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

  Widget _buildThirdScreen(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // Lottie animation in background layer
          Center(
            child: Lottie.asset(
              'assets/on_boarding/home (1).json',
              width: screenWidth,
              height: screenHeight,
            ),
          ),

          // Soft gradient overlays in corners (same as page 0 and page 1)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.2),
                    Color(0xFF00ff9d).withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.topRight,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.2),
                    Color(0xFF00ff9d).withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.4),
                    Color(0xFF00ff9d).withOpacity(0.03),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.topLeft,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withOpacity(0.3),
                    Color(0xFF00ff9d).withOpacity(0.03),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  center: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // Falling box with text - lands on door rug
          AnimatedBuilder(
            animation: _jiggleController,
            builder: (context, child) {
              // Better falling animation with bounce
              final fallProgress = _jiggleController.value;
              final easedProgress = Curves.elasticOut.transform(fallProgress);

              // Start above screen, fall to door rug (on the pink mat)
              final startY = -150.0; // Start higher above screen
              final endY =
                  screenHeight * 0.42; // Land on the rug (pink mat below door)
              final currentY = startY + (endY - startY) * easedProgress;

              // Small size throughout - no scaling animation
              final boxScale = 0.25; // Small size to fit on door rug

              // Slight rotation with bounce
              final rotation = (1 - easedProgress) * 0.3;

              // Text opacity - appears after box lands
              final textOpacity =
                  fallProgress > 0.65
                      ? ((fallProgress - 0.65) / 0.2).clamp(0.0, 1.0)
                      : 0.0;

              return Stack(
                children: [
                  // Falling box
                  Positioned(
                    left: 0,
                    right: 0,
                    top: currentY,
                    child: Transform.scale(
                      scale: boxScale,
                      child: Transform.rotate(
                        angle: rotation,
                        child: CustomPaint(
                          painter: DeliveryBoxPainter(
                            primaryColor: Theme.of(context).primaryColor,
                            accentColor: Theme.of(context).secondaryHeaderColor,
                            contentOpacity: 1.0,
                            svgAssetPath: 'assets/on_boarding/Asset 11.svg',
                            isArabic: Get.locale?.languageCode == 'ar',
                          ),
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 60),
                            width: screenWidth - 120,
                            height: 220,
                            child: Stack(
                              children: [
                                // SVG icon positioned in the icon area
                                Positioned(
                                  top: 40,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: SvgPicture.asset(
                                      'assets/on_boarding/Asset 11.svg',
                                      width: 30,
                                      height: 30,
                                      colorFilter: ColorFilter.mode(
                                        Theme.of(context).secondaryHeaderColor,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Text below the box area
                  Positioned(
                    bottom: 110,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: textOpacity,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 30),
                        child: Column(
                          children: [
                            Text(
                              'onboarding_page3_title'.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'onboarding_page3_description'.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Get Started button at bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _jiggleController,
              builder: (context, child) {
                // Button appears after box lands
                final buttonOpacity =
                    _jiggleController.value > 0.65
                        ? ((_jiggleController.value - 0.65) / 0.2).clamp(
                          0.0,
                          1.0,
                        )
                        : 0.0;

                // Jiggle effect
                final jiggleOffset = sin(_jiggleController.value * pi * 4) * 3;

                return Opacity(
                  opacity: buttonOpacity,
                  child: Transform.translate(
                    offset: Offset(0, jiggleOffset),
                    child: GestureDetector(
                      onTap: () {
                        _configureToRouteInitialPage();
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 60),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).secondaryHeaderColor.withOpacity(0.4),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).secondaryHeaderColor,
                              blurRadius: 0,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'onboarding_get_started'.tr,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.check, color: Colors.white, size: 22),
                          ],
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

  void _configureToRouteInitialPage() async {
    Get.find<SplashController>().disableIntro();
    // Redirect to unified auth screen with step-by-step OTP flow
    Get.offNamed(RouteHelper.getUnifiedAuthRoute());
  }
}

// Optimized custom painter that reuses TextPainters
class DeliveryBoxPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final double contentOpacity;
  final String? svgAssetPath;
  final TextPainter textPainter1;
  final TextPainter textPainter2;
  final bool isArabic;

  DeliveryBoxPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.contentOpacity,
    this.svgAssetPath,
    this.isArabic = false,
  }) : textPainter1 = TextPainter(
         text: TextSpan(
           text: isArabic ? 'احتياجك' : 'You Need It',
           style: TextStyle(
             fontSize: 20,
             fontWeight: FontWeight.w900,
             color: Colors.white.withOpacity(0.9),
             letterSpacing: isArabic ? 0 : 2,
           ),
         ),
         textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
       )..layout(),
       textPainter2 = TextPainter(
         text: TextSpan(
           text: isArabic ? 'مهمتنا' : 'We Speed It',
           style: TextStyle(
             fontSize: 20,
             fontWeight: FontWeight.w900,
             color: Color(0xFF1EF2A0),
             letterSpacing: isArabic ? 0 : 2,
           ),
         ),
         textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
       )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Box dimensions - smaller size
    final boxWidth = size.width - 120;
    final boxHeight = 200.0;
    final boxLeft = 60.0;
    final boxTop = (size.height - boxHeight) / 2;

    // Main box body (primary color)
    paint.color = primaryColor;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
      Radius.circular(30),
    );
    canvas.drawRRect(boxRect, paint);

    // Box flaps (top) - darker shade for 3D effect
    paint.color = Color.lerp(primaryColor, Colors.black, 0.2)!;
    final flapPath = Path();
    flapPath.moveTo(boxLeft + 30, boxTop);
    flapPath.lineTo(boxLeft + boxWidth * 0.3, boxTop - 20);
    flapPath.lineTo(boxLeft + boxWidth * 0.7, boxTop - 20);
    flapPath.lineTo(boxLeft + boxWidth - 30, boxTop);
    flapPath.close();
    canvas.drawPath(flapPath, paint);

    // Box tape (accent color stripe)
    paint.color = accentColor;
    final tapeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxLeft, boxTop + boxHeight * 0.4, boxWidth, 40),
      Radius.circular(5),
    );
    canvas.drawRRect(tapeRect, paint);

    // Tape pattern (dashed lines)
    paint.color = Colors.teal.withOpacity(0.3);
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    for (double i = boxLeft + 10; i < boxLeft + boxWidth - 10; i += 20) {
      canvas.drawLine(
        Offset(i, boxTop + boxHeight * 0.4 + 10),
        Offset(i + 10, boxTop + boxHeight * 0.4 + 10),
        paint,
      );
      canvas.drawLine(
        Offset(i, boxTop + boxHeight * 0.4 + 30),
        Offset(i + 10, boxTop + boxHeight * 0.4 + 30),
        paint,
      );
    }

    // Border outline (accent color)
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4;
    paint.color = accentColor;
    canvas.drawRRect(boxRect, paint);

    // SVG icon area
    final iconSize = 50.0;
    final iconLeft = boxLeft + (boxWidth - iconSize) / 2;
    final iconTop = boxTop + 20;

    // Draw SVG icon background
    paint.style = PaintingStyle.fill;
    paint.color = accentColor.withOpacity(0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(iconLeft, iconTop, iconSize, iconSize),
        Radius.circular(8),
      ),
      paint,
    );

    // Text with opacity
    if (contentOpacity > 0) {
      // Paint reused text painters with opacity layer
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white.withOpacity(contentOpacity),
      );

      textPainter1.paint(
        canvas,
        Offset(boxLeft + (boxWidth - textPainter1.width) / 2, boxTop + 125),
      );

      textPainter2.paint(
        canvas,
        Offset(boxLeft + (boxWidth - textPainter2.width) / 2, boxTop + 160),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(DeliveryBoxPainter oldDelegate) {
    return oldDelegate.contentOpacity != contentOpacity;
  }
}
