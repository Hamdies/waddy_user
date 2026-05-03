import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';

// ── Design tokens matching the reference ──
const Color _mintLight = Color(0xFFE8F5F0);

class HomeAppBarWidget extends StatelessWidget {
  const HomeAppBarWidget({super.key});

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'good_morning'.tr;
    if (hour >= 12 && hour < 17) return 'good_afternoon'.tr;
    if (hour >= 17 && hour < 21) return 'good_evening'.tr;
    return 'good_night'.tr;
  }

  String _getShortAddress(String? fullAddress) {
    if (fullAddress == null || fullAddress.isEmpty) {
      return 'your_location'.tr;
    }

    final parts = fullAddress.split(',').map((e) => e.trim()).toList();
    if (parts.isEmpty) return fullAddress;

    List<String> readableParts = [];
    for (var part in parts) {
      if (part.contains('+') && part.length < 15) continue;
      if (RegExp(r'^\d+').hasMatch(part)) continue;
      if (part.isNotEmpty) {
        readableParts.add(part);
        if (readableParts.length >= 2) break;
      }
    }

    if (readableParts.isEmpty) {
      readableParts.add(parts[0]);
    }

    String shortAddress = readableParts.join(', ');
    if (shortAddress.length > 35) {
      shortAddress = readableParts[0];
    }

    return shortAddress;
  }

  @override
  Widget build(BuildContext context) {
    final splashController = Get.find<SplashController>();
    final Color teal = Theme.of(context).primaryColor;
    final Color mint = Theme.of(context).secondaryHeaderColor;
    final Color textDark = Theme.of(context).textTheme.bodyLarge!.color!;
    const Color gray = Color(0xFF8E9A98);

    final bool showModuleIcon =
        splashController.module != null &&
        splashController.configModel!.module == null &&
        splashController.moduleList != null &&
        splashController.moduleList!.length != 1;

    return RamadanStringLightWrapper(
      position: WrapperPosition.top,
      showTopString: false,
      showBottomString: false,
      showRightConnector: false,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: Avatar + Greeting + Coins + Cart ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!showModuleIcon) ...[
                      _UserAvatarWithLevel(teal: teal, mint: mint),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GetBuilder<ProfileController>(
                          builder: (profileController) {
                            final user = profileController.userInfoModel;
                            final firstName = user?.fName ?? 'User';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_getTimeGreeting()},',
                                  style: robotoRegular.copyWith(
                                    fontSize: 12,
                                    color: gray,
                                  ),
                                ),
                                Text(
                                  '$firstName 👋',
                                  style: robotoBold.copyWith(
                                    fontSize: 17,
                                    color: textDark,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    if (showModuleIcon) const Spacer(),
                    if (AuthHelper.isLoggedIn()) ...[
                      _CoinsPill(teal: teal, textDark: textDark),
                      const SizedBox(width: 8),
                    ],
                    _CartButton(teal: teal),
                  ],
                ),

             

                const SizedBox(height: 10),

                // ── Row 2: Location ──
                GetBuilder<LocationController>(
                  builder: (locationController) {
                    final address =
                        AddressHelper.getUserAddressFromSharedPref();
                    final displayAddress = _getShortAddress(address?.address);

                    return GestureDetector(
                      onTap:
                          () => Get.find<LocationController>()
                              .navigateToLocationScreen('home'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📍', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              displayAddress,
                              style: robotoMedium.copyWith(
                                fontSize: 13,
                                color: teal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '▼',
                            style: TextStyle(
                              fontSize: 11,
                              color: teal.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                // ── Row 3: Search Bar ──
                _SearchBar(teal: teal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Search bar — tappable, navigates to search screen
class _SearchBar extends StatelessWidget {
  final Color teal;
  const _SearchBar({required this.teal});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(RouteHelper.getSearchRoute()),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.search, color: const Color(0xFFB0B8B6), size: 20),
            const SizedBox(width: 10),
            Text(
              'search_food_or_restaurant'.tr,
              style: robotoRegular.copyWith(
                fontSize: 14,
                color: const Color(0xFFB0B8B6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// XP pill — white rounded pill with coin icon + XP points count
class _CoinsPill extends StatelessWidget {
  final Color teal;
  final Color textDark;
  const _CoinsPill({required this.teal, required this.textDark});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        final xpPoints = xpController.currentLevel?.currentXp ?? 0;
        return GestureDetector(
          onTap: () => Get.toNamed(RouteHelper.getMainRoute('levels')),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _mintLight,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: teal.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/image/waddy_coin.png',
                  width: 22,
                  height: 22,
                ),
                const SizedBox(width: 5),
                Text(
                  '$xpPoints',
                  style: robotoBold.copyWith(
                    fontSize: 13,
                    color: teal,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 14,
                  color: teal.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Avatar — 46x46, gradient teal, rounded 14, LV badge at bottom-right
class _UserAvatarWithLevel extends StatelessWidget {
  final Color teal;
  final Color mint;
  const _UserAvatarWithLevel({required this.teal, required this.mint});

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = AuthHelper.isLoggedIn();

    if (!isLoggedIn) {
      return GestureDetector(
        onTap: () => Get.toNamed(RouteHelper.getSignInRoute(RouteHelper.main)),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [teal, const Color(0xFF1A7A6E)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 22,
            color: Colors.white,
          ),
        ),
      );
    }

    return GetBuilder<ProfileController>(
      builder: (profileController) {
        return GetBuilder<XpController>(
          builder: (xpController) {
            final user = profileController.userInfoModel;
            final level = xpController.currentLevel;
            final levelNumber = level?.currentLevel ?? 1;
            final firstName = user?.fName ?? '';

            return GestureDetector(
              onTap: () => Get.toNamed(RouteHelper.getMainRoute('levels')),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Avatar — 46x46 gradient box
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [teal, const Color(0xFF1A7A6E)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child:
                            user?.imageFullUrl != null &&
                                    user!.imageFullUrl!.isNotEmpty
                                ? Image.network(
                                  user.imageFullUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => _buildInitials(firstName),
                                )
                                : _buildInitials(firstName),
                      ),
                    ),
                    // LV badge — bottom-right with white border
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: mint,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          'LV$levelNumber',
                          style: TextStyle(
                            color: teal,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInitials(String firstName) {
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Cart button — 42x42, borderRadius 13, mintLight background
class _CartButton extends StatelessWidget {
  final Color teal;
  const _CartButton({required this.teal});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CartController>(
      builder: (cartController) {
        final itemCount = cartController.cartList.length;
        return GestureDetector(
          onTap: () => Get.toNamed(RouteHelper.getCartRoute()),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _mintLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: SvgPicture.asset(
                    'assets/image/nav_cart.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(teal, BlendMode.srcIn),
                  ),
                ),
                if (itemCount > 0)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      height: 12,
                      width: 12,
                      decoration: BoxDecoration(
                        color: Theme.of(context).secondaryHeaderColor,
                        shape: BoxShape.circle,
                        border: Border.all(width: 1.5, color: Colors.white),
                      ),
                      child: Center(
                        child: Text(
                          itemCount > 9 ? '9+' : '$itemCount',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 7,
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
        );
      },
    );
  }
}

/// One-time gamification hint — shown once after first login, dismissed on tap.
/// Explains the LV badge + coins pill to new users.
class _XpOnboardingHint extends StatefulWidget {
  const _XpOnboardingHint();

  @override
  State<_XpOnboardingHint> createState() => _XpOnboardingHintState();
}

class _XpOnboardingHintState extends State<_XpOnboardingHint>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _checkShouldShow();
  }

  Future<void> _checkShouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(AppConstants.xpOnboardingShown) ?? false;
    if (!shown && mounted) {
      setState(() => _visible = true);
      _ctrl.forward();
    }
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    if (mounted) setState(() => _visible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.xpOnboardingShown, true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final teal = Theme.of(context).primaryColor;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _mintLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: teal.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  '🏆',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'earn_xp_hint'.tr.isNotEmpty && 'earn_xp_hint'.tr != 'earn_xp_hint'
                        ? 'earn_xp_hint'.tr
                        : 'Order, explore & level up — your badge and coins grow with every action.',
                    style: robotoRegular.copyWith(
                      fontSize: 11.5,
                      color: teal.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: teal.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
