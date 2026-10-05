import 'package:waddy_app/features/xp/domain/models/xp_json.dart';

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
    final last = xpDate(json['last_activity_date']);
    final stored = xpInt(json['current_streak']);
    return UserStreakModel(
      currentStreak: _effectiveStreak(stored, last),
      longestStreak: xpInt(json['longest_streak']),
      streakBonusXp: xpInt(json['streak_bonus_xp']),
      lastActivityDate: last,
    );
  }

  /// The stored streak only resets on the user's *next* order, so a streak
  /// broken days ago still arrives as its old length (X-17). It is alive only
  /// if the last activity was today or yesterday; otherwise it is 0.
  static int _effectiveStreak(int stored, DateTime? last) {
    if (stored <= 0 || last == null) return stored;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(last.year, last.month, last.day);
    return today.difference(lastDay).inDays > 1 ? 0 : stored;
  }

  bool get isActiveToday {
    if (lastActivityDate == null) return false;
    final now = DateTime.now();
    return lastActivityDate!.year == now.year &&
        lastActivityDate!.month == now.month &&
        lastActivityDate!.day == now.day;
  }
}
