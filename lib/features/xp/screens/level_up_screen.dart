import 'dart:math' as math;
import 'package:waddy_app/util/swallow.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/level_up_event_model.dart';
import 'package:waddy_app/features/xp/widgets/level_up_rive_burst.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';

/// The full-screen "LEVEL UP!" celebration — a native port of Level Up.dc.html.
///
/// Deep-teal foil canvas, falling confetti, the level's medal, tier + level
/// chips, momentum stats, and the reward unlocked this level. The "LEVEL UP!"
/// headline and the XP readout come from the Rive artboard behind it (see
/// [LevelUpRiveBurst]), bound to the user's real numbers rather than drawn
/// twice. Presented via [LevelUpScreen.showQueue], which walks the
/// controller's [XpController.pendingLevelUps] one at a time and acknowledges
/// them on the server as each is dismissed.
class LevelUpScreen extends StatefulWidget {
  final LevelUpEvent event;
  final int? rank;

  const LevelUpScreen({super.key, required this.event, this.rank});

  /// Drain every queued level-up, showing one celebration after another, then
  /// acknowledge them all so they don't replay. Safe to call when the queue is
  /// empty (does nothing). Only call when a route context is available.
  static Future<void> showQueue(XpController xp) async {
    final events = xp.takePendingLevelUps();
    if (events.isEmpty) return;

    // The user's Maadi rank for the middle stat — reuse the leaderboard the
    // screen already loads; null hides the stat gracefully.
    final rank =
        xp.leaderboardModel?.currentUser?.rank ??
        xp.leaderboardModel?.entries.firstWhereOrNull((e) => e.isMe)?.rank;

    for (final event in events) {
      await Get.dialog(
        LevelUpScreen(event: event, rank: rank),
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
    final size = MediaQuery.of(context).size;
    final event = widget.event;

    final streak = _streakDays();

    return Material(
      color: _Lu.foil,
      child: Stack(
        children: [
          // The Rive celebration sits furthest back. It owns the "Level up!"
          // headline and the Current XP / Next level readout — bound to the
          // user's real numbers — so this screen deliberately does not draw
          // its own copies of those; the confetti rains over the top.
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
                  // if (event.rewardName != null) ...[
                  //   _FadeUp(
                  //     delayMs: 650,
                  //     child: _RewardUnlockedChip(rewardName: event.rewardName!),
                  //   ),
                  //   const SizedBox(height: Dimensions.paddingSizeDefault),
                  // ],
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
      final level = Get.find<XpController>().currentLevel;
      final next = level?.nextLevel?.xpRequired;
      if (next != null && next > 0) return next;
    } catch (e, s) {
      swallow('read next-level XP target', e, s);
    }
    return widget.event.totalXp;
  }

  int _streakDays() {
    try {
      return Get.find<XpController>().streak?.currentStreak ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME (matches the XP design tokens)
// ─────────────────────────────────────────────────────────────────────────────
class _Lu {
  _Lu._();
  static const Color mint = Color(0xFF1EF2A0);
  static const Color teal = Color(0xFF134E4A);
  static const Color foil = Color(0xFF0B2A27);
  static const Color border = Color(0xFF134E4A);
  static const Color red = Color(0xFFFF3B30);
  static const Color green = Color(0xFF22C55E);
}

String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDAL — the level badge, framed in teal with a mint ring + glow
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// TIER NAME + LEVEL
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// REWARD UNLOCKED — the prize this level grants, in the mint/teal card
// language established by _KeepGoingButton (hard border + drop shadow).
// ─────────────────────────────────────────────────────────────────────────────
class _RewardUnlockedChip extends StatelessWidget {
  final String rewardName;
  const _RewardUnlockedChip({required this.rewardName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical:
            Dimensions.paddingSizeSmall + Dimensions.paddingSizeExtraSmall,
      ),

      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${'level_up_your_reward'.tr} : ',
              style: waddyBold.copyWith(
                fontSize: 15,
                color: _Lu.mint,
                height: 1.2,
              ),
            ),
            TextSpan(
              text: rewardName,
              style: waddyBlack.copyWith(
                fontSize: 15,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
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

class _Pop extends StatefulWidget {
  final int delayMs;
  final Widget child;
  const _Pop({required this.delayMs, required this.child});

  @override
  State<_Pop> createState() => _PopState();
}

class _PopState extends State<_Pop> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
        final t = Curves.easeOutBack.transform(_c.value);
        return Opacity(
          opacity: (_c.value * 1.5).clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.5 + 0.5 * t, child: child),
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFETTI — lightweight painted field, respects reduced-motion
// ─────────────────────────────────────────────────────────────────────────────
class _ConfettiField extends StatefulWidget {
  final double height;
  const _ConfettiField({required this.height});

  @override
  State<_ConfettiField> createState() => _ConfettiFieldState();
}

class _ConfettiFieldState extends State<_ConfettiField>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_Conf> _pieces = [];
  double _t = 0;

  static const _colors = [_Lu.mint, _Lu.red, _Lu.green, Colors.white];

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    for (var i = 0; i < 26; i++) {
      _pieces.add(
        _Conf(
          left: rnd.nextDouble(),
          color: _colors[i % _colors.length],
          duration: 2.0 + rnd.nextDouble() * 2.2,
          delay: (i % 8) * 0.15,
          drift: (rnd.nextDouble() - 0.5) * 0.06,
          size: 6 + rnd.nextDouble() * 4,
        ),
      );
    }
    _ticker = createTicker((elapsed) {
      setState(() => _t = elapsed.inMilliseconds / 1000.0);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: _ConfettiPainter(
        pieces: _pieces,
        t: _t,
        fieldHeight: widget.height,
      ),
      size: Size.infinite,
    );
  }
}

class _Conf {
  final double left; // 0..1 horizontal start
  final Color color;
  final double duration; // seconds for a full fall
  final double delay; // seconds
  final double drift; // horizontal drift per cycle (fraction of width)
  final double size;
  const _Conf({
    required this.left,
    required this.color,
    required this.duration,
    required this.delay,
    required this.drift,
    required this.size,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Conf> pieces;
  final double t;
  final double fieldHeight;

  _ConfettiPainter({
    required this.pieces,
    required this.t,
    required this.fieldHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final c in pieces) {
      final localT = ((t - c.delay) / c.duration);
      if (localT < 0) continue;
      final cycle = localT % 1.0;
      final y = -40 + cycle * (size.height + 80);
      final x = (c.left + c.drift * cycle) * size.width;
      // Fade in at the top, out near the bottom.
      final opacity =
          cycle < 0.08
              ? cycle / 0.08
              : (cycle > 0.9 ? (1 - (cycle - 0.9) / 0.1) : 1.0);
      paint.color = c.color.withValues(alpha: (0.9 * opacity).clamp(0.0, 1.0));
      final angle = cycle * 2 * math.pi + c.left * 6;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: c.size,
            height: c.size * 1.7,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
