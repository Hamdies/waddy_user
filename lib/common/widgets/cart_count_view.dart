import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/add_to_cart_control.dart';
import 'package:waddy_app/common/widgets/quantity_stepper.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';

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
    // No custom resting visual: this is the app's add control, the same
    // square-then-stepper every other product surface uses.
    if (child == null) return AddToCartControl(item: item, inset: 0);
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
              // Elevated: every host lays this over a product photo.
              child: QuantityStepper(
                quantity: cartQty,
                itemName: item.name,
                elevated: true,
                onDecrement: () {
                  if (cartIndex < 0 ||
                      cartIndex >= cartController.cartList.length) {
                    return;
                  }
                  cartController.setDirectlyAddToCartIndex(index);
                  cartController.setQuantity(
                    false,
                    cartIndex,
                    cartController.cartList[cartIndex].stock,
                    cartController.cartList[cartIndex].item!.quantityLimit,
                  );
                },
                onRemove: () {
                  if (cartIndex < 0 ||
                      cartIndex >= cartController.cartList.length) {
                    return;
                  }
                  cartController.removeFromCart(cartIndex, item: item);
                },
                onIncrement: () {
                  if (cartIndex < 0 ||
                      cartIndex >= cartController.cartList.length) {
                    return;
                  }
                  cartController.setDirectlyAddToCartIndex(index);
                  cartController.setQuantity(
                    true,
                    cartIndex,
                    cartController.cartList[cartIndex].stock,
                    cartController.cartList[cartIndex].quantityLimit,
                  );
                },
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
