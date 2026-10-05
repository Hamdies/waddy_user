import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/util/boot_stats.dart';

/// `BootStats` measures the work before the first frame.
///
/// Every Mi 9T trace opens with `Skipped 61 frames` and a ~1,014ms frame
/// before anything is on screen. `FrameStats` cannot see that — it measures
/// frames, and this is the work happening instead of frames. `ApiStats` cannot
/// either, because most of it is not network.
///
/// What matters is that it never throws and never swallows a stage's result
/// or its exception: it runs on the path that decides whether the app starts
/// at all.
void main() {
  setUp(BootStats.begin);

  group('timing a stage', () {
    test('returns the value the stage produced', () async {
      final int result = await BootStats.stage('x', () async => 42);
      expect(result, 42);
    });

    test('an async value survives the wrapper', () async {
      final String result = await BootStats.stage('x', () async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        return 'done';
      });
      expect(result, 'done');
    });

    test('a failing stage rethrows — boot failures must not be hidden', () async {
      // The whole point of measuring boot is to understand it. A wrapper that
      // ate an exception here would turn a startup crash into a hang.
      await expectLater(
        BootStats.stage<void>('x', () async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );
    });

    test('a failing stage is still recorded', () async {
      try {
        await BootStats.stage<void>('slow-and-broken', () async {
          await Future<void>.delayed(const Duration(milliseconds: 2));
          throw StateError('boom');
        });
      } catch (_) {
        // expected
      }
      // Timed in a `finally`, so the cost of a stage that failed is still
      // visible — often that is the slow one.
      expect(BootStats.report(), contains('slow-and-broken'));
    });
  });

  group('the report', () {
    test('names every stage that ran', () async {
      await BootStats.stage('firebase.init', () async {});
      await BootStats.stage('di.init', () async {});
      final String out = BootStats.report();
      expect(out, contains('firebase.init'));
      expect(out, contains('di.init'));
    });

    test('is safe with no stages at all', () {
      expect(() => BootStats.report(), returnsNormally);
      expect(BootStats.report(), contains('BOOT to runApp'));
    });

    test('a repeated stage accumulates rather than overwriting', () async {
      // A boot step running twice is worth seeing, not hiding behind the last
      // measurement.
      await BootStats.stage('twice', () async {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      });
      await BootStats.stage('twice', () async {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      });
      final String out = BootStats.report();
      // One line, not two — the accumulation is the signal.
      expect('twice'.allMatches(out).length, 1);
    });

    test('begin() clears a previous run', () async {
      await BootStats.stage('old', () async {});
      BootStats.begin();
      expect(BootStats.report(), isNot(contains('old')));
    });
  });
}
