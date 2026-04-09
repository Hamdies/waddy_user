import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';

class DetailsAppBarWidget extends StatefulWidget implements PreferredSizeWidget {
  const DetailsAppBarWidget({super.key});

  @override
  DetailsAppBarWidgetState createState() => DetailsAppBarWidgetState();

  @override
  Size get preferredSize => const Size(double.maxFinite, 50);
}

class DetailsAppBarWidgetState extends State<DetailsAppBarWidget> with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
  }
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void shake() {
    controller.forward(from: 0.0);
  }

  String? itemName;

  void updateTitle(String name) {
    if (mounted) {
      setState(() {
        itemName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).primaryColor, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: const SizedBox.shrink(),
      actions: [
        // Bookmark / favourite icon
        GetBuilder<FavouriteController>(
          builder: (favouriteController) {
            final itemController = Get.find<ItemController>();
            final bool isFav = itemController.item != null &&
                favouriteController.wishItemIdList.contains(itemController.item!.id);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    key: ValueKey<bool>(isFav),
                    color: isFav ? const Color(0xFFE53935) : const Color(0xFF1A1A2E),
                    size: 20,
                  ),
                ),
                onPressed: () {
                  if (AuthHelper.isLoggedIn()) {
                    if (isFav) {
                      favouriteController.removeFromFavouriteList(
                        itemController.item!.id, false,
                      );
                    } else {
                      favouriteController.addToFavouriteList(
                        itemController.item, null, false,
                      );
                    }
                  } else {
                    showCustomSnackBar('you_are_not_logged_in'.tr);
                  }
                },
              ),
            );
          },
        ),
        const SizedBox(width: 4),
        // Cart icon with badge
        GetBuilder<CartController>(
          builder: (cartController) {
            final int cartCount = cartController.cartList.length;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(Icons.shopping_cart_outlined, color: Theme.of(context).primaryColor, size: 19),
                    onPressed: () => Get.toNamed(RouteHelper.getCartRoute()),
                  ),
                  if (cartCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).secondaryHeaderColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$cartCount',
                          style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
