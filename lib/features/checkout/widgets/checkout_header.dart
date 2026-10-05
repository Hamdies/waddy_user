import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/scratch_card/widgets/scratch_card_badge.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/cart/widgets/basket_top_bar.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Checkout's app bar: the cart's [BasketHeader], word for word, with
/// "Checkout" as the title — the two screens share one top bar.
class CheckoutHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? storeName;
  final List<CartModel?>? cartList;
  const CheckoutHeader({super.key, this.storeName, this.cartList});

  @override
  Size get preferredSize => const Size.fromHeight(kBasketHeaderHeight);

  @override
  Widget build(BuildContext context) {
    final int count = (cartList ?? const <CartModel?>[]).fold(
      0,
      (sum, c) => sum + (c?.quantity ?? 0),
    );

    return Material(
      color: WaddyColors.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: kBasketHeaderStartInset,
              end: Dimensions.paddingSizeDefault,
            ),
            child: Row(
              children: [
                Expanded(
                  child: BasketHeader(
                    title: 'checkout'.tr,
                    storeName: storeName,
                    itemCount: count,
                    onBack: () => Get.back(),
                  ),
                ),
                // Same sticker as the cart's header: pinned, over nothing
                // (docs/scratch_card_plan.md §3a).
                if (ScratchCardBadge.inBags)
                  const ScratchCardSticker(width: 46, height: 52, flips: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The cart's savings banner, word for word: "Waddy! You saved [amount]".
class CheckoutSavingsBanner extends StatelessWidget {
  final double amount;

  /// Kept for call-site compatibility; the shared banner does not name the
  /// store.
  final String? storeName;
  const CheckoutSavingsBanner({
    super.key,
    required this.amount,
    this.storeName,
  });

  @override
  Widget build(BuildContext context) => BasketSavingsBanner(amount: amount);
}
