import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:waddy_app/util/styles.dart';

/// The single source of truth for when a Spot Battle round closes.
///
/// This exists because the app previously stated the deadline twice, from two
/// different numbers, in the same card: the timer counted down to Monday 00:00
/// local, while the "crown locks" label beside it rendered that instant *minus
/// three hours* and so read "SUN · 9:00 PM". Two deadlines three hours apart,
/// side by side, on the one element whose whole job is urgency.
///
/// Nothing here invents a new deadline. It takes the instant the timer was
/// already counting to and makes every label derive from that same instant, so
/// the card can only ever state one time.
///
/// TODO(backend): the lock instant should arrive with the standings payload
/// rather than being computed on-device. Until it does, a user whose phone
/// clock or timezone is off sees a different deadline than the server enforces,
/// and a round the backend closes early cannot be reflected here at all. When
/// the field lands, replace [lockAt] with the server value and keep this class
/// as the formatting layer.
class SpotsRound {
  const SpotsRound._();

  /// Rounds close at Monday 00:00 in the user's local time — the same period
  /// boundary the backend counts on.
  static DateTime lockAt([DateTime? from]) {
    final now = from ?? DateTime.now();
    final daysToMonday = 8 - now.weekday; // 1 (Sun) .. 7 (Mon)
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: daysToMonday));
  }

  static Duration remaining([DateTime? from]) {
    final now = from ?? DateTime.now();
    final left = lockAt(now).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Full clock for the standings screen. Seconds are always the last unit so
  /// something on screen is always moving.
  static String countdown(Duration left) {
    String two(int n) => n.toString().padLeft(2, '0');
    final totalHours = left.inHours;
    final m = left.inMinutes % 60;
    final s = left.inSeconds % 60;

    if (totalHours < 1) return '${two(m)}:${two(s)}';
    if (totalHours < 24) return '$totalHours:${two(m)}:${two(s)}';

    final days = left.inDays;
    final hoursLeft = totalHours % 24;
    final d = 'spots_unit_d'.tr, h = 'spots_unit_h'.tr;
    return '$days$d $hoursLeft$h ${two(m)}:${two(s)}';
  }

  /// Coarse form for the home strip: "2d 6h" / "6h 12m" / "12m".
  ///
  /// Deliberately not second-accurate. On home this is context for a glance,
  /// and a 1Hz repaint on the busiest screen in the app buys nothing — the user
  /// is not watching it tick, they are deciding what to eat.
  static String short(Duration left) {
    final d = 'spots_unit_d'.tr;
    final h = 'spots_unit_h'.tr;
    final m = 'spots_unit_m'.tr;

    if (left.inDays >= 1) return '${left.inDays}$d ${left.inHours % 24}$h';
    if (left.inHours >= 1) return '${left.inHours}$h ${left.inMinutes % 60}$m';
    return '${left.inMinutes}$m';
  }

  /// True in the last day, when the countdown should switch to urgent styling.
  static bool isUrgent(Duration left) => left.inHours < 24;

  /// Human label for the lock instant itself ("MON · 12:00 AM").
  ///
  /// Derived from [lockAt] with no offset. The old `-3h` shift is gone: it made
  /// the label disagree with the timer directly above it.
  static String lockLabel([DateTime? from]) {
    final lock = lockAt(from);
    final locale = Get.locale?.toString();
    return displayCaps(
      '${DateFormat.E(locale).format(lock)} · ${DateFormat.jm(locale).format(lock)}',
    );
  }
}
