import 'package:waddy_app/features/xp/domain/models/prize_kind.dart';

/// What a level prize means to the user right now — the one place that
/// decides it (X-31).
///
/// The XP home used to read the level payload's `is_unlocked` / `is_claimed`,
/// which the backend sets for any instance (expired included) and for both
/// `claimed` and `used`. So an expired prize read "Ready" and a claimed coupon
/// not yet spent read "Used", while the Rewards screen, grouping by `status`,
/// got both right. Every surface now asks this.
enum RewardState {
  /// Claiming does something: a wallet credit pays out, a discount mints its
  /// coupon.
  claim,

  /// Spend it: a free delivery at checkout, a claimed discount's coupon.
  use,

  /// An earned badge. Nothing to claim or spend.
  badge,

  used,
  expired,

  /// Not reached yet (level payload only; `/prizes` lists owned prizes).
  locked;

  /// [status] is the user-prize status (`unlocked` · `claimed` · `used` ·
  /// `expired`), null when the user has no instance. [expiresAt] catches a
  /// prize past its deadline whose status the server flips only later.
  static RewardState of({
    required String type,
    required String? status,
    DateTime? expiresAt,
  }) {
    final kind = PrizeKind.parse(type);
    final s = status?.toLowerCase();
    if (s == null || s.isEmpty || s == 'locked') return RewardState.locked;
    if (kind == PrizeKind.badge) return RewardState.badge;
    if (s == 'used') return RewardState.used;
    if (s == 'expired' ||
        (expiresAt != null && DateTime.now().isAfter(expiresAt))) {
      return RewardState.expired;
    }
    // Checkout takes an unlocked free delivery as it is; there is no claim
    // step (X-26).
    if (kind == PrizeKind.freeDelivery) return RewardState.use;
    if (s == 'unlocked') return RewardState.claim;
    return RewardState.use;
  }

  /// Something the user can act on now. What the hero counts.
  bool get isLive => this == RewardState.claim || this == RewardState.use;
}
