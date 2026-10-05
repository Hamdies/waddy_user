import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';

/// What a store page says about the store before its products: its
/// store-wide discount and the owner's announcement. Shared by the
/// supermarket and specialty pages. Each draws nothing when the store has
/// nothing to say.

/// The store-wide discount: "20% off", its minimum and its cap.
class StoreDiscountBanner extends StatelessWidget {
  final Store store;

  const StoreDiscountBanner({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final discount = store.discount;
    if (discount == null || (discount.discount ?? 0) <= 0) {
      return const SizedBox.shrink();
    }
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accent = Theme.of(context).secondaryHeaderColor;
    final String discountText =
        discount.discountType == 'percent'
            ? '${discount.discount!.toStringAsFixed(0)}% ${'off'.tr}'
            : '${PriceConverter.convertPrice(discount.discount)} ${'off'.tr}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.local_offer_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  discountText,
                  style: waddyBold.copyWith(fontSize: 15, color: Colors.white),
                ),
                if ((discount.minPurchase ?? 0) > 0)
                  Text(
                    '${'min_purchase'.tr}: ${PriceConverter.convertPrice(discount.minPurchase)}',
                    style: waddyRegular.copyWith(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          if ((discount.maxDiscount ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${'up_to'.tr} ${PriceConverter.convertPrice(discount.maxDiscount)}',
                style: waddyBold.copyWith(fontSize: 10, color: primaryColor),
              ),
            ),
        ],
      ),
    );
  }
}

/// The owner's announcement ("Closed Friday for Eid").
class StoreAnnouncement extends StatelessWidget {
  final Store store;

  const StoreAnnouncement({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    if (!(store.announcementActive ?? false)) return const SizedBox.shrink();
    final Color primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Image.asset(Images.announcement, height: 20, width: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                store.announcementMessage ?? '',
                style: waddyRegular.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
