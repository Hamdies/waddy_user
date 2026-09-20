import 'package:waddy_app/common/widgets/custom_asset_image_widget.dart';
import 'package:waddy_app/features/language/widgets/language_card_widget.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:flutter/material.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:get/get.dart';

class ChooseLanguageScreen extends StatefulWidget {
  final bool fromMenu;
  const ChooseLanguageScreen({super.key, this.fromMenu = false});

  @override
  State<ChooseLanguageScreen> createState() => _ChooseLanguageScreenState();
}

// Device-locale auto-detection deliberately lives in the splash router, not
// here: doing it after this screen mounts made the picker flash on screen for
// a moment before it dismissed itself. By the time this screen is reached, the
// user genuinely has to choose.
class _ChooseLanguageScreenState extends State<ChooseLanguageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          (widget.fromMenu)
              ? CustomAppBar(title: 'language'.tr, backButton: true)
              : null,
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      backgroundColor: Theme.of(context).cardColor,
      body: GetBuilder<LocalizationController>(
        builder: (localizationController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              const Align(
                alignment: Alignment.center,
                child: CustomAssetImageWidget(
                  Images.languageBg,
                  height: 210,
                  width: 210,
                  fit: BoxFit.contain,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeLarge,
                ),
                child: Text(
                  'choose_your_language'.tr,
                  style: waddyBold.copyWith(fontSize: Dimensions.fontSizeLarge),
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeLarge,
                ),
                child: Text(
                  'choose_your_language_to_proceed'.tr,
                  style: waddyRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                  ),
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraLarge),

              Expanded(
                child: SingleChildScrollView(
                  child: ListView.builder(
                    itemCount: localizationController.languages.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeLarge,
                    ),
                    itemBuilder: (context, index) {
                      return LanguageCardWidget(
                        languageModel: localizationController.languages[index],
                        localizationController: localizationController,
                        index: index,
                      );
                    },
                  ),
                ),
              ),

              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimensions.paddingSizeDefault,
                    horizontal: Dimensions.paddingSizeExtraLarge,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: CustomButton(
                    buttonText: 'next'.tr,
                    onPressed: () {
                      if (localizationController.languages.isNotEmpty &&
                          localizationController.selectedLanguageIndex != -1) {
                        localizationController.setLanguage(
                          Locale(
                            AppConstants
                                .languages[localizationController
                                    .selectedLanguageIndex]
                                .languageCode!,
                            AppConstants
                                .languages[localizationController
                                    .selectedLanguageIndex]
                                .countryCode,
                          ),
                        );
                        if (widget.fromMenu) {
                          Navigator.pop(context);
                        } else {
                          Get.offNamed(RouteHelper.getOnBoardingRoute());
                        }
                      } else {
                        showCustomSnackBar('select_a_language'.tr);
                      }
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
