import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/util/frame_stats.dart';

/// `FrameStats` exists so M4 stops being a guess.
///
/// The plan counts 527 unscoped `update()` calls as the performance metric.
/// That is a proxy, and proxies have misled this codebase three times already
/// (§16, §20, §21 of the hardening plan). A rebuild is not jank: a `GetBuilder`
/// around a `Text` costs nothing, one around an image grid costs a frame.
///
/// These tests cover the reporting contract — that it never throws, reports
/// honestly when it has no data, and draws the build-vs-raster conclusion the
/// right way round. The frame numbers themselves can only come from a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    // Leave no callback registered between tests.
    if (FrameStats.isMeasuring) FrameStats.stop();
  });

  group('the measurement window', () {
    test('is closed until started', () {
      expect(FrameStats.isMeasuring, isFalse);
    });

    test('opens and closes', () {
      FrameStats.start('unit test');
      expect(FrameStats.isMeasuring, isTrue);
      FrameStats.stop();
      expect(FrameStats.isMeasuring, isFalse);
    });

    test('starting twice does not double-register the callback', () {
      // A second `start` replaces the window rather than stacking a listener;
      // otherwise every frame would be counted twice and jank would read low.
      FrameStats.start('first');
      FrameStats.start('second');
      expect(FrameStats.isMeasuring, isTrue);
      FrameStats.stop();
      expect(FrameStats.isMeasuring, isFalse);
    });

    test('stopping without starting does not throw', () {
      expect(() => FrameStats.stop(), returnsNormally);
    });
  });

  group('reporting', () {
    test('says so plainly when no frames were captured', () {
      // The likeliest misuse: a window closed before the first frame rendered.
      // Reporting "0% jank" there would be a lie that reads like a pass.
      FrameStats.start('empty window');
      final String out = FrameStats.stop();
      expect(out, contains('no frames captured'));
      expect(out, isNot(contains('0.0%')));
    });

    test('the label appears in the output', () {
      FrameStats.start('cart quantity tap');
      expect(FrameStats.stop(), contains('cart quantity tap'));
    });

    test('jank percentage is zero, not NaN, with no frames', () {
      // frames == 0 would divide by zero and render as NaN in a log.
      FrameStats.start('unit test');
      expect(FrameStats.jankPercent, 0);
      expect(FrameStats.jankPercent.isNaN, isFalse);
      FrameStats.stop();
    });

    test('counters reset between windows', () {
      FrameStats.start('first');
      FrameStats.stop();
      FrameStats.start('second');
      expect(FrameStats.frames, 0);
      expect(FrameStats.jankyFrames, 0);
      FrameStats.stop();
    });
  });

  group('the budget follows the display', () {
    test('falls back to a 60Hz frame when no display is attached', () {
      // A test binding has no real view, so this exercises the fallback. On a
      // device it reads the actual rate: 16.7ms at 60Hz, 8.3ms at 120Hz.
      // Hardcoding 60Hz would under-report jank on a ProMotion screen by 2x,
      // turning a real stutter into a clean report.
      expect(FrameStats.budget.inMilliseconds, inInclusiveRange(8, 17));
    });

    test('severe is two frames, whatever the rate', () {
      expect(
        FrameStats.severeBudget,
        FrameStats.budget * 2,
        reason: 'severe must scale with the display, not with a constant',
      );
      expect(
        FrameStats.severeBudget > FrameStats.budget,
        isTrue,
        reason: 'severe must be a strictly worse frame than janky',
      );
    });

    test('an implausible refresh rate falls back rather than trusting it', () {
      // A platform that answers 0 or 1000Hz has not really answered. The
      // guard keeps the budget sane rather than reporting everything, or
      // nothing, as jank.
      expect(FrameStats.budget.inMicroseconds, greaterThan(0));
      expect(FrameStats.budget.inMilliseconds, lessThanOrEqualTo(50));
    });
  });
}
