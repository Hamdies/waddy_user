import 'package:waddy_app/util/swallow.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/level_up_event_model.dart';
import 'package:waddy_app/features/xp/widgets/level_up_rive_burst.dart';
import 'package:waddy_app/features/xp/widgets/xp_tokens.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/features/xp/domain/models/prize_kind.dart';
import 'package:waddy_app/features/xp/widgets/prize_visual.dart';

/// The full-screen "LEVEL UP!" celebration.
///
/// The "LEVEL UP!" headline and the XP readout come from the Rive artboard
/// behind it (see [LevelUpRiveBurst]), bound to the user's real numbers. Over
/// it, in Flutter text so it localizes without a `.riv` change: the name of
/// the level reached and the reward it unlocked (X-05). Presented via
/// [LevelUpScreen.showQueue], which walks the controller's
/// [XpController.pendingLevelUps] one at a time and acknowledges them on the
/// server once all are dismissed.
class LevelUpScreen extends StatefulWidget {
  final LevelUpEvent event;

  const LevelUpScreen({super.key, required this.event});

  /// Drain every queued level-up, showing one celebration after another, then
  /// acknowledge them all so they don't replay. Safe to call when the queue is
  /// empty (does nothing). Only call when a route context is available.
  static Future<void> showQueue(XpController xp) async {
    final events = xp.takePendingLevelUps();
    if (events.isEmpty) return;

    for (final event in events) {
      await Get.dialog(
        LevelUpScreen(event: event),
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        useSafeArea: false,
      );
    }

    await xp.acknowledgeLevelUps(events.map((e) => e.transactionId).toList());
  }

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen> {
  final GlobalKey<LevelUpRiveBurstState> _burstKey =
      GlobalKey<LevelUpRiveBurstState>();

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final levelName = event.levelName;
    final rewardName = event.rewardName;

    return Material(
      color: XpTokens.foil,
      child: Stack(
        children: [
          // The Rive celebration sits furthest back. It owns the "Level up!"
          // headline and the Current XP / Next level readout — bound to the
          // user's real numbers — so this screen does not draw its own copies.
          Positioned.fill(
            child: LevelUpRiveBurst(
              key: _burstKey,
              level: event.level,
              currentXp: event.totalXp,
              nextLevelXp: _nextLevelXp(),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  // The artboard says "level 3"; this says what level 3 *is*.
                  if (levelName != null)
                    _FadeUp(
                      delayMs: 450,
                      child: Text(
                        levelName,
                        textAlign: TextAlign.center,
                        style: waddyBlack.copyWith(
                          fontSize: 26,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  if (rewardName != null) ...[
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                    _FadeUp(
                      delayMs: 650,
                      child: _RewardUnlockedChip(
                        rewardName: rewardName,
                        rewardType: event.rewardType,
                      ),
                    ),
                  ],
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  _KeepGoingButton(onTap: () => Get.back()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The XP threshold for the *next* level, for the artboard's "Next level at"
  /// readout. The level-up event itself only carries the level just reached, so
  /// this comes off the controller. Falls back to the user's current total so
  /// the animation never advertises a target of 0 XP.
  int _nextLevelXp() {
    try {
      final xp = Get.find<XpController>();
      // With several level-ups queued, the controller's "next level" is the
      // one after the *last*; read the one after this event's level instead.
      final next =
          xp.levelsListModel?.levels
              .where((l) => l.level == widget.event.level + 1)
              .firstOrNull
              ?.xpRequired;
      if (next != null && next > 0) return next;
      final fallback = xp.currentLevel?.nextLevel?.xpRequired;
      if (fallback != null && fallback > 0) return fallback;
    } catch (e, s) {
      swallow('read next-level XP target', e, s);
    }
    return widget.event.totalXp;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────
class _Lu {
  _Lu._();
  static const Color mint = XpTokens.mint;
  static const Color teal = XpTokens.teal;
  static const Color border = XpTokens.teal;
}

// ─────────────────────────────────────────────────────────────────────────────
// REWARD UNLOCKED — the prize this level grants
// ─────────────────────────────────────────────────────────────────────────────
class _RewardUnlockedChip extends StatelessWidget {
  final String rewardName;
  final String? rewardType;
  const _RewardUnlockedChip({required this.rewardName, this.rewardType});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeMedium,
      ),
      decoration: BoxDecoration(
        color: _Lu.mint.withValues(alpha: 0.12),
        border: Border.all(color: _Lu.mint, width: 2),
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(PrizeKind.parse(rewardType).icon, color: _Lu.mint, size: 26),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'level_up_your_reward'.tr,
                  style: waddyBold.copyWith(
                    fontSize: 12,
                    color: _Lu.mint,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rewardName,
                  style: waddyBlack.copyWith(
                    fontSize: 16,
                    color: Colors.white,
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
// KEEP GOING — dismiss button
// ─────────────────────────────────────────────────────────────────────────────
class _KeepGoingButton extends StatefulWidget {
  final VoidCallback onTap;
  const _KeepGoingButton({required this.onTap});

  @override
  State<_KeepGoingButton> createState() => _KeepGoingButtonState();
}

class _KeepGoingButtonState extends State<_KeepGoingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: double.infinity,
        transform: Matrix4.translationValues(
          _pressed ? 3 : 0,
          _pressed ? 3 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: _Lu.mint,
          border: Border.all(color: _Lu.border, width: 3),
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          boxShadow:
              _pressed
                  ? null
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ],
        ),
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeDefault,
        ),
        alignment: Alignment.center,
        child: Text(
          'waddy'.tr,
          style: waddyBlack.copyWith(
            fontSize: 18,
            color: _Lu.teal,
            letterSpacing: 0.07 * 18,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRANCE HELPERS — staggered fade-up / pop, honouring reduced-motion
// ─────────────────────────────────────────────────────────────────────────────
class _FadeUp extends StatefulWidget {
  final int delayMs;
  final Widget child;
  const _FadeUp({required this.delayMs, required this.child});

  @override
  State<_FadeUp> createState() => _FadeUpState();
}

class _FadeUpState extends State<_FadeUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeOut.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
