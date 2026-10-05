import 'package:waddy_app/features/xp/domain/models/xp_json.dart';

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
    // API format: { "challenges": { "daily": {...}, "weekly": {...} } }.
    // PHP serializes an empty challenges array as [] rather than {}, which is
    // why this reads through xpMap instead of indexing directly.
    final challenges = xpMap(json['challenges']);

    List<Challenge> parse(dynamic data) {
      if (data is List) return xpMapList(data).map(Challenge.fromJson).toList();
      final one = xpMap(data);
      return one == null ? const [] : [Challenge.fromJson(one)];
    }

    // The server sends no reset keys (X-29); each challenge's own
    // `expires_at` is its real deadline. These stay for older payloads only.
    return ChallengeModel(
      dailyChallenges: parse(challenges?['daily']),
      weeklyChallenges: parse(challenges?['weekly']),
      dailyResetTime: xpDate(json['daily_reset_time'] ?? json['daily_reset']),
      weeklyResetTime: xpDate(
        json['weekly_reset_time'] ?? json['weekly_reset'],
      ),
    );
  }
}

class Challenge {
  final int id; // User-assignment ID (use this for claiming)
  final int? challengeId; // Template challenge ID
  final String type; // daily, weekly
  final String
  challengeType; // complete_order, min_order_amount, multiple_orders, new_store
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
    final status = xpStr(json['status']) ?? 'active';
    final challengeType = xpStr(json['challenge_type']) ?? 'complete_order';

    // Progress is a per-type object; fall back to flat fields.
    int currentProgress;
    int targetProgress;
    final progress = xpMap(json['progress']);
    if (progress != null) {
      switch (challengeType) {
        case 'min_order_amount':
          currentProgress = xpInt(progress['amount_spent']);
          targetProgress = xpInt(progress['target'], 1);
          break;
        case 'multiple_orders':
          currentProgress = xpInt(progress['orders_completed']);
          targetProgress = xpInt(progress['target'], 1);
          break;
        case 'complete_order':
        case 'new_store':
          currentProgress = xpBool(progress['completed']) ? 1 : 0;
          targetProgress = 1;
          break;
        default:
          currentProgress = xpInt(progress['current']);
          targetProgress = xpInt(progress['target'], 1);
      }
    } else {
      currentProgress = xpInt(json['current_progress']);
      targetProgress = xpInt(json['target_progress'], 1);
    }

    return Challenge(
      id: xpInt(json['id']),
      challengeId: xpIntOrNull(json['challenge_id']),
      type: xpStr(json['type']) ?? 'daily',
      challengeType: challengeType,
      title: xpStr(json['title']) ?? '',
      description: xpStr(json['description']) ?? '',
      xpReward: xpInt(json['xp_reward']),
      status: status,
      currentProgress: currentProgress,
      targetProgress: targetProgress,
      conditions: xpMap(json['conditions']),
      startedAt: xpDate(json['started_at']),
      expiresAt: xpDate(json['expires_at']),
      completedAt: xpDate(json['completed_at']),
      icon: xpStr(json['icon']),
      actionType: xpStr(json['action_type']) ?? challengeType,
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

  /// This challenge after a successful claim — full progress, `claimed`.
  Challenge asClaimed() => Challenge(
    id: id,
    challengeId: challengeId,
    type: type,
    challengeType: challengeType,
    title: title,
    description: description,
    xpReward: xpReward,
    status: 'claimed',
    currentProgress: targetProgress,
    targetProgress: targetProgress,
    conditions: conditions,
    startedAt: startedAt,
    expiresAt: expiresAt,
    completedAt: completedAt ?? DateTime.now(),
    icon: icon,
    actionType: actionType,
  );

  double get progressPercentage {
    if (targetProgress == 0) return 0;
    return (currentProgress / targetProgress).clamp(0.0, 1.0);
  }

  bool get isCompleted => status == 'completed' || status == 'claimed';
  bool get isClaimed => status == 'claimed';

  /// Past its deadline. The server only flips `status` to expired hourly
  /// (X-18), so an "active" row can already be dead.
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isActive => status == 'active' && !isExpired;

  /// Time left before this challenge expires; null when there is no deadline
  /// or it has passed. This is the real countdown (X-29).
  Duration? get timeLeft {
    final t = expiresAt;
    if (t == null) return null;
    final left = t.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  bool get isBinaryChallenge =>
      challengeType == 'complete_order' || challengeType == 'new_store';
  bool get canClaim => status == 'completed';
}
