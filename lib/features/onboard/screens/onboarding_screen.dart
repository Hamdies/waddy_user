import 'dart:async';
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
  final ScrollController _horizontalScrollController = ScrollController();
  late AnimationController _entranceController;
  Timer? _autoScrollTimer;
  bool _isOnFirstScreen = true;

  // Media assets data (4 items): supports .png/.jpg/.jpeg and .svg
  final List<String> _svgAssets = [
    "assets/on_boarding/grocery.png",
    "assets/on_boarding/Asset 11.png",

    "assets/on_boarding/pizza_ranch.png",
    "assets/image/waddy_coin.png",
  ];

  // Card labels - dynamically localized
  List<String> get _cardLabels {
    return [
      'screen_1_kitchen_essentials'.tr,
      'screen_1_pet_essentials'.tr,
      'screen_1_favorite_food'.tr,
      'screen_1_xp_points_rewards'.tr,
    ];
  }

  // Cohesive pastel color scheme with consistent saturation
  final List<Color> _cardColors = [
    Color(0xFFE0F7F4), // Soft mint
    Color(0xFFffec9e), // Soft peach
    Color(0xFFF9D8FA),
    Color(0xFF1EF2A0).withOpacity(0.3), // Soft lime
  ];

  final List<Color> _textColors = [
    Color(0xFF00A896), // Teal
    Color(0xFF99450e), // Orange
    Color(0xFFe91fb0), // Blue
    Color(0xff134E4A), // Green
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

    // Entrance animation for first screen (logo move up + fade in)
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    // Start auto-scroll after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _horizontalScrollController.hasClients) {
        final sw = MediaQuery.of(context).size.width;
        final itemWidth = sw * 0.42 + 12;
        _horizontalScrollController.jumpTo(itemWidth * 2000);
      }
      _startAutoScroll();
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
    _entranceController.dispose();
    _autoScrollTimer?.cancel();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_horizontalScrollController.hasClients && _isOnFirstScreen) {
        final maxScroll = _horizontalScrollController.position.maxScrollExtent;
        final newOffset = _horizontalScrollController.offset + 0.8;
        if (newOffset < maxScroll) {
          _horizontalScrollController.jumpTo(newOffset);
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  String _getChipText(int cardIndex) {
    switch (cardIndex) {
      case 0:
        return 'chip_no_ingredients'.tr;
      case 1:
        return 'chip_feed_the_boss'.tr;
      case 2:
        return 'chip_lets_eat'.tr;
      case 3:
        return 'chip_free_stuff'.tr;
      default:
        return 'Explore';
    }
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

                                // Track which screen we're on for auto-scroll
                                if (index == 0) {
                                  _isOnFirstScreen = true;
                                  if (!_jiggleController.isAnimating) {
                                    _jiggleController.repeat(reverse: true);
                                  }
                                  _startAutoScroll();
                                  if (_exitController.status ==
                                      AnimationStatus.completed) {
                                    _exitController.reset();
                                  }
                                } else {
                                  _isOnFirstScreen = false;
                                  _stopAutoScroll();
                                }

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
    final cardWidth = screenWidth * 0.42;
    final cardHeight = 200.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_entranceController, _jiggleController]),
      builder: (context, child) {
        // Logo moves from center to top
        final logoMoveProgress = Curves.easeOutCubic.transform(
          (_entranceController.value * 1.8).clamp(0.0, 1.0),
        );
        final logoStartY = screenHeight * 0.32;
        final logoEndY = 50.0;
        final logoY = logoStartY + (logoEndY - logoStartY) * logoMoveProgress;

        // Cards fade in
        final cardsOpacity = Curves.easeOut.transform(
          ((_entranceController.value - 0.25) / 0.35).clamp(0.0, 1.0),
        );

        // Text fade in
        final textOpacity = Curves.easeOut.transform(
          ((_entranceController.value - 0.5) / 0.3).clamp(0.0, 1.0),
        );

        // Button fade in
        final buttonOpacity = Curves.easeOut.transform(
          ((_entranceController.value - 0.7) / 0.3).clamp(0.0, 1.0),
        );

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

              // Logo fixed at top (animates from center to top)
              Positioned(
                top: logoY,
                left: 0,
                right: 0,
                child: Center(
                  child: SvgPicture.asset(
                    "assets/on_boarding/Asset 11.svg",
                    fit: BoxFit.contain,
                    width: 70,
                    height: 70,
                  ),
                ),
              ),

              // Horizontally scrolling cards (infinite, right to left)
              Positioned(
                top: screenHeight * 0.20,
                left: 0,
                right: 0,
                height: cardHeight + 10,
                child: Opacity(
                  opacity: cardsOpacity,
                  child: ListView.builder(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: 10000,
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    itemBuilder: (context, index) {
                      final cardIndex = index % 4;

                      // Gentle float effect per card
                      final animValue = _jiggleController.value;
                      final easedValue = Curves.easeInOut.transform(animValue);
                      final floatOffset = sin(
                        easedValue * pi * 2 + cardIndex * pi / 2,
                      ) * 3.0;

                      return Transform.translate(
                        offset: Offset(0, floatOffset),
                        child: Container(
                          width: cardWidth,
                          height: cardHeight,
                          margin: EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: _cardColors[cardIndex % _cardColors.length],
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.7),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Circular icon badge
                              Container(
                                width: 75,
                                height: 75,
                                decoration: BoxDecoration(
                                  color: _cardColors[cardIndex % _cardColors.length]
                                      .withOpacity(0.4),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _textColors[cardIndex % _textColors.length]
                                        .withOpacity(0.4),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _textColors[cardIndex % _textColors.length]
                                          .withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    _svgAssets[cardIndex % _svgAssets.length],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              SizedBox(height: 14),
                              // Card label text
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  _cardLabels[cardIndex % _cardLabels.length],
                                  style: TextStyle(
                                    color: _textColors[
                                      cardIndex % _textColors.length
                                    ],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    letterSpacing: -0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: 8),
                              // Small chip badge with dynamic copy
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _textColors[cardIndex % _textColors.length]
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _textColors[cardIndex % _textColors.length]
                                        .withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  _getChipText(cardIndex),
                                  style: TextStyle(
                                    color: _textColors[
                                      cardIndex % _textColors.length
                                    ],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Title and description below cards
              Positioned(
                top: screenHeight * 0.53,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: textOpacity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'onboarding_page1_title1'.tr,
                          textAlign: TextAlign.center,
                          style: robotoBold.copyWith(
                            fontSize: 28,
                            color: Theme.of(context).primaryColor,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'onboarding_page1_title2'.tr,
                          textAlign: TextAlign.center,
                          style: robotoBold.copyWith(
                            fontSize: 24,
                            color: Theme.of(context).secondaryHeaderColor,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 12),
                        Image.asset(
                          "assets/on_boarding/stroke.png",
                          width: 120,
                          color: Theme.of(context).secondaryHeaderColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Next button at bottom (dark style)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: buttonOpacity,
                  child: CustomButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                    buttonText: 'onboarding_next'.tr,
                    icon: Icons.arrow_downward,
                    margin: EdgeInsets.symmetric(horizontal: 50),
                    height: 50,
                    fontSize: 18,
                    isBold: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecondScreen(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final centerX = screenWidth / 2;
    final centerY = screenHeight / 2;

    // All cards start from the same position (center top) and fall one over the other
    final startX = centerX - 75; // Center horizontally (150 / 2)
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

                // Target: exact center of the screen
                final boxCenterX = centerX - 75; // Center horizontally (150 / 2)
                final boxCenterY = centerY - 75; // Center vertically (150 / 2)

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

                // SHRINK smoothly as cards fall into box
                final scale = (1.0 - (smoothFallProgress * 0.6)).clamp(
                  0.2,
                  1.0,
                ); // Shrink to 40%, min 20%

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
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: _cardColors[index % _cardColors.length],
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.7),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Circular icon badge
                              Container(
                                width: 55,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: _cardColors[index % _cardColors.length]
                                      .withOpacity(0.4),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _textColors[index % _textColors.length]
                                        .withOpacity(0.4),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _textColors[index % _textColors.length]
                                          .withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    _svgAssets[index % _svgAssets.length],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              SizedBox(height: 10),
                              // Card label text
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  _cardLabels[index % _cardLabels.length],
                                  style: robotoBold.copyWith(
                                    color: _textColors[index % _textColors.length],
                                    fontSize: 11,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: 6),
                              // Small chip badge with dynamic copy
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _textColors[index % _textColors.length]
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _textColors[index % _textColors.length]
                                        .withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  _getChipText(index),
                                  style: TextStyle(
                                    color: _textColors[index % _textColors.length],
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ],
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
                          text1: 'delivery_box_you_need_it'.tr,
                          text2: 'delivery_box_we_speed_it'.tr,
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
                                style: robotoBold.copyWith(
                                  fontSize: 28,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    'onboarding_page2_title2'.tr,
                                    textAlign: TextAlign.center,
                                    style: robotoBold.copyWith(
                                      fontSize: 24,
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
                                style: robotoMedium.copyWith(
                                  fontSize: 15,
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
                  child: CustomButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    buttonText: 'Next',
                    color: Theme.of(context).primaryColor,
                    icon: Icons.arrow_downward,
                    margin: EdgeInsets.symmetric(horizontal: 80),
                    height: 50,
                    fontSize: 18,
                    isBold: true,
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
                            text1: 'delivery_box_you_need_it'.tr,
                            text2: 'delivery_box_we_speed_it'.tr,
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
                              style: robotoBold.copyWith(
                                fontSize: 28,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'onboarding_page3_description'.tr,
                              textAlign: TextAlign.center,
                              style: robotoMedium.copyWith(
                                fontSize: 15,
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
                    child: CustomButton(
                      onPressed: () {
                        _configureToRouteInitialPage();
                      },
                      buttonText: 'onboarding_get_started'.tr,
                      color: Theme.of(context).primaryColor,
                      icon: Icons.check,
                      margin: EdgeInsets.symmetric(horizontal: 60),
                      height: 50,
                      fontSize: 18,
                      isBold: true,
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
    required this.isArabic,
    this.svgAssetPath,
    String? text1,
    String? text2,
  }) : textPainter1 = TextPainter(
         text: TextSpan(
           text: text1,
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
           text: text2,
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
