import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';

class HomeAppBarWidget extends StatelessWidget {
  const HomeAppBarWidget({super.key});

  String _getShortAddress(String? fullAddress) {
    if (fullAddress == null || fullAddress.isEmpty) {
      return 'your_location'.tr;
    }

    final parts = fullAddress.split(',').map((e) => e.trim()).toList();
    if (parts.isEmpty) return fullAddress;

    // Skip plus codes and collect readable location parts
    List<String> readableParts = [];
    for (var part in parts) {
      // Skip if it looks like a plus code (contains + and alphanumeric)
      if (part.contains('+') && part.length < 15) continue;
      // Skip if it's mostly numbers/coordinates
      if (RegExp(r'^\d+').hasMatch(part)) continue;
      // Found a readable name
      if (part.isNotEmpty) {
        readableParts.add(part);
        // Take first 2 meaningful parts max (e.g., "Maadi Al Khabiri")
        if (readableParts.length >= 2) break;
      }
    }

    // Fallback to first part if nothing found
    if (readableParts.isEmpty) {
      readableParts.add(parts[0]);
    }

    // Join parts and check length
    String shortAddress = readableParts.join(', ');

    // If still too long, use just first part
    if (shortAddress.length > 30) {
      shortAddress = readableParts[0];
    }

    return shortAddress;
  }

  @override
  Widget build(BuildContext context) {
    final splashController = Get.find<SplashController>();
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
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeSmall,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeSmall,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar with Greeting + Notification
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar and Greeting together
                    if (!showModuleIcon)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _UserAvatarWithLevel(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GetBuilder<ProfileController>(
                                builder: (profileController) {
                                  final user = profileController.userInfoModel;
                                  final firstName = user?.fName ?? 'User';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _AnimatedGreetingWidget(
                                      firstName: firstName,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    _NotificationButton(),
                  ],
                ),

                const SizedBox(height: Dimensions.paddingSizeSmall),

                // Location
                GetBuilder<LocationController>(
                  builder: (locationController) {
                    final address =
                        AddressHelper.getUserAddressFromSharedPref();
                    final displayAddress = _getShortAddress(address?.address);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap:
                            () => Get.find<LocationController>()
                                .navigateToLocationScreen('home'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  displayAddress,
                                  style: robotoMedium.copyWith(
                                    fontSize: Dimensions.fontSizeDefault,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color!
                                        .withValues(alpha: 0.85),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color!
                                    .withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedGreetingWidget extends StatefulWidget {
  final String firstName;

  const _AnimatedGreetingWidget({required this.firstName});

  @override
  State<_AnimatedGreetingWidget> createState() =>
      _AnimatedGreetingWidgetState();
}

class _AnimatedGreetingWidgetState extends State<_AnimatedGreetingWidget> {
  final List<String> _greetingKeys = [
    'greeting_hungry',
    'greeting_grocery',
    'greeting_medicine',
    'greeting_pet_food',
  ];

  int _currentIndex = 0;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      // Fade out
      setState(() {
        _opacity = 0.0;
      });

      // Change text and fade in
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % _greetingKeys.length;
          _opacity = 1.0;
        });

        _startAnimation();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: _greetingKeys[_currentIndex].tr,
              style: robotoBold.copyWith(
                fontSize: 24,
                color: Theme.of(context).primaryColor,
                height: 1.2,
              ),
            ),
            TextSpan(
              text: ' ${widget.firstName}',
              style: robotoBold.copyWith(
                fontSize: 24,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.7),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserAvatarWithLevel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    final bool isLoggedIn = AuthHelper.isLoggedIn();

    if (!isLoggedIn) {
      return GestureDetector(
        onTap: () => Get.toNamed(RouteHelper.getSignInRoute(RouteHelper.main)),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primaryColor.withValues(alpha: 0.15), width: 1),
          ),
          child: Icon(
            Icons.person_outline_rounded,
            size: 20,
            color: primaryColor,
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

            return GestureDetector(
              onTap: () => Get.toNamed(RouteHelper.getMainRoute('levels')),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          user?.imageFullUrl != null &&
                                  user!.imageFullUrl!.isNotEmpty
                              ? Image.network(
                                user.imageFullUrl!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => _buildDefaultAvatar(
                                      context,
                                      levelNumber,
                                    ),
                              )
                              : _buildDefaultAvatar(context, levelNumber),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          'LV $levelNumber',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDefaultAvatar(BuildContext context, int level) {
    final Color primaryColor = Theme.of(context).primaryColor;
    return Container(
      color: primaryColor.withValues(alpha: 0.08),
      child: Center(
        child: Icon(Icons.person_rounded, size: 22, color: primaryColor),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<NotificationController>(
      builder: (notificationController) {
        return GestureDetector(
          onTap: () => Get.toNamed(RouteHelper.getNotificationRoute()),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    CupertinoIcons.bell_fill,
                    size: 19,
                    color: primaryColor,
                  ),
                ),
                if (notificationController.hasNotification)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      height: 8,
                      width: 8,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(width: 1.5, color: Colors.white),
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
