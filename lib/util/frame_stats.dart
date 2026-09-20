import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Measures what the user actually feels: dropped frames.
///
/// ## Why this exists
///
/// The hardening plan tracks 527 unscoped `update()` calls as the performance
/// metric. That number is a *proxy*, and this codebase has already been wrong
/// three times about what a proxy means — `configModel!` counted 358 sites
/// where ~60 mattered, the parse audit counted 260 where 26 mattered, and the
/// i18n gap counted 36 missing keys that were all unused.
///
/// A rebuild is not jank. A `GetBuilder` wrapping a `Text` costs nothing to
/// rebuild; one wrapping a grid of network images costs a frame. Scoping 527
/// call sites without knowing which is which would be weeks of work aimed at a
/// number rather than at a symptom.
///
/// So: measure first. [FrameStats] reports how many frames missed their budget
/// during a named window, and how badly. Then the scoping work goes where the
/// frames are actually being dropped.
///
/// ## How to read the output
///
/// A frame has two phases. **Build** is Dart — widget rebuilds, layout, paint
/// instructions; this is what unscoped `update()` inflates. **Raster** is the
/// GPU turning those instructions into pixels; this is inflated by images,
/// shadows, blurs, opacity layers and clipping.
///
/// The split is the whole diagnosis:
///
/// * build over budget, raster fine → too much rebuilding. Scope the updates.
/// * raster over budget, build fine → the *painting* is expensive. Scoping
///   `update()` will not help; look at image decode size, `BackdropFilter`,
///   `Opacity`, unclipped shadows.
/// * both → start with raster; it is usually the cheaper fix.
///
/// ## Budget
///
/// Read from the display, not assumed. 60Hz gives a 16.7ms budget, 120Hz gives
/// 8.3ms. A 120Hz device reports more jank at the same workload, which is
/// correct — it really is dropping frames the user can see.
///
/// ## Cost
///
/// One callback per frame doing a comparison and, rarely, a list append. It is
/// registered only when [start] is called, so it costs nothing until someone is
/// measuring. The report prints in debug and profile and is silent in release;
/// profile is where the numbers are worth reading.
class FrameStats {
  FrameStats._();

  /// One frame at the display's actual refresh rate.
  ///
  /// Hardcoding 16ms (60Hz) under-reports on a 120Hz screen by a factor of
  /// two: a ProMotion iPhone drops a frame at 8.3ms, and calling that fine
  /// would turn a real stutter into a clean report. Read from the device
  /// instead, with 60Hz as the fallback when the view is not yet attached.
  static Duration get budget {
    final double hz =
        WidgetsBinding.instance.platformDispatcher.views.isEmpty
            ? 60.0
            : WidgetsBinding
                .instance
                .platformDispatcher
                .views
                .first
                .display
                .refreshRate;
    // A nonsense rate (0, or absurdly high) means the platform did not answer;
    // 60Hz is the safe assumption for the devices this app targets.
    if (hz < 20 || hz > 500) return const Duration(milliseconds: 16);
    return Duration(microseconds: (1000000 / hz).round());
  }

  /// Two frames' worth. Not a stutter — a hitch the user sees as a pause.
  static Duration get severeBudget => budget * 2;

  static bool _listening = false;
  static String? _label;
  static DateTime? _startedAt;

  static int _frames = 0;
  static int _janky = 0;
  static int _severe = 0;
  static int _worstBuildUs = 0;
  static int _worstRasterUs = 0;
  static int _totalBuildUs = 0;
  static int _totalRasterUs = 0;

  /// True while a measurement window is open.
  static bool get isMeasuring => _listening;

  /// Frames rendered in the current window.
  static int get frames => _frames;

  /// Frames that missed the 16ms budget.
  static int get jankyFrames => _janky;

  /// Percentage of frames that missed budget. This is the number to hold a
  /// target against — under 1% feels smooth, over 5% feels broken.
  static double get jankPercent => _frames == 0 ? 0 : (_janky / _frames) * 100;

