import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/animated_quantity_text.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class CartCountView extends StatelessWidget {
  final Item item;
  final Widget? child;
  final int? index;
  const CartCountView({
    super.key,
    required this.item,
    this.child,
    this.index = -1,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CartController>(
      // Keyed because GetBuilder keeps the filter's last value across widget
      // updates; a card recycled for another item must not inherit it.
      key: ValueKey<int?>(item.id),
      // Rebuild only when this item's count or line position changes, not on
      // every cart change anywhere. The index is part of it because the tap
      // handlers below capture it.
      filter:
          (cart) => (
            cart.cartQuantity(item.id!),
            cart.isExistInCart(
              item.id,
              cart.cartVariant(item.id!),
              false,
              null,
            ),
          ),
      builder: (cartController) {
        int cartQty = cartController.cartQuantity(item.id!);
        int cartIndex = cartController.isExistInCart(
          item.id,
          cartController.cartVariant(item.id!),
          false,
          null,
        );
        return cartQty != 0
            ? Center(
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(
                    Dimensions.radiusExtraLarge,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        if (cartIndex < 0 ||
                            cartIndex >= cartController.cartList.length)
                          return;
                        if (cartController.cartList[cartIndex].quantity! > 1) {
                          cartController.setDirectlyAddToCartIndex(index);
                          cartController.setQuantity(
                            false,
                            cartIndex,
                            cartController.cartList[cartIndex].stock,
                            cartController
                                .cartList[cartIndex]
                                .item!
                                .quantityLimit,
                          );
                        } else {
                          cartController.removeFromCart(cartIndex);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeExtraSmall,
                        ),
                        child: Icon(
                          Icons.remove,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeSmall,
                      ),
                      // The quantity is applied optimistically, so there is nothing to
                      // wait for — swapping the digit out for a spinner on every tap is
                      // what made this stepper feel slow.
                      child: AnimatedQuantityText(
                        quantity: cartQty,
                        style: waddyMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(context).cardColor,
                        ),
                      ),
                    ),

                    InkWell(
                      onTap: () {
                        if (cartIndex < 0 ||
                            cartIndex >= cartController.cartList.length)
                          return;
                        cartController.setDirectlyAddToCartIndex(index);
                        cartController.setQuantity(
                          true,
                          cartIndex,
                          cartController.cartList[cartIndex].stock,
                          cartController.cartList[cartIndex].quantityLimit,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeExtraSmall,
                        ),
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            : InkWell(
              onTap: () {
                Get.find<ItemController>().itemDirectlyAddToCart(item, context);
              },
              child:
                  child ??
                  Container(
                    height: 25,
                    width: 25,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).cardColor,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
            );
      },
    );
  }
}
