import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/loyalty/controllers/loyalty_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/custom_text_field.dart';

class LoyaltyBottomSheetWidget extends StatefulWidget {
  final String amount;
  const LoyaltyBottomSheetWidget({super.key, required this.amount});

  @override
  State<LoyaltyBottomSheetWidget> createState() =>
      _LoyaltyBottomSheetWidgetState();
}

class _LoyaltyBottomSheetWidgetState extends State<LoyaltyBottomSheetWidget> {
  final TextEditingController _amountController = TextEditingController();

  int? exchangePointRate =
      Get.find<SplashController>().configModel.loyaltyPointExchangeRate ?? 0;
  int? minimumExchangePoint =
      Get.find<SplashController>().configModel.minimumPointToTransfer ?? 0;

  @override
  void initState() {
    super.initState();

    _amountController.text = widget.amount;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 550,
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.all(
              Radius.circular(Dimensions.radiusExtraLarge),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(Images.creditIcon, height: 50, width: 50),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$exchangePointRate ${'points'.tr}= ',
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                      ),
                    ),
                    Text(
                      PriceConverter.convertPrice(1),
                      textDirection: TextDirection.ltr,
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                Text(
                  '(${'from'.tr} ${widget.amount} ${'points'.tr})',
                  style: waddyRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).disabledColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                Text(
                  'amount_can_be_convert_into_wallet_money'.tr,
                  style: waddyRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).disabledColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: Dimensions.paddingSizeLarge),

                SizedBox(
                  width: null,
                  child: CustomTextField(
                    titleText: 'enter_amount'.tr,
                    controller: _amountController,
                    inputType: TextInputType.phone,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: Dimensions.paddingSizeLarge),

                GetBuilder<LoyaltyController>(
                  builder: (walletController) {
                    return CustomButton(
                      width: context.width / 3,
                      isBold: false,
                      buttonText: 'convert'.tr,
                      radius: 50,
                      isLoading: walletController.isLoading,
                      onPressed: () {
                        if (_amountController.text.isEmpty) {
                          if (Get.isBottomSheetOpen!) {
                            Get.back();
                          }
                          showCustomSnackBar('input_field_is_empty'.tr);
                        } else {
                          int amount = int.parse(_amountController.text.trim());
                          int? point =
                              Get.find<ProfileController>()
                                  .userInfoModel!
                                  .loyaltyPoint;

                          if (amount < minimumExchangePoint!) {
                            if (Get.isBottomSheetOpen!) {
                              Get.back();
                            }
                            showCustomSnackBar(
                              '${'please_exchange_more_then'.tr} $minimumExchangePoint ${'points'.tr}',
                            );
                          } else if (point! < amount) {
                            if (Get.isBottomSheetOpen!) {
                              Get.back();
                            }
                            showCustomSnackBar(
                              'you_do_not_have_enough_point_to_exchange'.tr,
                            );
                          } else {
                            walletController.pointToWallet(amount);
                          }
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.clear, size: 18),
          ),
        ),
      ],
    );
  }
}
