import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';

class EtaChipWidget extends StatelessWidget {
  final OrderModel order;
  const EtaChipWidget({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.estimatedDelivery != null &&
        order.estimatedDelivery!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeMedium,
          vertical: Dimensions.paddingSizeSmall,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 15,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              '${'estimated_delivery'.tr}: ${order.estimatedDelivery}',
              style: waddyMedium.copyWith(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
              ),
            ),
            if (DateConverter.formatEstimatedDeliveryTime(
                  order.estimatedDeliveryAt,
                ) !=
                null) ...[
              Text(
                ' (${DateConverter.formatEstimatedDeliveryTime(order.estimatedDeliveryAt)})',
                style: waddyMedium.copyWith(
                  fontSize: 12,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ],
        ),
      );
    } else if (order.store != null &&
        order.store!.deliveryTime != null &&
        order.store!.deliveryTime!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeMedium,
          vertical: Dimensions.paddingSizeSmall,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 15, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              '${'estimated_delivery'.tr}: ${order.store!.deliveryTime}',
              style: waddyMedium.copyWith(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
