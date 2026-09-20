class PrizeModel {
  final List<Prize> prizes;
  final List<Prize> usablePrizes;
  final List<Prize> usedPrizes;
  final List<Prize> expiredPrizesRaw;
  final int totalUnlocked;
  final int totalClaimed;

  PrizeModel({
    this.prizes = const [],
    this.usablePrizes = const [],
    this.usedPrizes = const [],
    this.expiredPrizesRaw = const [],
    this.totalUnlocked = 0,
    this.totalClaimed = 0,
  });

  factory PrizeModel.fromJson(Map<String, dynamic> json) {
    List<Prize> allPrizes = [];
    List<Prize> usable = [];
    List<Prize> used = [];
    List<Prize> expired = [];

    // Parse grouped format: usable_prizes, used_prizes, expired_prizes
    if (json['usable_prizes'] != null) {
      usable =
          (json['usable_prizes'] as List)
              .map((p) => Prize.fromJson(p))
              .toList();
      allPrizes.addAll(usable);
    }
    if (json['used_prizes'] != null) {
      used =
          (json['used_prizes'] as List).map((p) => Prize.fromJson(p)).toList();
      allPrizes.addAll(used);
    }
    if (json['expired_prizes'] != null) {
      expired =
          (json['expired_prizes'] as List)
              .map((p) => Prize.fromJson(p))
              .toList();
      allPrizes.addAll(expired);
    }

    // Fallback: flat prizes array
    if (allPrizes.isEmpty && json['prizes'] != null) {
      allPrizes =
          (json['prizes'] as List).map((p) => Prize.fromJson(p)).toList();
    }

    return PrizeModel(
      prizes: allPrizes,
      usablePrizes: usable,
      usedPrizes: used,
      expiredPrizesRaw: expired,
      totalUnlocked: json['total_unlocked'] ?? 0,
      totalClaimed: json['total_claimed'] ?? 0,
    );
  }

  List<Prize> get claimablePrizes =>
      usablePrizes.isNotEmpty
          ? usablePrizes.where((p) => p.canClaim).toList()
          : prizes.where((p) => p.canClaim).toList();

  List<Prize> get claimedPrizes =>
      usablePrizes.isNotEmpty
          ? usablePrizes.where((p) => p.isClaimed).toList()
          : prizes.where((p) => p.isClaimed).toList();

  List<Prize> get expiredPrizes =>
      expiredPrizesRaw.isNotEmpty
          ? expiredPrizesRaw
          : prizes.where((p) => p.isExpired).toList();
}

class Prize {
  final int id; // User's prize instance ID
  final int? prizeId; // Prize template ID
  final int level;
  final String? levelName;
  final String
  type; // badge, free_delivery, discount, wallet_credit, free_item, custom
  final String title;
  final String? description;
  final double? value;
  final double? minOrderAmount;
  final int? usageLimit;
  final String? couponCode;
  final String status; // unlocked, claimed, used, expired, null (locked)
  final bool isClaimed;
  final bool isUsable;
  final DateTime? unlockedAt;
  final DateTime? claimedAt;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final String? icon;

  Prize({
    required this.id,
    this.prizeId,
    required this.level,
    this.levelName,
    required this.type,
    required this.title,
    this.description,
    this.value,
    this.minOrderAmount,
    this.usageLimit,
    this.couponCode,
    this.status = 'locked',
    this.isClaimed = false,
    this.isUsable = false,
    this.unlockedAt,
    this.claimedAt,
    this.expiresAt,
    this.usedAt,
    this.icon,
  });

  factory Prize.fromJson(Map<String, dynamic> json) {
    final status = json['status'] ?? 'locked';
    return Prize(
      id: json['id'] ?? 0,
      prizeId: json['prize_id'],
      level: json['level'] ?? 1,
      levelName: json['level_name'],
      type: json['type'] ?? json['prize_type'] ?? 'badge',
      title: json['title'] ?? '',
      description: json['description'],
      value: json['value']?.toDouble(),
      minOrderAmount: json['min_order_amount']?.toDouble(),
      usageLimit: json['usage_limit'],
      couponCode: json['coupon_code'],
      status: status,
      isClaimed: json['is_claimed'] ?? status == 'claimed',
      isUsable: json['is_usable'] ?? false,
      unlockedAt:
          json['unlocked_at'] != null
              ? DateTime.tryParse(json['unlocked_at'].toString())
              : null,
      claimedAt:
          json['claimed_at'] != null
              ? DateTime.tryParse(json['claimed_at'].toString())
              : null,
      expiresAt:
          json['expires_at'] != null
              ? DateTime.tryParse(json['expires_at'].toString())
              : null,
      usedAt:
          json['used_at'] != null
              ? DateTime.tryParse(json['used_at'].toString())
              : null,
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prize_id': prizeId,
      'level': level,
      'level_name': levelName,
      'type': type,
      'title': title,
      'description': description,
      'value': value,
      'min_order_amount': minOrderAmount,
      'usage_limit': usageLimit,
      'coupon_code': couponCode,
      'status': status,
      'is_claimed': isClaimed,
      'is_usable': isUsable,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'claimed_at': claimedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'used_at': usedAt?.toIso8601String(),
      'icon': icon,
    };
  }

  bool get isExpired {
    if (status == 'expired') return true;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Prize can be claimed if status is "unlocked" and not expired
  bool get canClaim => status == 'unlocked' && !isExpired;

  /// Check if status is unlocked (but not yet claimed)
  bool get isUnlocked => status == 'unlocked';

  /// Check if status is used
  bool get isUsed => status == 'used';

  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}
