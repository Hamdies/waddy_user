import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sixam_mart/common/widgets/custom_ink_well.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/language/controllers/language_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/cart/domain/models/cart_model.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/common/widgets/item_bottom_sheet.dart';
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

  bool showAddonsVariations = false;

  @override
  Widget build(BuildContext context) {

    String? variationText = _setupVariationText(cart: widget.cart).$1;
    String addOnText = _setupAddonsText(cart: widget.cart) ?? '';

    int addonCount = widget.cart.addOnIds?.length ?? 0;
    int variationCount = _setupVariationText(cart: widget.cart).$2;

    double? discount = widget.cart.item!.discount;
    String? discountType = widget.cart.item!.discountType;
    String genericName = '';

    if(widget.cart.item!.genericName != null && widget.cart.item!.genericName!.isNotEmpty) {
      for (String name in widget.cart.item!.genericName!) {
        genericName += name;
      }
    }

    double totalPrice = _calculatePriceWithVariation(cartModel: widget.cart, discount: discount, discountType: discountType);
    // Calculate original price (without discount) for savings display
    double originalPrice = _calculatePriceWithVariation(cartModel: widget.cart, discount: 0, discountType: 'amount');
    double savings = originalPrice - totalPrice;

    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Slidable(
        key: UniqueKey(),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.2,
          children: [
            SlidableAction(
              onPressed: (context) {
                Get.find<CartController>().removeFromCart(widget.cartIndex, item: widget.cart.item);
              },
              backgroundColor: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.horizontal(right: Radius.circular(Get.find<LocalizationController>().isLtr ? Dimensions.radiusDefault : 0), left: Radius.circular(Get.find<LocalizationController>().isLtr ? 0 : Dimensions.radiusDefault)),
              foregroundColor: Colors.white,
              icon: CupertinoIcons.delete,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          ),
          child: CustomInkWell(
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
            radius: Dimensions.radiusDefault,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image (left) | Name+Price (middle) | Quantity pill (far right)
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  // Product image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200, width: 0.5),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: CustomImage(
                              image: '${widget.cart.item!.imageFullUrl}',
                              height: 52, width: 52, fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        widget.isAvailable ? const SizedBox() : Positioned.fill(
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), color: Colors.black.withValues(alpha: 0.6)),
                            child: Text('not_available_now_break'.tr, textAlign: TextAlign.center, style: robotoRegular.copyWith(
                              color: Colors.white, fontSize: 9,
                            )),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Middle section - name + price (takes remaining space)
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        widget.cart.item!.name!,
                        style: robotoMedium.copyWith(fontSize: 14, height: 1.2),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Price row: strikethrough original + yellow badge discounted
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                        if(savings > 0) ...[
                          Text(
                            PriceConverter.convertPrice(originalPrice),
                            style: robotoBold.copyWith(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.grey.shade500,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              PriceConverter.convertPrice(totalPrice),
                              style: robotoBold.copyWith(fontSize: 14, color: Theme.of(context).secondaryHeaderColor),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        ] else ...[
                          Text(
                            PriceConverter.convertPrice(totalPrice),
                            style: robotoBold.copyWith(fontSize: 16, color: primaryColor),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ],
                      ),

                      // Per-unit price breakdown when qty > 1
                      if(widget.cart.quantity != null && widget.cart.quantity! > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if(savings > 0) ...[
                                Text(
                                  PriceConverter.convertPrice(_calculateUnitPrice(cartModel: widget.cart, discount: 0, discountType: 'amount')),
                                  style: robotoRegular.copyWith(fontSize: 11, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough, decorationColor: Colors.grey.shade400),
                                  textDirection: TextDirection.ltr,
                                ),
                                Text('→', style: robotoRegular.copyWith(fontSize: 11, color: Colors.grey.shade400)),
                              ],
                              Text(
                                '${PriceConverter.convertPrice(_calculateUnitPrice(cartModel: widget.cart, discount: discount, discountType: discountType))} × ${widget.cart.quantity}',
                                style: robotoRegular.copyWith(fontSize: 11, color: Colors.grey.shade500),
                                textDirection: TextDirection.ltr,
                              ),
                              if(savings > 0)
                                Text(
                                  '${'saved'.tr} ${PriceConverter.convertPrice(savings)}',
                                  style: robotoMedium.copyWith(fontSize: 10, color: Colors.green.shade600),
                                  textDirection: TextDirection.ltr,
                                ),
                            ],
                          ),
                        ),

                      if(widget.cart.item!.unitType != null && widget.cart.item!.unitType!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            widget.cart.item!.unitType!,
                            style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),

                      if(genericName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            genericName,
                            style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      // Addons/Variations toggle
                      if(addOnText.isNotEmpty || (variationText != null && variationText.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                showAddonsVariations = !showAddonsVariations;
                              });
                            },
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${variationCount > 0 ? '$variationCount ${'variations'.tr}' : ''}'
                                  '${addonCount > 0 ? '${variationCount > 0 ? ', ' : ''}$addonCount ${'addons'.tr}' : ''}',
                                style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                showAddonsVariations ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 16, color: Colors.grey.shade500,
                              ),
                            ]),
                          ),
                        ),
                    ]),
                  ),

                  const SizedBox(width: 6),

                  // Far right - Quantity controls pill [- 1 +]
                  GetBuilder<CartController>(
                    builder: (cartController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accentColor, width: 1.5),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          InkWell(
                            onTap: cartController.isLoading ? null : () {
                              if (widget.cart.quantity! > 1) {
                                Get.find<CartController>().setQuantity(false, widget.cartIndex, widget.cart.stock, widget.cart.quantityLimit);
                              } else {
                                Get.find<CartController>().removeFromCart(widget.cartIndex, item: widget.cart.item);
                              }
                            },
                            child: Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              child: Icon(
                                widget.cart.quantity! == 1 ? CupertinoIcons.delete : Icons.remove_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 30,
                            alignment: Alignment.center,
                            child: Text(
                              widget.cart.quantity.toString(),
                              style: robotoBold.copyWith(fontSize: 13, color: Colors.white),
                            ),
                          ),
                          InkWell(
                            onTap: cartController.isLoading ? null : () {
                              Get.find<CartController>().forcefullySetModule(Get.find<CartController>().cartList[0].item!.moduleId!);
                              Get.find<CartController>().setQuantity(true, widget.cartIndex, widget.cart.stock, widget.cart.quantityLimit);
                            },
                            child: Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.add_rounded,
                                size: 15,
                                color: cartController.isLoading ? Colors.white54 : Colors.white,
                              ),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                ]),

                if(showAddonsVariations)
                  Padding(
                    padding: const EdgeInsets.only(left: 70, top: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if(addOnText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${'addons'.tr}: ', style: robotoMedium.copyWith(fontSize: 12)),
                            Flexible(child: Text(
                              addOnText,
                              style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey.shade600),
                            )),
                          ]),
                        ),
                      if(variationText != null && variationText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${'variations'.tr}: ', style: robotoMedium.copyWith(fontSize: 12)),
                            Flexible(child: Text(
                              variationText,
                              style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey.shade600),
                            )),
                          ]),
                        ),
                    ]),
                  ),

                if(widget.showDivider)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Divider(height: 1, color: Colors.grey.shade200),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _calculateUnitPrice({required CartModel cartModel, required double? discount, required String? discountType}) {
    bool newVariation = Get.find<SplashController>().getModuleConfig(cartModel.item!.moduleType).newVariation ?? false;
    double price = 0;
    if(newVariation) {
      for(int index = 0; index< cartModel.item!.foodVariations!.length; index++) {
        for(int i=0; i<cartModel.item!.foodVariations![index].variationValues!.length; i++) {
          if(cartModel.foodVariations![index][i]!) {
            price += PriceConverter.convertWithDiscount(cartModel.item!.foodVariations![index].variationValues![i].optionPrice!, discount, discountType, isFoodVariation: true)!;
          }
        }
      }
      price = price + (_calculateAddonPrice(cartModel) / (cartModel.quantity ?? 1)) + PriceConverter.convertWithDiscount(cartModel.item!.price!, discount, discountType, isFoodVariation: true)!;
    } else {
      String variationType = '';
      for(int i=0; i<cartModel.variation!.length; i++) {
        variationType = cartModel.variation![i].type!;
      }
      if(variationType.isNotEmpty) {
        for (Variation variation in cartModel.item!.variations!) {
          if (variation.type == variationType) {
            price = PriceConverter.convertWithDiscount(variation.price!, discount, discountType)!;
            break;
          }
        }
      } else {
        price = PriceConverter.convertWithDiscount(cartModel.item!.price!, discount, discountType)!;
      }
    }
    return price;
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
