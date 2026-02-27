class XpHistoryModel {
  final List<XpHistoryItem> history;
  final int totalEarned;
  final int totalItems;

  XpHistoryModel({
    required this.history,
    this.totalEarned = 0,
    this.totalItems = 0,
  });

  factory XpHistoryModel.fromJson(Map<String, dynamic> json) {
    return XpHistoryModel(
      history: json['history'] != null
          ? (json['history'] as List)
              .map((item) => XpHistoryItem.fromJson(item))
              .toList()
          : [],
      totalEarned: json['total_earned'] ?? 0,
      totalItems: json['total'] ?? json['total_items'] ?? 0,
    );
  }
}

class XpHistoryItem {
  final int id;
  final String type; // order, challenge, level_up, review, referral
  final int xp;
  final String description;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  XpHistoryItem({
    required this.id,
    required this.type,
    required this.xp,
    required this.description,
    this.createdAt,
    this.metadata,
  });

  factory XpHistoryItem.fromJson(Map<String, dynamic> json) {
    return XpHistoryItem(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'order',
      xp: json['xp'] ?? json['xp_earned'] ?? 0,
      description: json['description'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      metadata: json['metadata'],
    );
  }

  String get icon {
    switch (type) {
      case 'order':
        return '🛒';
      case 'challenge':
        return '🎯';
      case 'level_up':
        return '⬆️';
      case 'review':
        return '⭐';
      case 'referral':
        return '👥';
      default:
        return '✨';
    }
  }

  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
