import 'package:waddy_app/features/xp/domain/models/xp_json.dart';

class XpLeaderboardModel {
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUser;
  final int totalParticipants;

  XpLeaderboardModel({
    required this.entries,
    this.currentUser,
    this.totalParticipants = 0,
  });

  factory XpLeaderboardModel.fromJson(Map<String, dynamic> json) {
    // Current user: nested object first, then flat fields.
    LeaderboardEntry? currentUser;
    final nested = xpMap(json['current_user']);
    if (nested != null) {
      currentUser = LeaderboardEntry.fromJson(nested);
    } else if (json['my_rank'] != null || json['my_xp'] != null) {
      currentUser = LeaderboardEntry(
        userId: xpInt(json['my_id']),
        name: xpStr(json['my_name']) ?? 'You',
        image: xpStr(json['my_image']),
        rank: xpInt(json['my_rank']),
        totalXp: xpInt(json['my_xp']),
        level: xpInt(json['my_level'], 1),
        isMe: true,
        delta: xpInt(json['my_delta']),
        movement: xpStr(json['my_movement']) ?? 'none',
      );
    }

    return XpLeaderboardModel(
      entries:
          xpMapList(
            json['leaderboard'],
          ).map(LeaderboardEntry.fromJson).toList(),
      currentUser: currentUser,
      totalParticipants: xpInt(json['total_participants']),
    );
  }
}

class LeaderboardEntry {
  final int userId;
  final String name;
  final String? image;
  final int rank;
  final int totalXp;
  final int level;
  final String? levelName;
  final String? levelBadge;

  /// True when this row is the requesting user (server sets `is_me`), so the
  /// UI can highlight their own position within the top list.
  final bool isMe;

  /// Real rank movement since the user last viewed this board (server-computed
  /// from a per-period snapshot). Positive [delta] = climbed. [movement] is one
  /// of `up` / `down` / `held` / `new` / `none`, driving the ▲/▼/HELD column.
  final int delta;
  final String movement;

  LeaderboardEntry({
    required this.userId,
    required this.name,
    this.image,
    required this.rank,
    required this.totalXp,
    required this.level,
    this.levelName,
    this.levelBadge,
    this.isMe = false,
    this.delta = 0,
    this.movement = 'none',
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: xpInt(json['user_id'] ?? json['id']),
      name: xpStr(json['name']) ?? xpStr(json['f_name']) ?? 'User',
      image: xpStr(json['image']),
      rank: xpInt(json['rank']),
      totalXp: xpInt(json['total_xp'] ?? json['xp']),
      level: xpInt(json['level'] ?? json['current_level'], 1),
      levelName: xpStr(json['level_name']),
      levelBadge: xpStr(json['level_badge']),
      isMe: xpBool(json['is_me']),
      delta: xpInt(json['delta']),
      movement: xpStr(json['movement']) ?? 'none',
    );
  }

  String get rankDisplay {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }
}
