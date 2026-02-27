import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/store/domain/models/store_model.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/util/styles.dart';

class MinimumOrderProgressWidget extends StatelessWidget {
  final double subTotal;
  final Store? store;

  const MinimumOrderProgressWidget({
    super.key,
    required this.subTotal,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    if (store == null || store!.minimumOrder == null || store!.minimumOrder == 0) {
      return const SizedBox();
    }

    final double minimumOrder = store!.minimumOrder!;
    final double remaining = minimumOrder - subTotal;
    final bool isMet = remaining <= 0;
    final double progress = (subTotal / minimumOrder).clamp(0.0, 1.0);

    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMet
              ? accentColor.withValues(alpha: 0.3)
              : primaryColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isMet ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 18,
                color: isMet ? accentColor : primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMet
                      ? 'minimum_order_reached'.tr
                      : '${'add'.tr} ${PriceConverter.convertPrice(remaining)} ${'more_to_reach_minimum'.tr} ${PriceConverter.convertPrice(minimumOrder)}',
                  style: robotoMedium.copyWith(
                    fontSize: 12,
                    color: isMet ? primaryColor : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isMet ? accentColor : primaryColor,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                PriceConverter.convertPrice(subTotal),
                style: robotoMedium.copyWith(
                  fontSize: 11,
                  color: isMet ? accentColor : primaryColor,
                ),
                textDirection: TextDirection.ltr,
              ),
              Text(
                '${'min'.tr}: ${PriceConverter.convertPrice(minimumOrder)}',
                style: robotoRegular.copyWith(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
