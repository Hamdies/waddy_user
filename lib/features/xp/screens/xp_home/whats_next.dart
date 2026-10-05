part of '../xp_levels_screen.dart';

// The order CTA and "What's next": the next quest and the next reward.

// ─────────────────────────────────────────────────────────────────────────────
// ORDER CTA — the way out of this screen and into the product
// ─────────────────────────────────────────────────────────────────────────────
/// The screen's primary action.
///
/// This slot used to hold a 10-segment tier meter that restated the hero's own
/// "46/200" as "154 XP TO CHILLING" — the same fact, twice, 40pt apart. The
/// progress now lives once in the hero, and the space it freed goes to the
/// thing the screen never had: a route into ordering.
///
/// Every XP on this page is earned by ordering food, and until now nothing here
/// could start an order. When a free delivery is banked the label says so,
/// which is a claim the checkout actually honours — `checkout_calculation_helper`
/// zeroes the delivery charge for a selected XP prize.
class _OrderCta extends StatelessWidget {
  const _OrderCta();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      id: XpController.idPrizes,
      builder: (xp) {
        final hasFreeDelivery = (xp.prizeModel?.livePrizes ?? const []).any(
          (p) => p.kind == PrizeKind.freeDelivery,
        );
        final label =
            hasFreeDelivery
                ? 'xp_order_with_free_delivery'.tr
                : 'xp_order_now'.tr;

        return Padding(
          padding: const EdgeInsets.only(top: Dimensions.paddingSizeDefault),
          child: Pressable(
            semanticLabel: label,
            minSize: Dimensions.minTapTarget,
            onTap: () => RouteHelper.goToTab(RouteHelper.tabHome),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeMedium,
                horizontal: Dimensions.paddingSizeDefault,
              ),
              decoration: BoxDecoration(
                color: _Xp.mint,
                borderRadius: BorderRadius.circular(_Xp.rMd),
                border: Border.all(color: _Xp.teal, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasFreeDelivery
                        ? Icons.local_shipping_outlined
                        : Icons.storefront_outlined,
                    size: 18,
                    color: _Xp.teal,
                  ),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Flexible(
                    child: Text(
                      displayCaps(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: waddyBlack.copyWith(
                        fontSize: 13,
                        color: _Xp.teal,
                        height: 1,
                        letterSpacing: displayTracking(0.02 * 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WHAT'S NEXT — weekly challenge tile + next reward tile
// ─────────────────────────────────────────────────────────────────────────────
class _WhatsNextSection extends StatelessWidget {
  const _WhatsNextSection();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      id: XpController.idChallenges,
      builder: (xp) {
        // A finished quest waiting on its claim first: it is the one thing on
        // the page that pays out right now, and it used to lose to a quest at
        // 1/3 (X-36). Then an in-progress one, weekly before daily.
        final all = <Challenge>[
          ...?xp.challengeModel?.weeklyChallenges,
          ...?xp.challengeModel?.dailyChallenges,
        ];
        final challenge =
            all.firstWhereOrNull((c) => c.canClaim) ??
            all.firstWhereOrNull((c) => c.isActive) ??
            (all.isNotEmpty ? all.first : null);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              kicker: 'xp_momentum_kicker'.tr,
              title: 'xp_whats_next'.tr,
            ),
            const SizedBox(height: _Xp.sMd),
            if (challenge != null)
              _ChallengeTile(
                challenge: challenge,
                // The challenge's own deadline. The model-level reset times
                // are keys the server never sends (X-29).
                resetTime:
                    challenge.expiresAt ??
                    (challenge.type == 'weekly'
                        ? xp.challengeModel?.weeklyResetTime
                        : xp.challengeModel?.dailyResetTime),
              )
            else
              _EmptyTile(emoji: '🎯', text: 'xp_no_challenges'.tr),
            // The next reward comes from the level payload, and this section
            // listens to `idChallenges`, so it gets its own builder (X-35).
            GetBuilder<XpController>(
              id: XpController.idLevel,
              builder: (xp) {
                final reward = xp.nextReward;
                if (reward == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: _Xp.sSm),
                  child: _RewardTile(
                    reward: reward,
                    level: xp.nextRewardLevel,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  final Challenge challenge;
  final DateTime? resetTime;
  const _ChallengeTile({required this.challenge, this.resetTime});

  /// True when this challenge resets within the next 6 hours — genuine time
  /// pressure that earns the coral urgency color on its meta line.
  bool get _resetsSoon {
    final t = resetTime;
    if (t == null || challenge.isClaimed) return false;
    final left = t.difference(DateTime.now());
    return !left.isNegative && left.inHours < 6;
  }

  @override
  Widget build(BuildContext context) {
    final pct = challenge.progressPercentage;
    final meta = _metaLine(challenge);
    // Claimable = a positive prompt (mint); resetting soon = urgency (coral);
    // otherwise the quiet faint grey.
    final Color metaColor =
        challenge.canClaim && !challenge.isClaimed
            ? _Xp.mint
            : _resetsSoon
            ? _Xp.coral
            : _Xp.onDarkFaint;

    return GestureDetector(
      onTap: () => _openChallenge(challenge),
      child: _DarkTile(
        interactive: true,
        padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  challenge.icon?.isNotEmpty == true ? challenge.icon! : '🎯',
                  style: const TextStyle(fontSize: 20),
                ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeSmall,
                    vertical: Dimensions.paddingSizeExtraSmall,
                  ),
                  decoration: BoxDecoration(
                    color: _Xp.mint,
                    borderRadius: BorderRadius.circular(_Xp.rSm),
                  ),
                  child: Text(
                    '+${challenge.xpReward} XP',
                    style: waddyBlack.copyWith(
                      fontSize: 10.5,
                      color: _Xp.teal,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
              child: Stack(
                children: [
                  Container(height: 9, color: _Xp.overlay(0.14)),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(height: 9, color: _Xp.green),
                  ),
                ],
              ),
            ),
            if (meta != null) ...[
              const SizedBox(height: 7),
              Text(
                meta,
                style: waddyBold.copyWith(
                  fontSize: 10,
                  color: metaColor,
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _metaLine(Challenge c) {
    final unit = _resetPhrase(c);
    if (c.isClaimed) return 'xp_challenge_claimed'.tr;
    if (c.canClaim) return 'xp_challenge_claimable'.tr;
    if (c.targetProgress > 1) {
      final progress = 'xp_progress_of'.trParams({
        'current': fmtCount(c.currentProgress),
        'target': fmtCount(c.targetProgress),
      });
      return unit != null ? '$progress — $unit' : progress;
    }
    // The description is only worth showing when it says something the title
    // did not. Backends routinely send "Order Launch today" as the title and
    // "Order Launch today from X" as the description, which rendered as the
    // same sentence twice in one tile.
    // When the challenge is pinned to a store, naming it beats any generic
    // description — it is the fact that decides where the user has to go.
    final store = _targetStoreName(c);
    if (store != null) {
      return unit != null
          ? '${'xp_challenge_at_store'.trParams({'store': store})} — $unit'
          : 'xp_challenge_at_store'.trParams({'store': store});
    }

    final desc = c.description.trim();
    if (desc.isNotEmpty && !_echoesTitle(desc, c.title)) return desc;
    return unit ?? '';
  }

  /// True when [description] adds nothing over [title] — one contains the
  /// other, ignoring case and trailing punctuation.
  bool _echoesTitle(String description, String title) {
    final t = title.trim().toLowerCase();
    if (t.isEmpty) return false;
    final d = description.toLowerCase();
    return d.contains(t) || t.contains(d);
  }

  /// Where a challenge should take you.
  ///
  /// Every challenge on this screen is completed by *ordering*, so the default
  /// destination is the food feed rather than another XP screen — tapping
  /// "Order Launch today · +50 XP" used to open a list of challenges, which is
  /// the one thing it cannot help you do.
  ///
  /// When the challenge names a target store, this routes straight to it —
  /// admin sets that per challenge and the server refuses to credit progress
  /// from any other store, so "order from X" and where the tap lands agree.
  /// `new_store` never carries one: it is satisfied by anywhere the user has
  /// NOT ordered before, so a fixed target would contradict the rule.
  void _openChallenge(Challenge c) {
    final storeId = _targetStoreId(c);
    if (storeId != null) {
      StoreNavigator.open(Store(id: storeId));
      return;
    }
    if (c.canClaim && !c.isClaimed) {
      // The one case where the challenge screen IS the right destination:
      // there is XP waiting to be claimed there.
      Get.toNamed(RouteHelper.xpChallenges);
      return;
    }
    RouteHelper.goToTab(RouteHelper.tabHome);
  }

  /// Display name for the pinned store, sent alongside `store_id`.
  String? _targetStoreName(Challenge c) {
    final raw = c.conditions?['store_name'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  int? _targetStoreId(Challenge c) {
    final conditions = c.conditions;
    if (conditions == null) return null;
    for (final key in const ['store_id', 'store', 'target_store_id']) {
      final raw = conditions[key];
      if (raw is int && raw > 0) return raw;
      if (raw is String) {
        final parsed = int.tryParse(raw);
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return null;
  }

  /// Human "resets in Xh Ym" / "resets <Weekday>" from the real reset time —
  /// no hardcoded "Monday"/"tonight". Null when the server didn't send one.
  String? _resetPhrase(Challenge c) {
    final t = resetTime;
    if (t == null) return null;
    final left = t.difference(DateTime.now());
    if (left.isNegative) return 'xp_resetting_now'.tr;

    if (c.type == 'weekly') {
      // Weekday names came from a hardcoded English list, so an Arabic user
      // read "resets Monday". `DateFormat.EEEE` resolves them per locale.
      final weekday = DateFormat.EEEE(Get.locale?.toString()).format(t);
      return 'xp_resets_on'.trParams({'day': weekday});
    }
    // Daily: show the remaining time.
    final h = left.inHours;
    final m = left.inMinutes % 60;
    if (h >= 24) {
      return 'xp_resets_in_days'.trParams({'days': fmtCount(left.inDays)});
    }
    return h > 0
        ? 'xp_resets_in_hm'.trParams({
          'hours': fmtCount(h),
          'minutes': fmtCount(m),
        })
        : 'xp_resets_in_m'.trParams({'minutes': fmtCount(m)});
  }
}

class _RewardTile extends StatelessWidget {
  final LevelPrize reward;
  final int? level;
  const _RewardTile({required this.reward, required this.level});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(RouteHelper.xpPrizes),
      child: _DarkTile(
        interactive: true,
        padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
        child: Row(
          children: [
            // A gold-tinted, type-specific glyph badged with a small lock —
            // this is the *next* (still-locked) achievement, so it reads as a
            // prize you're working toward rather than a generic padlock.
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _Xp.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(_Xp.rMd),
                    ),
                    alignment: Alignment.center,
                    // The gift, played once on reveal (XM-03).
                    child: XpRiveIcon(
                      icon: XpIcon.gift,
                      size: 38,
                      fallback: reward.kind.icon,
                      fallbackColor: _Xp.gold,
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _Xp.foil,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                        border: Border.all(
                          color: _Xp.overlay(0.28),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 10,
                        color: _Xp.onDarkMed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayCaps(
                      level != null
                          ? 'xp_next_reward_level'.trParams({'level': '$level'})
                          : 'xp_next_reward'.tr,
                    ),
                    style: waddyBlack.copyWith(
                      fontSize: 9,
                      color: _Xp.mint,
                      letterSpacing: displayTracking(0.08 * 9),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reward.title.isNotEmpty
                        ? reward.title
                        : 'xp_reward_fallback'.tr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: waddyBlack.copyWith(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
