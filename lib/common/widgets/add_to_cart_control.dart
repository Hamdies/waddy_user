import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/common/widgets/quantity_stepper.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/item/domain/produce_preference.dart';
import 'package:waddy_app/features/item/screens/mart_product_screen.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// The app's one add-to-cart control, for every product surface in every
/// module.
///
/// ```
///   not in cart       in cart (simple)          in cart (has options)
///   ┌────┐            ╭──────────────────╮      ┌────────┐
///   │ +  │            │  🗑     2      +  │      │ +  2   │
///   └────┘▁mint       ╰──────────────────╯▁mint └────────┘▁mint
///   40×40             112×40 stepper            filled, reopens options
/// ```
///
/// Fills its parent's box and paints at the trailing end: give it [hitWidth] ×
/// [Dimensions.minTapTarget] and the box is the stepper's room. A tight slot is
/// the hit area as given; align the control in a loosened one (see
/// `StoreProductCard`) and the idle "+" is a 48 target of its own, growing to
/// the stepper's width only once the item is in the cart. The `+` and the
/// stepper's `+` glyph sit at the same spot, so the glyph under the thumb
/// does not move when the square grows into the pill.
///
/// A customizable item gets the stepper too while it has exactly one line in
/// the cart — the stepper drives that line. Once it sits on several lines under
/// different options, "its quantity" is not one number: the button goes back to
/// opening the options and says how many are in the cart in total ("+ 2").
class AddToCartControl extends StatelessWidget {
  /// The box the control expects: the regular stepper's full hit width.
  static const double hitWidth = 120;

  final Item item;

  /// Space between the painted control and the box's trailing edge. Never
  /// below 4, the stepper's own outset, so square and pill end in one place.
  final double inset;

  /// Where an item with options goes instead of the default (the item sheet
  /// or the item page): the specialty / pets product sheet.
  final VoidCallback? onOptions;

  /// True (the default, everywhere): the square turns into the − n + pill in
  /// place. False keeps the square and counts on it ("+ 2") — nothing uses it
  /// now.
  final bool expands;

  /// The small 82×34 pill, for a card with too little room beside its name for
  /// the regular one.
  final bool compact;

  /// Whether the "+" of a grocery item that only asks a question (size,
  /// salad or cooking) adds it at once, on its first answers. Off where the
  /// caller's [onOptions] is the real action (Buy again repeats the last line).
  final bool quickAdd;

  const AddToCartControl({
    super.key,
    required this.item,
    this.inset = 6,
    this.onOptions,
    this.expands = true,
    this.compact = false,
    this.quickAdd = true,
  });

  /// Whether the item needs a choice before it can go in the cart.
  static bool customizable(Item item) =>
      (item.variations?.isNotEmpty ?? false) ||
      (item.foodVariations?.isNotEmpty ?? false) ||
      (item.addOns?.isNotEmpty ?? false) ||
      // Produce asks ripeness / salad-or-cooking first, in the sheet.
      ProducePreference.asks(item.prepOption);

  bool get _customizable => customizable(item);

  int _lineIndex(CartController cart) =>
      _customizable ? -1 : cart.isExistInCart(item.id, '', false, null);

  /// A customizable item's quantity across all its cart lines.
  int _optionsQuantity(CartController cart) {
    int total = 0;
    for (final line in cart.cartList) {
      if (line.item?.id == item.id) total += line.quantity ?? 0;
    }
    return total;
  }

  /// The cart line a customizable item's stepper drives: its only line.
  /// With two or more (salad and cooking, two sizes) "its quantity" is not one
  /// number, so there is no line and the counter stays.
  int _soleLine(CartController cart) {
    int found = -1;
    for (int i = 0; i < cart.cartList.length; i++) {
      if (cart.cartList[i].item?.id != item.id) continue;
      if (found != -1) return -1;
      found = i;
    }
    return found;
  }

