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
    // Parse current user: try nested object first, then flat fields
    LeaderboardEntry? currentUser;
    if (json['current_user'] != null) {
      currentUser = LeaderboardEntry.fromJson(json['current_user']);
    } else if (json['my_rank'] != null || json['my_xp'] != null) {
      currentUser = LeaderboardEntry(
        userId: json['my_id'] ?? 0,
        name: json['my_name'] ?? 'You',
        image: json['my_image'],
        rank: json['my_rank'] ?? 0,
        totalXp: json['my_xp'] ?? 0,
        level: json['my_level'] ?? 1,
      );
    }

    return XpLeaderboardModel(
      entries: json['leaderboard'] != null
          ? (json['leaderboard'] as List)
              .map((e) => LeaderboardEntry.fromJson(e))
              .toList()
          : [],
      currentUser: currentUser,
      totalParticipants: json['total_participants'] ?? 0,
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

  LeaderboardEntry({
    required this.userId,
    required this.name,
    this.image,
    required this.rank,
    required this.totalXp,
    required this.level,
    this.levelName,
    this.levelBadge,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] ?? json['id'] ?? 0,
      name: json['name'] ?? json['f_name'] ?? 'User',
      image: json['image'],
      rank: json['rank'] ?? 0,
      totalXp: json['total_xp'] ?? json['xp'] ?? 0,
      level: json['level'] ?? json['current_level'] ?? 1,
      levelName: json['level_name'],
      levelBadge: json['level_badge'],
    );
  }

  String get rankDisplay {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }
}
