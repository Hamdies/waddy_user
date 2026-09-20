import 'package:waddy_app/theme/light_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

void showCartSnackBar() {
  ScaffoldMessenger.of(Get.context!).showSnackBar(
    SnackBar(
      dismissDirection: DismissDirection.horizontal,
      margin: EdgeInsets.only(
        right: Dimensions.paddingSizeSmall,
        top: Dimensions.paddingSizeSmall,
        bottom: Dimensions.paddingSizeSmall,
        left: Dimensions.paddingSizeSmall,
      ),
      duration: const Duration(seconds: 3),
      backgroundColor: WaddyColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        side: const BorderSide(color: WaddyColors.mint, width: 2),
      ),
      content: Text(
        'item_added_to_cart'.tr,
        style: waddyMedium.copyWith(color: Colors.white),
      ),
      action: SnackBarAction(
        label: 'view_cart'.tr,
        onPressed: () => Get.toNamed(RouteHelper.getCartRoute()),
        textColor: WaddyColors.mint,
      ),
    ),
  );
}
