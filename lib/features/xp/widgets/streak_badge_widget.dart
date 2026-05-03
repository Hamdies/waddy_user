import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/util/styles.dart';

class StreakBadgeWidget extends StatefulWidget {
  final Color neoBlack;
  final Color accentColor;

  const StreakBadgeWidget({
    super.key,
    required this.neoBlack,
    required this.accentColor,
  });

  @override
  State<StreakBadgeWidget> createState() => _StreakBadgeWidgetState();
}

class _StreakBadgeWidgetState extends State<StreakBadgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _fireController;
  late Animation<double> _fireScale;
  late Animation<double> _fireGlow;

  @override
  void initState() {
    super.initState();
    _fireController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);
    _fireScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _fireController, curve: Curves.easeInOut),
    );
    _fireGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fireController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fireController.dispose();
    super.dispose();
  }

  /// Milestone at 7, 14, 30, 60, 100 days — fire icon animates
  bool _isMilestone(int streak) =>
      streak >= 7 && (streak % 7 == 0 || streak >= 30);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        final streak = xpController.streak;
        if (streak == null || streak.currentStreak == 0) {
          return const SizedBox.shrink();
        }

        final isMilestone = _isMilestone(streak.currentStreak);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMilestone ? widget.accentColor : widget.neoBlack,
              width: isMilestone ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.neoBlack,
                offset: const Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fire icon — pulses on milestone streaks
              isMilestone
                  ? AnimatedBuilder(
                      animation: _fireController,
                      builder: (_, __) => Transform.scale(
                        scale: _fireScale.value,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: widget.accentColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: widget.neoBlack, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: widget.accentColor.withValues(alpha: _fireGlow.value * 0.6),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text('🔥', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: widget.neoBlack, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🔥', style: TextStyle(fontSize: 22)),
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
                            color: widget.neoBlack,
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
                              color: widget.accentColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'today'.tr,
                              style: robotoBold.copyWith(
                                fontSize: 11,
                                color: widget.neoBlack,
                              ),
                            ),
                          ),
                        ],
                        if (isMilestone) ...[
                          const SizedBox(width: 6),
                          const Text('🎯', style: TextStyle(fontSize: 12)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${'best'.tr}: ${streak.longestStreak} ${'days'.tr}',
                      style: robotoRegular.copyWith(
                        fontSize: 11,
                        color: widget.neoBlack.withValues(alpha: 0.5),
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
                    color: widget.accentColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: widget.neoBlack, width: 1.5),
                  ),
                  child: Text(
                    '+${streak.streakBonusXp} XP',
                    style: robotoBold.copyWith(
                      fontSize: 12,
                      color: widget.neoBlack,
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
