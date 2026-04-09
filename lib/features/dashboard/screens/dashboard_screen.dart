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
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';

import 'package:waddy_app/common/widgets/custom_dialog.dart';
import 'package:waddy_app/features/checkout/widgets/congratulation_dialogue.dart';
import 'package:waddy_app/features/dashboard/widgets/parcel_bottom_sheet_widget.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/dashboard/widgets/live_cart_widget.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/features/xp/screens/xp_levels_screen.dart';
import 'package:waddy_app/features/menu/screens/menu_screen.dart';
import 'package:waddy_app/features/order/screens/order_screen.dart';
import 'package:waddy_app/features/cart/screens/cart_screen.dart';
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
    // Skip cart for Places module - it doesn't use cart
    final isPlacesModule =
        Get.find<SplashController>().module?.moduleType.toString() ==
        AppConstants.places;
    if (_isLogin && !isPlacesModule) {
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

                                _screens = [
                                  const HomeScreen(),
                                  const XpLevelsScreen(),
                                  const CartScreen(fromNav: true),
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
      height: 70 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
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
            iconData: HugeIcons.strokeRoundedMoney03,
            label: 'Rewards',
            isSelected: pageIndex == 1,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            onTap: () => onPageChanged(1),
          ),
          // Cart tab with badge
          GetBuilder<CartController>(
            builder: (cartController) {
              final itemCount = cartController.cartList.length;
              return _CartNavItem(
                isSelected: pageIndex == 2,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                itemCount: itemCount,
                onTap: onCenterTap,
              );
            },
          ),
          _CurvedNavItem(
            iconData: HugeIcons.strokeRoundedFileValidation,
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
    );
  }
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
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with selection animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color:
                      widget.isSelected
                          ? widget.secondaryColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: widget.iconData,
                  color: color,
                  size: 22,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(height: 3),
              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
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

/// Cart navigation item with badge — inline in the flat nav bar
class _CartNavItem extends StatefulWidget {
  final bool isSelected;
  final Color primaryColor;
  final Color secondaryColor;
  final int itemCount;
  final VoidCallback onTap;

  const _CartNavItem({
    required this.isSelected,
    required this.primaryColor,
    required this.secondaryColor,
    required this.itemCount,
    required this.onTap,
  });

  @override
  State<_CartNavItem> createState() => _CartNavItemState();
}

class _CartNavItemState extends State<_CartNavItem>
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
    final color =
        widget.isSelected ? widget.primaryColor : const Color(0xFF9CA3AF);
    final hasItems = widget.itemCount > 0;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 70,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color:
                      widget.isSelected
                          ? widget.secondaryColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedShoppingBag02,
                      color: color,
                      size: 20,
                    ),
                    if (hasItems)
                      Positioned(
                        right: -8,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).secondaryHeaderColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              widget.itemCount > 99
                                  ? '99+'
                                  : '${widget.itemCount}',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: 0.1,
                  height: 1.1,
                ),
                child: const Text(
                  'Cart',
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

/// Wrapper widget that combines LiveCartWidget above the bottom nav bar
/// Features scroll-aware hiding of bottom nav while keeping LiveCartWidget visible
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