  /// Opens a measurement window.
  ///
  /// Call it immediately before the interaction being measured — a screen
  /// push, a scroll, a quantity tap — and [stop] when it settles. Calling it
  /// again replaces the window, matching `ApiStats.startWindow`.
  static void start(String label) {
    _reset();
    _label = label;
    _startedAt = DateTime.now();
    if (!_listening) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _listening = true;
    }
  }

  /// Closes the window and returns the report.
  static String stop() {
    final String out = report();
    if (_listening) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _listening = false;
    }
    return out;
  }

  /// Closes the window and prints the report.
  ///
  /// Printed in debug **and profile**, silent in release. Profile is the only
  /// build whose frame numbers mean anything — debug is 3-10x slower — so
  /// gating this on `kDebugMode` alone hid the report in the exact mode it
  /// exists to serve.
  static void stopAndPrint() {
    final String out = stop();
    if (!kReleaseMode) debugPrint(out);
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final FrameTiming t in timings) {
      final int buildUs = t.buildDuration.inMicroseconds;
      final int rasterUs = t.rasterDuration.inMicroseconds;
      final int totalUs = t.totalSpan.inMicroseconds;

      _frames++;
      _totalBuildUs += buildUs;
      _totalRasterUs += rasterUs;
      if (buildUs > _worstBuildUs) _worstBuildUs = buildUs;
      if (rasterUs > _worstRasterUs) _worstRasterUs = rasterUs;

      // totalSpan covers vsync to vsync, which is what the user experiences —
      // a frame can have a fast build and still be late.
      if (totalUs > budget.inMicroseconds) _janky++;
      if (totalUs > severeBudget.inMicroseconds) _severe++;
    }
  }

  static void _reset() {
    _frames = 0;
    _janky = 0;
    _severe = 0;
    _worstBuildUs = 0;
    _worstRasterUs = 0;
    _totalBuildUs = 0;
    _totalRasterUs = 0;
    _label = null;
    _startedAt = null;
  }

  /// Human-readable summary, shaped like `ApiStats.report()` so the two read
  /// together in a log.
  static String report() {
    final int wallMs =
        _startedAt == null
            ? 0
            : DateTime.now().difference(_startedAt!).inMilliseconds;

    if (_frames == 0) {
      return '── FRAMES ${_label ?? 'session'} ──\n'
          '  no frames captured'
          '${wallMs > 0 ? ' in ${wallMs}ms' : ''} — the window may have '
          'closed before the first frame rendered\n';
    }

    // Judged on the AVERAGE, not the worst frame.
    //
    // The first version compared worst-case build against worst-case raster,
    // and got the answer backwards on a real device: one 84ms build outlier
    // during a cold start outvoted a raster average running 2-3x the build
    // average across every other frame. A single stutter is not what a scroll
    // feels like; the steady-state cost is.
    //
    // Worst values are still reported — they are what a user perceives as a
    // hitch — but they do not decide where the work goes.
    final int avgBuildUs = _totalBuildUs ~/ _frames;
    final int avgRasterUs = _totalRasterUs ~/ _frames;

    final String verdict;
    if (avgRasterUs > avgBuildUs * 1.3) {
      verdict =
          'RASTER-bound (avg ${_ms(avgRasterUs)} vs build ${_ms(avgBuildUs)}) '
          '— painting cost. Look at image decode size, Opacity, '
          'BackdropFilter, unclipped shadows. Scoping update() will not help';
    } else if (avgBuildUs > avgRasterUs * 1.3) {
      verdict =
          'BUILD-bound (avg ${_ms(avgBuildUs)} vs raster ${_ms(avgRasterUs)}) '
          '— rebuild cost. This is what scoping update() addresses';
    } else {
      verdict =
          'MIXED (build ${_ms(avgBuildUs)}, raster ${_ms(avgRasterUs)}) '
          '— neither dominates; start with raster, it is usually cheaper';
    }

    final StringBuffer out =
        StringBuffer()
          ..writeln('── FRAMES ${_label ?? 'session'} ────────────────────')
          ..writeln(
            'frames: $_frames   '
            'janky: $_janky (${jankPercent.toStringAsFixed(1)}%)'
            '   severe: $_severe'
            '${wallMs > 0 ? '   wall: ${wallMs}ms' : ''}'
            // Printed so a reader can confirm the budget matched the screen.
            // A 120Hz device showing a 16ms budget means the rate was not read.
            '   budget: ${(budget.inMicroseconds / 1000).toStringAsFixed(1)}ms',
          )
          ..writeln(
            '  build   avg ${_ms(_totalBuildUs ~/ _frames).padLeft(7)}   '
            'worst ${_ms(_worstBuildUs).padLeft(7)}',
          )
          ..writeln(
            '  raster  avg ${_ms(_totalRasterUs ~/ _frames).padLeft(7)}   '
            'worst ${_ms(_worstRasterUs).padLeft(7)}',
          )
          ..writeln('  $verdict');
    return out.toString();
  }

  static String _ms(int microseconds) =>
      '${(microseconds / 1000).toStringAsFixed(1)}ms';
}
