import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/waddy_toast.dart';
import 'package:waddy_app/helper/route_helper.dart';

void showCartSnackBar() {
  WaddyToast.show(
    'item_added_to_cart'.tr,
    icon: Icons.shopping_bag_rounded,
    duration: const Duration(seconds: 3),
    actionLabel: 'view_cart'.tr,
    onAction: () => Get.toNamed(RouteHelper.getCartRoute()),
  );
}
