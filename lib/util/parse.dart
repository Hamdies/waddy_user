import 'package:flutter/foundation.dart';

import 'package:waddy_app/util/swallow.dart';

/// Parsing values that arrive from the server or from a URL.
///
/// ## Why not one "never throws" helper
///
/// The obvious move is a single `asDouble(v) => double.tryParse(v) ?? 0`. That
/// is wrong for money, and dangerously so: a missing price silently becoming
/// `0` produces a plausible wrong number that flows into an order, a total and
/// a payment. A crash at least names the problem. A wrong total does not.
///
/// So there are two tiers, and the choice is the point:
///
/// * **[lenient]** — display values. A missing rating, a malformed distance, a
///   coordinate the server left null. Render a fallback; nobody is harmed by a
///   map that opens on the wrong centre or a badge that reads `0 km`.
///
/// * **[strict]** — money, quantities and identifiers. Returns `null` on bad
///   input and reports to Crashlytics, so the caller has to decide what to do
///   with "I could not read this". The caller must **block the flow**, not
///   substitute a number.
///
/// The rule of thumb: if a wrong value would change what the customer pays,
/// receives, or is shown as owing, it is [strict].
///
/// ## Why `.toString()` first
///
/// Most call sites already do `int.parse(json['x'].toString())`, because the
/// backend is inconsistent about whether a numeric field arrives as a JSON
/// number or a quoted string. These helpers accept `Object?` and normalise, so
/// that dance disappears from the call sites.
class Parse {
  Parse._();

  // ---------------------------------------------------------------------
  // Lenient — display values
  // ---------------------------------------------------------------------

  /// An int for display, or [fallback] when the value is absent or unreadable.
  static int lenientInt(Object? value, {int fallback = 0}) =>
      _toInt(value) ?? fallback;

  /// A double for display, or [fallback] when absent or unreadable.
  static double lenientDouble(Object? value, {double fallback = 0}) =>
      _toDouble(value) ?? fallback;

  /// A coordinate, or null when it cannot be read.
  ///
  /// Coordinates get their own accessor because `0` is a *valid* latitude —
  /// it is in the Gulf of Guinea, several thousand kilometres from any Waddi
  /// zone. Defaulting a broken coordinate to zero puts a map pin in the
  /// Atlantic; returning null lets the caller fall back to a sensible centre.
  static double? coordinate(Object? value) {
    final double? parsed = _toDouble(value);
    if (parsed == null) return null;
    // Outside this range it is not a latitude, whatever it parsed to. Kept
    // deliberately loose (latitude bounds, not longitude) because the same
    // accessor reads both and -180..180 would let a junk latitude through.
    if (parsed.isNaN || parsed.abs() > 180) return null;
    return parsed;
  }

  // ---------------------------------------------------------------------
  // Strict — money, quantities, identifiers
  // ---------------------------------------------------------------------

  /// An int that must be right, or null.
  ///
  /// Reports to Crashlytics so a backend that starts sending junk in a
  /// quantity or an id becomes visible instead of silently changing orders.
  /// The caller decides what "unreadable" means for its flow — usually
  /// "refuse to proceed".
  static int? strictInt(Object? value, String field) {
    final int? parsed = _toInt(value);
    if (parsed == null) _reportUnreadable(field, value);
    return parsed;
  }

  /// A monetary or otherwise load-bearing double, or null.
  ///
  /// Never substitutes a value. A price that cannot be read is not zero.
  static double? strictDouble(Object? value, String field) {
    final double? parsed = _toDouble(value);
    if (parsed == null) _reportUnreadable(field, value);
    return parsed;
  }

  // ---------------------------------------------------------------------

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) {
      // A double that is not a whole number is not an int, and truncating it
      // silently is how a quantity of 2.5 becomes 2.
      return value == value.roundToDouble() ? value.toInt() : null;
    }
    final String s = value.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return int.tryParse(s) ?? double.tryParse(s)?.toInt();
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    final String s = value.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return double.tryParse(s);
  }

  static void _reportUnreadable(String field, Object? value) {
    // The value itself is included: knowing the backend sent "12,50" rather
    // than "12.50" is the whole diagnosis.
    final String detail = value == null ? 'null' : '"$value"';
    if (kDebugMode) {
      debugPrint('[Parse.strict] unreadable $field: $detail');
    }
    swallow(
      'unreadable $field from server: $detail',
      FormatException('cannot parse $field', detail),
      StackTrace.current,
      true,
    );
  }
}
