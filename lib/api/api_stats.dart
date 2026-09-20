import 'package:flutter/foundation.dart';

/// Counts what actually leaves the device.
///
/// The performance work has targets stated in requests-per-screen and
/// bytes-on-the-wire ("home should cost one round trip, not twenty-five"), and
/// none of those were measurable — the app had no idea how many calls it made.
/// Every request through [ApiClient] reports here, so the numbers can be read
/// back instead of estimated.
///
/// Counting is cheap (two int adds and a map write per request) and stays on in
/// release; only the printed report is debug-gated. Set [enabled] to false to
/// turn even the counting off.
class ApiStats {
  ApiStats._();

  static bool enabled = true;

  static int requests = 0;
  static int failures = 0;
  static int bytes = 0;
  static int fromCache304 = 0;

  static final Map<String, int> _countByEndpoint = {};
  static final Map<String, int> _slowestMsByEndpoint = {};
  static final Map<String, int> _bytesByEndpoint = {};

  static DateTime? _windowStart;
  static String? _windowLabel;

  /// Groups `/api/v1/stores/get-stores/all?offset=1&limit=12` under
  /// `/api/v1/stores/get-stores/all`, so a paginated rail reads as one endpoint
  /// called N times rather than N endpoints called once.
  static String normalise(String uri) {
    final int q = uri.indexOf('?');
    return q == -1 ? uri : uri.substring(0, q);
  }

  static void record({
    required String uri,
    required int elapsedMs,
    required int responseBytes,
    required bool ok,
    bool notModified = false,
  }) {
    if (!enabled) return;
    final String key = normalise(uri);

    requests++;
    bytes += responseBytes;
    if (!ok) failures++;
    if (notModified) fromCache304++;

    _countByEndpoint[key] = (_countByEndpoint[key] ?? 0) + 1;
    _bytesByEndpoint[key] = (_bytesByEndpoint[key] ?? 0) + responseBytes;
    if (elapsedMs > (_slowestMsByEndpoint[key] ?? 0)) {
      _slowestMsByEndpoint[key] = elapsedMs;
    }
  }

  /// Opens a named measurement window — call before a screen starts loading,
  /// close it when the load settles. [report] then describes just that screen.
  static void startWindow(String label) {
    reset();
    _windowStart = DateTime.now();
    _windowLabel = label;
  }

  static void reset() {
    requests = 0;
    failures = 0;
    bytes = 0;
    fromCache304 = 0;
    _countByEndpoint.clear();
    _slowestMsByEndpoint.clear();
    _bytesByEndpoint.clear();
    _windowStart = null;
    _windowLabel = null;
  }

  /// Human-readable summary, ordered by call count so the loudest endpoint is
  /// first. Duplicated endpoints — the thing worth hunting — sort to the top.
  static String report() {
    final int elapsed =
        _windowStart == null
            ? 0
            : DateTime.now().difference(_windowStart!).inMilliseconds;

    final List<String> keys =
        _countByEndpoint.keys.toList()..sort(
          (a, b) =>
              (_countByEndpoint[b] ?? 0).compareTo(_countByEndpoint[a] ?? 0),
        );

    final StringBuffer out =
        StringBuffer()
          ..writeln('── API ${_windowLabel ?? 'session'} ────────────────────')
          ..writeln(
            'requests: $requests   failures: $failures   '
            '304s: $fromCache304   bytes: ${_kb(bytes)}'
            '${elapsed > 0 ? '   wall: ${elapsed}ms' : ''}',
          );

    for (final String key in keys) {
      final int count = _countByEndpoint[key] ?? 0;
      out.writeln(
        '  ${count.toString().padLeft(2)}×  '
        '${(_slowestMsByEndpoint[key] ?? 0).toString().padLeft(5)}ms  '
        '${_kb(_bytesByEndpoint[key] ?? 0).padLeft(8)}  $key',
      );
    }
    return out.toString();
  }

  static void printReport() {
    if (kDebugMode) {
      debugPrint(report());
    }
  }

  static String _kb(int b) =>
      b < 1024 ? '${b}B' : '${(b / 1024).toStringAsFixed(1)}KB';
}
