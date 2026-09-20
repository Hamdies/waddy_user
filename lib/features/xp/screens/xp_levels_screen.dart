import 'package:flutter/foundation.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/common/widgets/spots/spots_l10n.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/level_up_event_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_level_model.dart';
import 'package:waddy_app/features/xp/screens/level_up_screen.dart';
import 'package:waddy_app/features/xp/widgets/streak_rive_badge.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';

/// ─── WADDI XP home ───────────────────────────────────────────────────────────
/// Faithful native port of the "Waddi XP progression system" Home.dc.html:
/// a dark deep-teal canvas with a mint-foil hero card (giant watermark level,
/// tier ribbon, total XP + "just earned" toast), a segmented tier meter, a
/// "what's next" block (weekly challenge + locked next reward), an XP-sources
/// grid, and a trophy case. Neubrutalist — teal/mint, hard zero-blur shadows.
///
/// Lives as the "XP" tab inside the dashboard, so it renders scroll content
/// only: the app's own bottom nav owns the tab bar the mock draws at the base.
class XpLevelsScreen extends StatefulWidget {
  const XpLevelsScreen({super.key});

  @override
  State<XpLevelsScreen> createState() => _XpLevelsScreenState();
}

class _XpLevelsScreenState extends State<XpLevelsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _entrance.forward();
    _initXpData();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _initXpData() async {
    try {
      final controller = Get.find<XpController>();
      // Await the leaderboard alongside level details so the level-up
      // celebration can show the user's rank stat the moment it fires.
      await Future.wait([
        controller.getLevelDetails(),
        controller.getLeaderboard(),
      ]);
      controller.getChallenges();
      controller.getHistory();
      controller.getXpConfig();
      if (AuthHelper.isLoggedIn()) {
        try {
          Get.find<ProfileController>().getUserInfo();
        } catch (e, s) {
          swallow('refresh profile for XP header', e, s);
        }
      }
      _maybeCelebrateLevelUp(controller);
    } catch (e) {
      debugPrint('XpController not found: $e');
    }
  }

  /// If the server flagged un-celebrated level-ups, play them once this screen
  /// is mounted and visible. Guarded so a rebuild/refresh can't double-fire.
  bool _celebrating = false;
  void _maybeCelebrateLevelUp(XpController controller) {
    if (_celebrating || controller.pendingLevelUps.isEmpty) return;
    _celebrating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _celebrating = false;
        return;
      }
      await LevelUpScreen.showQueue(controller);
      _celebrating = false;
    });
  }

  bool get _isRamadan {
    try {
      return Get.find<HomeController>().showRamadanDecorations;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scoped to the level payload. This wraps the whole page, so leaving it
    // bare meant every `update()` in the module — a challenge tab tap
    // included — repainted the entire tree. The sections below subscribe
    // separately to the state each of them actually reads.
    Widget body = GetBuilder<XpController>(
      id: XpController.idLevel,
      builder: (xp) {
        // Crossfade between skeleton and content so the swap is a soft
        // dissolve, not a snap. Keyed children drive the switch.
        final Widget child;
        if (xp.currentLevel == null && !xp.isLevelLoading) {
          child =
              AuthHelper.isLoggedIn()
                  ? _ErrorState(
                    key: const ValueKey('error'),
                    onRetry: _initXpData,
                  )
                  : const _SignInPromptState(key: ValueKey('signInPrompt'));
        } else if (xp.currentLevel == null) {
          // First load, nothing to show yet: a skeleton that mirrors the real
          // layout so the page keeps a stable shape instead of popping in
          // section by section as each request lands.
          child = const _XpSkeleton(key: ValueKey('skeleton'));
        } else {
          child = RefreshIndicator(
            key: const ValueKey('content'),
            color: _Xp.mint,
            backgroundColor: _Xp.panel,
            onRefresh: _initXpData,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Masthead(),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          Dimensions.paddingSizeDefault,
                          0,
                          Dimensions.paddingSizeDefault,
                          MediaQuery.of(context).padding.bottom + 28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hero + CTA are one tight group — what you have,
                            // then how to spend it. Generous gaps after.
                            _FoilHeroCard(xp: xp),
                            const _OrderCta(),
                            const SizedBox(height: _Xp.sXl),
                            const _WhatsNextSection(),
                            const SizedBox(height: _Xp.sXl),
                            const _XpSourcesSection(),
                            const SizedBox(height: _Xp.sXl),
                            const _RewardsSection(),
                            if (kDebugMode) ...[
                              const SizedBox(height: _Xp.sXl),
                              _SimulateLevelUpButton(xp: xp),
                            ],
                            const SizedBox(height: 90),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: const Cubic(0.16, 1, 0.3, 1), // ease-out-expo
          switchOutCurve: const Cubic(0.16, 1, 0.3, 1),
          child: child,
        );
      },
    );

    if (_isRamadan) {
      body = RamadanStringLightWrapper(
        showTopString: true,
        showBottomString: false,
        alwaysOn: true,
        metalColor: _Xp.panel,
        metalShadeColor: _Xp.foil,
        lightColor: _Xp.mint,
        lightSecondaryColor: _Xp.mint.withValues(alpha: 0.7),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: _Xp.panel,
      body: SafeArea(bottom: false, child: body),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME TOKENS
// ─────────────────────────────────────────────────────────────────────────────
/// The XP surface's slice of the shared Spots system.
///
/// This class used to redeclare `mint`, `teal`, `panel`, `border` and `green`
/// with the same hex values as `Spots`, plus its own radius and spacing scales —
/// two sources of truth for one brand, and the spacing was off the project's 4pt
/// grid (14 and 36). Everything that `Spots` already owns now forwards to it, so
/// a brand change lands in one file.
///
/// What remains are the tokens the dark XP surface genuinely needs and `Spots`
/// (light-mode only) does not define: the darker `foil` hero, the mint and gold
/// washes, the gold achievement accent, and the coral urgency accent.
class _Xp {
  _Xp._();

  // ── FORWARDED FROM THE SHARED SYSTEM ──────────────────────────────────
  static const Color mint = Spots.mint;
  static const Color teal = Spots.teal;
  static const Color panel = Spots.panel;
  static const Color green = Spots.green;
  static const Color border = Spots.border;

  // ── XP-ONLY TOKENS ────────────────────────────────────────────────────
  static const Color foil = Color(0xFF0B2A27); // darker foil hero card
  static const Color mint100 = Color(0xFFD6FCEC); // mint wash (toast)

  // ── SEMANTIC ACCENTS ──────────────────────────────────────────────────
  // Each color owns one meaning so the eye can decode state without reading:
  //   mint  → forward progress / XP earned  (dominant)
  //   gold  → achievement — the "crown" win state  (secondary)
  //   coral → urgency — streak at risk, resets soon  (accent)
  static const Color gold = Color(0xFFFFC93C); // won/achieved — crown accent
  static const Color goldInk = Color(0xFF4A3410); // ink on gold surfaces
  static const Color coral = Color(0xFFFF6B4A); // urgency / streak-at-risk

  // Neutrals tinted toward the teal hue rather than flat white — subtle
  // cohesion so overlays read as "part of the canvas", not stickers on it.
  static const Color _tint = Color(0xFFCFF5E9); // pale teal-mint for overlays
  static Color overlay(double a) => _tint.withValues(alpha: a);

  // Text on dark. `onDarkFaint` sat at 0.5, which computes to 4.5:1 on `panel` —
  // a rounding-boundary pass used at 9–9.5sp. Raised to clear AA outright.
  static Color get onDark => Colors.white;
  static Color get onDarkMed => Colors.white.withValues(alpha: 0.62);
  static Color get onDarkFaint => Colors.white.withValues(alpha: 0.58);

  // Radii — the shared scale. `rSm` was 5, one off `Spots.radiusSm`.
  static const double rSm = Spots.radiusSm; // 4
  static const double rMd = Spots.radiusMd; // 8
  static const double rLg = Spots.radiusLg; // 10

  // Spacing — snapped onto the 4pt grid `Spots` keeps (was 8 / 14 / 36).
  static const double sSm = Spots.s8; // within a group
  static const double sMd = Spots.s12; // header → content
  static const double sXl = Spots.s32; // section-to-section breathing room

  static List<BoxShadow> shadow({
    double dx = 4,
    double dy = 4,
    Color color = border,
  }) => Spots.shadow(dx: dx, dy: dy, color: color);
}

/// Locale-aware digit grouping.
///
/// This used to insert `,` unconditionally, which is wrong under `ar` — Arabic
/// groups with `٬`. `fmtCount` delegates to `NumberFormat.decimalPattern` for
/// the active locale.
String _fmt(int n) => fmtCount(n);

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

    // What the user actually owns right now. This is the hero's headline: an
    // inventory of things they can spend, not a count of things they cannot.
    final claimable = xp.prizeModel?.claimablePrizes ?? const [];

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
              _HeroBadge(badge: data?.levelBadge),
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
              _RewardWallet(claimable: claimable, xp: xp),
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
    final conditions = _conditionsLine(first);

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

  /// The strings that decide whether a reward is actually usable today: the
  /// basket it needs and how long it lasts. Both were parsed by the model and
  /// shown nowhere.
  String? _conditionsLine(Prize prize) {
    final parts = <String>[];

    final min = prize.minOrderAmount;
    if (min != null && min > 0) {
      parts.add(
        'xp_min_order'.trParams({
          'amount': PriceConverter.convertPrice(min, forDM: true),
        }),
      );
    }

    final expires = prize.expiresAt;
    if (expires != null) {
      final days = expires.difference(DateTime.now()).inDays;
      if (days >= 0 && days <= 30) {
        parts.add(
          days == 0
              ? 'xp_expires_today'.tr
              : trPlural('xp_expires_in_days', days),
        );
      }
    }

    return parts.isEmpty ? null : parts.join(' · ');
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
  const _HeroBadge({this.badge});

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
              : const Icon(
                Icons.emoji_events_rounded,
                size: 26,
                color: _Xp.gold,
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
        '+${widget.xp} XP JUST EARNED',
        style: waddyBlack.copyWith(fontSize: 11, color: _Xp.teal, height: 1),
      ),
    );
    if (reduce) return chip;
    return AnimatedBuilder(
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
        final hasFreeDelivery = (xp.prizeModel?.claimablePrizes ?? const [])
            .any((p) => p.type.toLowerCase() == 'free_delivery');
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
        // Prefer an in-progress weekly challenge; fall back to any active one.
        final all = <Challenge>[
          ...?xp.challengeModel?.weeklyChallenges,
          ...?xp.challengeModel?.dailyChallenges,
        ];
        final challenge =
            all.firstWhereOrNull((c) => c.isActive) ??
            all.firstWhereOrNull((c) => c.canClaim) ??
            (all.isNotEmpty ? all.first : null);

        final reward = xp.nextReward;
        final rewardLevel = xp.nextRewardLevel;

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
                resetTime:
                    challenge.type == 'weekly'
                        ? xp.challengeModel?.weeklyResetTime
                        : xp.challengeModel?.dailyResetTime,
              )
            else
              _EmptyTile(emoji: '🎯', text: 'xp_no_challenges'.tr),
            if (reward != null) ...[
              const SizedBox(height: _Xp.sSm),
              _RewardTile(reward: reward, level: rewardLevel),
            ],
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
      Get.toNamed(RouteHelper.getStoreRoute(id: storeId, page: 'store'));
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
                    child: Icon(
                      iconForPrizeType(reward.type),
                      size: 22,
                      color: _Xp.gold,
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

/// Outlined glyph per prize type — guarantees each reward kind is visually
/// distinct in the trophy case (a delivery van never looks like a discount
/// tag), replacing the identical medal emoji the backend sometimes sends.
IconData iconForPrizeType(String type) {
  switch (type.toLowerCase()) {
    case 'free_delivery':
      return Icons.local_shipping_outlined;
    case 'discount':
      return Icons.sell_outlined;
    case 'wallet_credit':
      return Icons.account_balance_wallet_outlined;
    case 'badge':
      return Icons.workspace_premium_outlined;
    case 'free_item':
      return Icons.redeem_outlined;
    default:
      return Icons.emoji_events_outlined;
  }
}

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
                    _SourceRow(data: sources[i]),
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
          '+${val('order', config.xpPerOrder)} XP',
          'xp_source_order'.tr,
        ),
      if (val('vote', 0) > 0)
        _SourceData(
          Icons.how_to_vote_outlined,
          '+${val('vote', 0)} XP',
          'xp_source_vote'.tr,
        ),
      if (val('review', config.xpPerReview) > 0)
        _SourceData(
          Icons.star_outline_rounded,
          '+${val('review', config.xpPerReview)} XP',
          'xp_source_review'.tr,
        ),
      if (val('place_submission', 0) > 0)
        _SourceData(
          Icons.add_location_alt_outlined,
          '+${val('place_submission', 0)} XP',
          'xp_source_add_place'.tr,
        ),
      if (val('streak_bonus', config.streakBonusXp) > 0)
        _SourceData(
          Icons.local_fire_department_outlined,
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
  const _SourceData(this.icon, this.amount, this.label);
}

/// One "way to earn" row: glyph disc · action label · aligned XP value.
/// Rows in a shared surface scan far better than three identical cards.
class _SourceRow extends StatelessWidget {
  final _SourceData data;
  const _SourceRow({required this.data});

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
            child: Icon(data.icon, size: 18, color: _Xp.mint),
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
              ...shown.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: Dimensions.paddingSizeSmall,
                  ),
                  child: _RewardRow(reward: r),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Real level prizes only — claimable first, then unlocked, then locked.
  /// Never padded with sample data.
  List<_RewardEntry> _buildRewards(XpController xp) {
    final levels = xp.levelsListModel?.levels ?? [];
    final ready = <_RewardEntry>[];
    final owned = <_RewardEntry>[];
    final locked = <_RewardEntry>[];

    for (final level in levels) {
      for (final p in level.prizes) {
        final entry = _RewardEntry(
          icon: iconForPrizeType(p.type),
          title: p.title.isNotEmpty ? p.title : 'xp_reward_fallback'.tr,
          level: level.level,
          unlocked: p.isUnlocked || p.isClaimed,
          claimed: p.isClaimed,
        );
        if (entry.unlocked && !entry.claimed) {
          ready.add(entry);
        } else if (entry.unlocked) {
          owned.add(entry);
        } else {
          locked.add(entry);
        }
      }
    }
    return [...ready, ...owned, ...locked];
  }
}

class _RewardEntry {
  final IconData icon;
  final String title;
  final int level;
  final bool unlocked;
  final bool claimed;
  const _RewardEntry({
    required this.icon,
    required this.title,
    required this.level,
    required this.unlocked,
    required this.claimed,
  });
}

class _RewardRow extends StatelessWidget {
  final _RewardEntry reward;
  const _RewardRow({required this.reward});

  @override
  Widget build(BuildContext context) {
    // Locked rewards used to sit under a blanket `Opacity(0.32)`, which drove
    // their label to 2.6:1 against the panel and the level tag to 1.75:1 —
    // both far under AA. State is carried by the icon treatment and an explicit
    // status word instead, so the text itself stays legible.
    final bool ready = reward.unlocked && !reward.claimed;
    final Color accent =
        ready
            ? _Xp.mint
            : reward.claimed
            ? _Xp.onDarkMed
            : _Xp.overlay(0.55);

    final String status =
        ready
            ? 'xp_reward_ready_tag'.tr
            : reward.claimed
            ? 'xp_reward_used_tag'.tr
            : 'xp_reward_locked_tag'.trParams({'level': '${reward.level}'});

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
              child: Icon(
                reward.unlocked ? reward.icon : Icons.lock_outline_rounded,
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

// ─────────────────────────────────────────────────────────────────────────────
// SHARED PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────
/// Kicker + title, with an optional trailing action.
///
/// Not `SpotsSectionHeader`: that one is built for the light Places canvas
/// (`Spots.ink` on paper) and this surface is the dark foil. The structure and
/// the directional arrow rule are deliberately the same.
class _SectionHeader extends StatelessWidget {
  final String kicker;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({
    required this.kicker,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // The arrow is not mirrored by the framework — it has to be chosen.
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayCaps(kicker),
          style: waddyBlack.copyWith(
            fontSize: 9.5,
            color: _Xp.onDarkFaint,
            letterSpacing: displayTracking(0.1 * 9.5),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: waddyBlack.copyWith(
            fontSize: 15,
            color: Colors.white,
            height: 1,
          ),
        ),
      ],
    );

    if (actionLabel == null || onAction == null) return heading;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        Pressable(
          semanticLabel: actionLabel!,
          minSize: Dimensions.minTapTarget,
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Dimensions.paddingSizeSmall,
            ),
            child: Text(
              '${displayCaps(actionLabel!)} ${isLtr ? '→' : '←'}',
              style: waddyBlack.copyWith(
                fontSize: 11,
                color: _Xp.mint,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A secondary surface on the foil canvas. Deliberately *lighter* than the
/// hero (fill-forward, hairline edge) so the hero stays the one heavily-framed
/// object and these read as content, not competing outlined cards.
class _DarkTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Slightly raised presence for tappable tiles (challenge/reward) so they
  /// still afford interaction without shouting like the hero.
  final bool interactive;
  const _DarkTile({
    required this.child,
    required this.padding,
    this.interactive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _Xp.overlay(interactive ? 0.07 : 0.05),
        border: Border.all(
          color: _Xp.overlay(interactive ? 0.16 : 0.10),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(_Xp.rMd),
      ),
      child: child,
    );
  }
}

class _EmptyTile extends StatelessWidget {
  final String emoji;
  final String text;
  const _EmptyTile({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return _DarkTile(
      padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: waddyBold.copyWith(
                fontSize: 12,
                color: _Xp.onDarkMed,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING SKELETON — mirrors the real layout so the page has a stable shape on
// first load, with a single travelling shimmer instead of piecemeal pop-in.
// ─────────────────────────────────────────────────────────────────────────────
class _XpSkeleton extends StatelessWidget {
  const _XpSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Masthead: wordmark + level chip
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeMedium,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeMedium,
            ),
            child: Row(
              children: [
                _Shimmer(width: 26, height: 26, radius: 6),
                SizedBox(width: 10),
                _Shimmer(width: 84, height: 15, radius: 4),
                Spacer(),
                _Shimmer(width: 48, height: 26, radius: _Xp.rSm + 1),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeExtraSmall,
              Dimensions.paddingSizeDefault,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero card silhouette
                Container(
                  width: double.infinity,
                  height: 236,
                  decoration: BoxDecoration(
                    color: _Xp.foil,
                    border: Border.all(color: _Xp.overlay(0.14), width: 2),
                    borderRadius: BorderRadius.circular(_Xp.rLg),
                  ),
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  child: const Column(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _Shimmer(width: 96, height: 22, radius: _Xp.rSm),
                      ),
                      SizedBox(height: 14),
                      _Shimmer(width: 52, height: 52, radius: 9),
                      SizedBox(height: 12),
                      _Shimmer(width: 130, height: 16, radius: 4),
                      SizedBox(height: 18),
                      // Twin stat placeholders
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Shimmer(width: 88, height: 34, radius: 6),
                          SizedBox(width: 28),
                          _Shimmer(width: 88, height: 34, radius: 6),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Segmented meter placeholder
                Row(
                  children: List.generate(10, (i) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: i == 9 ? 0 : 3,
                        ),
                        child: const _Shimmer(
                          width: double.infinity,
                          height: 14,
                          radius: 2,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: _Xp.sXl),
                // Section header + tile stubs, twice (What's next, XP sources)
                for (var s = 0; s < 2; s++) ...[
                  const _Shimmer(width: 120, height: 12, radius: 3),
                  const SizedBox(height: 6),
                  const _Shimmer(width: 150, height: 18, radius: 4),
                  const SizedBox(height: _Xp.sMd),
                  const _Shimmer(
                    width: double.infinity,
                    height: 74,
                    radius: _Xp.rMd,
                  ),
                  const SizedBox(height: _Xp.sXl),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single shimmer block. One shared controller-less implicit animation via a
/// repeating gradient sweep; collapses to a flat block under reduced-motion.
class _Shimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _Shimmer({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = _Xp.overlay(0.06);
    final radius = BorderRadius.circular(widget.radius);
    if (MediaQuery.of(context).disableAnimations) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: radius),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // A soft mint highlight sweeps left→right across the base block.
          final t = _c.value * 2 - 1; // -1 → 1
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: base,
              gradient: LinearGradient(
                begin: Alignment(t - 0.6, 0),
                end: Alignment(t + 0.6, 0),
                colors: [base, _Xp.mint.withValues(alpha: 0.10), base],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shown instead of [_ErrorState] when the 401 is because there's no session
/// at all (guest/none), not a real network failure — the fix is signing in,
/// not retrying.
class _SignInPromptState extends StatelessWidget {
  const _SignInPromptState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeExtraOverLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              size: 56,
              color: _Xp.mint.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 20),
            Text(
              'sign_in_to_view_your_xp'.tr,
              textAlign: TextAlign.center,
              style: waddyBlack.copyWith(fontSize: 22, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              'track_levels_quests_and_rewards'.tr,
              textAlign: TextAlign.center,
              style: waddyRegular.copyWith(fontSize: 14, color: _Xp.onDarkMed),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Get.toNamed(RouteHelper.getUnifiedAuthRoute()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeExtremeLarge,
                  vertical: Dimensions.paddingSizeDefault,
                ),
                decoration: BoxDecoration(
                  color: _Xp.mint,
                  borderRadius: BorderRadius.circular(_Xp.rMd),
                  border: Border.all(color: _Xp.border, width: 3),
                  boxShadow: _Xp.shadow(),
                ),
                child: Text(
                  'sign_in'.tr,
                  style: waddyBlack.copyWith(fontSize: 16, color: _Xp.teal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeExtraOverLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: _Xp.mint.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 20),
            Text(
              'failed_to_load'.tr,
              textAlign: TextAlign.center,
              style: waddyBlack.copyWith(fontSize: 22, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              'pull_to_retry'.tr,
              textAlign: TextAlign.center,
              style: waddyRegular.copyWith(fontSize: 14, color: _Xp.onDarkMed),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeExtremeLarge,
                  vertical: Dimensions.paddingSizeDefault,
                ),
                decoration: BoxDecoration(
                  color: _Xp.mint,
                  borderRadius: BorderRadius.circular(_Xp.rMd),
                  border: Border.all(color: _Xp.border, width: 3),
                  boxShadow: _Xp.shadow(),
                ),
                child: Text(
                  'retry'.tr,
                  style: waddyBlack.copyWith(fontSize: 16, color: _Xp.teal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIMULATE LEVEL-UP — debug-only trigger for the celebration + Rive burst
// ─────────────────────────────────────────────────────────────────────────────
/// Fires the level-up celebration on demand so the Rive burst can be reviewed
/// without grinding real XP. Debug builds only (see the `kDebugMode` guard at
/// the call site), and it never touches the server: the event is synthesised
/// locally and shown directly, so nothing is acknowledged or consumed from the
/// real `pendingLevelUps` queue.
class _SimulateLevelUpButton extends StatelessWidget {
  final XpController xp;
  const _SimulateLevelUpButton({required this.xp});

  Future<void> _simulate() async {
    final current = xp.currentLevel;
    // Preview the *next* level where we know it, so the celebration shows a
    // plausible progression rather than re-congratulating the current level.
    final next = current?.nextLevel;
    final level = next?.levelNumber ?? ((current?.currentLevel ?? 0) + 1);

    // The level list carries the badge art; nextLevel itself doesn't.
    final badge =
        current?.allLevels
            .firstWhereOrNull((l) => l.level == level)
            ?.badgeImage;

    final event = LevelUpEvent(
      transactionId: -1, // sentinel: never sent to the acknowledge endpoint
      level: level,
      levelName: next?.name ?? 'Level $level',
      levelBadge: badge,
      totalXp: current?.currentXp ?? 0,
      xpGained: current?.xpForNextLevel ?? 0,
      rewardName: 'Free delivery for a week',
      rewardType: 'perk',
      rarity: 'rare',
    );

    await Get.dialog(
      LevelUpScreen(event: event, rank: xp.leaderboardModel?.currentUser?.rank),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      useSafeArea: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: _simulate,
        borderRadius: BorderRadius.circular(_Xp.rMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeExtremeLarge,
            vertical: Dimensions.paddingSizeDefault,
          ),
          decoration: BoxDecoration(
            color: _Xp.gold,
            borderRadius: BorderRadius.circular(_Xp.rMd),
            border: Border.all(color: _Xp.border, width: 3),
            boxShadow: _Xp.shadow(),
          ),
          child: Text(
            'DEBUG · SIMULATE LEVEL UP',
            style: waddyBlack.copyWith(fontSize: 14, color: _Xp.goldInk),
          ),
        ),
      ),
    );
  }
}
