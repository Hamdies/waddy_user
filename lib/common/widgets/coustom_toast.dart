import 'package:flutter/material.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// The toast body.
///
/// ## Why this drives its own animation
///
/// A Material 3 floating `SnackBar` animates in by growing its HEIGHT — see
/// `_snackBarM3HeightCurve` in Flutter's snack_bar.dart, which wraps the bar in
/// `Align(heightFactor: 0→1)`. That relayouts the subtree on every frame of the
/// transition, and the fade is an `Interval(0.4, 0.6)` so the bar is already
/// half-grown before it starts becoming visible. The result reads as a shudder:
/// the box unfolds, then abruptly appears.
///
/// It was worse here because this widget used to add 40px of bottom padding and
/// 20px of side margin INSIDE the animated area, so the height Flutter was
/// interpolating included dead space, and the content jumped as it resolved.
///
/// The fix is twofold. The dead space moved OUT of the animated area and onto
/// the SnackBar's own `margin` (see showCustomSnackBar), so what Flutter's
/// height animation interpolates is now just the bar itself. And the motion the
/// eye actually tracks — a short slide plus a fade — is owned here, running on
/// transform and opacity only. Those are compositor-level: no relayout per
/// frame, so the bar arrives smoothly instead of unfolding.
class CustomToast extends StatefulWidget {
  final String text;
  final bool isError;
  final Color textColor;
  final double borderRadius;
  final EdgeInsets padding;

  /// Whether to run the built-in slide+fade.
  ///
  /// Off for the GetX branch: `GetSnackBar` already slides its own bar in, and
  /// two slides on the same widget read as a bounce. Only the ScaffoldMessenger
  /// path needs us to supply the motion.
  final bool animate;

  const CustomToast({
    super.key,
    required this.text,
    this.textColor = Colors.white,
    this.borderRadius = Dimensions.radiusDefault,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Dimensions.paddingSizeDefault,
      vertical: Dimensions.paddingSizeMedium,
    ),
    this.animate = true,
    required this.isError,
  });

  @override
  State<CustomToast> createState() => _CustomToastState();
}

class _CustomToastState extends State<CustomToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // Slightly longer than Flutter's own 250ms transition so our motion is
      // what the eye tracks, rather than a second animation racing it.
      duration: const Duration(milliseconds: 320),
    );
    // Opacity leads the slide: the bar is legible before it finishes settling,
    // which is what makes it read as "arriving" rather than "unfolding".
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    // Short travel. A long slide on a bar that is already near the bottom edge
    // just looks like it is falling into place late.
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.isError ? WaddyColors.coral : WaddyColors.mint;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: WaddyColors.primary,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: WaddyColors.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: widget.padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isError
                      ? Icons.error_rounded
                      : Icons.check_circle_rounded,
                  color: accent,
                  size: 22,
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),

                Flexible(
                  child: Text(
                    widget.text,
                    style: waddyMedium.copyWith(color: widget.textColor),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
