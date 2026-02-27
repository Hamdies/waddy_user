import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';

class XpProgressWidget extends StatelessWidget {
  const XpProgressWidget({super.key});

  // Neo-pop color palette (matching XP levels screen)
  static const Color _neoBlack = Color(0xFF121212);
  static const Color _brandNeonGreen = Color(0xFF1EF2A0);
  static const Color _brandDarkTeal = Color(0xFF134E4A);
  static const Color _tealText = Color(0xFF0D7377);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        if (xpController.isLevelLoading) {
          return _buildSkeleton(context);
        }

        final level = xpController.currentLevel;
        if (level == null) {
          return const SizedBox.shrink();
        }

        final progress = level.progressPercentage / 100;
        final visualProgress = progress > 0 ? progress : 0.05;
        final nextLevel = level.currentLevel + 1;

        // Get next level data and prize
        String? nextPrize;
        String? currentLevelImage = level.levelBadge;

        if (xpController.levelsListModel != null) {
          final nextLevelData = xpController.levelsListModel!.levels
              .firstWhereOrNull((l) => l.level == nextLevel);
          if (nextLevelData != null) {
            if (nextLevelData.prizes.isNotEmpty) {
              nextPrize = nextLevelData.prizes.first.title;
            }
          }

          if (currentLevelImage == null || currentLevelImage.isEmpty) {
            final currentLevelData = xpController.levelsListModel!.levels
                .firstWhereOrNull((l) => l.level == level.currentLevel);
            if (currentLevelData != null) {
              currentLevelImage = currentLevelData.badgeImage;
            }
          }
        }

        return GestureDetector(
          onTap: () => Get.toNamed(RouteHelper.getMainRoute('levels')),
          child: Container(
            margin: const EdgeInsets.only(
              left: Dimensions.paddingSizeDefault,
              right: Dimensions.paddingSizeDefault,
              top: 16,
            ),
            padding: const EdgeInsets.all(12),
            // Clean container styling with subtle shadow
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _neoBlack.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _neoBlack.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Compact badge with level
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _brandNeonGreen,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _neoBlack.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child:
                        (currentLevelImage != null &&
                                currentLevelImage.isNotEmpty)
                            ? CachedNetworkImage(
                              imageUrl: currentLevelImage,
                              fit: BoxFit.cover,
                              placeholder:
                                  (_, __) => const Icon(
                                    Icons.emoji_events_rounded,
                                    color: _neoBlack,
                                    size: 22,
                                  ),
                              errorWidget:
                                  (_, __, ___) => const Icon(
                                    Icons.emoji_events_rounded,
                                    color: _neoBlack,
                                    size: 22,
                                  ),
                            )
                            : const Icon(
                              Icons.emoji_events_rounded,
                              color: _neoBlack,
                              size: 22,
                            ),
                  ),
                ),

                const SizedBox(width: 10),

                // Level info + progress - compact
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Level name & XP on same row
                      Row(
                        children: [
                          // Level badge inline
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _brandDarkTeal,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _neoBlack, width: 1.5),
                            ),
                            child: Text(
                              'LV ${level.currentLevel}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              level.levelName,
                              style: const TextStyle(
                                color: _neoBlack,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // XP count
                          Text(
                            '${level.currentXp}/${level.xpForNextLevel}',
                            style: const TextStyle(
                              color: _tealText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Compact progress bar
                      Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: _neoBlack, width: 1.5),
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: visualProgress.clamp(0.08, 1.0),
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: _brandNeonGreen,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _neoBlack,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Next prize - compact inline
                      if (!level.isMaxLevel && nextPrize != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('🎁', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Next: $nextPrize',
                                style: TextStyle(
                                  color: _neoBlack.withValues(alpha: 0.6),
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Compact arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _brandNeonGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: _neoBlack,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        left: Dimensions.paddingSizeDefault,
        right: Dimensions.paddingSizeDefault,
        top: 16,
      ),
      padding: const EdgeInsets.all(12),
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neoBlack.withValues(alpha: 0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: _neoBlack.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
