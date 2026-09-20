import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/checkout/widgets/voice_player_widget.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Shows delivery instructions (voice + text) on the order tracking screen
/// Visible when order is pending, confirmed, processing, handover, or picked_up
class DeliveryInstructionTrackingWidget extends StatelessWidget {
  final OrderModel order;

  const DeliveryInstructionTrackingWidget({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final bool hasVoice =
        order.voiceInstructionFullUrl != null &&
        order.voiceInstructionFullUrl!.isNotEmpty;
    final bool hasText =
        order.deliveryInstruction != null &&
        order.deliveryInstruction!.isNotEmpty;

    if (!hasVoice && !hasText) return const SizedBox();

    final List<String> instructions =
        hasText ? order.deliveryInstruction!.split(', ') : [];

    return Container(
      margin: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'delivery_instructions'.tr,
                style: waddyMedium.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                ),
              ),
            ],
          ),

          if (hasVoice) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            VoicePlayerWidget(
              audioUrl: order.voiceInstructionFullUrl!,
              isNetworkSource: true,
            ),
          ],

          if (instructions.isNotEmpty) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  instructions.map((instruction) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeMedium,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusExtraLarge,
                        ),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getInstructionIcon(instruction),
                            size: 14,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              instruction.tr,
                              style: waddyRegular.copyWith(
                                fontSize: Dimensions.fontSizeExtraSmall,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getInstructionIcon(String instruction) {
    final lower = instruction.toLowerCase();
    if (lower.contains('call')) return Icons.phone_disabled_rounded;
    if (lower.contains('bell') || lower.contains('ring')) {
      return Icons.notifications_off_rounded;
    }
    if (lower.contains('door')) return Icons.door_front_door_rounded;
    if (lower.contains('guard') || lower.contains('security')) {
      return Icons.security_rounded;
    }
    if (lower.contains('front')) return Icons.home_rounded;
    if (lower.contains('reception') || lower.contains('desk')) {
      return Icons.desk_rounded;
    }
    return Icons.info_outline_rounded;
  }
}
