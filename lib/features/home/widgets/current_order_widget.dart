import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/order/domain/models/order_details_model.dart';
import 'package:sixam_mart/features/order/screens/order_details_screen.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

/// Compact order status card — horizontal stepper with items, time & total.
class CurrentOrderWidget extends StatelessWidget {
  const CurrentOrderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AuthHelper.isLoggedIn()) return const SizedBox.shrink();

    return GetBuilder<OrderController>(
      builder: (orderController) {
        final orders = orderController.runningOrderModel?.orders;
        if (orders == null || orders.isEmpty) return const SizedBox.shrink();

        final order = orders.first;

        // Trigger fetch of order details for item images (cached)
        if (order.id != null &&
            !orderController.orderDetailsCache.containsKey(order.id)) {
          orderController.fetchOrderDetailsForList(order.id!);
        }

        final details = orderController.orderDetailsCache[order.id];

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: 6,
          ),
          child: _CompactOrderCard(order: order, details: details),
        );
      },
    );
  }
}

class _CompactOrderCard extends StatelessWidget {
  final OrderModel order;
  final List<OrderDetailsModel>? details;
  const _CompactOrderCard({required this.order, this.details});

  static const _stepLabels = ['Placed', 'Confirmed', 'Preparing', 'On the way'];
  static const _stepIcons = [
    Icons.receipt_long_rounded,
    Icons.check_circle_outline_rounded,
    Icons.restaurant_rounded,
    Icons.delivery_dining_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).primaryColor;
    final Color accent = Theme.of(context).secondaryHeaderColor;
    final status = order.orderStatus ?? '';
    final step = _progressStep(status);
    final statusInfo = _statusInfo(status, order.store?.name ?? '');
    final storeName = order.store?.name ?? '';
    final deliveryTime = order.store?.deliveryTime ?? '';
    final total = order.orderAmount ?? 0;
    final itemCount = order.detailsCount ?? details?.length ?? 0;

