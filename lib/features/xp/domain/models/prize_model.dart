class PrizeModel {
  final List<Prize> prizes;
  final int totalUnlocked;
  final int totalClaimed;

  PrizeModel({
    this.prizes = const [],
    this.totalUnlocked = 0,
    this.totalClaimed = 0,
  });

  factory PrizeModel.fromJson(Map<String, dynamic> json) {
    return PrizeModel(
      prizes:
          json['prizes'] != null
              ? (json['prizes'] as List).map((p) => Prize.fromJson(p)).toList()
              : [],
      totalUnlocked: json['total_unlocked'] ?? 0,
      totalClaimed: json['total_claimed'] ?? 0,
    );
  }

  List<Prize> get claimablePrizes => prizes.where((p) => p.canClaim).toList();

  List<Prize> get claimedPrizes => prizes.where((p) => p.isClaimed).toList();

  List<Prize> get expiredPrizes => prizes.where((p) => p.isExpired).toList();
}

class Prize {
  final int id;
  final int level;
  final String type; // badge, free_delivery, discount, wallet_credit
  final String title;
  final String? description;
  final double? value;
  final String? couponCode;
  final String status; // unlocked, claimed, used, locked
  final bool isClaimed;
  final DateTime? claimedAt;
  final DateTime? expiresAt;
  final String? icon;

  Prize({
    required this.id,
    required this.level,
    required this.type,
    required this.title,
    this.description,
    this.value,
    this.couponCode,
    this.status = 'locked',
    this.isClaimed = false,
    this.claimedAt,
    this.expiresAt,
    this.icon,
  });

  factory Prize.fromJson(Map<String, dynamic> json) {
    final status = json['status'] ?? 'locked';
    return Prize(
      id: json['id'] ?? 0,
      level: json['level'] ?? 1,
      type: json['type'] ?? json['prize_type'] ?? 'badge',
      title: json['title'] ?? '',
      description: json['description'],
      value: json['value']?.toDouble(),
      couponCode: json['coupon_code'],
      status: status,
      isClaimed: json['is_claimed'] ?? status == 'claimed',
      claimedAt:
          json['claimed_at'] != null
              ? DateTime.parse(json['claimed_at'])
              : null,
      expiresAt:
          json['expires_at'] != null
              ? DateTime.parse(json['expires_at'])
              : null,
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level': level,
      'type': type,
      'title': title,
      'description': description,
      'value': value,
      'coupon_code': couponCode,
      'status': status,
      'is_claimed': isClaimed,
      'claimed_at': claimedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'icon': icon,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Prize can be claimed if status is "unlocked" and not expired
  bool get canClaim => status == 'unlocked' && !isExpired;

  /// Check if status is unlocked (but not yet claimed)
  bool get isUnlocked => status == 'unlocked';

  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}
