import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/styles.dart';

class ZomatoStatusHeader extends StatelessWidget {
  final OrderModel order;
  final int? etaMinutes;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onRefreshEta;

  const ZomatoStatusHeader({
    super.key,
    required this.order,
    required this.etaMinutes,
    required this.onBack,
    required this.onShare,
    required this.onRefreshEta,
  });

  String _statusTitle(OrderStatus? status) {
    if (status == null) return 'Order Placed';
    switch (status) {
      case OrderStatus.pending:
        return 'Order Placed';
      case OrderStatus.accepted:
      case OrderStatus.confirmed:
        return 'Order Confirmed';
      case OrderStatus.processing:
        return 'Being Prepared';
      case OrderStatus.handover:
        return 'Collecting Your Order';
      case OrderStatus.pickedUp:
        return 'On the Way!';
      case OrderStatus.delivered:
        return 'Delivered!';
      default:
        return (order.orderStatus ?? '').tr.capitalizeFirst ?? 'Processing';
    }
  }

  String _statusSubtitle(OrderStatus? status) {
    if (status == null) return 'Your order is being processed';
    switch (status) {
      case OrderStatus.pending:
        return 'Your order is being processed';
      case OrderStatus.accepted:
      case OrderStatus.confirmed:
        return 'The restaurant has confirmed your order';
      case OrderStatus.processing:
        return 'The chef is working on your order 👨‍🍳';
      case OrderStatus.handover:
        return 'Your order is being handed to the rider';
      case OrderStatus.pickedUp:
        return etaMinutes != null && etaMinutes! > 0
            ? 'Arriving in about $etaMinutes min'
            : 'Your rider is heading your way 🛵';
      case OrderStatus.delivered:
        return 'Hope you enjoy your meal! 🎉';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);

    // White pill below the teal hero — "Order Placed / Being Prepared" big heading
    return Container(
      width: double.infinity,
      color: WaddyColors.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            _statusTitle(status),
            style: waddyDisplay.copyWith(
              fontSize: 26,
              color: WaddyColors.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _statusSubtitle(status),
            style: waddyBody.copyWith(
              fontSize: 14,
              color: WaddyColors.inkLight,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
