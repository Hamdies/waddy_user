import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/features/chat/domain/models/conversation_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ZomatoDeliveryPartnerCard extends StatelessWidget {
  final OrderModel order;
  final bool showChatPermission;
  final VoidCallback onTimerCancel;
  final VoidCallback onStartTracking;

  const ZomatoDeliveryPartnerCard({
    super.key,
    required this.order,
    required this.showChatPermission,
    required this.onTimerCancel,
    required this.onStartTracking,
  });

  @override
  Widget build(BuildContext context) {
    final dm = order.deliveryMan;
    if (dm == null) return _buildAssigning();

    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
    final bool showActions = status != null && status.isOngoing;
    final String name = '${dm.fName ?? ''} ${dm.lName ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WaddyColors.primary.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with mint border
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: WaddyColors.mint, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: WaddyColors.mint.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: CustomImage(
                image: '${dm.imageFullUrl}',
                height: 56,
                width: 56,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'delivery_partner'.tr,
                  style: waddyTitle.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: WaddyColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: WaddyColors.amber),
                    const SizedBox(width: 3),
                    Text(
                      '4.8 · 🛵 On the way',
                      style: waddyBody.copyWith(
                        fontSize: 12,
                        color: WaddyColors.inkLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showActions) ...[
            if (showChatPermission) ...[
              _buildAction(
                icon: Icons.chat_bubble_outline_rounded,
                filled: false,
                onTap: () async {
                  onTimerCancel();
                  await Get.toNamed(
                    RouteHelper.getChatRoute(
                      notificationBody: NotificationBodyModel(
                        deliverymanId: dm.id,
                        orderId: int.parse(order.id.toString()),
                      ),
                      user: User(
                        id: dm.id,
                        fName: dm.fName,
                        lName: dm.lName,
                        imageFullUrl: dm.imageFullUrl,
                      ),
                    ),
                  );
                  onStartTracking();
                },
              ),
              const SizedBox(width: 8),
            ],
            _buildAction(
              icon: Icons.phone_rounded,
              filled: true,
              onTap: () {
                if (dm.phone != null && dm.phone!.isNotEmpty) {
                  launchUrlString(
                    'tel:${dm.phone}',
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssigning() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WaddyColors.primary.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: WaddyColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: WaddyColors.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: WaddyColors.mint,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'delivery_partner'.tr,
                        style: waddyTitle.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: WaddyColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'finding_rider_maadi'.tr,
                        style: waddyBody.copyWith(
                          fontSize: 12,
                          color: WaddyColors.inkLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    color: WaddyColors.amber,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Text(
                    '⏳ Soon',
                    style: waddyLabel.copyWith(
                      color: const Color(0xFF5C3D00),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade100, height: 1),
          GestureDetector(
            onTap: () => Get.toNamed(RouteHelper.getSupportRoute()),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.headset_mic_outlined,
                    size: 15,
                    color: WaddyColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'need_help_with_order'.tr.isNotEmpty
                        ? 'need_help_with_order'.tr
                        : 'Need help with your order?',
                    style: waddyLabel.copyWith(
                      fontSize: 13,
                      color: WaddyColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? WaddyColors.primary : WaddyColors.surfaceRaised,
          border: filled
              ? null
              : Border.all(color: WaddyColors.divider, width: 1.5),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: WaddyColors.primary.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: filled ? WaddyColors.mint : WaddyColors.primary,
        ),
      ),
    );
  }
}
