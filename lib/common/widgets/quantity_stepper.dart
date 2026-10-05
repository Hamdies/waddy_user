import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/animated_quantity_text.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

enum QuantityStepperSize {
  /// Badge-sized, 82×34 painted. Only for a slot that genuinely cannot fit
  /// [regular]; nothing uses it today.
  compact,

  /// The default everywhere: cards, rows, photo corners, cart lines. 112×40
  /// painted — the same height as the resting `+` (`AddToCartControl`), so
  /// tapping it grows the control sideways instead of swapping in something
  /// smaller.
  regular,

  /// Bottom bars of the item sheet and item details, next to a full CTA.
  large,
}

/// The app's one quantity stepper: `−  n  +` on a mint pill with a teal rim.
///
/// ```
///   hit box   ┌───────────────┬───────────────┐  48 tall
///   painted   │ ╭─────────────┼─────────────╮ │
///             │ │  −          2          +  │ │
///             │ ╰─────────────┼─────────────╯ │
///             └───────────────┴───────────────┘
///                 decrement       increment
/// ```
///
/// ## Touch targets
///
/// The control is split down the middle, like `UIStepper`: the left half is
/// one button and the right half is the other, each at least 48×48. The
/// number is not a control, so there is no reason to leave it as a dead zone
/// between two small targets — a thumb that lands anywhere on the side of the
/// `+` adds one. The halves meet but never overlap, and the pill is painted
/// smaller than the box, so it stays badge-sized on a photo while the target
/// is full-sized.
///
/// ## Removal
///
/// With [onRemove] set, the minus becomes a trash glyph at [min]: a minus that
/// silently deletes the line must say so before the tap. Without it, the minus
/// disables at [min] (the item sheet, where the quantity is pre-add and 1 is
/// the floor).
///
/// The widget holds no cart logic. Callers own what a tap does, and apply it
/// optimistically — the stepper never dims or gates on a network round-trip,
/// which is what used to swallow rapid taps.
class QuantityStepper extends StatelessWidget {
  final int quantity;

  /// Null disables the `+`.
  final VoidCallback? onIncrement;

  /// Called for a minus above [min].
  final VoidCallback? onDecrement;

  /// Called for a minus at [min]. When set, the minus draws as a trash glyph
  /// there; when null, the minus is disabled there.
  final VoidCallback? onRemove;

  final int min;
  final QuantityStepperSize size;

  /// Adds a soft shadow, for a stepper laid over a photograph — where the rim
  /// alone can get lost against a busy image.
  final bool elevated;

