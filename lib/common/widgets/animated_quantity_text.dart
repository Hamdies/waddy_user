import 'package:flutter/material.dart';
import 'package:waddy_app/util/motion.dart';

/// The number inside a quantity stepper.
///
/// The new number is on screen, fully opaque, on the frame the tap lands. The
/// only motion is a short nudge in the direction of travel — up on increment,
/// down on decrement — so the count still says which button was pressed when
/// a thumb covers it.
///
/// This used to be an [AnimatedSwitcher] cross-fade: the incoming digit
/// started at opacity 0 and the outgoing one lingered, so for the first ~100ms
/// after a tap the number was mostly invisible, and rapid taps stacked several
/// half-transparent digits in one slot. The count was correct but read as
/// late — which is what "laggy" is to a stepper. One [Text], one controller
/// restarted per change, translate + scale only: paint-time transforms, no
/// layout, no extra children.
class AnimatedQuantityText extends StatefulWidget {
  final int quantity;
  final TextStyle? style;

  const AnimatedQuantityText({super.key, required this.quantity, this.style});

  @override
  State<AnimatedQuantityText> createState() => _AnimatedQuantityTextState();
}

class _AnimatedQuantityTextState extends State<AnimatedQuantityText>
    with SingleTickerProviderStateMixin {
  /// Travel as a fraction of the glyph's height. Enough to register, short
  /// enough to stay inside a 32pt pill.
  static const double _nudge = 0.3;

  /// Short enough that a second tap never lands mid-motion on a stale-looking
  /// digit; each change restarts it anyway.
  static const Duration _duration = Duration(milliseconds: 140);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    // Seeded at rest so the first build draws the number still.
    value: 1,
  );
  late final Animation<double> _settle = CurvedAnimation(
    parent: _controller,
    curve: WaddyMotion.easeOut,
  );

  bool _countingUp = true;

  @override
  void didUpdateWidget(AnimatedQuantityText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quantity == oldWidget.quantity) return;
    _countingUp = widget.quantity > oldWidget.quantity;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Text text = Text(
      '${widget.quantity}',
      textAlign: TextAlign.center,
      // Tabular figures: "9" → "10" and "1" → "2" keep the slot width steady,
      // so the pill does not twitch as the count changes.
      style: (widget.style ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return AnimatedBuilder(
      animation: _settle,
      child: text,
      builder: (context, child) {
        final double remaining = 1 - _settle.value;
        return FractionalTranslation(
          translation: Offset(0, (_countingUp ? _nudge : -_nudge) * remaining),
          child: Transform.scale(scale: 1 + 0.12 * remaining, child: child),
        );
      },
    );
  }
}
