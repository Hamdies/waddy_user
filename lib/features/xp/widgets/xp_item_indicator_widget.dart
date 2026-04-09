import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// A compact XP indicator shown when adding items to cart
/// Shows the XP that will be earned from this item
class XpItemIndicatorWidget extends StatelessWidget {
  final double itemPrice;
  final int quantity;
  
  const XpItemIndicatorWidget({
    super.key,
    required this.itemPrice,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    // Only show for logged-in users (not guests)
    if (!AuthHelper.isLoggedIn()) {
      return const SizedBox.shrink();
    }

    return GetBuilder<XpController>(
      builder: (xpController) {
        // Fetch config if not loaded
        if (xpController.xpConfig == null && !xpController.isXpConfigLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            xpController.getXpConfig();
          });
          return const SizedBox.shrink();
        }
        
        if (xpController.xpConfig == null || !xpController.xpConfig!.levelingEnabled) {
          return const SizedBox.shrink();
        }

        final splashController = Get.find<SplashController>();
        final moduleType = splashController.module?.moduleType;
        final totalPrice = itemPrice * quantity;
        final estimatedXp = xpController.calculateEstimatedXp(totalPrice, moduleType);
        
        if (estimatedXp <= 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeSmall,
            vertical: Dimensions.paddingSizeExtraSmall,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF134E4A).withOpacity(0.9),
                const Color(0xFF0D7377).withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFF1EF2A0),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '+$estimatedXp XP',
                style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: const Color(0xFF1EF2A0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
