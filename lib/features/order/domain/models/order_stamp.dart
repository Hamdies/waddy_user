import 'package:waddy_app/features/order/domain/models/order_model.dart';

/// Status timestamps (`pending`, `delivered`, `canceled`, …) come from the
/// backend as naive wall-clock strings ("2026-09-27 07:52:00") written in the
/// server's configured business timezone, which is not necessarily the
/// customer's. `created_at` is cast by Laravel and arrives as a real UTC
/// instant ("…T04:52:00.000000Z").
///
/// `pending` and `created_at` are written in the same save, so the gap between
/// them is exactly the server's UTC offset. Reading the stamps through that
/// offset gives true instants whatever the admin timezone setting is, without
/// changing the wire format the store app also parses.
extension OrderStampX on OrderModel {
  /// The server's offset from UTC, or null when it can't be derived.
  Duration? get _serverOffset {
    final DateTime? created = _parse(createdAt);
    final DateTime? placed = _parseNaiveAsUtc(pending);
    if (created == null || placed == null || !created.isUtc) return null;
    final int minutes = placed.difference(created).inMinutes;
    // Real offsets are whole quarter-hours within ±14 h; anything else means
    // the two stamps weren't written together (switching a failed digital
    // payment to cash re-stamps `pending`).
    final int rounded = (minutes / 15).round() * 15;
    if ((minutes - rounded).abs() > 1 || rounded.abs() > 14 * 60) return null;
    return Duration(minutes: rounded);
  }

  /// A status stamp as a local [DateTime], or null when absent or unreadable.
  DateTime? stampToLocal(String? raw) {
    final DateTime? parsed = _parse(raw);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed.toLocal();
    final Duration? offset = _serverOffset;
    if (offset == null) return parsed; // best effort: treat as device-local
    return _parseNaiveAsUtc(raw)!.subtract(offset).toLocal();
  }

  static DateTime? _parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  static DateTime? _parseNaiveAsUtc(String? raw) {
    final DateTime? parsed = _parse(raw);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed;
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    );
  }
}
