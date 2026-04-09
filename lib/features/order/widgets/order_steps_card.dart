import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/features/order/widgets/verification_code_widget.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/theme/light_theme.dart';

class OrderStepsCard extends StatelessWidget {
  final OrderModel order;
  final OrderController orderController;
  final int itemCount;
  final bool parcel;
  final bool ongoing;
  final VoidCallback onViewDetails;

  const OrderStepsCard({
    super.key,
    required this.order,
    required this.orderController,
    required this.itemCount,
    required this.parcel,
    required this.ongoing,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
    final bool deliveryAssigned =
        order.deliveryMan != null && (status?.isDeliveryAssigned ?? false);
    final bool orderReceived =
        (status != null && status != OrderStatus.pending) ||
        order.paymentStatus == 'paid';

    return Container(
      margin: EdgeInsets.only(
        left: Dimensions.paddingSizeDefault,
        right: Dimensions.paddingSizeDefault,
        top: -20,
        bottom: Dimensions.paddingSizeExtraSmall,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: tilted item images + "View Details"
          Padding(
            padding: EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeSmall,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!parcel &&
                    orderController.orderDetails != null &&
                    orderController.orderDetails!.isNotEmpty)
                  _buildItemImagesFan(orderController.orderDetails!)
                else
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                  ),
                SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parcel
                            ? '1 ${'parcel'.tr}'
                            : '$itemCount ${'items'.tr}',
                        style: waddyBodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: Dimensions.fontSizeDefault,
                          color: WaddyColors.ink,
                        ),
                      ),
                      SizedBox(height: Dimensions.paddingSizeExtraSmall),
                      Text(
                        'to_be_packed'.tr,
                        style: waddyBody.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: WaddyColors.inkLight,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onViewDetails,
                  child: Text(
                    'view_details'.tr,
                    style: waddyLabel.copyWith(
                      fontWeight: FontWeight.w600,
                      color: WaddyColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade200, height: 1),

          // Step 1: Order received
          Padding(
            padding: EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeSmall,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeSmall,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bold step circle — solid primary when active
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutQuart,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: orderReceived
                        ? WaddyColors.primary
                        : Colors.grey.shade100,
                    boxShadow: orderReceived
                        ? [
                            BoxShadow(
                              color: WaddyColors.primary.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      orderReceived
                          ? Icons.check_rounded
                          : Icons.hourglass_empty_rounded,
                      key: ValueKey(orderReceived),
                      size: 22,
                      color: orderReceived
                          ? WaddyColors.mint
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeDefault),
                Expanded(
                  child: Text(
                    'We got your order 🎉',
                    style: waddyBodyMedium.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: orderReceived ? WaddyColors.ink : WaddyColors.inkLight,
                      fontWeight: orderReceived ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: orderReceived
                      ? Container(
                          key: const ValueKey('check'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: const BoxDecoration(
                            color: WaddyColors.mintSurface,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Text(
                            '✓ Done',
                            style: waddyMicro.copyWith(
                              fontWeight: FontWeight.w700,
                              color: WaddyColors.primary,
                              fontSize: 11,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ],
            ),
          ),

          // Step 2: Delivery partner
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeSmall,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeDefault,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bold step circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutQuart,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: deliveryAssigned
                        ? WaddyColors.primary
                        : Colors.grey.shade100,
                    boxShadow: deliveryAssigned
                        ? [
                            BoxShadow(
                              color: WaddyColors.primary.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.delivery_dining_rounded,
                    size: 22,
                    color: deliveryAssigned
                        ? WaddyColors.mint
                        : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeDefault),
                // Animated text — switches when rider is assigned
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutQuart,
                        )),
                        child: child,
                      ),
                    ),
                    child: deliveryAssigned
                        ? RichText(
                            key: const ValueKey('assigned'),
                            text: TextSpan(
                              style: waddyBodyMedium.copyWith(
                                fontSize: Dimensions.fontSizeDefault,
                                color: WaddyColors.ink,
                              ),
                              children: [
                                TextSpan(
                                  text: order.deliveryMan!.fName ?? 'your_delivery_partner_is'.tr,
                                  style: waddyBodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: Dimensions.fontSizeDefault,
                                    color: WaddyColors.ink,
                                  ),
                                ),
                                const TextSpan(text: ' is on the way 🛵'),
                              ],
                            ),
                          )
                        : Text(
                            key: const ValueKey('finding'),
                            'finding_rider_maadi'.tr,
                            style: waddyBody.copyWith(
                              fontSize: Dimensions.fontSizeDefault,
                              color: WaddyColors.inkLight,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // OTP / Delivery code
          if (order.otp != null && order.otp!.isNotEmpty && ongoing) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Divider(color: Colors.grey.shade200, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: VerificationCodeWidget(otp: order.otp!),
            ),
          ],

          // Cancellation reason
          if (order.orderStatus == 'canceled' &&
              order.cancellationReason != null) ...[
            Divider(color: Colors.grey.shade200, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.red),
                  const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'cancellation_note'.tr,
                          style: waddyBodyMedium.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: WaddyColors.error,
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                        Text(
                          order.cancellationReason!,
                          style: waddyMicro.copyWith(
                            color: WaddyColors.inkLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Delivery instruction
          if (order.deliveryInstruction != null &&
              order.deliveryInstruction!.isNotEmpty) ...[
            Divider(color: Colors.grey.shade200, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: WaddyColors.inkLight,
                  ),
                  const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'delivery_instruction'.tr,
                          style: waddyBodyMedium.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: WaddyColors.ink,
                          ),
                        ),
                        Text(
                          order.deliveryInstruction!,
                          style: waddyMicro.copyWith(
                            color: WaddyColors.inkLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Order ID + payment method
          Divider(color: Colors.grey.shade200, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeExtraSmall,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeSmall,
            ),
            child: Row(
              children: [
                Text(
                  '${'order_id'.tr}: ',
                  style: waddyMicro.copyWith(
                    color: WaddyColors.inkMuted,
                  ),
                ),
                Text(
                  '#${order.id}',
                  style: waddyLabel.copyWith(
                    fontWeight: FontWeight.w600,
                    color: WaddyColors.ink,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeExtraSmall,
                    vertical: Dimensions.paddingSizeExtraSmall / 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.paymentMethod == 'cash_on_delivery'
                        ? 'cash_on_delivery'.tr
                        : order.paymentMethod == 'wallet'
                        ? 'wallet_payment'.tr
                        : order.paymentMethod == 'partial_payment'
                        ? 'partial_payment'.tr
                        : order.paymentMethod == 'offline_payment'
                        ? 'offline_payment'.tr
                        : 'digital_payment'.tr,
                    style: waddyMicro.copyWith(
                      fontWeight: FontWeight.w600,
                      color: WaddyColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImagesFan(List<OrderDetailsModel> items) {
    final List<OrderDetailsModel> display = items.take(3).toList();
    final double fanWidth = 46 + 18.0 * (display.length - 1).clamp(0, 2);
    final List<double> angles = [-0.22, 0.0, 0.22];

    return SizedBox(
      width: fanWidth,
      height: 52,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: List.generate(display.length, (i) {
          return Positioned(
            left: i * 18.0,
            top: 3,
            child: Transform.rotate(
              angle: angles[i],
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomImage(
                    image: '${display[i].imageFullUrl}',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
