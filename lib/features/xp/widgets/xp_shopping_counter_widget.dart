import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

/// A live XP counter widget shown during shopping (cart screen)
/// Encourages users to add more items to earn more XP
class XpShoppingCounterWidget extends StatefulWidget {
  final double? overrideAmount;
  
  const XpShoppingCounterWidget({
    super.key,
    this.overrideAmount,
  });

  @override
  State<XpShoppingCounterWidget> createState() => _XpShoppingCounterWidgetState();
}

class _XpShoppingCounterWidgetState extends State<XpShoppingCounterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  int _displayedXp = 0;
  int _previousXp = 0;
  bool _configFetched = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _fetchXpConfig();
  }

  void _fetchXpConfig() {
    if (_configFetched) return;
    _configFetched = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final xpController = Get.find<XpController>();
      await xpController.getXpConfig();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _animateXpIncrease(int newXp) {
    if (newXp > _previousXp) {
      _pulseController.forward().then((_) {
        _pulseController.reverse();
      });
    }
    _previousXp = newXp;
  }

  String? _getModuleType() {
    final splashController = Get.find<SplashController>();
    return splashController.module?.moduleType;
  }

  @override
  Widget build(BuildContext context) {
    // Only show for logged-in users (not guests)
    if (!AuthHelper.isLoggedIn()) {
      return const SizedBox.shrink();
    }

    return GetBuilder<XpController>(
      builder: (xpController) {
        // Don't show if config not loaded or leveling disabled
        if (xpController.isXpConfigLoading) {
          return const SizedBox.shrink();
        }
        
        if (xpController.xpConfig == null || !xpController.xpConfig!.levelingEnabled) {
          return const SizedBox.shrink();
        }

        return GetBuilder<CartController>(
          builder: (cartController) {
            // Get order amount from cart or override
            final orderAmount = widget.overrideAmount ?? 
                (cartController.itemPrice + cartController.addOns - cartController.itemDiscountPrice);
            
            if (orderAmount <= 0) {
              return const SizedBox.shrink();
            }

            final moduleType = _getModuleType();
            final estimatedXp = xpController.calculateEstimatedXp(orderAmount, moduleType);
            
            // Animate if XP increased
            if (estimatedXp != _displayedXp) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _animateXpIncrease(estimatedXp);
                  setState(() {
                    _displayedXp = estimatedXp;
                  });
                }
              });
            }

            final Color primaryColor = Theme.of(context).primaryColor;
            final Color accentColor = Theme.of(context).secondaryHeaderColor;

            // Next reward info
            final nextReward = xpController.nextReward;
            final nextRewardLevel = xpController.nextRewardLevel;
            final xpToNext = xpController.xpToNextReward;

            // Determine prize icon & label
            IconData prizeIcon = Icons.card_giftcard_rounded;
            String prizeLabel = nextReward?.title ?? '';
            if (nextReward != null) {
              if (nextReward.type == 'free_delivery') {
                prizeIcon = Icons.local_shipping_rounded;
                if (prizeLabel.isEmpty) prizeLabel = 'free_delivery_prize'.tr;
              } else if (nextReward.type == 'discount') {
                prizeIcon = Icons.percent_rounded;
                if (prizeLabel.isEmpty) prizeLabel = 'discount_prize'.tr;
              } else if (nextReward.type == 'wallet_credit') {
                prizeIcon = Icons.account_balance_wallet_rounded;
                if (prizeLabel.isEmpty) prizeLabel = 'wallet_credit_prize'.tr;
              }
            }

            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
                    ),
                    child: Row(
                      children: [
                        // Left: sparkle icon
                        Icon(Icons.auto_awesome, size: 16, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          'earn_xp'.tr,
                          style: robotoRegular.copyWith(fontSize: 11, color: Colors.grey.shade500),
                        ),

                        // Center: next delivery prize
                        if (nextReward != null) ...[
                          const SizedBox(width: 10),
                          Container(width: 1, height: 24, color: Colors.grey.shade200),
                          const SizedBox(width: 10),
                          Icon(prizeIcon, size: 16, color: primaryColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  prizeLabel,
                                  style: robotoMedium.copyWith(fontSize: 11, color: primaryColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (xpToNext > 0)
                                  Text(
                                    '$xpToNext ${'xp_to_lvl'.tr} $nextRewardLevel',
                                    style: robotoRegular.copyWith(fontSize: 9, color: Colors.grey.shade400),
                                  ),
                              ],
                            ),
                          ),
                        ] else
                          const Spacer(),

                        const SizedBox(width: 8),

                        // Right: XP badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+$_displayedXp XP',
                            style: robotoBold.copyWith(
                              fontSize: 14,
                              color: primaryColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

}
