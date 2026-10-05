import 'package:flutter/foundation.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/common/widgets/spots/spots_l10n.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/reward_state.dart';
import 'package:waddy_app/features/xp/domain/models/level_up_event_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_level_model.dart';
import 'package:waddy_app/features/xp/screens/level_up_screen.dart';
import 'package:waddy_app/features/xp/widgets/streak_rive_badge.dart';
import 'package:waddy_app/features/xp/widgets/xp_tokens.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/features/xp/domain/models/prize_kind.dart';
import 'package:waddy_app/features/xp/widgets/prize_visual.dart';
import 'package:waddy_app/features/xp/widgets/xp_motion.dart';

part 'xp_home/hero.dart';
part 'xp_home/whats_next.dart';
part 'xp_home/earn_and_rewards.dart';
part 'xp_home/primitives.dart';
part 'xp_home/states.dart';

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

  /// Tab visit: revalidate what's stale, in parallel, with the cache on
  /// screen meanwhile. Pull-to-refresh: [force] refetches everything (X-19).
  ///
  /// The leaderboard and history used to be fetched here too — the first one
  /// awaited, blocking everything behind it — for a rank nothing renders and
  /// a history nothing shows (X-22).
  Future<void> _initXpData({bool force = false}) async {
    try {
      final controller = Get.find<XpController>();
      await controller.revalidate(force: force);
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
                    onRetry: () => _initXpData(force: true),
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
            onRefresh: () => _initXpData(force: true),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                // Slivers, not a Column in a SingleChildScrollView: sections
                // below the fold are built when scrolled to, not all on the
                // first frame (X-09). Each child is aligned to the start so it
                // gets the loose width the Column used to give it.
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  slivers: [
                    const SliverToBoxAdapter(child: _Masthead()),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        Dimensions.paddingSizeDefault,
                        0,
                        Dimensions.paddingSizeDefault,
                        MediaQuery.of(context).padding.bottom + 28,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          [
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
                              ]
                              .map(
                                (w) => Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: w,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
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
/// The XP tokens, shared with the other XP screens (see `xp_tokens.dart`).
typedef _Xp = XpTokens;

/// Locale-aware digit grouping.
///
/// This used to insert `,` unconditionally, which is wrong under `ar` — Arabic
/// groups with `٬`. `fmtCount` delegates to `NumberFormat.decimalPattern` for
/// the active locale.
String _fmt(int n) => fmtCount(n);
