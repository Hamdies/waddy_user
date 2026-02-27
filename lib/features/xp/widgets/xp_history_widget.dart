import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_history_model.dart';
import 'package:sixam_mart/util/styles.dart';

class XpHistoryWidget extends StatelessWidget {
  final Color neoBlack;
  final Color accentColor;
  final Color tealText;

  const XpHistoryWidget({
    super.key,
    required this.neoBlack,
    required this.accentColor,
    required this.tealText,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        if (xpController.isHistoryLoading && xpController.historyModel == null) {
          return _buildSkeleton();
        }

        final history = xpController.historyModel?.history ?? [];
        if (history.isEmpty) return const SizedBox.shrink();

        // Show max 5 items in the preview
        final previewItems = history.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.history_rounded, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'recent_activity'.tr,
                  style: robotoBold.copyWith(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (history.length > 5)
                  Text(
                    '${xpController.historyModel?.totalEarned ?? 0} ${'total_xp'.tr}',
                    style: robotoMedium.copyWith(
                      fontSize: 12,
                      color: accentColor,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // History items
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: neoBlack, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: neoBlack,
                    offset: const Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: previewItems.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: neoBlack.withValues(alpha: 0.1),
                ),
                itemBuilder: (context, index) {
                  return _HistoryTile(
                    item: previewItems[index],
                    neoBlack: neoBlack,
                    accentColor: accentColor,
                    tealText: tealText,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 120, height: 16,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final XpHistoryItem item;
  final Color neoBlack;
  final Color accentColor;
  final Color tealText;

  const _HistoryTile({
    required this.item,
    required this.neoBlack,
    required this.accentColor,
    required this.tealText,
  });

  @override
  Widget build(BuildContext context) {
    final isLevelUp = item.type == 'level_up';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isLevelUp
                  ? accentColor.withValues(alpha: 0.15)
                  : neoBlack.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(item.icon, style: const TextStyle(fontSize: 18)),
          ),

          const SizedBox(width: 12),

          // Description + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: robotoMedium.copyWith(
                    fontSize: 13,
                    color: neoBlack,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.timeAgo,
                  style: robotoRegular.copyWith(
                    fontSize: 11,
                    color: neoBlack.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // XP badge
          if (item.xp > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isLevelUp ? accentColor : tealText.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLevelUp ? neoBlack : tealText.withValues(alpha: 0.3),
                  width: isLevelUp ? 1.5 : 1,
                ),
              ),
              child: Text(
                '+${item.xp} XP',
                style: robotoBold.copyWith(
                  fontSize: 12,
                  color: isLevelUp ? neoBlack : tealText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
