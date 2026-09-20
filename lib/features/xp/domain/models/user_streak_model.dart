class UserStreakModel {
  final int currentStreak;
  final int longestStreak;
  final int streakBonusXp;
  final DateTime? lastActivityDate;

  UserStreakModel({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.streakBonusXp = 0,
    this.lastActivityDate,
  });

  factory UserStreakModel.fromJson(Map<String, dynamic> json) {
    return UserStreakModel(
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      streakBonusXp: json['streak_bonus_xp'] ?? 0,
      lastActivityDate:
          json['last_activity_date'] != null
              ? DateTime.tryParse(json['last_activity_date'].toString())
              : null,
    );
  }

  bool get isActiveToday {
    if (lastActivityDate == null) return false;
    final now = DateTime.now();
    return lastActivityDate!.year == now.year &&
        lastActivityDate!.month == now.month &&
        lastActivityDate!.day == now.day;
  }
}
