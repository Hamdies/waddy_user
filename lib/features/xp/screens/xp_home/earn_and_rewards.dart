part of '../xp_levels_screen.dart';

// "Ways to earn" and the rewards list.

// ─────────────────────────────────────────────────────────────────────────────
// XP SOURCES — 3-up "ways to earn" grid
// ─────────────────────────────────────────────────────────────────────────────
class _XpSourcesSection extends StatelessWidget {
  const _XpSourcesSection();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      id: XpController.idConfig,
      builder: (xp) {
        final sources = _realSources(xp);
        // Nothing real to show yet (config still loading / leveling disabled) —
        // drop the section entirely rather than invent numbers.
        if (sources.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              kicker: 'xp_ways_to_earn'.tr,
              title: 'xp_sources'.tr,
            ),
            const SizedBox(height: _Xp.sMd),
            // A single grouped surface of action rows — replaces the three
            // identical floating cards (the classic AI card-grid) with a
            // scannable list where the XP value is the aligned right column.
            Container(
              decoration: BoxDecoration(
                color: _Xp.overlay(0.05),
                borderRadius: BorderRadius.circular(_Xp.rMd),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeMedium,
                vertical: Dimensions.paddingSizeExtraSmall,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < sources.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: _Xp.overlay(0.08),
                      ),
                    _SourceRow(data: sources[i], index: i),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build up to three "ways to earn" tiles from live server config only —
  /// no hardcoded XP values. Reads the `xp_sources` block (with sensible
  /// fallbacks to the flat config fields for older backends), picks the three
  /// most relevant positive-value actions, and skips any that resolve to 0.
  List<_SourceData> _realSources(XpController xp) {
    final config = xp.xpConfig;
    if (config == null) return const [];

    final s = config.xpSources;
    int val(String key, int fallback) {
      final v = s[key] ?? fallback;
      return v > 0 ? v : 0;
    }

    // Candidates in priority order; each keeps only real, positive values.
    // Icons are outlined Material glyphs (not emoji) so they render identically
    // across devices and read as a designed set rather than placeholders.
    final candidates = <_SourceData>[
      if (val('order', config.xpPerOrder) > 0)
        _SourceData(
          Icons.shopping_bag_outlined,
          XpIcon.coin,
          '+${val('order', config.xpPerOrder)} XP',
          'xp_source_order'.tr,
        ),
      if (val('vote', 0) > 0)
        _SourceData(
          Icons.how_to_vote_outlined,
          XpIcon.heart,
          '+${val('vote', 0)} XP',
          'xp_source_vote'.tr,
        ),
      if (val('review', config.xpPerReview) > 0)
        _SourceData(
          Icons.star_outline_rounded,
          XpIcon.star,
          '+${val('review', config.xpPerReview)} XP',
          'xp_source_review'.tr,
        ),
      if (val('place_submission', 0) > 0)
        _SourceData(
          Icons.add_location_alt_outlined,
          null, // no pin in the icon set
          '+${val('place_submission', 0)} XP',
          'xp_source_add_place'.tr,
        ),
      if (val('streak_bonus', config.streakBonusXp) > 0)
        _SourceData(
          Icons.local_fire_department_outlined,
          XpIcon.fire,
          '+${val('streak_bonus', config.streakBonusXp)} XP',
          'xp_source_streak'.tr,
        ),
    ];

    return candidates.take(3).toList();
  }
}

class _SourceData {
  final IconData icon;
  final String amount;
  final String label;
  /// The animated version, or null to keep [icon] static.
  final XpIcon? motion;
  const _SourceData(this.icon, this.motion, this.amount, this.label);
}

/// One "way to earn" row: glyph disc · action label · aligned XP value.
/// Rows in a shared surface scan far better than three identical cards.
class _SourceRow extends StatelessWidget {
  final _SourceData data;
  final int index;
  const _SourceRow({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeMedium,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _Xp.mint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(_Xp.rSm + 2),
            ),
            alignment: Alignment.center,
            child:
                data.motion != null
                    ? XpRiveIcon(
                      icon: data.motion!,
                      size: 26,
                      fallback: data.icon,
                      fallbackColor: _Xp.mint,
                      playOnReveal: XpMotion.stagger * index,
                    )
                    : Icon(data.icon, size: 18, color: _Xp.mint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.label,
              style: waddyBold.copyWith(
                fontSize: 13,
                color: _Xp.onDark,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            data.amount,
            style: waddyBlack.copyWith(
              fontSize: 14,
              color: _Xp.mint,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REWARDS — a list of what you have and what is next
// ─────────────────────────────────────────────────────────────────────────────
/// Replaces the 4-across trophy grid.
///
/// The grid had two structural problems the list does not. It forced square
/// cells (`GridView.count` with no `childAspectRatio`), so a longer label like
/// "2x FREE DELIVERY" wrapped to two lines while its neighbours fit on one, and
/// at the system's larger font sizes the square could not hold icon + two lines
/// + tag at all. And all eight cells sat inside a single `GestureDetector`:
/// eight things that looked tappable, one destination.
///
/// A row grows downward instead of fighting a fixed square, and each row is its
/// own control with its own semantics.
class _RewardsSection extends StatelessWidget {
  const _RewardsSection();

  static const int _visibleCount = 5;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      id: XpController.idLevel,
      builder: (xp) {
        // While the levels payload is still loading and we have nothing to show,
        // stay out of the way rather than flash an empty state.
        if (xp.isLevelsLoading &&
            (xp.levelsListModel?.levels.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }

        final rewards = _buildRewards(xp);
        final shown = rewards.take(_visibleCount).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              kicker: 'xp_rewards_kicker'.tr,
              title: 'xp_rewards_title'.tr,
              actionLabel: rewards.isNotEmpty ? 'xp_see_all'.tr : null,
              onAction:
                  rewards.isNotEmpty
                      ? () => Get.toNamed(RouteHelper.xpPrizes)
                      : null,
            ),
            const SizedBox(height: _Xp.sMd),
            if (rewards.isEmpty)
              _EmptyTile(emoji: '🎁', text: 'xp_rewards_empty'.tr)
            else
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: Dimensions.paddingSizeSmall,
                  ),
                  child: _RewardRow(reward: shown[i], index: i),
                ),
          ],
        );
      },
    );
  }

  /// Real level prizes only, in the order they matter: act on it now, owned,
  /// coming next, then the record. Never padded with sample data.
  ///
  /// State comes from [RewardState] — the same call the Rewards screen groups
  /// by — not the payload's `is_unlocked` / `is_claimed`, which read an expired
  /// prize as ready and an unspent coupon as used (X-31).
  List<_RewardEntry> _buildRewards(XpController xp) {
    final levels = xp.levelsListModel?.levels ?? [];
    final entries = <_RewardEntry>[
      for (final level in levels)
        for (final p in level.prizes)
          _RewardEntry(
            icon: p.kind.icon,
            kind: p.kind,
            title: p.title.isNotEmpty ? p.title : 'xp_reward_fallback'.tr,
            level: level.level,
            state: p.rewardState,
          ),
    ];
    const order = [
      RewardState.claim,
      RewardState.use,
      RewardState.badge,
      RewardState.locked,
      RewardState.used,
      RewardState.expired,
    ];
    // A stable sort: within a state, rewards keep their level order.
    return [
      for (final state in order) ...entries.where((e) => e.state == state),
    ];
  }
}

class _RewardEntry {
  final IconData icon;
  final PrizeKind kind;
  final String title;
  final int level;
  final RewardState state;
  const _RewardEntry({
    required this.icon,
    required this.kind,
    required this.title,
    required this.level,
    required this.state,
  });
}

class _RewardRow extends StatelessWidget {
  final _RewardEntry reward;
  final int index;
  const _RewardRow({required this.reward, required this.index});

