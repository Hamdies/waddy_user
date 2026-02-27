import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/features/xp/domain/models/checkout_prize_model.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class PrizeSelectionWidget extends StatelessWidget {
  final double orderAmount;

  const PrizeSelectionWidget({super.key, required this.orderAmount});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        // Don't show if no prizes available
        if (xpController.checkoutPrizes.isEmpty &&
            !xpController.isCheckoutPrizesLoading) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: Dimensions.paddingSizeSmall,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                child: Row(
                  children: [
                    Icon(
                      Icons.card_giftcard,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Text(
                      'apply_xp_prize'.tr,
                      style: robotoBold.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Loading state
              if (xpController.isCheckoutPrizesLoading)
                const Padding(
                  padding: EdgeInsets.all(Dimensions.paddingSizeDefault),
                  child: Center(child: CircularProgressIndicator()),
                )
              // Prize list
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: xpController.checkoutPrizes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final prize = xpController.checkoutPrizes[index];
                    final isSelected =
                        xpController.selectedCheckoutPrize?.id == prize.id;

                    return InkWell(
                      onTap: () {
                        if (isSelected) {
                          xpController.clearSelectedCheckoutPrize();
                        } else {
                          xpController.selectCheckoutPrize(prize);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeDefault,
                        ),
                        child: Row(
                          children: [
                            // Radio button
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child:
                                  isSelected
                                      ? Center(
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      )
                                      : null,
                            ),

                            const SizedBox(
                              width: Dimensions.paddingSizeDefault,
                            ),

                            // Prize info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _buildPrizeIcon(context, prize),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          prize.title,
                                          style: robotoMedium.copyWith(
                                            fontSize:
                                                Dimensions.fontSizeDefault,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (prize.expiresAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatExpiry(prize),
                                      style: robotoRegular.copyWith(
                                        fontSize: Dimensions.fontSizeSmall,
                                        color: _getExpiryColor(prize),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Free delivery badge
                            if (prize.isFreeDelivery)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'free_delivery'.tr,
                                  style: robotoMedium.copyWith(
                                    fontSize: Dimensions.fontSizeExtraSmall,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrizeIcon(BuildContext context, CheckoutPrize prize) {
    IconData iconData;
    Color iconColor;

    switch (prize.type) {
      case 'free_delivery':
        iconData = Icons.local_shipping_outlined;
        iconColor = Colors.green;
        break;
      case 'discount':
        iconData = Icons.discount_outlined;
        iconColor = Colors.orange;
        break;
      case 'wallet_credit':
        iconData = Icons.wallet_outlined;
        iconColor = Colors.blue;
        break;
      default:
        iconData = Icons.card_giftcard;
        iconColor = Theme.of(context).primaryColor;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, size: 16, color: iconColor),
    );
  }

  String _formatExpiry(CheckoutPrize prize) {
    if (prize.timeUntilExpiry == null) return '';

    final duration = prize.timeUntilExpiry!;
    if (duration.inDays > 0) {
      return '${'expires_in'.tr} ${duration.inDays} ${'days'.tr}';
    } else if (duration.inHours > 0) {
      return '${'expires_in'.tr} ${duration.inHours} ${'hours'.tr}';
    } else {
      return 'expires_soon'.tr;
    }
  }

  Color _getExpiryColor(CheckoutPrize prize) {
    if (prize.timeUntilExpiry == null) return Colors.grey;

    final duration = prize.timeUntilExpiry!;
    if (duration.inDays < 1) {
      return Colors.red;
    } else if (duration.inDays < 3) {
      return Colors.orange;
    }
    return Colors.grey;
  }
}
