import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// The flat card every checkout section sits in: a hairline border on white,
/// no shadow. Sections are told apart by spacing and type, not elevation —
/// seven shadowed cards stacked on one screen read as noise.
class CheckoutCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const CheckoutCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Dimensions.paddingSizeDefault),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: WaddyColors.divider),
      ),
      child: child,
    );
  }
}

/// Square check used for the checkout's opt-ins (save tip, save
/// instructions). Filled [WaddyColors.primary] when on.
class CheckoutCheckRow extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;
  final String label;
  const CheckoutCheckRow({
    super.key,
    required this.value,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        // The whole row is the target, and it clears the thumb minimum even
        // though the box it draws is 20.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? WaddyColors.primary : WaddyColors.surface,
                  borderRadius: BorderRadius.circular(
                    Dimensions.radiusExtraSmall,
                  ),
                  border: Border.all(
                    color: value ? WaddyColors.primary : WaddyColors.inkMuted,
                    width: 1.5,
                  ),
                ),
                child:
                    value
                        ? const HugeIcon(
                          icon: HugeIcons.strokeRoundedTick02,
                          size: 16,
                          color: WaddyColors.surface,
                        )
                        : null,
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: Text(
                  label,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: WaddyColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Radio dot for single-choice checkout lists. The selected state is a thick
/// [WaddyColors.primary] ring rather than a filled dot, as in the design.
class CheckoutRadio extends StatelessWidget {
  final bool selected;
  const CheckoutRadio({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: WaddyColors.surface,
        border: Border.all(
          color: selected ? WaddyColors.primary : WaddyColors.inkMuted,
          width: selected ? 5.5 : 1.5,
        ),
      ),
    );
  }
}

/// Section heading that sits directly on the page, outside any card
/// ("Pay with", "Payment summary").
class CheckoutSectionTitle extends StatelessWidget {
  final String title;
  const CheckoutSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: waddyBold.copyWith(
        fontSize: Dimensions.fontSizeLarge,
        color: WaddyColors.ink,
      ),
    );
  }
}

/// The checkout's one icon: a Huge Icons glyph at its own size.
///
/// A bare [HugeIcon] fills whatever tight box it lands in — inside a 44px
/// circle it draws at 44, not at its `size` — which is how the screen's icons
/// ballooned. The [Center] loosens the constraint so [size] is what renders.
class CheckoutIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  final double size;
  final Color? color;
  const CheckoutIcon({
    super.key,
    required this.icon,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: HugeIcon(
        icon: icon,
        size: size,
        color: color ?? WaddyColors.ink,
        strokeWidth: 1.6,
      ),
    );
  }
}

/// A discount or a freebie: a flat mint block with bold teal type, so money
/// saved is spotted without reading. The one place full-saturation mint is
/// not a control — it marks a win, and it is never large enough to be
/// mistaken for a button.
class CheckoutSavingChip extends StatelessWidget {
  final String text;
  final double? fontSize;
  const CheckoutSavingChip(this.text, {super.key, this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WaddyColors.mint,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
        vertical: 2,
      ),
      child: Text(
        text,
        textDirection: TextDirection.ltr,
        style: waddyBold.copyWith(
          fontSize: fontSize ?? Dimensions.fontSizeSmall,
          color: WaddyColors.primary,
        ),
      ),
    );
  }
}
