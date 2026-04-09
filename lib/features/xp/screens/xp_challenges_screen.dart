import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/util/styles.dart';

class XpChallengesScreen extends StatefulWidget {
  const XpChallengesScreen({super.key});

  @override
  State<XpChallengesScreen> createState() => _XpChallengesScreenState();
}

class _XpChallengesScreenState extends State<XpChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _countdownTimer;

  // --- COLOR PALETTE (Same as XP Levels Screen) ---
  final Color brandDarkTeal = const Color(0xFF134E4A);
  final Color brandNeonGreen = const Color(0xFF1EF2A0);
  final Color neoBlack = const Color(0xFF121212);
  final Color lightTeal = const Color(0xFFE0F7F4);
  final Color tealText = const Color(0xFF0D7377);
  final Color textSecondary = const Color(0xFF5A6670);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        Get.find<XpController>().changeChallengeTab(_tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<XpController>().getChallenges();
    });

    // Live countdown timer — tick every 30 seconds
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandDarkTeal,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildHeader(),

            // Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildNeoTabBar(),
            ),

            const SizedBox(height: 16),

            // Reset Timer Info
            GetBuilder<XpController>(
              builder: (xpController) {
                if (xpController.challengeModel != null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildResetInfo(xpController),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 16),

            // Challenges List
            Expanded(
              child: GetBuilder<XpController>(
                builder: (xpController) {
                  if (xpController.isChallengesLoading) {
                    return Center(
                      child: CircularProgressIndicator(color: brandNeonGreen),
                    );
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChallengesList(
                        xpController.challengeModel?.dailyChallenges ?? [],
                        xpController,
                        isDaily: true,
                      ),
                      _buildChallengesList(
                        xpController.challengeModel?.weeklyChallenges ?? [],
                        xpController,
                        isDaily: false,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎯 ${'challenges'.tr}',
                  style: robotoBold.copyWith(fontSize: 22, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'complete_challenges_to_earn_xp'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeoTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neoBlack, width: 2.5),
        boxShadow: [
          BoxShadow(color: neoBlack, offset: const Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: brandNeonGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: neoBlack,
        unselectedLabelColor: textSecondary,
        labelStyle: robotoBold.copyWith(fontSize: 14),
        unselectedLabelStyle: robotoMedium.copyWith(fontSize: 14),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.today_rounded, size: 18),
                const SizedBox(width: 8),
                Text('daily'.tr),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.date_range_rounded, size: 18),
                const SizedBox(width: 8),
                Text('weekly'.tr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetInfo(XpController xpController) {
    final challenges = xpController.challengeModel;
    if (challenges == null) return const SizedBox.shrink();

    final isDaily = xpController.selectedChallengeTab == 0;
    final resetTime =
        isDaily ? challenges.dailyResetTime : challenges.weeklyResetTime;

    if (resetTime == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final duration = resetTime.difference(now);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: lightTeal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neoBlack, width: 2),
        boxShadow: [
          BoxShadow(color: neoBlack, offset: const Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: brandNeonGreen,
              shape: BoxShape.circle,
              border: Border.all(color: neoBlack, width: 2),
            ),
            child: Icon(Icons.timer_outlined, size: 18, color: neoBlack),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDaily ? 'daily_reset'.tr : 'weekly_reset'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
                Text(
                  'challenges_reset_in'.tr,
                  style: robotoBold.copyWith(fontSize: 14, color: tealText),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: brandNeonGreen,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: neoBlack, width: 2),
            ),
            child: Text(
              '${hours}h ${minutes}m',
              style: robotoBold.copyWith(fontSize: 14, color: neoBlack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesList(
    List<Challenge> challenges,
    XpController xpController, {
    required bool isDaily,
  }) {
    if (challenges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 40,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'no_challenges_available'.tr,
              style: robotoMedium.copyWith(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isDaily ? 'check_back_tomorrow'.tr : 'check_back_next_week'.tr,
              style: robotoRegular.copyWith(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => xpController.getChallenges(reload: true),
      color: brandNeonGreen,
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: challenges.length,
        itemBuilder: (context, index) {
          final challenge = challenges[index];
          return _NeoChallengeCard(
            challenge: challenge,
            neoBlack: neoBlack,
            accentColor: brandNeonGreen,
            lightTeal: lightTeal,
            tealText: tealText,
            textSecondary: textSecondary,
            isLoading: xpController.isClaimingChallengeId(challenge.id),
            onClaim:
                challenge.canClaim
                    ? () => xpController.claimChallenge(challenge.id)
                    : null,
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// NEO CHALLENGE CARD
// -----------------------------------------------------------------------------
class _NeoChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final Color neoBlack;
  final Color accentColor;
  final Color lightTeal;
  final Color tealText;
  final Color textSecondary;
  final VoidCallback? onClaim;
  final bool isLoading;

  const _NeoChallengeCard({
    required this.challenge,
    required this.neoBlack,
    required this.accentColor,
    required this.lightTeal,
    required this.tealText,
    required this.textSecondary,
    this.onClaim,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDaily = challenge.type == 'daily';
    final canClaim = challenge.canClaim;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canClaim ? accentColor : neoBlack,
          width: canClaim ? 3 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: canClaim ? accentColor.withValues(alpha: 0.5) : neoBlack,
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Challenge Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDaily ? Colors.orange.shade50 : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDaily ? Colors.orange : Colors.purple,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDaily
                            ? Icons.today_rounded
                            : Icons.date_range_rounded,
                        size: 14,
                        color: isDaily ? Colors.orange : Colors.purple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isDaily ? 'daily'.tr : 'weekly'.tr,
                        style: robotoBold.copyWith(
                          fontSize: 11,
                          color: isDaily ? Colors.orange : Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // XP Reward Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: neoBlack, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: neoBlack,
                        offset: const Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    '+${challenge.xpReward} XP',
                    style: robotoBold.copyWith(fontSize: 13, color: neoBlack),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Title
            Text(
              challenge.title,
              style: robotoBold.copyWith(fontSize: 17, color: neoBlack),
            ),
            const SizedBox(height: 4),

            // Description
            Text(
              challenge.description,
              style: robotoRegular.copyWith(fontSize: 13, color: textSecondary),
            ),

            const SizedBox(height: 18),

            // Progress Section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'progress'.tr,
                            style: robotoMedium.copyWith(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                          Text(
                            '${challenge.currentProgress}/${challenge.targetProgress}',
                            style: robotoBold.copyWith(
                              fontSize: 13,
                              color: neoBlack,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Neo-style Progress Bar
                      Stack(
                        children: [
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: neoBlack, width: 1.5),
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: challenge.progressPercentage.clamp(
                              0.05,
                              1.0,
                            ),
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color:
                                    challenge.isCompleted
                                        ? Colors.green
                                        : accentColor,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: neoBlack, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Action Button
                _buildActionButton(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (challenge.isClaimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
            const SizedBox(width: 4),
            Text(
              'claimed'.tr,
              style: robotoBold.copyWith(
                color: Colors.green.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (challenge.canClaim) {
      return GestureDetector(
        onTap: isLoading ? null : onClaim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: neoBlack, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: neoBlack,
                offset: const Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child:
              isLoading
                  ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(neoBlack),
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: neoBlack),
                      const SizedBox(width: 4),
                      Text(
                        'claim'.tr,
                        style: robotoBold.copyWith(
                          color: neoBlack,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
        ),
      );
    }

    // In Progress
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: neoBlack, width: 1.5),
      ),
      child: Text(
        'in_progress'.tr,
        style: robotoMedium.copyWith(color: textSecondary, fontSize: 13),
      ),
    );
  }
}
