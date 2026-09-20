import 'package:waddy_app/features/profile/widgets/notification_status_change_bottom_sheet.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/confirmation_dialog.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/profile/widgets/profile_button_widget.dart';
import 'package:waddy_app/features/profile/widgets/profile_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/widgets/xp_progress_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();

    if (AuthHelper.isLoggedIn() &&
        Get.find<ProfileController>().userInfoModel == null) {
      Get.find<ProfileController>().getUserInfo();
    }

    // Initialize XP controller if logged in (deferred to avoid build-phase setState)
    if (AuthHelper.isLoggedIn()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<XpController>().getLevelDetails();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showWalletCard =
        Get.find<SplashController>().configModel.customerWalletStatus == 1 ||
        Get.find<SplashController>().configModel.loyaltyPointStatus == 1;
    bool isLoggedIn = AuthHelper.isLoggedIn();

    return Scaffold(
      appBar: null,
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      key: UniqueKey(),
      body: GetBuilder<ProfileController>(
        builder: (profileController) {
          return (isLoggedIn && profileController.userInfoModel == null)
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 1170,
                    height: double.infinity,
                    color: Theme.of(context).primaryColor,
                  ),

                  SizedBox(
                    width: context.width,
                    height: 240,
                    child: Center(
                      child: Image.asset(
                        Images.profileBg,
                        height: 240,
                        width: 1170,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),

                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 0,
                    right: 0,
                    child: Text(
                      'profile'.tr,
                      textAlign: TextAlign.center,
                      style: waddyMedium.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).cardColor,
                      ),
                    ),
                  ),

                  Positioned(
                    top: MediaQuery.of(context).padding.top,
                    left: 10,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: Theme.of(context).cardColor,
                        size: 20,
                      ),
                      onPressed: () => Get.back(),
                    ),
                  ),

                  Positioned(
                    top: MediaQuery.of(context).padding.top + 55,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeExtremeLarge,
                      ),
                      child: Row(
                        children: [
                          ClipOval(
                            child: CustomImage(
                              placeholder: Images.guestIcon,
                              image:
                                  '${(profileController.userInfoModel != null && isLoggedIn) ? profileController.userInfoModel!.imageFullUrl : ''}',
                              height: 70,
                              width: 70,
                              fit: BoxFit.cover,
                              color:
                                  isLoggedIn &&
                                          profileController
                                                  .userInfoModel
                                                  ?.imageFullUrl !=
                                              null
                                      ? null
                                      : Theme.of(context).cardColor,
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeDefault),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isLoggedIn
                                      ? '${profileController.userInfoModel?.fName ?? ''} ${profileController.userInfoModel?.lName ?? ''}'
                                      : 'guest_user'.tr,
                                  style: waddyBold.copyWith(
                                    fontSize: Dimensions.fontSizeExtraLarge,
                                    color: Theme.of(context).cardColor,
                                  ),
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeExtraSmall,
                                ),

                                isLoggedIn
                                    ? Text(
                                      '${'joined'.tr} ${DateConverter.containTAndZToUTCFormat(profileController.userInfoModel!.createdAt!)}',
                                      style: waddyMedium.copyWith(
                                        fontSize: Dimensions.fontSizeSmall,
                                        color: Theme.of(
                                          context,
                                        ).cardColor.withValues(alpha: 0.7),
                                      ),
                                    )
                                    : InkWell(
                                      onTap: () async {
                                        await Get.toNamed(
                                          RouteHelper.getSignInRoute(
                                            Get.currentRoute,
                                          ),
                                        );
                                        if (AuthHelper.isLoggedIn()) {
                                          profileController.getUserInfo();
                                        }
                                      },
                                      child: Text(
                                        'login_to_view_all_feature'.tr,
                                        style: waddyMedium.copyWith(
                                          fontSize: Dimensions.fontSizeSmall,
                                          color: Theme.of(
                                            context,
                                          ).cardColor.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeDefault),

                          isLoggedIn
                              ? InkWell(
                                onTap:
                                    () => Get.toNamed(
                                      RouteHelper.getUpdateProfileRoute(),
                                    ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).cardColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.05),
                                        blurRadius: 5,
                                        spreadRadius: 1,
                                        offset: const Offset(3, 3),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(
                                    Dimensions.paddingSizeSmall,
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                ),
                              )
                              : InkWell(
                                onTap: () async {
                                  await Get.toNamed(
                                    RouteHelper.getSignInRoute(
                                      Get.currentRoute,
                                    ),
                                  );
                                  if (AuthHelper.isLoggedIn()) {
                                    profileController.getUserInfo();
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusDefault,
                                    ),
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: Dimensions.paddingSizeSmall,
                                    horizontal: Dimensions.paddingSizeLarge,
                                  ),
                                  child: Text(
                                    'login'.tr,
                                    style: waddyMedium.copyWith(
                                      color: Theme.of(context).cardColor,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: 180,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(
                        Dimensions.paddingSizeLarge,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                        color: Theme.of(context).cardColor,
                      ),
                      child: Column(
                        children: [
                          (showWalletCard && isLoggedIn)
                              ? Row(
                                children: [
                                  Get.find<SplashController>()
                                              .configModel
                                              .loyaltyPointStatus ==
                                          1
                                      ? Expanded(
                                        child: ProfileCardWidget(
                                          image: Images.loyaltyIcon,
                                          data:
                                              profileController
                                                          .userInfoModel!
                                                          .loyaltyPoint !=
                                                      null
                                                  ? profileController
                                                      .userInfoModel!
                                                      .loyaltyPoint
                                                      .toString()
                                                  : '0',
                                          title: 'loyalty_points'.tr,
                                        ),
                                      )
                                      : const SizedBox(),
                                  SizedBox(
                                    width:
                                        Get.find<SplashController>()
                                                    .configModel
                                                    .loyaltyPointStatus ==
                                                1
                                            ? Dimensions.paddingSizeSmall
                                            : 0,
                                  ),

                                  isLoggedIn
                                      ? Expanded(
                                        child: ProfileCardWidget(
                                          image: Images.shoppingBagIcon,
                                          data:
                                              profileController
                                                  .userInfoModel!
                                                  .orderCount
                                                  .toString(),
                                          title: 'total_order'.tr,
                                        ),
                                      )
                                      : const SizedBox(),
                                  SizedBox(
                                    width:
                                        Get.find<SplashController>()
                                                    .configModel
                                                    .customerWalletStatus ==
                                                1
                                            ? Dimensions.paddingSizeSmall
                                            : 0,
                                  ),

                                  Get.find<SplashController>()
                                              .configModel
                                              .customerWalletStatus ==
                                          1
                                      ? Expanded(
                                        child: ProfileCardWidget(
                                          image: Images.walletProfile,
                                          data: PriceConverter.convertPrice(
                                            profileController
                                                .userInfoModel!
                                                .walletBalance,
                                          ),
                                          title: 'wallet_balance'.tr,
                                        ),
                                      )
                                      : const SizedBox(),
                                ],
                              )
                              : const SizedBox(),
                          const SizedBox(height: Dimensions.paddingSizeDefault),

                          // XP & Levels Card
                          if (isLoggedIn) _buildXpCard(context),

                          if (isLoggedIn)
                            const SizedBox(
                              height: Dimensions.paddingSizeDefault,
                            ),

                          isLoggedIn
                              ? GetBuilder<AuthController>(
                                builder: (authController) {
                                  return ProfileButtonWidget(
                                    icon: Icons.notifications,
                                    title: 'notification'.tr,
                                    isButtonActive: authController.notification,
                                    onTap: () {
                                      Get.bottomSheet(
                                        const NotificationStatusChangeBottomSheet(),
                                      );
                                    },
                                  );
                                },
                              )
                              : const SizedBox(),
                          SizedBox(
                            height:
                                isLoggedIn ? Dimensions.paddingSizeSmall : 0,
                          ),

                          isLoggedIn &&
                                  Get.find<SplashController>()
                                      .configModel
                                      .centralizeLoginSetup!
                                      .manualLoginStatus!
                              ? ProfileButtonWidget(
                                icon: Icons.lock,
                                title: 'change_password'.tr,
                                onTap: () {
                                  Get.toNamed(
                                    RouteHelper.getResetPasswordRoute(
                                      phone: '',
                                      email: '',
                                      token: '',
                                      page: 'password-change',
                                    ),
                                  );
                                },
                              )
                              : const SizedBox(),
                          SizedBox(
                            height:
                                isLoggedIn &&
                                        Get.find<SplashController>()
                                            .configModel
                                            .centralizeLoginSetup!
                                            .manualLoginStatus!
                                    ? Dimensions.paddingSizeSmall
                                    : 0,
                          ),

                          isLoggedIn
                              ? ProfileButtonWidget(
                                icon: Icons.delete,
                                title: 'delete_account'.tr,
                                iconImage: Images.profileDelete,
                                color: Theme.of(context).colorScheme.error,
                                onTap: () {
                                  Get.dialog(
                                    ConfirmationDialog(
                                      icon: Images.support,
                                      title:
                                          'are_you_sure_to_delete_account'.tr,
                                      description:
                                          'it_will_remove_your_all_information'
                                              .tr,
                                      isLogOut: true,
                                      onYesPressed:
                                          () => profileController.deleteUser(),
                                    ),
                                    useSafeArea: false,
                                  );
                                },
                              )
                              : const SizedBox(),
                          SizedBox(
                            height:
                                isLoggedIn ? Dimensions.paddingSizeLarge : 0,
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${'version'.tr}:',
                                style: waddyRegular.copyWith(
                                  fontSize: Dimensions.fontSizeExtraSmall,
                                ),
                              ),
                              const SizedBox(
                                width: Dimensions.paddingSizeExtraSmall,
                              ),
                              Text(
                                AppConstants.appVersion.toStringAsFixed(1),
                                style: waddyMedium.copyWith(
                                  fontSize: Dimensions.fontSizeExtraSmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
        },
      ),
    );
  }

  Widget _buildXpCard(BuildContext context) {
    // No `GetBuilder` here: this card reads nothing off the controller. The
    // only live part is `XpProgressBar`, which subscribes on its own.
    return Builder(
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'xp_and_levels'.tr,
                        style: waddyMedium.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Get.toNamed(RouteHelper.getXpLevelsRoute()),
                    child: Row(
                      children: [
                        Text(
                          'view_all'.tr,
                          style: waddyRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              // XP Progress Bar
              const XpProgressBar(compact: true),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              // Quick action buttons
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      context,
                      Icons.flag_outlined,
                      'challenges'.tr,
                      () => Get.toNamed(RouteHelper.getXpChallengesRoute()),
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(
                    child: _buildQuickActionButton(
                      context,
                      Icons.card_giftcard,
                      'prizes'.tr,
                      () => Get.toNamed(RouteHelper.getXpPrizesRoute()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeSmall,
          horizontal: Dimensions.paddingSizeDefault,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Theme.of(context).primaryColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: waddyMedium.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
