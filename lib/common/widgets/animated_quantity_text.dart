import 'package:flutter/material.dart';

/// The number inside a quantity stepper, animated so the count *reads* as
/// counting rather than blinking to a new glyph.
///
/// The digit slides in the direction of travel — up on increment, down on
/// decrement — so the motion says which button was pressed even when the user's
/// thumb is covering it. A plain [AnimatedSwitcher] cross-fades both ways and
/// reads as a flicker at these sizes; the direction is the whole point.
///
/// Direction has to be tracked here because [AnimatedSwitcher] hands its
/// transition builder no history — only the child being animated. So we record
/// the previous quantity in [didUpdateWidget] and let every transition in flight
/// share that one direction.
class AnimatedQuantityText extends StatefulWidget {
  final int quantity;
  final TextStyle? style;

  const AnimatedQuantityText({super.key, required this.quantity, this.style});

  @override
  State<AnimatedQuantityText> createState() => _AnimatedQuantityTextState();
}

class _AnimatedQuantityTextState extends State<AnimatedQuantityText> {
  /// Slide distance as a fraction of the digit's own height. Short on purpose:
  /// a counter that travels a full line reads as a slot machine, and at 14sp the
  /// glyph only needs to move a little to register as having changed.
  static const double _slideExtent = 0.4;

  /// Fast enough to keep up with repeated tapping. Anything past ~180ms and a
  /// second tap lands while the first digit is still moving, which is what makes
  /// a stepper feel laggy even when the number is already correct.
  static const Duration _duration = Duration(milliseconds: 150);
  static const Duration _reverseDuration = Duration(milliseconds: 110);

  /// True when the last change was an increase. Seeded to `true` so the very
  /// first build — which does not animate anyway — has a defined direction.
  bool _countingUp = true;

  @override
  void didUpdateWidget(AnimatedQuantityText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quantity != oldWidget.quantity) {
      _countingUp = widget.quantity > oldWidget.quantity;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Incoming digits travel toward zero from the far side; the outgoing digit
    // runs its animation in reverse, which carries it back out the opposite
    // edge for free. That is what keeps the two digits from crossing.
    final Offset begin = Offset(0, _countingUp ? _slideExtent : -_slideExtent);

    return AnimatedSwitcher(
      duration: _duration,
      reverseDuration: _reverseDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // Without this the outgoing digit is laid out beside the incoming one and
      // the stepper's width jitters mid-transition.
      layoutBuilder:
          (current, previous) => Stack(
            alignment: Alignment.center,
            children: <Widget>[...previous, if (current != null) current],
          ),
      transitionBuilder:
          (child, animation) => FadeTransition(
            // Opacity runs ahead of position so the arriving digit is already solid
            // by the time it settles. Fading linearly over the whole slide leaves
            // both digits translucent in the middle, which is the muddy look.
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: begin,
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
      child: Text(
        '${widget.quantity}',
        // The key is what tells AnimatedSwitcher a new digit arrived; without it
        // the Text is reused in place and nothing animates at all.
        key: ValueKey<int>(widget.quantity),
        textAlign: TextAlign.center,
        style: widget.style,
      ),
    );
  }
}
