import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:waddy_app/util/styles.dart';

class XpLeaderboardScreen extends StatefulWidget {
  const XpLeaderboardScreen({super.key});

  @override
  State<XpLeaderboardScreen> createState() => _XpLeaderboardScreenState();
}

class _XpLeaderboardScreenState extends State<XpLeaderboardScreen> {
  static const Color _brandDarkTeal = Color(0xFF134E4A);
  static const Color _brandNeonGreen = Color(0xFF1EF2A0);
  static const Color _neoBlack = Color(0xFF121212);
  static const Color _tealText = Color(0xFF0D7377);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<XpController>().getLeaderboard(reload: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandDarkTeal,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _brandNeonGreen,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _neoBlack, width: 2),
                      ),
                      child: Icon(Icons.arrow_back_rounded, size: 20, color: _neoBlack),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'leaderboard'.tr,
                    style: robotoBold.copyWith(
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.emoji_events_rounded, color: _brandNeonGreen, size: 28),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Content
            Expanded(
              child: GetBuilder<XpController>(
                builder: (xpController) {
                  if (xpController.isLeaderboardLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: _brandNeonGreen),
                    );
                  }

                  final leaderboard = xpController.leaderboardModel;
                  if (leaderboard == null || leaderboard.entries.isEmpty) {
                    return Center(
                      child: Text(
                        'no_data_available'.tr,
                        style: robotoMedium.copyWith(color: Colors.white70),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: _brandNeonGreen,
                    backgroundColor: _brandDarkTeal,
                    onRefresh: () => xpController.getLeaderboard(reload: true),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Top 3 podium
                        if (leaderboard.entries.length >= 3)
                          _buildPodium(leaderboard.entries.take(3).toList()),

                        const SizedBox(height: 16),

                        // Current user card
                        if (leaderboard.currentUser != null)
                          _buildCurrentUserCard(leaderboard.currentUser!),

                        const SizedBox(height: 16),

                        // Full list
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _neoBlack, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: _neoBlack,
                                offset: const Offset(3, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: leaderboard.entries.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: _neoBlack.withValues(alpha: 0.1),
                            ),
                            itemBuilder: (context, index) {
                              return _buildEntryTile(leaderboard.entries[index]);
                            },
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> top3) {
    // Reorder: [2nd, 1st, 3rd]
    final ordered = [
      if (top3.length > 1) top3[1],
      top3[0],
      if (top3.length > 2) top3[2],
    ];
    final heights = [100.0, 130.0, 80.0];
    final colors = [Colors.grey.shade300, _brandNeonGreen, Colors.orange.shade200];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(ordered.length, (i) {
        final entry = ordered[i];
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: i == 1 ? 56 : 44,
                height: i == 1 ? 56 : 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i],
                  border: Border.all(color: _neoBlack, width: 2),
                ),
                child: ClipOval(
                  child: entry.image != null && entry.image!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: entry.image!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person,
                            size: i == 1 ? 28 : 22,
                            color: _neoBlack,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: i == 1 ? 28 : 22,
                          color: _neoBlack,
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entry.name,
                style: robotoBold.copyWith(
                  fontSize: 11,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                '${entry.totalXp} XP',
                style: robotoMedium.copyWith(
                  fontSize: 10,
                  color: _brandNeonGreen,
                ),
              ),
              const SizedBox(height: 6),
              // Podium bar
              Container(
                height: heights[i],
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  border: Border.all(color: _neoBlack, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  entry.rankDisplay,
                  style: robotoBold.copyWith(
                    fontSize: i == 1 ? 24 : 18,
                    color: _neoBlack,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentUserCard(LeaderboardEntry user) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _brandNeonGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _neoBlack, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: _neoBlack,
            offset: const Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'your_rank'.tr,
            style: robotoMedium.copyWith(fontSize: 13, color: _neoBlack),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _brandDarkTeal,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _neoBlack, width: 1.5),
            ),
            child: Text(
              user.rankDisplay,
              style: robotoBold.copyWith(fontSize: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${user.totalXp} XP',
            style: robotoBold.copyWith(fontSize: 14, color: _neoBlack),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(LeaderboardEntry entry) {
    final isTop3 = entry.rank <= 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: Text(
              entry.rankDisplay,
              style: robotoBold.copyWith(
                fontSize: isTop3 ? 18 : 14,
                color: isTop3 ? _tealText : _neoBlack.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _neoBlack.withValues(alpha: 0.05),
              border: Border.all(
                color: isTop3 ? _brandNeonGreen : _neoBlack.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: entry.image != null && entry.image!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: entry.image!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.person,
                        size: 18,
                        color: _neoBlack.withValues(alpha: 0.4),
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 18,
                      color: _neoBlack.withValues(alpha: 0.4),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: robotoMedium.copyWith(fontSize: 14, color: _neoBlack),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.levelName != null)
                  Text(
                    '${'level'.tr} ${entry.level} · ${entry.levelName}',
                    style: robotoRegular.copyWith(
                      fontSize: 11,
                      color: _neoBlack.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),

          // XP
          Text(
            '${entry.totalXp}',
            style: robotoBold.copyWith(
              fontSize: 14,
              color: _tealText,
            ),
          ),
          Text(
            ' XP',
            style: robotoRegular.copyWith(
              fontSize: 11,
              color: _neoBlack.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
