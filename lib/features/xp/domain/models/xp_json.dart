/// Tolerant readers for XP payloads (X-13).
///
/// The models used to assign `json['x'] ?? 0` straight into `int` fields. That
/// held only while every backend column happened to be cast, and it broke in
/// production the first time a shape drifted: PHP serializes an empty
/// associative array as `[]`, so `"challenges": []` arrived where a map was
/// expected. These readers accept what the wire can plausibly carry — numbers
/// as int, double or numeric string, maps that may be empty lists — and fall
/// back instead of throwing.
library;

int xpInt(dynamic v, [int fallback = 0]) => xpIntOrNull(v) ?? fallback;

int? xpIntOrNull(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  if (v is bool) return v ? 1 : 0;
  return null;
}

double? xpDoubleOrNull(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool xpBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    if (v == '1' || v.toLowerCase() == 'true') return true;
    if (v == '0' || v.toLowerCase() == 'false') return false;
  }
  return fallback;
}

String? xpStr(dynamic v) {
  if (v == null) return null;
  final s = '$v';
  return s.isEmpty ? null : s;
}

/// A map, or null. An empty PHP array (`[]`) reads as null, not a crash.
Map<String, dynamic>? xpMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

/// The maps inside a list, skipping anything that isn't one.
List<Map<String, dynamic>> xpMapList(dynamic v) =>
    v is List
        ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];

DateTime? xpDate(dynamic v) => v == null ? null : DateTime.tryParse('$v');
