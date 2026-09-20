import 'dart:async';

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
import 'package:waddy_app/common/widgets/animated_quantity_text.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/item_bottom_sheet.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CartItemWidget extends StatefulWidget {
  final CartModel cart;
  final int cartIndex;
  final List<AddOns> addOns;
  final bool isAvailable;
  final bool showDivider;
  const CartItemWidget({
    super.key,
    required this.cart,
    required this.cartIndex,
    required this.isAvailable,
    required this.addOns,
    required this.showDivider,
  });

  @override
  State<CartItemWidget> createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<CartItemWidget> {
  /// Holds the server-side delete open for the undo window. See [_remove].
  ///
  /// Deliberately NOT cancelled in dispose: removing the line disposes this
  /// very row, so cancelling there would drop every delete before it was sent
  /// and the item would return on the next cart fetch. The callback touches
  /// only the controller, never this State, so it is safe after dispose.
  Timer? _undoTimer;

  /// Removes the item with a 4-second undo window.
  ///
  /// The line disappears locally at once, but the server-side delete is held
  /// behind [_undoTimer]. Undo cancels the timer and re-inserts at the original
  /// index, so nothing was ever sent. The timer — NOT the snackbar's dismissal
  /// — is what commits: an earlier version made the toast's `.closed` callback
  /// load-bearing, which is why the toast could not simply be removed later.
  void _remove() {
    final cartController = Get.find<CartController>();
    final int index = widget.cartIndex;
    final result = cartController.removeFromCartOptimistic(index);

    _undoTimer?.cancel();
    bool undone = false;

    _undoTimer = Timer(const Duration(seconds: 4), () {
      if (undone) return;
      cartController.confirmCartRemoval(
        result.cartId,
        item: result.removed.item,
      );
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'item_removed'.tr,
            style: waddyMedium.copyWith(color: Colors.white),
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: WaddyColors.ink,
          action: SnackBarAction(
            label: 'undo'.tr,
            textColor: WaddyColors.mint,
            onPressed: () {
              undone = true;
              _undoTimer?.cancel();
              cartController.restoreCartItem(result.removed, index);
            },
          ),
        ),
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
    double savings = originalPrice - totalPrice;

    // Subtitle. The design shows the item's chosen options — the line under
    // the name is what the customer picked, not catalogue metadata, so
    // variation/add-on text leads and unit/store are omitted entirely.
    String subtitle = '';
    if (variationText != null && variationText.isNotEmpty) {
      subtitle = variationText;
    }

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
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            // Mockup: 18px above, 16px below each row.
            padding: const EdgeInsets.fromLTRB(
              0,
              Dimensions.paddingSizeDefault,
              0,
              Dimensions.paddingSizeDefault,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image — 64x64 @ r12 per the mockup.
                GestureDetector(
                  onTap: () => _openItemSheet(),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: WaddyColors.surfaceWarmAlt,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                          child: CustomImage(
                            image: '${widget.cart.item!.imageFullUrl}',
                            height: 64,
                            width: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (!widget.isAvailable)
                          Positioned.fill(
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                                color: Colors.black.withValues(alpha: 0.55),
                              ),
                              child: Text(
                                'not_available_now_break'.tr,
                                textAlign: TextAlign.center,
                                style: waddyRegular.copyWith(
                                  color: Colors.white,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: Dimensions.paddingSizeMedium),

                // Right of the image is one column with two rows, per the
                // mockup: name/price on top, then (notes + edit) beside the
                // stepper. The stepper moved out of the text column so it can
                // bottom-align against the meta block.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1 — name left, price right, baseline-shared.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openItemSheet(),
                              child: Text(
                                widget.cart.item!.name!,
                                style: waddyBold.copyWith(
                                  fontSize: 17,
                                  height: 1.25,
                                  letterSpacing: -0.2,
                                  color: WaddyColors.ink,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          // Struck-through original sits INLINE before the live
                          // price when discounted (mockup's "Water For Driver").
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (savings > 0) ...[
                                Text(
                                  PriceConverter.convertPrice(originalPrice),
                                  style: waddyRegular.copyWith(
                                    fontSize: 13,
                                    color: WaddyColors.ink,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: WaddyColors.error,
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                                const SizedBox(
                                  width: Dimensions.paddingSizeSmall,
                                ),
                              ],
                              Text(
                                PriceConverter.convertPrice(totalPrice),
                                style: waddyBold.copyWith(
                                  fontSize: 17,
                                  letterSpacing: -0.2,
                                  color: WaddyColors.ink,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      // Row 2 — meta column (promo, note, edit) vs stepper,
                      // bottom-aligned as in the mockup.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // No "Promo" badge and no "Edit" link: tapping
                                // the row (image or name) already opens the item
                                // sheet, and the struck-through price alongside
                                // the live one already says the line is
                                // discounted.
                                if (subtitle.isNotEmpty)
                                  Text(
                                    subtitle,
                                    style: waddyRegular.copyWith(
                                      fontSize: 15,
                                      height: 1.4,
                                      color: WaddyColors.inkLight,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                if (addOnText.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      addOnText,
                                      style: waddyRegular.copyWith(
                                        fontSize: 13,
                                        color: WaddyColors.inkMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(width: Dimensions.paddingSizeMedium),

                          // Quantity stepper — bordered pill, r10, per mockup.
                          GetBuilder<CartController>(
                            builder: (cartController) {
                              // No isLoading dimming or gating here: the quantity is
                              // applied optimistically, so the stepper stays live
                              // and rapid taps all register.
                              return Container(
                                decoration: BoxDecoration(
                                  // Explicit white: without it the stepper
                                  // picked up the row's ground and read grey.
                                  color: WaddyColors.surface,
                                  border: Border.all(
                                    color: WaddyColors.divider,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusSmall,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: IntrinsicWidth(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (widget.cart.quantity! > 1) {
                                            Get.find<CartController>()
                                                .setQuantity(
                                                  false,
                                                  widget.cartIndex,
                                                  widget.cart.stock,
                                                  widget.cart.quantityLimit,
                                                );
                                          } else {
                                            _remove();
                                          }
                                        },
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                          bottomLeft: Radius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                        ),
                                        child: const SizedBox(
                                          width: 34,
                                          height: 34,
                                          child: Center(
                                            // The design draws a trash can on
                                            // every row, including the one at
                                            // quantity 2, so the glyph is fixed
                                            // rather than swapping minus/trash.
                                            // The ACTION still decrements above
                                            // 1 and only removes at 1.
                                            child: Icon(
                                              CupertinoIcons.delete,
                                              size: 16,
                                              color: WaddyColors.ink,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 28,
                                        height: 34,
                                        child: Center(
                                          child: AnimatedQuantityText(
                                            quantity: widget.cart.quantity ?? 0,
                                            style: waddyBold.copyWith(
                                              fontSize: 16,
                                              color: WaddyColors.ink,
                                            ),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          if (Get.find<CartController>()
                                              .cartList
                                              .isEmpty)
                                            return;
                                          Get.find<CartController>()
                                              .forcefullySetModule(
                                                Get.find<CartController>()
                                                    .cartList[0]
                                                    .item!
                                                    .moduleId!,
                                              );
                                          Get.find<CartController>()
                                              .setQuantity(
                                                true,
                                                widget.cartIndex,
                                                widget.cart.stock,
                                                widget.cart.quantityLimit,
                                              );
                                        },
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                          bottomRight: Radius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                        ),
                                        child: const SizedBox(
                                          width: 34,
                                          height: 34,
                                          child: Center(
                                            child: Icon(
                                              Icons.add_rounded,
                                              size: 16,
                                              color: WaddyColors.ink,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (widget.showDivider)
            const Divider(height: 1, thickness: 1, color: WaddyColors.divider),
        ],
      ),
    );
  }

  double _calculatePriceWithVariation({
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

  double _calculateAddonPrice(CartModel cartModel) {
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
