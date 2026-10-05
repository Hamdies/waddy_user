import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/styles.dart';

/// The store info sheet (address, phone, hours, delivery) and its
/// opening-hours sheet, opened by tapping the store in a store page's header.
/// Shared by the supermarket and specialty pages.
abstract final class StoreInfoSheet {
  static Widget _buildInfoRow(IconData icon, String text, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: waddyRegular.copyWith(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFeatureBadge(
    IconData icon,
    String label,
    Color primaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: waddyMedium.copyWith(fontSize: 11, color: primaryColor),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STORE INFO DIALOG — triggered by info icon in app bar
  // ═══════════════════════════════════════════════════════════════
  static void show(BuildContext context, Store store) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final bool hasRating = (store.avgRating ?? 0) > 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Store logo + name
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: CustomImage(
                        image: '${store.logoFullUrl}',
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name ?? '',
                          style: waddyBold.copyWith(
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        if (hasRating) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${store.avgRating!.toStringAsFixed(1)} (${store.ratingCount ?? 0})',
                                style: waddyMedium.copyWith(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              // Address
              if (store.address != null && store.address!.isNotEmpty)
                _buildInfoRow(
                  Icons.location_on_outlined,
                  store.address!,
                  primaryColor,
                ),
              // Phone
              if (store.phone != null && store.phone!.isNotEmpty)
                _buildInfoRow(Icons.phone_outlined, store.phone!, primaryColor),
              // Delivery time
              if (store.deliveryTime != null && store.deliveryTime!.isNotEmpty)
                _buildInfoRow(
                  Icons.delivery_dining_rounded,
                  store.deliveryTime!,
                  primaryColor,
                ),
              // Delivery fee
              if (store.freeDelivery == true)
                _buildInfoRow(
                  Icons.local_shipping_outlined,
                  'free_delivery'.tr,
                  primaryColor,
                )
              else if ((store.minimumShippingCharge ?? 0) > 0)
                _buildInfoRow(
                  Icons.local_shipping_outlined,
                  '${'from'.tr} ${PriceConverter.convertPrice(store.minimumShippingCharge)}',
                  primaryColor,
                ),
              // Min order
              if ((store.minimumOrder ?? 0) > 0)
                _buildInfoRow(
                  Icons.shopping_basket_outlined,
                  '${'min'.tr} ${PriceConverter.convertPrice(store.minimumOrder)}',
                  primaryColor,
                ),
              const SizedBox(height: 8),
              // Feature badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (store.delivery == true)
                    _buildFeatureBadge(
                      Icons.delivery_dining_rounded,
                      'delivery'.tr,
                      primaryColor,
                    ),
                  if (store.takeAway == true)
                    _buildFeatureBadge(
                      Icons.shopping_bag_outlined,
                      'take_away'.tr,
                      primaryColor,
                    ),
                  if (store.scheduleOrder == true)
                    _buildFeatureBadge(
                      Icons.schedule_rounded,
                      'schedule_order'.tr,
                      primaryColor,
                    ),
                ],
              ),
              // Store hours link
              if (store.schedules != null && store.schedules!.isNotEmpty) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _showStoreHoursSheet(context, store, primaryColor);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'store_hours'.tr,
                          style: waddyMedium.copyWith(
                            fontSize: 13,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STORE HOURS BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════
  static void _showStoreHoursSheet(
    BuildContext context,
    Store store,
    Color primaryColor,
  ) {
    final dayNames = [
      'monday'.tr,
      'tuesday'.tr,
      'wednesday'.tr,
      'thursday'.tr,
      'friday'.tr,
      'saturday'.tr,
      'sunday'.tr,
    ];
    final int todayWeekday =
        DateTime.now().weekday == 7 ? 0 : DateTime.now().weekday;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'store_hours'.tr,
                style: waddyBold.copyWith(fontSize: 17, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              ...List.generate(7, (dayIndex) {
                final daySchedules =
                    store.schedules!.where((s) => s.day == dayIndex).toList();
                final isToday = dayIndex == todayWeekday;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color:
                        isToday
                            ? primaryColor.withValues(alpha: 0.06)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          dayNames[dayIndex],
                          style: (isToday ? waddyBold : waddyMedium).copyWith(
                            fontSize: 13,
                            color: isToday ? primaryColor : Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          daySchedules.isEmpty
                              ? 'closed'.tr
                              : daySchedules
                                  .map(
                                    (s) =>
                                        '${s.openingTime} - ${s.closingTime}',
                                  )
                                  .join(', '),
                          style: waddyRegular.copyWith(
                            fontSize: 13,
                            color:
                                daySchedules.isEmpty
                                    ? Colors.red.shade600
                                    : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'today'.tr,
                            style: waddyBold.copyWith(
                              fontSize: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
