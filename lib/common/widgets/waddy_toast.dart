import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// The app's one toast: a pill that drops in under the status bar.
///
/// ## Why not SnackBar
///
/// Both previous paths were expensive per frame. A Material 3 floating
/// `SnackBar` animates by interpolating its HEIGHT (`Align(heightFactor)`
/// inside snack_bar.dart), so the bar and the Scaffold's layout delegate
/// relayout on every frame of the entrance, and the old toast body ran a second
/// slide on top of that. `GetSnackBar` pushed a whole overlay route per toast.
///
/// This is one [OverlayEntry] on the root navigator. The pill is laid out
/// once, cached behind a [RepaintBoundary], and the entrance moves it with
/// translate + opacity only — compositor work, no layout or repaint per frame.
///
/// ## Why the top
///
/// The bottom of the screen is owned by whatever the current page pins there —
/// the cart bar (which IS the nav on food/grocery), the checkout button, the
/// keyboard — and an overlay cannot know how tall any of those are. The old
/// bars guessed with fixed offsets (100, 96 + inset) and still covered them on
/// some screens. The top edge is the same on every page.
///
/// ## Replace, don't queue
///
/// A new toast while one is showing swaps the text in place and restarts the
/// timer. A parallel fan-out of failing reads used to stack a queue of bars
/// that blocked the screen for ~14s (docs/snackbar_noise_plan.md).
class WaddyToast {
  WaddyToast._();

  static OverlayEntry? _entry;
  static final GlobalKey<_ToastHostState> _hostKey =
      GlobalKey<_ToastHostState>();

  static void show(
    String message, {
    bool isError = false,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (message.isEmpty) return;
    final _ToastData data = _ToastData(
      message: message,
      isError: isError,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );

    final _ToastHostState? host = _hostKey.currentState;
    if (_entry != null && host != null && host.mounted) {
      host.replace(data);
      return;
    }

    // No navigator means no tree to attach to (fired during teardown or before
    // the first route). Dropping the toast beats crashing.
    final OverlayState? overlay = Get.key.currentState?.overlay;
    if (overlay == null) return;

    _entry?.remove();
    final OverlayEntry entry = OverlayEntry(
      builder: (_) => _ToastHost(key: _hostKey, initial: data, onGone: _remove),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Slides the current toast out, if there is one.
  static void hide() => _hostKey.currentState?.dismiss();

  static void _remove() {
    _entry?.remove();
    _entry = null;
  }
}

class _ToastData {
  final String message;
  final bool isError;
  final IconData? icon;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ToastData({
    required this.message,
    required this.isError,
    required this.icon,
    required this.duration,
    required this.actionLabel,
    required this.onAction,
  });
}

class _ToastHost extends StatefulWidget {
  final _ToastData initial;
  final VoidCallback onGone;

  const _ToastHost({super.key, required this.initial, required this.onGone});

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late _ToastData _data = widget.initial;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WaddyMotion.enter,
    reverseDuration: WaddyMotion.fast,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: WaddyMotion.easeOut,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.6),
    end: Offset.zero,
  ).animate(_curve);

  Timer? _timer;

  /// Live drag distance while the finger is on the pill. Upward only — the
  /// gesture is "flick it away", and pulling it down has nowhere to go.
  double _dragY = 0;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _startTimer();
  }

  void replace(_ToastData data) {
    setState(() {
      _data = data;
      _dragY = 0;
    });
    // Mid-exit: bring it back rather than letting the removal land on the new
    // message.
    if (_dismissing) {
      _dismissing = false;
      _controller.forward();
    }
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(_data.duration, dismiss);
  }

  Future<void> dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _timer?.cancel();
    await _controller.reverse();
    // A replace() during the exit cleared the flag and re-entered.
    if (_dismissing && mounted) widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double top =
        MediaQuery.paddingOf(context).top + Dimensions.paddingSizeSmall;

    return Positioned(
      top: top,
      left: Dimensions.paddingSizeDefault,
      right: Dimensions.paddingSizeDefault,
      // Align shrink-wraps the pill, so only the pill hit-tests; taps on either
      // side of it fall through to the page.
      child: Align(
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: _curve,
          child: SlideTransition(
            position: _slide,
            child: Transform.translate(
              offset: Offset(0, _dragY),
              child: GestureDetector(
                // Holding the pill pauses it, so a toast being read or reached
                // for does not leave under the finger.
                onVerticalDragStart: (_) => _timer?.cancel(),
                onVerticalDragUpdate:
                    (d) => setState(
                      () => _dragY = (_dragY + d.delta.dy).clamp(-80.0, 0.0),
                    ),
                onVerticalDragEnd: (d) {
                  if (_dragY < -24 || (d.primaryVelocity ?? 0) < -300) {
                    dismiss();
                  } else {
                    setState(() => _dragY = 0);
                    _startTimer();
                  }
                },
                onTap: dismiss,
                child: RepaintBoundary(child: _pill()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill() {
    final Color accent = _data.isError ? WaddyColors.coral : WaddyColors.mint;
    final IconData icon =
        _data.icon ??
        (_data.isError ? Icons.error_rounded : Icons.check_circle_rounded);

    return Semantics(
      liveRegion: true,
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: WaddyColors.primary,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              border: Border.all(color: accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: WaddyColors.primary.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: Dimensions.paddingSizeDefault,
                end:
                    _data.actionLabel == null
                        ? Dimensions.paddingSizeDefault
                        : Dimensions.paddingSizeExtraSmall,
                top: Dimensions.paddingSizeMedium,
                bottom: Dimensions.paddingSizeMedium,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: accent, size: 22),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Flexible(
                    child: Text(
                      _data.message,
                      style: waddyMedium.copyWith(color: Colors.white),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_data.actionLabel != null) _action(accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(Color accent) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: Dimensions.paddingSizeExtraSmall,
      ),
      child: TextButton(
        onPressed: () {
          _data.onAction?.call();
          dismiss();
        },
        style: TextButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(Dimensions.minTapTarget, 36),
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeMedium,
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: Text(
          _data.actionLabel!,
          style: waddyBold.copyWith(color: accent),
        ),
      ),
    );
  }
}
