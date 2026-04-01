import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/home/widgets/letter_dialog_widget.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';

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
                // ── Row 1: Avatar + Greeting + Notification ──
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
                                    fontSize: 13,
                                    color: gray,
                                  ),
                                ),
                                Text(
                                  '$firstName 👋',
                                  style: robotoBold.copyWith(
                                    fontSize: 18,
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
                    if (kDebugMode) ...[
                      GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const LetterDialogWidget(),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.mail_outline, size: 20, color: Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _NotificationButton(teal: teal),
                  ],
                ),

                const SizedBox(height: 12),

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

/// XP progress bar — mintLight background, no border, matching the reference
class _XpProgressBar extends StatelessWidget {
  final Color teal;
  final Color mint;
  const _XpProgressBar({required this.teal, required this.mint});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        final level = xpController.currentLevel;
        if (level == null) return const SizedBox.shrink();

        final progress = (level.progressPercentage / 100).clamp(0.0, 1.0);
        final nextReward = xpController.nextReward;
        final primaryColor = Theme.of(context).primaryColor;
        final accentColor = Theme.of(context).secondaryHeaderColor;

        return GestureDetector(
          onTap: () => Get.toNamed(RouteHelper.getMainRoute('levels')),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0F0F0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Lightning Bolt / Coin Icon on left

                // Column for text and progress bar
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Level Name & Next Reward
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            level.levelName,
                            style: robotoBold.copyWith(
                              fontSize: 14,
                              color: primaryColor,
                            ),
                          ),
                          if (nextReward != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${xpController.getRewardIcon(nextReward.type)} ',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                Text(
                                  nextReward.title,
                                  style: robotoMedium.copyWith(
                                    fontSize: 11,
                                    color: primaryColor.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Compact Progress Bar with Chest
                      SizedBox(
                        height: 24,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          clipBehavior: Clip.none,
                          children: [
                            // Progress Track
                            Container(
                              height: 16,
                              margin: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAEAEA),
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(8),
                                  right: Radius.circular(4),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Fill Indicator
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: accentColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  // Text Inside
                                  Center(
                                    child: Text(
                                      // xpForNextLevel historically represents total required for current level minus total required for previous level.
                                      // Or if xpToNextLevel = remaining, total required for this level is currentXp + xpToNextLevel
                                      '${level.currentXp} / ${level.currentXp + level.xpToNextLevel} XP',
                                      style: robotoBold.copyWith(
                                        fontSize: 10,
                                        color: primaryColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Chest Icon on right edge
                            Positioned(
                              right: 0,
                              child: Container(
                                height: 26,
                                width: 26,
                                
                                child:  Center(
                                  child: Image.asset("assets/image/waddy_coin.png",)
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/image/waddy_coin.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 5),
                Text(
                  '$xpPoints',
                  style: robotoBold.copyWith(
                    fontSize: 14,
                    color: textDark,
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

/// Notification bell — 42x42, borderRadius 13, mintLight background
class _NotificationButton extends StatelessWidget {
  final Color teal;
  const _NotificationButton({required this.teal});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NotificationController>(
      builder: (notificationController) {
        return GestureDetector(
          onTap: () => Get.toNamed(RouteHelper.getNotificationRoute()),
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
                 Center(child: HugeIcon(icon:HugeIcons.strokeRoundedNotification01, color: teal, size: 20)),
                if (notificationController.hasNotification)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      height: 10,
                      width: 10,
                      decoration: BoxDecoration(
                        color:  Theme.of(  context).secondaryHeaderColor,
                        shape: BoxShape.circle,
                        border: Border.all(width: 2, color: Colors.white),
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
