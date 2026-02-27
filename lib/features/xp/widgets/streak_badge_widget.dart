import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/util/styles.dart';

class StreakBadgeWidget extends StatelessWidget {
  final Color neoBlack;
  final Color accentColor;

  const StreakBadgeWidget({
    super.key,
    required this.neoBlack,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        final streak = xpController.streak;
        if (streak == null || streak.currentStreak == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: neoBlack, width: 2),
            boxShadow: [
              BoxShadow(
                color: neoBlack,
                offset: const Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fire icon with streak count
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.orange.shade400,
                      Colors.deepOrange.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: neoBlack, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '🔥',
                  style: const TextStyle(fontSize: 22),
                ),
              ),

              const SizedBox(width: 12),

              // Streak info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${streak.currentStreak} ${'day_streak'.tr}',
                          style: robotoBold.copyWith(
                            fontSize: 15,
                            color: neoBlack,
                          ),
                        ),
                        if (streak.isActiveToday) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'today'.tr,
                              style: robotoBold.copyWith(
                                fontSize: 9,
                                color: neoBlack,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${'best'.tr}: ${streak.longestStreak} ${'days'.tr}',
                      style: robotoRegular.copyWith(
                        fontSize: 11,
                        color: neoBlack.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // Bonus XP badge
              if (streak.streakBonusXp > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: neoBlack, width: 1.5),
                  ),
                  child: Text(
                    '+${streak.streakBonusXp} XP',
                    style: robotoBold.copyWith(
                      fontSize: 12,
                      color: neoBlack,
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
