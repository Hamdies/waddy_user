import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/order/screens/order_details_screen.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/date_converter.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/app_design_tokens.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class CurrentOrderWidget extends StatelessWidget {
  const CurrentOrderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AuthHelper.isLoggedIn()) return const SizedBox.shrink();

    return GetBuilder<OrderController>(
      builder: (ctrl) {
        final orders = ctrl.runningOrderModel?.orders
            ?.where((o) => o.orderStatus != AppConstants.delivered)
            .toList();
        if (orders == null || orders.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: 6,
          ),
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
      case AppConstants.pending:        return 'ORDER PLACED';
      case AppConstants.accepted:
      case AppConstants.confirmed:      return 'ORDER CONFIRMED';
      case AppConstants.processing:     return 'BEING PREPARED';
      case AppConstants.handover:       return 'READY FOR PICKUP';
      case AppConstants.pickedUp:       return 'ORDER ARRIVING';
      default:                          return 'IN PROGRESS';
    }
  }

  String _lottieForStatus(String status) {
    switch (status) {
      case AppConstants.pending:        return 'assets/animation/order_placed.json';
      case AppConstants.accepted:
      case AppConstants.confirmed:      return 'assets/animation/order_confirmed.json';
      case AppConstants.processing:     return 'assets/animation/preparing_order.json';
      case AppConstants.handover:
      case AppConstants.pickedUp:       return 'assets/animation/delivery_order.json';
      default:                          return 'assets/animation/completed_order.json';
    }
  }

  int _segmentForStatus(String s) {
    switch (s) {
      case AppConstants.pending:        return 0;
      case AppConstants.accepted:
      case AppConstants.confirmed:      return 1;
      case AppConstants.processing:     return 2;
      case AppConstants.handover:       return 3;
      case AppConstants.pickedUp:       return 3;
      default:                          return 0;
    }
  }

  String _eta(OrderModel order) {
    if (order.estimatedDeliveryAt != null &&
        order.estimatedDeliveryAt!.isNotEmpty) {
      final mins = DateConverter.estimatedDeliveryMinutes(
        estimatedDeliveryAt: order.estimatedDeliveryAt,
      );
      if (mins <= 0) return 'Now';
      return '$mins mins';
    }
    final dt = order.store?.deliveryTime ?? '';
    if (dt.isEmpty) return '';
    final parts = dt.split('-');
    if (parts.length == 2) {
      final lo = int.tryParse(parts[0].trim());
      final hi = int.tryParse(parts[1].trim());
      if (lo != null && hi != null) return '$lo\u2013$hi mins';
    }
    final single = int.tryParse(dt.trim());
    if (single != null) return '$single mins';
    return dt;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent  = Theme.of(context).secondaryHeaderColor;
    final bool isRtl    = Directionality.of(context) == TextDirection.rtl;

    final status      = order.orderStatus ?? '';
    final storeName   = order.store?.name ?? 'Your Order';
    final eta         = _eta(order);
    final label       = _statusLabel(status);
    final segment     = _segmentForStatus(status);
    final lottie      = _lottieForStatus(status);

    // "Waddy Food · 12 mins away"
    final subtitle = eta.isNotEmpty ? '$storeName \u00b7 $eta away' : storeName;

    return GestureDetector(
      onTap: _goToDetails,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).secondaryHeaderColor.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Lottie animation — rounded square ────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Lottie.asset(
                  lottie,
                  fit: BoxFit.cover,
                  repeat: true,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ── Status label + subtitle ──────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: robotoBold.copyWith(
                      fontSize: 10,
                      color: AppDesignTokens.primaryDark,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: robotoMedium.copyWith(
                      fontSize: 12,
                      color: const Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── 3-segment progress bar ────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).secondaryHeaderColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Track',
              style: robotoMedium.copyWith(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
            
          
           

            const SizedBox(width: 8),

            // ── Chevron ───────────────────────────────────────
            
          ],
        ),
      ),
    );
  }
}