  @override
  Widget build(BuildContext context) {
    // Locked rewards used to sit under a blanket `Opacity(0.32)`, which drove
    // their label to 2.6:1 against the panel and the level tag to 1.75:1 —
    // both far under AA. State is carried by the icon treatment and an explicit
    // status word instead, so the text itself stays legible.
    final RewardState state = reward.state;
    final bool ready = state.isLive;
    final Color accent = switch (state) {
      RewardState.claim || RewardState.use => _Xp.mint,
      RewardState.badge => _Xp.gold,
      RewardState.used || RewardState.expired => _Xp.onDarkMed,
      RewardState.locked => _Xp.overlay(0.55),
    };

    final String status = switch (state) {
      RewardState.claim => 'xp_prizes_ready_to_claim'.tr,
      RewardState.use => 'xp_prizes_ready_to_use'.tr,
      RewardState.badge => 'xp_reward_earned_tag'.tr,
      RewardState.used => 'xp_reward_used_tag'.tr,
      RewardState.expired => 'xp_prizes_expired'.tr,
      RewardState.locked => 'xp_reward_locked_tag'.trParams({
        'level': '${reward.level}',
      }),
    };

    return Pressable(
      semanticLabel: '${reward.title}, $status',
      minSize: Dimensions.minTapTarget,
      onTap: () => Get.toNamed(RouteHelper.xpPrizes),
      child: _DarkTile(
        interactive: true,
        padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color:
                    ready
                        ? _Xp.mint.withValues(alpha: 0.14)
                        : _Xp.overlay(0.06),
                borderRadius: BorderRadius.circular(_Xp.rSm),
                border: Border.all(
                  color:
                      ready
                          ? _Xp.mint.withValues(alpha: 0.5)
                          : _Xp.overlay(0.22),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              // Motion only for good news (XM-06): a reward you can act on
              // plays on reveal and again when it turns ready. Locked, used
              // and expired stay static glyphs.
              child:
                  ready
                      ? XpRiveIcon(
                        icon: XpIcon.forPrize(reward.kind),
                        size: 30,
                        fallback: reward.icon,
                        fallbackColor: accent,
                        playOnReveal: XpMotion.stagger * index,
                        playWhen: state,
                      )
                      : Icon(
                        state == RewardState.locked
                            ? Icons.lock_outline_rounded
                            : reward.icon,
                        size: 18,
                        color: accent,
                      ),
            ),
            const SizedBox(width: Dimensions.paddingSizeMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reward.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: waddyBlack.copyWith(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyBold.copyWith(
                      fontSize: 10,
                      color: ready ? _Xp.mint : _Xp.onDarkMed,
                      height: 1.2,
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
