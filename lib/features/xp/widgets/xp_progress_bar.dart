import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/util/dimensions.dart';

class XpProgressBar extends StatelessWidget {
  final double? width;
  final double height;
  final bool showLevelInfo;
  final bool compact;

  const XpProgressBar({
    super.key,
    this.width,
    this.height = 12,
    this.showLevelInfo = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      id: XpController.idLevel,
      builder: (xpController) {
        if (xpController.isLevelLoading) {
          return _buildSkeleton(context);
        }

        final level = xpController.currentLevel;
        if (level == null) {
          return const SizedBox.shrink();
        }

        // Resolve the next level's absolute xpRequired from the levels list
        // so the bar is consistent with the roadmap.
        final nextLevel = level.currentLevel + 1;
        final levels = xpController.levelsListModel?.levels ?? [];
        final nextLevelData = levels.firstWhereOrNull(
          (l) => l.level == nextLevel,
        );
        final xpTarget = nextLevelData?.xpRequired ?? level.xpForNextLevel;
        final progress =
            xpTarget > 0 ? (level.currentXp / xpTarget).clamp(0.0, 1.0) : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLevelInfo && !compact) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeSmall,
                          vertical: Dimensions.paddingSizeExtraSmall,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryColor,
                              Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                        ),
                        child: Text(
                          'Lv.${level.currentLevel}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        level.levelName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${level.currentXp} / $xpTarget XP',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (compact && showLevelInfo)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: Dimensions.paddingSizeExtraSmall,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lv.${level.currentLevel} ${level.levelName}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    Text(
                      '${level.currentXp}/$xpTarget',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                color: Colors.grey.shade200,
              ),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    width:
                        (width ?? MediaQuery.of(context).size.width) *
                        progress.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height / 2),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withValues(alpha: 0.7),
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  // Shimmer effect
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width:
                        (width ?? MediaQuery.of(context).size.width) *
                        progress.clamp(0.0, 1.0),
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ).createShader(bounds);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(height / 2),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLevelInfo) ...[
          Container(
            width: 100,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: Colors.grey.shade200,
          ),
        ),
      ],
    );
  }
}
