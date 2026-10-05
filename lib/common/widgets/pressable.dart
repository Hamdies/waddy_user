import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waddy_app/util/motion.dart';

/// The app's press language: anything tappable scales down while held.
///
/// This exists so "does it react to my finger" is never a per-widget decision.
/// A tap target with no press state doesn't read as broken — it reads as
/// *slow*, because the user gets no confirmation the interface heard them until
/// the next screen paints.
///
/// The scale is deliberately kept animated under `disableAnimations`: it is a
/// direct response to a finger already on the glass, not autonomous motion, and
/// removing it takes away feedback rather than reducing motion sickness.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far to scale while held — pick from [WaddyMotion]'s press depths by
  /// the element's footprint, not by taste.
  final double scale;

  /// Anchor for the scale. Left-anchored blocks (an address line, a headline)
  /// must not drift inward when pressed, so they scale from their start edge.
  final AlignmentGeometry alignment;

  final HitTestBehavior behavior;

  /// Wraps the child in a `Semantics(button: true)` when set. Skip it when the
  /// call site already provides its own.
  final String? semanticLabel;

  /// Minimum hit-box size, independent of how big the child draws.
  ///
  /// [behavior] is `opaque`, so without this the visual bounds *are* the tap
  /// bounds — a 40pt circle is a 40pt target, 8pt under the platform minimum.
  /// Setting this expands the box the gesture detector sees while the child
  /// keeps drawing at its own size, so a control can meet [Dimensions.minTapTarget]
  /// without redrawing the design around it.
  ///
  /// Expands outward from the child's centre: check that the extra area does
  /// not overlap a neighbouring target when the visual gap is tighter than the
  /// growth.
  final double? minSize;

  /// Announced as the picked one in a group (a size tile, a chip). Null for
  /// controls that are not a choice; only meaningful with [semanticLabel].
  final bool? selected;

  /// Fires a selection tick when the finger lands.
  ///
  /// On by default because the press scale alone only answers the *eye*, and
  /// the eye is often somewhere else — on a food photo, on the price, halfway
  /// to the next card. The tick is the only confirmation that reaches the user
  /// without them looking for it. Turn it off for presses that are already
  /// accompanied by a stronger cue (a sheet opening, a celebration) so the two
  /// don't stack into a double buzz.
  final bool haptic;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = WaddyMotion.pressCard,
    this.alignment = Alignment.center,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
    this.haptic = true,
    this.minSize,
    this.selected,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null || widget.onLongPress != null;

    Widget result = GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      // Down/up rather than onTap so the scale tracks the finger: pressing and
      // sliding off still shows the press and then releases it, which is what
      // tells the user the tap was cancelled rather than missed.
      onTapDown:
          enabled
              ? (_) {
                // On down, not on tap: the tick has to land on the same frame as
                // the scale, or the press reads as two separate events — a
                // squeeze now and a buzz afterwards. Sliding off still buzzes,
                // and that is correct: it confirms the touch was received, and
                // the scale springing back is what says it was cancelled.
                if (widget.haptic) HapticFeedback.selectionClick();
                _setPressed(true);
              }
              : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        // Resolved here so a start-anchored press mirrors correctly in Arabic.
        alignment: widget.alignment.resolve(
          Directionality.maybeOf(context) ?? TextDirection.ltr,
        ),
        duration: WaddyMotion.press,
        curve: WaddyMotion.easeOut,
        // Inside the scale, so the padded box is what the gesture detector
        // measures but only the child is what visibly squeezes — growing the
        // hit area must not make the press animation look bigger than the
        // control.
        child:
            widget.minSize == null
                ? widget.child
                : ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: widget.minSize!,
                    minHeight: widget.minSize!,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: widget.child,
                  ),
                ),
      ),
    );

    if (widget.semanticLabel != null) {
      result = Semantics(
        button: true,
        // A control with no handler is announced as dimmed, not as a live
        // button that does nothing.
        enabled: enabled,
        selected: widget.selected,
        label: widget.semanticLabel,
        child: result,
      );
    }
    return result;
  }
}
