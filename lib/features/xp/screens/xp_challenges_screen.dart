import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';

/// ─── WADDI XP — Quests ────────────────────────────────────────────────────────
/// Native port of Challenges.dc.html: a dark deep-teal "Quests" screen with a
/// streak card, then Daily and Weekly quest sections (shown together, each with
/// its own reset countdown). Every quest is a compact card — emoji, title, an
/// XP-reward chip that flips to "✓ CLAIMED", a progress track (green in
/// progress, mint when complete), and a "N of M" / status line. Claiming is
/// wired to the real backend via [XpController.claimChallenge].
class XpChallengesScreen extends StatefulWidget {
  const XpChallengesScreen({super.key});

  @override
  State<XpChallengesScreen> createState() => _XpChallengesScreenState();
}

class _XpChallengesScreenState extends State<XpChallengesScreen> {
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final xp = Get.find<XpController>();
      xp.getChallenges();
      // Streak lives on the level-details payload; ensure it's loaded so the
      // streak card is real even when this screen is opened directly.
      xp.getLevelDetails();
    });
    // Live reset countdown — tick each minute.
    _countdown = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _refresh() =>
      Get.find<XpController>().getChallenges(reload: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Q.panel,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            Expanded(
              child: GetBuilder<XpController>(
                id: XpController.idChallenges,
                builder: (xp) {
                  final model = xp.challengeModel;
                  if (xp.isChallengesLoading && model == null) {
                    return const Center(
                      child: CircularProgressIndicator(color: _Q.mint),
                    );
                  }

                  final daily = model?.dailyChallenges ?? [];
                  final weekly = model?.weeklyChallenges ?? [];
                  final streak = xp.streak?.currentStreak ?? 0;

                  return RefreshIndicator(
                    color: _Q.mint,
                    backgroundColor: _Q.panel,
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        MediaQuery.of(context).padding.bottom + 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _StreakCard(days: streak),
                          _QuestSection(
                            label: 'Daily quests',
                            resetLabel: _dailyResetLabel(model?.dailyResetTime),
                            quests: daily,
                            emptyText: 'check_back_tomorrow'.tr,
                            xp: xp,
                          ),
                          _QuestSection(
                            label: 'Weekly quests',
                            resetLabel: _weeklyResetLabel(
                              model?.weeklyResetTime,
                            ),
                            quests: weekly,
                            emptyText: 'check_back_next_week'.tr,
                            xp: xp,
                          ),
                        ],
                      ),
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

  /// "8h 12m" style remaining-time label for the daily reset.
  String _dailyResetLabel(DateTime? resetTime) {
    if (resetTime == null) return '—';
    final left = resetTime.difference(DateTime.now());
    if (left.isNegative) return 'soon';
    final h = left.inHours;
    final m = left.inMinutes % 60;
    if (h >= 24) {
      final d = left.inDays;
      final hh = left.inHours % 24;
      return hh > 0 ? '${d}d ${hh}h' : '${d}d';
    }
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  /// The weekday the weekly quests reset on (e.g. "Monday").
  String _weeklyResetLabel(DateTime? resetTime) {
    if (resetTime == null) return '—';
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[(resetTime.weekday - 1).clamp(0, 6)];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME (matches the XP design tokens)
// ─────────────────────────────────────────────────────────────────────────────
class _Q {
  _Q._();
  static const Color mint = Color(0xFF1EF2A0);
  static const Color teal = Color(0xFF134E4A);
  static const Color panel = Color(0xFF0E3532);
  static const Color border = Color(0xFF134E4A);
  static const Color green = Color(0xFF22C55E);

  static Color get onMed => Colors.white.withValues(alpha: 0.5);
  static Color get faint => Colors.white.withValues(alpha: 0.45);
  static Color get tileFill => Colors.white.withValues(alpha: 0.06);
  static Color get tileBorder => Colors.white.withValues(alpha: 0.28);
  static Color get track => Colors.white.withValues(alpha: 0.14);
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — "WHAT'S NEXT / QUESTS" + a quiet back affordance
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(
                top: 2,
                right: Dimensions.paddingSizeMedium,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHAT\'S NEXT',
                  style: waddyBlack.copyWith(
                    fontSize: 10,
                    color: _Q.onMed,
                    letterSpacing: 0.1 * 10,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'QUESTS',
                  style: waddyBlack.copyWith(
                    fontSize: 22,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Play at your pace — new quests roll in daily and weekly',
                  style: waddyBold.copyWith(
                    fontSize: 11,
                    color: _Q.onMed,
                    height: 1.3,
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

// ─────────────────────────────────────────────────────────────────────────────
// STREAK CARD
// ─────────────────────────────────────────────────────────────────────────────
class _StreakCard extends StatelessWidget {
  final int days;
  const _StreakCard({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Q.tileFill,
        border: Border.all(color: _Q.tileBorder, width: 2.5),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeMedium,
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$days ${days == 1 ? 'DAY' : 'DAYS'} STREAK',
                  style: waddyBlack.copyWith(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ONE ORDER A DAY KEEPS IT ALIVE',
                  style: waddyBold.copyWith(
                    fontSize: 10,
                    color: _Q.mint,
                    letterSpacing: 0.03 * 10,
                    height: 1,
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

// ─────────────────────────────────────────────────────────────────────────────
// QUEST SECTION — header row (label + reset) then quest cards
// ─────────────────────────────────────────────────────────────────────────────
class _QuestSection extends StatelessWidget {
  final String label;
  final String resetLabel;
  final List<Challenge> quests;
  final String emptyText;
  final XpController xp;

  const _QuestSection({
    required this.label,
    required this.resetLabel,
    required this.quests,
    required this.emptyText,
    required this.xp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Dimensions.paddingSizeLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: waddyBlack.copyWith(
                    fontSize: 11,
                    color: Colors.white,
                    letterSpacing: 0.08 * 11,
                    height: 1,
                  ),
                ),
              ),
              Text(
                _resetText(label, resetLabel),
                style: waddyBold.copyWith(
                  fontSize: 9.5,
                  color: _Q.faint,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (quests.isEmpty)
            _EmptyQuest(text: emptyText)
          else
            ...quests.map(
              (q) => Padding(
                padding: const EdgeInsets.only(
                  bottom: Dimensions.paddingSizeSmall,
                ),
                child: _QuestCard(
                  challenge: q,
                  claiming: xp.isClaimingChallengeId(q.id),
                  onClaim: q.canClaim ? () => xp.claimChallenge(q.id) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _resetText(String label, String reset) {
    // Daily shows "RESETS IN 8h 12m"; weekly shows "RESETS MONDAY".
    final isDaily = label.toLowerCase().startsWith('daily');
    if (reset == '—') return '';
    return isDaily
        ? 'RESETS IN ${reset.toUpperCase()}'
        : 'RESETS ${reset.toUpperCase()}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUEST CARD
// ─────────────────────────────────────────────────────────────────────────────
class _QuestCard extends StatelessWidget {
  final Challenge challenge;
  final bool claiming;
  final VoidCallback? onClaim;

  const _QuestCard({
    required this.challenge,
    required this.claiming,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final done = challenge.isCompleted; // completed or claimed
    final claimed = challenge.isClaimed;
    final canClaim = challenge.canClaim;
    final pct = challenge.progressPercentage.clamp(0.0, 1.0);
    final emoji =
        (challenge.icon != null && challenge.icon!.isNotEmpty)
            ? challenge.icon!
            : _fallbackEmoji(challenge);

    final card = Container(
      decoration: BoxDecoration(
        color: done ? _Q.mint.withValues(alpha: 0.08) : _Q.tileFill,
        border: Border.all(color: done ? _Q.mint : _Q.tileBorder, width: 2.5),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: emoji · title · reward chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  challenge.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBlack.copyWith(
                    fontSize: 13,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _RewardChip(
                xp: challenge.xpReward,
                claimed: claimed,
                canClaim: canClaim,
                claiming: claiming,
                onClaim: onClaim,
              ),
            ],
          ),
          const SizedBox(height: 11),
          // Progress track
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
            child: Stack(
              children: [
                Container(height: 9, color: _Q.track),
                FractionallySizedBox(
                  widthFactor: done ? 1.0 : pct,
                  child: Container(height: 9, color: done ? _Q.mint : _Q.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          // Meta: N of M · status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${challenge.currentProgress} of ${challenge.targetProgress}',
                style: waddyBold.copyWith(
                  fontSize: 10,
                  color: _Q.onMed,
                  height: 1,
                ),
              ),
              Text(
                _statusLabel(challenge),
                style: waddyBlack.copyWith(
                  fontSize: 10,
                  color: done ? _Q.mint : _Q.onMed,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Tapping a claimable card claims it too (the chip is small); otherwise
    // the whole card is inert so an in-progress quest doesn't feel tappable.
    if (canClaim && onClaim != null && !claiming) {
      return GestureDetector(onTap: onClaim, child: card);
    }
    return card;
  }

  String _statusLabel(Challenge c) {
    if (c.isClaimed) return 'CLAIMED';
    if (c.canClaim) return 'READY TO CLAIM';
    if (c.isCompleted) return 'COMPLETE';
    return 'IN PROGRESS';
  }

  String _fallbackEmoji(Challenge c) {
    switch (c.challengeType) {
      case 'multiple_orders':
        return '🎯';
      case 'min_order_amount':
        return '💰';
      case 'new_store':
        return '🗺️';
      case 'complete_order':
      default:
        return '🍔';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REWARD CHIP — "+N XP" / claim button / "✓ CLAIMED"
// ─────────────────────────────────────────────────────────────────────────────
class _RewardChip extends StatelessWidget {
  final int xp;
  final bool claimed;
  final bool canClaim;
  final bool claiming;
  final VoidCallback? onClaim;

  const _RewardChip({
    required this.xp,
    required this.claimed,
    required this.canClaim,
    required this.claiming,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    // Claimed — outlined mint tag.
    if (claimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: _Q.mint, width: 2),
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
        ),
        child: Text(
          '✓ CLAIMED',
          style: waddyBlack.copyWith(fontSize: 10.5, color: _Q.mint, height: 1),
        ),
      );
    }

    // Ready to claim — solid mint button that claims on tap.
    if (canClaim) {
      return GestureDetector(
        onTap: claiming ? null : onClaim,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeSmall,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _Q.mint,
            borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
            border: Border.all(color: _Q.border, width: 2),
          ),
          child:
              claiming
                  ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(_Q.teal),
                    ),
                  )
                  : Text(
                    'CLAIM +$xp',
                    style: waddyBlack.copyWith(
                      fontSize: 10.5,
                      color: _Q.teal,
                      height: 1,
                    ),
                  ),
        ),
      );
    }

    // In progress — plain mint reward chip.
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
        vertical: Dimensions.paddingSizeExtraSmall,
      ),
      decoration: BoxDecoration(
        color: _Q.mint,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
      child: Text(
        '+$xp XP',
        style: waddyBlack.copyWith(fontSize: 10.5, color: _Q.teal, height: 1),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyQuest extends StatelessWidget {
  final String text;
  const _EmptyQuest({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _Q.tileFill,
        border: Border.all(color: _Q.tileBorder, width: 2.5),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: 22,
      ),
      child: Column(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            'All done for now',
            style: waddyBlack.copyWith(
              fontSize: 13,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: waddyBold.copyWith(
              fontSize: 11,
              color: _Q.onMed,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
