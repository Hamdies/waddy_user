enum OrderStatus {
  pending,
  accepted,
  confirmed,
  processing,
  handover,
  pickedUp,
  delivered,
  failed,
  canceled,
  refundRequested,
  refunded,
  refundRequestCanceled;

  static OrderStatus? fromString(String? status) {
    if (status == null) return null;
    switch (status) {
      case 'pending':
        return OrderStatus.pending;
      case 'accepted':
        return OrderStatus.accepted;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'processing':
        return OrderStatus.processing;
      case 'handover':
        return OrderStatus.handover;
      case 'picked_up':
        return OrderStatus.pickedUp;
      case 'delivered':
        return OrderStatus.delivered;
      case 'failed':
        return OrderStatus.failed;
      case 'canceled':
        return OrderStatus.canceled;
      case 'refund_requested':
        return OrderStatus.refundRequested;
      case 'refunded':
        return OrderStatus.refunded;
      case 'refund_request_canceled':
        return OrderStatus.refundRequestCanceled;
      default:
        return null;
    }
  }

  String get value {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.accepted:
        return 'accepted';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.processing:
        return 'processing';
      case OrderStatus.handover:
        return 'handover';
      case OrderStatus.pickedUp:
        return 'picked_up';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.failed:
        return 'failed';
      case OrderStatus.canceled:
        return 'canceled';
      case OrderStatus.refundRequested:
        return 'refund_requested';
      case OrderStatus.refunded:
        return 'refunded';
      case OrderStatus.refundRequestCanceled:
        return 'refund_request_canceled';
    }
  }

  bool get isTerminal =>
      this == OrderStatus.delivered ||
      this == OrderStatus.failed ||
      this == OrderStatus.canceled ||
      this == OrderStatus.refundRequested ||
      this == OrderStatus.refunded ||
      this == OrderStatus.refundRequestCanceled;

  bool get isOngoing => !isTerminal;

  bool get isActive =>
      this == OrderStatus.accepted ||
      this == OrderStatus.confirmed ||
      this == OrderStatus.processing ||
      this == OrderStatus.handover ||
      this == OrderStatus.pickedUp;

  /// Statuses where the lucky spin waiting layout should show
  bool get isWaitingStatus =>
      this == OrderStatus.pending ||
      this == OrderStatus.accepted ||
      this == OrderStatus.confirmed ||
      this == OrderStatus.processing ||
      this == OrderStatus.handover;

  /// Statuses where delivery man assignment is considered confirmed
  bool get isDeliveryAssigned =>
      this == OrderStatus.handover ||
      this == OrderStatus.pickedUp ||
      this == OrderStatus.delivered;

  /// Statuses where tracking button should show
  bool get isTrackable =>
      this == OrderStatus.pending ||
      this == OrderStatus.accepted ||
      this == OrderStatus.confirmed ||
      this == OrderStatus.processing ||
      this == OrderStatus.handover ||
      this == OrderStatus.pickedUp;
}
