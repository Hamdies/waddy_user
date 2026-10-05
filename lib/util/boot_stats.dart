import 'package:flutter/foundation.dart';

/// Times the work that happens before the first frame.
///
/// ## Why this exists
///
/// Every profile trace on the Mi 9T opens with the same line:
///
/// ```
/// I/Choreographer: Skipped 61 frames!  The application may be doing too much
///                  work on its main thread.
/// W/Looper: PerfMonitor doFrame : time=1014ms
/// ```
///
/// A one-second frame before anything is on screen. `FrameStats` cannot see it
/// — that measures frames, and this is the work happening *instead* of frames.
/// `ApiStats` cannot either, because most of it is not network.
///
/// `main()` serially awaits five things before `runApp`: Firebase, the DI
/// container, the notification plugin, deep links, and locale data. Which of
/// those costs the second is not knowable by reading the code — Firebase might
/// be 50ms or 600ms depending on the device and whether Play Services is warm.
///
/// So each is bracketed and reported. Then the ones worth parallelising can be
/// chosen by size rather than by guess, which is the mistake this plan has
/// made five times (docs/performance_baseline.md §13.1).
///
/// ## Cost
///
/// One `Stopwatch` and a map write per stage, on a path that runs once. The
/// report prints in debug and profile, and is silent in release.
class BootStats {
  BootStats._();

  static final Stopwatch _total = Stopwatch();
  static final Map<String, int> _stageMs = <String, int>{};
  static final List<String> _order = <String>[];

  /// Starts the overall timer. Call as the first line of `main()`.
  static void begin() {
    _stageMs.clear();
    _order.clear();
    _total
      ..reset()
      ..start();
  }

  /// Times [action] and records it under [stage].
  ///
  /// Returns whatever [action] returns, so it wraps an existing await without
  /// restructuring the call:
  ///
  /// ```dart
  /// final languages = await BootStats.stage('di.init', di.init);
  /// ```
  static Future<T> stage<T>(String name, Future<T> Function() action) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      return await action();
    } finally {
      sw.stop();
      // A stage that runs twice accumulates rather than overwriting — a
      // silently repeated boot step is worth seeing, not hiding.
      if (!_stageMs.containsKey(name)) _order.add(name);
      _stageMs[name] = (_stageMs[name] ?? 0) + sw.elapsedMilliseconds;
    }
  }

  /// Stops the timer and prints the breakdown. Call immediately before
  /// `runApp`.
  static void endAndPrint() {
    _total.stop();
    if (kReleaseMode) return;
    debugPrint(report());
  }

  static String report() {
    final int total = _total.elapsedMilliseconds;
    final int measured = _stageMs.values.fold(0, (int a, int b) => a + b);

    final StringBuffer out =
        StringBuffer()
          ..writeln('── BOOT to runApp ────────────────────')
          ..writeln('total: ${total}ms   measured: ${measured}ms');

    // Slowest first: the point is to find what to attack.
    final List<String> byCost =
        _order.toList()
          ..sort((String a, String b) => _stageMs[b]!.compareTo(_stageMs[a]!));

    for (final String name in byCost) {
      final int ms = _stageMs[name]!;
      final int pct = total == 0 ? 0 : ((ms / total) * 100).round();
      out.writeln(
        '  ${ms.toString().padLeft(5)}ms  ${pct.toString().padLeft(3)}%  $name',
      );
    }

    // Anything not inside a stage: plugin registration, the Dart VM warming,
    // and whatever else sits between the awaits.
    final int unaccounted = total - measured;
    if (unaccounted > 0) {
      out.writeln(
        '  ${unaccounted.toString().padLeft(5)}ms  '
        '${(total == 0 ? 0 : ((unaccounted / total) * 100).round()).toString().padLeft(3)}%  '
        '(unmeasured — plugin registration, VM warmup)',
      );
    }
    return out.toString();
  }
}
