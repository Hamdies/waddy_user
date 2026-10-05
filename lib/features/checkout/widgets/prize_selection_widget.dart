import 'package:flutter/material.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/checkout_prize_model.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/xp/domain/models/prize_kind.dart';
import 'package:waddy_app/features/xp/widgets/prize_visual.dart';

class PrizeSelectionWidget extends StatelessWidget {
  final double orderAmount;

  const PrizeSelectionWidget({super.key, required this.orderAmount});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      id: XpController.idCheckoutPrizes,
      builder: (xpController) {
        // Don't show if no prizes available
        if (xpController.checkoutPrizes.isEmpty &&
            !xpController.isCheckoutPrizesLoading) {
          return const SizedBox.shrink();
        }

        return Container(
          // Vertical only: the checkout page already pads its content.
          margin: const EdgeInsets.symmetric(
            vertical: Dimensions.paddingSizeSmall,
          ),
          decoration: BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            boxShadow: [
              BoxShadow(
                color: WaddyColors.inkLight.withOpacity(0.1),
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
                      color: WaddyColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Text(
                      'apply_xp_prize'.tr,
                      style: waddyBold.copyWith(
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
                                          ? WaddyColors.primary
                                          : WaddyColors.inkLight,
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
                                            color: WaddyColors.primary,
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
                                          style: waddyMedium.copyWith(
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
                                      style: waddyRegular.copyWith(
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
                                  horizontal: Dimensions.paddingSizeSmall,
                                  vertical: Dimensions.paddingSizeExtraSmall,
                                ),
                                decoration: BoxDecoration(
                                  color: WaddyColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                ),
                                child: Text(
                                  'free_delivery'.tr,
                                  style: waddyMedium.copyWith(
                                    fontSize: Dimensions.fontSizeExtraSmall,
                                    color: WaddyColors.success,
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
    // The glyph is the XP surfaces' (X-38); the colour stays checkout's.
    final kind = prize.kind;
    final IconData iconData = kind.icon;
    final Color iconColor = switch (kind) {
      PrizeKind.freeDelivery => WaddyColors.success,
      PrizeKind.discount => WaddyColors.amberInk,
      PrizeKind.walletCredit => WaddyColors.mintInk,
      PrizeKind.badge || PrizeKind.other => WaddyColors.primary,
    };

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
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
    if (prize.timeUntilExpiry == null) return WaddyColors.inkLight;

    final duration = prize.timeUntilExpiry!;
    if (duration.inDays < 1) {
      return WaddyColors.error;
    } else if (duration.inDays < 3) {
      return WaddyColors.amberInk;
    }
    return WaddyColors.inkLight;
  }
}
