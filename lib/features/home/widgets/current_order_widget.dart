import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/screens/order_details_screen.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';

class CurrentOrderWidget extends StatelessWidget {
  const CurrentOrderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AuthHelper.isLoggedIn()) return const SizedBox.shrink();

    return GetBuilder<OrderController>(
      builder: (ctrl) {
        final orders =
            ctrl.runningOrderModel?.orders
                ?.where((o) => o.orderStatus != AppConstants.delivered)
                .toList();
        if (orders == null || orders.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _OrderCard(order: orders.first),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  void _goToDetails() {
    HapticFeedback.lightImpact();
    Get.toNamed(
      RouteHelper.getOrderDetailsRoute(order.id),
      arguments: OrderDetailsScreen(orderId: order.id, orderModel: order),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case AppConstants.pending:
        return 'order_placed'.tr;
      case AppConstants.accepted:
      case AppConstants.confirmed:
        return 'order_confirmed'.tr;
      case AppConstants.processing:
        return 'being_prepared'.tr;
      case AppConstants.handover:
        return 'ready_for_pickup'.tr;
      case AppConstants.pickedUp:
        return 'order_arriving'.tr;
      default:
        return 'in_progress'.tr;
    }
  }

  String _lottieForStatus(String status) {
    switch (status) {
      case AppConstants.pending:
        return 'assets/animation/order_placed.json';
      case AppConstants.accepted:
      case AppConstants.confirmed:
        return 'assets/animation/order_confirmed.json';
      case AppConstants.processing:
        return 'assets/animation/preparing_order.json';
      case AppConstants.handover:
      case AppConstants.pickedUp:
        return 'assets/animation/delivery_order.json';
      default:
        return 'assets/animation/completed_order.json';
    }
  }

  String _eta(OrderModel order) {
    if (order.estimatedDeliveryAt != null &&
        order.estimatedDeliveryAt!.isNotEmpty) {
      final mins = DateConverter.estimatedDeliveryMinutes(
        estimatedDeliveryAt: order.estimatedDeliveryAt,
      );
      if (mins <= 0) return 'now'.tr;
      return '$mins ${'mins'.tr}';
    }
    final dt = order.store?.deliveryTime ?? '';
    if (dt.isEmpty) return '';
    final parts = dt.split('-');
    if (parts.length == 2) {
      final lo = int.tryParse(parts[0].trim());
      final hi = int.tryParse(parts[1].trim());
      if (lo != null && hi != null) return '$lo\u2013$hi ${'mins'.tr}';
    }
    final single = int.tryParse(dt.trim());
    if (single != null) return '$single ${'mins'.tr}';
    return dt;
  }

  @override
  Widget build(BuildContext context) {
    final status = order.orderStatus ?? '';
    final storeName = order.store?.name ?? 'your_order'.tr;
    final eta = _eta(order);
    final label = _statusLabel(status);
    final lottie = _lottieForStatus(status);

    // "Arriving now" only once the courier is actually en route \u2014 an expired
    // ETA on a pending order must not contradict the "Order Placed" status.
    final bool courierEnRoute = status == AppConstants.pickedUp;
    final String subtitle;
    if (eta == 'now'.tr) {
      subtitle =
          courierEnRoute ? '$storeName \u00b7 ${'arriving_now'.tr}' : storeName;
    } else if (eta.isNotEmpty) {
      subtitle = '$storeName \u00b7 $eta';
    } else {
      subtitle = storeName;
    }

    return Semantics(
      button: true,
      label: '$label. $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _goToDetails,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeMedium,
              vertical: Dimensions.paddingSizeMedium,
            ),
            decoration: BoxDecoration(
              color: WaddyColors.surface,
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              border: Border.all(
                color: WaddyColors.primary.withValues(alpha: 0.18),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: WaddyColors.shadowTeal,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: WaddyColors.primarySurface,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                      child: Lottie.asset(
                        lottie,
                        fit: BoxFit.cover,
                        repeat: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: waddyBold.copyWith(
                            fontSize: 11,
                            color: WaddyColors.primary,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: waddyMedium.copyWith(
                            fontSize: 12,
                            color: WaddyColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    // 48, not 44: this is the track-order CTA on a live order,
                    // the one control the user is most likely to be reaching
                    // for one-handed while walking.
                    constraints: const BoxConstraints(
                      minHeight: Dimensions.minTapTarget,
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeMedium,
                        vertical: Dimensions.paddingSizeSmall,
                      ),
                      decoration: BoxDecoration(
                        color: WaddyColors.primary,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                      ),
                      child: Text(
                        'track'.tr,
                        style: waddyMedium.copyWith(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
