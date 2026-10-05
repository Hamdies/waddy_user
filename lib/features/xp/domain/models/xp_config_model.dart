import 'package:waddy_app/features/xp/domain/models/xp_json.dart';

class XpConfigModel {
  final bool levelingEnabled;
  final int xpPerOrder;
  final int xpPerReview;
  final int xpSignupBonus;
  final int maxLevel;
  final int streakBonusXp;

  /// XP earned per currency unit spent. Comes from the server so the client
  /// estimate stays in sync if an admin changes the rate.
  final double xpPerCurrencyUnit;
  final Map<String, double> multipliers;
  final MultiplierEvent? multiplierEvent;

  /// Real per-action XP amounts keyed by source (`order`, `review`, `vote`,
  /// `place_review`, `photo_review`, `place_submission`, `streak_bonus`), from
  /// the server's `xp_sources` block. Drives the "Ways to earn" grid so it shows
  /// live values, never invented ones. Empty on older backends.
  final Map<String, int> xpSources;

  XpConfigModel({
    required this.levelingEnabled,
    required this.xpPerOrder,
    required this.xpPerReview,
    this.xpSignupBonus = 50,
    this.maxLevel = 10,
    this.streakBonusXp = 0,
    this.xpPerCurrencyUnit = 0.1,
    required this.multipliers,
    this.multiplierEvent,
    this.xpSources = const {},
  });

  factory XpConfigModel.fromJson(Map<String, dynamic> json) {
    final multipliersMap = <String, double>{};
    xpMap(json['multipliers'])?.forEach((key, value) {
      multipliersMap[key] = xpDoubleOrNull(value) ?? 0.0;
    });

    final sourcesMap = <String, int>{};
    xpMap(json['xp_sources'])?.forEach((key, value) {
      final v = xpIntOrNull(value);
      if (v != null) sourcesMap[key] = v;
    });

    final event = xpMap(json['multiplier_event']);
    return XpConfigModel(
      levelingEnabled: xpBool(json['enabled']),
      xpPerOrder: xpInt(json['xp_per_order']),
      xpPerReview: xpInt(json['xp_per_review']),
      xpSignupBonus: xpInt(json['xp_signup_bonus'], 50),
      maxLevel: xpInt(json['max_level'], 10),
      streakBonusXp: xpInt(json['streak_bonus_xp']),
      xpPerCurrencyUnit: xpDoubleOrNull(json['xp_per_currency_unit']) ?? 0.1,
      multipliers: multipliersMap,
      multiplierEvent: event != null ? MultiplierEvent.fromJson(event) : null,
      xpSources: sourcesMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leveling_enabled': levelingEnabled,
      'xp_per_order': xpPerOrder,
      'xp_per_review': xpPerReview,
      'xp_signup_bonus': xpSignupBonus,
      'max_level': maxLevel,
      'streak_bonus_xp': streakBonusXp,
      'multipliers': multipliers,
    };
  }

  /// Effective multiplier for a module, including any active event bonus.
  double _multiplierFor(String? moduleType) {
    double multiplier = 1.0;
    if (moduleType != null && multipliers.containsKey(moduleType)) {
      multiplier = multipliers[moduleType]!;
    }
    if (multiplierEvent != null && multiplierEvent!.isActive) {
      multiplier *= multiplierEvent!.multiplier;
    }
    return multiplier;
  }

  /// Estimate XP from a whole-order amount (used where line items aren't
  /// available, e.g. the order-success screen).
  ///
  /// NOTE: the server floors XP per item line, so for multi-item orders this
  /// aggregate estimate can read a few XP high. Prefer
  /// [calculateEstimatedXpForItems] wherever line items are known (cart/checkout).
  int calculateEstimatedXp(double orderAmount, String? moduleType) {
    if (!levelingEnabled) return 0;
    final multiplier = _multiplierFor(moduleType);
    return xpPerOrder + (orderAmount * multiplier * xpPerCurrencyUnit).floor();
  }

  /// Estimate XP from individual line items, matching the backend exactly:
  /// xp_per_order (flat) + Σ floor(price × qty × multiplier × rate) per line.
  int calculateEstimatedXpForItems(
    List<({double price, int quantity})> lines,
    String? moduleType,
  ) {
    if (!levelingEnabled) return 0;
    final multiplier = _multiplierFor(moduleType);
    int itemXp = 0;
    for (final line in lines) {
      itemXp +=
          (line.price * line.quantity * multiplier * xpPerCurrencyUnit).floor();
    }
    return xpPerOrder + itemXp;
  }

  bool get hasActiveEvent =>
      multiplierEvent != null && multiplierEvent!.isActive;
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
      active: xpBool(json['active']),
      multiplier: xpDoubleOrNull(json['multiplier']) ?? 1.0,
      title: xpStr(json['title']),
      endsAt: xpDate(json['ends_at']),
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
