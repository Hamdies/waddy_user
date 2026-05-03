import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/string_extension.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/checkout/widgets/payment_method_bottom_sheet.dart';

class PaymentSection extends StatelessWidget {
  final int? storeId;
  final bool isCashOnDeliveryActive;
  final bool isDigitalPaymentActive;
  final bool isWalletActive;
  final double total;
  final CheckoutController checkoutController;
  final bool isOfflinePaymentActive;
  const PaymentSection({super.key, this.storeId, required this.isCashOnDeliveryActive, required this.isDigitalPaymentActive,
    required this.isWalletActive, required this.total, required this.checkoutController, required this.isOfflinePaymentActive,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveHelper.isDesktop(context);

    // ── Desktop layout unchanged ─────────────────────────────────
    if (isDesktop) {
      return Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(storeId != null ? 'payment_method'.tr : 'choose_payment_method'.tr, style: robotoMedium),
          storeId == null ? InkWell(
            onTap: () {
              if(checkoutController.paymentMethodIndex == -1){
                Get.dialog(Dialog(backgroundColor: Colors.transparent, child: PaymentMethodBottomSheet(
                  isCashOnDeliveryActive: isCashOnDeliveryActive, isDigitalPaymentActive: isDigitalPaymentActive,
                  isWalletActive: isWalletActive, storeId: storeId, totalPrice: total, isOfflinePaymentActive: isOfflinePaymentActive,
                )));
              }
            },
            child: Image.asset(Images.paymentSelect, height: 24, width: 24),
          ) : const SizedBox(),
        ]),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            color: WaddyColors.surface,
            border: Border.all(color: WaddyColors.divider, width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall, horizontal: Dimensions.radiusDefault),
          child: storeId != null
              ? Row(children: [
                  Image.asset(Images.cash, width: 20, height: 20, color: WaddyColors.inkMid),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(child: Text('cash_on_delivery'.tr,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: WaddyColors.inkLight),
                  )),
                  Text(PriceConverter.convertPrice(total), textDirection: TextDirection.ltr,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge, color: WaddyColors.primary),
                  ),
                ])
              : Row(children: [
                  checkoutController.paymentMethodIndex != -1
                      ? Image.asset(
                          checkoutController.paymentMethodIndex == 0 ? Images.cash
                              : checkoutController.paymentMethodIndex == 1 ? Images.wallet
                              : checkoutController.paymentMethodIndex == 2 ? Images.digitalPayment
                              : Images.cash,
                          width: 20, height: 20, color: WaddyColors.inkMid,
                        )
                      : Icon(Icons.add_circle_outline_sharp, size: 18, color: WaddyColors.primary),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(
                    child: Text(
                      checkoutController.paymentMethodIndex == 0
                          ? '${'cash_on_delivery'.tr}${checkoutController.isPartialPay ? ' (${'partial'.tr})' : ''}'
                          : checkoutController.paymentMethodIndex == 1 && !checkoutController.isPartialPay ? 'wallet_payment'.tr
                          : checkoutController.paymentMethodIndex == 2
                              ? '${'digital_payment'.tr} (${checkoutController.digitalPaymentName?.replaceAll('_', ' ').toTitleCase() ?? ''}${checkoutController.isPartialPay ? ' - ${'partial'.tr}' : ''})'
                          : checkoutController.paymentMethodIndex == 3
                              ? '${'offline_payment'.tr} (${checkoutController.offlineMethodList![checkoutController.selectedOfflineBankIndex].methodName}${checkoutController.isPartialPay ? ' - ${'partial'.tr}' : ''})'
                          : 'add_payment_method'.tr,
                      style: robotoMedium.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: checkoutController.paymentMethodIndex == -1 ? WaddyColors.primary : WaddyColors.inkLight,
                      ),
                    ),
                  ),
                  checkoutController.paymentMethodIndex != -1
                      ? PriceConverter.convertAnimationPrice(
                          checkoutController.viewTotalPrice,
                          textStyle: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge, color: WaddyColors.primary),
                        )
                      : const SizedBox(),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  InkWell(
                    onTap: () {
                      Get.dialog(Dialog(backgroundColor: Colors.transparent, child: PaymentMethodBottomSheet(
                        isCashOnDeliveryActive: isCashOnDeliveryActive, isDigitalPaymentActive: isDigitalPaymentActive,
                        isWalletActive: isWalletActive, storeId: storeId, totalPrice: total, isOfflinePaymentActive: isOfflinePaymentActive,
                      )));
                    },
                    child: Image.asset(Images.paymentSelect, height: 24, width: 24),
                  ),
                ]),
        ),
      ]);
    }

    // ── Mobile: Waddy-styled payment pill matching the cart screen ──
    final String paymentLabel = storeId != null
        ? 'cash_on_delivery'.tr
        : checkoutController.paymentMethodIndex == 0
            ? '${'cash_on_delivery'.tr}${checkoutController.isPartialPay ? ' (${'partial'.tr})' : ''}'
            : checkoutController.paymentMethodIndex == 1 && !checkoutController.isPartialPay
                ? 'wallet_payment'.tr
                : checkoutController.paymentMethodIndex == 2
                    ? '${'digital_payment'.tr} (${checkoutController.digitalPaymentName?.replaceAll('_', ' ').toTitleCase() ?? ''}${checkoutController.isPartialPay ? ' - ${'partial'.tr}' : ''})'
                    : checkoutController.paymentMethodIndex == 3
                        ? '${'offline_payment'.tr}'
                        : 'select_payment_method'.tr;

    final IconData paymentIcon = checkoutController.paymentMethodIndex == 1
        ? Icons.account_balance_wallet_rounded
        : checkoutController.paymentMethodIndex == 2
            ? Icons.credit_card_rounded
            : checkoutController.paymentMethodIndex == -1
                ? Icons.warning_rounded
                : Icons.money_rounded;

    final bool isUnselected = storeId == null && checkoutController.paymentMethodIndex == -1;

    void openPaymentSheet() {
      if (storeId != null) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (con) => PaymentMethodBottomSheet(
          isCashOnDeliveryActive: isCashOnDeliveryActive,
          isDigitalPaymentActive: isDigitalPaymentActive,
          isWalletActive: isWalletActive,
          storeId: storeId,
          totalPrice: total,
          isOfflinePaymentActive: isOfflinePaymentActive,
        ),
      );
    }

    return GestureDetector(
      onTap: openPaymentSheet,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: WaddyColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnselected ? WaddyColors.coral.withValues(alpha: 0.4) : WaddyColors.divider,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isUnselected ? WaddyColors.coralSurface : WaddyColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                paymentIcon,
                size: 18,
                color: isUnselected ? WaddyColors.coral : WaddyColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'payment_method'.tr,
                    style: robotoRegular.copyWith(fontSize: 10, color: WaddyColors.inkMuted),
                  ),
                  Text(
                    paymentLabel,
                    style: robotoMedium.copyWith(
                      fontSize: 13,
                      color: isUnselected ? WaddyColors.coral : WaddyColors.ink,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (checkoutController.paymentMethodIndex != -1)
              PriceConverter.convertAnimationPrice(
                checkoutController.viewTotalPrice,
                textStyle: robotoBold.copyWith(fontSize: 15, color: WaddyColors.primary),
              ),
            const SizedBox(width: 6),
            if (storeId == null)
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isUnselected ? WaddyColors.coral : WaddyColors.inkMuted,
              ),
          ],
        ),
      ),
    );
  }
}