    // Collect item image URLs (max 3)
    final List<String> itemImages = [];
    if (details != null) {
      for (final d in details!) {
        final url = d.itemDetails?.imageFullUrl ?? d.imageFullUrl;
        if (url != null && url.isNotEmpty && itemImages.length < 3) {
          itemImages.add(url);
        }
      }
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Get.toNamed(
          RouteHelper.getOrderDetailsRoute(order.id),
          arguments: OrderDetailsScreen(orderId: order.id, orderModel: order),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Row 1: Status headline + subtitle ──
            // Row(
            //   crossAxisAlignment: CrossAxisAlignment.start,
            //   children: [
            //     Padding(
            //       padding: const EdgeInsets.only(top: 5),
            //       child: Container(
            //         width: 8,
            //         height: 8,
            //         decoration: BoxDecoration(
            //           shape: BoxShape.circle,
            //           color: step < 3 ? const Color(0xFFFFA726) : accent,
            //           boxShadow: [
            //             BoxShadow(
            //               color: (step < 3 ? const Color(0xFFFFA726) : accent)
            //                   .withValues(alpha: 0.4),
            //               blurRadius: 6,
            //             ),
            //           ],
            //         ),
            //       ),
            //     ),
            //     const SizedBox(width: 8),
            //     Expanded(
            //       child: Column(
            //         crossAxisAlignment: CrossAxisAlignment.start,
            //         children: [
            //           Text(
            //             statusInfo.headline,
            //             style: robotoBold.copyWith(
            //               fontSize: 12.5,
            //               color: primary,
            //             ),
            //             maxLines: 1,
            //             overflow: TextOverflow.ellipsis,
            //           ),
            //           const SizedBox(height: 2),
            //           Text(
            //             statusInfo.subtitle,
            //             style: robotoRegular.copyWith(
            //               fontSize: 10.5,
            //               color: Colors.grey.shade500,
            //             ),
            //             maxLines: 1,
            //             overflow: TextOverflow.ellipsis,
            //           ),
            //         ],
            //       ),
            //     ),
            //     Text(
            //       '#${order.id}',
            //       style: robotoMedium.copyWith(
            //         fontSize: 10,
            //         color: Colors.grey.shade400,
            //       ),
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 10),

            // ── Row 2: Horizontal progress stepper ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: List.generate(4, (i) {
                  final done = i <= step;
                  final isCurrent = i == step;
                  return Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                done
                                    ? accent.withValues(
                                      alpha: isCurrent ? 1.0 : 0.85,
                                    )
                                    : Colors.grey.shade100,
                            border: Border.all(
                              color: done ? accent : Colors.grey.shade300,
                              width: isCurrent ? 2.5 : 1.5,
                            ),
                            boxShadow:
                                isCurrent
                                    ? [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Icon(
                            done && !isCurrent
                                ? Icons.check_rounded
                                : _stepIcons[i],
                            size: 15,
                            color: done ? primary : Colors.grey.shade400,
                          ),
                        ),
                        if (i < 3)
                          Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: i < step ? accent : Colors.grey.shade200,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Text(
                      _stepLabels[i],
                      textAlign:
                          i == 0
                              ? TextAlign.left
                              : i == 3
                              ? TextAlign.right
                              : TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            i == step ? FontWeight.w700 : FontWeight.w500,
                        color: i <= step ? primary : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Row 3: Item images + Store + Total + Time ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // Item images (overlapping circles)
                  if (itemImages.isNotEmpty)
                    SizedBox(
                      width: 20.0 + (itemImages.length - 1) * 14.0,
                      height: 26,
                      child: Stack(
                        children: List.generate(itemImages.length, (i) {
                          return Positioned(
                            left: i * 14.0,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: CustomImage(
                                  image: itemImages[i],
                                  fit: BoxFit.cover,
                                  width: 26,
                                  height: 26,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  if (itemImages.isNotEmpty) const SizedBox(width: 8),

                  // Store name + item count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName.isNotEmpty ? storeName : 'your_order'.tr,
                          style: robotoMedium.copyWith(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (itemCount > 0)
                          Text(
                            '$itemCount ${'items'.tr}',
                            style: robotoRegular.copyWith(
                              fontSize: 9.5,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Total
                  if (total > 0) ...[
                    Text(
                      PriceConverter.convertPrice(total),
                      style: robotoBold.copyWith(fontSize: 12, color: primary),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Delivery time pill
                  if (deliveryTime.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 9, color: primary),
                          const SizedBox(width: 2),
                          Text(
                            deliveryTime,
                            style: robotoBold.copyWith(
                              fontSize: 9,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Row 4: View Order CTA ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'view_order'.tr,
                    style: robotoBold.copyWith(fontSize: 11.5, color: primary),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _progressStep(String s) {
    if (s == AppConstants.pending) return 0;
    if (s == AppConstants.accepted || s == AppConstants.confirmed) return 1;
    if (s == AppConstants.processing) return 2;
    if (s == AppConstants.handover || s == AppConstants.pickedUp) return 3;
    return 0;
  }

  _StatusInfo _statusInfo(String s, String store) {
    final name = store.isNotEmpty ? store : 'the store';
    switch (s) {
      case AppConstants.pending:
        return _StatusInfo(
          'Waiting for confirmation',
          'We\'ve sent your order to $name',
        );
      case AppConstants.accepted:
      case AppConstants.confirmed:
        return _StatusInfo('Order confirmed ✓', '$name accepted your order');
      case AppConstants.processing:
        return _StatusInfo('Preparing your order', '$name is getting it ready');
      case AppConstants.handover:
        return _StatusInfo(
          'Ready for pickup',
          'Your order is waiting at $name',
        );
      case AppConstants.pickedUp:
        return _StatusInfo(
          'On the way to you',
          'Your rider picked up from $name',
        );
      default:
        return const _StatusInfo(
          'Order in progress',
          'We\'re working on your order',
        );
    }
  }
}

class _StatusInfo {
  final String headline;
  final String subtitle;
  const _StatusInfo(this.headline, this.subtitle);
}
