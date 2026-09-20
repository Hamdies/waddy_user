import 'dart:async';
import 'dart:math';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/onboard/controllers/onboard_controller.dart';
import 'package:waddy_app/helper/guest_bootstrap_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

// Concept-style card palette — neutral near-white surface with dark ink,
// like the reference shopping-list cards (not the brand mint).
const Color _cardInk = Color(0xFF17181A); // near-black title

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  /// Ambient float loop behind screen 1's hero card. Loops for as long as
  /// screen 1 is visible.
  late AnimationController _jiggleController;

  /// One-shot entrance for screen 3 (box slide + copy + CTA fades).
  late AnimationController _thirdScreenController;

  late AnimationController _exitController;

  late List<Map<String, double>> _cardIntervals;
  late AnimationController _entranceController;

  // Per-card slight timing variance for screen 2 (seeded once so it stays
  // stable across rebuilds within a session, but differs launch to launch).
  // Cards fall straight down from above, one at a time, then settle into
  // the box and stop — independent of the box/text entrance.
  final Random _fallRandom = Random();
  late List<double>
  _fallDurationScale; // small per-card speed variance so falls aren't identical
  late AnimationController
  _cardFallController; // plays once per visit to screen 2, decoupled from _exitController

  // Drives the single hero card as it morphs from one topic to the next.
  late AnimationController _morphController;
  Timer? _morphTimer;
  int _topicIndex = 0;

  bool _isOnFirstScreen = true;
  bool _isBootstrapping = false;
  bool _reduceMotion = false;

  final List<String> _svgAssets = [
    "assets/on_boarding/coffee.png",
    "assets/on_boarding/burger.png",
    "assets/on_boarding/pets.png",
  ];

  // ─── Hero card topics ─────────────────────────────────────────────────────
  // The first screen shows ONE mint card that morphs between these topics.
  // Every topic shares the same mint surface and dark-teal accent; only the
  // title/subtitle/icon/images change. Images repeat the existing asset for
  // now — swap `headerIcon` / `itemImages` for real photos later.
  List<_OnboardTopic> get _topics => [
    _OnboardTopic(
      title: 'onboarding_card_fresh_title'.tr,
      subtitle: 'onboarding_card_fresh_subtitle'.tr,
      count: 6,
      daysAgo: 3,
      headerIcon: Icons.local_grocery_store_rounded,
      itemImages: const ['assets/on_boarding/fresh_market.png'],
    ),
    _OnboardTopic(
      title: 'onboarding_card_burger_title'.tr,
      subtitle: 'onboarding_card_burger_subtitle'.tr,
      count: 12,
      daysAgo: 2,
      headerIcon: Icons.local_grocery_store_rounded,
      itemImages: const ['assets/on_boarding/burger.png'],
    ),
    _OnboardTopic(
      title: 'onboarding_card_coffee_title'.tr,
      subtitle: 'onboarding_card_coffee_subtitle'.tr,
      count: 8,
      daysAgo: 1,
      headerIcon: Icons.restaurant_rounded,
      itemImages: const ['assets/on_boarding/coffee.png'],
    ),
    _OnboardTopic(
      title: 'onboarding_card_pet_title'.tr,
      subtitle: 'onboarding_card_pet_subtitle'.tr,
      count: 8,
      daysAgo: 1,
      headerIcon: Icons.pets_rounded,
      itemImages: const ['assets/on_boarding/pets.png'],
    ),
    _OnboardTopic(
      title: 'onboarding_card_italian_title'.tr,
      subtitle: 'onboarding_card_italian_subtitle'.tr,
      count: 6,
      daysAgo: 3,
      headerIcon: Icons.restaurant_rounded,
      itemImages: const ['assets/on_boarding/italy_home.png'],
    ),
  ];

  List<String> get _cardLabels {
    return [
      'screen_1_kitchen_essentials'.tr,
      'screen_1_pet_essentials'.tr,
      'screen_1_favorite_food'.tr,
      'screen_1_xp_points_rewards'.tr,
    ];
  }

  // ─── Responsive helpers ───────────────────────────────────────────────────

  /// Returns a value interpolated across mobile → tablet → desktop.
  /// Pass the three breakpoint values; the helper picks based on screen width.
  T _r<T>(
    BuildContext context, {
    required T mobile,
    required T tab,
    required T desktop,
  }) {
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

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    Get.find<OnBoardingController>().getOnBoardingList();

    // Ambient float loop for screen 1's hero card. Deliberately slow — this
    // one wants to read as "gentle", so it keeps its original pace.
    _jiggleController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    // Screen 3's one-shot entrance. Previously this shared _jiggleController
    // with screen 1's ambient float, which meant the two could not be tuned
    // independently: the entrance inherited the float's slow 3500ms, so the
    // copy only began fading at ~1.9s and the CTA finished at ~3.0s. Split
    // out and shortened so the text and button arrive quickly.
    _thirdScreenController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // One-shot entrance for the box + its text — plays once, independent of
    // the cards, so the text always fades in on its own normal schedule.
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // One-shot controller that drives all 3 falling cards, staggered, then
    // stops once the last card has landed — decoupled from the one-shot
    // box/text entrance, but no longer loops.
    //
    // Shortened further for 3 cards (was 2200ms for 4). The stagger below
    // finishes its last landing at ~1.0, so the duration is trimmed with it
    // to avoid leaving dead time where the controller keeps ticking with
    // nothing left to animate.
    _cardFallController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fallDurationScale = List.generate(
      3,
      (_) => 0.92 + _fallRandom.nextDouble() * 0.16,
    ); // 0.92x–1.08x speed

    // Fall schedule (normalized 0–1 over the run): each card drifts down into
    // the box one at a time. The stagger is tightened so at most two cards
    // are ever airborne at once — previously up to three overlapped, which
    // tripled the simultaneous transform+opacity layers mid-run and is the
    // main reason this screen felt heavier than screen 3 (which only ever
    // animates a single element).
    // With only 3 cards, the last one starts at 0.44 and lands by ~0.79 even
    // at the slowest per-card scale (0.44 + 0.32*1.08), leaving a brief
    // settled beat before the run ends rather than a hard cutoff.
    _cardIntervals = List.generate(3, (index) {
      final fallStart = index * 0.22;
      final fallEnd = fallStart + 0.32 * _fallDurationScale[index];
      return {'fallStart': fallStart, 'fallEnd': fallEnd};
    });

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Cross-fade / slide the hero card between topics.
    _morphController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
  }

  bool _motionSetupDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (String asset in _svgAssets) {}

    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!_motionSetupDone) {
      _motionSetupDone = true;
      if (_reduceMotion) {
        // Skip straight to each animation's resting/settled state instead of
        // playing the motion — same convention as order_details_screen.dart.
        _entranceController.value = 1.0;
        _thirdScreenController.value = 1.0;
        if (_isOnFirstScreen) {
          _startMorphCycle();
        }
      } else {
        _jiggleController.repeat(reverse: true);
        _entranceController.forward();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startMorphCycle();
        });
      }
    }
  }

  @override
  void dispose() {
    _jiggleController.dispose();
    _thirdScreenController.dispose();
    _exitController.dispose();
    _cardFallController.dispose();
    _entranceController.dispose();
    _morphController.dispose();
    _morphTimer?.cancel();
    super.dispose();
  }

  // Every few seconds, advance to the next topic and play the morph. The
  // outgoing topic stays painted until the transition finishes so the two
  // cross-fade instead of blinking.
  void _startMorphCycle() {
    _morphTimer?.cancel();
    _morphTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted || !_isOnFirstScreen) return;
      _advanceTopic();
    });
  }

  void _advanceTopic() {
    if (_reduceMotion) {
      // Still cycle topics (informational), just skip the cross-fade tween.
      setState(() {
        _topicIndex = (_topicIndex + 1) % _topics.length;
      });
      return;
    }
    _morphController.forward(from: 0.0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _topicIndex = (_topicIndex + 1) % _topics.length;
      });
      _morphController.value = 0.0;
    });
  }

  void _stopMorphCycle() {
    _morphTimer?.cancel();
    _morphTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null,
      body: SafeArea(
        child: GetBuilder<OnBoardingController>(
          builder: (onBoardingController) {
            return onBoardingController.onBoardingList.isNotEmpty
                ? SafeArea(
                  child: Center(
                    child: SizedBox(
                      width: Dimensions.maxContentWidth,
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              Expanded(
                                child: PageView.builder(
                                  itemCount:
                                      onBoardingController
                                          .onBoardingList
                                          .length,
                                  controller: _pageController,
                                  scrollDirection: Axis.horizontal,
                                  physics:
                                      onBoardingController.selectedIndex ==
                                              onBoardingController
                                                      .onBoardingList
                                                      .length -
                                                  1
                                          ? const NeverScrollableScrollPhysics()
                                          : const AlwaysScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return _buildAnimatedFirstScreen(
                                        context,
                                        onBoardingController
                                            .onBoardingList
                                            .length,
                                      );
                                    }
                                    if (index == 1) {
                                      return _buildSecondScreen(context);
                                    }
                                    if (index == 2) {
                                      return _buildThirdScreen(context);
                                    }
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
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
                                          style: waddyMedium.copyWith(
                                            fontSize: _headingSize(context),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(
                                          height: context.height * 0.025,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                Dimensions.paddingSizeLarge,
                                          ),
                                          child: Text(
                                            onBoardingController
                                                .onBoardingList[index]
                                                .description,
                                            style: waddyRegular.copyWith(
                                              fontSize: _bodySize(context),
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).disabledColor,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                  onPageChanged: (index) {
                                    onBoardingController.changeSelectIndex(
                                      index,
                                    );

                                    if (index == 0) {
                                      _isOnFirstScreen = true;
                                      if (_reduceMotion) {
                                        _jiggleController.stop();
                                        _jiggleController.value = 0.0;
                                      } else if (!_jiggleController
                                          .isAnimating) {
                                        _jiggleController.repeat(reverse: true);
                                      }
                                      _startMorphCycle();
                                      if (_exitController.status ==
                                          AnimationStatus.completed) {
                                        _exitController.reset();
                                      }
                                    } else {
                                      _isOnFirstScreen = false;
                                      _stopMorphCycle();
                                    }

                                    if (index == 1) {
                                      _exitController.stop();
                                      _cardFallController.stop();
                                      if (_reduceMotion) {
                                        _exitController.value = 1.0;
                                        _cardFallController.value = 1.0;
                                      } else {
                                        _exitController.reset();
                                        _cardFallController.reset();
                                        _cardFallController.forward();
                                        Future.delayed(
                                          const Duration(milliseconds: 80),
                                          () {
                                            if (mounted) {
                                              _exitController.forward(
                                                from: 0.0,
                                              );
                                            }
                                          },
                                        );
                                      }
                                    } else {
                                      _cardFallController.stop();
                                    }

                                    if (index == 2) {
                                      if (_reduceMotion) {
                                        _thirdScreenController.value = 1.0;
                                      } else {
                                        // Starts immediately — the old 100ms
                                        // delay just added dead time before
                                        // anything on the screen moved.
                                        _thirdScreenController.forward(
                                          from: 0.0,
                                        );
                                      }
                                    }

                                    if (onBoardingController.selectedIndex ==
                                        3) {
                                      _configureToRouteInitialPage();
                                    }
                                  },
                                ),
                              ),
                            ],
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

  /// A single mint card that cross-fades + slides between topics. The card
  /// shell (surface, border, radius, shadow) stays put while its contents
  /// morph, so it reads as one card changing rather than a swap.
  Widget _buildMorphingCard(BuildContext context) {
    final topics = _topics;
    final current = topics[_topicIndex];
    final next = topics[(_topicIndex + 1) % topics.length];

    final t = Curves.easeInOut.transform(_morphController.value);

    // Content cross-fade: outgoing leaves in the first half, incoming enters
    // in the second half, with a wide overlap so combined opacity never dips
    // to near-zero in the middle (previously both layers bottomed out around
    // t=0.5, leaving the headline nearly invisible for a beat).
    final outOpacity = (1.0 - t / 0.7).clamp(0.0, 1.0);
    final inOpacity = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
    final outShift = -18.0 * t; // outgoing drifts up
    final inShift = 18.0 * (1.0 - t); // incoming rises into place

    final cardW = _r<double>(
      context,
      mobile: 360.0,
      tab: 520.0,
      desktop: 620.0,
    );
    final cardH = _r<double>(
      context,
      mobile: 280.0,
      tab: 340.0,
      desktop: 380.0,
    );
    const cardRadius = 30.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: cardW,
          height: cardH,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 32,
          ),
          decoration: BoxDecoration(
            color: Spots.mint, // near-white card surface
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: WaddyColors.primary, width: 3),
            boxShadow: [
              BoxShadow(
                color: WaddyColors.primary.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cardRadius - 3),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Opacity(
                        opacity: outOpacity,
                        child: Transform.translate(
                          offset: Offset(0, outShift),
                          child: _topicContent(context, current, cardH),
                        ),
                      ),
                      Opacity(
                        opacity: inOpacity,
                        child: Transform.translate(
                          offset: Offset(0, inShift),
                          child: _topicContent(context, next, cardH),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Brand mark — handle style badge above the top of the card.
        const PositionedDirectional(
          top: -60,
          end: 18,
          start: 18,
          child: _CardBrandMark(),
        ),
      ],
    );
  }

  /// Concept-card layout: a bold centered title, a muted subtitle, and a
  /// large single image bleeding to the bottom edge of the card.
  Widget _topicContent(
    BuildContext context,
    _OnboardTopic topic,
    double cardH,
  ) {
    return SizedBox(
      height: cardH - 20, // matches the card's top padding
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeSmall,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      topic.title,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: waddyBold.copyWith(
                        fontSize: 34,
                        color: _cardInk,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      topic.subtitle,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: waddyRegular.copyWith(
                        fontSize: 16,
                        color: _cardInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _scatteredImages(topic.itemImages, cardH),
          ),
        ],
      ),
    );
  }

  /// Renders the single onboarding image, sized to dominate the lower part
  /// of the card. Source images vary in aspect ratio, so the box always
  /// bottom-aligns the visible content instead of letting `contain` center
  /// it with uneven whitespace above/below.
  Widget _scatteredImages(List<String> images, double cardH) {
    if (images.isEmpty) return const SizedBox.shrink();

    final tileH = cardH * 0.75;
    final imageAsset = images.first;

    return SizedBox(
      width: double.infinity,
      height: tileH,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Image.asset(
          imageAsset,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
        ),
      ),
    );
  }

  /// Title2 with one word ("Cravings" in English) given a hand-drawn stroke
  /// underline that pops in, tied to the entrance timeline. Falls back to a
  /// single plain Text for locales where the source string can't be split
  /// this way (e.g. Arabic word order/structure differs).
  Widget _buildTitle2(BuildContext context) {
    final raw = 'onboarding_page1_title2'.tr;
    const highlight = 'Cravings';
    final style = waddyBold.copyWith(
      fontSize: _headingSize(context),
      color: Theme.of(context).primaryColor,
      height: 1.15,
      letterSpacing: -0.5,
    );

    final idx = raw.indexOf(highlight);
    if (Get.locale?.languageCode == 'ar' || idx == -1) {
      return Text(raw, textAlign: TextAlign.center, style: style);
    }

    final before = raw.substring(0, idx);
    final after = raw.substring(idx + highlight.length);

    // Draw the stroke in left-to-right slightly after the rest of the line
    // fades in, like it's being sketched under the word in real time.
    final strokeT = Curves.easeOutCubic.transform(
      ((_entranceController.value - 0.6) / 0.3).clamp(0.0, 1.0),
    );
    final strokeWidth = _r<double>(
      context,
      mobile: 130,
      tab: 165,
      desktop: 190,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: before, style: style),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(highlight, style: style),
                PositionedDirectional(
                  bottom: -14,
                  start: 0,
                  end: 0,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ClipRect(
                      clipper: _FractionalWidthClipper(strokeT),
                      child: Image.asset(
                        'assets/on_boarding/stroke.png',
                        width: strokeWidth,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextSpan(text: after, style: style),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAnimatedFirstScreen(BuildContext context, int pageCount) {
    final screenHeight = MediaQuery.of(context).size.height;
    final logoSz = _logoSize(context);

    // Card sits below the logo; text block below the card. Text sits a touch
    // lower than before now that the progress dots are gone, so the button
    // doesn't feel stranded far below the description.
    final cardTopRatio = _r<double>(
      context,
      mobile: 0.18,
      tab: 0.17,
      desktop: 0.15,
    );
    final textTopRatio = _r<double>(
      context,
      mobile: 0.56,
      tab: 0.56,
      desktop: 0.54,
    );
    final logoEndY = _r<double>(
      context,
      mobile: 50.0,
      tab: 60.0,
      desktop: 70.0,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([
        _entranceController,
        _jiggleController,
        _morphController,
      ]),
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

        // Gentle floating of the whole card.
        final floatOffset =
            sin(Curves.easeInOut.transform(_jiggleController.value) * pi * 2) *
            4.0;

        return Container(
          color: Colors.white,
          child: Stack(
            children: [
              // Logo animates from center to top — fluid size

              // Skip — secondary action, kept quiet (muted text, no fill) so
              // it doesn't compete with "Next" for attention. Jumps straight
              // to the last onboarding page rather than ending the flow
              // outright, so Get Started/permissions are still surfaced.
              PositionedDirectional(
                top: 8,
                end: 8,
                child: SafeArea(
                  bottom: false,
                  child: Opacity(
                    opacity: buttonOpacity,
                    child: TextButton(
                      onPressed: () {
                        _pageController.animateToPage(
                          pageCount - 1,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).disabledColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        'onboarding_skip'.tr,
                        style: waddyRegular.copyWith(
                          fontSize: _bodySize(context),
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Single hero card that morphs between topics
              Positioned(
                top: screenHeight * cardTopRatio,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: cardsOpacity,
                  child: Transform.translate(
                    offset: Offset(0, floatOffset),
                    child: Center(child: _buildMorphingCard(context)),
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
                      horizontal: _r<double>(
                        context,
                        mobile: 24,
                        tab: 60,
                        desktop: 80,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'onboarding_page1_title1'.tr,
                          textAlign: TextAlign.center,
                          style: waddyMedium.copyWith(
                            fontSize: 26,
                            color: Theme.of(context).primaryColor,
                            height: 1.8,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildTitle2(context),
                        const SizedBox(height: 22),
                        Text(
                          'onboarding_page1_description'.tr,
                          textAlign: TextAlign.center,
                          style: waddyRegular.copyWith(
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
                bottom: _r<double>(context, mobile: 60, tab: 52, desktop: 60),
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
                    height: _r<double>(
                      context,
                      mobile: 50,
                      tab: 56,
                      desktop: 60,
                    ),
                    fontSize: _r<double>(
                      context,
                      mobile: 18,
                      tab: 20,
                      desktop: 20,
                    ),
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

    // Card size — bigger and bolder, easy to read as it falls
    final cardSz = _r<double>(context, mobile: 168, tab: 150, desktop: 138);

    // Delivery box width
    final boxHorizPadding = _r<double>(
      context,
      mobile: 36,
      tab: 80,
      desktop: 130,
    );
    final boxW = (screenWidth - boxHorizPadding * 2).clamp(240.0, 560.0);
    final boxH = _r<double>(context, mobile: 270, tab: 290, desktop: 310);

    // The box+text block is anchored from a fixed top offset (not centered
    // via Column+Center) so its on-screen position is known exactly — the
    // falling cards below target this same boxTop, guaranteeing they land
    // inside the box instead of drifting past it toward screen-center.
    final boxTop =
        _r<double>(context, mobile: 0.24, tab: 0.22, desktop: 0.20) *
        screenHeight;
    final boxCX = screenWidth / 2 - cardSz / 2;
    final boxCY = boxTop + boxH / 2 - cardSz / 2;

    // Each card starts off-screen above, directly over the box, and falls
    // straight down into it — one card at a time, in sequence.
    final startY = -cardSz - 20;

    // Built once per layout, not per frame. The block only ever fades, and a
    // FadeTransition drives that opacity on the compositor from the existing
    // animation — so the three Text widgets (each of which does a `.tr`
    // lookup, a style copyWith, and a full text layout) are constructed once
    // instead of 60x/sec while the cards are falling.
    final textBlock = FadeTransition(
      opacity: CurvedAnimation(
        parent: _exitController,
        // Matches the previous hand-rolled ramp: starts at p=0.25 and
        // completes by p=0.85, eased out.
        curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _r<double>(context, mobile: 24, tab: 60, desktop: 100),
        ),
        child: Column(
          children: [
            Text(
              'onboarding_page2_title1'.tr,
              textAlign: TextAlign.center,
              style: waddyBold.copyWith(
                fontSize: _headingSize(context) * 1.15,
                color: Theme.of(context).primaryColor,
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'onboarding_page2_title2'.tr,
              textAlign: TextAlign.center,
              style: waddyBold.copyWith(
                fontSize: _subtitleSize(context) * 1.15,
                color: Theme.of(context).primaryColor,
                height: 1.15,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'onboarding_page2_description'.tr,
              textAlign: TextAlign.center,
              style: waddyRegular.copyWith(
                fontSize: _bodySize(context) * 1.15,
                color: Theme.of(context).disabledColor,
                height: 1.55,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // ── 3 cards: fall straight down into the box, one at a time, then
          // settle and stop — independent of the box/text entrance below ──
          //
          // Each card's visual body is built ONCE (as the AnimatedBuilder's
          // `child`) and only transformed per frame. Previously the whole
          // subtree — decoration, blurred shadow, ClipRRect, FittedBox text
          // layout, image — was reconstructed per card every frame, which is
          // what made this screen stutter. Now the per-frame work is a single
          // Transform + a FadeTransition-equivalent on an already-built tree.
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _cardFallController,
              child: _FallingCard(
                size: cardSz,
                label: _cardLabels[i % _cardLabels.length],
                imageAsset: _svgAssets[i % _svgAssets.length],
              ),
              builder: (context, cardChild) {
                final p = _cardFallController.value;
                final fallStart = _cardIntervals[i]['fallStart']!;
                final fallEnd = _cardIntervals[i]['fallEnd']!;

                // Gentle ease-in-out fall — no gravity physics, no bounce,
                // just a soft glide from above the screen into the box.
                final rawFall = ((p - fallStart) / (fallEnd - fallStart)).clamp(
                  0.0,
                  1.0,
                );

                // Once a card has fully landed it is invisible (fadeOut hits
                // 0 at rawFall == 1) and never moves again, so drop it out of
                // the tree entirely instead of transforming a hidden subtree
                // for the rest of the run. Same for cards that haven't
                // started falling yet.
                //
                // The per-landing HapticFeedback.lightImpact() that used to
                // fire here is gone. It is a synchronous platform-channel hop
                // into native code, and it fired four times at exactly the
                // moments other cards were mid-flight — on Android the
                // vibrator call can block long enough to drop the frame.
                // Fade-out completes at 0.88, so anything past that is a
                // fully transparent card being transformed for nothing.
                if (rawFall <= 0.0 || rawFall >= 0.88) {
                  return const SizedBox.shrink();
                }

                // easeOutCubic, not easeInOutQuad. An entering element must
                // start fast: ease-in-out holds the card almost still for the
                // first third of its travel, which reads as lag even though
                // the frame budget is identical. Ease-out puts the movement
                // where the eye is already looking and lets it settle into
                // the box, so the same 1800ms run feels markedly quicker.
                final fall = Curves.easeOutCubic.transform(rawFall);

                // The airborne wobble is gone. It was a 7-cycle sine per card
                // per frame whose peak amplitude is 2.5px on a 168px card —
                // invisible in motion, but it forced a horizontal offset that
                // changed every single frame, so no card could ever hold a
                // stable raster. Cards now fall on a clean vertical line.
                final currentX = boxCX;
                final currentY = startY + (boxCY - startY) * fall;

                // Scale: full size while falling, shrinking into the box on
                // arrival — but only to 0.45, not 0.15. Nothing in the real
                // world shrinks to a speck before vanishing, and the old
                // range spent its last frames re-rasterizing a card so small
                // its border and shadow were sub-pixel noise.
                final scale = (1.0 - fall * 0.55).clamp(0.45, 1.0);

                // Opacity: fades in softly as it appears, and is fully gone by
                // the time it reaches the box mouth (0.88 rather than 1.0) so
                // the card never lingers as a barely-visible smudge.
                final fadeIn = (rawFall * 4).clamp(0.0, 1.0);
                final fadeOut =
                    rawFall > 0.62
                        ? (1.0 - (rawFall - 0.62) / 0.26).clamp(0.0, 1.0)
                        : 1.0;
                final opacity = (fadeIn * fadeOut).clamp(0.0, 1.0);

                // A single Transform node carries both the translate and the
                // centre-origin scale — one matrix, one layer — rather than
                // animating Positioned's left/top (which dirties the parent
                // Stack's layout every frame) with a Transform.scale on top.
                return Positioned(
                  left: 0,
                  top: 0,
                  // Opacity sits ABOVE the Transform, not below it. When it
                  // wrapped the card directly, RenderOpacity's layer was the
                  // transform's child and every frame re-composited a scaled,
                  // shadow-casting subtree. Hoisted here it applies to the
                  // already-transformed layer, so the card rasterizes once
                  // (via the RepaintBoundary inside _FallingCard) and both
                  // the matrix and the alpha are pure compositor work.
                  child: Opacity(
                    opacity: opacity,
                    child: Transform(
                      transform:
                          Matrix4.identity()
                            ..translateByDouble(currentX, currentY, 0.0, 1.0)
                            ..scaleByDouble(scale, scale, 1.0, 1.0),
                      // Scale about the card's own centre, matching the previous
                      // Transform.scale(alignment: Alignment.center). The
                      // translate above is unaffected: RenderTransform composes
                      // this as T(c)·M·T(-c), and the leading translation in M
                      // commutes out to leave translate-then-centre-scale.
                      alignment: Alignment.center,
                      child: cardChild,
                    ),
                  ),
                );
              },
            );
          }),
          // ── Delivery box — always visible; pulses each time a card enters it ──
          Positioned(
            top: boxTop,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nothing here listens to _exitController any more. The box
                  // and its copy are a fully static subtree; the entrance
                  // fade is a FadeTransition below, and the landing bounce is
                  // _LandingPulse's own transform. Both are compositor-only,
                  // so the CustomPaint rasterizes exactly once per visit.
                  _LandingPulse(
                    fall: _cardFallController,
                    intervals: _cardIntervals,
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _exitController,
                        // Matches the old hand-rolled contentOpacity ramp:
                        // eased-out over the first 60% of the entrance.
                        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                      ),
                      child: CustomPaint(
                        painter: DeliveryBoxPainter(
                          primaryColor: Theme.of(context).primaryColor,
                          accentColor: Theme.of(context).secondaryHeaderColor,
                          svgAssetPath: 'assets/on_boarding/Asset 11.svg',
                          isArabic: Get.locale?.languageCode == 'ar',
                          text1: 'delivery_box_you_need_it'.tr,
                          text2: 'delivery_box_we_speed_it'.tr,
                        ),
                        child: Builder(
                          builder: (context) {
                            final paintedBoxHeight = boxH * 0.78;
                            final iconScale = paintedBoxHeight / 200.0;
                            final iconSize = 50.0 * iconScale;
                            final paintedBoxTop = (boxH - paintedBoxHeight) / 2;
                            final iconTop = paintedBoxTop + 20 * iconScale;

                            return SizedBox(
                              width: boxW + boxHorizPadding * 2,
                              height: boxH,
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: iconTop,
                                    left: 0,
                                    right: 0,
                                    height: iconSize,
                                    child: Center(
                                      child: Image.asset(
                                        'assets/image/logo_no_bg.png',
                                        width: iconSize * 0.9,
                                        height: iconSize * 0.9,
                                        fit: BoxFit.contain,
                                        color:
                                            Theme.of(
                                              context,
                                            ).secondaryHeaderColor,
                                        colorBlendMode: BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  textBlock,
                ],
              ),
            ),
          ),

          // Next button
          Positioned(
            bottom: _r<double>(context, mobile: 40, tab: 52, desktop: 60),
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
    final lottieSize = _r<double>(
      context,
      mobile: double.infinity,
      tab: 600,
      desktop: 700,
    );
    final lottieW =
        lottieSize == double.infinity
            ? screenWidth
            : lottieSize.clamp(0.0, screenWidth);
    final lottieH =
        lottieSize == double.infinity
            ? screenHeight
            : (lottieSize * 0.85).clamp(0.0, screenHeight);

    // The box is bottom-anchored (like the title block and button below it)
    // instead of top-positioned from a guessed screen fraction — anchoring
    // to the same edge the text uses guarantees clearance by construction:
    // box bottom-anchor = title's own bottom-anchor + title block's reserved
    // height + a fixed gap, so it always sits above the text with room to
    // spare, regardless of screen size or text wrapping.
    final endScale = _r<double>(context, mobile: 0.26, tab: 0.23, desktop: 0.2);
    final titleBlockBottom = _r<double>(
      context,
      mobile: 110,
      tab: 120,
      desktop: 130,
    );
    final titleBlockReservedHeight = _r<double>(
      context,
      mobile: 130,
      tab: 145,
      desktop: 160,
    );
    const boxToTextGap = 20.0;
    final boxRestBottom =
        titleBlockBottom + titleBlockReservedHeight + boxToTextGap;

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

          // Box slides in diagonally from off-screen like it's being set
          // down by hand — tilted on approach, leveling out and settling
          // into place as it arrives, instead of a straight vertical drop.
          AnimatedBuilder(
            animation: _thirdScreenController,
            // Built once and reused every tick — the SVG badge and its
            // container never change while the box slides/settles, so
            // reparsing/reconstructing them ~60x during the ~3.5s entrance
            // was pure waste (SvgPicture in particular is costlier to
            // rebuild than a raster image).
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
            builder: (context, boxChild) {
              final placeProgress = _thirdScreenController.value;
              // Approach phase (0–0.45): eased slide in from the side while
              // tilted. Settle phase (0.40–1.0): rotation springs level and
              // scale overshoots slightly before resting — sells the sense
              // of the box being placed down by hand.
              //
              // The approach was compressed from 0.65 so the box is home
              // early and the copy/CTA below can come in over the tail of
              // the settle rather than queueing up behind the whole slide.
              final slideT = (placeProgress / 0.45).clamp(0.0, 1.0);
              final slideEased = Curves.easeOutCubic.transform(slideT);

              final startOffsetX = _r<double>(
                context,
                mobile: 130.0,
                tab: 160.0,
                desktop: 190.0,
              );
              final startOffsetY = _r<double>(
                context,
                mobile: 90.0,
                tab: 100.0,
                desktop: 110.0,
              );
              // Slides in from the bottom-right toward its resting spot.
              final currentOffsetX = startOffsetX * (1 - slideEased);
              final currentBottom =
                  boxRestBottom + startOffsetY * (1 - slideEased);

              final settleT = ((placeProgress - 0.38) / 0.42).clamp(0.0, 1.0);
              // Tilt starts steep on approach and springs past level before
              // resting flat, echoing the overshoot on scale.
              final startTilt = -0.30; // radians, tilted on approach
              final settleOvershoot = sin(settleT * pi) * (1 - settleT * 0.4);
              final currentRotation =
                  startTilt * (1 - slideEased) - settleOvershoot * 0.06;

              // Scale grows with the approach, overshoots past endScale on
              // landing, then springs back to rest.
              final baseScale = endScale * (0.55 + 0.45 * slideEased);
              final scale = baseScale + settleOvershoot * endScale * 0.18;

              final boxOpacity = (placeProgress * 6).clamp(0.0, 1.0);

              // Copy comes in early and quickly — it starts while the box is
              // still on approach (0.22) and is fully legible by 0.46, rather
              // than waiting for the box to land first. Eased so the ramp
              // doesn't read as a hard linear wipe at this shorter duration.
              final textOpacity = Curves.easeOut.transform(
                ((placeProgress - 0.22) / 0.24).clamp(0.0, 1.0),
              );

              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: currentBottom,
                    child: Opacity(
                      opacity: boxOpacity,
                      child: Transform.translate(
                        offset: Offset(currentOffsetX, 0),
                        child: Transform(
                          alignment: Alignment.bottomCenter,
                          transform:
                              Matrix4.identity()
                                ..rotateZ(currentRotation)
                                ..scaleByDouble(scale, scale, 1.0, 1.0),
                          child: CustomPaint(
                            painter: DeliveryBoxPainter(
                              primaryColor: Theme.of(context).primaryColor,
                              accentColor:
                                  Theme.of(context).secondaryHeaderColor,
                              svgAssetPath: 'assets/on_boarding/Asset 11.svg',
                              isArabic: Get.locale?.languageCode == 'ar',
                              text1: 'delivery_box_you_need_it'.tr,
                              text2: 'delivery_box_we_speed_it'.tr,
                            ),
                            child: boxChild,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: _r<double>(
                      context,
                      mobile: 110,
                      tab: 120,
                      desktop: 130,
                    ),
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: textOpacity,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _r<double>(
                            context,
                            mobile: 30,
                            tab: 80,
                            desktop: 120,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'onboarding_page3_title'.tr,
                              textAlign: TextAlign.center,
                              style: waddyBold.copyWith(
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
                              style: waddyRegular.copyWith(
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
            bottom: _r<double>(context, mobile: 40, tab: 52, desktop: 60),
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _thirdScreenController,
              builder: (context, child) {
                // CTA follows the copy closely instead of trailing the whole
                // box entrance — in by 0.52, so it is tappable well before
                // the box has finished settling.
                final buttonOpacity = Curves.easeOut.transform(
                  ((_thirdScreenController.value - 0.30) / 0.22).clamp(
                    0.0,
                    1.0,
                  ),
                );
                // Single settling bob rather than the old two-cycle wobble,
                // which at this shorter duration read as a jitter. Damped so
                // it comes to rest instead of stopping mid-swing.
                final t = _thirdScreenController.value;
                final jiggleOffset = sin(t * pi * 2) * 3 * (1 - t);

                return Opacity(
                  opacity: buttonOpacity,
                  child: Transform.translate(
                    offset: Offset(0, jiggleOffset),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomButton(
                          onPressed: () {
                            _configureToRouteInitialPage();
                          },
                          buttonText:
                              _isBootstrapping
                                  ? 'setting_things_up'.tr
                                  : 'onboarding_get_started'.tr,
                          isLoading: _isBootstrapping,

                          margin: _buttonMargin(context),
                          height: _r<double>(
                            context,
                            mobile: 50,
                            tab: 56,
                            desktop: 60,
                          ),
                          fontSize: _r<double>(
                            context,
                            mobile: 18,
                            tab: 20,
                            desktop: 20,
                          ),
                          isBold: true,
                        ),
                      ],
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

  Future<void> _configureToRouteInitialPage() async {
    if (_isBootstrapping) return;
    Get.find<SplashController>().disableIntro();

    debugPrint(
      '[Waddy] guest_browse_status from config: ${Get.find<SplashController>().configModelOrNull?.guestBrowseStatus}',
    );
    if (!GuestBootstrapHelper.guestBrowseEnabled) {
      Get.offNamed(RouteHelper.getUnifiedAuthRoute());
      return;
    }

    setState(() => _isBootstrapping = true);
    final GuestBootstrapResult result =
        await GuestBootstrapHelper.bootstrapGuest();
    // handedToLocationGate means the gate is showing the permission dialog or
    // the mandatory picker — navigating here would wipe it out.
    if (result == GuestBootstrapResult.failed) {
      // Visible fallback: the user should read this as "we adapted", not as
      // a button that silently did nothing.
      showCustomSnackBar('setting_up_failed_login_instead'.tr);
      Get.offNamed(RouteHelper.getUnifiedAuthRoute());
    }
    if (mounted) {
      setState(() => _isBootstrapping = false);
    }
  }
}

// Text layout is genuinely static per (text, locale) pair — it does not
// depend on contentOpacity/scale — so the two TextPainters are cached here
// and reused across every repaint instead of being laid out from scratch on
// every animation tick (this painter is rebuilt ~60x/sec while cards fall).
final Map<String, TextPainter> _deliveryBoxTextPainterCache = {};

TextPainter _cachedTextPainter({
  required String text,
  required Color color,
  required bool isArabic,
}) {
  final key = '$text|${color.toARGB32()}|$isArabic';
  return _deliveryBoxTextPainterCache.putIfAbsent(key, () {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: isArabic ? 0 : 2,
        ),
      ),
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
    )..layout();
  });
}

class DeliveryBoxPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final String? svgAssetPath;
  final TextPainter textPainter1;
  final TextPainter textPainter2;
  final bool isArabic;

  DeliveryBoxPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.isArabic,
    this.svgAssetPath,
    String? text1,
    String? text2,
  }) : textPainter1 = _cachedTextPainter(
         text: text1 ?? '',
         color: Colors.white.withValues(alpha: 0.9),
         isArabic: isArabic,
       ),
       textPainter2 = _cachedTextPainter(
         text: text2 ?? '',
         color: const Color(0xFF1EF2A0),
         isArabic: isArabic,
       );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Derived from the actual canvas size (not fixed px) so the painted box
    // scales when its container (boxW/boxH) grows — was previously frozen
    // at a hardcoded 200px tall regardless of the container's real height.
    final boxLeft = size.width * 0.12;
    final boxWidth = size.width - boxLeft * 2;
    final boxHeight = size.height * 0.78;
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

    // Scale factor relative to the box's original 200px-tall baseline, so
    // the tape band, perforations, icon, and text offsets grow with it
    // instead of looking undersized/cramped inside a larger box.
    final scale = boxHeight / 200.0;
    final tapeHeight = 40.0 * scale;

    paint.color = accentColor;
    final tapeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxLeft, boxTop + boxHeight * 0.4, boxWidth, tapeHeight),
      Radius.circular(5 * scale),
    );
    canvas.drawRRect(tapeRect, paint);

    paint.color = Colors.teal.withValues(alpha: 0.3);
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    for (double i = boxLeft + 10; i < boxLeft + boxWidth - 10; i += 20) {
      canvas.drawLine(
        Offset(i, boxTop + boxHeight * 0.4 + tapeHeight * 0.25),
        Offset(i + 10, boxTop + boxHeight * 0.4 + tapeHeight * 0.25),
        paint,
      );
      canvas.drawLine(
        Offset(i, boxTop + boxHeight * 0.4 + tapeHeight * 0.75),
        Offset(i + 10, boxTop + boxHeight * 0.4 + tapeHeight * 0.75),
        paint,
      );
    }

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4;
    paint.color = accentColor;
    canvas.drawRRect(boxRect, paint);

    final iconSize = 50.0 * scale;
    final iconLeft = boxLeft + (boxWidth - iconSize) / 2;
    final iconTop = boxTop + 20 * scale;

    paint.style = PaintingStyle.fill;
    paint.color = accentColor.withValues(alpha: 0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(iconLeft, iconTop, iconSize, iconSize),
        Radius.circular(8 * scale),
      ),
      paint,
    );

    // The copy is painted unconditionally at full alpha. Its fade-in used to
    // live here as a contentOpacity-driven saveLayer, which meant the painter
    // reported shouldRepaint == true on every frame of the entrance — and the
    // entrance overlaps the first two card falls. That re-rasterized the
    // RRect, the flap path, the ~25-segment perforation loop and both text
    // runs 60x/sec at exactly the busiest moment on this screen. The fade is
    // now a FadeTransition wrapped around the whole CustomPaint, so it is
    // compositor work on a layer that is rasterized exactly once.
    textPainter1.paint(
      canvas,
      Offset(
        boxLeft + (boxWidth - textPainter1.width) / 2,
        boxTop + 125 * scale,
      ),
    );
    textPainter2.paint(
      canvas,
      Offset(
        boxLeft + (boxWidth - textPainter2.width) / 2,
        boxTop + 160 * scale,
      ),
    );
  }

  @override
  bool shouldRepaint(DeliveryBoxPainter oldDelegate) => false;
}

/// Bounces [child] briefly each time one of the falling cards lands in it.
///
/// Kept as its own widget for two reasons. It confines rebuilds driven by the
/// fall controller to just this node instead of the whole box + copy column
/// above it; and it takes the box as a prebuilt `child`, so the expensive
/// CustomPaint subtree is constructed once and only ever transformed.
///
/// The RepaintBoundary matters as much as the scoping: a transform on a
/// parent repaints its child regardless of what the painter's shouldRepaint
/// returns, so without the boundary each pulse frame re-rasterizes the RRect,
/// the flap path, the ~25-segment perforation loop and two text paints. With
/// it the box is rasterized once and the bounce is a compositor transform of
/// that cached layer.
class _LandingPulse extends StatelessWidget {
  final Animation<double> fall;
  final List<Map<String, double>> intervals;
  final Widget child;

  const _LandingPulse({
    required this.fall,
    required this.intervals,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fall,
      child: RepaintBoundary(child: child),
      builder: (context, boxChild) {
        final fallP = fall.value;

        double landingPulse = 0.0;
        for (int i = 0; i < intervals.length; i++) {
          final fe = intervals[i]['fallEnd']!;
          const pulseWindow = 0.12;
          if (fallP >= fe - pulseWindow * 0.3 && fallP <= fe + pulseWindow) {
            final t = ((fallP - (fe - pulseWindow * 0.3)) / (pulseWindow * 1.3))
                .clamp(0.0, 1.0);
            landingPulse = t < 0.3 ? t / 0.3 : (1.0 - t) / 0.7;
          }
        }

        // At rest for most of the run — skip the Transform entirely rather
        // than pushing an identity matrix onto the layer tree every frame.
        if (landingPulse == 0.0) return boxChild!;

        return Transform.scale(
          scale: 1.0 + landingPulse * 0.035,
          child: boxChild,
        );
      },
    );
  }
}

/// One of the four cards that fall into the delivery box on screen 2.
///
/// Deliberately a plain StatelessWidget with no animated inputs: it is passed
/// to AnimatedBuilder as `child`, so it is built exactly once per visit to
/// screen 2 and then only transformed. Nothing inside here may depend on the
/// animation value, or the per-frame cost comes straight back.
///
/// Three things that used to be animated are now fixed, because each one cost
/// a full re-rasterization every frame:
///   * the drop shadow (a blur — by far the most expensive), previously
///     tweened on both blurRadius and alpha;
///   * the rounded clip, which is unnecessary since the children already sit
///     inside the card's padded bounds;
///   * the label's FittedBox, which re-ran text layout on every rebuild and
///     is replaced by a fixed-size Text.
class _FallingCard extends StatelessWidget {
  final double size;
  final String label;
  final String imageAsset;

  const _FallingCard({
    required this.size,
    required this.label,
    required this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    // The caller already wraps this in an Opacity, and RenderOpacity is
    // itself a repaint boundary that pushes an OpacityLayer (no saveLayer),
    // so this boundary is belt-and-braces rather than load-bearing — it keeps
    // the card independently cached if that Opacity ever goes away.
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Spots.mint,
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
          border: Border.all(color: WaddyColors.primary, width: 3),
          boxShadow: [
            BoxShadow(
              color: WaddyColors.primary.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
          child: Column(
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: waddyBold.copyWith(
                  fontSize: 16,
                  color: _cardInk,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    // Decode at roughly the on-screen size instead of full
                    // resolution — these are ~168px tiles, and the shrinking
                    // transform makes them smaller still.
                    cacheWidth: (size * 2).round(),
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

/// Fixed brand mark shown once at the bottom-right of the hero card. Lives
/// outside the morphing content stack so it never gets duplicated or
/// cross-faded between outgoing/incoming topics — it just sits still.
class _CardBrandMark extends StatelessWidget {
  const _CardBrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 60,
          decoration: BoxDecoration(
            color: WaddyColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(Dimensions.radiusDefault),
              topRight: Radius.circular(Dimensions.radiusDefault),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
            child: SvgPicture.asset(
              "assets/on_boarding/Asset 11.svg",
              width: 24,
              height: 24,
            ),
          ),
        ),
      ],
    );
  }
}

/// Clips a child to a left-aligned fraction of its own width — used to
/// "draw in" the stroke-underline image left-to-right as [fraction] goes 0→1.
class _FractionalWidthClipper extends CustomClipper<Rect> {
  final double fraction;

  _FractionalWidthClipper(this.fraction);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(_FractionalWidthClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

/// One topic shown in the morphing hero card on the first onboarding screen.
class _OnboardTopic {
  final String title;
  final String subtitle;
  final int count;
  final int daysAgo;
  final IconData headerIcon;
  final List<String> itemImages;

  const _OnboardTopic({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.daysAgo,
    required this.headerIcon,
    required this.itemImages,
  });
}
