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
  final int id; // User-assignment ID (use this for claiming)
  final int? challengeId; // Template challenge ID
  final String type; // daily, weekly
  final String challengeType; // complete_order, min_order_amount, multiple_orders, new_store
  final String title;
  final String description;
  final int xpReward;
  final String status; // active, completed, claimed
  final int currentProgress;
  final int targetProgress;
  final Map<String, dynamic>? conditions;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? completedAt;
  final String? icon;
  final String? actionType; // order, review, spend, etc.

  Challenge({
    required this.id,
    this.challengeId,
    required this.type,
    this.challengeType = 'complete_order',
    required this.title,
    required this.description,
    required this.xpReward,
    this.status = 'active',
    this.currentProgress = 0,
    this.targetProgress = 1,
    this.conditions,
    this.startedAt,
    this.expiresAt,
    this.completedAt,
    this.icon,
    this.actionType,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    final status = json['status'] ?? 'active';
    final challengeType = json['challenge_type'] ?? 'complete_order';

    // Parse dynamic progress object based on challenge_type
    int currentProgress = 0;
    int targetProgress = 1;

    if (json['progress'] != null && json['progress'] is Map) {
      final progress = json['progress'] as Map<String, dynamic>;
      switch (challengeType) {
        case 'min_order_amount':
          currentProgress = (progress['amount_spent'] ?? 0).toInt();
          targetProgress = (progress['target'] ?? 1).toInt();
          break;
        case 'multiple_orders':
          currentProgress = (progress['orders_completed'] ?? 0).toInt();
          targetProgress = (progress['target'] ?? 1).toInt();
          break;
        case 'complete_order':
        case 'new_store':
          currentProgress = (progress['completed'] == true) ? 1 : 0;
          targetProgress = 1;
          break;
        default:
          currentProgress = (progress['current'] ?? 0).toInt();
          targetProgress = (progress['target'] ?? 1).toInt();
      }
    } else {
      // Fallback: try flat fields for backwards compatibility
      currentProgress = json['current_progress'] ?? 0;
      targetProgress = json['target_progress'] ?? 1;
    }

    return Challenge(
      id: json['id'] ?? 0,
      challengeId: json['challenge_id'],
      type: json['type'] ?? 'daily',
      challengeType: challengeType,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      xpReward: json['xp_reward'] ?? 0,
      status: status,
      currentProgress: currentProgress,
      targetProgress: targetProgress,
      conditions: json['conditions'] is Map<String, dynamic>
          ? json['conditions']
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
      icon: json['icon'],
      actionType: json['action_type'] ?? json['challenge_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challenge_id': challengeId,
      'type': type,
      'challenge_type': challengeType,
      'title': title,
      'description': description,
      'xp_reward': xpReward,
      'status': status,
      'current_progress': currentProgress,
      'target_progress': targetProgress,
      'conditions': conditions,
      'started_at': startedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'icon': icon,
      'action_type': actionType,
    };
  }

  double get progressPercentage {
    if (targetProgress == 0) return 0;
    return (currentProgress / targetProgress).clamp(0.0, 1.0);
  }

  bool get isCompleted => status == 'completed' || status == 'claimed';
  bool get isClaimed => status == 'claimed';
  bool get isActive => status == 'active';
  bool get isBinaryChallenge =>
      challengeType == 'complete_order' || challengeType == 'new_store';
  bool get canClaim => status == 'completed';
}
