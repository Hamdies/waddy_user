import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/features/chat/domain/models/conversation_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DeliveryManCard extends StatelessWidget {
  final OrderModel order;
  final bool showChatPermission;
  final VoidCallback onTimerCancel;
  final VoidCallback onStartTracking;

  const DeliveryManCard({
    super.key,
    required this.order,
    required this.showChatPermission,
    required this.onTimerCancel,
    required this.onStartTracking,
  });

  @override
  Widget build(BuildContext context) {
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
    final bool showActions = status != null && status.isOngoing;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeExtraSmall,
      ),
      padding: EdgeInsets.all(
        Dimensions.paddingSizeSmall + Dimensions.paddingSizeExtraSmall,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipOval(
            child: CustomImage(
              image: '${order.deliveryMan!.imageFullUrl}',
              height: 40,
              width: 40,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.deliveryMan!.fName} ${order.deliveryMan!.lName}',
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  'delivery_man'.tr,
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (showActions) ...[
            if (showChatPermission)
              _buildCircleAction(context, Icons.chat_bubble_outline, () async {
                onTimerCancel();
                await Get.toNamed(
                  RouteHelper.getChatRoute(
                    notificationBody: NotificationBodyModel(
                      deliverymanId: order.deliveryMan!.id,
                      orderId: int.parse(order.id.toString()),
                    ),
                    user: User(
                      id: order.deliveryMan!.id,
                      fName: order.deliveryMan!.fName,
                      lName: order.deliveryMan!.lName,
                      imageFullUrl: order.deliveryMan!.imageFullUrl,
                    ),
                  ),
                );
                onStartTracking();
              }),
            const SizedBox(width: 8),
            _buildCircleAction(context, Icons.phone_outlined, () {
              if (order.deliveryMan!.phone != null &&
                  order.deliveryMan!.phone!.isNotEmpty) {
                launchUrlString(
                  'tel:${order.deliveryMan!.phone}',
                  mode: LaunchMode.externalApplication,
                );
              }
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCircleAction(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        ),
        child: Icon(icon, size: 18, color: Theme.of(context).primaryColor),
      ),
    );
  }
}
