import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/item_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CartItemWidget extends StatefulWidget {
  final CartModel cart;
  final int cartIndex;
  final List<AddOns> addOns;
  final bool isAvailable;
  final bool showDivider;
  const CartItemWidget({super.key, required this.cart, required this.cartIndex, required this.isAvailable, required this.addOns, required this.showDivider});

  @override
  State<CartItemWidget> createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<CartItemWidget> {

  void _removeWithUndo(BuildContext context) {
    final cartController = Get.find<CartController>();
    final int originalIndex = widget.cartIndex;
    final String itemName = widget.cart.item?.name ?? 'item'.tr;
    final result = cartController.removeFromCartOptimistic(originalIndex);
    bool undone = false;
    ScaffoldMessenger.of(context)
      .showSnackBar(
        SnackBar(
          content: Text('"$itemName" ${'item_removed_from_cart'.tr}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'undo'.tr,
            onPressed: () {
              undone = true;
              cartController.restoreCartItem(result.removed, originalIndex);
            },
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      )
      .closed
      .then((_) {
        if (!undone) {
          cartController.confirmCartRemoval(result.cartId, item: result.removed.item);
        }
      });
  }

  int _calculateItemXp(double itemPrice) {
    if (!AuthHelper.isLoggedIn()) return 0;
    try {
      final xpController = Get.find<XpController>();
      if (xpController.xpConfig == null || !xpController.xpConfig!.levelingEnabled) return 0;
      final moduleType = Get.find<SplashController>().module?.moduleType;
      return xpController.calculateEstimatedXp(itemPrice, moduleType);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {

    String? variationText = _setupVariationText(cart: widget.cart).$1;
    String addOnText = _setupAddonsText(cart: widget.cart) ?? '';

    double? discount = widget.cart.item!.discount;
    String? discountType = widget.cart.item!.discountType;

    double totalPrice = _calculatePriceWithVariation(cartModel: widget.cart, discount: discount, discountType: discountType);
    double originalPrice = _calculatePriceWithVariation(cartModel: widget.cart, discount: 0, discountType: 'amount');
    double savings = originalPrice - totalPrice;
    int itemXp = _calculateItemXp(totalPrice);

    // Build subtitle: unitType · storeName
    String subtitle = '';
    if (widget.cart.item!.unitType != null && widget.cart.item!.unitType!.isNotEmpty) {
      subtitle = widget.cart.item!.unitType!;
    }
    if (variationText != null && variationText.isNotEmpty) {
      subtitle = subtitle.isNotEmpty ? '$subtitle · $variationText' : variationText;
    }
    if (widget.cart.item!.storeName != null && widget.cart.item!.storeName!.isNotEmpty) {
      subtitle = subtitle.isNotEmpty ? '$subtitle · ${widget.cart.item!.storeName}' : widget.cart.item!.storeName!;
    }

    return Slidable(
      key: UniqueKey(),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.2,
        children: [
          SlidableAction(
            onPressed: (context) {
              _removeWithUndo(context);
            },
            backgroundColor: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.horizontal(right: Radius.circular(Get.find<LocalizationController>().isLtr ? Dimensions.radiusDefault : 0), left: Radius.circular(Get.find<LocalizationController>().isLtr ? 0 : Dimensions.radiusDefault)),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                GestureDetector(
                  onTap: () {
                    ResponsiveHelper.isMobile(context) ? showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (con) => ItemBottomSheet(itemId: widget.cart.item!.id!, cartIndex: widget.cartIndex, cart: widget.cart),
                    ) : showDialog(context: context, builder: (con) => Dialog(
                      child: ItemBottomSheet(itemId: widget.cart.item!.id!, cartIndex: widget.cartIndex, cart: widget.cart),
                    ));
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F2EC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CustomImage(
                            image: '${widget.cart.item!.imageFullUrl}',
                            height: 72, width: 72, fit: BoxFit.cover,
                          ),
                        ),
                        if (!widget.isAvailable)
                          Positioned.fill(
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black.withValues(alpha: 0.55),
                              ),
                              child: Text(
                                'not_available_now_break'.tr,
                                textAlign: TextAlign.center,
                                style: robotoRegular.copyWith(color: Colors.white, fontSize: 9),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Middle: name + subtitle + stepper
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          ResponsiveHelper.isMobile(context) ? showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (con) => ItemBottomSheet(itemId: widget.cart.item!.id!, cartIndex: widget.cartIndex, cart: widget.cart),
                          ) : showDialog(context: context, builder: (con) => Dialog(
                            child: ItemBottomSheet(itemId: widget.cart.item!.id!, cartIndex: widget.cartIndex, cart: widget.cart),
                          ));
                        },
                        child: Text(
                          widget.cart.item!.name!,
                          style: robotoMedium.copyWith(fontSize: 15, height: 1.3, color: const Color(0xFF1A1A1A)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            subtitle,
                            style: robotoRegular.copyWith(fontSize: 12.5, color: const Color(0xFF888888)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      if (addOnText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            addOnText,
                            style: robotoRegular.copyWith(fontSize: 11.5, color: const Color(0xFF999999)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Quantity stepper - left aligned
                      GetBuilder<CartController>(
                        builder: (cartController) {
                          return AnimatedOpacity(
                            opacity: cartController.isLoading ? 0.5 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFDEDEDE), width: 1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IntrinsicWidth(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: cartController.isLoading ? null : () {
                                        if (widget.cart.quantity! > 1) {
                                          Get.find<CartController>().setQuantity(false, widget.cartIndex, widget.cart.stock, widget.cart.quantityLimit);
                                        } else {
                                          _removeWithUndo(context);
                                        }
                                      },
                                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                                      child: SizedBox(
                                        width: 36,
                                        height: 34,
                                        child: Center(
                                          child: Icon(
                                            widget.cart.quantity! == 1 ? CupertinoIcons.delete : Icons.remove_rounded,
                                            size: 15,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 32,
                                      height: 34,
                                      child: Center(
                                        child: Text(
                                          widget.cart.quantity.toString(),
                                          style: robotoBold.copyWith(fontSize: 14, color: const Color(0xFF1A1A1A)),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: cartController.isLoading ? null : () {
                                        Get.find<CartController>().forcefullySetModule(Get.find<CartController>().cartList[0].item!.moduleId!);
                                        Get.find<CartController>().setQuantity(true, widget.cartIndex, widget.cart.stock, widget.cart.quantityLimit);
                                      },
                                      borderRadius: const BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
                                      child: SizedBox(
                                        width: 36,
                                        height: 34,
                                        child: Center(
                                          child: Icon(Icons.add_rounded, size: 15, color: const Color(0xFF1A1A1A)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right: price + original price + XP
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      PriceConverter.convertPrice(totalPrice),
                      style: robotoBold.copyWith(
                        fontSize: 16,
                        color: const Color(0xFF1A1A1A),
                        height: 1.2,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                    if (savings > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          PriceConverter.convertPrice(originalPrice),
                          style: robotoRegular.copyWith(
                            fontSize: 12,
                            color: const Color(0xFFAAAAAA),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFFAAAAAA),
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    if (itemXp > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '+$itemXp XP',
                          style: robotoMedium.copyWith(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          if (widget.showDivider)
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0EFED)),
        ],
      ),
    );
  }

  double _calculatePriceWithVariation({required CartModel cartModel, required double? discount, required String? discountType}) {
    bool newVariation = Get.find<SplashController>().getModuleConfig(cartModel.item!.moduleType).newVariation ?? false;
    double price = 0;
    if(newVariation) {
      for(int index = 0; index< cartModel.item!.foodVariations!.length; index++) {
        for(int i=0; i<cartModel.item!.foodVariations![index].variationValues!.length; i++) {
          if(cartModel.foodVariations![index][i]!) {
            price += (PriceConverter.convertWithDiscount(cartModel.item!.foodVariations![index].variationValues![i].optionPrice!, discount, discountType, isFoodVariation: true)! * cartModel.quantity!);
          }
        }
      }

      price = price + _calculateAddonPrice(cartModel) + (PriceConverter.convertWithDiscount(cartModel.item!.price!, discount, discountType, isFoodVariation: true)! * cartModel.quantity!);

    } else {

      String variationType = '';
      for(int i=0; i<cartModel.variation!.length; i++) {
        variationType = cartModel.variation![i].type!;
      }

      if(variationType.isNotEmpty) {
        for (Variation variation in cartModel.item!.variations!) {
          if (variation.type == variationType) {
            price = (PriceConverter.convertWithDiscount(variation.price!, discount, discountType)! * cartModel.quantity!);
            break;
          }
        }
      } else {
        price = (PriceConverter.convertWithDiscount(cartModel.item!.price!, discount, discountType)! * cartModel.quantity!);
      }
    }
    return price;
  }

  (String?, int) _setupVariationText({required CartModel cart}) {
    String? variationText = '';
    int count = 0;

    if(Get.find<SplashController>().getModuleConfig(cart.item!.moduleType).newVariation!) {
      if(cart.foodVariations!.isNotEmpty) {
        for(int index=0; index<cart.foodVariations!.length; index++) {
          if(cart.foodVariations![index].contains(true)) {
            variationText = '${variationText!}${variationText.isNotEmpty ? ', ' : ''}${cart.item!.foodVariations![index].name} (';
            for(int i=0; i<cart.foodVariations![index].length; i++) {
              if(cart.foodVariations![index][i]!) {
                variationText = '${variationText!}${variationText.endsWith('(') ? '' : ', '}${cart.item!.foodVariations![index].variationValues![i].level}';
                count ++;
              }
            }
            variationText = '${variationText!})';
          }
        }
      }
    }else {
      if(cart.variation!.isNotEmpty) {
        List<String> variationTypes = cart.variation![0].type!.split('-');
        if(variationTypes.length == cart.item!.choiceOptions!.length) {
          int index0 = 0;
          for (var choice in cart.item!.choiceOptions!) {
            variationText = '${variationText!}${(index0 == 0) ? '' : ',  '}${choice.title} - ${variationTypes[index0]}';
            index0 = index0 + 1;
            count ++;
          }
        }else {
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
        addOnText = '$addOnText${(index0 == 0) ? '' : ',  '}${addOn.name} (${qtys[index0]})';
        index0 = index0 + 1;
      }
    }
    return addOnText;
  }

  double _calculateAddonPrice(CartModel cartModel) {
    List<AddOns> addOnList = [];
    double addonPrice = 0;
    for (var addOnId in cartModel.addOnIds!) {
      for(AddOns addOns in cartModel.item!.addOns!) {
        if(addOns.id == addOnId.id) {
          addOnList.add(addOns);
          break;
        }
      }
    }

    for(int index=0; index<addOnList.length; index++) {
      addonPrice = addonPrice + (addOnList[index].price! * cartModel.addOnIds![index].quantity!);
    }
    return addonPrice;
  }
}