  /// Names the item in screen-reader labels ("Increase quantity Falafel").
  final String? itemName;

  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.onRemove,
    this.min = 1,
    this.size = QuantityStepperSize.regular,
    this.elevated = false,
    this.itemName,
  });

  @override
  Widget build(BuildContext context) {
    final _Metrics m = _Metrics.of(size);
    final bool atMin = quantity <= min;
    final bool removes = atMin && onRemove != null;
    final VoidCallback? minusTap = atMin ? onRemove : onDecrement;
    final String name = itemName == null ? '' : ' $itemName';

    return SizedBox(
      width: m.width,
      height: m.hitHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The painted pill, inset inside the hit box.
          Positioned.fill(
            left: m.outset,
            right: m.outset,
            top: (m.hitHeight - m.pillHeight) / 2,
            bottom: (m.hitHeight - m.pillHeight) / 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: WaddyColors.mintSurface,
                border: Border.all(color: WaddyColors.primary, width: 1.5),
                borderRadius: BorderRadius.circular(m.pillHeight / 2),
                boxShadow: [
                  if (elevated)
                    BoxShadow(
                      color: WaddyColors.primary.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  // The mint ledge the resting `+` stands on, so the button
                  // and the stepper read as one control in two states.
                  const BoxShadow(
                    color: WaddyColors.mint,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _StepperHalf(
                  icon:
                      removes
                          ? Icons.delete_outline_rounded
                          : Icons.remove_rounded,
                  semanticLabel:
                      removes
                          ? '${'remove'.tr}$name'
                          : '${'decrease_quantity'.tr}$name',
                  onTap: minusTap,
                  glyphInset: m.glyphInset,
                  glyphSize: m.glyphSize,
                  alignment: AlignmentDirectional.centerStart,
                ),
              ),
              Expanded(
                child: _StepperHalf(
                  icon: Icons.add_rounded,
                  semanticLabel: '${'increase_quantity'.tr}$name',
                  onTap: onIncrement,
                  glyphInset: m.glyphInset,
                  glyphSize: m.glyphSize,
                  alignment: AlignmentDirectional.centerEnd,
                ),
              ),
            ],
          ),
          // On top of the halves but transparent to touch, so a tap on the
          // number goes to whichever half it landed in.
          IgnorePointer(
            child: MediaQuery(
              // The slot between the glyphs is fixed; past 1.3× a three-digit
              // count would run under them.
              data: MediaQuery.of(context).copyWith(
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.3),
              ),
              child: AnimatedQuantityText(
                quantity: quantity,
                style: waddyBold.copyWith(
                  fontSize: m.fontSize,
                  color: WaddyColors.primary,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrics {
  /// Hit-box width of the whole control; each half gets half of it.
  final double width;
  final double hitHeight;
  final double pillHeight;

  /// How far the hit box extends past each rounded end of the pill.
  final double outset;

  /// Glyph centre's distance from the hit box's outer edge.
  final double glyphInset;
  final double glyphSize;
  final double fontSize;

  const _Metrics({
    required this.width,
    this.hitHeight = Dimensions.minTapTarget,
    required this.pillHeight,
    required this.outset,
    required this.glyphInset,
    required this.glyphSize,
    required this.fontSize,
  });

  static _Metrics of(QuantityStepperSize size) => switch (size) {
    // 96 = two 48×48 halves. Painted 82×34, badge-sized on a photo corner.
    // The 7pt outset puts the `+` glyph at the centre of its 48pt half —
    // exactly where the resting 34pt `+` disc (centred in a 48pt box) draws
    // it, so the glyph stays put when the disc becomes the pill.
    QuantityStepperSize.compact => const _Metrics(
      width: 2 * Dimensions.minTapTarget,
      pillHeight: 34,
      outset: 7,
      glyphInset: Dimensions.minTapTarget / 2,
      glyphSize: 18,
      fontSize: 15,
    ),
    // 120 = two 60×48 halves, wider than the minimum because the eye aims
    // at the glyph, and a bigger glyph on a bigger pill is what reads as
    // "easy to hit". Painted 112×40. The 4pt outset puts the `+` glyph's
    // centre 24pt from the trailing edge — exactly where the resting 40pt
    // `+` square (painted 4pt in from the same edge) draws it, so the glyph
    // stays under the thumb when the square becomes the pill.
    QuantityStepperSize.regular => const _Metrics(
      width: 120,
      pillHeight: 40,
      outset: 4,
      glyphInset: 24,
      glyphSize: 22,
      fontSize: 18,
    ),
    // The bottom bars of the item sheet and item details, beside a 48pt CTA.
    QuantityStepperSize.large => const _Metrics(
      width: 148,
      hitHeight: 52,
      pillHeight: 48,
      outset: 0,
      glyphInset: 26,
      glyphSize: 24,
      fontSize: 20,
    ),
  };
}

/// One half of the stepper: the whole half is the target, the glyph sits at
/// its outer end, and only the glyph squeezes on press.
class _StepperHalf extends StatefulWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double glyphInset;
  final double glyphSize;
  final AlignmentDirectional alignment;

  const _StepperHalf({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    required this.glyphInset,
    required this.glyphSize,
    required this.alignment,
  });

  @override
  State<_StepperHalf> createState() => _StepperHalfState();
}

class _StepperHalfState extends State<_StepperHalf> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final bool atStart = widget.alignment == AlignmentDirectional.centerStart;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // Haptic on down, with the squeeze, so the two land as one event and
        // the tap is confirmed even while the eye is on the price.
        onTapDown:
            enabled
                ? (_) {
                  HapticFeedback.selectionClick();
                  _setPressed(true);
                }
                : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: atStart ? widget.glyphInset - widget.glyphSize / 2 : 0,
            end: atStart ? 0 : widget.glyphInset - widget.glyphSize / 2,
          ),
          child: Align(
            alignment: widget.alignment,
            child: AnimatedScale(
              // Deeper than the app's control press: at 18pt, a 6% squeeze is
              // one pixel and reads as nothing.
              scale: _pressed ? 0.8 : 1,
              duration: WaddyMotion.press,
              curve: WaddyMotion.easeOut,
              child: Icon(
                widget.icon,
                size: widget.glyphSize,
                color:
                    enabled
                        ? WaddyColors.primary
                        : WaddyColors.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
