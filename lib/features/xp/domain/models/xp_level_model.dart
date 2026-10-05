import 'package:waddy_app/features/xp/domain/models/reward_state.dart';
import 'package:waddy_app/features/xp/domain/models/xp_json.dart';
import 'package:waddy_app/features/xp/domain/models/prize_kind.dart';

class XpLevelModel {
  final int currentLevel;
  final String levelName;
  final String? levelBadge;
  final int currentXp;
  final int xpForNextLevel;
  final int xpToNextLevel;
  final double progressPercentage;
  final bool isMaxLevel;
  final NextLevel? nextLevel;
  final List<Level> allLevels;

  /// Real identity for the home hero: the user's global XP rank and their
  /// neighbourhood (zone) name — the "RANK #128 · MAADI" line. Null when the
  /// server didn't supply them (older backend / no zone set).
  final int? rank;
  final String? zoneName;

  /// Most recent positive XP award and how long ago it landed, so the
  /// "+N XP JUST EARNED" toast only shows for a genuinely recent earn.
  final int? recentEarnedXp;
  final int? recentEarnedSecondsAgo;

  XpLevelModel({
    required this.currentLevel,
    required this.levelName,
    this.levelBadge,
    required this.currentXp,
    required this.xpForNextLevel,
    required this.xpToNextLevel,
    required this.progressPercentage,
    this.isMaxLevel = false,
    this.nextLevel,
    this.allLevels = const [],
    this.rank,
    this.zoneName,
    this.recentEarnedXp,
    this.recentEarnedSecondsAgo,
  });

  factory XpLevelModel.fromJson(Map<String, dynamic> json) {
    final recent = xpMap(json['recent_earned']);
    final next = xpMap(json['next_level']);
    return XpLevelModel(
      currentLevel: xpInt(json['current_level'], 1),
      levelName: xpStr(json['level_name']) ?? 'Newbie',
      levelBadge: xpStr(json['level_badge']),
      currentXp: xpInt(json['current_xp'] ?? json['total_xp']),
      xpForNextLevel: xpInt(
        json['xp_for_next_level'] ?? json['xp_to_next_level'],
        100,
      ),
      xpToNextLevel: xpInt(json['xp_to_next_level'], 100),
      progressPercentage:
          (xpDoubleOrNull(json['progress_percentage']) ?? 0)
              .clamp(0, 100)
              .toDouble(),
      isMaxLevel: xpBool(json['is_max_level']),
      nextLevel: next != null ? NextLevel.fromJson(next) : null,
      allLevels: xpMapList(json['all_levels']).map(Level.fromJson).toList(),
      rank: xpIntOrNull(json['rank']),
      zoneName: xpStr(json['zone_name']),
      recentEarnedXp: xpIntOrNull(recent?['xp']),
      recentEarnedSecondsAgo: xpIntOrNull(recent?['seconds_ago']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_level': currentLevel,
      'level_name': levelName,
      'level_badge': levelBadge,
      'current_xp': currentXp,
      'xp_for_next_level': xpForNextLevel,
      'xp_to_next_level': xpToNextLevel,
      'progress_percentage': progressPercentage,
      'is_max_level': isMaxLevel,
      'next_level': nextLevel?.toJson(),
      'all_levels': allLevels.map((level) => level.toJson()).toList(),
    };
  }

  /// Check if user is at max level. Pass maxLevel from config, defaults to 10.
  bool isMaxLevelFor(int maxLevel) => isMaxLevel || currentLevel >= maxLevel;
}

class NextLevel {
  final int levelNumber;
  final String name;
  final int xpRequired;

  NextLevel({
    required this.levelNumber,
    required this.name,
    required this.xpRequired,
  });

  factory NextLevel.fromJson(Map<String, dynamic> json) {
    return NextLevel(
      levelNumber: xpInt(json['level_number']),
      name: xpStr(json['name']) ?? '',
      xpRequired: xpInt(json['xp_required']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level_number': levelNumber,
      'name': name,
      'xp_required': xpRequired,
    };
  }
}

class Level {
  final int level;
  final String name;
  final int xpRequired;
  final String? description;
  final String? badgeImage;
  final bool isUnlocked;
  final bool isCurrent;
  final List<LevelPrize> prizes;

  Level({
    required this.level,
    required this.name,
    required this.xpRequired,
    this.description,
    this.badgeImage,
    this.isUnlocked = false,
    this.isCurrent = false,
    this.prizes = const [],
  });

