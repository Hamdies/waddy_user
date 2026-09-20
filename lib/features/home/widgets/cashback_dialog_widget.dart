import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/widgets/cashback_logo_widget.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class CashBackDialogWidget extends StatelessWidget {
  const CashBackDialogWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (homeController) {
        return homeController.cashBackOfferList != null
            ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeLarge,
                vertical: 50,
              ),
              alignment:
                  Get.find<LocalizationController>().isLtr
                      ? Alignment.bottomRight
                      : Alignment.bottomLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(),

                  homeController.cashBackOfferList!.isNotEmpty
                      ? Container(
                        constraints: BoxConstraints(
                          maxHeight: context.height * 0.5,
                          minHeight: 30,
                        ),
                        width: context.width * 0.8,
                        margin: EdgeInsets.only(right: 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxHeight: context.height * 0.5,
                                minHeight: 30,
                              ),
                              padding: const EdgeInsets.only(
                                bottom: Dimensions.paddingSizeSmall,
                              ),
                              child: ListView.builder(
                                itemCount:
                                    homeController.cashBackOfferList!.length,
                                shrinkWrap: true,
                                itemBuilder: (context, index) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusSmall,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(
                                      Dimensions.paddingSizeExtraSmall,
                                    ),
                                    margin: const EdgeInsets.only(
                                      bottom: Dimensions.paddingSizeSmall,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .disabledColor
                                                .withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              Dimensions.radiusSmall,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(
                                            Dimensions.paddingSizeSmall,
                                          ),
                                          child: Text(
                                            homeController
                                                    .cashBackOfferList![index]
                                                    .title ??
                                                '',
                                            style: waddyBold,
                                          ),
                                        ),

                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                Dimensions.paddingSizeDefault,
                                            vertical:
                                                Dimensions.paddingSizeSmall,
                                          ),
                                          child: Text(
                                            '${'min_spent'.tr} ${PriceConverter.convertPrice(homeController.cashBackOfferList![index].minPurchase!)} '
                                            '| ${'valid_till'.tr} ${DateConverter.stringToReadableString(homeController.cashBackOfferList![index].endDate!)}',
                                            style: waddyRegular.copyWith(
                                              color:
                                                  Theme.of(context).hintColor,
                                              fontSize:
                                                  Dimensions.fontSizeSmall,
                                            ),
                                          ),
                                        ),

                                        // Text('Min Spent \$500 |Valid till 22 Sept, 2023', style: waddyRegular.copyWith(color: Theme.of(context).hintColor)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                      : Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusSmall,
                          ),
                        ),
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeExtraSmall,
                        ),
                        child: Text(
                          'no_offer_available'.tr,
                          style: waddyRegular.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ),

                  Container(
                    height: 80,
                    width: 65,
                    margin: EdgeInsets.only(
                      bottom: Dimensions.paddingSizeLarge,
                      right: 0,
                    ),
                    child: InkWell(
                      onTap: () => Get.back(),
                      child: const CashBackLogoWidget(),
                    ),
                  ),
                ],
              ),
            )
            : const SizedBox();
      },
    );
  }
}
