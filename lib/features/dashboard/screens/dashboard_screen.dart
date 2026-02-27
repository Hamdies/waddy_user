import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sixam_mart/features/dashboard/widgets/store_registration_success_bottom_sheet.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/parcel/controllers/parcel_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/rental_module/rental_cart_screen/taxi_cart_screen.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/taxi_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';

import 'package:sixam_mart/common/widgets/custom_dialog.dart';
import 'package:sixam_mart/features/checkout/widgets/congratulation_dialogue.dart';
import 'package:sixam_mart/features/dashboard/widgets/parcel_bottom_sheet_widget.dart';
import 'package:sixam_mart/features/home/screens/home_screen.dart';
import 'package:sixam_mart/features/dashboard/widgets/live_cart_widget.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/features/xp/screens/xp_levels_screen.dart';
import 'package:sixam_mart/features/menu/screens/menu_screen.dart';
import 'package:sixam_mart/features/order/screens/order_screen.dart';
import 'package:sixam_mart/features/cart/screens/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
  bool _canExit = GetPlatform.isWeb ? true : false;

  late bool _isLogin;
  bool active = false;

  @override
  void initState() {
    super.initState();

    _isLogin = AuthHelper.isLoggedIn();

    _showRegistrationSuccessBottomSheet();

    if (_isLogin) {
      if (Get.find<SplashController>().configModel!.loyaltyPointStatus == 1 &&
          Get.find<AuthController>().getEarningPint().isNotEmpty &&
          !ResponsiveHelper.isDesktop(Get.context)) {
        Future.delayed(
          const Duration(seconds: 1),
          () =>
              showAnimatedDialog(Get.context!, const CongratulationDialogue()),
        );
      }
      suggestAddressBottomSheet();
      Get.find<OrderController>().getRunningOrders(1, fromDashboard: true);
    }

    _pageIndex = widget.pageIndex;

    _pageController = PageController(initialPage: widget.pageIndex);

    _screens = [
      const HomeScreen(),
      const XpLevelsScreen(),
      const CartScreen(fromNav: true),
      const OrderScreen(),
      const MenuScreen(),
    ];

    // Ensure cart data is loaded for LiveCartWidget visibility
    if (_isLogin || AuthHelper.isGuestLoggedIn()) {
      Get.find<CartController>().getCartDataOnline();
    }
  }

  _showRegistrationSuccessBottomSheet() {
    bool canShowBottomSheet =
        Get.find<HomeController>().getRegistrationSuccessfulSharedPref();
    if (canShowBottomSheet) {
      Future.delayed(const Duration(seconds: 1), () {
        ResponsiveHelper.isDesktop(Get.context)
            ? Get.dialog(
              const Dialog(child: StoreRegistrationSuccessBottomSheet()),
            ).then((value) {
              Get.find<HomeController>().saveRegistrationSuccessfulSharedPref(
                false,
              );
              Get.find<HomeController>().saveIsStoreRegistrationSharedPref(
                false,
              );
              setState(() {});
            })
            : showModalBottomSheet(
              context: Get.context!,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (con) => const StoreRegistrationSuccessBottomSheet(),
            ).then((value) {
              Get.find<HomeController>().saveRegistrationSuccessfulSharedPref(
                false,
              );
              Get.find<HomeController>().saveIsStoreRegistrationSharedPref(
                false,
              );
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
              if (!ResponsiveHelper.isDesktop(context) &&
                  Get.find<SplashController>().module != null &&
                  Get.find<SplashController>().configModel!.module == null) {
                Get.find<SplashController>().setModule(null);
                Get.find<StoreController>().resetStoreData();
              } else {
                if (_canExit) {
                  if (GetPlatform.isAndroid) {
                    SystemNavigator.pop();
                  } else if (GetPlatform.isIOS) {
                    exit(0);
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
                  // floatingActionButton: Padding(
                  //   padding: const EdgeInsets.only(bottom: 100.0),
                  //   child: FloatingActionButton(
                  //     mini: true,
                  //     onPressed: () {
                  //       showDialog(
                  //         context: context,
                  //         builder: (context) => const LetterDialogWidget(),
                  //       );
                  //     },
                  //     child: const Icon(Icons.email),
                  //   ),
                  // ),
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

                      ResponsiveHelper.isDesktop(context) || keyboardVisible
                          ? const SizedBox()
                          : Align(
                            alignment: Alignment.bottomCenter,
                            child: GetBuilder<SplashController>(
                              builder: (splashController) {
                                bool isParcel =
                                    splashController.module != null &&
                                    splashController
                                        .configModel!
                                        .moduleConfig!
                                        .module!
                                        .isParcel!;
                                bool isTaxiWithCache =
                                    ((splashController.module != null &&
                                            splashController.module!.moduleType
                                                    .toString() ==
                                                AppConstants.taxi) ||
                                        (splashController.cacheModule != null &&
                                            splashController
                                                    .cacheModule!
                                                    .moduleType
                                                    .toString() ==
                                                AppConstants.taxi)) &&
                                    TaxiHelper.haveTaxiModule();
                                bool isTaxi =
                                    (splashController.module != null &&
                                        splashController.module!.moduleType
                                                .toString() ==
                                            AppConstants.taxi);
                                isParcel = isParcel && !isTaxiWithCache;

                                _screens = [
                                  const HomeScreen(),
                                  const XpLevelsScreen(),
                                  const CartScreen(fromNav: true),
                                  OrderScreen(index: isTaxi ? 1 : 0),
                                  const MenuScreen(),
                                ];
                                // Modern Floating Bottom Nav Bar with Center Cutout
                                // and Live Cart Widget above it
                                return _BottomNavWithLiveCart(
                                  pageIndex: _pageIndex,
                                  isParcel: isParcel,
                                  isTaxi: isTaxi,
                                  isTaxiWithCache: isTaxiWithCache,
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
                                    } else if (isTaxiWithCache) {
                                      Get.to(() => const TaxiCartScreen());
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

  void _setPage(int pageIndex) {
    setState(() {
      _pageController!.jumpToPage(pageIndex);
      _pageIndex = pageIndex;

      // Clear module context when navigating to home tab to show all modules
      if (pageIndex == 0 &&
          Get.find<SplashController>().module != null &&
          Get.find<SplashController>().configModel!.module == null) {
        Get.find<SplashController>().setModule(null);
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

/// Premium Curved Notch Bottom Navigation Bar
/// Features: Curved cutout for center FAB, theme-aware colors, smooth animations
class _CenteredCutoutBottomNav extends StatelessWidget {
  final int pageIndex;
  final bool isParcel;
  final bool isTaxi;
  final bool isTaxiWithCache;
  final bool isLogin;
  final bool showBottomSheet;
  final bool hasRunningOrders;
  final bool fromSplash;
  final bool showLocationSuggestion;
  final bool active;
  final Function(int) onPageChanged;
  final VoidCallback onCenterTap;

  const _CenteredCutoutBottomNav({
    required this.pageIndex,
    required this.isParcel,
    required this.isTaxi,
    required this.isTaxiWithCache,
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
    final screenWidth = MediaQuery.of(context).size.width;

    // Theme colors
    final primaryColor =
        Theme.of(context).colorScheme.primary; // Dark teal #134E4A
    final secondaryColor =
        Theme.of(context).colorScheme.secondary; // Neon green #1EF2A0

    return SizedBox(
      height: 85 + bottomPadding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main nav bar with curved notch
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 70 + bottomPadding,
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: CustomPaint(
                painter: _CurvedNotchPainter(
                  notchRadius: 38,
                  backgroundColor: Colors.white,
                  shadowColor: Colors.black.withOpacity(0.08),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Left side items
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _CurvedNavItem(
                            iconData: HugeIcons.strokeRoundedHome01,
                            label: 'Home',
                            isSelected: pageIndex == 0,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                            onTap: () => onPageChanged(0),
                          ),
                          _CurvedNavItem(
                            iconData: HugeIcons.strokeRoundedWink,
                            label: 'Earn More',
                            isSelected: pageIndex == 1,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                            onTap: () => onPageChanged(1),
                          ),
                        ],
                      ),
                    ),
                    // Center spacer for FAB
                    const SizedBox(width: 80),
                    // Right side items
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _CurvedNavItem(
                            iconData: HugeIcons.strokeRoundedProfile,
                            label: 'Orders',
                            isSelected: pageIndex == 3,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                            onTap: () => onPageChanged(3),
                          ),
                          _CurvedNavItem(
                            iconData: HugeIcons.strokeRoundedUser,
                            label: 'Account',
                            isSelected: pageIndex == 4,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                            onTap: () => onPageChanged(4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Floating center cart button with badge
          Positioned(
            top: 0,
            left: (screenWidth - 60) / 2,
            child: GetBuilder<CartController>(
              builder: (cartController) {
                final itemCount = cartController.cartList.length;
                return _FloatingCartButton(
                  isSelected: pageIndex == 2,
                  onTap: onCenterTap,
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                  itemCount: itemCount,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for curved notch background
class _CurvedNotchPainter extends CustomPainter {
  final double notchRadius;
  final Color backgroundColor;
  final Color shadowColor;

  _CurvedNotchPainter({
    required this.notchRadius,
    required this.backgroundColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill;

    final shadowPaint =
        Paint()
          ..color = shadowColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();
    final centerX = size.width / 2;
    final notchDepth = notchRadius + 8;
    final curveWidth = notchRadius + 20;

    // Start from left
    path.moveTo(0, 0);

    // Line to start of notch curve
    path.lineTo(centerX - curveWidth, 0);

    // First curve down into notch
    path.quadraticBezierTo(
      centerX - notchRadius * 0.6,
      0,
      centerX - notchRadius * 0.5,
      notchDepth * 0.5,
    );

    // Arc around the notch
    path.arcToPoint(
      Offset(centerX + notchRadius * 0.5, notchDepth * 0.5),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );

    // Curve back up from notch
    path.quadraticBezierTo(
      centerX + notchRadius * 0.6,
      0,
      centerX + curveWidth,
      0,
    );

    // Line to right edge
    path.lineTo(size.width, 0);

    // Complete the rectangle
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Draw shadow first
    canvas.drawPath(path.shift(const Offset(0, -2)), shadowPaint);

    // Draw background
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CurvedNotchPainter oldDelegate) =>
      oldDelegate.notchRadius != notchRadius ||
      oldDelegate.backgroundColor != backgroundColor;
}

/// Navigation item for curved notch design
class _CurvedNavItem extends StatefulWidget {
  final List<List<dynamic>> iconData;
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onTap;

  const _CurvedNavItem({
    required this.iconData,
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onTap,
  });

  @override
  State<_CurvedNavItem> createState() => _CurvedNavItemState();
}

class _CurvedNavItemState extends State<_CurvedNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // Selected: primary color (dark teal), Unselected: grey
    final color =
        widget.isSelected ? widget.primaryColor : const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 70,
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with selection animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      widget.isSelected
                          ? widget.secondaryColor.withOpacity(0.15)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(icon: widget.iconData, color: color, size: 22),
              ),
              const SizedBox(height: 2),
              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: 0.1,
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

/// Floating cart button that sits in the notch with item count badge
class _FloatingCartButton extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color secondaryColor;
  final int itemCount;

  const _FloatingCartButton({
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
    required this.secondaryColor,
    this.itemCount = 0,
  });

  @override
  State<_FloatingCartButton> createState() => _FloatingCartButtonState();
}

class _FloatingCartButtonState extends State<_FloatingCartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = widget.itemCount > 0;

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main button
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Soft dark teal gradient - easier on the eyes
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.primaryColor.withOpacity(0.95), // Dark teal
                        widget.primaryColor,
                      ],
                    ),
                    boxShadow: [
                      // Soft shadow for depth
                      BoxShadow(
                        color: widget.primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      // Subtle ambient shadow
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedShoppingBag02,
                      size: 26,
                      color:
                          Theme.of(
                            context,
                          ).secondaryHeaderColor, // White icon for contrast
                    ),
                  ),
                ),
              ),
              // Badge with item count
              if (hasItems)
                Positioned(
                  right: 0,
                  top: 0,
                  child: AnimatedScale(
                    scale: hasItems ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.elasticOut,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444), // Red badge
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.itemCount > 99 ? '99+' : '${widget.itemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
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

/// Wrapper widget that combines LiveCartWidget above the bottom nav bar
/// Features scroll-aware hiding of bottom nav while keeping LiveCartWidget visible
class _BottomNavWithLiveCart extends StatefulWidget {
  final int pageIndex;
  final bool isParcel;
  final bool isTaxi;
  final bool isTaxiWithCache;
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
    required this.isTaxi,
    required this.isTaxiWithCache,
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

class _BottomNavWithLiveCartState extends State<_BottomNavWithLiveCart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

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
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide when certain conditions are met
    if (widget.fromSplash && widget.showLocationSuggestion && widget.active) {
      return const SizedBox();
    }

    // Hide bottom nav entirely when on cart page — cart has its own checkout button
    if (widget.pageIndex == 2) {
      return const SizedBox();
    }

    // Hide bottom nav for grocery or food module - show LiveCartWidget instead
    return GetBuilder<SplashController>(
      builder: (splashController) {
        // Check if current module is grocery or food
        final module = splashController.module;
        final isGroceryOrFood =
            module != null &&
            (module.moduleType.toString() == AppConstants.grocery ||
                module.moduleType.toString() == AppConstants.food);

        // For grocery/food modules, show floating LiveCartWidget instead of bottom nav
        if (isGroceryOrFood) {
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
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 8,
                    ),
                    child: LiveCartWidget(
                      onTap: () => Get.toNamed(RouteHelper.getCartRoute()),
                    ),
                  ),
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
                child: _CenteredCutoutBottomNav(
                  pageIndex: widget.pageIndex,
                  isParcel: widget.isParcel,
                  isTaxi: widget.isTaxi,
                  isTaxiWithCache: widget.isTaxiWithCache,
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
