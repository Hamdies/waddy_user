import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// GetX has no ICU plurals — keys come in `_one` / `_other` pairs and the
/// Arabic `_other` copy must be written to read acceptably for every count.
String trPlural(
  String base,
  int count, {
  Map<String, String> params = const {},
}) => (count == 1 ? '${base}_one' : '${base}_other').trParams({
  'count': fmtCount(count),
  ...params,
});

/// Locale-aware digit grouping for vote counts and stats.
String fmtCount(int n) =>
    NumberFormat.decimalPattern(Get.locale?.toString()).format(n);
