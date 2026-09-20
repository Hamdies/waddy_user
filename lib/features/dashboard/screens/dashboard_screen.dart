import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:waddy_app/features/dashboard/widgets/store_registration_success_bottom_sheet.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/parcel/controllers/parcel_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/deep_link_helper.dart';
import 'package:waddy_app/helper/tracking_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/theme/light_theme.dart';

import 'package:waddy_app/common/widgets/custom_dialog.dart';
import 'package:waddy_app/features/checkout/widgets/congratulation_dialogue.dart';
import 'package:waddy_app/features/dashboard/widgets/parcel_bottom_sheet_widget.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/screens/xp_levels_screen.dart';
import 'package:waddy_app/features/menu/screens/menu_screen.dart';
import 'package:waddy_app/features/order/screens/order_screen.dart';
import 'package:waddy_app/features/places/screens/places_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/cart/widgets/pill_cart_bar.dart';

class DashboardScreen extends StatefulWidget {
  final int pageIndex;
  final bool fromSplash;
  const DashboardScreen({
    super.key,
    required this.pageIndex,
    this.fromSplash = false,
  });

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  PageController? _pageController;
  int _pageIndex = 0;
  late List<Widget> _screens;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey();
  bool _canExit = false;

  late bool _isLogin;
  bool active = false;

