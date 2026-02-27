import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/xp/domain/models/prize_model.dart';

class PrizeCardWidget extends StatelessWidget {
  final Prize prize;
  final VoidCallback? onClaim;
  final bool isLoading;

  const PrizeCardWidget({
    super.key,
    required this.prize,
    this.onClaim,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border:
            prize.canClaim
                ? Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                  width: 2,
                )
                : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Prize icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getPrizeColor(prize.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getPrizeIcon(prize.type),
                    color: _getPrizeColor(prize.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prize.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'level'.tr + ' ${prize.level}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (prize.description != null) ...[
              const SizedBox(height: 12),
              Text(
                prize.description!,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (prize.value != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getPrizeColor(prize.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getValueText(prize),
                  style: TextStyle(
                    color: _getPrizeColor(prize.type),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Expiration and action
            Row(
              children: [
                if (prize.expiresAt != null &&
                    !prize.isClaimed &&
                    !prize.isExpired)
                  Expanded(child: _buildExpirationInfo(context)),
                if (prize.expiresAt == null ||
                    prize.isClaimed ||
                    prize.isExpired)
                  const Spacer(),
                _buildActionButton(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpirationInfo(BuildContext context) {
    final timeLeft = prize.timeUntilExpiry;
    if (timeLeft == null) return const SizedBox.shrink();

    final days = timeLeft.inDays;
    final hours = timeLeft.inHours % 24;

    String expiryText;
    Color expiryColor;

    if (days > 7) {
      expiryText = '$days ${'days_left'.tr}';
      expiryColor = Colors.grey.shade600;
    } else if (days > 0) {
      expiryText = '$days ${'days_left'.tr}';
      expiryColor = Colors.orange;
    } else {
      expiryText = '$hours ${'hours_left'.tr}';
      expiryColor = Colors.red;
    }

    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 14, color: expiryColor),
        const SizedBox(width: 4),
        Text(
          expiryText,
          style: TextStyle(
            fontSize: 12,
            color: expiryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (prize.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'expired'.tr,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      );
    }

    if (prize.isClaimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
            const SizedBox(width: 4),
            Text(
              'claimed'.tr,
              style: TextStyle(
                color: Colors.green.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onClaim,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      child:
          isLoading
              ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
              : Text(
                'claim'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
    );
  }

  IconData _getPrizeIcon(String type) {
    switch (type) {
      case 'badge':
        return Icons.military_tech;
      case 'free_delivery':
        return Icons.local_shipping;
      case 'discount':
        return Icons.discount;
      case 'wallet_credit':
        return Icons.account_balance_wallet;
      default:
        return Icons.card_giftcard;
    }
  }

  Color _getPrizeColor(String type) {
    switch (type) {
      case 'badge':
        return Colors.amber;
      case 'free_delivery':
        return Colors.blue;
      case 'discount':
        return Colors.green;
      case 'wallet_credit':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getValueText(Prize prize) {
    switch (prize.type) {
      case 'discount':
        return '${prize.value?.toInt()}% ${'off'.tr}';
      case 'wallet_credit':
        return '+${prize.value?.toInt()} ${'credits'.tr}';
      case 'free_delivery':
        return 'free_delivery'.tr;
      default:
        return prize.value?.toString() ?? '';
    }
  }
}
