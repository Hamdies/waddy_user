import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/item_bottom_sheet.dart';
import 'package:waddy_app/common/widgets/quantity_stepper.dart';
import 'package:waddy_app/common/widgets/waddy_toast.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/item/domain/produce_preference.dart';

class CartItemWidget extends StatefulWidget {
  final CartModel cart;
  final int cartIndex;
  final List<AddOns> addOns;
  final bool isAvailable;
  final bool showDivider;

  /// The line total to print, from [PriceConverter.allocateRounded] across
  /// the whole basket so the lines add up to the cart's total. Null prints
  /// the line's own rounded total.
  final double? displayPrice;
  const CartItemWidget({
    super.key,
    required this.cart,
    required this.cartIndex,
    required this.isAvailable,
    required this.addOns,
    required this.showDivider,
    this.displayPrice,
  });

  /// This line's total after item discounts, unrounded — what the cart
  /// screen allocates display rounding over.
  static double lineTotal(CartModel cart) =>
      _CartItemWidgetState._calculatePriceWithVariation(
        cartModel: cart,
        discount: cart.item!.discount,
        discountType: cart.item!.discountType,
      );

  @override
  State<CartItemWidget> createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<CartItemWidget> {
  /// Removes the item immediately, then offers Undo.
  ///
  /// The delete is NOT held back. An earlier version delayed the server-side
  /// delete behind a timer, which left a window where the line was gone
  /// locally but still on the server, so any refetch in that window brought
  /// it back. Here the delete goes out at once and Undo is a fresh add of the
  /// same line ([CartController.restoreLine]), so the cart never disagrees
  /// with itself.
  void _remove() {
    final CartModel line = widget.cart;
    Get.find<CartController>().removeFromCart(
      widget.cartIndex,
      item: line.item,
    );
    _showUndo(line);
  }

  void _showUndo(CartModel line) {
    WaddyToast.show(
      '${line.item?.name ?? ''} · ${'removed_from_cart'.tr}',
      icon: Icons.delete_outline_rounded,
      duration: const Duration(seconds: 4),
      actionLabel: 'undo'.tr,
      onAction: () => Get.find<CartController>().restoreLine(line),
    );
  }

  /// Opens the item sheet — where variations, add-ons and the per-item note
  /// are actually edited. Both the image/name taps and the Edit link use it.
  void _openItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (con) => ItemBottomSheet(
            itemId: widget.cart.item!.id!,
            cartIndex: widget.cartIndex,
            cart: widget.cart,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? variationText = _setupVariationText(cart: widget.cart).$1;
    String addOnText = _setupAddonsText(cart: widget.cart) ?? '';

    double? discount = widget.cart.item!.discount;
    String? discountType = widget.cart.item!.discountType;

    double totalPrice = _calculatePriceWithVariation(
      cartModel: widget.cart,
      discount: discount,
      discountType: discountType,
    );
    double originalPrice = _calculatePriceWithVariation(
      cartModel: widget.cart,
      discount: 0,
      discountType: 'amount',
    );
    // Printed figure: the basket-wide allocation when given, so the lines
    // sum to the total. The saving follows it, so struck-through minus shown
    // is what the banner adds up.
    if (widget.displayPrice != null) totalPrice = widget.displayPrice!;
    double savings = originalPrice - totalPrice;

    // Under the name: what the customer picked (variations, then add-ons),
    // then the line price. The stepper stands alone on the right.
    final String? preference = ProducePreference.label(widget.cart.preference);
    final String options = [
      if (preference != null) preference,
      if (variationText != null && variationText.isNotEmpty) variationText,
      if (addOnText.isNotEmpty) addOnText,
    ].join(' · ');

    return Slidable(
      key: UniqueKey(),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.2,
        children: [
          SlidableAction(
            onPressed: (_) => _remove(),
            backgroundColor: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(
                Get.find<LocalizationController>().isLtr
                    ? Dimensions.radiusDefault
                    : 0,
              ),
              left: Radius.circular(
                Get.find<LocalizationController>().isLtr
                    ? 0
                    : Dimensions.radiusDefault,
              ),
            ),
            foregroundColor: WaddyColors.surface,
            icon: CupertinoIcons.delete,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeSmall,
        ),
        decoration: BoxDecoration(
          border:
              widget.showDivider
                  ? const Border(bottom: BorderSide(color: WaddyColors.divider))
                  : null,
        ),
        child: Row(
          children: [
            GestureDetector(onTap: _openItemSheet, child: _thumbnail()),
            const SizedBox(width: Dimensions.paddingSizeMedium),
            Expanded(
              child: GestureDetector(
                onTap: _openItemSheet,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.cart.item!.name!,
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: WaddyColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (options.isNotEmpty) ...[
                      const SizedBox(
                        height: Dimensions.paddingSizeExtraSmall / 2,
                      ),
                      Text(
                        options,
                        style: waddyMedium.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: WaddyColors.inkLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                    // The app's price line: the line total on the mint block
                    // when it is discounted, the undiscounted total struck
                    // through after it — the same drawing as every product
                    // card, so a deal reads the same in the cart.
                    PriceTag(
                      price: ItemPrice.from(
                        now: totalPrice,
                        was: savings > 0 ? originalPrice : totalPrice,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeMedium),
            _stepper(),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail() {
    return SizedBox(
      width: 52,
      height: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: WaddyColors.surfaceWarmAlt),
            CustomImage(
              image: '${widget.cart.item!.imageFullUrl}',
              height: 52,
              width: 52,
              fit: BoxFit.cover,
            ),
            if (!widget.isAvailable)
              Container(
                alignment: Alignment.center,
                color: WaddyColors.ink.withValues(alpha: 0.6),
                child: Text(
                  'not_available_now_break'.tr,
                  textAlign: TextAlign.center,
                  style: waddyBold.copyWith(
                    color: WaddyColors.surface,
                    fontSize: Dimensions.fontSizeOverSmall,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Minus at quantity 1 is a trash glyph and removes the line (with Undo).
  Widget _stepper() {
    return QuantityStepper(
      quantity: widget.cart.quantity ?? 0,
      itemName: widget.cart.item?.name,
      onDecrement:
          () => Get.find<CartController>().setQuantity(
            false,
            widget.cartIndex,
            widget.cart.stock,
            widget.cart.quantityLimit,
          ),
      onRemove: _remove,
      onIncrement: () {
        final CartController cart = Get.find<CartController>();
        if (cart.cartList.isEmpty) return;
        cart.forcefullySetModule(cart.cartList[0].item!.moduleId!);
        cart.setQuantity(
          true,
          widget.cartIndex,
          widget.cart.stock,
          widget.cart.quantityLimit,
        );
      },
    );
  }

  static double _calculatePriceWithVariation({
    required CartModel cartModel,
    required double? discount,
    required String? discountType,
  }) {
    bool newVariation =
        Get.find<SplashController>()
            .getModuleConfig(cartModel.item!.moduleType)
            .newVariation ??
        false;
    double price = 0;
    if (newVariation) {
      for (
        int index = 0;
        index < cartModel.item!.foodVariations!.length;
        index++
      ) {
        for (
          int i = 0;
          i < cartModel.item!.foodVariations![index].variationValues!.length;
          i++
        ) {
          if (cartModel.foodVariations![index][i]!) {
            price +=
                (PriceConverter.convertWithDiscount(
                      cartModel
                          .item!
                          .foodVariations![index]
                          .variationValues![i]
                          .optionPrice!,
                      discount,
                      discountType,
                      isFoodVariation: true,
                    )! *
                    cartModel.quantity!);
          }
        }
      }

      price =
          price +
          _calculateAddonPrice(cartModel) +
          (PriceConverter.convertWithDiscount(
                cartModel.item!.price!,
                discount,
                discountType,
                isFoodVariation: true,
              )! *
              cartModel.quantity!);
    } else {
      String variationType = '';
      for (int i = 0; i < cartModel.variation!.length; i++) {
        variationType = cartModel.variation![i].type!;
      }

      if (variationType.isNotEmpty) {
        for (Variation variation in cartModel.item!.variations!) {
          if (variation.type == variationType) {
            price =
                (PriceConverter.convertWithDiscount(
                      variation.price!,
                      discount,
                      discountType,
                    )! *
                    cartModel.quantity!);
            break;
          }
        }
      } else {
        price =
            (PriceConverter.convertWithDiscount(
                  cartModel.item!.price!,
                  discount,
                  discountType,
                )! *
                cartModel.quantity!);
      }
    }
    return price;
  }

  (String?, int) _setupVariationText({required CartModel cart}) {
    String? variationText = '';
    int count = 0;

    if (Get.find<SplashController>()
        .getModuleConfig(cart.item!.moduleType)
        .newVariation!) {
      if (cart.foodVariations!.isNotEmpty) {
        for (int index = 0; index < cart.foodVariations!.length; index++) {
          if (cart.foodVariations![index].contains(true)) {
            variationText =
                '${variationText!}${variationText.isNotEmpty ? ', ' : ''}${cart.item!.foodVariations![index].name} (';
            for (int i = 0; i < cart.foodVariations![index].length; i++) {
              if (cart.foodVariations![index][i]!) {
                variationText =
                    '${variationText!}${variationText.endsWith('(') ? '' : ', '}${cart.item!.foodVariations![index].variationValues![i].level}';
                count++;
              }
            }
            variationText = '${variationText!})';
          }
        }
      }
    } else {
      if (cart.variation!.isNotEmpty) {
        List<String> variationTypes = cart.variation![0].type!.split('-');
        if (variationTypes.length == cart.item!.choiceOptions!.length) {
          int index0 = 0;
          for (var choice in cart.item!.choiceOptions!) {
            variationText =
                '${variationText!}${(index0 == 0) ? '' : ',  '}${choice.title} - ${variationTypes[index0]}';
            index0 = index0 + 1;
            count++;
          }
        } else {
          variationText = cart.item!.variations![0].type;
        }
      }
    }
    return (variationText, count);
  }

  String? _setupAddonsText({required CartModel cart}) {
    String addOnText = '';
    int index0 = 0;
    List<int?> ids = [];
    List<int?> qtys = [];
    for (var addOn in cart.addOnIds!) {
      ids.add(addOn.id);
      qtys.add(addOn.quantity);
    }
    for (var addOn in cart.item!.addOns!) {
      if (ids.contains(addOn.id)) {
        addOnText =
            '$addOnText${(index0 == 0) ? '' : ',  '}${addOn.name} (${qtys[index0]})';
        index0 = index0 + 1;
      }
    }
    return addOnText;
  }

  static double _calculateAddonPrice(CartModel cartModel) {
    List<AddOns> addOnList = [];
    double addonPrice = 0;
    for (var addOnId in cartModel.addOnIds!) {
      for (AddOns addOns in cartModel.item!.addOns!) {
        if (addOns.id == addOnId.id) {
          addOnList.add(addOns);
          break;
        }
      }
    }

    for (int index = 0; index < addOnList.length; index++) {
      addonPrice =
          addonPrice +
          (addOnList[index].price! * cartModel.addOnIds![index].quantity!);
    }
    return addonPrice;
  }
}
