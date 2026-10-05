import 'package:get/get.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:flutter/material.dart';

class CustomButton extends StatefulWidget {
  final Function? onPressed;
  final String buttonText;
  final bool transparent;
  final EdgeInsets? margin;
  final double? height;
  final double? width;
  final double? fontSize;
  final double radius;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final bool isLoading;
  final bool isBold;
  final bool isBorder;

  /// Replaces the default centered text/icon row entirely when set. The
  /// container, fill, border and tap handling are unchanged — only the
  /// content inside them differs — so call sites with their own layout (a
  /// split left/right row, an inline chip) can still get the button's shared
  /// look and disabled/loading behaviour instead of rebuilding it.
  ///
  /// [buttonText] is still required for accessibility (it backs the
  /// semantic label a screen reader announces) even when [child] supplies the
  /// visible content.
  final Widget? child;

  const CustomButton({
    super.key,
    this.onPressed,
    required this.buttonText,
    this.transparent = false,
    this.margin,
    this.width,
    this.height,
    this.fontSize,
    this.radius = 12,
    this.icon,
    this.color,
    this.textColor,
    this.isLoading = false,
    this.isBold = true,
    this.isBorder = false,
    this.child,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nudgeController;

  @override
  void initState() {
    super.initState();
    _nudgeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _nudgeController.stop();
      _nudgeController.value = 0.0;
    } else if (!_nudgeController.isAnimating) {
      _nudgeController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _nudgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null;

    // Default look: mint fill with an ink (dark teal) border and ink text —
    // the two-tone brand treatment. `color`/`textColor`/`transparent` still
    // override per call site for the few buttons that need something else.
    // Disabled fills from [divider], not [disabledColor]. `disabledColor` is
    // inkMuted (#9EAAA8), and the ink label on it measures 3.96:1 — under the
    // 4.5:1 floor for the label text. Since a disabled primary CTA is the
    // FIRST thing a user sees on screens that gate their button on input (the
    // map picker sits disabled until a pin resolves), that failure is on
    // screen more often than the enabled state. divider (#E4ECEA) reads as
    // the same "inert" step and carries the ink label at 7.89:1.
    final Color buttonColor =
        isDisabled
            ? WaddyColors.divider
            : widget.transparent
            ? Colors.transparent
            : widget.color ?? WaddyColors.mint;
    final Color inkColor = widget.textColor ?? WaddyColors.primary;
    // The teal border is part of the default two-tone look, so a call site
    // that already supplies its own fill (a brand color of its own) draws no
    // border rather than a teal ring that clashes with a fill the border was
    // never designed to sit on. A disabled button likewise draws no live ring:
    // at full strength the border is the loudest "pressable" cue on the
    // control, and ringing an inert fill with it makes a dead button look
    // armed.
    final Color borderColor =
        isDisabled
            ? WaddyColors.divider
            : widget.transparent
            ? WaddyColors.primary.withValues(alpha: 0.4)
            : widget.color ?? WaddyColors.primary;

    return Center(
      child: SizedBox(
        width: widget.width ?? Dimensions.maxContentWidth,
        child: Padding(
          padding: widget.margin ?? EdgeInsets.zero,
          child: GestureDetector(
            onTap:
                widget.isLoading || isDisabled
                    ? null
                    : widget.onPressed as void Function()?,
            child: Semantics(
              button: true,
              label: widget.buttonText,
              child: Container(
                // A FLOOR, not a fixed height. With the global textScaler pin
                // removed, a hard `height` clipped its own label once the OS
                // font size went up — the button kept its box and the text
                // lost. Existing call sites are unaffected: their value is
                // still the height at default scale, it can now only grow.
                constraints: BoxConstraints(minHeight: widget.height ?? 50),
                // Only bites once the label outgrows the min height; at
                // default scale the Center still does the work.
                padding: const EdgeInsets.symmetric(
                  vertical: Dimensions.paddingSizeExtraSmall,
                ),
                decoration: BoxDecoration(
                  color: buttonColor,
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: Border.all(
                    color: borderColor,
                    width: widget.transparent ? 0.5 : 2,
                  ),
                  boxShadow:
                      widget.transparent || isDisabled
                          ? null
                          : [
                            BoxShadow(
                              color: WaddyColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              blurRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                ),
                child:
                    widget.child ??
                    Center(
                      child:
                          widget.isLoading
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 15,
                                    width: 15,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        inkColor,
                                      ),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: Dimensions.paddingSizeSmall,
                                  ),
                                  Text(
                                    'loading'.tr,
                                    style: waddyMedium.copyWith(
                                      color: inkColor,
                                    ),
                                  ),
                                ],
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.buttonText,
                                    textAlign: TextAlign.center,
                                    style:
                                        widget.isBold
                                            ? waddyBold.copyWith(
                                              color: inkColor,
                                              fontSize:
                                                  widget.fontSize ??
                                                  Dimensions.fontSizeLarge,
                                            )
                                            : waddyRegular.copyWith(
                                              color: inkColor,
                                              fontSize:
                                                  widget.fontSize ??
                                                  Dimensions.fontSizeLarge,
                                            ),
                                  ),
                                  if (widget.icon != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: Dimensions.paddingSizeExtraSmall,
                                      ),
                                      child: AnimatedBuilder(
                                        animation: _nudgeController,
                                        builder: (context, child) {
                                          final nudge =
                                              Curves.easeInOut.transform(
                                                _nudgeController.value,
                                              ) *
                                              4.0;
                                          return Transform.translate(
                                            offset: Offset(nudge, 0),
                                            child: child,
                                          );
                                        },
                                        child: Icon(
                                          widget.icon,
                                          color: inkColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
