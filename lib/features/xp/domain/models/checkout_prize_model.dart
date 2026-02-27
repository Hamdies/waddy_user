/// Model for prizes available at checkout
class CheckoutPrize {
  final int id;
  final String title;
  final String type; // free_delivery, discount, etc.
  final double? value;
  final double? minOrderAmount;
  final DateTime? expiresAt;
  final String? description;

  CheckoutPrize({
    required this.id,
    required this.title,
    required this.type,
    this.value,
    this.minOrderAmount,
    this.expiresAt,
    this.description,
  });

  factory CheckoutPrize.fromJson(Map<String, dynamic> json) {
    return CheckoutPrize(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      type: json['type'] ?? json['prize_type'] ?? 'free_delivery',
      value: json['value']?.toDouble(),
      minOrderAmount: json['min_order_amount']?.toDouble(),
      expiresAt:
          json['expires_at'] != null
              ? DateTime.parse(json['expires_at'])
              : null,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'value': value,
      'min_order_amount': minOrderAmount,
      'expires_at': expiresAt?.toIso8601String(),
      'description': description,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isFreeDelivery => type == 'free_delivery';
}
