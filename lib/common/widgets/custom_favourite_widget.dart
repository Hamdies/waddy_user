import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/guest_gate_helper.dart';

class CustomFavouriteWidget extends StatefulWidget {
  final Store? store;
  final Item? item;
  final bool isStore;
  final bool isWished;
  final double? size;
  final int? storeId;
  const CustomFavouriteWidget({
    super.key,
    this.store,
    this.item,
    this.isStore = false,
    required this.isWished,
    this.size = 25,
    this.storeId,
  });

  @override
  State<CustomFavouriteWidget> createState() => _CustomFavouriteWidgetState();
}

class _CustomFavouriteWidgetState extends State<CustomFavouriteWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: Colors.transparent,
      onTap:
          Get.find<FavouriteController>().isRemoving
              ? null
              : () {
                // Soft wall: a guest gets the phone→OTP sheet in place, then the
                // favourite is applied on success. See docs/guest_mode_plan.md.
                GuestGate.requireAccount(
                  () => _decideWished(
                    widget.isWished,
                    Get.find<FavouriteController>(),
                  ),
                  reason: 'favourite',
                );
                _controller.reverse().then((value) => _controller.forward());
              },
      child: ScaleTransition(
        scale: Tween(
          begin: 0.7,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: Icon(
          widget.isWished ? CupertinoIcons.heart_solid : CupertinoIcons.heart,
          color:
              widget.isWished
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).primaryColor.withValues(alpha: 0.3),
          size: widget.size,
        ),
      ),
    );
  }

  _decideWished(bool isWished, FavouriteController favouriteController) {
    if (widget.isStore) {
      isWished
          ? favouriteController.removeFromFavouriteList(
            widget.storeId ?? widget.store?.id,
            true,
          )
          : favouriteController.addToFavouriteList(
            null,
            widget.storeId ?? widget.store?.id,
            true,
          );
    } else {
      isWished
          ? favouriteController.removeFromFavouriteList(widget.item?.id, false)
          : favouriteController.addToFavouriteList(widget.item, null, false);
    }
  }
}
