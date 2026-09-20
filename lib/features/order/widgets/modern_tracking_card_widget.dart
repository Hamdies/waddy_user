import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Modern tracking card with glassmorphism design and ETA display
class ModernTrackingCardWidget extends StatelessWidget {
  final String? orderStatus;
  final String? subStatus;
  final String? eta;
  final bool takeAway;
  final String? deliveryManName;
  final String? deliveryManPhone;

  const ModernTrackingCardWidget({
    super.key,
    this.orderStatus,
    this.subStatus,
    this.eta,
    this.takeAway = false,
    this.deliveryManName,
    this.deliveryManPhone,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo();
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDarkMode
                  ? [
                    Colors.grey.shade900.withOpacity(0.9),
                    Colors.grey.shade800.withOpacity(0.8),
                  ]
                  : [
                    Colors.white.withOpacity(0.95),
                    Colors.white.withOpacity(0.85),
                  ],
        ),
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status
          _buildHeader(context, statusInfo),

          // Progress bar
          _buildProgressBar(context, statusInfo.progress),

          // Status details
          _buildStatusDetails(context, statusInfo),

          // ETA section (only when driver assigned)
          if (eta != null || statusInfo.showETA) _buildETASection(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, _StatusInfo info) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      child: Row(
        children: [
          // Animated status icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [info.color, info.color.withOpacity(0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: info.color.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(info.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),

          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),

          // Time indicator
          if (info.timeText != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeMedium,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: info.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(
                  Dimensions.radiusExtraLarge,
                ),
              ),
              child: Text(
                info.timeText!,
                style: TextStyle(
                  color: info.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, double progress) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      height: 6,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            width: MediaQuery.of(context).size.width * progress * 0.85,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDetails(BuildContext context, _StatusInfo info) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepIndicator(
            context,
            'Order\nPlaced',
            info.step >= 1,
            info.step == 1,
          ),
          _buildStepDivider(context, info.step >= 2),
          _buildStepIndicator(
            context,
            'Confirmed',
            info.step >= 2,
            info.step == 2,
          ),
          _buildStepDivider(context, info.step >= 3),
          _buildStepIndicator(
            context,
            'Preparing',
            info.step >= 3,
            info.step == 3,
          ),
          _buildStepDivider(context, info.step >= 4),
          _buildStepIndicator(
            context,
            takeAway ? 'Ready' : 'On Way',
            info.step >= 4,
            info.step == 4,
          ),
          _buildStepDivider(context, info.step >= 5),
          _buildStepIndicator(
            context,
            'Delivered',
            info.step >= 5,
            info.step == 5,
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(
    BuildContext context,
    String label,
    bool isCompleted,
    bool isActive,
  ) {
    final color =
        isCompleted
            ? Theme.of(context).primaryColor
            : Theme.of(context).disabledColor;

    return Column(
      children: [
        Container(
          width: isActive ? 28 : 22,
          height: isActive ? 28 : 22,
          decoration: BoxDecoration(
            color: isCompleted ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
            boxShadow:
                isActive
                    ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)]
                    : null,
          ),
          child:
              isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isCompleted ? color : Theme.of(context).hintColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(BuildContext context, bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeLarge),
        color:
            isCompleted
                ? Theme.of(context).primaryColor
                : Theme.of(context).dividerColor,
      ),
    );
  }

  Widget _buildETASection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            color: Theme.of(context).primaryColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Arrival',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
              Text(
                eta ?? 'Calculating...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeSmall,
              vertical: Dimensions.paddingSizeExtraSmall,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo() {
    switch (orderStatus) {
      case 'pending':
        return _StatusInfo(
          title: 'Order Placed',
          subtitle: 'Waiting for restaurant to confirm',
          icon: Icons.receipt_long_rounded,
          color: Colors.orange,
          step: 1,
          progress: 0.2,
          timeText: eta ?? 'Pending',
          showETA: eta != null,
        );
      case 'accepted':
      case 'confirmed':
        return _StatusInfo(
          title: 'Order Confirmed',
          subtitle: 'Restaurant is preparing your order',
          icon: Icons.check_circle_rounded,
          color: Colors.blue,
          step: 2,
          progress: 0.35,
          timeText: eta ?? 'Confirmed',
          showETA: eta != null,
        );
      case 'processing':
        String subtitle = 'Your order is being prepared';
        if (subStatus == 'packaging') {
          subtitle = 'Packaging your order';
        } else if (subStatus == 'ready') {
          subtitle = 'Order ready for pickup';
        }
        return _StatusInfo(
          title: 'Preparing Order',
          subtitle: subtitle,
          icon: Icons.restaurant_rounded,
          color: Colors.purple,
          step: 3,
          progress: 0.5,
          timeText: eta ?? 'Cooking',
          showETA: eta != null,
        );
      case 'handover':
        return _StatusInfo(
          title: takeAway ? 'Ready for Pickup' : 'Ready for Delivery',
          subtitle: takeAway ? 'Your order is waiting' : 'Waiting for driver',
          icon: Icons.inventory_2_rounded,
          color: Colors.teal,
          step: 4,
          progress: 0.65,
          timeText: eta ?? 'Ready',
          showETA: eta != null,
        );
      case 'picked_up':
        String subtitle = 'Driver is on the way';
        if (subStatus == 'nearby') {
          subtitle = 'Driver is nearby!';
        } else if (subStatus == 'arrived') {
          subtitle = 'Driver has arrived!';
        }
        return _StatusInfo(
          title: 'On The Way',
          subtitle: subtitle,
          icon: Icons.delivery_dining_rounded,
          color: Theme.of(Get.context!).primaryColor,
          step: 4,
          progress: 0.8,
          timeText: eta,
          showETA: true,
        );
      case 'delivered':
        return _StatusInfo(
          title: 'Delivered!',
          subtitle: 'Enjoy your meal!',
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          step: 5,
          progress: 1.0,
          timeText: 'Done',
          showETA: false,
        );
      default:
        return _StatusInfo(
          title: 'Processing',
          subtitle: 'Please wait...',
          icon: Icons.hourglass_empty_rounded,
          color: Colors.grey,
          step: 0,
          progress: 0.1,
          showETA: false,
        );
    }
  }
}

class _StatusInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int step;
  final double progress;
  final String? timeText;
  final bool showETA;

  _StatusInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.step,
    required this.progress,
    this.timeText,
    this.showETA = false,
  });
}
