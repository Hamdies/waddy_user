import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/support/widgets/support_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Support & Help — a Waddy-themed take on the "chat widget" pattern: a
/// mint-dominant greeting header you can message from directly, plus the
/// plain contact channels (address / call / email) beneath it.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaddyColors.canvas,
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: FooterView(
              child: SizedBox(
                width: Dimensions.maxContentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildGreetingHeader(context),
                    const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeDefault,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'other_ways_to_reach_us'.tr,
                            style: waddyMedium.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: WaddyColors.inkLight,
                            ),
                          ),
                          const SizedBox(height: Dimensions.paddingSizeSmall),

                          SupportButtonWidget(
                            icon: Icons.location_on_rounded,
                            title: 'address'.tr,
                            surfaceColor: WaddyColors.primarySurface,
                            inkColor: WaddyColors.primary,
                            info:
                                Get.find<SplashController>()
                                    .configModel
                                    .address,
                            onTap: () {},
                          ),
                          const SizedBox(height: Dimensions.paddingSizeSmall),

                          SupportButtonWidget(
                            icon: Icons.call_rounded,
                            title: 'call'.tr,
                            surfaceColor: WaddyColors.coralSurface,
                            inkColor: WaddyColors.coralInk,
                            info:
                                Get.find<SplashController>().configModel.phone,
                            onTap: () async {
                              final phone =
                                  Get.find<SplashController>()
                                      .configModel
                                      .phone;
                              if (await canLaunchUrlString('tel:$phone')) {
                                launchUrlString('tel:$phone');
                              } else {
                                showCustomSnackBar(
                                  '${'can_not_launch'.tr} $phone',
                                );
                              }
                            },
                          ),
                          const SizedBox(height: Dimensions.paddingSizeSmall),

                          SupportButtonWidget(
                            icon: Icons.mail_outline_rounded,
                            title: 'email_us'.tr,
                            surfaceColor: WaddyColors.amberSurface,
                            inkColor: WaddyColors.amberInk,
                            info:
                                Get.find<SplashController>().configModel.email,
                            onTap: () {
                              final Uri emailLaunchUri = Uri(
                                scheme: 'mailto',
                                path:
                                    Get.find<SplashController>()
                                        .configModel
                                        .email,
                              );
                              launchUrlString(emailLaunchUri.toString());
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: Dimensions.paddingSizeDefault),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mint-dominant greeting panel, standing in for a third-party chat
  /// widget's colored header: avatar + wave + headline + a "send us a
  /// message" CTA that opens the in-app chat.
  ///
  /// Mint TINT ([WaddyColors.mintSurfaceDeep]→[WaddyColors.mintSurface])
  /// carries the brand wash here, not full-saturation [WaddyColors.mint] —
  /// that stays reserved for the one pressable control on the panel (the
  /// CTA's icon badge), per the mint-is-dominant-but-controls-stay-saturated
  /// rule in light_theme.dart.
  Widget _buildGreetingHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeExtraLarge,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [WaddyColors.mintSurfaceDeep, WaddyColors.mintSurface],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(Dimensions.radiusExtraLarge),
          bottomRight: Radius.circular(Dimensions.radiusExtraLarge),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: WaddyColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: WaddyColors.primary,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Container(
            height: 48,
            width: 48,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Image.asset(Images.waddyLogo, fit: BoxFit.contain),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Text(
            'support_greeting_wave'.tr,
            style: waddyMedium.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: WaddyColors.mintInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'how_can_we_help_you'.tr,
            style: waddyBold.copyWith(
              fontSize: Dimensions.fontSizeExtraLarge,
              color: WaddyColors.ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraLarge),

          // "Send us a message" — opens the in-app chat. The only
          // full-saturation mint on this panel: the pressable icon badge.
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            child: InkWell(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              onTap: () => Get.toNamed(RouteHelper.getConversationRoute()),
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: WaddyColors.mint,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: WaddyColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeDefault),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'send_us_a_message'.tr,
                            style: waddyMedium.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: WaddyColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'usually_replies_in_minutes'.tr,
                            style: waddyRegular.copyWith(
                              fontSize: Dimensions.fontSizeExtraSmall,
                              color: WaddyColors.inkLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: WaddyColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
