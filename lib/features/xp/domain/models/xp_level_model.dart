class XpLevelModel {
  final int currentLevel;
  final String levelName;
  final String? levelBadge;
  final int currentXp;
  final int xpForNextLevel;
  final int xpToNextLevel;
  final double progressPercentage;
  final List<Level> allLevels;

  XpLevelModel({
    required this.currentLevel,
    required this.levelName,
    this.levelBadge,
    required this.currentXp,
    required this.xpForNextLevel,
    required this.xpToNextLevel,
    required this.progressPercentage,
    this.allLevels = const [],
  });

  factory XpLevelModel.fromJson(Map<String, dynamic> json) {
    return XpLevelModel(
      currentLevel: json['current_level'] ?? 1,
      levelName: json['level_name'] ?? 'Newbie',
      levelBadge: json['level_badge'],
      currentXp: json['current_xp'] ?? json['total_xp'] ?? 0,
      xpForNextLevel:
          json['xp_for_next_level'] ?? json['xp_to_next_level'] ?? 100,
      xpToNextLevel: json['xp_to_next_level'] ?? 100,
      progressPercentage: (json['progress_percentage'] ?? 0.0).toDouble(),
      allLevels:
          json['all_levels'] != null
              ? (json['all_levels'] as List)
                  .map((level) => Level.fromJson(level))
                  .toList()
              : [],
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
      'all_levels': allLevels.map((level) => level.toJson()).toList(),
    };
  }

  /// Check if user is at max level. Pass maxLevel from config, defaults to 10.
  bool isMaxLevelFor(int maxLevel) => currentLevel >= maxLevel;
  
  /// Legacy getter — use isMaxLevelFor() with config value when possible
  bool get isMaxLevel => currentLevel >= 10;
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

  factory Level.fromJson(Map<String, dynamic> json, {int? currentLevel, int? currentXp}) {
    final levelNumber = json['level_number'] ?? json['level'] ?? 1;
    final xpRequired = json['xp_required'] ?? 0;
    
    // Determine unlock status:
    // 1. First check backend's is_unlocked
    // 2. If not provided, check if user has enough XP
    // 3. Fallback to currentLevel comparison
    bool isUnlocked = json['is_unlocked'] ?? false;
    if (!isUnlocked && currentXp != null && currentXp >= xpRequired) {
      isUnlocked = true;
    }
    if (!isUnlocked && currentLevel != null && levelNumber <= currentLevel) {
      isUnlocked = true;
    }
    
    // Determine if this is the current active level
    bool isCurrent = json['is_current'] ?? false;
    if (!isCurrent && currentLevel != null) {
      isCurrent = levelNumber == currentLevel;
    }
    
    return Level(
      level: levelNumber,
      name: json['name'] ?? '',
      xpRequired: xpRequired,
      description: json['description'],
      badgeImage: json['badge_image'],
      isUnlocked: isUnlocked,
      isCurrent: isCurrent,
      prizes:
          json['prizes'] != null
              ? (json['prizes'] as List)
                  .map((prize) => LevelPrize.fromJson(prize))
                  .toList()
              : [],
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

  factory LevelPrize.fromJson(Map<String, dynamic> json) {
    return LevelPrize(
      id: json['id'] ?? 0,
      instanceId: json['instance_id'], // UserLevelPrize ID for claiming!
      type: json['type'] ?? 'badge',
      title: json['title'] ?? '',
      description: json['description'],
      value: json['value']?.toDouble(),
      icon: json['icon'],
      isClaimed: json['is_claimed'] ?? false,
      isUnlocked: json['is_unlocked'] ?? false,
      status: json['status'],
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
    final backendCurrentLevel = json['current_level'] ?? 1;
    final currentXp = json['current_xp'] ?? 0;
    
    // Parse levels first to calculate the actual current level based on XP
    final levelsList = json['levels'] != null
        ? (json['levels'] as List).map((l) => l as Map<String, dynamic>).toList()
        : <Map<String, dynamic>>[];
    
    // Calculate actual current level based on XP (highest level user qualifies for)
    int calculatedCurrentLevel = backendCurrentLevel;
    for (var levelJson in levelsList) {
      final levelNum = levelJson['level_number'] ?? levelJson['level'] ?? 1;
      final xpRequired = levelJson['xp_required'] ?? 0;
      if (currentXp >= xpRequired && levelNum > calculatedCurrentLevel) {
        calculatedCurrentLevel = levelNum;
      }
    }
    
    // Use the higher of backend's current_level or calculated level
    final effectiveCurrentLevel = calculatedCurrentLevel > backendCurrentLevel 
        ? calculatedCurrentLevel 
        : backendCurrentLevel;
    
    return LevelsListModel(
      levels: levelsList
          .map(
            (level) => Level.fromJson(
              level, 
              currentLevel: effectiveCurrentLevel,
              currentXp: currentXp,
            ),
          )
          .toList(),
      currentLevel: effectiveCurrentLevel,
      currentXp: currentXp,
      xpForNextLevel: json['xp_for_next_level'],
      xpToNextLevel: json['xp_to_next_level'] ?? 0,
      progressPercentage: (json['progress_percentage'] ?? 0.0).toDouble(),
    );
  }
}
