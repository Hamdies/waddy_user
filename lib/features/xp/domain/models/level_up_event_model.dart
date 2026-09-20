/// A single unacknowledged level-up, surfaced by `xp/level-details` under
/// `pending_level_ups`. Drives the "Level Up!" celebration screen and is cleared
/// via `xp/level-ups/acknowledge` once shown.
class LevelUpEvent {
  final int transactionId;
  final int level;
  final String? levelName;
  final String? levelBadge;

  /// Lifetime XP the user held right after crossing into this level.
  final int totalXp;

  /// XP required to reach this level — the "+N XP this level" headline value.
  final int xpGained;

  final String? rewardName;
  final String? rewardType;
  final String? rarity;

  const LevelUpEvent({
    required this.transactionId,
    required this.level,
    this.levelName,
    this.levelBadge,
    this.totalXp = 0,
    this.xpGained = 0,
    this.rewardName,
    this.rewardType,
    this.rarity,
  });

  factory LevelUpEvent.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    String? asStr(dynamic v) => (v == null || '$v'.isEmpty) ? null : '$v';

    return LevelUpEvent(
      transactionId: asInt(json['transaction_id']),
      level: asInt(json['level']),
      levelName: asStr(json['level_name']),
      levelBadge: asStr(json['level_badge']),
      totalXp: asInt(json['total_xp']),
      xpGained: asInt(json['xp_gained']),
      rewardName: asStr(json['reward_name']),
      rewardType: asStr(json['reward_type']),
      rarity: asStr(json['rarity']),
    );
  }
}
