import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class AddressConfirmDialogue extends StatelessWidget {
  final String icon;
  final String? title;
  final String description;
  final Function onYesPressed;
  const AddressConfirmDialogue({super.key, required this.icon, this.title, required this.description, required this.onYesPressed});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveHelper.isDesktop(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge)),
      insetPadding: const EdgeInsets.all(30),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: PointerInterceptor(
        child: SizedBox(
          width: 500,
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              ResponsiveHelper.isDesktop(context) ? Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.clear),
                ),
              ) : const SizedBox(),

              // Icon container instead of image
              Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete02,
                  color: Theme.of(context).colorScheme.error,
                  size: isDesktop ? 50 : 40,
                  strokeWidth: 2,
                ),
              ),

              const SizedBox(height: Dimensions.paddingSizeLarge),

              title != null ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
                child: Text(
                  title!, 
                  textAlign: TextAlign.center,
                  style: robotoBold.copyWith(
                    fontSize: isDesktop ? Dimensions.fontSizeLarge : Dimensions.fontSizeExtraLarge,
                    color: Theme.of(context).textTheme.titleSmall?.color,
                  ),
                ),
              ) : const SizedBox(),

              const SizedBox(height: Dimensions.paddingSizeDefault),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
                child: Text(
                  description, 
                  style: robotoRegular.copyWith(
                    fontSize: isDesktop ? Dimensions.fontSizeSmall : Dimensions.fontSizeDefault, 
                    color: Theme.of(context).hintColor,
                    height: 1.5,
                  ), 
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: Dimensions.paddingSizeExtraLarge),

              GetBuilder<AddressController>(builder: (addressController) {
                return !addressController.isLoading ? Row(children: [
                  SizedBox(width: isDesktop ? Dimensions.paddingSizeExtremeLarge : 0),
                  
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onYesPressed(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedDelete02,
                              color: Colors.white,
                              size: 18,
                              strokeWidth: 2,
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                            Text(
                              'delete'.tr,
                              style: robotoBold.copyWith(
                                color: Colors.white,
                                fontSize: Dimensions.fontSizeDefault,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(width: isDesktop ? Dimensions.paddingSizeExtraLarge : Dimensions.paddingSizeLarge),

                  Expanded(
                    child: GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                        ),
                        child: Center(
                          child: Text(
                            'cancel'.tr,
                            style: robotoBold.copyWith(
                              color: Theme.of(context).primaryColor,
                              fontSize: Dimensions.fontSizeDefault,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(width: isDesktop ? Dimensions.paddingSizeExtremeLarge : 0),
                ]) : const Center(child: CircularProgressIndicator());
              }),

              SizedBox(height: isDesktop ? Dimensions.paddingSizeExtremeLarge : 0),

            ]),
          ),
        ),
      ),
    );
  }
}

