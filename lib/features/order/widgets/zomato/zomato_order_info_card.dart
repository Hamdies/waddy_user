import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/styles.dart';

class ZomatoOrderInfoCard extends StatelessWidget {
  final OrderModel order;
  final OrderController orderController;
  final VoidCallback? onViewDetails;
  final bool ongoing;

  const ZomatoOrderInfoCard({
    super.key,
    required this.order,
    required this.orderController,
    this.onViewDetails,
    this.ongoing = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = orderController.orderDetails ?? [];
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);

    final bool orderReceived =
        (status != null && status != OrderStatus.pending) ||
        order.paymentStatus == 'paid';
    final bool deliveryAssigned =
        order.deliveryMan != null && (status?.isDeliveryAssigned ?? false);

    final bool showOtp =
        order.otp != null && order.otp!.isNotEmpty && ongoing;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: item fan + count + View Details ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (items.isNotEmpty)
                  _buildItemImagesFan(items)
                else
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: WaddyColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: WaddyColors.primary,
                      size: 26,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        () {
                          final count = items.isNotEmpty ? items.length : 1;
                          return count == 1 ? '1 ${'item'.tr}' : '$count ${'items'.tr}';
                        }(),
                        style: waddyTitle.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: WaddyColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items.isNotEmpty
                            ? (items.first.itemDetails?.name ?? 'to_be_packed'.tr)
                            : 'to_be_packed'.tr,
                        style: waddyBody.copyWith(
                          fontSize: 12,
                          color: WaddyColors.inkLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onViewDetails != null)
                  GestureDetector(
                    onTap: onViewDetails,
                    child: Text(
                      'view_details'.tr,
                      style: waddyLabel.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: WaddyColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Divider(color: Colors.grey.shade100, height: 1),

          // ── Step 1: Order received ────────────────────────────────────
          _buildStepRow(
            isActive: orderReceived,
            icon: orderReceived
                ? Icons.check_rounded
                : Icons.hourglass_empty_rounded,
            label: 'We got your order 🎉',
          ),

          // Dashed connector between steps
          Padding(
            padding: const EdgeInsets.only(left: 39),
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(),
            ),
          ),

          // ── Step 2: Delivery partner ──────────────────────────────────
          _buildDeliveryStepRow(
            isActive: deliveryAssigned,
            order: order,
          ),

          // ── OTP Verification Code ─────────────────────────────────────
          if (showOtp) ...[
            const SizedBox(height: 4),
            _buildOtpBlock(order.otp!),
          ],

          // ── Order ID + payment ────────────────────────────────────────
          Divider(color: Colors.grey.shade100, height: 1),
          _buildOrderFooter(context),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required bool isActive,
    required IconData icon,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutQuart,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? WaddyColors.primary : Colors.grey.shade100,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: WaddyColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? WaddyColors.mint : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: waddyBodyMedium.copyWith(
                fontSize: 14,
                color: isActive ? WaddyColors.ink : WaddyColors.inkLight,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryStepRow({
    required bool isActive,
    required OrderModel order,
  }) {
    final dm = order.deliveryMan;
    final String label = isActive && dm != null
        ? '${dm.fName ?? ''} is on the way 🛵'
        : 'finding_rider_maadi'.tr;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutQuart,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? WaddyColors.primary : Colors.grey.shade100,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: WaddyColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.delivery_dining_rounded,
              size: 18,
              color: isActive ? WaddyColors.mint : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutQuart),
                  ),
                  child: child,
                ),
              ),
              child: Text(
                label,
                key: ValueKey(isActive),
                style: waddyBodyMedium.copyWith(
                  fontSize: 14,
                  color: isActive ? WaddyColors.ink : WaddyColors.inkLight,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Prominent mint OTP card — matches the screenshot style exactly
  Widget _buildOtpBlock(String otp) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: WaddyColors.mint,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: WaddyColors.mint.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: WaddyColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: WaddyColors.mint,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VERIFICATION CODE',
                      style: waddyLabel.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: WaddyColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'SHARE WITH DRIVER ONLY',
                      style: waddyMicro.copyWith(
                        fontSize: 9,
                        color: WaddyColors.primary.withValues(alpha: 0.65),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Digit blocks
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: otp.split('').map((digit) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 48,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: WaddyColors.primary.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    digit,
                    style: waddyDisplay.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: WaddyColors.primary,
                      height: 1,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFooter(BuildContext context) {
    final String paymentLabel = _paymentLabel();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${'order_id'.tr}',
                style: waddyMicro.copyWith(
                  color: WaddyColors.inkMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '#${order.id}',
                style: waddyTitle.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: WaddyColors.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: WaddyColors.primarySurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: WaddyColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              paymentLabel,
              style: waddyLabel.copyWith(
                color: WaddyColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _paymentLabel() {
    switch (order.paymentMethod) {
      case 'cash_on_delivery':
        return 'cash on delivery';
      case 'wallet':
        return 'wallet';
      case 'partial_payment':
        return 'partial payment';
      case 'offline_payment':
        return 'offline payment';
      default:
        return 'digital payment';
    }
  }

  Widget _buildItemImagesFan(List<OrderDetailsModel> items) {
    final List<OrderDetailsModel> display = items.take(3).toList();
    final double fanWidth = 52 + 20.0 * (display.length - 1).clamp(0, 2);
    final List<double> angles = [-0.22, 0.0, 0.22];

    return SizedBox(
      width: fanWidth,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(display.length, (i) {
          return Positioned(
            left: i * 20.0,
            top: 4,
            child: Transform.rotate(
              angle: angles[i.clamp(0, 2)],
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(10),
                  child: CustomImage(
                    image: display[i].imageFullUrl ?? '',
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

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE4ECEA)
      ..strokeWidth = 1;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
