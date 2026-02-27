class XpConfigModel {
  final bool levelingEnabled;
  final int xpPerOrder;
  final int xpPerReview;
  final int maxLevel;
  final int streakBonusXp;
  final Map<String, double> multipliers;
  final MultiplierEvent? multiplierEvent;

  XpConfigModel({
    required this.levelingEnabled,
    required this.xpPerOrder,
    required this.xpPerReview,
    this.maxLevel = 10,
    this.streakBonusXp = 0,
    required this.multipliers,
    this.multiplierEvent,
  });

  factory XpConfigModel.fromJson(Map<String, dynamic> json) {
    Map<String, double> multipliersMap = {};
    if (json['multipliers'] != null) {
      (json['multipliers'] as Map<String, dynamic>).forEach((key, value) {
        multipliersMap[key] = (value is int) ? value.toDouble() : (value ?? 0.0).toDouble();
      });
    }

    return XpConfigModel(
      levelingEnabled: json['enabled'] ?? false,
      xpPerOrder: json['xp_per_order'] ?? 0,
      xpPerReview: json['xp_per_review'] ?? 0,
      maxLevel: json['max_level'] ?? 10,
      streakBonusXp: json['streak_bonus_xp'] ?? 0,
      multipliers: multipliersMap,
      multiplierEvent: json['multiplier_event'] != null
          ? MultiplierEvent.fromJson(json['multiplier_event'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leveling_enabled': levelingEnabled,
      'xp_per_order': xpPerOrder,
      'xp_per_review': xpPerReview,
      'max_level': maxLevel,
      'streak_bonus_xp': streakBonusXp,
      'multipliers': multipliers,
    };
  }

  /// Calculate estimated XP for a given order amount and module type
  /// Formula: xp_per_order + floor(order_amount × module_multiplier)
  int calculateEstimatedXp(double orderAmount, String? moduleType) {
    if (!levelingEnabled) return 0;
    
    double multiplier = 1.0;
    if (moduleType != null && multipliers.containsKey(moduleType)) {
      multiplier = multipliers[moduleType]!;
    }

    // Apply event multiplier if active
    if (multiplierEvent != null && multiplierEvent!.isActive) {
      multiplier *= multiplierEvent!.multiplier;
    }
    
    return xpPerOrder + (orderAmount * multiplier).floor();
  }

  bool get hasActiveEvent => multiplierEvent != null && multiplierEvent!.isActive;
}

class MultiplierEvent {
  final bool active;
  final double multiplier;
  final String? title;
  final DateTime? endsAt;

  MultiplierEvent({
    this.active = false,
    this.multiplier = 1.0,
    this.title,
    this.endsAt,
  });

  factory MultiplierEvent.fromJson(Map<String, dynamic> json) {
    return MultiplierEvent(
      active: json['active'] ?? false,
      multiplier: (json['multiplier'] ?? 1.0).toDouble(),
      title: json['title'],
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'].toString())
          : null,
    );
  }

  bool get isActive {
    if (!active) return false;
    if (endsAt != null && endsAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  Duration? get timeRemaining {
    if (endsAt == null) return null;
    final diff = endsAt!.difference(DateTime.now());
    return diff.isNegative ? null : diff;
  }
}
