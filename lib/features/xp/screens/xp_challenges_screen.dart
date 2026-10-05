import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:waddy_app/common/widgets/spots/spots_l10n.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/screens/level_up_screen.dart';
import 'package:waddy_app/features/xp/widgets/streak_rive_badge.dart';
import 'package:waddy_app/features/xp/widgets/xp_motion.dart';
import 'package:waddy_app/features/xp/widgets/xp_tokens.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';

/// ─── WADDI XP — Quests ────────────────────────────────────────────────────────
/// A dark deep-teal "Quests" screen: a streak card, then Daily and Weekly quest
/// sections, each with its countdown. Every quest is a compact card — emoji,
/// title, an XP-reward chip that becomes a claim button and then "✓ claimed",
/// a progress track, and a "N of M" / status line.
///
/// Claiming is the payoff of the whole loop, so it is treated as one (X-30):
/// the card stays and flips to claimed, the XP floats up off it, and a level-up
/// the claim caused plays on the spot.
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
      // Revalidate rather than serve the session cache: progress moves with
      // every delivered order. Streak lives on the level payload.
      xp.getChallenges(reload: true);
      xp.getLevelDetails(reload: true);
    });
    // Live countdown — tick each minute.
    _countdown = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final xp = Get.find<XpController>();
    await Future.wait([
      xp.getChallenges(reload: true),
      xp.getLevelDetails(reload: true),
    ]);
  }

  Future<void> _claim(Challenge c) async {
    final xp = Get.find<XpController>();
    final ok = await xp.claimChallenge(c.id);
    if (!ok || !mounted) return;
    // The claim refetched the level payload; if it crossed a level, celebrate
    // now rather than whenever the XP tab is next opened.
    await LevelUpScreen.showQueue(xp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XpTokens.panel,
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
                  if (model == null) {
                    if (xp.challengesFailed && !xp.isChallengesLoading) {
                      return _ErrorState(onRetry: _refresh);
                    }
                    return const Center(
                      child: CircularProgressIndicator(color: XpTokens.mint),
                    );
                  }

                  return RefreshIndicator(
                    color: XpTokens.mint,
                    backgroundColor: XpTokens.panel,
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        Dimensions.paddingSizeDefault,
                        Dimensions.paddingSizeExtraSmall,
                        Dimensions.paddingSizeDefault,
                        MediaQuery.of(context).padding.bottom + 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: Dimensions.paddingSizeDefault),
                          GetBuilder<XpController>(
                            id: XpController.idLevel,
                            builder:
                                (xp) => _StreakCard(
                                  days: xp.streak?.currentStreak ?? 0,
                                ),
                          ),
                          _QuestSection(
                            label: 'xp_daily_quests'.tr,
                            weekly: false,
                            quests: model.dailyChallenges,
                            emptyText: 'check_back_tomorrow'.tr,
                            xp: xp,
                            onClaim: _claim,
                          ),
                          _QuestSection(
                            label: 'xp_weekly_quests'.tr,
                            weekly: true,
                            quests: model.weeklyChallenges,
                            emptyText: 'check_back_next_week'.tr,
                            xp: xp,
                            onClaim: _claim,
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
}

/// "Resets in 8h 12m" / "Resets Monday", from a quest's real deadline.
///
/// This used to read model-level reset keys the server never sends, so it was
/// always blank (X-29). The daily quest is a rolling window from assignment,
/// so its own `expires_at` is the true countdown.
String? _resetPhrase(DateTime? deadline, {required bool weekly}) {
  if (deadline == null) return null;
  final left = deadline.difference(DateTime.now());
  if (left.isNegative) return 'xp_resetting_now'.tr;
  if (weekly && left.inHours >= 24) {
    return 'xp_resets_on'.trParams({
      'day': DateFormat.EEEE(Get.locale?.toString()).format(deadline),
    });
  }
  if (left.inHours >= 24) {
    return 'xp_resets_in_days'.trParams({'days': fmtCount(left.inDays)});
  }
  final h = left.inHours;
  final m = left.inMinutes % 60;
  return h > 0
      ? 'xp_resets_in_hm'.trParams({
        'hours': fmtCount(h),
        'minutes': fmtCount(m),
      })
      : 'xp_resets_in_m'.trParams({'minutes': fmtCount(m)});
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — kicker, title, a quiet back affordance
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        14,
        Dimensions.paddingSizeDefault,
        10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: MaterialLocalizations.of(context).backButtonTooltip,
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                width: Dimensions.minTapTarget,
                height: Dimensions.minTapTarget,
                margin: const EdgeInsetsDirectional.only(
                  end: Dimensions.paddingSizeMedium,
                ),
                decoration: BoxDecoration(
                  color: XpTokens.overlay(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: XpTokens.overlay(0.2), width: 1.5),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayCaps('xp_whats_next'.tr),
                  style: waddyBlack.copyWith(
                    fontSize: 10,
                    color: XpTokens.onDarkMed,
                    letterSpacing: displayTracking(0.1 * 10),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayCaps('xp_quests_title'.tr),
                  style: waddyBlack.copyWith(
                    fontSize: 22,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'xp_quests_subtitle'.tr,
                  style: waddyBold.copyWith(
                    fontSize: 11,
                    color: XpTokens.onDarkMed,
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
    // The streak is only drawn alive when it is (X-17): a broken one reads
    // as "start one", not as a days count that no longer exists.
    final alive = days > 0;
    return Container(
      decoration: BoxDecoration(
        color: XpTokens.overlay(0.06),
        border: Border.all(
          color: alive ? XpTokens.coral : XpTokens.overlay(0.28),
          width: 2.5,
        ),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeMedium,
      ),
      child: Row(
        children: [
          // The same live flame as the XP home hero (X-43) — the one loop
          // on this screen. A broken streak keeps the dim, still emoji.
          if (alive)
            SizedBox(
              width: 44,
              height: 44,
              child: IgnorePointer(child: StreakRiveBadge(streak: days)),
            )
          else
            const Opacity(
              opacity: 0.45,
              child: Text('🔥', style: TextStyle(fontSize: 26)),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayCaps(
                    alive
                        ? 'xp_streak_title'.trParams({'count': fmtCount(days)})
                        : 'xp_streak_none'.tr,
                  ),
                  style: waddyBlack.copyWith(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'xp_streak_hint'.tr,
                  style: waddyBold.copyWith(
                    fontSize: 11,
                    color: alive ? XpTokens.coral : XpTokens.mint,
                    height: 1.2,
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
// QUEST SECTION — header row (label + countdown) then quest cards
// ─────────────────────────────────────────────────────────────────────────────
class _QuestSection extends StatelessWidget {
  final String label;
  final bool weekly;
  final List<Challenge> quests;
  final String emptyText;
  final XpController xp;
  final Future<void> Function(Challenge) onClaim;

  const _QuestSection({
    required this.label,
    required this.weekly,
    required this.quests,
    required this.emptyText,
    required this.xp,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    // Count down to the nearest live quest's deadline.
    final deadlines =
        quests
            .where((q) => q.isActive)
            .map((q) => q.expiresAt)
            .whereType<DateTime>()
            .toList()
          ..sort();
    final reset =
        deadlines.isEmpty
            ? null
            : _resetPhrase(deadlines.first, weekly: weekly);
    final visible = quests.where((q) => !q.isExpired || q.isCompleted).toList();

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
                  displayCaps(label),
                  style: waddyBlack.copyWith(
                    fontSize: 11,
                    color: Colors.white,
                    letterSpacing: displayTracking(0.08 * 11),
                    height: 1,
                  ),
                ),
              ),
              if (reset != null)
                Text(
                  displayCaps(reset),
                  style: waddyBold.copyWith(
                    fontSize: 10,
                    color: XpTokens.onDarkFaint,
                    height: 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            _EmptyQuest(text: emptyText)
          else
            ...visible.map(
              (q) => Padding(
                padding: const EdgeInsets.only(
                  bottom: Dimensions.paddingSizeSmall,
                ),
                child: _QuestCard(
                  key: ValueKey('quest-${q.id}'),
                  challenge: q,
                  claiming: xp.isClaimingChallengeId(q.id),
                  onClaim: q.canClaim ? () => onClaim(q) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUEST CARD
// ─────────────────────────────────────────────────────────────────────────────
class _QuestCard extends StatefulWidget {
  final Challenge challenge;
  final bool claiming;
  final VoidCallback? onClaim;

  const _QuestCard({
    super.key,
    required this.challenge,
    required this.claiming,
    this.onClaim,
  });

  @override
  State<_QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<_QuestCard>
    with SingleTickerProviderStateMixin {
  /// The "+N XP" that floats off the card when its claim lands.
  late final AnimationController _flyUp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didUpdateWidget(covariant _QuestCard old) {
    super.didUpdateWidget(old);
    if (!old.challenge.isClaimed && widget.challenge.isClaimed) {
      _flyUp.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flyUp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final done = challenge.isCompleted; // completed or claimed
    final claimed = challenge.isClaimed;
    final canClaim = challenge.canClaim;
    final pct = challenge.progressPercentage.clamp(0.0, 1.0);
    final emoji =
        (challenge.icon != null && challenge.icon!.isNotEmpty)
            ? challenge.icon!
            : _fallbackEmoji(challenge);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color:
            done
                ? XpTokens.mint.withValues(alpha: 0.08)
                : XpTokens.overlay(0.06),
        border: Border.all(
          color: done ? XpTokens.mint : XpTokens.overlay(0.28),
          width: 2.5,
        ),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Known quest types get the animated icon, which plays on reveal
              // and again when the quest completes or is claimed (XM-05).
              // Unknown types keep the backend's emoji.
              if (XpIcon.forChallengeType(challenge.challengeType)
                  case final XpIcon motion)
                XpRiveIcon(
                  icon: motion,
                  size: 30,
                  fallbackColor: XpTokens.mint,
                  playWhen: challenge.status,
                )
              else
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
                claiming: widget.claiming,
                onClaim: widget.onClaim,
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
            child: Stack(
              children: [
                Container(height: 9, color: XpTokens.overlay(0.14)),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 400),
                  widthFactor: done ? 1.0 : pct,
                  child: Container(
                    height: 9,
                    color: done ? XpTokens.mint : XpTokens.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  _progressLabel(challenge),
                  style: waddyBold.copyWith(
                    fontSize: 10,
                    color: XpTokens.onDarkMed,
                    height: 1,
                  ),
                ),
              ),
              Text(
                displayCaps(_statusLabel(challenge)),
                style: waddyBlack.copyWith(
                  fontSize: 10,
                  color: done ? XpTokens.mint : XpTokens.onDarkMed,
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
    final tappable =
        canClaim && widget.onClaim != null && !widget.claiming
            ? GestureDetector(onTap: widget.onClaim, child: card)
            : card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        tappable,
        PositionedDirectional(
          end: Dimensions.paddingSizeMedium,
          top: 0,
          child: IgnorePointer(child: _flyUpLabel(challenge.xpReward)),
        ),
      ],
    );
  }

  Widget _flyUpLabel(int xp) {
    return AnimatedBuilder(
      animation: _flyUp,
      builder: (context, _) {
        final t = _flyUp.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        final reduce = MediaQuery.of(context).disableAnimations;
        final rise = reduce ? 0.0 : Curves.easeOutCubic.transform(t) * 42;
        final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
        return Transform.translate(
          offset: Offset(0, -rise),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeSmall,
                vertical: Dimensions.paddingSizeExtraSmall,
              ),
              decoration: BoxDecoration(
                color: XpTokens.mint,
                border: Border.all(color: XpTokens.teal, width: 2),
                borderRadius: BorderRadius.circular(XpTokens.rSm),
              ),
              child: Text(
                'xp_plus_amount'.trParams({'xp': fmtCount(xp)}),
                style: waddyBlack.copyWith(
                  fontSize: 13,
                  color: XpTokens.teal,
                  height: 1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// "2 of 3", or for a spend quest "EGP 150 of EGP 250" — a bare "150 of
  /// 250" never said what was being counted.
  String _progressLabel(Challenge c) {
    if (c.isBinaryChallenge) {
      return 'xp_progress_of'.trParams({
        'current': fmtCount(c.isCompleted ? 1 : c.currentProgress),
        'target': fmtCount(1),
      });
    }
    if (c.challengeType == 'min_order_amount') {
      return 'xp_progress_of'.trParams({
        'current': PriceConverter.convertPrice(c.currentProgress.toDouble()),
        'target': PriceConverter.convertPrice(c.targetProgress.toDouble()),
      });
    }
    return 'xp_progress_of'.trParams({
      'current': fmtCount(c.currentProgress),
      'target': fmtCount(c.targetProgress),
    });
  }

  String _statusLabel(Challenge c) {
    if (c.isClaimed) return 'xp_challenge_claimed'.tr;
    if (c.canClaim) return 'xp_challenge_claimable'.tr;
    if (c.isCompleted) return 'xp_challenge_complete'.tr;
    return 'xp_challenge_in_progress'.tr;
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
// REWARD CHIP — "+N XP" / claim button / "✓ claimed"
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
    if (claimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: XpTokens.mint, width: 2),
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
        ),
        child: Text(
          '✓ ${displayCaps('xp_challenge_claimed'.tr)}',
          style: waddyBlack.copyWith(
            fontSize: 10.5,
            color: XpTokens.mint,
            height: 1,
          ),
        ),
      );
    }

    if (canClaim) {
      return Semantics(
        button: true,
        child: GestureDetector(
          onTap: claiming ? null : onClaim,
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeSmall,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: XpTokens.mint,
              borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
              border: Border.all(color: XpTokens.teal, width: 2),
            ),
            alignment: Alignment.center,
            child:
                claiming
                    ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(XpTokens.teal),
                      ),
                    )
                    : Text(
                      displayCaps(
                        'xp_claim_reward'.trParams({'xp': fmtCount(xp)}),
                      ),
                      style: waddyBlack.copyWith(
                        fontSize: 10.5,
                        color: XpTokens.teal,
                        height: 1,
                      ),
                    ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
        vertical: Dimensions.paddingSizeExtraSmall,
      ),
      decoration: BoxDecoration(
        color: XpTokens.mint,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
      child: Text(
        'xp_plus_amount'.trParams({'xp': fmtCount(xp)}),
        style: waddyBlack.copyWith(
          fontSize: 10.5,
          color: XpTokens.teal,
          height: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY + ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyQuest extends StatelessWidget {
  final String text;
  const _EmptyQuest({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: XpTokens.overlay(0.06),
        border: Border.all(color: XpTokens.overlay(0.28), width: 2.5),
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
            'xp_all_done'.tr,
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
              color: XpTokens.onDarkMed,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// A failed load is not "all done" (X-13).
class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📡', style: TextStyle(fontSize: 30)),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(
              'failed_to_load'.tr,
              textAlign: TextAlign.center,
              style: waddyBlack.copyWith(fontSize: 14, color: Colors.white),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: XpTokens.mint,
                foregroundColor: XpTokens.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeLarge,
                  vertical: Dimensions.paddingSizeSmall,
                ),
              ),
              child: Text(
                'retry'.tr,
                style: waddyBlack.copyWith(fontSize: 13, color: XpTokens.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