  factory Level.fromJson(
    Map<String, dynamic> json, {
    int? currentLevel,
    int? currentXp,
  }) {
    final levelNumber = xpInt(json['level_number'] ?? json['level'], 1);
    final xpRequired = xpInt(json['xp_required']);

    // Unlock status: the backend's is_unlocked, else enough XP, else the
    // current-level comparison.
    bool isUnlocked = xpBool(json['is_unlocked']);
    if (!isUnlocked && currentXp != null && currentXp >= xpRequired) {
      isUnlocked = true;
    }
    if (!isUnlocked && currentLevel != null && levelNumber <= currentLevel) {
      isUnlocked = true;
    }

    bool isCurrent = xpBool(json['is_current']);
    if (!isCurrent && currentLevel != null) {
      isCurrent = levelNumber == currentLevel;
    }

    return Level(
      level: levelNumber,
      name: xpStr(json['name']) ?? '',
      xpRequired: xpRequired,
      description: xpStr(json['description']),
      badgeImage: xpStr(json['badge_image']),
      isUnlocked: isUnlocked,
      isCurrent: isCurrent,
      prizes: xpMapList(json['prizes']).map(LevelPrize.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'name': name,
      'xp_required': xpRequired,
      'description': description,
      'badge_image': badgeImage,
      'is_unlocked': isUnlocked,
      'is_current': isCurrent,
      'prizes': prizes.map((prize) => prize.toJson()).toList(),
    };
  }
}

class LevelPrize {
  final int id; // LevelPrize definition ID
  final int? instanceId; // UserLevelPrize ID - USE THIS FOR CLAIMING!
  final String type; // badge, free_delivery, discount, wallet_credit
  final String title;
  final String? description;
  final double? value;
  final String? icon;
  final bool isClaimed;
  final bool isUnlocked;
  final String? status;

  LevelPrize({
    required this.id,
    this.instanceId,
    required this.type,
    required this.title,
    this.description,
    this.value,
    this.icon,
    this.isClaimed = false,
    this.isUnlocked = false,
    this.status,
  });

  /// Get the ID to use for claiming (instanceId if available, otherwise id)
  int get claimId => instanceId ?? id;

  PrizeKind get kind => PrizeKind.parse(type);

  /// The user-prize status, or one rebuilt from the flags for a payload that
  /// predates `status`. Null means not unlocked yet.
  String? get effectiveStatus =>
      status ??
      (isClaimed ? 'claimed' : (isUnlocked ? 'unlocked' : null));

  /// See [RewardState.of]. The level payload carries no expiry, so an expired
  /// prize is known only once the server flips its status.
  RewardState get rewardState =>
      RewardState.of(type: type, status: effectiveStatus);

  factory LevelPrize.fromJson(Map<String, dynamic> json) {
    return LevelPrize(
      id: xpInt(json['id']),
      instanceId: xpIntOrNull(
        json['instance_id'],
      ), // UserLevelPrize ID for claiming!
      // `xp/level-details` sends `prize_type`. Reading only `type` made every
      // level prize a badge (X-14).
      type: xpStr(json['type']) ?? xpStr(json['prize_type']) ?? 'badge',
      title: xpStr(json['title']) ?? '',
      description: xpStr(json['description']),
      value: xpDoubleOrNull(json['value']),
      icon: xpStr(json['icon']),
      isClaimed: xpBool(json['is_claimed']),
      isUnlocked: xpBool(json['is_unlocked']),
      status: xpStr(json['status']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'instance_id': instanceId,
      'type': type,
      'title': title,
      'description': description,
      'value': value,
      'icon': icon,
      'is_claimed': isClaimed,
      'is_unlocked': isUnlocked,
      'status': status,
    };
  }
}

class LevelsListModel {
  final List<Level> levels;
  final int currentLevel;
  final int currentXp;
  final int? xpForNextLevel;
  final int xpToNextLevel;
  final double progressPercentage;

  LevelsListModel({
    required this.levels,
    required this.currentLevel,
    this.currentXp = 0,
    this.xpForNextLevel,
    this.xpToNextLevel = 0,
    this.progressPercentage = 0.0,
  });

  factory LevelsListModel.fromJson(Map<String, dynamic> json) {
    final backendCurrentLevel = xpInt(json['current_level'], 1);
    final currentXp = xpInt(json['current_xp']);
    final levelsList = xpMapList(json['levels']);

    // The server's level is the truth (X-37). This used to re-derive one from
    // the `xp_required` thresholds and keep the higher, so whenever the server
    // lagged (a pending level-up, a refund, an admin threshold edit) the same
    // payload held two different current levels.
    final effectiveCurrentLevel = backendCurrentLevel;

    return LevelsListModel(
      levels:
          levelsList
              .map(
                // No `currentXp`: unlocking by threshold was the same
                // second guess.
                (level) =>
                    Level.fromJson(level, currentLevel: effectiveCurrentLevel),
              )
              .toList(),
      currentLevel: effectiveCurrentLevel,
      currentXp: currentXp,
      xpForNextLevel: xpIntOrNull(json['xp_for_next_level']),
      xpToNextLevel: xpInt(json['xp_to_next_level']),
      progressPercentage:
          (xpDoubleOrNull(json['progress_percentage']) ?? 0)
              .clamp(0, 100)
              .toDouble(),
    );
  }
}
