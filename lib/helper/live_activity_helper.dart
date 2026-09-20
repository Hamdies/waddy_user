class LiveActivityData {
  final String title;
  final String subtitle;
  final double progress;
  final String? etaText;
  final int step;

  LiveActivityData({
    required this.title,
    required this.subtitle,
    required this.progress,
    this.etaText,
    required this.step,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'subtitle': subtitle,
    'progress': progress,
    'etaText': etaText,
    'step': step,
  };
}

class LiveActivityHelper {
  static LiveActivityData getActivityData({
    required String status,
    String? subStatus,
    String? eta,
    bool takeAway = false,
  }) {
    switch (status) {
      case 'pending':
        return LiveActivityData(
          title: 'Order Placed',
          subtitle: 'Waiting for restaurant to confirm',
          progress: 0.2,
          etaText: eta,
          step: 1,
        );
      case 'accepted':
      case 'confirmed':
        return LiveActivityData(
          title: 'Order Confirmed',
          subtitle: 'Restaurant is preparing your order',
          progress: 0.35,
          etaText: eta,
          step: 2,
        );
      case 'processing':
        String subtitle = 'Your order is being prepared';
        if (subStatus == 'packaging') {
          subtitle = 'Packaging your order';
        } else if (subStatus == 'ready') {
          subtitle = 'Order ready for pickup';
        }
        return LiveActivityData(
          title: 'Preparing Order',
          subtitle: subtitle,
          progress: 0.5,
          etaText: eta,
          step: 3,
        );
      case 'handover':
        return LiveActivityData(
          title: takeAway ? 'Ready for Pickup' : 'Ready for Delivery',
          subtitle: takeAway ? 'Your order is waiting' : 'Waiting for driver',
          progress: 0.65,
          etaText: eta,
          step: 4,
        );
      case 'picked_up':
        String subtitle = 'Driver is on the way';
        if (subStatus == 'nearby') {
          subtitle = 'Driver is nearby!';
        } else if (subStatus == 'arrived') {
          subtitle = 'Driver has arrived!';
        }
        return LiveActivityData(
          title: 'On The Way',
          subtitle: subtitle,
          progress: 0.8,
          etaText: eta,
          step: 4,
        );
      case 'delivered':
        return LiveActivityData(
          title: 'Delivered!',
          subtitle: 'Enjoy your meal!',
          progress: 1.0,
          etaText: null,
          step: 5,
        );
      default:
        return LiveActivityData(
          title: 'Processing',
          subtitle: 'Please wait...',
          progress: 0.1,
          step: 0,
        );
    }
  }

  static bool isTerminalStatus(String status) {
    return [
      'delivered',
      'failed',
      'canceled',
      'refund_requested',
      'refunded',
    ].contains(status);
  }
}
