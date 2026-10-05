import 'package:waddy_app/features/xp/domain/models/xp_json.dart';
import 'package:waddy_app/features/xp/domain/models/prize_kind.dart';

/// Model for prizes available at checkout
class CheckoutPrize {
  final int id;
  final String title;
  final String type; // free_delivery, discount, etc.
  final double? value;
  final double? minOrderAmount;
  final DateTime? expiresAt;
  final String? description;
  final String? levelName;

  CheckoutPrize({
    required this.id,
    required this.title,
    required this.type,
    this.value,
    this.minOrderAmount,
    this.expiresAt,
    this.description,
    this.levelName,
  });

  factory CheckoutPrize.fromJson(Map<String, dynamic> json) {
    return CheckoutPrize(
      id: xpInt(json['id']),
      title: xpStr(json['title']) ?? '',
      type: xpStr(json['type']) ?? xpStr(json['prize_type']) ?? 'free_delivery',
      value: xpDoubleOrNull(json['value']),
      minOrderAmount: xpDoubleOrNull(json['min_order_amount']),
      expiresAt: xpDate(json['expires_at']),
      description: xpStr(json['description']),
      levelName: xpStr(json['level_name']),
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
      'level_name': levelName,
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

  PrizeKind get kind => PrizeKind.parse(type);

  bool get isFreeDelivery => kind == PrizeKind.freeDelivery;
}