  @override
  void initState() {
    super.initState();

    _live = this;

    _isLogin = AuthHelper.isLoggedIn();

    _showRegistrationSuccessBottomSheet();

    if (_isLogin) {
      if (Get.find<SplashController>().configModel.loyaltyPointStatus == 1 &&
          Get.find<AuthController>().getEarningPint().isNotEmpty) {
        Future.delayed(
          const Duration(seconds: 1),
          () =>
              showAnimatedDialog(Get.context!, const CongratulationDialogue()),
        );
      }
      suggestAddressBottomSheet();
      Get.find<OrderController>().getRunningOrders(1, fromDashboard: true);
      // Primes the Rewards badge. Both calls no-op once their model is
      // loaded, and without them the dot could only ever light up after the
      // user had already opened the tab it is meant to point at.
      Get.find<XpController>().getChallenges();
      Get.find<XpController>().getPrizes();
    }

    _pageIndex = widget.pageIndex;

    _pageController = PageController(initialPage: widget.pageIndex);

    _screens = [
      const HomeScreen(),
      const XpLevelsScreen(),
      const PlacesHomeScreen(),
      const OrderScreen(),
      const MenuScreen(),
    ];

    // Ensure cart data is loaded for the home cart bar's visibility
    // Skip cart for Places module - it doesn't use cart
    final isPlacesModule =
        Get.find<SplashController>().module?.moduleType.toString() ==
        AppConstants.places;
    if ((_isLogin || AuthHelper.isGuestLoggedIn()) && !isPlacesModule) {
      Get.find<CartController>().getCartDataOnline();
    }

    // Every entry path (splash, guest bootstrap, location gate, picker) ends
    // here, so this is the one safe place to fire a stashed deep link: zone
    // context exists and the target lands on top of home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkHelper.consumePending();
      TrackingHelper.requestOnce();
    });
  }

  @override
  void dispose() {
    // Only clear if this instance is still the registered one: a replacement
    // dashboard runs its initState before the outgoing one disposes.
    if (identical(_live, this)) _live = null;
    super.dispose();
  }

  _showRegistrationSuccessBottomSheet() {
    bool canShowBottomSheet =
        Get.find<HomeController>().getRegistrationSuccessfulSharedPref();
    if (canShowBottomSheet) {
      Future.delayed(const Duration(seconds: 1), () {
        showModalBottomSheet(
          context: Get.context!,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (con) => const StoreRegistrationSuccessBottomSheet(),
        ).then((value) {
          Get.find<HomeController>().saveRegistrationSuccessfulSharedPref(
            false,
          );
          Get.find<HomeController>().saveIsStoreRegistrationSharedPref(false);
          setState(() {});
        });
      });
    }
  }

  Future<void> suggestAddressBottomSheet() async {
    active = await Get.find<LocationController>().checkLocationActive();
    if (widget.fromSplash &&
        Get.find<LocationController>().showLocationSuggestion &&
        active) {
      // Auto-set current location instead of showing bottom sheet
      Get.find<LocationController>().showSuggestedLocation(false);
      Get.find<LocationController>().checkPermission(() async {
        await Get.find<LocationController>().getCurrentLocation(true);
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool keyboardVisible = MediaQuery.of(context).viewInsets.bottom != 0;
    return GetBuilder<SplashController>(
      builder: (splashController) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (_pageIndex != 0) {
              _setPage(0);
            } else {
              if (Get.find<SplashController>().module != null &&
                  Get.find<SplashController>().configModel.module == null) {
                Get.find<SplashController>().leaveModule();
                Get.find<StoreController>().resetStoreData();
              } else {
                if (_canExit) {
                  if (GetPlatform.isAndroid) {
                    SystemNavigator.pop();
                  } else if (GetPlatform.isIOS) {
                    exit(0);
                  }
                } else {
                  showCustomSnackBar(
                    'back_press_again_to_exit'.tr,
                    isError: false,
                    showDuration: 2,
                  );
                  _canExit = true;
                  Timer(const Duration(seconds: 2), () {
                    _canExit = false;
                  });
                }
              }
            }
          },
          child: GetBuilder<OrderController>(
            builder: (orderController) {
              return SafeArea(
                top: false,
                bottom: GetPlatform.isAndroid,
                child: Scaffold(
                  key: _scaffoldKey,

                  body: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: _screens.length,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          return _screens[index];
                        },
                      ),

                      keyboardVisible
                          ? const SizedBox()
                          : Align(
                            alignment: Alignment.bottomCenter,
                            child: GetBuilder<SplashController>(
                              builder: (splashController) {
                                bool isParcel =
                                    splashController.module != null &&
                                    splashController
                                        .configModel
                                        .moduleConfig!
                                        .module!
                                        .isParcel!;

                                _screens = [
                                  const HomeScreen(),
                                  const XpLevelsScreen(),
                                  const PlacesHomeScreen(),
                                  const OrderScreen(),
                                  const MenuScreen(),
                                ];
                                // Modern Floating Bottom Nav Bar with Center Cutout
                                // and Live Cart Widget above it
                                return _BottomNavWithLiveCart(
                                  pageIndex: _pageIndex,
                                  isParcel: isParcel,
                                  isLogin: _isLogin,
                                  showBottomSheet:
                                      orderController.showBottomSheet,
                                  hasRunningOrders:
                                      orderController.runningOrderModel !=
                                          null &&
                                      orderController
                                          .runningOrderModel!
                                          .orders!
                                          .isNotEmpty,
                                  fromSplash: widget.fromSplash,
                                  showLocationSuggestion:
                                      Get.find<LocationController>()
                                          .showLocationSuggestion,
                                  active: active,
                                  onPageChanged: _setPage,
                                  onCenterTap: () {
                                    if (isParcel) {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder:
                                            (con) => ParcelBottomSheetWidget(
                                              parcelCategoryList:
                                                  Get.find<ParcelController>()
                                                      .parcelCategoryList,
                                            ),
                                      );
                                    } else {
                                      _setPage(2); // Switch to Cart tab
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// The live dashboard, so any screen already inside it can switch tabs without
  /// pushing a second one.
  ///
  /// Entering a tab used to mean `Get.toNamed(RouteHelper.getMainRoute(...))`,
  /// which stacks a whole new `DashboardScreen` over the current one — the back
  /// button then pops to a *different* copy of the app. Registered in
  /// `initState` and cleared in `dispose`, so it is null exactly when no
  /// dashboard is mounted.
  static DashboardScreenState? _live;

  /// Switches the mounted dashboard to [pageIndex] and returns true. Returns
  /// false when no dashboard is mounted, so callers can fall back to a route:
  ///
  /// ```dart
  /// if (!DashboardScreenState.switchToTab(0)) {
  ///   Get.offAllNamed(RouteHelper.getMainRoute('home'));
  /// }
  /// ```
  ///
  /// Goes through `_setPage` rather than the `PageController` directly, because
  /// switching to home also clears module context and reloads the feed.
  static bool switchToTab(int pageIndex) {
    final state = _live;
    if (state == null || !state.mounted) return false;
    state._setPage(pageIndex);
    return true;
  }

  void _setPage(int pageIndex) {
    setState(() {
      _pageController!.jumpToPage(pageIndex);
      _pageIndex = pageIndex;

      // Clear module context when navigating to home tab to show all modules
      if (pageIndex == 0 &&
          Get.find<SplashController>().module != null &&
          Get.find<SplashController>().configModel.module == null) {
        Get.find<SplashController>().leaveModule();
        Get.find<StoreController>().resetStoreData();
        HomeScreen.loadData(false);
      }
    });
  }

  Widget trackView(BuildContext context, {required bool status}) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color:
            status
                ? Theme.of(context).primaryColor
                : Theme.of(context).disabledColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
    );
  }
}

/// Flat Bottom Navigation Bar with 5 equal tabs (Home, Rewards, Cart, Orders, Account)
class _FlatBottomNav extends StatelessWidget {
  final int pageIndex;
  final bool isParcel;
  final bool isLogin;
  final bool showBottomSheet;
  final bool hasRunningOrders;
  final bool fromSplash;
  final bool showLocationSuggestion;
  final bool active;
  final Function(int) onPageChanged;
  final VoidCallback onCenterTap;

  const _FlatBottomNav({
    required this.pageIndex,
    required this.isParcel,
    required this.isLogin,
    required this.showBottomSheet,
    required this.hasRunningOrders,
    required this.fromSplash,
    required this.showLocationSuggestion,
    required this.active,
    required this.onPageChanged,
    required this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Theme colors
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Container(
      height: 58 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        // The feed scrolls tinted bands (the grocery shelf) right up under the
        // bar, where a 6%-alpha hairline all but disappears. The border sets
        // the edge on white, the shadow keeps it readable on everything else.
        border: Border(
          top: BorderSide(
            color: primaryColor.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: HugeIcons.strokeRoundedHome01,
            imageIcon: Images.logoMarkTransparent,
            label: 'home'.tr,
            isSelected: pageIndex == 0,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            onTap: () => onPageChanged(0),
          ),
          // The badge says exactly one thing: a reward is sitting there
          // unclaimed. It used to be hardwired on, which made it wallpaper —
          // and wallpaper is what people stop seeing.
          GetBuilder<XpController>(
            id: XpController.idBadge,
            builder:
                (xpController) => _NavItem(
                  icon: HugeIcons.strokeRoundedGiftCard02,
                  label: 'rewards'.tr,
                  isSelected: pageIndex == 1,
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                  showPulsingBadge: isLogin && xpController.hasUnclaimedRewards,
                  onTap: () => onPageChanged(1),
                ),
          ),
          // Places to Visit tab — icon auto-morphs between a small set of
          // "what you can explore" glyphs (compass/pin/building/coffee) so
          // the tab itself hints at variety; discovery content still lives
          // in the feed, this is chrome-level texture only.
          _NavItem(
            icon: HugeIcons.strokeRoundedCompass01,
            morphIcons: const [
              HugeIcons.strokeRoundedCoffee02,
              HugeIcons.strokeRoundedBowling,
              HugeIcons.strokeRoundedGameController01,
              HugeIcons.strokeRoundedMaskTheater02,
            ],
            label: 'explore'.tr,
            isSelected: pageIndex == 2,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            onTap: onCenterTap,
          ),
          _NavItem(
            icon: HugeIcons.strokeRoundedInvoice01,
            label: 'orders'.tr,
            isSelected: pageIndex == 3,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            onTap: () => onPageChanged(3),
          ),
          _NavItem(
            icon: HugeIcons.strokeRoundedUser,
            label: 'account'.tr,
            isSelected: pageIndex == 4,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            onTap: () => onPageChanged(4),
          ),
        ],
      ),
    );
  }
}

/// Navigation item using a HugeIcons glyph — one consistent icon family
/// across every tab, at a bigger size for stronger visual presence.
///
/// Optional per-tab embellishments:
/// - [imageIcon]: renders this image (tinted to match the selected/unselected
///   nav color) instead of [icon] — used for the Home tab's brand mark.
/// - [morphIcons]: when set, the icon shape auto-cycles through this list on
///   a timer instead of showing a single static [icon] — used for Explore.
/// - [showPulsingBadge]: draws a small pulsing mint dot over the icon.
class _NavItem extends StatefulWidget {
  final List<List<dynamic>> icon;
  final String? imageIcon;
  final List<List<List<dynamic>>>? morphIcons;
  final bool showPulsingBadge;
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    this.imageIcon,
    this.morphIcons,
    this.showPulsingBadge = false,
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  Timer? _morphTimer;
  int _morphIndex = 0;

  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    if (widget.showPulsingBadge) _startPulse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMorph();
  }

  /// The Explore tab's icon cycles through a set of glyphs. That is permanent,
  /// unprompted motion in the app's chrome, so it has to answer to the OS
  /// reduce-motion setting — it previously ran on a 2s timer forever regardless,
  /// which is exactly the kind of ambient movement that setting exists to stop.
  ///
  /// Frozen, the tab falls back to its base [icon] (the compass), which is also
  /// the one glyph that actually means "explore".
  void _syncMorph() {
    _morphTimer?.cancel();
    _morphTimer = null;

    final morphIcons = widget.morphIcons;
    if (morphIcons == null || morphIcons.length <= 1) return;
    if (MediaQuery.of(context).disableAnimations) {
      if (_morphIndex != 0) setState(() => _morphIndex = 0);
      return;
    }

    _morphTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() => _morphIndex = (_morphIndex + 1) % morphIcons.length);
    });
  }

  /// The badge is now data-driven, so it can switch on mid-session (a
  /// challenge completes, prizes finish loading). Without this the pulse
  /// controller would only ever exist if the badge was already showing on
  /// the frame this tab was first built.
  @override
  void didUpdateWidget(covariant _NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showPulsingBadge == oldWidget.showPulsingBadge) return;
    if (widget.showPulsingBadge) {
      _startPulse();
    } else {
      _pulseController?.dispose();
      _pulseController = null;
      _pulseAnimation = null;
    }
  }

  void _startPulse() {
    _pulseController?.dispose();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.85, end: 2.0).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _morphTimer?.cancel();
    _pulseController?.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _scaleController.forward().then((_) => _scaleController.reverse());
    widget.onTap();
  }

  Widget _buildIcon(Color color) {
    if (widget.imageIcon != null) {
      // The logo glyph has built-in transparent padding, so it needs to
      // render larger than the icon box to read at the same visual size
      // as the HugeIcons glyphs on the other tabs.
      return Image.asset(
        widget.imageIcon!,
        width: 52,
        height: 52,
        color: color,
      );
    }

    final morphIcons = widget.morphIcons;
    final currentIcon =
        morphIcons != null
            ? morphIcons[_morphIndex % morphIcons.length]
            : widget.icon;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder:
          (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
      child: HugeIcon(
        key: ValueKey(morphIcons != null ? _morphIndex : 0),
        icon: currentIcon,
        color: color,
        size: 22,
        strokeWidth: widget.isSelected ? 2.0 : 1.7,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isSelected ? widget.primaryColor : WaddyColors.inkLight;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 68,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    _buildIcon(color),
                    if (widget.showPulsingBadge && _pulseAnimation != null)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation!,
                          builder: (context, _) {
                            final scale = _pulseAnimation!.value;
                            final fade = (1.0 - _pulseController!.value).clamp(
                              0.0,
                              1.0,
                            );
                            return Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Transform.scale(
                                  scale: scale,
                                  child: Opacity(
                                    opacity: fade,
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: WaddyColors.mint,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: WaddyColors.mint,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                // Icon and label share one colour and swing weight together,
                // so the selected tab reads as a single object rather than a
                // tinted glyph with some text near it. w600 was too close to
                // w700 for that switch to register at 11pt.
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      widget.isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: color,
                  letterSpacing: 0.1,
                  height: 1.1,
                ),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom slot for the dashboard: the home cart bar for food/grocery modules,
/// the flat nav bar otherwise. Scroll-aware, and yields to any route pushed on
/// top so its bar does not render through screens with their own cart bar.
class _BottomNavWithLiveCart extends StatefulWidget {
  final int pageIndex;
  final bool isParcel;
  final bool isLogin;
  final bool showBottomSheet;
  final bool hasRunningOrders;
  final bool fromSplash;
  final bool showLocationSuggestion;
  final bool active;
  final Function(int) onPageChanged;
  final VoidCallback onCenterTap;

  const _BottomNavWithLiveCart({
    required this.pageIndex,
    required this.isParcel,
    required this.isLogin,
    required this.showBottomSheet,
    required this.hasRunningOrders,
    required this.fromSplash,
    required this.showLocationSuggestion,
    required this.active,
    required this.onPageChanged,
    required this.onCenterTap,
  });

  @override
  State<_BottomNavWithLiveCart> createState() => _BottomNavWithLiveCartState();
}

/// Notifies the dashboard when another route covers or uncovers it.
///
/// Needed because the dashboard stays mounted under pushed routes, so its
/// floating cart bar would otherwise render through them. `Get.routing.current`
/// is a plain String (not an Rx), so it cannot drive an Obx; `ModalRoute
/// .isCurrent` never notifies. RouteAware is the primitive that actually fires
/// on both push and pop.
final RouteObserver<ModalRoute<void>> dashboardRouteObserver =
    RouteObserver<ModalRoute<void>>();

class _BottomNavWithLiveCartState extends State<_BottomNavWithLiveCart>
    with SingleTickerProviderStateMixin, RouteAware {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  /// True while another route sits on top of the dashboard.
  bool _isCovered = false;

  ModalRoute<void>? _subscribedRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies can fire repeatedly (locale, media query, theme),
    // so re-subscribing blindly would stack duplicate registrations. Only
    // resubscribe when the route we are attached to actually changes.
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void> && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        dashboardRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      dashboardRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    if (mounted) setState(() => _isCovered = true);
  }

  @override
  void didPopNext() {
    if (mounted) setState(() => _isCovered = false);
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    dashboardRouteObserver.unsubscribe(this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide when certain conditions are met
    if (widget.fromSplash && widget.showLocationSuggestion && widget.active) {
      return const SizedBox();
    }

    // Hide bottom nav for grocery or food module - show the cart bar instead
    return GetBuilder<SplashController>(
      builder: (splashController) {
        // Check if current module is grocery or food
        final module = splashController.module;
        final isGroceryOrFood =
            module?.type == ModuleType.grocery ||
            module?.type == ModuleType.food;

        // On food/grocery the cart bar REPLACES the bottom nav — it IS the
        // nav for those modules, not an extra bar stacked above one.
        if (isGroceryOrFood) {
          // The dashboard stays mounted underneath anything pushed on top of
          // it, so without this its cart bar renders THROUGH pushed screens —
          // stacking a second bar under FoodStoreScreen's own anchored one.
          // `_isCovered` is kept current by a RouteObserver (didPushNext /
          // didPopNext), which notifies on both push and pop.
          if (_isCovered) return const SizedBox.shrink();

          return GetBuilder<HomeController>(
            builder: (homeController) {
              // Hide on scroll down, show when stopped or scrolling up
              final isVisible = homeController.isBottomNavVisible;

              return AnimatedSlide(
                offset: isVisible ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: isVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  // No outer padding: the bar carries the system inset as
                  // padding INSIDE its own white ground, so the white runs to
                  // the physical screen edge instead of leaving a gap under it.
                  // Store-agnostic: the cart may span a store whose minimum
                  // and free-delivery flags are not in memory here, so only
                  // the admin-wide rules are evaluated.
                  child: const PillCartBar(globalOnly: true),
                ),
              );
            },
          );
        }

        return GetBuilder<HomeController>(
          builder: (homeController) {
            // Animate based on visibility state
            if (homeController.isBottomNavVisible) {
              _animationController.reverse();
            } else {
              _animationController.forward();
            }

            return SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _FlatBottomNav(
                  pageIndex: widget.pageIndex,
                  isParcel: widget.isParcel,
                  isLogin: widget.isLogin,
                  showBottomSheet: widget.showBottomSheet,
                  hasRunningOrders: widget.hasRunningOrders,
                  fromSplash: widget.fromSplash,
                  showLocationSuggestion: widget.showLocationSuggestion,
                  active: widget.active,
                  onPageChanged: widget.onPageChanged,
                  onCenterTap: widget.onCenterTap,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
