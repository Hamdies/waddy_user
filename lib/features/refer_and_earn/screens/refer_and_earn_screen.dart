import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/not_logged_in_screen.dart';
import 'package:waddy_app/util/dimensions.dart';

class ReferAndEarnScreen extends StatefulWidget {
  const ReferAndEarnScreen({super.key});

  @override
  State<ReferAndEarnScreen> createState() => _ReferAndEarnScreenState();
}

class _ReferAndEarnScreenState extends State<ReferAndEarnScreen> {
  @override
  void initState() {
    super.initState();
    _initCall();
  }

  void _initCall() {
    if (AuthHelper.isLoggedIn() &&
        Get.find<ProfileController>().userInfoModel == null) {
      Get.find<ProfileController>().getUserInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLoggedIn = AuthHelper.isLoggedIn();
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body:
          isLoggedIn
              ? SafeArea(
                child: GetBuilder<ProfileController>(
                  builder: (profileController) {
                    final refCode =
                        profileController.userInfoModel?.refCode ?? '';
                    final rewardAmount = PriceConverter.convertPrice(
                      Get.find<SplashController>()
                              .configModel
                              .refEarningExchangeRate
                              ?.toDouble() ??
                          0.0,
                    );

                    return Column(
                      children: [
                        // Back button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Get.back(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                            ),
                            padding: const EdgeInsets.all(
                              Dimensions.paddingSizeDefault,
                            ),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // Lottie
                        Lottie.asset(
                          "assets/animation/waddi_coins.json",
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 40),

                        // Title
                        const Text(
                          'Invite friends!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Subtitle with reward
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 50),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF666666),
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Share your code and earn ',
                                ),
                                TextSpan(
                                  text: rewardAmount,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' for every friend who joins!',
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // Bottom card
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: Dimensions.paddingSizeExtraLarge,
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F8),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            children: [
                              // Label
                              Text(
                                'your_personal_code'.tr.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF999999),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Code
                              profileController.userInfoModel != null
                                  ? Text(
                                    refCode,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      letterSpacing: 3,
                                    ),
                                  )
                                  : const SizedBox(
                                    height: 28,
                                    width: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              const SizedBox(height: 24),

                              // Buttons row
                              Row(
                                children: [
                                  // Copy button
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (refCode.isNotEmpty) {
                                          Clipboard.setData(
                                            ClipboardData(text: refCode),
                                          );
                                          showCustomSnackBar(
                                            'referral_code_copied'.tr,
                                            isError: false,
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical:
                                              Dimensions.paddingSizeDefault,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusLarge,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE8E8E8),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.copy_rounded,
                                              size: 18,
                                              color: primaryColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'copy'.tr.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: primaryColor,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Share button
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (refCode.isNotEmpty) {
                                          Share.share(
                                            Get.find<SplashController>()
                                                        .configModel
                                                        .appUrlAndroid !=
                                                    null
                                                ? '${AppConstants.appName} ${'referral_code'.tr}: $refCode \n${'download_app_from_this_link'.tr}: ${Get.find<SplashController>().configModelOrNull?.appUrlAndroid}'
                                                : '${AppConstants.appName} ${'referral_code'.tr}: $refCode',
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical:
                                              Dimensions.paddingSizeDefault,
                                        ),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusLarge,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.share_rounded,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'SHARE',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),
              )
              : SafeArea(
                child: NotLoggedInScreen(
                  callBack: (value) {
                    _initCall();
                    setState(() {});
                  },
                ),
              ),
    );
  }
}
