import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/widgets/brilliant_roadmap_widget.dart';
import 'package:waddy_app/features/xp/widgets/xp_history_widget.dart';
import 'package:waddy_app/features/xp/widgets/xp_leaderboard_preview_widget.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';

class XpLevelsScreen extends StatefulWidget {
  const XpLevelsScreen({super.key});

  @override
  State<XpLevelsScreen> createState() => _XpLevelsScreenState();
}

class _XpLevelsScreenState extends State<XpLevelsScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController.forward();
    _initXpData();
  }

  Future<void> _initXpData() async {
    try {
      final controller = Get.find<XpController>();
      await controller.getLevelDetails();
      controller.getChallenges();
      controller.getHistory();
      controller.getLeaderboard();
    } catch (e) {
      debugPrint("XpController not found: $e");
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isRamadan {
    try {
      return Get.find<HomeController>().isRamadanCelebrationActive;
    } catch (_) {
      return false;
    }
  }

  Widget _buildErrorState(Color accent, Color black) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: accent.withValues(alpha: 0.6)),
            const SizedBox(height: 20),
            Text(
              'failed_to_load'.tr,
              style: robotoBlack.copyWith(fontSize: 22, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'pull_to_retry'.tr,
              style: robotoRegular.copyWith(fontSize: 14, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _initXpData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: black, width: 3),
                  boxShadow: [BoxShadow(color: black, offset: const Offset(4, 4), blurRadius: 0)],
                ),
                child: Text(
                  'retry'.tr,
                  style: robotoBlack.copyWith(fontSize: 16, color: black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRamadanHeader(Color bg, Color accent) {
    final darkerBg = HSLColor.fromColor(bg)
        .withLightness((HSLColor.fromColor(bg).lightness - 0.05).clamp(0.0, 1.0))
        .toColor();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [darkerBg, bg],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 22),
          Text(
            'ramadan_kareem'.tr,
            style: robotoBlack.copyWith(fontSize: 26, color: accent, letterSpacing: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            'earn_extra_blessings'.tr,
            style: robotoRegular.copyWith(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRamadan = _isRamadan;
    final theme = Theme.of(context);
    final sw = MediaQuery.sizeOf(context).width;
    final hPad = (sw * 0.051).clamp(14.0, 24.0);
    final isCompact = sw < 360;

    final Color primary = theme.primaryColor;
    final Color accent = theme.colorScheme.secondary;
    final Color deepPrimary = HSLColor.fromColor(primary)
        .withLightness((HSLColor.fromColor(primary).lightness - 0.06).clamp(0.0, 1.0))
        .toColor();
    final Color neo = deepPrimary;

    Widget body = GetBuilder<XpController>(
      builder: (xpController) {
        if (xpController.currentLevel == null && !xpController.isLevelLoading) {
          return _buildErrorState(accent, primary);
        }

        return RefreshIndicator(
          color: accent,
          backgroundColor: primary,
          onRefresh: _initXpData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Ramadan header / top spacer ──────────────────────────
                if (isRamadan)
                  _buildRamadanHeader(primary, accent)
                else
                  SizedBox(height: isCompact ? 12 : 20),

                // ── Top bar ──────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: [
                      _NavButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        accent: accent,
                        neo: neo,
                        onTap: () => Get.back(),
                      ),
                      const Spacer(),
                      _NavButton(
                        icon: Icons.info_outline_rounded,
                        accent: accent,
                        neo: neo,
                        onTap: () => _showLearnMoreBottomSheet(context, neo, accent),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isCompact ? 8 : 12),

                // ── HERO CARD ────────────────────────────────────────────
                FadeTransition(
                  opacity: _entranceFade,
                  child: SlideTransition(
                    position: _entranceSlide,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: _HeroLevelCard(
                        primary: primary,
                        accent: accent,
                        neo: neo,
                        bounceAnimation: _bounceAnimation,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: isCompact ? 12 : 16),

                // ── CHALLENGES + streak merged into one slab ─────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: ScaleTransition(
                    scale: _pulseScale,
                    child: _ChallengesButton(primary: primary, accent: accent, neo: neo),
                  ),
                ),

                SizedBox(height: isCompact ? 14 : 20),

                // ── Action buttons ───────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'view_details'.tr,
                          icon: Icons.info_outline_rounded,
                          filled: false,
                          primary: primary,
                          accent: accent,
                          neo: neo,
                          onTap: () => _showLearnMoreBottomSheet(context, neo, accent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          label: 'view_prizes'.tr,
                          icon: Icons.card_giftcard_rounded,
                          filled: true,
                          primary: primary,
                          accent: accent,
                          neo: neo,
                          onTap: () => Get.toNamed(RouteHelper.xpPrizes),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isCompact ? 28 : 36),

                // ── Leaderboard preview (widget has its own header) ───────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: XpLeaderboardPreviewWidget(
                    neoBlack: neo,
                    accentColor: accent,
                    tealBg: primary,
                  ),
                ),

                SizedBox(height: isCompact ? 28 : 36),

                // ── SECTION LABEL: Roadmap ────────────────────────────────
                _SectionLabel(label: 'level_roadmap'.tr, accent: accent, hPad: hPad),
                const SizedBox(height: 12),

                // ── Levels Roadmap ────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: _LevelRoadmapSection(primary: primary, accent: accent),
                ),

                SizedBox(height: isCompact ? 28 : 36),

                // ── SECTION LABEL: History ────────────────────────────────
                _SectionLabel(label: 'recent_activity'.tr, accent: accent, hPad: hPad),
                const SizedBox(height: 12),

                // ── XP History ────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: XpHistoryWidget(
                    neoBlack: deepPrimary,
                    accentColor: accent,
                    tealText: primary,
                  ),
                ),

                SizedBox(height: isCompact ? 36 : 52),
              ],
            ),
          ),
        );
      },
    );

    if (isRamadan) {
      body = RamadanStringLightWrapper(
        showTopString: true,
        showBottomString: false,
        alwaysOn: true,
        metalColor: primary,
        metalShadeColor: deepPrimary,
        lightColor: accent,
        lightSecondaryColor: accent.withValues(alpha: 0.7),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: primary,
      body: SafeArea(child: body),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL — bold accent stripe left-border + huge weight title
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final Color accent;
  final double hPad;

  const _SectionLabel({required this.label, required this.accent, required this.hPad});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Row(
        children: [
          // Accent stripe — flips to trailing side on RTL
          if (!isRtl) ...[
            Container(
              width: 5,
              height: 28,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            // Don't call toUpperCase() — set in translation files for each locale
            label,
            style: robotoBlack.copyWith(
              fontSize: 13,
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ),
          if (isRtl) ...[
            const SizedBox(width: 10),
            Container(
              width: 5,
              height: 28,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV BUTTON — back / info
// ─────────────────────────────────────────────────────────────────────────────
class _NavButton extends StatelessWidget {
  final IconData icon;
  final Color accent, neo;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.accent,
    required this.neo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2.5),
              boxShadow: [BoxShadow(color: neo, offset: const Offset(2, 2), blurRadius: 0)],
            ),
            child: Icon(icon, color: accent, size: 17),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEARN MORE BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
void _showLearnMoreBottomSheet(BuildContext context, Color neo, Color accent) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: neo, width: 3),
        boxShadow: [BoxShadow(color: neo, offset: const Offset(5, 5), blurRadius: 0)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯  ${'how_it_works'.tr}'.toUpperCase(),
            style: robotoBlack.copyWith(fontSize: 18, color: neo, letterSpacing: 1.2),
          ),
          const SizedBox(height: 24),
          _LearnMoreStep(number: '1', title: 'place_orders'.tr, desc: 'every_order_earns_xp'.tr, neo: neo, accent: accent),
          _LearnMoreStep(number: '2', title: 'complete_challenges_step'.tr, desc: 'daily_weekly_bonus_xp'.tr, neo: neo, accent: accent),
          _LearnMoreStep(number: '3', title: 'level_up'.tr, desc: 'reach_new_levels_auto'.tr, neo: neo, accent: accent),
          _LearnMoreStep(number: '4', title: 'get_rewards'.tr, desc: 'free_delivery_discounts_more'.tr, neo: neo, accent: accent),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
}

class _LearnMoreStep extends StatelessWidget {
  final String number, title, desc;
  final Color neo, accent;

  const _LearnMoreStep({
    required this.number,
    required this.title,
    required this.desc,
    required this.neo,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              border: Border.all(color: neo, width: 2.5),
            ),
            child: Center(
              child: Text(number, style: robotoBlack.copyWith(fontSize: 13, color: neo)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: robotoBold.copyWith(fontSize: 14, color: neo)),
                const SizedBox(height: 2),
                Text(desc, style: robotoRegular.copyWith(fontSize: 12, color: const Color(0xFF5A6670))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEO-POP CONTAINER — press feedback
// ─────────────────────────────────────────────────────────────────────────────
class NeoPopContainer extends StatefulWidget {
  final Widget child;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double shadowOffset;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const NeoPopContainer({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.borderColor = Colors.black,
    this.borderWidth = 2.5,
    this.borderRadius = 16,
    this.shadowOffset = 4,
    this.padding,
    this.onTap,
  });

  @override
  State<NeoPopContainer> createState() => _NeoPopContainerState();
}

class _NeoPopContainerState extends State<NeoPopContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _pressAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap != null ? (_) => _pressController.forward() : null,
      onTapUp: widget.onTap != null ? (_) => _pressController.reverse() : null,
      onTapCancel: widget.onTap != null ? () => _pressController.reverse() : null,
      child: AnimatedBuilder(
        animation: _pressAnim,
        builder: (_, child) {
          final offset = widget.shadowOffset * _pressAnim.value;
          return Transform.translate(
            offset: Offset(offset, offset),
            child: Container(
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(color: widget.borderColor, width: widget.borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: widget.borderColor,
                    offset: Offset(
                      widget.shadowOffset * (1 - _pressAnim.value),
                      widget.shadowOffset * (1 - _pressAnim.value),
                    ),
                    blurRadius: 0,
                  ),
                ],
              ),
              padding: widget.padding,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO LEVEL CARD
// ─────────────────────────────────────────────────────────────────────────────
class _HeroLevelCard extends StatelessWidget {
  final Color primary, accent, neo;
  final Animation<double> bounceAnimation;

  const _HeroLevelCard({
    required this.primary,
    required this.accent,
    required this.neo,
    required this.bounceAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width;
    final avatarSize = sw < 360 ? 88.0 : sw > 414 ? 112.0 : 100.0;
    final cardHPad = sw < 360 ? 14.0 : 22.0;

    return GetBuilder<XpController>(
      builder: (xpController) {
        final currentLevelData = xpController.currentLevel;
        final levelName = currentLevelData?.levelName ?? 'Explorer';
        final currentLevel = currentLevelData?.currentLevel ?? 1;
        final nextLevel = currentLevel + 1;
        final currentXp = currentLevelData?.currentXp ?? 0;
        final isMaxLevel = currentLevelData?.isMaxLevelFor(xpController.maxLevel) ?? false;

        final levels = xpController.levelsListModel?.levels ?? [];
        final nextLevelData = levels.firstWhereOrNull((l) => l.level == nextLevel);
        final xpForNextLevel = nextLevelData?.xpRequired
            ?? currentLevelData?.xpForNextLevel
            ?? 200;

        final readyToLevelUp = currentXp >= xpForNextLevel && !isMaxLevel;
        final progressPct = xpForNextLevel > 0
            ? (currentXp / xpForNextLevel * 100).clamp(0.0, 100.0)
            : 0.0;
        final visualProgress = readyToLevelUp
            ? 100.0
            : (progressPct > 0 ? progressPct : 5.0);
        final xpToGo = (xpForNextLevel - currentXp).clamp(0, 999999);

        String nextPrizeTitle = 'Free Delivery';
        if (nextLevelData != null && nextLevelData.prizes.isNotEmpty) {
          nextPrizeTitle = nextLevelData.prizes.first.title;
        }

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // ── White card ──────────────────────────────────────────────
            Container(
              margin: EdgeInsets.only(top: avatarSize / 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: neo, width: 2.5),
                boxShadow: [BoxShadow(color: neo, offset: const Offset(5, 5), blurRadius: 0)],
              ),
              padding: EdgeInsets.fromLTRB(cardHPad, avatarSize * 0.58, cardHPad, 20),
              child: Column(
                children: [
                  // Level name
                  Text(
                    levelName,
                    style: robotoBlack.copyWith(
                      fontSize: sw < 360 ? 20.0 : 24.0,
                      color: neo,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  // "LEVEL X" chip
                  Text(
                    'Level $currentLevel',
                    style: robotoMedium.copyWith(
                      fontSize: 12,
                      color: const Color(0xFF7A8A8E),
                    ),
                  ),

                  SizedBox(height: sw < 360 ? 12 : 16),

                  // ── XP number — bold but not overwhelming ───────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$currentXp',
                        style: robotoBlack.copyWith(
                          fontSize: sw < 360 ? 40.0 : 48.0,
                          color: neo,
                          letterSpacing: -1,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'XP',
                        style: robotoBlack.copyWith(
                          fontSize: 15,
                          color: accent,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  // XP context label
                  Text(
                    isMaxLevel
                        ? '🏆  MAX LEVEL'
                        : readyToLevelUp
                            ? '🎉  ${'ready_to_level_up'.tr}'
                            : '$xpToGo ${'xp_to_go'.tr}',
                    style: (readyToLevelUp ? robotoBold : robotoMedium).copyWith(
                      fontSize: 12,
                      color: readyToLevelUp ? accent : const Color(0xFF7A8A8E),
                    ),
                  ),

                  SizedBox(height: sw < 360 ? 12 : 16),

                  // ── Progress bar ─────────────────────────────────────────
                  _XpProgressBar(
                    visualProgress: visualProgress,
                    accent: accent,
                    neo: neo,
                    readyToLevelUp: readyToLevelUp,
                  ),

                  const SizedBox(height: 8),

                  // Progress label + level pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$currentXp / $xpForNextLevel XP',
                        style: robotoBold.copyWith(fontSize: 12, color: neo),
                      ),
                      if (!isMaxLevel)
                        Row(
                          children: [
                            _LevelPill(level: currentLevel, isActive: true, accent: accent, neo: neo),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.double_arrow_rounded, color: Color(0xFFB0BEC5), size: 16),
                            ),
                            _LevelPill(level: nextLevel, isActive: false, accent: accent, neo: neo),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Next reward box ──────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                    decoration: BoxDecoration(
                      color: readyToLevelUp
                          ? accent.withValues(alpha: 0.12)
                          : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: readyToLevelUp ? accent : neo.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          readyToLevelUp ? '🎉' : '🎁',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: isMaxLevel
                              ? Text(
                                  'max_level_reached'.tr,
                                  style: robotoBold.copyWith(fontSize: 13, color: neo),
                                )
                              : readyToLevelUp
                                  ? Text(
                                      'ready_to_level_up'.tr,
                                      style: robotoBold.copyWith(fontSize: 13, color: neo),
                                    )
                                  : Row(
                                      children: [
                                        Text(
                                          '${'next_label'.tr}: ',
                                          style: robotoMedium.copyWith(fontSize: 12, color: const Color(0xFF7A8A8E)),
                                        ),
                                        Flexible(
                                          child: Text(
                                            nextPrizeTitle,
                                            style: robotoBold.copyWith(fontSize: 13, color: neo),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '  (Lv $nextLevel)',
                                          style: robotoMedium.copyWith(fontSize: 11, color: const Color(0xFF7A8A8E)),
                                        ),
                                      ],
                                    ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Floating avatar — TickerMode pauses when widget is offscreen ──
            AnimatedBuilder(
              animation: bounceAnimation,
              builder: (context, child) => Positioned(
                top: TickerMode.valuesOf(context).enabled ? bounceAnimation.value : 0,
                child: child!,
              ),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(avatarSize * 0.24),
                  border: Border.all(color: neo, width: 3.5),
                  boxShadow: [BoxShadow(color: neo, offset: const Offset(4, 4), blurRadius: 0)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(avatarSize * 0.20),
                  child: currentLevelData?.levelBadge != null
                      ? CustomImage(image: currentLevelData!.levelBadge!, fit: BoxFit.cover)
                      : Image.asset(Images.guest, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL PILL
// ─────────────────────────────────────────────────────────────────────────────
class _LevelPill extends StatelessWidget {
  final int level;
  final bool isActive;
  final Color accent, neo;

  const _LevelPill({
    required this.level,
    required this.isActive,
    required this.accent,
    required this.neo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? accent : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: neo, width: isActive ? 2 : 1.5),
        boxShadow: isActive
            ? [BoxShadow(color: neo, offset: const Offset(2, 2), blurRadius: 0)]
            : null,
      ),
      child: Text(
        'LV $level',
        style: robotoBlack.copyWith(
          fontSize: 11,
          color: isActive ? neo : const Color(0xFF7A8A8E),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// XP PROGRESS BAR — chunky 26px, glows when ready to level up
// ─────────────────────────────────────────────────────────────────────────────
class _XpProgressBar extends StatefulWidget {
  final double visualProgress;
  final Color accent, neo;
  final bool readyToLevelUp;

  const _XpProgressBar({
    required this.visualProgress,
    required this.accent,
    required this.neo,
    required this.readyToLevelUp,
  });

  @override
  State<_XpProgressBar> createState() => _XpProgressBarState();
}

class _XpProgressBarState extends State<_XpProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.readyToLevelUp) _glowController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_XpProgressBar old) {
    super.didUpdateWidget(old);
    if (widget.readyToLevelUp && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!widget.readyToLevelUp && _glowController.isAnimating) {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.readyToLevelUp) return _buildBar(glowAlpha: 0);
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => _buildBar(glowAlpha: _glowAnim.value),
    );
  }

  Widget _buildBar({required double glowAlpha}) {
    return Stack(
      children: [
        // Track — slightly darker so empty portion reads clearly against white card
        Container(
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFFD5D8DC),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: widget.neo.withValues(alpha: 0.3), width: 1.5),
          ),
        ),
        // Fill
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (widget.visualProgress / 100).clamp(0.06, 1.0),
          child: Container(
            height: 26,
            decoration: BoxDecoration(
              color: widget.accent,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: widget.neo.withValues(alpha: 0.4), width: 1.5),
              boxShadow: glowAlpha > 0
                  ? [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: glowAlpha * 0.6),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHALLENGES BUTTON — dramatic full-width slab
// ─────────────────────────────────────────────────────────────────────────────
class _ChallengesButton extends StatelessWidget {
  final Color primary, accent, neo;

  const _ChallengesButton({required this.primary, required this.accent, required this.neo});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        int challengeCount = 0;
        if (xpController.challengeModel != null) {
          challengeCount = xpController.challengeModel!.dailyChallenges.length +
              xpController.challengeModel!.weeklyChallenges.length;
        }

        // Streak data merged in
        final streak = xpController.streak;
        final hasStreak = streak != null && streak.currentStreak > 0;

        final sw = MediaQuery.sizeOf(context).width;
        final vPad = sw < 360 ? 14.0 : sw > 414 ? 20.0 : 17.0;

        // Build secondary line: streak + challenge hint
        String secondaryLine;
        if (hasStreak && challengeCount > 0) {
          secondaryLine = '🔥 ${streak.currentStreak} ${'day_streak'.tr}  ·  ${'complete_challenges_to_earn_xp'.tr}';
        } else if (hasStreak) {
          secondaryLine = '🔥 ${streak.currentStreak} ${'day_streak'.tr}  ·  ${'keep_it_up'.tr}';
        } else {
          secondaryLine = 'complete_challenges_to_earn_xp'.tr;
        }

        return NeoPopContainer(
          onTap: () => Get.toNamed(RouteHelper.xpChallenges),
          color: accent,
          borderColor: neo,
          borderRadius: 20,
          shadowOffset: 6,
          padding: EdgeInsets.symmetric(vertical: vPad, horizontal: 22),
          child: Row(
            children: [
              // Left: icon + text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag_rounded, color: neo, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'challenges'.tr.toUpperCase(),
                          style: robotoBlack.copyWith(
                            fontSize: 16,
                            color: neo,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      secondaryLine,
                      style: robotoMedium.copyWith(
                        fontSize: 11,
                        color: neo.withValues(alpha: 0.65),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: count badge or chevron
              if (challengeCount > 0)
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: neo,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$challengeCount',
                      style: robotoBlack.copyWith(fontSize: 17, color: accent),
                    ),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: neo, size: 26),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BUTTONS — View Details / View Prizes
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final Color primary, accent, neo;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.primary,
    required this.accent,
    required this.neo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width;
    final vPad = sw < 360 ? 11.0 : 14.0;

    // Ghost (unfilled) buttons get no shadow and transparent bg — clear secondary status
    if (!filled) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: vPad, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: robotoMedium.copyWith(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return NeoPopContainer(
      onTap: onTap,
      color: primary,
      borderColor: accent,
      borderRadius: 14,
      shadowOffset: 5,
      borderWidth: 2.5,
      padding: EdgeInsets.symmetric(vertical: vPad, horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: robotoBold.copyWith(fontSize: 14, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL ROADMAP SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _LevelRoadmapSection extends StatelessWidget {
  final Color primary, accent;

  const _LevelRoadmapSection({required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        if (xpController.isLevelsLoading) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(color: accent, strokeWidth: 3),
            ),
          );
        }

        final levelsData = xpController.levelsListModel;
        if (levelsData == null || levelsData.levels.isEmpty) {
          return const SizedBox.shrink();
        }

        return BrilliantRoadmapWidget(
          levels: levelsData.levels,
          currentLevel: levelsData.currentLevel,
          currentXp: xpController.currentLevel?.currentXp ?? 0,
          xpController: xpController,
          themeBg: primary,
          themeAccent: accent,
          themeBlack: primary,
        );
      },
    );
  }
}
