part of '../xp_levels_screen.dart';

// The masthead and the foil hero card: identity, the reward wallet, progress and streak.

// ─────────────────────────────────────────────────────────────────────────────
// MASTHEAD — brand wordmark + tappable level chip
// ─────────────────────────────────────────────────────────────────────────────
class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      id: XpController.idLevel,
      builder: (xp) {
        final level = xp.currentLevel?.currentLevel ?? 1;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeMedium,
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeMedium,
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/image/waddy.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Row(
                children: [
                  Text(
                    'WADDI ',
                    style: waddyBlack.copyWith(
                      fontSize: 15,
                      color: Colors.white,
                      letterSpacing: displayTracking(0.03 * 15),
                      height: 1,
                    ),
                  ),
                  Text(
                    'XP',
                    style: waddyBlack.copyWith(
                      fontSize: 15,
                      color: _Xp.mint,
                      letterSpacing: displayTracking(0.03 * 15),
                      height: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Get.toNamed(RouteHelper.xpPrizes),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeSmall,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _Xp.mint,
                    border: Border.all(color: _Xp.border, width: 2.5),
                    borderRadius: BorderRadius.circular(_Xp.rSm + 1),
                  ),
                  child: Text(
                    displayCaps('xp_level_short'.trParams({'level': '$level'})),
                    style: waddyBlack.copyWith(
                      fontSize: 11,
                      color: _Xp.teal,
                      letterSpacing: displayTracking(0.05 * 11),
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOIL HERO CARD — the centrepiece
// ─────────────────────────────────────────────────────────────────────────────
class _FoilHeroCard extends StatelessWidget {
  final XpController xp;
  const _FoilHeroCard({required this.xp});

  @override
  Widget build(BuildContext context) {
    final data = xp.currentLevel;
    final level = data?.currentLevel ?? 1;
    final totalXp = data?.currentXp ?? 0;
    final isMax = data?.isMaxLevelFor(xp.maxLevel) ?? false;

    // Progress toward next level (the "tier" in the mock's language).
    final levels = xp.levelsListModel?.levels ?? [];
    final nextLevelData = levels.firstWhereOrNull((l) => l.level == level + 1);
    final xpTarget =
        nextLevelData?.xpRequired ?? data?.xpForNextLevel ?? (totalXp + 100);
    final xpCurrent = totalXp.clamp(0, xpTarget);
    final nextName = nextLevelData?.name ?? 'xp_next_level'.tr;

    // Live user identity for the hero: handle, rank, city.
    String handle = '@YOU';
    String? subMeta;
    if (AuthHelper.isLoggedIn()) {
      try {
        final me = Get.find<ProfileController>().userInfoModel;
        final name =
            [me?.fName, me?.lName]
                .whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .join(' ')
                .trim();
        if (name.isNotEmpty) {
          // `displayCaps` leaves Arabic untouched (it has no uppercase), and
          // the single-name '@handle' form is dropped entirely — it is an
          // English-web convention that rendered as "@أحمد" in Arabic.
          handle = displayCaps(name);
        }
      } catch (e, s) {
        swallow('format leaderboard handle', e, s);
      }
    }
    // Rank is deliberately absent. It used to sit here as a co-hero stat, but
    // "#18" on a screen meant to feel earned reads as "seventeen people are
    // ahead of you" — one more deficit meter on a page that already had three.
    // The leaderboard still exists on its own screen for anyone who wants it.
    final zoneName = data?.zoneName;
    subMeta =
        (zoneName != null && zoneName.isNotEmpty) ? displayCaps(zoneName) : '';

    final streak = xp.streak?.currentStreak ?? 0;
    // "Just earned" is only honest for a genuinely recent award. Use the
    // server's recent_earned (xp + seconds_ago); show the toast only inside a
    // short window so a week-old transaction never reads as "just earned".
    final recentXp = data?.recentEarnedXp ?? 0;
    final recentAgo = data?.recentEarnedSecondsAgo;
    final lastEarned =
        (recentXp > 0 && recentAgo != null && recentAgo <= 600) ? recentXp : 0;

    return Container(
      margin: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
      decoration: BoxDecoration(
        color: _Xp.foil,
        border: Border.all(color: _Xp.mint, width: 4),
        borderRadius: BorderRadius.circular(_Xp.rLg),
        boxShadow: _Xp.shadow(dx: 6, dy: 6, color: _Xp.mint),
      ),
      // NOT clipped: the streak flame is positioned to overhang the card's top
      // edge. With `Clip.antiAlias` here the parent cut it off, so the flame
      // read as a small badge stuck inside the corner rather than the intended
      // overhang — the inner Stack's `Clip.none` could not save it.
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Streak badge — a live Rive flame carrying the user's real streak.
          // Directional so it sits in the trailing corner under RTL too.
          PositionedDirectional(
            end: -10,
            top: -24,
            width: 110,
            height: 110,
            child: IgnorePointer(child: StreakRiveBadge(streak: streak)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tier ribbon

              // Medal / badge
              _HeroBadge(badge: data?.levelBadge, level: level),
              const SizedBox(height: 8),
              Text(
                handle,
                style: waddyBlack.copyWith(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              if (subMeta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subMeta,
                  textAlign: TextAlign.center,
                  style: waddyBold.copyWith(
                    fontSize: 10,
                    color: _Xp.onDarkMed,
                    height: 1.2,
                  ),
                ),
              ],
              const SizedBox(height: Dimensions.paddingSizeDefault),
              // The headline: what you can spend today. When the wallet is
              // empty this falls back to the single nearest reward, so the card
              // always answers "what do I get" rather than "how far behind am I".
              // Prizes are their own payload. This card is built under
              // `idLevel`, so without its own builder the count stayed stale
              // whenever prizes landed after the level (X-35).
              GetBuilder<XpController>(
                id: XpController.idPrizes,
                // What the user actually owns right now: an inventory of
                // things they can spend, not a count of things they cannot. A
                // claimed free delivery is as much "yours" as an unclaimed one.
                builder:
                    (xp) => _RewardWallet(
                      claimable: xp.prizeModel?.livePrizes ?? const [],
                      xp: xp,
                    ),
              ),
              if (lastEarned > 0) ...[
                const SizedBox(height: Dimensions.paddingSizeMedium),
                _JustEarnedToast(xp: lastEarned),
              ],
              const SizedBox(height: Dimensions.paddingSizeMedium),
              // Divider + rows
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 9),
                child: Column(
                  children: [
                    // Progress toward the next level is stated here and ONLY
                    // here. It used to appear again in a 10-segment meter
                    // directly below the card — the same fact, two encodings,
                    // 40pt apart.
                    if (!isMax)
                      _HeroRow(
                        label: displayCaps(
                          'xp_to_next'.trParams({'level': nextName}),
                        ),
                        value: '${_fmt(xpCurrent)}/${_fmt(xpTarget)}',
                      )
                    else
                      _HeroRow(
                        label: displayCaps('xp_status'.tr),
                        value: displayCaps('xp_max_level'.tr),
                      ),
                    _HeroRow(
                      label: displayCaps('xp_streak'.tr),
                      // A live streak burns coral — it's the loss-averse hook
                      // ("don't break it"), so it gets the urgency color.
                      value:
                          streak > 0 ? trPlural('xp_streak_days', streak) : '—',
                      valueColor: streak > 0 ? _Xp.coral : _Xp.onDarkMed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The wallet: what the user can spend right now.
///
/// This replaced a twin-stat block whose second half was the leaderboard rank.
/// A rank on a rewards screen is a comparison ("#18 of 240"), and comparison on
/// a page that already showed three progress deficits made the whole surface
/// read as a scoreboard of things not yet earned.
///
/// Total XP stays, because it is the currency the rest of the screen is priced
/// in. What leads now is the count of *usable* rewards — and when that is zero,
/// the single nearest reward, so the card never has nothing to say.
class _RewardWallet extends StatelessWidget {
  final List<Prize> claimable;
  final XpController xp;
  const _RewardWallet({required this.claimable, required this.xp});

  @override
  Widget build(BuildContext context) {
    final xpStat = _Stat(
      value: _fmt(xp.currentLevel?.currentXp ?? 0),
      label: displayCaps('xp_total'.tr),
      color: _Xp.mint,
    );

    if (claimable.isEmpty) {
      // Nothing banked yet. Name the next concrete reward instead of a tier —
      // "180 XP until free delivery" beats "180 XP TO CHILLING".
      final next = xp.nextReward;
      if (next == null) return Center(child: xpStat);
      final remaining = xp.xpToNextReward;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          xpStat,
          const SizedBox(height: Dimensions.paddingSizeMedium),
          Text(
            remaining > 0
                ? 'xp_until_reward'.trParams({
                  'xp': _fmt(remaining),
                  'reward': next.title,
                })
                : 'xp_reward_ready'.trParams({'reward': next.title}),
            textAlign: TextAlign.center,
            style: waddyBold.copyWith(
              fontSize: 12,
              color: _Xp.onDarkMed,
              height: 1.3,
            ),
          ),
        ],
      );
    }

    // At least one reward is sitting unused. Lead with the count, then qualify
    // the first one with the conditions that actually govern it.
    final first = claimable.first;
    final conditions = prizeConditionsLine(
      minOrderAmount: first.minOrderAmount,
      expiresAt: first.expiresAt,
      maxDays: 30,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: trPlural('xp_rewards_ready', claimable.length),
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _fmt(claimable.length),
                style: waddyBlack.copyWith(
                  fontSize: 32,
                  color: _Xp.mint,
                  height: 1,
                  letterSpacing: displayTracking(-0.02 * 32),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayCaps(trPlural('xp_rewards_ready', claimable.length)),
                textAlign: TextAlign.center,
                style: waddyBold.copyWith(
                  fontSize: 10,
                  color: _Xp.onDarkMed,
                  height: 1.2,
                  letterSpacing: displayTracking(0.08 * 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          first.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: waddyBlack.copyWith(
            fontSize: 15,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        if (conditions != null) ...[
          const SizedBox(height: 4),
          Text(
            conditions,
            textAlign: TextAlign.center,
            style: waddyBold.copyWith(
              fontSize: 11,
              color: _Xp.onDarkMed,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    // One node, not two. A screen reader used to hit the numeral and its label
    // as unrelated fragments ("46", then "TOTAL XP"), because nothing tied them
    // together; `excludeSemantics` collapses the pair into one readable phrase.
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: waddyBlack.copyWith(
              fontSize: 32,
              color: color,
              height: 1,
              letterSpacing: displayTracking(-0.02 * 32),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: waddyBold.copyWith(
              fontSize: 9.5,
              color: _Xp.onDarkFaint,
              letterSpacing: displayTracking(0.08 * 9.5),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String? badge;
  final int level;
  const _HeroBadge({this.badge, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      margin: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: _Xp.teal,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child:
          (badge != null && badge!.isNotEmpty)
              ? CustomImage(
                image: badge!,
                fit: BoxFit.cover,
                width: 52,
                height: 52,
              )
              // No badge art from the server: the crown, which plays once
              // on arrival and again when the level changes (XM-03).
              : XpRiveIcon(
                icon: XpIcon.crown,
                size: 44,
                fallback: Icons.emoji_events_rounded,
                fallbackColor: _Xp.gold,
                playWhen: level,
              ),
    );
  }
}

/// The "+N XP JUST EARNED" pop — mirrors the mock's spring `@keyframes pop`.
class _JustEarnedToast extends StatefulWidget {
  final int xp;
  const _JustEarnedToast({required this.xp});

  @override
  State<_JustEarnedToast> createState() => _JustEarnedToastState();
}

class _JustEarnedToastState extends State<_JustEarnedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: Dimensions.paddingSizeExtraSmall,
      ),
      decoration: BoxDecoration(
        color: _Xp.mint100,
        border: Border.all(color: _Xp.border, width: 2),
        borderRadius: BorderRadius.circular(_Xp.rSm + 1),
      ),
      child: Text(
        displayCaps('xp_just_earned'.trParams({'xp': fmtCount(widget.xp)})),
        style: waddyBlack.copyWith(fontSize: 11, color: _Xp.teal, height: 1),
      ),
    );
    if (reduce) return chip;
    final popped = AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        // scale .6 → 1.08 → 1 with a small rotate settle
        final t = Curves.easeOut.transform(_c.value);
        final scale =
            t < 0.6
                ? 0.6 + (1.08 - 0.6) * (t / 0.6)
                : 1.08 - (1.08 - 1.0) * ((t - 0.6) / 0.4);
        final rot = (1 - t) * -0.07;
        return Opacity(
          opacity: (_c.value * 2).clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: chip,
    );
    // A one-shot coin burst behind the chip (XM-03). Outside the layout, so
    // the chip keeps its size.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        const Positioned(
          child: IgnorePointer(
            child: XpLottieOnce(asset: XpMotion.coinBurst, size: 72),
          ),
        ),
        popped,
      ],
    );
  }
}

class _HeroRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _HeroRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeExtraSmall,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: waddyBold.copyWith(
                fontSize: 11,
                color: _Xp.onDarkMed,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: waddyBlack.copyWith(
              fontSize: 11,
              color: valueColor ?? Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
