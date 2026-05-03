import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';

/// Inline leaderboard preview: top-3 podium + current user rank.
/// Tapping anywhere opens the full leaderboard screen.
class XpLeaderboardPreviewWidget extends StatelessWidget {
  final Color neoBlack;
  final Color accentColor;
  final Color tealBg;

  const XpLeaderboardPreviewWidget({
    super.key,
    required this.neoBlack,
    required this.accentColor,
    required this.tealBg,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        final leaderboard = xpController.leaderboardModel;
        final isLoading = xpController.isLeaderboardLoading;

        return GestureDetector(
          onTap: () => Get.toNamed(RouteHelper.xpLeaderboard),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: neoBlack, width: 2.5),
              boxShadow: [
                BoxShadow(color: neoBlack, offset: const Offset(4, 4), blurRadius: 0),
              ],
            ),
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────────
                Container(
                  // Min 48px tap target height
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    border: Border(bottom: BorderSide(color: neoBlack, width: 2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_rounded, color: neoBlack, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'leaderboard'.tr,
                        style: robotoBold.copyWith(fontSize: 15, color: neoBlack),
                      ),
                      const Spacer(),
                      // "See All" pill — bold, full-opacity
                      Container(
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: neoBlack.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: neoBlack.withValues(alpha: 0.25), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'see_all'.tr.toUpperCase(),
                              style: robotoBlack.copyWith(fontSize: 10, color: neoBlack, letterSpacing: 1.2),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.chevron_right_rounded, size: 15, color: neoBlack),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Body ────────────────────────────────────────────────────
                if (isLoading && leaderboard == null)
                  _buildSkeleton()
                else if (leaderboard == null || leaderboard.entries.isEmpty)
                  _buildEmpty()
                else
                  _buildContent(leaderboard),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(XpLeaderboardModel leaderboard) {
    final top3 = leaderboard.entries.take(3).toList();
    final currentUser = leaderboard.currentUser;
    final userInTop3 = currentUser != null && currentUser.rank <= 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Fluid inner horizontal padding: tight on small screens, generous on large
        final hPad = (w * 0.044).clamp(12.0, 20.0);

        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 8),
          child: Column(
            children: [
              // ── Top 3 Podium ─────────────────────────────────────────────
              _Podium(top3: top3, neoBlack: neoBlack, accentColor: accentColor),

              // ── Current user rank row ─────────────────────────────────────
              if (currentUser != null && !userInTop3) ...[
                const SizedBox(height: 14),
                Divider(color: neoBlack.withValues(alpha: 0.08), thickness: 1),
                const SizedBox(height: 10),
                _UserRankRow(
                  user: currentUser,
                  neoBlack: neoBlack,
                  accentColor: accentColor,
                  tealBg: tealBg,
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    // LayoutBuilder drives fluid skeleton proportions, matching the real podium
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final hPad = (w * 0.044).clamp(12.0, 20.0);
        final colW = (w - hPad * 2 - 16) / 3; // approx column width

        // Scale bars relative to column width
        final bar1st = (colW * 0.85).clamp(70.0, 120.0);
        final bar2nd = (colW * 0.62).clamp(52.0, 88.0);
        final bar3rd = (colW * 0.48).clamp(40.0, 68.0);
        final av1st = (colW * 0.44).clamp(44.0, 64.0);
        final av2nd = (colW * 0.34).clamp(36.0, 52.0);
        final av3rd = (colW * 0.31).clamp(32.0, 46.0);

        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _SkeletonPodiumColumn(barHeight: bar2nd, avatarSize: av2nd)),
                  const SizedBox(width: 8),
                  Expanded(child: _SkeletonPodiumColumn(barHeight: bar1st, avatarSize: av1st)),
                  const SizedBox(width: 8),
                  Expanded(child: _SkeletonPodiumColumn(barHeight: bar3rd, avatarSize: av3rd)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: neoBlack.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text(
            'be_first_on_leaderboard'.tr,
            style: robotoBold.copyWith(fontSize: 14, color: neoBlack),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'place_order_to_earn_xp'.tr,
            style: robotoRegular.copyWith(fontSize: 12, color: neoBlack.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Skeleton column (avatar circle + bar) ───────────────────────────────────
class _SkeletonPodiumColumn extends StatelessWidget {
  final double barHeight;
  final double avatarSize;

  const _SkeletonPodiumColumn({required this.barHeight, required this.avatarSize});

  @override
  Widget build(BuildContext context) {
    const shimmer = Color(0xFF121212);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: shimmer.withValues(alpha: 0.08),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 48,
          height: 10,
          decoration: BoxDecoration(
            color: shimmer.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 8,
          decoration: BoxDecoration(
            color: shimmer.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: shimmer.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
        ),
      ],
    );
  }
}

// ── Top-3 Podium ──────────────────────────────────────────────────────────────
class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  final Color neoBlack;
  final Color accentColor;

  const _Podium({required this.top3, required this.neoBlack, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    // Reorder: 2nd | 1st | 3rd
    final ordered = [
      if (top3.length > 1) top3[1],
      top3[0],
      if (top3.length > 2) top3[2],
    ];

    // Medal emojis
    const medals = ['🥈', '🥇', '🥉'];
    // Bar fill colors: silver | gold accent | bronze
    final barColors = [
      const Color(0xFFD0D5DD),
      accentColor,
      const Color(0xFFFFD6A5),
    ];
    // Medal badge bg colors
    final medalBgColors = [
      const Color(0xFFB0B8C1),
      const Color(0xFFFFC107),
      const Color(0xFFCD7F32),
    ];

    // Use LayoutBuilder so every dimension is proportional to available width
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Each column gets roughly 1/3 of available width after gaps
        final colW = (w - 16) / 3; // 16 = 2 × 8px gaps

        // Avatar sizes: fluid, clamped to min/max for legibility
        final avatarSizes = [
          (colW * 0.58).clamp(38.0, 54.0), // 2nd
          (colW * 0.74).clamp(48.0, 68.0), // 1st
          (colW * 0.52).clamp(34.0, 48.0), // 3rd
        ];

        // Bar heights: proportional — 1st is tallest
        final barHeights = [
          (colW * 0.64).clamp(60.0, 96.0),  // 2nd
          (colW * 0.88).clamp(80.0, 130.0), // 1st
          (colW * 0.50).clamp(48.0, 74.0),  // 3rd
        ];

        // Font sizes for watermark rank number inside bar
        final rankFontSizes = [
          (colW * 0.22).clamp(16.0, 26.0),
          (colW * 0.30).clamp(22.0, 36.0),
          (colW * 0.20).clamp(14.0, 22.0),
        ];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(ordered.length, (i) {
            final entry = ordered[i];
            final isFirst = i == 1;
            final avatarSize = avatarSizes[i];
            final barHeight = barHeights[i];
            final barColor = barColors[i];
            final rankFontSize = rankFontSizes[i];
            // Medal badge size: proportional to avatar
            final badgeSize = (avatarSize * 0.40).clamp(14.0, 24.0);

            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isFirst ? 4.0 : 2.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Avatar + medal badge ──────────────────────────────
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Avatar circle
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: barColor,
                            border: Border.all(
                              color: isFirst ? neoBlack : neoBlack.withValues(alpha: 0.4),
                              width: isFirst ? 2.5 : 2.0,
                            ),
                            boxShadow: isFirst
                                ? [BoxShadow(
                                    color: neoBlack,
                                    offset: const Offset(2, 2),
                                    blurRadius: 0,
                                  )]
                                : null,
                          ),
                          child: ClipOval(
                            child: entry.image != null && entry.image!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: entry.image!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Icon(
                                      Icons.person_rounded,
                                      size: avatarSize * 0.5,
                                      color: const Color(0xFF121212).withValues(alpha: 0.45),
                                    ),
                                  )
                                : Icon(
                                    Icons.person_rounded,
                                    size: avatarSize * 0.5,
                                    color: const Color(0xFF121212).withValues(alpha: 0.45),
                                  ),
                          ),
                        ),
                        // ── Medal badge — bottom-right ────────────────────
                        Positioned(
                          bottom: -4,
                          right: (avatarSize / 2 - badgeSize - 2).clamp(0, avatarSize),
                          child: Container(
                            width: badgeSize,
                            height: badgeSize,
                            decoration: BoxDecoration(
                              color: medalBgColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              medals[i],
                              style: TextStyle(fontSize: badgeSize * 0.52),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: (colW * 0.06).clamp(5.0, 10.0)),

                    // Name — fluid, black weight for 1st
                    Text(
                      entry.name.split(' ').first,
                      style: (isFirst ? robotoBlack : robotoBold).copyWith(
                        fontSize: isFirst
                            ? (colW * 0.11).clamp(11.0, 14.0)
                            : (colW * 0.095).clamp(10.0, 13.0),
                        color: const Color(0xFF1A1A1A),
                        letterSpacing: isFirst ? -0.3 : 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: (colW * 0.02).clamp(2.0, 4.0)),

                    // XP — bold for 1st
                    Text(
                      '${entry.totalXp} XP',
                      style: (isFirst ? robotoBold : robotoMedium).copyWith(
                        fontSize: (colW * 0.088).clamp(9.0, 12.0),
                        color: isFirst ? const Color(0xFF3A4A4E) : const Color(0xFF5A6670),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: (colW * 0.05).clamp(4.0, 8.0)),

                    // ── Podium bar ────────────────────────────────────────
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        border: Border.all(
                          color: isFirst ? neoBlack : neoBlack.withValues(alpha: 0.35),
                          width: isFirst ? 2.5 : 1.5,
                        ),
                        boxShadow: isFirst
                            ? [BoxShadow(
                                color: neoBlack,
                                offset: const Offset(3, 3),
                                blurRadius: 0,
                              )]
                            : null,
                      ),
                      alignment: Alignment.center,
                      // Ghosted rank number as watermark — black weight for drama
                      child: Text(
                        i == 1 ? '1' : i == 0 ? '2' : '3',
                        style: robotoBlack.copyWith(
                          fontSize: rankFontSize,
                          color: isFirst
                              ? neoBlack.withValues(alpha: 0.20)
                              : neoBlack.withValues(alpha: 0.13),
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Current user rank row ─────────────────────────────────────────────────────
class _UserRankRow extends StatelessWidget {
  final LeaderboardEntry user;
  final Color neoBlack;
  final Color accentColor;
  final Color tealBg;

  const _UserRankRow({
    required this.user,
    required this.neoBlack,
    required this.accentColor,
    required this.tealBg,
  });

  @override
  Widget build(BuildContext context) {
    // Min 48px height for comfortable touch target
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor, width: 2),
      ),
      child: Row(
        children: [
          // "You" label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: neoBlack, width: 2),
              boxShadow: [BoxShadow(color: neoBlack, offset: const Offset(2, 2), blurRadius: 0)],
            ),
            child: Text(
              'you_label'.tr.toUpperCase(),
              style: robotoBlack.copyWith(fontSize: 10, color: neoBlack, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Text(
              user.name.split(' ').first,
              style: robotoBold.copyWith(fontSize: 14, color: neoBlack),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // XP — bold, neoBlack
          Text(
            '${user.totalXp} XP',
            style: robotoBlack.copyWith(fontSize: 13, color: neoBlack),
          ),
          const SizedBox(width: 10),
          // Rank badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: tealBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: neoBlack, width: 1.5),
              boxShadow: [BoxShadow(color: neoBlack, offset: const Offset(2, 2), blurRadius: 0)],
            ),
            child: Text(
              user.rank <= 3 ? user.rankDisplay : '#${user.rank}',
              style: robotoBold.copyWith(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
