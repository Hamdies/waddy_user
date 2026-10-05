import 'package:waddy_app/features/xp/domain/models/reward_state.dart';
import 'package:waddy_app/features/xp/domain/models/xp_json.dart';
import 'package:waddy_app/features/xp/domain/models/prize_kind.dart';

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
    List<Prize> parse(dynamic v) => xpMapList(v).map(Prize.fromJson).toList();

    // Grouped format: usable_prizes, used_prizes, expired_prizes.
    final usable = parse(json['usable_prizes']);
    final used = parse(json['used_prizes']);
    final expired = parse(json['expired_prizes']);
    // Owned but held back right now (a period limit). Without this group the
    // server dropped them entirely (X-32); [RewardState] places them.
    final waiting = parse(json['waiting_prizes']);
    var allPrizes = [...usable, ...waiting, ...used, ...expired];

    // Fallback: flat prizes array.
    if (allPrizes.isEmpty) allPrizes = parse(json['prizes']);

    // `/prizes` sends no totals, so these used to read 0 beside a full list.
    // Derive them when absent.
    return PrizeModel(
      prizes: allPrizes,
      usablePrizes: usable,
      usedPrizes: used,
      expiredPrizesRaw: expired,
      totalUnlocked: xpIntOrNull(json['total_unlocked']) ?? allPrizes.length,
      totalClaimed:
          xpIntOrNull(json['total_claimed']) ??
          allPrizes.where((p) => p.isClaimed || p.isUsed).length,
    );
  }

  /// Rewards the user can act on right now: claim, or spend. Not badges, not
  /// used, not expired. What the XP hero counts and the nav badge points at.
  List<Prize> get livePrizes =>
      _owned.where((p) => p.rewardState.isLive).toList();

  /// Prizes where claiming *does* something (a wallet credit pays out, a
  /// discount mints its coupon). A free delivery is spent at checkout as it
  /// is, so it never waits on a claim (X-26).
  List<Prize> get needsClaimPrizes =>
      _owned.where((p) => p.rewardState == RewardState.claim).toList();

  /// Every owned prize. `fromJson` fills [prizes] with all groups; a model
  /// built directly may carry only [usablePrizes].
  List<Prize> get _owned => prizes.isNotEmpty ? prizes : usablePrizes;

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
    final status = xpStr(json['status']) ?? 'locked';
    return Prize(
      id: xpInt(json['id']),
      prizeId: xpIntOrNull(json['prize_id']),
      level: xpInt(json['level'], 1),
      levelName: xpStr(json['level_name']),
      type: xpStr(json['type']) ?? xpStr(json['prize_type']) ?? 'badge',
      title: xpStr(json['title']) ?? '',
      description: xpStr(json['description']),
      value: xpDoubleOrNull(json['value']),
      minOrderAmount: xpDoubleOrNull(json['min_order_amount']),
      usageLimit: xpIntOrNull(json['usage_limit']),
      couponCode: xpStr(json['coupon_code']),
      status: status,
      isClaimed: xpBool(json['is_claimed'], status == 'claimed'),
      isUsable: xpBool(json['is_usable']),
      unlockedAt: xpDate(json['unlocked_at']),
      claimedAt: xpDate(json['claimed_at']),
      expiresAt: xpDate(json['expires_at']),
      usedAt: xpDate(json['used_at']),
      icon: xpStr(json['icon']),
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

  PrizeKind get kind => PrizeKind.parse(type);

  /// See [RewardState.of].
  RewardState get rewardState =>
      RewardState.of(type: type, status: status, expiresAt: expiresAt);

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
