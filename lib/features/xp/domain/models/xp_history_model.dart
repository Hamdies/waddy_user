class XpHistoryModel {
  final List<XpHistoryItem> history;
  final int totalEarned;
  final int totalItems;
  final int limit;
  final int offset;

  XpHistoryModel({
    required this.history,
    this.totalEarned = 0,
    this.totalItems = 0,
    this.limit = 20,
    this.offset = 1,
  });

  factory XpHistoryModel.fromJson(Map<String, dynamic> json) {
    final historyList =
        json['history'] != null
            ? (json['history'] as List)
                .asMap()
                .entries
                .map(
                  (entry) => XpHistoryItem.fromJson(
                    entry.value,
                    fallbackId: entry.key,
                  ),
                )
                .toList()
            : <XpHistoryItem>[];

    return XpHistoryModel(
      history: historyList,
      totalEarned: json['total_earned'] ?? 0,
      totalItems:
          json['total_size'] ?? json['total'] ?? json['total_items'] ?? 0,
      limit: json['limit'] ?? 20,
      offset: json['offset'] ?? 1,
    );
  }

  bool get hasMore => history.length < totalItems;
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

  factory XpHistoryItem.fromJson(
    Map<String, dynamic> json, {
    int fallbackId = 0,
  }) {
    return XpHistoryItem(
      id: json['id'] ?? fallbackId,
      type: json['type'] ?? 'order',
      xp: json['xp'] ?? json['xp_earned'] ?? 0,
      description: json['description'] ?? '',
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      metadata: json['metadata'],
    );
  }

  /// True for XP deductions (e.g. an order refund reversed its XP).
  bool get isNegative => xp < 0;

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
      case 'streak':
        return '🔥';
      case 'signup':
        return '🎉';
      case 'refund':
        return '↩️';
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
