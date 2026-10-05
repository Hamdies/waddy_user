import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/language/widgets/language_bottom_sheet_widget.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/xp_level_model.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/features/pets/pets_navigator.dart';
import 'package:waddy_app/features/pets/screens/pet_profile_screen.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/confirmation_dialog.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:waddy_app/features/wallet/controllers/wallet_controller.dart';
import 'package:waddy_app/features/wallet/domain/models/card_appearance_model.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _isNotificationEnabled = true;

  @override
  void initState() {
    super.initState();
    if (AuthHelper.isLoggedIn()) {
      Get.find<XpController>().getLevelDetails();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<WalletController>().loadCardAppearance();
      });
    }
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (mounted) {
      setState(() {
        _isNotificationEnabled =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      });
    }
  }

  // ── Theme palette ──
  static const _cardBg = Color(0xFF134E4A);
  static const _cardBorder = Color(0xFF1A6B65);
  static const _labelColor = Color(0xFF9EE8C8);
  static const _valueColor = Colors.white;
  static const _accentGreen = Color(0xFF1EF2A0);
  static const _subtitleColor = Color(0xFF64748B);
  static const _titleColor = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: GetBuilder<ProfileController>(
        builder: (profileController) {
          final bool isLoggedIn = AuthHelper.isLoggedIn();

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // ─── 1. FOODIE LICENCE CARD (Avatar + Name + XP) ───
                  _buildFoodieLicenceCard(
                    context,
                    profileController,
                    isLoggedIn,
                    primaryColor,
                    secondaryColor,
                  ),

                  const SizedBox(height: 16),

                  // ─── 2. QUICK ACTIONS ───
                  _buildQuickActions(
                    context,
                    profileController,
                    isLoggedIn,
                    primaryColor,
                  ),

                  const SizedBox(height: 20),

                  // ════════════════════════════════════════════════
                  //  PERSONAL
                  // ════════════════════════════════════════════════
                  _buildSectionHeader(context, 'Personal'),
                  _buildFlatItem(
                    context,
                    icon: HugeIcons.strokeRoundedUser,
                    title: 'profile'.tr,
                    onTap:
                        () => Get.toNamed(RouteHelper.getUpdateProfileRoute()),
                  ),
                  _buildFlatItem(
                    context,
                    icon: HugeIcons.strokeRoundedLocation01,
                    title: 'my_address'.tr,
                    onTap: () => Get.toNamed(RouteHelper.getAddressRoute()),
                  ),
                  // Only where a Pets module serves this zone.
                  if (PetsNavigator.available)
                    _buildFlatItem(
                      context,
                      icon: HugeIcons.strokeRoundedBone01,
                      title: 'my_pets'.tr,
                      onTap: () => PetProfileScreen.open(),
                    ),
                  _buildFlatItem(
                    context,
                    icon: HugeIcons.strokeRoundedFavourite,
                    title: 'favourite'.tr,
                    onTap: () => Get.toNamed(RouteHelper.getFavouriteScreen()),
                  ),

                  // ════════════════════════════════════════════════
                  //  REWARDS & OFFERS
                  // ════════════════════════════════════════════════
                  _buildSectionHeader(context, 'Rewards & Offers'),
                  _buildFlatItem(
                    context,
                    icon: HugeIcons.strokeRoundedCoupon01,
                    title: 'coupon'.tr,
                    onTap: () => Get.toNamed(RouteHelper.getCouponRoute()),
                  ),
                  if (Get.find<SplashController>()
                          .configModel
                          .loyaltyPointStatus ==
                      1)
                    _buildFlatItem(
                      context,
                      icon: HugeIcons.strokeRoundedStars,
                      title: 'loyalty_points'.tr,
                      suffix:
                          !isLoggedIn
                              ? null
                              : '${profileController.userInfoModel?.loyaltyPoint ?? 0} ${'points'.tr}',
                      onTap: () => Get.toNamed(RouteHelper.getLoyaltyRoute()),
                    ),
                  if (isLoggedIn &&
                      profileController.userInfoModel?.refCode != null)
                    _buildFlatItem(
                      context,
                      icon: HugeIcons.strokeRoundedUserGroup,
                      title: 'Invite Friends',
                      suffix: 'Earn rewards',
                      onTap:
                          () => Get.toNamed(RouteHelper.getReferAndEarnRoute()),
                    ),

                  // ════════════════════════════════════════════════
                  //  PREFERENCES
                  // ════════════════════════════════════════════════
                  _buildSectionHeader(context, 'Preferences'),
                  _buildFlatItem(
                    context,
                    icon: HugeIcons.strokeRoundedLanguageSkill,
                    title: 'language'.tr,
                    onTap: () => _manageLanguageFunctionality(),
                  ),
                  if (isLoggedIn) ...[
                    _buildToggleItem(
                      context,
                      icon: HugeIcons.strokeRoundedNotification02,
                      title: 'Notifications',
                      value: _isNotificationEnabled,
                      onChanged: (val) async {
                        if (!val) {
                          await FirebaseMessaging.instance.deleteToken();
                          setState(() => _isNotificationEnabled = false);
                        } else {
                          final settings =
                              await FirebaseMessaging.instance
                                  .requestPermission();
                          if (settings.authorizationStatus ==
                                  AuthorizationStatus.authorized ||
                              settings.authorizationStatus ==
                                  AuthorizationStatus.provisional) {
                            setState(() => _isNotificationEnabled = true);
                          }
                        }
                      },
                    ),
                    _buildToggleItem(
                      context,
                      icon: HugeIcons.strokeRoundedSmartPhone01,
                      title: 'Hide Phone Number',
                      value:
                          profileController.userInfoModel?.hidePhone ?? false,
                      onChanged: (val) async {
                        final confirmed = await Get.dialog<bool>(
                          AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusLarge,
                              ),
                            ),
                            title: Text(
                              val ? 'Hide Phone Number?' : 'Show Phone Number?',
                              style: waddyBold.copyWith(fontSize: 17),
                            ),
                            content: Text(
                              val
                                  ? 'Your phone number will be hidden from delivery personnel and stores.'
                                  : 'Your phone number will be visible to delivery personnel and stores.',
                              style: waddyRegular.copyWith(
                                fontSize: 14,
                                color: _subtitleColor,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: false),
                                child: Text(
                                  'Cancel',
                                  style: waddyMedium.copyWith(
                                    color: _subtitleColor,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Get.back(result: true),
                                child: Text(
                                  'Confirm',
                                  style: waddyMedium.copyWith(
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          final response = await Get.find<AuthController>()
                              .toggleHidePhone(hidePhone: val);
                          if (response.isSuccess) {
                            profileController.userInfoModel?.hidePhone = val;
                            profileController.update();
                          }
                        }
                      },
                    ),
                  ],

                  // ════════════════════════════════════════════════
                  //  SUPPORT & ACCOUNT
                  // ════════════════════════════════════════════════
                  _buildSectionHeader(context, 'Support & Account'),
                  _buildFlatItem(
                    context,
                    icon: HugeIcons.strokeRoundedHelpCircle,
                    title: 'help_and_support'.tr,
                    onTap: () => Get.toNamed(RouteHelper.getSupportRoute()),
                  ),
                  const SizedBox(height: 8),
                  if (isLoggedIn)
                    _buildFlatItem(
                      context,
                      icon: HugeIcons.strokeRoundedDelete02,
                      title: 'delete_account'.tr,
                      iconColor: _subtitleColor,
                      textColor: const Color(0xFFDC2626),
                      onTap: () {
                        Get.dialog(
                          ConfirmationDialog(
                            icon: Images.warning,
                            description: 'are_you_sure_to_delete_account'.tr,
                            onYesPressed: () => profileController.deleteUser(),
                          ),
                          useSafeArea: false,
                        );
                      },
                    ),
                  _buildFlatItem(
                    context,
                    icon:
                        isLoggedIn
                            ? HugeIcons.strokeRoundedLogout01
                            : HugeIcons.strokeRoundedLogin01,
                    title: isLoggedIn ? 'logout'.tr : 'sign_in'.tr,
                    iconColor: isLoggedIn ? _subtitleColor : primaryColor,
                    textColor:
                        isLoggedIn ? const Color(0xFFDC2626) : primaryColor,
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
                              Get.find<FavouriteController>().removeFavourite();
                              await Get.find<AuthController>()
                                  .clearSharedData();
                              Get.find<HomeController>()
                                  .forcefullyNullCashBackOffers();
                              Get.offAllNamed(RouteHelper.getInitialRoute());
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

                  const SizedBox(height: 24),

                  // ─── FOOTER: Version + Text Links ───
                  Center(
                    child: Text(
                      '--',
                      style: waddyRegular.copyWith(
                        fontSize: 14,
                        color: _subtitleColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Version ${AppConstants.appVersion}',
                      style: waddyRegular.copyWith(
                        fontSize: 13,
                        color: _subtitleColor.withOpacity(0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap:
                            () => Get.toNamed(
                              RouteHelper.getHtmlRoute('privacy-policy'),
                            ),
                        child: Text(
                          'privacy_policy'.tr,
                          style: waddyRegular.copyWith(
                            fontSize: 12,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeSmall,
                        ),
                        child: Text(
                          '|',
                          style: waddyRegular.copyWith(
                            fontSize: 12,
                            color: _subtitleColor.withOpacity(0.4),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap:
                            () => Get.toNamed(
                              RouteHelper.getHtmlRoute('terms-and-condition'),
                            ),
                        child: Text(
                          'terms_conditions'.tr,
                          style: waddyRegular.copyWith(
                            fontSize: 12,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeSmall,
                        ),
                        child: Text(
                          '|',
                          style: waddyRegular.copyWith(
                            fontSize: 12,
                            color: _subtitleColor.withOpacity(0.4),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap:
                            () => Get.toNamed(
                              RouteHelper.getHtmlRoute('about-us'),
                            ),
                        child: Text(
                          'about_us'.tr,
                          style: waddyRegular.copyWith(
                            fontSize: 12,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Made with ❤️ in Egypt',
                      style: waddyRegular.copyWith(
                        fontSize: 11,
                        color: _subtitleColor.withValues(alpha: 0.45),
                      ),
                    ),
                  ),

                  SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. FOODIE LICENCE CARD — Avatar + Name + XP bar (original feel)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFoodieLicenceCard(
    BuildContext context,
    ProfileController profileController,
    bool isLoggedIn,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return GetBuilder<XpController>(
      id: XpController.idLevel,
      builder: (xpController) {
        final currentLevel = xpController.currentLevel;
        final levelsListModel = xpController.levelsListModel;
        final levelNumber = currentLevel?.currentLevel ?? 1;
        final currentXp = currentLevel?.currentXp ?? 0;
        final xpForNextLevel = currentLevel?.xpForNextLevel ?? 100;
        final progressPercentage = currentLevel?.progressPercentage ?? 0.0;

        final userName =
            isLoggedIn && profileController.userInfoModel != null
                ? '${profileController.userInfoModel?.fName ?? ''} ${profileController.userInfoModel?.lName ?? ''}'
                    .trim()
                : 'guest_user'.tr;
        final userPhone =
            isLoggedIn && profileController.userInfoModel != null
                ? profileController.userInfoModel!.phone ?? '-'
                : '-';
        final isLoading = isLoggedIn && profileController.userInfoModel == null;

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
            border: Border.all(color: _cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _cardBg.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top section: avatar + name + greeting ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar with LV badge
                    GestureDetector(
                      onTap:
                          () =>
                              isLoggedIn
                                  ? Get.toNamed(
                                    RouteHelper.getUpdateProfileRoute(),
                                  )
                                  : _handleGuestSignIn(profileController),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              border: Border.all(color: _accentGreen, width: 2),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF134E4A), Color(0xFF1A7A6E)],
                              ),
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusLarge,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusLarge,
                              ),
                              child:
                                  isLoading
                                      ? Shimmer(
                                        child: Container(
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
                                        height: 74,
                                        width: 74,
                                        fit: BoxFit.cover,
                                      )
                                      : Center(
                                        child: Text(
                                          _getInitials(
                                            profileController,
                                            isLoggedIn,
                                          ),
                                          style: waddyBold.copyWith(
                                            fontSize: 28,
                                            color: _valueColor,
                                          ),
                                        ),
                                      ),
                            ),
                          ),
                          // LV badge
                          if (isLoggedIn)
                            Positioned(
                              bottom: -11,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Dimensions.paddingSizeSmall,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accentGreen,
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusSmall,
                                    ),
                                    border: Border.all(
                                      color: _cardBg,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    'LV$levelNumber',
                                    style: waddyBold.copyWith(
                                      fontSize: 10,
                                      color: _cardBg,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Greeting + Name + Phone + Waddi logo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Your Foodie Licence',
                                style: waddyMedium.copyWith(
                                  color: _accentGreen,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap:
                                    () => Get.toNamed(
                                      RouteHelper.getXpLevelsRoute(),
                                    ),
                                child: Image.asset(
                                  'assets/image/waddy.png',
                                  width: 34,
                                  height: 34,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          isLoading
                              ? Shimmer(
                                child: Container(
                                  height: 20,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusExtraSmall,
                                    ),
                                  ),
                                ),
                              )
                              : Text(
                                userName,
                                style: waddyBold.copyWith(
                                  fontSize: 20,
                                  color: _valueColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          const SizedBox(height: 4),
                          Text(
                            userPhone,
                            style: waddyRegular.copyWith(
                              fontSize: 12,
                              color: _labelColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divider ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeMedium,
                ),
                child: Divider(height: 1, color: _cardBorder),
              ),

              // ── XP Progress Section ──
              if (isLoggedIn)
                GestureDetector(
                  onTap: () => Get.toNamed(RouteHelper.getXpLevelsRoute()),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress bar
                        SizedBox(
                          height: 24,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                height: 16,
                                margin: const EdgeInsets.only(right: 22),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0A2E2B),
                                  borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(
                                      Dimensions.radiusSmall,
                                    ),
                                    right: Radius.circular(
                                      Dimensions.radiusExtraSmall,
                                    ),
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: (progressPercentage / 100)
                                          .clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF0D9972),
                                              _accentGreen,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(
                                              Dimensions.radiusSmall,
                                            ),
                                            bottomLeft: Radius.circular(
                                              Dimensions.radiusSmall,
                                            ),
                                            topRight: Radius.circular(
                                              Dimensions.radiusExtraSmall,
                                            ),
                                            bottomRight: Radius.circular(
                                              Dimensions.radiusExtraSmall,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Text(
                                        '$currentXp / ${currentXp + xpForNextLevel} XP',
                                        style: waddyBold.copyWith(
                                          fontSize: 10,
                                          color: secondaryColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 0,
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: Image.asset(
                                    'assets/image/waddy_coin.png',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Next reward teaser
                        if (_getNextLevel(levelsListModel, levelNumber) !=
                            null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(width: 5),
                              Text(
                                'Only $xpForNextLevel XP left for ',
                                style: waddyMedium.copyWith(
                                  fontSize: 11,
                                  color: _labelColor,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _getNextPrizeTitle(
                                    _getNextLevel(
                                      levelsListModel,
                                      levelNumber,
                                    )!,
                                  ),
                                  style: waddyBold.copyWith(
                                    fontSize: 11,
                                    color: _accentGreen,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 15,
                                color: _accentGreen,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // ── Login CTA for guests ──
              if (!isLoggedIn)
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    onTap: () => _handleGuestSignIn(profileController),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: Dimensions.paddingSizeSmall,
                      ),
                      decoration: BoxDecoration(
                        color: _accentGreen,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.login,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'sign_in'.tr,
                            style: waddyBold.copyWith(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. QUICK ACTIONS — My Orders | Wallet (mini card) | Waddy Club | Get Help
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildQuickActions(
    BuildContext context,
    ProfileController profileController,
    bool isLoggedIn,
    Color primaryColor,
  ) {
    // No `GetBuilder` here: the quick-actions grid reads nothing off the XP
    // controller, so subscribing only repainted 49 lines on every XP update.
    return Builder(
      builder: (context) {
        final normalItems = [
          _QuickAction(
            icon: HugeIcons.strokeRoundedInvoice01,
            label: 'my_orders'.tr,
            onTap: () => Get.toNamed(RouteHelper.getOrderRoute()),
          ),
          _QuickAction(
            icon: HugeIcons.strokeRoundedAward01,
            label: 'Waddy Club',
            onTap: () => Get.toNamed(RouteHelper.getXpLevelsRoute()),
          ),
          _QuickAction(
            icon: HugeIcons.strokeRoundedHeadset,
            label: 'Get Help',
            onTap: () => Get.toNamed(RouteHelper.getConversationRoute()),
          ),
        ];

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: Dimensions.paddingSizeDefault,
            horizontal: Dimensions.paddingSizeSmall,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ── Normal items ──
              ...normalItems.map((item) {
                return _buildNormalQuickItem(item, primaryColor);
              }),
              // ── Wallet item (mini card + balance chip) ──
              _buildWalletQuickItem(profileController, primaryColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNormalQuickItem(_QuickAction item, Color primaryColor) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _accentGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(icon: item.icon, color: primaryColor, size: 24),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: waddyMedium.copyWith(fontSize: 11, color: _titleColor),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletQuickItem(
    ProfileController profileController,
    Color primaryColor,
  ) {
    return GetBuilder<WalletController>(
      builder: (walletController) {
        final appearance =
            CardAppearances.options[walletController.selectedCardAppearance];
        final symbolIndex = walletController.selectedCardSymbol;
        final balance = profileController.userInfoModel?.walletBalance ?? 0;

        return GestureDetector(
          onTap: () => Get.toNamed(RouteHelper.getWalletRoute()),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 76,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 48px tall wrapper to align with circle icons
                SizedBox(
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                        color: appearance.cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: appearance.cardColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Image.asset(
                              Images.waddyLogo,
                              width: 12,
                              height: 12,
                              color: appearance.brandColor,
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: SvgPicture.asset(
                                'assets/image/wallet_ch/${symbolIndex + 1}c.svg',
                                color: appearance.brandColor,
                                width: 14,
                                height: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'my_wallet'.tr,
                  style: waddyMedium.copyWith(fontSize: 11, color: _titleColor),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION HEADER — Gojek style
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeLarge,
        18,
        Dimensions.paddingSizeLarge,
        8,
      ),
      margin: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Text(
        title,
        style: waddyMedium.copyWith(fontSize: 13, color: _subtitleColor),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FLAT MENU ITEM — Gojek style: icon + title + suffix > chevron
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFlatItem(
    BuildContext context, {
    required List<List<dynamic>> icon,
    required String title,
    String? suffix,
    Color? iconColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeLarge,
            vertical: Dimensions.paddingSizeMedium,
          ),
          child: Row(
            children: [
              HugeIcon(icon: icon, color: iconColor ?? primaryColor, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: waddyMedium.copyWith(
                    fontSize: 15,
                    color: textColor ?? _titleColor,
                  ),
                ),
              ),
              if (suffix != null) ...[
                Text(
                  suffix,
                  style: waddyRegular.copyWith(
                    fontSize: 13,
                    color: _subtitleColor,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOGGLE ITEM — Gojek style flat toggle row
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildToggleItem(
    BuildContext context, {
    required List<List<dynamic>> icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeLarge,
        vertical: Dimensions.paddingSizeSmall,
      ),
      child: Row(
        children: [
          HugeIcon(icon: icon, color: primaryColor, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: waddyMedium.copyWith(fontSize: 15, color: _titleColor),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: _accentGreen,
              inactiveTrackColor: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _getInitials(ProfileController profileController, bool isLoggedIn) {
    if (!isLoggedIn || profileController.userInfoModel == null) return 'G';
    final firstName = profileController.userInfoModel?.fName ?? '';
    final lastName = profileController.userInfoModel?.lName ?? '';
    if (firstName.isEmpty && lastName.isEmpty) return 'U';
    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0].toUpperCase();
    if (lastName.isNotEmpty) initials += lastName[0].toUpperCase();
    return initials.isNotEmpty ? initials : 'U';
  }

  Level? _getNextLevel(
    LevelsListModel? levelsListModel,
    int currentLevelNumber,
  ) {
    if (levelsListModel == null) return null;
    for (final level in levelsListModel.levels) {
      if (level.level > currentLevelNumber) return level;
    }
    return null;
  }

  String _getNextPrizeTitle(Level level) {
    if (level.prizes.isNotEmpty) return level.prizes.first.title;
    return 'Reach ${level.name}';
  }

  void _handleGuestSignIn(ProfileController profileController) async {
    await Get.toNamed(RouteHelper.getSignInRoute(Get.currentRoute));
    if (AuthHelper.isLoggedIn()) {
      profileController.getUserInfo();
      Get.find<XpController>().getLevelDetails();
    }
  }

  void _manageLanguageFunctionality() {
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

class _QuickAction {
  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
