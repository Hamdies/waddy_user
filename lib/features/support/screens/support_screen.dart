import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/support/widgets/support_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'help_support'.tr),
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: FooterView(
            child: SizedBox(
              width: Dimensions.maxContentWidth,
              child: Column(
                children: [
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  Image.asset(Images.supportImage, height: 120),
                  const SizedBox(height: 30),

                  Image.asset(Images.logo, width: 200),
                  const SizedBox(height: 40),

                  SupportButtonWidget(
                    icon: Icons.location_on,
                    title: 'address'.tr,
                    color: Colors.blue,
                    info: Get.find<SplashController>().configModel.address,
                    onTap: () {},
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  SupportButtonWidget(
                    icon: Icons.call,
                    title: 'call'.tr,
                    color: Colors.red,
                    info: Get.find<SplashController>().configModel.phone,
                    onTap: () async {
                      if (await canLaunchUrlString(
                        'tel:${Get.find<SplashController>().configModel.phone}',
                      )) {
                        launchUrlString(
                          'tel:${Get.find<SplashController>().configModel.phone}',
                        );
                      } else {
                        showCustomSnackBar(
                          '${'can_not_launch'.tr} ${Get.find<SplashController>().configModel.phone}',
                        );
                      }
                    },
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  SupportButtonWidget(
                    icon: Icons.mail_outline,
                    title: 'email_us'.tr,
                    color: Colors.green,
                    info: Get.find<SplashController>().configModel.email,
                    onTap: () {
                      final Uri emailLaunchUri = Uri(
                        scheme: 'mailto',
                        path: Get.find<SplashController>().configModel.email,
                      );
                      launchUrlString(emailLaunchUri.toString());
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
