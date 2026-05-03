import 'dart:async';
import 'dart:math';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/onboard/controllers/onboard_controller.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/web_menu_bar.dart';
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

  late List<Map<String, double>> _cardIntervals;
  final ScrollController _horizontalScrollController = ScrollController();
  late AnimationController _entranceController;
  Timer? _autoScrollTimer;
  bool _isOnFirstScreen = true;

  final List<String> _svgAssets = [
    "assets/on_boarding/grocery.png",
    "assets/on_boarding/Asset 11.png",
    "assets/on_boarding/pizza_ranch.png",
    "assets/image/waddy_coin.png",
  ];

  List<String> get _cardLabels {
    return [
      'screen_1_kitchen_essentials'.tr,
      'screen_1_pet_essentials'.tr,
      'screen_1_favorite_food'.tr,
      'screen_1_xp_points_rewards'.tr,
    ];
  }

  final List<Color> _cardColors = [
    Color(0xFFE0F7F4),
    Color(0xFFffec9e),
    Color(0xFFF9D8FA),
    Color(0xFF1EF2A0).withValues(alpha: 0.3),
  ];

  final List<Color> _textColors = [
    Color(0xFF00A896),
    Color(0xFF99450e),
    Color(0xFFe91fb0),
    Color(0xff134E4A),
  ];

  // ─── Responsive helpers ───────────────────────────────────────────────────

  /// Returns a value interpolated across mobile → tablet → desktop.
  /// Pass the three breakpoint values; the helper picks based on screen width.
  T _r<T>(BuildContext context, {required T mobile, required T tab, required T desktop}) {
    if (ResponsiveHelper.isDesktop(context)) return desktop;
    if (ResponsiveHelper.isTab(context)) return tab;
    return mobile;
  }

  /// Fluid horizontal button margin: tighter on phone, generous on tablet/web.
  EdgeInsets _buttonMargin(BuildContext context) => EdgeInsets.symmetric(
        horizontal: _r<double>(context, mobile: 40, tab: 120, desktop: 200),
      );

  /// Fluid heading font size.
  double _headingSize(BuildContext context) =>
      _r<double>(context, mobile: 28, tab: 34, desktop: 38);

  /// Fluid subtitle font size.
  double _subtitleSize(BuildContext context) =>
      _r<double>(context, mobile: 24, tab: 28, desktop: 32);

  /// Fluid body font size.
  double _bodySize(BuildContext context) =>
      _r<double>(context, mobile: 15, tab: 17, desktop: 18);

  /// Fluid logo size (SVG).
  double _logoSize(BuildContext context) =>
      _r<double>(context, mobile: 70, tab: 90, desktop: 100);

  /// Card width — narrow on mobile, fixed cap on tablet/desktop.
  double _cardWidth(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    if (ResponsiveHelper.isDesktop(context)) return 220;
    if (ResponsiveHelper.isTab(context)) return (sw * 0.28).clamp(180, 240);
    return sw * 0.42;
  }

  /// Card height — grows a little on larger screens.
  double _cardHeight(BuildContext context) =>
      _r<double>(context, mobile: 200, tab: 220, desktop: 240);

  /// Icon badge size inside cards.
  double _badgeSize(BuildContext context) =>
      _r<double>(context, mobile: 75, tab: 90, desktop: 100);

  /// Card label font size.
  double _cardLabelSize(BuildContext context) =>
      _r<double>(context, mobile: 15, tab: 16, desktop: 17);

  /// Chip label font size inside cards.
  double _chipSize(BuildContext context) =>
      _r<double>(context, mobile: 11, tab: 12, desktop: 13);

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    Get.find<OnBoardingController>().getOnBoardingList();

    _jiggleController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    )..repeat(reverse: true);

    _exitController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    // Phase layout (normalized 0–1 over 1400ms):
    //   0.00 – 0.55 : cards fall in from top, staggered (card i starts at i*0.08)
    //   0.55 – 1.00 : cards suck into box one by one (staggered by 0.08 each)
    //
    // Each card fall window = [i*0.08, i*0.08+0.28]
    // Each card suck window = [0.55 + i*0.08, 0.55 + i*0.08 + 0.18]
    _cardIntervals = List.generate(4, (index) {
      final fallStart = index * 0.08;
      final fallEnd   = fallStart + 0.28;
      final suckStart = 0.55 + index * 0.08;
      final suckEnd   = suckStart + 0.18;
      return {
        'fallStart': fallStart,
        'fallEnd':   fallEnd,
        'suckStart': suckStart,
        'suckEnd':   suckEnd,
      };
    });

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _horizontalScrollController.hasClients) {
        final sw = MediaQuery.of(context).size.width;
        final itemWidth = _cardWidth(context) + 12;
        _horizontalScrollController.jumpTo(itemWidth * 2000);
      }
      _startAutoScroll();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    final isTab = ResponsiveHelper.isTab(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final dotActiveW = (isDesktop || isTab) ? 32.0 : 24.0;
    final dotInactiveW = (isDesktop || isTab) ? 10.0 : 8.0;
    final dotH = (isDesktop || isTab) ? 10.0 : 8.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isDesktop ? const WebMenuBar() : null,
      body: SafeArea(
        child: GetBuilder<OnBoardingController>(
          builder: (onBoardingController) {
            return onBoardingController.onBoardingList.isNotEmpty
                ? SafeArea(
                    child: Center(
                      child: SizedBox(
                        width: Dimensions.webMaxWidth,
                        child: Column(
                          children: [
                            Expanded(
                              child: PageView.builder(
                                itemCount: onBoardingController.onBoardingList.length,
                                controller: _pageController,
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return _buildAnimatedFirstScreen(context);
                                  }
                                  if (index == 1) {
                                    return _buildSecondScreen(context);
                                  }
                                  if (index == 2) {
                                    return _buildThirdScreen(context);
                                  }
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      onBoardingController.onBoardingList[index].imageUrl != ''
                                          ? Padding(
                                              padding: EdgeInsets.all(context.height * 0.05),
                                              child: Image.asset(
                                                onBoardingController.onBoardingList[index].imageUrl,
                                                height: context.height * 0.4,
                                              ),
                                            )
                                          : const SizedBox(),
                                      Text(
                                        onBoardingController.onBoardingList[index].title,
                                        style: robotoMedium.copyWith(
                                          fontSize: _headingSize(context),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: context.height * 0.025),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: Dimensions.paddingSizeLarge,
                                        ),
                                        child: Text(
                                          onBoardingController.onBoardingList[index].description,
                                          style: robotoRegular.copyWith(
                                            fontSize: _bodySize(context),
                                            color: Theme.of(context).disabledColor,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                                onPageChanged: (index) {
                                  onBoardingController.changeSelectIndex(index);

                                  if (index == 0) {
                                    _isOnFirstScreen = true;
                                    if (!_jiggleController.isAnimating) {
                                      _jiggleController.repeat(reverse: true);
                                    }
                                    _startAutoScroll();
                                    if (_exitController.status == AnimationStatus.completed) {
                                      _exitController.reset();
                                    }
                                  } else {
                                    _isOnFirstScreen = false;
                                    _stopAutoScroll();
                                  }

                                  if (index == 1) {
                                    _exitController.stop();
                                    _exitController.reset();
                                    Future.delayed(
                                      const Duration(milliseconds: 80),
                                      () {
                                        if (mounted) {
                                          _exitController.forward(from: 0.0);
                                        }
                                      },
                                    );
                                  }

                                  if (index == 2) {
                                    _jiggleController.reset();
                                    Future.delayed(
                                      const Duration(milliseconds: 100),
                                      () {
                                        if (_jiggleController.status != AnimationStatus.completed) {
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

                            // Progress dots — always exactly 3, no skip
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: _r<double>(context, mobile: 24, tab: 32, desktop: 36),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (index) {
                                  final isActive = onBoardingController.selectedIndex == index;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: isActive ? dotActiveW : dotInactiveW,
                                    height: dotH,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Theme.of(context).primaryColor
                                          : Theme.of(context).primaryColor.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(dotH / 2),
                                    ),
                                  );
                                }),
                              ),
                            ),
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
    final cardWidth = _cardWidth(context);
    final cardHeight = _cardHeight(context);
    final logoSz = _logoSize(context);
    final badgeSz = _badgeSize(context);

    // On larger screens the card strip sits relatively higher
    final cardStripTopRatio = _r<double>(context, mobile: 0.20, tab: 0.18, desktop: 0.16);
    // Text block starts lower on mobile (cards are big), closer on tablet/desktop
    final textTopRatio = _r<double>(context, mobile: 0.53, tab: 0.50, desktop: 0.48);
    // Logo end position — slightly higher on larger screens to clear more room
    final logoEndY = _r<double>(context, mobile: 50.0, tab: 60.0, desktop: 70.0);

    return AnimatedBuilder(
      animation: Listenable.merge([_entranceController, _jiggleController]),
      builder: (context, child) {
        final logoMoveProgress = Curves.easeOutCubic.transform(
          (_entranceController.value * 1.8).clamp(0.0, 1.0),
        );
        final logoStartY = screenHeight * 0.32;
        final logoY = logoStartY + (logoEndY - logoStartY) * logoMoveProgress;

        final cardsOpacity = Curves.easeOut.transform(
          ((_entranceController.value - 0.25) / 0.35).clamp(0.0, 1.0),
        );
        final textOpacity = Curves.easeOut.transform(
          ((_entranceController.value - 0.5) / 0.3).clamp(0.0, 1.0),
        );
        final buttonOpacity = Curves.easeOut.transform(
          ((_entranceController.value - 0.7) / 0.3).clamp(0.0, 1.0),
        );

        return Container(
          color: Colors.white,
          child: Stack(
            children: [
              // Single subtle brand accent — top-left only
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFF00ff9d).withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                      center: Alignment.topLeft,
                    ),
                  ),
                ),
              ),

              // Logo animates from center to top — fluid size
              Positioned(
                top: logoY,
                left: 0,
                right: 0,
                child: Center(
                  child: SvgPicture.asset(
                    "assets/on_boarding/Asset 11.svg",
                    fit: BoxFit.contain,
                    width: logoSz,
                    height: logoSz,
                  ),
                ),
              ),

              // Horizontally scrolling category cards — fluid width/height
              Positioned(
                top: screenHeight * cardStripTopRatio,
                left: 0,
                right: 0,
                height: cardHeight + 10,
                child: Opacity(
                  opacity: cardsOpacity,
                  child: ListView.builder(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: null, // truly infinite
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemBuilder: (context, index) {
                      final cardIndex = index % 4;

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
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: _cardColors[cardIndex % _cardColors.length],
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: badgeSz,
                                height: badgeSz,
                                decoration: BoxDecoration(
                                  color: _cardColors[cardIndex % _cardColors.length].withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _textColors[cardIndex % _textColors.length].withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _textColors[cardIndex % _textColors.length].withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
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
                              const SizedBox(height: 14),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  _cardLabels[cardIndex % _cardLabels.length],
                                  style: TextStyle(
                                    color: _textColors[cardIndex % _textColors.length],
                                    fontSize: _cardLabelSize(context),
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    letterSpacing: -0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _textColors[cardIndex % _textColors.length].withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _textColors[cardIndex % _textColors.length].withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  _getChipText(cardIndex),
                                  style: TextStyle(
                                    color: _textColors[cardIndex % _textColors.length],
                                    fontSize: _chipSize(context),
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

              // Title and subtitle — fluid text sizes, strong hierarchy
              Positioned(
                top: screenHeight * textTopRatio,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: textOpacity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _r<double>(context, mobile: 24, tab: 60, desktop: 80),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'onboarding_page1_title1'.tr,
                          textAlign: TextAlign.center,
                          style: robotoBold.copyWith(
                            fontSize: _headingSize(context),
                            color: Theme.of(context).primaryColor,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'onboarding_page1_title2'.tr,
                          textAlign: TextAlign.center,
                          style: robotoBold.copyWith(
                            fontSize: _subtitleSize(context),
                            color: Theme.of(context).secondaryHeaderColor,
                            height: 1.1,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Image.asset(
                          "assets/on_boarding/stroke.png",
                          width: _r<double>(context, mobile: 120, tab: 150, desktop: 160),
                          color: Theme.of(context).secondaryHeaderColor,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'onboarding_page1_description'.tr,
                          textAlign: TextAlign.center,
                          style: robotoRegular.copyWith(
                            fontSize: _bodySize(context),
                            color: Theme.of(context).disabledColor,
                            height: 1.5,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Next button — fluid margins
              Positioned(
                bottom: _r<double>(context, mobile: 30, tab: 40, desktop: 48),
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: buttonOpacity,
                  child: CustomButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    },
                    buttonText: 'onboarding_next'.tr,
                    icon: Icons.arrow_forward,
                    margin: _buttonMargin(context),
                    height: _r<double>(context, mobile: 50, tab: 56, desktop: 60),
                    fontSize: _r<double>(context, mobile: 18, tab: 20, desktop: 20),
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

    // Card size — large enough to read, will shrink into box
    final cardSz = _r<double>(context, mobile: 140, tab: 125, desktop: 115);
    final badgeSz = cardSz * 0.42;

    // Cards land at slightly staggered horizontal positions across screen top-half
    // Each card drops from above the screen to its landing Y, then gets sucked into box
    final List<double> landX = [
      screenWidth * 0.06,                     // far left
      screenWidth * 0.54,                     // right-center
      screenWidth * 0.28,                     // left-center
      screenWidth - cardSz - screenWidth * 0.06, // far right
    ];
    final double landY = screenHeight * 0.10; // all land near same Y row
    final List<double> landAngles = [-0.10, 0.08, -0.06, 0.12]; // final resting tilt

    // Box center — cards fly into here during suck phase
    final boxCX = screenWidth / 2 - cardSz / 2;
    final boxCY = screenHeight / 2 - cardSz / 2;

    // Delivery box width
    final boxHorizPadding = _r<double>(context, mobile: 60, tab: 100, desktop: 150);
    final boxW = (screenWidth - boxHorizPadding * 2).clamp(200.0, 500.0);
    final boxH = _r<double>(context, mobile: 220, tab: 240, desktop: 260);

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // Subtle brand accent
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withValues(alpha: 0.13),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                  center: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // ── 4 cards: fall from top → land → suck into box ──────────────
          ...List.generate(4, (i) {
            return AnimatedBuilder(
              animation: _exitController,
              builder: (context, _) {
                final p = _exitController.value;
                final fallStart = _cardIntervals[i]['fallStart']!;
                final fallEnd   = _cardIntervals[i]['fallEnd']!;
                final suckStart = _cardIntervals[i]['suckStart']!;
                final suckEnd   = _cardIntervals[i]['suckEnd']!;

                // ── FALL phase: card drops from above screen to landing spot ──
                final rawFall = ((p - fallStart) / (fallEnd - fallStart)).clamp(0.0, 1.0);
                // accelerate = real gravity (slow start, fast land)
                final fall = Curves.easeIn.transform(rawFall);

                final startAboveY = -cardSz - 20;
                final droppedX = landX[i];
                final droppedY = landY;

                // Tiny horizontal drift while falling (more natural)
                final driftX = (i.isEven ? -1.0 : 1.0) * 12.0 * (1.0 - fall);

                // ── SUCK phase: card flies from landing spot into box center ──
                final rawSuck = ((p - suckStart) / (suckEnd - suckStart)).clamp(0.0, 1.0);
                final suck = Curves.easeInBack.transform(rawSuck);

                // Position: blend between landed pos and box center
                final currentX = droppedX + driftX + (boxCX - droppedX) * suck;
                final currentY = startAboveY + (droppedY - startAboveY) * fall
                                 + (boxCY - droppedY) * suck;

                // Rotation: random tilt while falling, straightens to landAngle,
                //           then spins slightly as it gets sucked in
                final fallRotation = landAngles[i] * fall;
                final suckRotation = fallRotation + suck * 0.4 * (i.isEven ? 1 : -1);

                // Scale: 1.0 while falling and resting, shrinks fast during suck
                final scale = rawSuck < 0.0 ? 1.0 : (1.0 - suck * 0.95).clamp(0.05, 1.0);

                // Opacity: fade in as card appears, fade out at end of suck
                final fadeIn  = (rawFall * 4).clamp(0.0, 1.0);
                final fadeOut = rawSuck > 0.75 ? (1.0 - (rawSuck - 0.75) / 0.25).clamp(0.0, 1.0) : 1.0;
                final opacity = (fadeIn * fadeOut).clamp(0.0, 1.0);

                // Shadow strengthens on landing, fades during suck
                final shadowBlur = 8.0 + fall * 12.0 * (1.0 - suck);
                final shadowOp   = 0.10 + fall * 0.12 * (1.0 - suck);

                return Positioned(
                  left: currentX,
                  top: currentY,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: suckRotation,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: Container(
                          width: cardSz,
                          height: cardSz,
                          decoration: BoxDecoration(
                            color: _cardColors[i % _cardColors.length],
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.75),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _textColors[i % _textColors.length]
                                    .withValues(alpha: shadowOp),
                                blurRadius: shadowBlur,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: badgeSz,
                                height: badgeSz,
                                decoration: BoxDecoration(
                                  color: _cardColors[i % _cardColors.length]
                                      .withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _textColors[i % _textColors.length]
                                        .withValues(alpha: 0.30),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    _svgAssets[i % _svgAssets.length],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  _cardLabels[i % _cardLabels.length],
                                  style: robotoBold.copyWith(
                                    color: _textColors[i % _textColors.length],
                                    fontSize: 11,
                                    height: 1.15,
                                    letterSpacing: -0.2,
                                  ),
                                  textAlign: TextAlign.center,
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
                );
              },
            );
          }),

          // ── Delivery box — always visible; pulses each time a card enters it ──
          Center(
            child: AnimatedBuilder(
              animation: _exitController,
              builder: (context, _) {
                final p = _exitController.value;

                // For each card compute how far through its suck phase we are (0–1).
                // The box scale peaks at the midpoint of each card's suck, then
                // returns to 1.0 — giving a "filling" pulse per card.
                double boxScale = 1.0;
                for (int i = 0; i < 4; i++) {
                  final ss = _cardIntervals[i]['suckStart']!;
                  final se = _cardIntervals[i]['suckEnd']!;
                  if (p >= ss && p <= se) {
                    final t = (p - ss) / (se - ss); // 0→1 within this card's suck
                    // Triangle wave: rises 0→0.5, falls 0.5→1 → scale 1.0 → 1.035 → 1.0
                    final pulse = t < 0.5 ? t * 2 : (1.0 - t) * 2;
                    boxScale = 1.0 + pulse * 0.035;
                  }
                }

                // Box text content fades in after 60%
                final contentOpacity = ((p - 0.60) / 0.25).clamp(0.0, 1.0);

                // Bottom text block fades in after 70%
                final textOpacity = ((p - 0.70) / 0.22).clamp(0.0, 1.0);

                return Transform.scale(
                  scale: boxScale,
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
                          child: SizedBox(
                            width: boxW + boxHorizPadding * 2,
                            height: boxH,
                            child: Stack(
                              children: [
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
                        const SizedBox(height: 28),
                        Opacity(
                          opacity: textOpacity,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: _r<double>(context, mobile: 24, tab: 60, desktop: 100),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'onboarding_page2_title1'.tr,
                                  textAlign: TextAlign.center,
                                  style: robotoBold.copyWith(
                                    fontSize: _headingSize(context),
                                    color: Theme.of(context).primaryColor,
                                    height: 1.15,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'onboarding_page2_title2'.tr,
                                  textAlign: TextAlign.center,
                                  style: robotoBold.copyWith(
                                    fontSize: _subtitleSize(context),
                                    color: Theme.of(context).secondaryHeaderColor,
                                    height: 1.15,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Image.asset(
                                  "assets/on_boarding/stroke.png",
                                  width: _r<double>(context, mobile: 120, tab: 150, desktop: 160),
                                  color: Theme.of(context).secondaryHeaderColor,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'onboarding_page2_description'.tr,
                                  textAlign: TextAlign.center,
                                  style: robotoRegular.copyWith(
                                    fontSize: _bodySize(context),
                                    color: Theme.of(context).disabledColor,
                                    height: 1.55,
                                    letterSpacing: 0.1,
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

          // Next button
          Positioned(
            bottom: _r<double>(context, mobile: 40, tab: 48, desktop: 56),
            left: 0,
            right: 0,
            child: CustomButton(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              buttonText: 'onboarding_next'.tr,
              color: Theme.of(context).primaryColor,
              icon: Icons.arrow_forward,
              margin: _buttonMargin(context),
              height: _r<double>(context, mobile: 50, tab: 56, desktop: 60),
              fontSize: _r<double>(context, mobile: 18, tab: 20, desktop: 20),
              isBold: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThirdScreen(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Constrain Lottie on tablet/desktop — full size on phone is fine,
    // but on a 1300px desktop it would be comically oversized
    final lottieSize = _r<double>(context, mobile: double.infinity, tab: 600, desktop: 700);
    final lottieW = lottieSize == double.infinity ? screenWidth : lottieSize.clamp(0.0, screenWidth);
    final lottieH = lottieSize == double.infinity ? screenHeight : (lottieSize * 0.85).clamp(0.0, screenHeight);

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // Lottie animation — constrained on large screens
          Center(
            child: Lottie.asset(
              'assets/on_boarding/home (1).json',
              width: lottieW,
              height: lottieH,
              fit: BoxFit.contain,
            ),
          ),

          // Single subtle brand accent — top-right
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF00ff9d).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                  center: Alignment.topRight,
                ),
              ),
            ),
          ),

          // Falling box with text
          AnimatedBuilder(
            animation: _jiggleController,
            builder: (context, child) {
              final fallProgress = _jiggleController.value;
              final easedProgress = Curves.elasticOut.transform(fallProgress);

              const startY = -150.0;
              final endY = screenHeight * _r<double>(context, mobile: 0.42, tab: 0.40, desktop: 0.38);
              final currentY = startY + (endY - startY) * easedProgress;

              final boxScale = _r<double>(context, mobile: 0.25, tab: 0.22, desktop: 0.20);
              final rotation = (1 - easedProgress) * 0.3;

              final textOpacity = fallProgress > 0.65
                  ? ((fallProgress - 0.65) / 0.2).clamp(0.0, 1.0)
                  : 0.0;

              return Stack(
                children: [
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
                            margin: const EdgeInsets.symmetric(horizontal: 60),
                            width: screenWidth - 120,
                            height: 220,
                            child: Stack(
                              children: [
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
                  Positioned(
                    bottom: _r<double>(context, mobile: 110, tab: 120, desktop: 130),
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: textOpacity,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _r<double>(context, mobile: 30, tab: 80, desktop: 120),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'onboarding_page3_title'.tr,
                              textAlign: TextAlign.center,
                              style: robotoBold.copyWith(
                                fontSize: _headingSize(context),
                                color: Theme.of(context).primaryColor,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'onboarding_page3_description'.tr,
                              textAlign: TextAlign.center,
                              style: robotoRegular.copyWith(
                                fontSize: _bodySize(context),
                                color: Theme.of(context).disabledColor,
                                height: 1.55,
                                letterSpacing: 0.1,
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

          // Get Started button — fluid size and margins
          Positioned(
            bottom: _r<double>(context, mobile: 40, tab: 48, desktop: 56),
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _jiggleController,
              builder: (context, child) {
                final buttonOpacity = _jiggleController.value > 0.65
                    ? ((_jiggleController.value - 0.65) / 0.2).clamp(0.0, 1.0)
                    : 0.0;
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
                      margin: _buttonMargin(context),
                      height: _r<double>(context, mobile: 50, tab: 56, desktop: 60),
                      fontSize: _r<double>(context, mobile: 18, tab: 20, desktop: 20),
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
             color: Colors.white.withValues(alpha: 0.9),
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

    final boxWidth = size.width - 120;
    const boxHeight = 200.0;
    const boxLeft = 60.0;
    final boxTop = (size.height - boxHeight) / 2;

    paint.color = primaryColor;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
      const Radius.circular(30),
    );
    canvas.drawRRect(boxRect, paint);

    paint.color = Color.lerp(primaryColor, Colors.black, 0.2)!;
    final flapPath = Path();
    flapPath.moveTo(boxLeft + 30, boxTop);
    flapPath.lineTo(boxLeft + boxWidth * 0.3, boxTop - 20);
    flapPath.lineTo(boxLeft + boxWidth * 0.7, boxTop - 20);
    flapPath.lineTo(boxLeft + boxWidth - 30, boxTop);
    flapPath.close();
    canvas.drawPath(flapPath, paint);

    paint.color = accentColor;
    final tapeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxLeft, boxTop + boxHeight * 0.4, boxWidth, 40),
      const Radius.circular(5),
    );
    canvas.drawRRect(tapeRect, paint);

    paint.color = Colors.teal.withValues(alpha: 0.3);
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

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4;
    paint.color = accentColor;
    canvas.drawRRect(boxRect, paint);

    const iconSize = 50.0;
    final iconLeft = boxLeft + (boxWidth - iconSize) / 2;
    final iconTop = boxTop + 20;

    paint.style = PaintingStyle.fill;
    paint.color = accentColor.withValues(alpha: 0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(iconLeft, iconTop, iconSize, iconSize),
        const Radius.circular(8),
      ),
      paint,
    );

    if (contentOpacity > 0) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white.withValues(alpha: contentOpacity),
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
