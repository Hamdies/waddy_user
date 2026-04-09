import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:waddy_app/features/xp/domain/models/xp_level_model.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/widgets/level_claim_celebration_widget.dart';
import 'package:get/get.dart';
import 'package:waddy_app/util/styles.dart';

/// Compact card-based roadmap — each level is a tappable horizontal card
class BrilliantRoadmapWidget extends StatelessWidget {
  final List<Level> levels;
  final int currentLevel;
  final int currentXp;
  final XpController? xpController;
  final Color? themeBg;
  final Color? themeAccent;
  final Color? themeBlack;

  static const Color _defTeal = Color(0xFF134E4A);
  static const Color _defNeon = Color(0xFF1EF2A0);
  static const Color _defBlack = Color(0xFF121212);

  const BrilliantRoadmapWidget({
    super.key,
    required this.levels,
    this.currentLevel = 1,
    this.currentXp = 0,
    this.xpController,
    this.themeBg,
    this.themeAccent,
    this.themeBlack,
  });

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.route_rounded, color: themeAccent ?? _defNeon, size: 20),
            const SizedBox(width: 8),
            Text(
              'level_roadmap'.tr,
              style: robotoBold.copyWith(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Level cards
        ...levels.asMap().entries.map((entry) {
          final index = entry.key;
          final level = entry.value;
          final isLast = index == levels.length - 1;
          return _LevelCard(
            level: level,
            currentXp: xpController?.levelsListModel?.currentXp ??
                xpController?.currentLevel?.currentXp ??
                currentXp,
            isLast: isLast,
            xpController: xpController,
            teal: themeBg ?? _defTeal,
            neon: themeAccent ?? _defNeon,
            neoBlack: themeBlack ?? _defBlack,
          );
        }),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  final Level level;
  final int currentXp;
  final bool isLast;
  final XpController? xpController;
  final Color teal;
  final Color neon;
  final Color neoBlack;

  const _LevelCard({
    required this.level,
    required this.currentXp,
    required this.isLast,
    this.xpController,
    this.teal = const Color(0xFF134E4A),
    this.neon = const Color(0xFF1EF2A0),
    this.neoBlack = const Color(0xFF121212),
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = level.isCurrent;
    final isCompleted = level.isUnlocked && !isCurrent;
    final isLocked = !level.isUnlocked;
    final hasPrizes = level.prizes.isNotEmpty;
    final hasUnclaimedPrizes =
        hasPrizes && level.prizes.any((p) => !p.isClaimed);

    return Column(
      children: [
        GestureDetector(
          onTap: () => _onTap(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCurrent
                  ? Colors.white
                  : isCompleted
                      ? Colors.white.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrent
                    ? neon
                    : isCompleted
                        ? teal.withValues(alpha: 0.3)
                        : neoBlack.withValues(alpha: 0.08),
                width: isCurrent ? 2.5 : 1.5,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: neon.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: neoBlack,
                        offset: const Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                _buildBadge(isCurrent, isCompleted, isLocked),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              level.name,
                              style: robotoBold.copyWith(
                                fontSize: 15,
                                color: isLocked
                                    ? neoBlack.withValues(alpha: 0.35)
                                    : neoBlack,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent) _buildStatusChip('you_label'.tr, neon, neoBlack),
                          if (isCompleted) _buildStatusChip('✓', teal, Colors.white),
                          if (isLocked)
                            Text(
                              '${level.xpRequired} XP',
                              style: robotoMedium.copyWith(
                                fontSize: 11,
                                color: neoBlack.withValues(alpha: 0.3),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (isCurrent) ...[
                        _buildMiniProgressBar(),
                        const SizedBox(height: 4),
                      ],
                      if (hasPrizes && !isLocked)
                        _buildPrizePreview(hasUnclaimedPrizes)
                      else if (hasPrizes && isLocked)
                        Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 12,
                                color: neoBlack.withValues(alpha: 0.2)),
                            const SizedBox(width: 4),
                            Text(
                              '${level.prizes.length} ${level.prizes.length == 1 ? 'prize_singular'.tr : 'prizes_plural'.tr}',
                              style: robotoRegular.copyWith(
                                fontSize: 11,
                                color: neoBlack.withValues(alpha: 0.25),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '${'level'.tr} ${level.level}',
                          style: robotoRegular.copyWith(
                            fontSize: 11,
                            color: neoBlack.withValues(alpha: 0.3),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isCurrent
                      ? teal
                      : neoBlack.withValues(alpha: isLocked ? 0.15 : 0.3),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Container(
            width: 2,
            height: 10,
            margin: const EdgeInsets.only(left: 32),
            color: isCompleted || isCurrent
                ? teal.withValues(alpha: 0.25)
                : neoBlack.withValues(alpha: 0.06),
          ),
      ],
    );
  }

  Widget _buildBadge(bool isCurrent, bool isCompleted, bool isLocked) {
    final double size = isCurrent ? 48 : 40;

    if (isCurrent && level.badgeImage != null && level.badgeImage!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: neon, width: 2),
          boxShadow: [
            BoxShadow(color: neon.withValues(alpha: 0.3), blurRadius: 8),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: level.badgeImage!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _buildIconBadge(isCurrent, isCompleted, isLocked, size),
          ),
        ),
      );
    }

    if (isCompleted && level.badgeImage != null && level.badgeImage!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: teal.withValues(alpha: 0.3), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: level.badgeImage!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _buildIconBadge(isCurrent, isCompleted, isLocked, size),
          ),
        ),
      );
    }

    return _buildIconBadge(isCurrent, isCompleted, isLocked, size);
  }

  Widget _buildIconBadge(bool isCurrent, bool isCompleted, bool isLocked, double size) {
    Color bg;
    Color iconColor;
    IconData icon;

    if (isCurrent) {
      bg = neon;
      iconColor = neoBlack;
      icon = Icons.star_rounded;
    } else if (isCompleted) {
      bg = teal;
      iconColor = Colors.white;
      icon = Icons.check_rounded;
    } else {
      bg = neoBlack.withValues(alpha: 0.06);
      iconColor = neoBlack.withValues(alpha: 0.2);
      icon = Icons.lock_rounded;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(isCurrent ? 14 : 12),
        border: isCurrent ? Border.all(color: neoBlack, width: 2) : null,
      ),
      child: Icon(icon, color: iconColor, size: isCurrent ? 24 : 18),
    );
  }

  Widget _buildStatusChip(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: label == 'you_label'.tr ? Border.all(color: neoBlack, width: 1.5) : null,
      ),
      child: Text(
        label,
        style: robotoBold.copyWith(fontSize: 10, color: textColor),
      ),
    );
  }

  Widget _buildMiniProgressBar() {
    final xpRequired = level.xpRequired;
    final progress = xpRequired > 0
        ? (currentXp / xpRequired).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: neoBlack.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress > 0.05 ? progress : 0.05,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: neon,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$currentXp / $xpRequired XP',
              style: robotoMedium.copyWith(fontSize: 10, color: teal),
            ),
            if (currentXp < xpRequired)
              Text(
                '${xpRequired - currentXp} ${'to_go'.tr}',
                style: robotoRegular.copyWith(
                  fontSize: 10,
                  color: neoBlack.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrizePreview(bool hasUnclaimed) {
    final prizeIcons = level.prizes.take(3).map((p) {
      switch (p.type.toLowerCase()) {
        case 'free_delivery':
          return '🚚';
        case 'discount':
          return '💰';
        case 'wallet_credit':
          return '💳';
        case 'badge':
          return '🏅';
        default:
          return '🎁';
      }
    }).toList();

    return Row(
      children: [
        ...prizeIcons.map((emoji) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(emoji, style: const TextStyle(fontSize: 12)),
            )),
        const SizedBox(width: 4),
        if (hasUnclaimed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: neon.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'claim'.tr,
              style: robotoBold.copyWith(fontSize: 9, color: teal),
            ),
          )
        else
          Text(
            'claimed'.tr,
            style: robotoRegular.copyWith(
              fontSize: 10,
              color: neoBlack.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }

  void _onTap(BuildContext context) {
    final xp = xpController?.levelsListModel?.currentXp ??
        xpController?.currentLevel?.currentXp ??
        currentXp;

    if (level.isUnlocked) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => LevelClaimCelebrationWidget(
          level: level.level,
          levelName: level.name,
          badgeImage: level.badgeImage,
          description: level.description,
          prizes: level.prizes,
          hasPrizesToClaim:
              level.prizes.isNotEmpty && level.prizes.any((p) => !p.isClaimed),
          onClaimPrizes: (levelNum) async {
            bool allSuccess = true;
            final controller = xpController;
            if (controller == null) return false;
            for (var prize in level.prizes) {
              if (prize.isClaimed) continue;
              final success = await controller.claimPrize(prize.claimId);
              if (!success) allSuccess = false;
            }
            if (allSuccess) controller.getAllLevels(reload: true);
            return allSuccess;
          },
        ),
      );
    } else {
      _showLockedSheet(context, xp);
    }
  }

  void _showLockedSheet(BuildContext context, int userXp) {
    final xpNeeded = (level.xpRequired - userXp).clamp(0, 999999);
    final progress = level.xpRequired > 0
        ? (userXp / level.xpRequired).clamp(0.0, 1.0)
        : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: neoBlack, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: neoBlack,
              offset: const Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: neoBlack.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.lock_rounded,
                  color: neoBlack.withValues(alpha: 0.25), size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              level.name,
              style: robotoBold.copyWith(fontSize: 20, color: neoBlack),
            ),
            const SizedBox(height: 4),
            Text(
              '${'level'.tr} ${level.level} · ${level.xpRequired} ${'xp_required_label'.tr}',
              style: robotoRegular.copyWith(
                fontSize: 13,
                color: neoBlack.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: neoBlack.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: neoBlack.withValues(alpha: 0.1), width: 1),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress > 0.03 ? progress : 0.03,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: neon,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: neoBlack, width: 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$userXp / ${level.xpRequired} XP',
                  style: robotoBold.copyWith(fontSize: 13, color: neoBlack),
                ),
                Text(
                  '$xpNeeded ${'xp_to_go'.tr}',
                  style: robotoMedium.copyWith(
                    fontSize: 12,
                    color: neoBlack.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            if (level.prizes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: neon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: neon.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        level.prizes.map((p) => p.title).join(', '),
                        style: robotoMedium.copyWith(
                          fontSize: 12,
                          color: teal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
