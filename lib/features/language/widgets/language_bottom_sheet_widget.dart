import 'package:waddy_app/features/language/widgets/language_card_widget.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:get/get.dart';

class LanguageBottomSheetWidget extends StatefulWidget {
  const LanguageBottomSheetWidget({super.key});

  @override
  State<LanguageBottomSheetWidget> createState() => _LanguageBottomSheetWidgetState();
}

class _LanguageBottomSheetWidgetState extends State<LanguageBottomSheetWidget> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocalizationController>(builder: (localizationController) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(Dimensions.radiusExtraLarge),
            topRight: Radius.circular(Dimensions.radiusExtraLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Dimensions.paddingSizeDefault),
            
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: Dimensions.paddingSizeExtraLarge),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeExtraLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'choose_your_language'.tr,
                    style: robotoBold.copyWith(
                      fontSize: Dimensions.fontSizeOverLarge,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Text(
                    'choose_your_language_to_proceed'.tr,
                    style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: Dimensions.paddingSizeLarge),
            
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeExtraLarge,
                  vertical: Dimensions.paddingSizeSmall,
                ),
                child: ListView.builder(
                  itemCount: localizationController.languages.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return LanguageCardWidget(
                      languageModel: localizationController.languages[index],
                      localizationController: localizationController,
                      index: index,
                      fromBottomSheet: true,
                    );
                  },
                ),
              ),
            ),
            
            SafeArea(
              child: Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: CustomButton(
                  buttonText: 'update'.tr,
                  onPressed: () {
                    if(localizationController.languages.isNotEmpty && localizationController.selectedLanguageIndex != -1) {
                      localizationController.saveCacheLanguage(Locale(
                        AppConstants.languages[localizationController.selectedLanguageIndex].languageCode!,
                        AppConstants.languages[localizationController.selectedLanguageIndex].countryCode,
                      ));
                    }
                    Get.back();
                  },
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