  double get _edge => inset < 4 ? 4 : inset;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CartController>(
      // GetBuilder keeps the filter's last value in its State; a slot reused
      // for another item needs a fresh one.
      key: ValueKey<int?>(item.id),
      // Only this item's own lines decide what it draws. Never null: GetX
      // treats a null first value as "no filter".
      filter: (cart) {
        if (!expands) return _optionsQuantity(cart);
        final int i = _customizable ? _soleLine(cart) : _lineIndex(cart);
        if (i != -1) return cart.cartList[i].quantity ?? 1;
        // Several lines: the counter's total, offset clear of any quantity.
        return _customizable ? -2 - _optionsQuantity(cart) : -1;
      },
      builder: (cart) {
        if (!expands) return _add(context, inCart: _optionsQuantity(cart));
        final int i = _customizable ? _soleLine(cart) : _lineIndex(cart);
        if (i != -1) return _stepper(cart.cartList[i].quantity ?? 1);
        return _add(
          context,
          inCart: _customizable ? _optionsQuantity(cart) : 0,
        );
      },
    );
  }

  Widget _stepper(int quantity) {
    // Re-resolved on tap: the builder's index is a frame old.
    int line() =>
        _customizable
            ? _soleLine(Get.find<CartController>())
            : Get.find<CartController>().isExistInCart(
              item.id,
              '',
              false,
              null,
            );
    int? stockOf(int j) =>
        Get.find<CartController>().cartList[j].stock ?? item.stock;

    final Widget stepper = QuantityStepper(
      quantity: quantity,
      itemName: item.name,
      elevated: true,
      size: compact ? QuantityStepperSize.compact : QuantityStepperSize.regular,
      onDecrement: () {
        final c = Get.find<CartController>();
        final int j = line();
        if (j != -1) {
          c.setQuantity(false, j, stockOf(j), item.quantityLimit);
        }
      },
      // The stepper routes the minus at 1 here: `decideItemQuantity` has
      // no floor and would leave a zero-quantity line.
      onRemove: () {
        final int j = line();
        if (j != -1) Get.find<CartController>().removeFromCart(j, item: item);
      },
      onIncrement: () {
        final c = Get.find<CartController>();
        final int j = line();
        if (j != -1) {
          c.setQuantity(true, j, stockOf(j), item.quantityLimit);
        }
      },
    );

    return Padding(
      padding: EdgeInsetsDirectional.only(end: _edge - 4),
      // In a slot narrower than the pill (a photo corner) it grows toward the
      // start, pinned by its trailing edge, never squeezed. In an unbounded
      // slot (a row's trailing child) it just takes its own width —
      // OverflowBox would try to be infinitely wide there.
      child: LayoutBuilder(
        builder:
            (context, constraints) =>
                constraints.hasBoundedWidth
                    ? OverflowBox(
                      alignment: AlignmentDirectional.centerEnd,
                      minWidth: 0,
                      maxWidth: double.infinity,
                      child: stepper,
                    )
                    : stepper,
      ),
    );
  }

  Widget _add(BuildContext context, {int inCart = 0}) {
    return AddToCartSquare(
      inCart: inCart,
      inset: _edge,
      semanticLabel: item.name ?? '',
      onTap:
          _customizable && quickAdd && MartProductScreen.handles(item)
              ? () => Get.find<ItemController>().quickAddToCart(item)
              : _customizable && onOptions != null
              ? onOptions
              : () => Get.find<ItemController>().itemDirectlyAddToCart(
                item,
                context,
              ),
    );
  }
}

/// The add square on its own: white with a teal rim on a mint ledge, filled
/// teal with the count ("+ 2") once [inCart] is above zero.
///
/// [AddToCartControl] is the normal way in; this is for a card whose model
/// is too thin for it (a home rail's lightweight `Items`), so the square still
/// looks the same everywhere.
class AddToCartSquare extends StatelessWidget {
  final int inCart;
  final VoidCallback? onTap;

  /// The product's name, for the screen-reader label.
  final String semanticLabel;

  /// Space between the square and the box's trailing edge.
  final double inset;

  const AddToCartSquare({
    super.key,
    this.inCart = 0,
    required this.onTap,
    required this.semanticLabel,
    this.inset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bool filled = inCart > 0;
    final Color fg = filled ? WaddyColors.mint : WaddyColors.primary;
    return Pressable(
      semanticLabel:
          filled
              ? '${'add'.tr} $semanticLabel, $inCart'
              : '${'add'.tr} $semanticLabel',
      scale: WaddyMotion.pressControl,
      alignment: AlignmentDirectional.centerEnd,
      onTap: onTap,
      // NOT `Pressable(minSize:)` — that centres the child in its box, which
      // parked the square mid-photo instead of in the corner. The minimum is
      // applied here and the Align pins the square to the trailing edge. The
      // Align hugs the square (widthFactor 1) so the target is the square plus
      // its 48 minimum, never the whole slot: a slot loosened by its caller
      // (a card's photo corner) must not turn the photo's bottom strip into
      // an add button.
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: Dimensions.minTapTarget,
          minHeight: Dimensions.minTapTarget,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          widthFactor: 1,
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: inset),
            child: Container(
              constraints: const BoxConstraints(minWidth: 40),
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: filled ? 10 : 0),
              decoration: BoxDecoration(
                color: filled ? WaddyColors.primary : WaddyColors.surface,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                border: Border.all(color: WaddyColors.primary, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: WaddyColors.mint, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: filled ? 18 : 22, color: fg),
                  if (filled) ...[
                    const SizedBox(width: 3),
                    Text(
                      '$inCart',
                      style: waddyBold.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
