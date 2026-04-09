import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/util/app_design_tokens.dart';

/// Compact widget showing the next reward and XP needed to reach it
/// Used in the cart bar to motivate users
class NextRewardIndicatorWidget extends StatelessWidget {
  final Color? textColor;
  final double fontSize;
  final bool compact;

  const NextRewardIndicatorWidget({
    super.key,
    this.textColor,
    this.fontSize = 10,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        final nextReward = xpController.nextReward;
        final xpToReward = xpController.xpToNextReward;

        if (nextReward == null) {
          // No next reward, show level progress instead
          final xpToNext = xpController.currentLevel?.xpToNextLevel ?? 0;
          if (xpToNext <= 0) return const SizedBox.shrink();

          return Text(
            '$xpToNext ${'to_next_level'.tr}',
            style: TextStyle(
              color: textColor ?? Colors.white.withValues(alpha: 0.7),
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          );
        }

        final rewardIcon = xpController.getRewardIcon(nextReward.type);
        final rewardName = xpController.getRewardName(nextReward.type);

        if (compact) {
          // Compact format for cart bar: "10 to 🚚"
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$xpToReward ${'to_label'.tr} ',
                style: TextStyle(
                  color: textColor ?? Colors.white.withValues(alpha: 0.7),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(rewardIcon, style: TextStyle(fontSize: fontSize + 2)),
            ],
          );
        }

        // Full format: "10 XP to 🚚 Free Delivery"
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$xpToReward ${'xp_to_label'.tr} ',
              style: TextStyle(
                color: textColor ?? Colors.white.withValues(alpha: 0.7),
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(rewardIcon, style: TextStyle(fontSize: fontSize + 2)),
            const SizedBox(width: 4),
            Text(
              rewardName,
              style: TextStyle(
                color: textColor ?? Colors.white.withValues(alpha: 0.9),
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Larger version for expanded cart drawer
class NextRewardBannerWidget extends StatelessWidget {
  const NextRewardBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        final nextReward = xpController.nextReward;
        final xpToReward = xpController.xpToNextReward;

        if (nextReward == null) {
          // No next reward available
          return const SizedBox.shrink();
        }

        final rewardIcon = xpController.getRewardIcon(nextReward.type);
        final rewardName = xpController.getRewardName(nextReward.type);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppDesignTokens.gamificationGoldLight,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
            border: Border.all(
              color: AppDesignTokens.gamificationGold.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Reward icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppDesignTokens.gamificationGold.withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDesignTokens.radiusSmall,
                  ),
                ),
                child: Center(
                  child: Text(rewardIcon, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'next_reward_label'.tr} $rewardName',
                      style: const TextStyle(
                        color: AppDesignTokens.primaryDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${'just_xp_away'.tr.replaceAll('@xp', xpToReward.toString())}',
                      style: TextStyle(
                        color: AppDesignTokens.primaryDark.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Progress indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppDesignTokens.gamificationGold,
                  borderRadius: BorderRadius.circular(
                    AppDesignTokens.radiusSmall,
                  ),
                ),
                child: Text(
                  '+$xpToReward',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
