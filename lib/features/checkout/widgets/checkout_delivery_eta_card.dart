import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:get/get.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:waddy_app/features/checkout/widgets/time_slot_section.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// "Delivery · Arriving in approx. 15-25 min · Change".
///
/// Collapses what used to be two cards — delivery type and preference time —
/// into one line, because for almost every order neither is changed. Both
/// still exist: "Change" opens them in a sheet. The link is hidden when there
/// is nothing to change (delivery-only store, no scheduling).
class CheckoutDeliveryEtaCard extends StatelessWidget {
  final CheckoutController checkoutController;
  final List<CartModel?>? cartList;
  final int? storeId;
  final bool todayClosed;
  final bool tomorrowClosed;
  final Module? module;
  final double total;
  final double deliveryCharge;
  final String deliveryChargeForView;
  final JustTheController scheduleTooltipController;

  const CheckoutDeliveryEtaCard({
    super.key,
    required this.checkoutController,
    required this.cartList,
    required this.storeId,
    required this.todayClosed,
    required this.tomorrowClosed,
    required this.module,
    required this.total,
    required this.deliveryCharge,
    required this.deliveryChargeForView,
    required this.scheduleTooltipController,
  });

  bool get _canDeliver =>
      Get.find<SplashController>().configModel.homeDeliveryStatus == 1 &&
      (checkoutController.store?.delivery ?? false);

  bool get _canTakeAway =>
      storeId == null &&
      Get.find<SplashController>().configModel.takeawayStatus == 1 &&
      (checkoutController.store?.takeAway ?? false);

  // Same gate TimeSlotSection applies to itself.
  bool get _canSchedule =>
      storeId == null &&
      (checkoutController.store?.scheduleOrder ?? false) &&
      (cartList?.isNotEmpty ?? false) &&
      cartList![0]!.item!.availableDateStarts == null;

  @override
  Widget build(BuildContext context) {
    final bool takeAway = checkoutController.orderType == 'take_away';
    final bool closed =
        (checkoutController.selectedDateSlot == 0 && todayClosed) ||
        (checkoutController.selectedDateSlot == 1 && tomorrowClosed);
    final String? eta = checkoutController.store?.deliveryTime;

    final String subtitle;
    if (closed) {
      subtitle =
          (module?.showRestaurantText ?? false)
              ? 'restaurant_is_closed'.tr
              : 'store_is_closed'.tr;
    } else if (checkoutController.preferableTime.isNotEmpty) {
      subtitle = checkoutController.preferableTime;
    } else if (eta != null && eta.isNotEmpty) {
      subtitle = (takeAway ? 'ready_in_approx' : 'arriving_in_approx').trParams(
        {'time': eta},
      );
    } else {
      subtitle = '';
    }

    final bool canChange = (_canDeliver && _canTakeAway) || _canSchedule;

    return CheckoutCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeMedium,
      ),
      child: Row(
        children: [
          CheckoutIcon(
            icon:
                takeAway
                    ? HugeIcons.strokeRoundedShoppingBag02
                    : HugeIcons.strokeRoundedMotorbike02,
            size: 22,
            color: WaddyColors.ink,
          ),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  takeAway ? 'take_away'.tr : 'delivery'.tr,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: WaddyColors.ink,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: closed ? WaddyColors.error : WaddyColors.inkLight,
                    ),
                  ),
              ],
            ),
          ),
          if (canChange)
            TextButton(
              onPressed: () => _openOptions(context),
              style: TextButton.styleFrom(
                foregroundColor: WaddyColors.mintInk,
                minimumSize: const Size(
                  Dimensions.minTapTarget,
                  Dimensions.minTapTarget,
                ),
              ),
              child: Text(
                'change'.tr,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: WaddyColors.mintInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => GetBuilder<CheckoutController>(
            builder: (controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: WaddyColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(Dimensions.radiusExtraLarge),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SheetHandle(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Dimensions.paddingSizeDefault,
                          Dimensions.paddingSizeSmall,
                          Dimensions.paddingSizeDefault,
                          Dimensions.paddingSizeSmall,
                        ),
                        child: Text(
                          'delivery_options'.tr,
                          style: waddyBold.copyWith(
                            fontSize: Dimensions.fontSizeLarge,
                            color: WaddyColors.ink,
                          ),
                        ),
                      ),
                      if (_canDeliver && _canTakeAway) ...[
                        _OrderTypeOption(
                          icon: HugeIcons.strokeRoundedMotorbike02,
                          title: 'delivery'.tr,
                          subtitle: deliveryChargeForView,
                          selected: controller.orderType == 'delivery',
                          onTap: () => _selectOrderType(controller, 'delivery'),
                        ),
                        _OrderTypeOption(
                          icon: HugeIcons.strokeRoundedShoppingBag02,
                          title: 'take_away'.tr,
                          subtitle: 'free'.tr,
                          selected: controller.orderType == 'take_away',
                          onTap:
                              () => _selectOrderType(controller, 'take_away'),
                        ),
                      ],
                      if (_canSchedule)
                        TimeSlotSection(
                          storeId: storeId,
                          checkoutController: controller,
                          cartList: cartList,
                          tooltipController2: scheduleTooltipController,
                          tomorrowClosed: tomorrowClosed,
                          todayClosed: todayClosed,
                          module: module,
                        ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  /// The tap handler DeliveryOptionButtonWidget ran, minus its initState.
  ///
  /// That widget also forced the order type back to its default every time it
  /// mounted, which is harmless on a page that mounts once but would undo the
  /// user's choice each time this sheet opened. The default is applied by
  /// StoreController when the store loads, so nothing is lost by leaving it
  /// out.
  void _selectOrderType(CheckoutController controller, String value) {
    controller.setOrderType(value);
    controller.setInstruction(-1);

    if (value == 'take_away') {
      if (controller.isPartialPay) {
        final double tips = double.tryParse(controller.tipController.text) ?? 0;
        controller.checkBalanceStatus(total, deliveryCharge + tips);
      }
    } else {
      if (controller.isPartialPay) {
        controller.changePartialPayment();
      } else {
        controller.setPaymentMethod(-1);
      }
    }
  }
}

class _OrderTypeOption extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _OrderTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: Dimensions.paddingSizeMedium,
          ),
          child: Row(
            children: [
              CheckoutIcon(icon: icon, size: 22, color: WaddyColors.ink),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: waddyMedium.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: WaddyColors.ink,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: waddyRegular.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: WaddyColors.inkLight,
                        ),
                      ),
                  ],
                ),
              ),
              CheckoutRadio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: Dimensions.paddingSizeMedium),
        decoration: BoxDecoration(
          color: WaddyColors.divider,
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
        ),
      ),
    );
  }
}
