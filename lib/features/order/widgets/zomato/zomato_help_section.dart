import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/util/styles.dart';

const Color _primary = Color(0xFF134E4A);
const Color _accent = Color(0xFF1EF2A0);

class ZomatoHelpSection extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onHelp;
  final VoidCallback onCancel;

  const ZomatoHelpSection({
    super.key,
    required this.order,
    required this.onHelp,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
    final bool canCancel = status == OrderStatus.pending;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Cancel Order button (red) — only shown when cancellable
          if (canCancel) ...[
            Expanded(
              child: _ActionButton(
                label: 'cancel_order'.tr,
                icon: Icons.cancel_outlined,
                onTap: onCancel,
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade600,
                borderColor: Colors.red.shade200,
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Contact Support button
          Expanded(
            child: _ActionButton(
              label: 'contact_support'.tr,
              icon: Icons.support_agent_rounded,
              onTap: onHelp,
              backgroundColor: _accent.withValues(alpha: 0.10),
              foregroundColor: _primary,
              borderColor: _accent.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foregroundColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: robotoMedium.copyWith(
                    fontSize: 13,
                    color: foregroundColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
