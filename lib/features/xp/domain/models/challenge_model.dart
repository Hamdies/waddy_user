class ChallengeModel {
  final List<Challenge> dailyChallenges;
  final List<Challenge> weeklyChallenges;
  final DateTime? dailyResetTime;
  final DateTime? weeklyResetTime;

  ChallengeModel({
    this.dailyChallenges = const [],
    this.weeklyChallenges = const [],
    this.dailyResetTime,
    this.weeklyResetTime,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    List<Challenge> daily = [];
    List<Challenge> weekly = [];

    // Handle new API format: { "challenges": { "daily": {...}, "weekly": {...} }, "has_daily": true }
    if (json['challenges'] != null) {
      final challenges = json['challenges'];

      // Parse daily challenge(s)
      if (challenges['daily'] != null) {
        final dailyData = challenges['daily'];
        if (dailyData is List) {
          daily = dailyData.map((c) => Challenge.fromJson(c)).toList();
        } else if (dailyData is Map<String, dynamic>) {
          daily = [Challenge.fromJson(dailyData)];
        }
      }

      // Parse weekly challenge(s)
      if (challenges['weekly'] != null) {
        final weeklyData = challenges['weekly'];
        if (weeklyData is List) {
          weekly = weeklyData.map((c) => Challenge.fromJson(c)).toList();
        } else if (weeklyData is Map<String, dynamic>) {
          weekly = [Challenge.fromJson(weeklyData)];
        }
      }
    }
    // Handle old API format: { "daily_challenges": [...], "weekly_challenges": [...] }
    else {
      if (json['daily_challenges'] != null) {
        daily =
            (json['daily_challenges'] as List)
                .map((c) => Challenge.fromJson(c))
                .toList();
      }
      if (json['weekly_challenges'] != null) {
        weekly =
            (json['weekly_challenges'] as List)
                .map((c) => Challenge.fromJson(c))
                .toList();
      }
    }

    // Parse reset times
    DateTime? dailyReset;
    DateTime? weeklyReset;

    if (json['daily_reset_time'] != null) {
      dailyReset = DateTime.tryParse(json['daily_reset_time'].toString());
    } else if (json['daily_reset'] != null) {
      dailyReset = DateTime.tryParse(json['daily_reset'].toString());
    }

    if (json['weekly_reset_time'] != null) {
      weeklyReset = DateTime.tryParse(json['weekly_reset_time'].toString());
    } else if (json['weekly_reset'] != null) {
      weeklyReset = DateTime.tryParse(json['weekly_reset'].toString());
    }

    return ChallengeModel(
      dailyChallenges: daily,
      weeklyChallenges: weekly,
      dailyResetTime: dailyReset,
      weeklyResetTime: weeklyReset,
    );
  }
}

class Challenge {
  final int id;
  final String type; // daily, weekly
  final String title;
  final String description;
  final int xpReward;
  final int currentProgress;
  final int targetProgress;
  final bool isCompleted;
  final bool isClaimed;
  final DateTime? expiresAt;
  final String? icon;
  final String? actionType; // order, review, spend, etc.

  Challenge({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.xpReward,
    this.currentProgress = 0,
    this.targetProgress = 1,
    this.isCompleted = false,
    this.isClaimed = false,
    this.expiresAt,
    this.icon,
    this.actionType,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'daily',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      xpReward: json['xp_reward'] ?? 0,
      currentProgress: json['current_progress'] ?? 0,
      targetProgress: json['target_progress'] ?? 1,
      isCompleted: json['is_completed'] ?? false,
      isClaimed: json['is_claimed'] ?? false,
      expiresAt:
          json['expires_at'] != null
              ? DateTime.parse(json['expires_at'])
              : null,
      icon: json['icon'],
      actionType: json['action_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'description': description,
      'xp_reward': xpReward,
      'current_progress': currentProgress,
      'target_progress': targetProgress,
      'is_completed': isCompleted,
      'is_claimed': isClaimed,
      'expires_at': expiresAt?.toIso8601String(),
      'icon': icon,
      'action_type': actionType,
    };
  }

  double get progressPercentage {
    if (targetProgress == 0) return 0;
    return (currentProgress / targetProgress).clamp(0.0, 1.0);
  }

  bool get canClaim => isCompleted && !isClaimed;
}
