import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/xp_history_model.dart';
import 'package:waddy_app/util/styles.dart';

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

class _HistoryTile extends StatefulWidget {
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
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _popController;
  late Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _popScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _popController, curve: Curves.elasticOut),
    );
    // level_up tiles pop in; regular tiles just appear
    if (widget.item.type == 'level_up') {
      _popController.forward();
    } else {
      _popController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLevelUp = widget.item.type == 'level_up';
    final sw = MediaQuery.sizeOf(context).width;
    final isCompact = sw < 360;
    final iconSize = isCompact ? 32.0 : 36.0;
    final hPad = isCompact ? 10.0 : 14.0;
    final vPad = isCompact ? 10.0 : 12.0;

    return ScaleTransition(
      scale: _popScale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        child: Row(
          children: [
            // Icon
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: isLevelUp
                    ? widget.accentColor.withValues(alpha: 0.15)
                    : widget.neoBlack.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
              ),
              alignment: Alignment.center,
              child: Text(widget.item.icon, style: TextStyle(fontSize: isCompact ? 16.0 : 18.0)),
            ),

            SizedBox(width: isCompact ? 8 : 12),

            // Description + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.description,
                    style: robotoMedium.copyWith(
                      fontSize: isCompact ? 12.0 : 13.0,
                      color: widget.neoBlack,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.item.timeAgo,
                    style: robotoRegular.copyWith(
                      fontSize: 11,
                      color: widget.neoBlack.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // XP badge
            if (widget.item.xp > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 7 : 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isLevelUp ? widget.accentColor : widget.tealText.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLevelUp ? widget.neoBlack : widget.tealText.withValues(alpha: 0.3),
                    width: isLevelUp ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  '+${widget.item.xp} XP',
                  style: robotoBold.copyWith(
                    fontSize: isCompact ? 11.0 : 12.0,
                    color: isLevelUp ? widget.neoBlack : widget.tealText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
