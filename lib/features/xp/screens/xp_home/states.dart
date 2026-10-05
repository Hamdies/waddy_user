part of '../xp_levels_screen.dart';

// Loading, signed-out and error states, and the debug level-up trigger.

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
            const XpLottieOnce(asset: XpMotion.rewardsHero, size: 96),
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
      LevelUpScreen(event: event),
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
