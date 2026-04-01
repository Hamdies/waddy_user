import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_details_model.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/order/domain/models/order_status.dart';
import 'package:sixam_mart/features/order/widgets/lucky_spin_section.dart';
import 'package:sixam_mart/features/order/widgets/verification_code_widget.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

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
                        style: robotoBold.copyWith(
                          fontSize: Dimensions.fontSizeDefault,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: Dimensions.paddingSizeExtraSmall),
                      Text(
                        'to_be_packed'.tr,
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onViewDetails,
                  child: Text(
                    'view_details'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: Theme.of(context).primaryColor,
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
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        orderReceived
                            ? const Color(0xFF1BA672).withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                  ),
                  child: Icon(
                    orderReceived
                        ? Icons.check_circle_outline_rounded
                        : Icons.hourglass_empty_rounded,
                    size: 20,
                    color:
                        orderReceived
                            ? const Color(0xFF1BA672)
                            : Colors.grey.shade400,
                  ),
                ),
                SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Colors.black87,
                      ),
                      children: [
                        TextSpan(text: '${'yay'.tr}! ${'we_have'.tr} '),
                        TextSpan(
                          text: 'received'.tr,
                          style: robotoBold.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(text: ' ${'your_order'.tr}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dashed divider
          Padding(
            padding: EdgeInsets.only(
              left: ResponsiveHelper.isMobile(context) ? 50 : 54,
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: DashedLinePainter(),
            ),
          ),

          // Step 2: Delivery partner
          Padding(
            padding: EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeSmall,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeDefault,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        deliveryAssigned
                            ? const Color(0xFF1BA672).withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                  ),
                  child: Icon(
                    Icons.delivery_dining_rounded,
                    size: 20,
                    color:
                        deliveryAssigned
                            ? const Color(0xFF1BA672)
                            : Colors.grey.shade400,
                  ),
                ),
                SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: Text(
                    deliveryAssigned
                        ? '${'your_delivery_partner_is'.tr} ${order.deliveryMan!.fName ?? ''}'
                        : 'we_will_assign_a_delivery_partner_soon'.tr,
                    style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // OTP / Delivery code
          if (order.otp != null && order.otp!.isNotEmpty && ongoing) ...[
            SizedBox(height: Dimensions.paddingSizeSmall),
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
                  SizedBox(width: Dimensions.paddingSizeExtraSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'cancellation_note'.tr,
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(height: Dimensions.paddingSizeExtraSmall),
                        Text(
                          order.cancellationReason!,
                          style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeExtraSmall,
                            color: Colors.grey.shade600,
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
                  Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  SizedBox(width: Dimensions.paddingSizeExtraSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'delivery_instruction'.tr,
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          order.deliveryInstruction!,
                          style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeExtraSmall,
                            color: Colors.grey.shade600,
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
            padding: EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeExtraSmall,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeSmall,
            ),
            child: Row(
              children: [
                Text(
                  '${'order_id'.tr}: ',
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '#${order.id}',
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
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
                    style: robotoMedium.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontSize: Dimensions.fontSizeOverSmall,
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
