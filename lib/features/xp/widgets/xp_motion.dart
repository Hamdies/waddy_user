import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:rive/rive.dart';
import 'package:waddy_app/features/xp/domain/models/prize_kind.dart';

// ─────────────────────────────────────────────────────────────────────────────
// XP MOTION — animated icons for XP home, Rewards and Quests (XM-01..XM-06)
// ─────────────────────────────────────────────────────────────────────────────
//
// Every animation file the XP surfaces use is named HERE and nowhere else. To
// swap an icon, change its file or artboard in [XpIcon] / [XpMotion]; nothing
// else needs to change. A file or artboard that fails to load falls back to
// the Material glyph the widget was given, so a bad swap degrades, never
// breaks.
//
// The motion budget (XM-06), enforced by how the widgets below are used:
//   • one loop per screen: the streak flame. Nothing here loops by itself.
//   • everything else plays once — on reveal, when its state turns good, on a
//     claim.
//   • motion means good news: locked / used / expired rows and error states
//     stay static Material glyphs.
//   • reduced motion: the static glyph, never an animation.

/// Files that are not one-icon-per-artboard.
class XpMotion {
  XpMotion._();

  /// The icon set: one artboard per icon (see [XpIcon]).
  static const String iconSet = 'assets/animation/interactive_icon_set.riv';

  /// Next-reward tile and the empty Rewards screen.
  static const String giftBox = 'assets/animation/gift_box.riv';

  /// One-shot coin burst: "+N XP just earned", a claimed reward.
  static const String coinBurst = 'assets/animation/waddi_coins.json';

  /// Signed-out XP home.
  static const String rewardsHero = 'assets/animation/bottom_nav/rewards.json';

  /// The state machine and the input that plays an icon. The icon set's
  /// artboards each ship `State Machine 1` with a hold-style `Boolean 1`.
  static const String stateMachine = 'State Machine 1';
  static const String playInput = 'Boolean 1';

  /// How long the play input is held before it is released.
  static const Duration playHold = Duration(milliseconds: 1200);

  /// Gap between icons revealed together, so a list doesn't fire in unison.
  static const Duration stagger = Duration(milliseconds: 80);
}

/// Every animated icon on the XP surfaces: file + artboard. The one table.
enum XpIcon {
  crown(XpMotion.iconSet, '21_Crown', Icons.emoji_events_outlined),
  coin(XpMotion.iconSet, '23_Coin', Icons.shopping_bag_outlined),
  flash(XpMotion.iconSet, '03_Flash', Icons.local_shipping_outlined),
  diamond(XpMotion.iconSet, '06_Diamon', Icons.sell_outlined),
  star(XpMotion.iconSet, '01_Star', Icons.star_outline_rounded),
  starAlt(XpMotion.iconSet, '42_Star 2', Icons.emoji_events_outlined),
  heart(XpMotion.iconSet, '02_Heart', Icons.favorite_border_rounded),
  fire(XpMotion.iconSet, '26_Fire', Icons.local_fire_department_outlined),

  /// Default artboard and state machine; it has no play input.
  gift(XpMotion.giftBox, null, Icons.redeem_outlined);

  final String asset;

  /// Null selects the file's default artboard.
  final String? artboard;

  /// The static glyph when no other fallback is given.
  final IconData glyph;

  const XpIcon(this.asset, this.artboard, this.glyph);

  /// The icon for a prize kind (XM-02).
  static XpIcon forPrize(PrizeKind kind) {
    switch (kind) {
      case PrizeKind.freeDelivery:
        return XpIcon.flash;
      case PrizeKind.discount:
        return XpIcon.diamond;
      case PrizeKind.walletCredit:
        return XpIcon.coin;
      case PrizeKind.badge:
        return XpIcon.crown;
      case PrizeKind.other:
        return XpIcon.starAlt;
    }
  }

  /// The icon for a quest's `challenge_type`, or null for a type with no
  /// mapping (the card then keeps the backend's emoji).
  static XpIcon? forChallengeType(String type) {
    switch (type) {
      case 'complete_order':
      case 'multiple_orders':
        return XpIcon.coin;
      case 'min_order_amount':
        return XpIcon.diamond;
      case 'new_store':
        return XpIcon.star;
      default:
        return null;
    }
  }
}

/// One animated icon that plays once, never loops on its own, and falls back
/// to [fallback] while loading, on failure, and under reduced motion.
class XpRiveIcon extends StatefulWidget {
  final XpIcon icon;
  final double size;

  /// Shown while loading, on failure and under reduced motion. Defaults to
  /// the icon's own [XpIcon.glyph].
  final IconData? fallback;
  final Color fallbackColor;

  /// Play once this long after it loads. Null: wait for [playWhen].
  final Duration? playOnReveal;

