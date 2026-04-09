import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/widgets/brilliant_roadmap_widget.dart';
import 'package:waddy_app/features/xp/widgets/streak_badge_widget.dart';
import 'package:waddy_app/features/xp/widgets/xp_history_widget.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _initXpData();
  }

  Future<void> _initXpData() async {
    try {
      final controller = Get.find<XpController>();
      await controller.getLevelDetails();
      controller.getChallenges();
      controller.getHistory();
    } catch (e) {
      debugPrint("XpController not found: $e");
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  // --- RAMADAN DETECTION ---
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
            Icon(Icons.wifi_off_rounded, size: 48, color: accent.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'failed_to_load'.tr,
              style: robotoBold.copyWith(fontSize: 18, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'pull_to_retry'.tr,
              style: robotoRegular.copyWith(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _initXpData(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: black, width: 2.5),
                  boxShadow: [BoxShadow(color: black, offset: const Offset(3, 3), blurRadius: 0)],
                ),
                child: Text(
                  'retry'.tr,
                  style: robotoBold.copyWith(fontSize: 14, color: black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- RAMADAN DECORATIVE HEADER ---
  Widget _buildRamadanHeader(Color bg, Color accent, Color textSec) {
    final darkerBg = HSLColor.fromColor(bg).withLightness(
      (HSLColor.fromColor(bg).lightness - 0.05).clamp(0.0, 1.0),
    ).toColor();

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
         SizedBox(height: 22),
          Text(
            'ramadan_kareem'.tr,
            style: robotoBold.copyWith(
              fontSize: 22,
              color: accent,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'earn_extra_blessings'.tr,
            style: robotoRegular.copyWith(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Decorative lanterns row
         
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRamadan = _isRamadan;
    final theme = Theme.of(context);

    // --- All colors derived from brand theme ---
    final Color primary = theme.primaryColor;              // dark teal
    final Color accent = theme.colorScheme.secondary;      // neon green
    final Color deepPrimary = HSLColor.fromColor(primary)
        .withLightness((HSLColor.fromColor(primary).lightness - 0.06).clamp(0.0, 1.0))
        .toColor();
    final Color neo = deepPrimary; // neo-pop border & shadow color

    Widget body = GetBuilder<XpController>(
      builder: (xpController) {
        if (xpController.currentLevel == null && !xpController.isLevelLoading) {
          return _buildErrorState(accent, primary);
        }

        return RefreshIndicator(
          color: accent,
          backgroundColor: primary,
          onRefresh: () => _initXpData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Ramadan decorative header
                if (isRamadan)
                  _buildRamadanHeader(primary, accent, Colors.white70)
                else
                  const SizedBox(height: 20),

                // Top bar: Leaderboard + Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Leaderboard button — neo-pop
                      GestureDetector(
                        onTap: () => Get.toNamed(RouteHelper.xpLeaderboard),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: neo, width: 2.5),
                            boxShadow: [BoxShadow(color: neo, offset: const Offset(3, 3), blurRadius: 0)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events_rounded, size: 16, color: neo),
                              const SizedBox(width: 5),
                              Text(
                                'leaderboard'.tr,
                                style: robotoBold.copyWith(fontSize: 12, color: neo),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      _InfoIconButton(accent: accent, neo: neo),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 1. Main Profile Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _NeoLevelProgressCard(
                    primary: primary,
                    accent: accent,
                    neo: neo,
                    bounceAnimation: _bounceAnimation,
                  ),
                ),

                const SizedBox(height: 14),

                // Streak Badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: StreakBadgeWidget(
                    neoBlack: deepPrimary,
                    accentColor: accent,
                  ),
                ),

                const SizedBox(height: 20),

                // 2. PRIMARY CTA - Challenges
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ChallengesButton(primary: primary, accent: accent, neo: neo),
                ),

                const SizedBox(height: 20),

                // Action buttons row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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

                const SizedBox(height: 28),

                // 5. Levels Roadmap
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _LevelRoadmapSection(
                    primary: primary,
                    accent: accent,
                  ),
                ),

                const SizedBox(height: 28),

                // 6. Recent Activity (XP History)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: XpHistoryWidget(
                    neoBlack: deepPrimary,
                    accentColor: accent,
                    tealText: primary,
                  ),
                ),

                const SizedBox(height: 40),
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

// -----------------------------------------------------------------------------
// INFO ICON BUTTON
// -----------------------------------------------------------------------------
class _InfoIconButton extends StatelessWidget {
  final Color accent, neo;

  const _InfoIconButton({required this.accent, required this.neo});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLearnMoreBottomSheet(context, neo, accent),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 2.5),
          boxShadow: [BoxShadow(color: neo, offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Icon(Icons.info_outline_rounded, color: accent, size: 18),
      ),
    );
  }
}

// Top-level function for showing learn more bottom sheet
void _showLearnMoreBottomSheet(
  BuildContext context,
  Color neo,
  Color accent,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: neo, width: 3),
        boxShadow: [BoxShadow(color: neo, offset: const Offset(4, 4), blurRadius: 0)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🎯 ${'how_it_works'.tr}', style: robotoBold.copyWith(fontSize: 20, color: neo)),
          const SizedBox(height: 20),
          _LearnMoreStep(number: '1', title: 'place_orders'.tr, desc: 'every_order_earns_xp'.tr, neo: neo, accent: accent),
          _LearnMoreStep(number: '2', title: 'complete_challenges_step'.tr, desc: 'daily_weekly_bonus_xp'.tr, neo: neo, accent: accent),
          _LearnMoreStep(number: '3', title: 'level_up'.tr, desc: 'reach_new_levels_auto'.tr, neo: neo, accent: accent),
          _LearnMoreStep(number: '4', title: 'get_rewards'.tr, desc: 'free_delivery_discounts_more'.tr, neo: neo, accent: accent),
          const SizedBox(height: 10),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              border: Border.all(color: neo, width: 2),
            ),
            child: Center(
              child: Text(number, style: robotoBold.copyWith(fontSize: 13, color: neo)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: robotoBold.copyWith(fontSize: 14, color: neo)),
                Text(desc, style: robotoRegular.copyWith(fontSize: 12, color: const Color(0xFF5A6670))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// NEO-POP CONTAINER (kept for external usage)
// -----------------------------------------------------------------------------
class NeoPopContainer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(color: borderColor, offset: Offset(shadowOffset, shadowOffset), blurRadius: 0),
          ],
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. LEVEL PROGRESS CARD — Brand teal/neon style
// -----------------------------------------------------------------------------
class _NeoLevelProgressCard extends StatelessWidget {
  final Color primary, accent, neo;
  final Animation<double> bounceAnimation;

  const _NeoLevelProgressCard({
    required this.primary,
    required this.accent,
    required this.neo,
    required this.bounceAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        final currentLevelData = xpController.currentLevel;
        final levelName = currentLevelData?.levelName ?? 'Explorer';
        final currentLevel = currentLevelData?.currentLevel ?? 1;
        final nextLevel = currentLevel + 1;
        final currentXp = currentLevelData?.currentXp ?? 0;
        final isMaxLevel = currentLevelData?.isMaxLevelFor(xpController.maxLevel) ?? false;

        // Use the next level's absolute xpRequired from the levels list
        // so the progress card is consistent with the roadmap.
        final levels = xpController.levelsListModel?.levels ?? [];
        final nextLevelData = levels.firstWhereOrNull(
          (l) => l.level == nextLevel,
        );
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
            // Neo-pop card
            Container(
              margin: const EdgeInsets.only(top: 50),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: neo, width: 2.5),
                boxShadow: [BoxShadow(color: neo, offset: const Offset(5, 5), blurRadius: 0)],
              ),
              padding: const EdgeInsets.fromLTRB(20, 55, 20, 22),
              child: Column(
                children: [
                  Text(
                    levelName,
                    style: robotoBold.copyWith(fontSize: 22, color: neo),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Level $currentLevel',
                    style: robotoMedium.copyWith(fontSize: 13, color: const Color(0xFF5A6670)),
                  ),
                  const SizedBox(height: 18),

                  // REWARD BOX — neo-pop inner box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: readyToLevelUp
                          ? accent.withValues(alpha: 0.15)
                          : Color.lerp(primary, Colors.white, 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: readyToLevelUp ? accent : neo,
                        width: 2,
                      ),
                    ),
                    child: isMaxLevel
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('👑 ', style: TextStyle(fontSize: 18)),
                              Text(
                                'max_level_reached'.tr,
                                style: robotoBold.copyWith(fontSize: 16, color: neo),
                              ),
                            ],
                          )
                        : readyToLevelUp
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🎉 ', style: TextStyle(fontSize: 18)),
                                  Text(
                                    'ready_to_level_up'.tr,
                                    style: robotoBold.copyWith(fontSize: 16, color: neo),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🎁 ', style: TextStyle(fontSize: 18)),
                                  Text('${'next_label'.tr} ', style: robotoMedium.copyWith(fontSize: 14, color: const Color(0xFF5A6670))),
                                  Flexible(
                                    child: Text(
                                      nextPrizeTitle,
                                      style: robotoBold.copyWith(fontSize: 16, color: neo),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(' (Lv $nextLevel)', style: robotoMedium.copyWith(fontSize: 12, color: const Color(0xFF5A6670))),
                                ],
                              ),
                  ),

                  const SizedBox(height: 18),

                  // Level badges — neo-pop
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LevelPill(level: currentLevel, isActive: true, accent: accent, neo: neo),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(Icons.double_arrow_rounded, color: const Color(0xFF5A6670), size: 22),
                      ),
                      _LevelPill(level: nextLevel, isActive: false, accent: accent, neo: neo),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Progress Bar — neo-pop with bold border
                  Stack(
                    children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: neo, width: 2),
                        ),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (visualProgress / 100).clamp(0.08, 1.0),
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: neo, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$currentXp / $xpForNextLevel XP',
                        style: robotoBold.copyWith(fontSize: 14, color: neo),
                      ),
                      Text(
                        isMaxLevel
                            ? '🏆 MAX'
                            : readyToLevelUp
                                ? '🎉 Level Up!'
                                : '$xpToGo ${'xp_to_go'.tr}',
                        style: robotoMedium.copyWith(
                          fontSize: 12,
                          color: readyToLevelUp ? accent : const Color(0xFF5A6670),
                          fontWeight: readyToLevelUp ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Floating Avatar — neo-pop
            AnimatedBuilder(
              animation: bounceAnimation,
              builder: (context, child) {
                return Positioned(
                  top: bounceAnimation.value,
                  child: Container(
                    width: 95,
                    height: 95,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: neo, width: 3),
                      boxShadow: [BoxShadow(color: neo, offset: const Offset(3, 3), blurRadius: 0)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: currentLevelData?.levelBadge != null
                          ? CustomImage(image: currentLevelData!.levelBadge!, fit: BoxFit.cover)
                          : Image.asset(Images.guest, fit: BoxFit.cover),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? accent : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: neo, width: 2),
        boxShadow: isActive
            ? [BoxShadow(color: neo, offset: const Offset(2, 2), blurRadius: 0)]
            : null,
      ),
      child: Text(
        'LV $level',
        style: robotoBold.copyWith(
          fontSize: 13,
          color: isActive ? neo : const Color(0xFF5A6670),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. CHALLENGES BUTTON — Neo-pop CTA
// -----------------------------------------------------------------------------
class _ChallengesButton extends StatelessWidget {
  final Color primary, accent, neo;

  const _ChallengesButton({required this.primary, required this.accent, required this.neo});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        int challengeCount = 0;
        if (xpController.challengeModel != null) {
          challengeCount =
              xpController.challengeModel!.dailyChallenges.length +
              xpController.challengeModel!.weeklyChallenges.length;
        }

        return NeoPopContainer(
          onTap: () => Get.toNamed(RouteHelper.xpChallenges),
          color: accent,
          borderColor: neo,
          borderRadius: 16,
          shadowOffset: 5,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_rounded, color: neo, size: 24),
                  const SizedBox(width: 10),
                  Text('challenges'.tr, style: robotoBold.copyWith(fontSize: 16, color: neo)),
                  if (challengeCount > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: neo,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$challengeCount',
                        style: robotoBold.copyWith(fontSize: 13, color: accent),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'complete_challenges_to_earn_xp'.tr,
                style: robotoMedium.copyWith(fontSize: 12, color: neo.withValues(alpha: 0.7)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// 4. ACTION BUTTON — Neo-pop (View Details / View Prizes)
// -----------------------------------------------------------------------------
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
    return NeoPopContainer(
      onTap: onTap,
      color: filled ? primary : const Color(0xFFF5F5F5),
      borderColor: filled ? accent : neo,
      borderRadius: 12,
      shadowOffset: filled ? 4 : 2,
      borderWidth: filled ? 2.5 : 2,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: filled ? Colors.white : const Color(0xFF5A6670), size: filled ? 20 : 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: (filled ? robotoBold : robotoMedium).copyWith(
              fontSize: filled ? 14 : 13,
              color: filled ? Colors.white : const Color(0xFF5A6670),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. LEVELS ROADMAP
// -----------------------------------------------------------------------------
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
              child: CircularProgressIndicator(color: accent),
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
