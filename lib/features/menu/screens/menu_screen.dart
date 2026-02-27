import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:sixam_mart/features/auth/widgets/auth_dialog_widget.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/language/controllers/language_controller.dart';
import 'package:sixam_mart/features/language/widgets/language_bottom_sheet_widget.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/favourite/controllers/favourite_controller.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/rental_module/rental_cart_screen/controllers/taxi_cart_controller.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_level_model.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/confirmation_dialog.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = Get.isDarkMode;
    if (AuthHelper.isLoggedIn()) {
      Get.find<XpController>().getCurrentLevel();
      Get.find<XpController>().getAllLevels();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor; // 0xFF134E4A dark teal
    final secondaryColor =
        Theme.of(context).colorScheme.secondary; // 0xFF1EF2A0 neon green

    return Scaffold(
      backgroundColor: Colors.white,
      body: GetBuilder<ProfileController>(
        builder: (profileController) {
          final bool isLoggedIn = AuthHelper.isLoggedIn();

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  const SizedBox(height: 12),

                  // Compact ID Card
                  _buildCompactIdCard(
                    context,
                    profileController,
                    isLoggedIn,
                    primaryColor,
                    secondaryColor,
                  ),

                  const SizedBox(height: 20),

                  // Settings Section
                  _buildSection(
                    context,
                    title: 'settings'.tr,
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.person_outline_rounded,
                        title: 'profile'.tr,
                        subtitle: 'Update and modify your profile',
                        iconBackgroundColor: secondaryColor.withOpacity(0.22),
                        iconColor: primaryColor,
                        onTap: () => Get.toNamed(RouteHelper.getProfileRoute()),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.location_on_outlined,
                        title: 'my_address'.tr,
                        subtitle: 'Manage your delivery addresses',
                        iconBackgroundColor: secondaryColor.withOpacity(0.22),
                        iconColor: primaryColor,
                        onTap: () => Get.toNamed(RouteHelper.getAddressRoute()),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.language_rounded,
                        title: 'language'.tr,
                        subtitle: 'Change your preferred language',
                        iconBackgroundColor: secondaryColor.withOpacity(0.22),
                        iconColor: primaryColor,
                        onTap: () => _manageLanguageFunctionality(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Promotional Activity Section
                  _buildSection(
                    context,
                    title: 'promotional_activity'.tr,
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.local_offer_outlined,
                        title: 'coupon'.tr,
                        iconBackgroundColor: secondaryColor.withOpacity(0.22),
                        iconColor: primaryColor,
                        onTap: () => Get.toNamed(RouteHelper.getCouponRoute()),
                      ),
                      if (Get.find<SplashController>()
                              .configModel!
                              .loyaltyPointStatus ==
                          1)
                        _buildMenuItem(
                          context,
                          icon: Icons.stars_outlined,
                          title: 'loyalty_points'.tr,
                          iconBackgroundColor: secondaryColor.withOpacity(0.22),
                          iconColor: primaryColor,
                          suffix:
                              !isLoggedIn
                                  ? null
                                  : '${profileController.userInfoModel?.loyaltyPoint ?? 0} ${'points'.tr}',
                          onTap:
                              () => Get.toNamed(RouteHelper.getLoyaltyRoute()),
                        ),
                      if (Get.find<SplashController>()
                              .configModel!
                              .customerWalletStatus ==
                          1)
                        _buildMenuItem(
                          context,
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'my_wallet'.tr,
                          iconBackgroundColor: secondaryColor.withOpacity(0.22),
                          iconColor: primaryColor,
                          suffix:
                              !isLoggedIn
                                  ? null
                                  : PriceConverter.convertPrice(
                                    profileController
                                            .userInfoModel
                                            ?.walletBalance ??
                                        0,
                                  ),
                          onTap:
                              () => Get.toNamed(RouteHelper.getWalletRoute()),
                          showDivider: false,
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Help & Support Section
                  _buildSection(
                    context,
                    title: 'help_and_support'.tr,
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.chat_bubble_outline,
                        title: 'live_chat'.tr,
                        iconBackgroundColor: secondaryColor.withOpacity(0.22),
                        iconColor: primaryColor,
                        onTap:
                            () =>
                                Get.toNamed(RouteHelper.getConversationRoute()),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.help_outline,
                        title: 'help_and_support'.tr,
                        iconBackgroundColor: secondaryColor.withOpacity(0.22),
                        iconColor: primaryColor,
                        onTap: () => Get.toNamed(RouteHelper.getSupportRoute()),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.info_outline,
                        title: 'about_us'.tr,
                        iconBackgroundColor: secondaryColor.withOpacity(0.22),
                        iconColor: primaryColor,
                        onTap:
                            () => Get.toNamed(
                              RouteHelper.getHtmlRoute('about-us'),
                            ),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.description_outlined,
                        title: 'terms_conditions'.tr,
                        iconBackgroundColor: secondaryColor.withOpacity(0.22),
                        iconColor: primaryColor,
                        onTap:
                            () => Get.toNamed(
                              RouteHelper.getHtmlRoute('terms-and-condition'),
                            ),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.privacy_tip_outlined,
                        title: 'privacy_policy'.tr,
                        iconBackgroundColor: secondaryColor.withOpacity(0.22),
                        iconColor: primaryColor,
                        onTap:
                            () => Get.toNamed(
                              RouteHelper.getHtmlRoute('privacy-policy'),
                            ),
                        showDivider: false,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Account Section
                  _buildSection(
                    context,
                    title: 'account'.tr,
                    children: [
                      if (isLoggedIn)
                        _buildMenuItem(
                          context,
                          icon: Icons.delete_outline,
                          title: 'delete_account'.tr,
                          iconColor: Colors.white,
                          iconBackgroundColor: const Color(0xFFDC2626),
                          textColor: const Color(0xFFDC2626),
                          onTap: () {
                            Get.dialog(
                              ConfirmationDialog(
                                icon: Images.warning,
                                description:
                                    'are_you_sure_to_delete_account'.tr,
                                onYesPressed: () {
                                  profileController.deleteUser();
                                },
                              ),
                              useSafeArea: false,
                            );
                          },
                        ),
                      _buildMenuItem(
                        context,
                        icon: isLoggedIn ? Icons.logout : Icons.login,
                        title: isLoggedIn ? 'logout'.tr : 'sign_in'.tr,
                        iconColor:
                            isLoggedIn
                                ? Colors.white
                                : Theme.of(context).primaryColor,
                        iconBackgroundColor:
                            isLoggedIn ? const Color(0xFFDC2626) : null,
                        textColor:
                            isLoggedIn
                                ? const Color(0xFFDC2626)
                                : Theme.of(context).primaryColor,
                        showDivider: false,
                        onTap: () async {
                          if (AuthHelper.isLoggedIn()) {
                            Get.dialog(
                              ConfirmationDialog(
                                icon: Images.support,
                                description: 'are_you_sure_to_logout'.tr,
                                isLogOut: true,
                                onYesPressed: () async {
                                  Get.find<AuthController>().resetOtpView();
                                  Get.find<ProfileController>().clearUserInfo();
                                  Get.find<AuthController>().socialLogout();
                                  Get.find<CartController>().clearCartList(
                                    canRemoveOnline: false,
                                  );
                                  Get.find<FavouriteController>()
                                      .removeFavourite();
                                  await Get.find<AuthController>()
                                      .clearSharedData();
                                  Get.find<HomeController>()
                                      .forcefullyNullCashBackOffers();
                                  Get.find<TaxiCartController>()
                                      .getCarCartList();
                                  Get.offAllNamed(
                                    RouteHelper.getInitialRoute(),
                                  );
                                },
                              ),
                              useSafeArea: false,
                            );
                          } else {
                            Get.find<FavouriteController>().removeFavourite();
                            await Get.toNamed(
                              RouteHelper.getSignInRoute(Get.currentRoute),
                            );
                            if (AuthHelper.isLoggedIn()) {
                              await Get.find<FavouriteController>()
                                  .getFavouriteList();
                              profileController.getUserInfo();
                            }
                          }
                        },
                      ),
                    ],
                  ),

                  SizedBox(
                    height:
                        ResponsiveHelper.isDesktop(context)
                            ? Dimensions.paddingSizeExtremeLarge
                            : 100,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactIdCard(
    BuildContext context,
    ProfileController profileController,
    bool isLoggedIn,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        final currentLevel = xpController.currentLevel;
        final levelsListModel = xpController.levelsListModel;
        final levelName = currentLevel?.levelName ?? 'Newbie';
        final levelNumber = currentLevel?.currentLevel ?? 1;
        final currentXp = currentLevel?.currentXp ?? 0;
        final xpForNextLevel = currentLevel?.xpForNextLevel ?? 100;
        final progressPercentage = currentLevel?.progressPercentage ?? 0.0;

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.6),
                offset: const Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor, width: 2),
            ),
            child: Column(
              children: [
                // Header bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.asset(
                          'assets/image/Group 3.png',
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Your Official Foodie License",
                        style: robotoBold.copyWith(
                          fontSize: 12,
                          color: secondaryColor,
                        ),
                      ),

                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isLoggedIn && profileController.userInfoModel != null
                              ? 'ID ${profileController.userInfoModel!.id.toString().padLeft(4, '0')} ${DateTime.now().year}'
                              : 'ID 0000 ${DateTime.now().year}',
                          style: robotoRegular.copyWith(
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.7),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: secondaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.verified_user,
                          color: secondaryColor,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with profile image or initial letter and edit button
                      Stack(
                        children: [
                          Container(
                            width: 70,
                            height: 85,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: primaryColor, width: 2),
                              color: primaryColor.withOpacity(0.1),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.2),
                                  offset: const Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child:
                                  isLoggedIn &&
                                          profileController.userInfoModel ==
                                              null
                                      ? Shimmer(
                                        child: Container(
                                          width: 70,
                                          height: 85,
                                          color: Colors.grey.shade300,
                                        ),
                                      )
                                      : (isLoggedIn &&
                                          profileController.userInfoModel !=
                                              null &&
                                          profileController
                                                  .userInfoModel!
                                                  .imageFullUrl !=
                                              null &&
                                          profileController
                                              .userInfoModel!
                                              .imageFullUrl!
                                              .isNotEmpty)
                                      ? CustomImage(
                                        image:
                                            profileController
                                                .userInfoModel!
                                                .imageFullUrl!,
                                        height: 85,
                                        width: 70,
                                        fit: BoxFit.cover,
                                      )
                                      : Center(
                                        child: Text(
                                          _getInitials(
                                            profileController,
                                            isLoggedIn,
                                          ),
                                          style: robotoBold.copyWith(
                                            fontSize: 32,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                            ),
                          ),
                          // Edit button
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap:
                                  () => Get.toNamed(
                                    RouteHelper.getUpdateProfileRoute(),
                                  ),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: secondaryColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: primaryColor,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.3),
                                      offset: const Offset(1, 1),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Details with progress bar
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCompactField(
                              'name'.tr.toUpperCase(),
                              isLoggedIn &&
                                      profileController.userInfoModel != null
                                  ? '${profileController.userInfoModel?.fName ?? ''} ${profileController.userInfoModel?.lName ?? ''}'
                                  : 'guest_user'.tr,
                              primaryColor,
                              secondaryColor,
                              isLarge: true,
                              isLoading:
                                  isLoggedIn &&
                                  profileController.userInfoModel == null,
                            ),
                            const SizedBox(height: 8),
                            _buildCompactField(
                              'phone'.tr.toUpperCase(),
                              isLoggedIn &&
                                      profileController.userInfoModel != null
                                  ? profileController.userInfoModel!.phone ??
                                      '-'
                                  : '-',
                              primaryColor,
                              secondaryColor,
                              isLarge: true,
                              valueColor: primaryColor,
                            ),
                            const SizedBox(height: 12),
                            // Progress bar inline
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: secondaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: primaryColor,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'LV.$levelNumber',
                                        style: robotoBold.copyWith(
                                          fontSize: 9,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  levelName,
                                  style: robotoMedium.copyWith(
                                    fontSize: 10,
                                    color: primaryColor,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$currentXp / $xpForNextLevel XP',
                                  style: robotoMedium.copyWith(
                                    fontSize: 10,
                                    color: primaryColor.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Improved progress bar - full width, more visible
                            Stack(
                              children: [
                                // Background track
                                Container(
                                  height: 10,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: primaryColor.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                // Progress fill
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final progressWidth =
                                        constraints.maxWidth *
                                        (progressPercentage / 100).clamp(
                                          0.0,
                                          1.0,
                                        );
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 600,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      height: 10,
                                      width:
                                          progressWidth > 0 ? progressWidth : 0,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            secondaryColor,
                                            secondaryColor.withOpacity(0.85),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: secondaryColor.withOpacity(
                                              0.5,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Next Prize Text
                if (isLoggedIn &&
                    _getNextLevel(levelsListModel, levelNumber) != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border(
                        top: BorderSide(color: primaryColor.withOpacity(0.1)),
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            _getPrizeIcon(
                              _getNextLevel(levelsListModel, levelNumber)!,
                            ),
                            color: primaryColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Unlock Level ${_getNextLevel(levelsListModel, levelNumber)!.level}',
                                style: robotoMedium.copyWith(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),

                              Text(
                                'To Get ${_getNextPrizeTitle(_getNextLevel(levelsListModel, levelNumber)!)}',
                                style: robotoRegular.copyWith(
                                  fontSize: 12,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Login for guests (no badges section)
                if (!isLoggedIn)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.05),
                      border: Border(
                        top: BorderSide(color: primaryColor.withOpacity(0.15)),
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: Center(
                      child: InkWell(
                        onTap: () async {
                          if (!ResponsiveHelper.isDesktop(context)) {
                            await Get.toNamed(
                              RouteHelper.getSignInRoute(Get.currentRoute),
                            );
                            if (AuthHelper.isLoggedIn()) {
                              profileController.getUserInfo();
                              Get.find<XpController>().getCurrentLevel();
                              Get.find<XpController>().getAllLevels();
                            }
                          } else {
                            Get.dialog(
                              const Center(
                                child: AuthDialogWidget(
                                  exitFromApp: true,
                                  backFromThis: true,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: primaryColor, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4),
                                offset: const Offset(1.5, 1.5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.login, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'sign_in'.tr,
                                style: robotoMedium.copyWith(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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

  String _getInitials(ProfileController profileController, bool isLoggedIn) {
    if (!isLoggedIn || profileController.userInfoModel == null) {
      return 'G';
    }
    final firstName = profileController.userInfoModel?.fName ?? '';
    final lastName = profileController.userInfoModel?.lName ?? '';
    if (firstName.isEmpty && lastName.isEmpty) {
      return 'U';
    }
    String initials = '';
    if (firstName.isNotEmpty) {
      initials += firstName[0].toUpperCase();
    }
    if (lastName.isNotEmpty) {
      initials += lastName[0].toUpperCase();
    }
    return initials.isNotEmpty ? initials : 'U';
  }

  Level? _getNextLevel(
    LevelsListModel? levelsListModel,
    int currentLevelNumber,
  ) {
    if (levelsListModel == null) return null;
    final levels = levelsListModel.levels;
    for (final level in levels) {
      if (level.level > currentLevelNumber) {
        return level;
      }
    }
    return null;
  }

  IconData _getPrizeIcon(Level level) {
    if (level.prizes.isNotEmpty) {
      final prizeType = level.prizes.first.type.toLowerCase();
      switch (prizeType) {
        case 'free_delivery':
          return Icons.local_shipping_outlined;
        case 'discount':
          return Icons.percent_outlined;
        case 'wallet_credit':
          return Icons.account_balance_wallet_outlined;
        case 'badge':
          return Icons.workspace_premium_outlined;
        default:
          return Icons.card_giftcard_outlined;
      }
    }
    return Icons.emoji_events_outlined;
  }

  String _getNextPrizeTitle(Level level) {
    if (level.prizes.isNotEmpty) {
      return level.prizes.first.title;
    }
    return 'Reach ${level.name}';
  }

  Widget _buildCompactField(
    String label,
    String value,
    Color primaryColor,
    Color secondaryColor, {
    bool isLarge = false,
    bool isLoading = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 45,
          child: Text(
            label,
            style: robotoRegular.copyWith(
              fontSize: 8,
              color: primaryColor.withOpacity(0.5),
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child:
              isLoading
                  ? Shimmer(
                    child: Container(
                      height: isLarge ? 14 : 11,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  )
                  : Text(
                    value,
                    style: (isLarge ? robotoBold : robotoMedium).copyWith(
                      fontSize: isLarge ? 14 : 11,
                      color: valueColor ?? primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(
            left: Dimensions.paddingSizeDefault + 4,
            bottom: 10,
          ),
          child: Text(
            title,
            style: robotoMedium.copyWith(
              fontSize: 13,
              color: Theme.of(context).primaryColor.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Grouped Card Container
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    String? suffix,
    Color? iconColor,
    Color? iconBackgroundColor,
    Color? textColor,
    bool showDivider = true,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    // Use vibrant, distinct background colors for each icon type
    final defaultIconBgColor = secondaryColor.withOpacity(0.15);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border:
                showDivider
                    ? Border(
                      bottom: BorderSide(color: Colors.grey.shade100, width: 1),
                    )
                    : null,
          ),
          child: Row(
            children: [
              // Solid vibrant icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackgroundColor ?? defaultIconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor ?? primaryColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: robotoMedium.copyWith(
                        fontSize: 15,
                        color: textColor ?? const Color(0xFF1E293B),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: robotoRegular.copyWith(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (suffix != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    suffix,
                    style: robotoMedium.copyWith(
                      fontSize: 12,
                      color: primaryColor,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? iconColor,
    Color? iconBackgroundColor,
    bool showDivider = true,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border:
            showDivider
                ? Border(
                  bottom: BorderSide(color: Colors.grey.shade100, width: 1),
                )
                : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackgroundColor ?? secondaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor ?? primaryColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: robotoMedium.copyWith(
                    fontSize: 15,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: robotoRegular.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: secondaryColor,
              trackColor: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  _manageLanguageFunctionality() {
    Get.find<LocalizationController>().saveCacheLanguage(null);
    Get.find<LocalizationController>().searchSelectedLanguage();
    showModalBottomSheet(
      isScrollControlled: true,
      useRootNavigator: true,
      context: Get.context!,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(Dimensions.radiusExtraLarge),
          topRight: Radius.circular(Dimensions.radiusExtraLarge),
        ),
      ),
      builder:
          (context) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: const LanguageBottomSheetWidget(),
          ),
    ).then(
      (value) => Get.find<LocalizationController>().setLanguage(
        Get.find<LocalizationController>().getCacheLocaleFromSharedPref(),
      ),
    );
  }
}
