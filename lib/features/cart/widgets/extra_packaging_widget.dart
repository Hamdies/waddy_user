import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class ExtraPackagingWidget extends StatelessWidget {
  final CartController cartController;
  const ExtraPackagingWidget({super.key, required this.cartController});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CartController>(
      builder: (cart) {
        return cart.cartStore?.extraPackagingStatus ?? false
            ? Container(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade50,
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Checkbox(
                    activeColor: Theme.of(context).primaryColor,
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -4,
                    ),
                    value: cartController.needExtraPackage,
                    onChanged: (bool? isChecked) {
                      cartController.toggleExtraPackage();
                    },
                  ),
                  const SizedBox(width: Dimensions.paddingSizeDefault),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('need_extra_packaging'.tr, style: waddyMedium),
                        Text(
                          '${'additional'.tr} ${PriceConverter.convertPrice(cart.cartStore?.extraPackagingAmount)} '
                          '${'change_will_be_added_for_extra_packaging'.tr}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: waddyRegular.copyWith(
                            color: Theme.of(context).disabledColor,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            : const SizedBox();
      },
    );
  }
}