  /// Plays whenever this value changes — pass the state that should
  /// celebrate (e.g. "ready", a claim count). Null never plays on change.
  final Object? playWhen;

  const XpRiveIcon({
    super.key,
    required this.icon,
    required this.fallbackColor,
    this.fallback,
    this.size = 24,
    this.playOnReveal = Duration.zero,
    this.playWhen,
  });

  @override
  State<XpRiveIcon> createState() => _XpRiveIconState();
}

class _XpRiveIconState extends State<XpRiveIcon> {
  /// One loader per file for the session. The icon set is one 800 KB file
  /// shared by every icon on screen; a loader per widget would decode it once
  /// per row. The builder never disposes a loader it was given, and these
  /// live as long as the app, so they are never disposed either.
  static final Map<String, FileLoader> _loaders = {};

  FileLoader get _loader => _loaders.putIfAbsent(
    widget.icon.asset,
    () => FileLoader.fromAsset(widget.icon.asset, riveFactory: Factory.rive),
  );

  RiveWidgetController? _controller;
  bool _failed = false;
  Timer? _reveal;
  Timer? _release;

  void _onLoaded(RiveLoaded state) {
    _controller = state.controller;
    final delay = widget.playOnReveal;
    if (delay != null) {
      _reveal = Timer(delay, _play);
    }
  }

  /// Hold the play input, then release it. The input is a native object, so
  /// it is fetched and disposed per write rather than kept: the builder
  /// disposes the controller (and its state machine) before this state.
  void _play() {
    if (!_set(true)) return;
    _release?.cancel();
    _release = Timer(XpMotion.playHold, () => _set(false));
  }

  bool _set(bool value) {
    final controller = _controller;
    if (!mounted || controller == null) return false;
    // Deprecated in favour of data binding, but these files expose a real
    // state-machine input, not a view model (see rive-014-api).
    // ignore: deprecated_member_use
    final input = controller.stateMachine.boolean(XpMotion.playInput);
    if (input == null) return false;
    input.value = value;
    input.dispose();
    return true;
  }

  @override
  void didUpdateWidget(covariant XpRiveIcon old) {
    super.didUpdateWidget(old);
    if (widget.icon != old.icon) {
      _controller = null;
      _failed = false;
    } else if (widget.playWhen != old.playWhen && widget.playWhen != null) {
      _play();
    }
  }

  @override
  void dispose() {
    _reveal?.cancel();
    _release?.cancel();
    super.dispose();
  }

  Widget get _static => Icon(
    widget.fallback ?? widget.icon.glyph,
    size: widget.size * 0.75,
    color: widget.fallbackColor,
  );

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_failed || MediaQuery.of(context).disableAnimations) {
      child = _static;
    } else {
      final artboard = widget.icon.artboard;
      child = RiveWidgetBuilder(
        key: ValueKey(widget.icon),
        fileLoader: _loader,
        artboardSelector:
            artboard != null
                ? ArtboardSelector.byName(artboard)
                : ArtboardSelector.byDefault(),
        stateMachineSelector:
            widget.icon.artboard != null
                ? StateMachineSelector.byName(XpMotion.stateMachine)
                : StateMachineSelector.byDefault(),
        onLoaded: _onLoaded,
        onFailed: (error, _) {
          debugPrint('XpRiveIcon ${widget.icon.name} failed: $error');
          if (mounted) setState(() => _failed = true);
        },
        builder:
            (context, state) => switch (state) {
              RiveLoaded() => RiveWidget(
                controller: state.controller,
                fit: Fit.contain,
              ),
              // Loading: the glyph, so the slot never flashes empty.
              _ => _static,
            },
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(child: child),
    );
  }
}

/// A Lottie that plays once and stops on its last frame. Nothing under
/// reduced motion — every caller pairs it with real text.
class XpLottieOnce extends StatelessWidget {
  final String asset;
  final double size;
  final Duration delay;

  const XpLottieOnce({
    super.key,
    required this.asset,
    required this.size,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return SizedBox(width: size, height: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child: _DelayedLottie(asset: asset, delay: delay),
    );
  }
}

class _DelayedLottie extends StatefulWidget {
  final String asset;
  final Duration delay;
  const _DelayedLottie({required this.asset, required this.delay});

  @override
  State<_DelayedLottie> createState() => _DelayedLottieState();
}

class _DelayedLottieState extends State<_DelayedLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _start;

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      widget.asset,
      controller: _c,
      fit: BoxFit.contain,
      repeat: false,
      onLoaded: (composition) {
        _c.duration = composition.duration;
        _start = Timer(widget.delay, () {
          if (mounted) _c.forward(from: 0);
        });
      },
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
