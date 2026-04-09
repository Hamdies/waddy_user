import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/util/styles.dart';

const Color _primary = Color(0xFF134E4A);
const Color _accent = Color(0xFF1EF2A0);

class ZomatoDeliveryDetails extends StatelessWidget {
  final OrderModel order;

  const ZomatoDeliveryDetails({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.deliveryAddress == null) return const SizedBox.shrink();

    final address = order.deliveryAddress!;
    final String contactName = address.contactPersonName ?? '';
    final String contactPhone = address.contactPersonNumber ?? '';
    final String addressType =
        (address.addressType ?? 'home').tr.capitalizeFirst ?? '';
    final String addressText = address.address ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'all_your_delivery_details_in_one_place'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: 13,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('\u{1F447}', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Phone row
          if (contactName.isNotEmpty || contactPhone.isNotEmpty)
            _buildDetailRow(
              context: context,
              icon: Icons.phone_outlined,
              title:
                  '$contactName${contactPhone.isNotEmpty ? ', $contactPhone' : ''}',
              subtitle: 'delivery_partner_may_call'.tr,
              showEdit: true,
            ),

          if (contactName.isNotEmpty || contactPhone.isNotEmpty)
            _buildDashedDivider(),

          // Address row
          _buildDetailRow(
            context: context,
            icon: Icons.location_on_outlined,
            title: '${'delivery_at'.tr} $addressType',
            subtitle: addressText,
            showEdit: true,
          ),

          _buildDashedDivider(),

          // Delivery instructions
          _buildDetailRow(
            context: context,
            icon: Icons.delivery_dining_outlined,
            title: 'add_delivery_instructions'.tr,
            subtitle: order.deliveryInstruction ?? '',
            showArrow: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    bool showEdit = false,
    bool showArrow = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: _primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: robotoMedium.copyWith(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: robotoRegular.copyWith(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (showEdit)
            Text(
              'edit'.tr,
              style: robotoMedium.copyWith(fontSize: 14, color: _primary),
            ),
          if (showArrow)
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Colors.grey.shade400,
            ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashedLinePainter(),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1;
    const dashWidth = 5.0;
    const dashSpace = 3.0;
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
