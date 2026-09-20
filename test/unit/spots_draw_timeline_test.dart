import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/places/domain/spots_draw_timeline.dart';

/// `CLAW-10` — the grab sequence, tested without a ticker.
///
/// [ClawGrabTimeline.frameAt] is pure, which is the whole reason the timeline
/// was pulled out of the widget: "the ball is held before the jaws close" is a
/// bug you can assert here in a millisecond and would otherwise only catch by
/// watching a 15-second animation and trusting your eyes.
///
/// Timings are the design's eight-step `STEPS` array. The cumulative
/// milestones, for reading the assertions below:
///
///     scan    0 →  520
///     seek  520 → 1280
///     drop 1280 → 1900
///     grab 1900 → 2420
///     lift 2420 → 3040
///     carry 3040 → 3600
///     release 3600 → 3880
///     settle  3880 → 4580
const _grab = 4580;

/// Local time, as `frameAt` wants it, from a millisecond offset into one grab.
double _at(int ms) => ms / _grab;

void main() {
  group('grab durations', () {
    test('one grab is 4.58s', () {
      expect(ClawGrabTimeline.grab.inMilliseconds, _grab);
    });

    test('five pulls — the live default — runs about 23 seconds', () {
      final total = ClawGrabTimeline.total(5);
      expect(total.inMilliseconds, _grab * 5);
      // The threshold that made the SKIP control non-optional.
      expect(total.inSeconds, greaterThan(10));
    });

    test('the step durations sum to one grab', () {
      final sum =
          ClawGrabTimeline.scan +
          ClawGrabTimeline.seek +
          ClawGrabTimeline.descend +
          ClawGrabTimeline.close +
          ClawGrabTimeline.lift +
          ClawGrabTimeline.carry +
          ClawGrabTimeline.eject +
          ClawGrabTimeline.reveal;
      expect(sum, ClawGrabTimeline.grab);
    });
  });

  group('the hunt', () {
    test('starts by scanning away from the target, not toward it', () {
      // The anticipation beat: the claw must not have committed to the target
      // column while it is still scanning, or the machine has already told
      // you the answer.
      final f = ClawGrabTimeline.frameAt(_at(300));
      expect(f.stage, ClawStage.scan);
      expect(f.travel, 0);
      expect(f.scanAway, greaterThan(0));
      expect(f.held, isFalse);
    });

    test('the scan sweep unwinds as the seek winds on', () {
      // Blended rather than switched, so the claw makes one continuous move
      // instead of snapping back to park between the two steps.
      final f = ClawGrabTimeline.frameAt(_at(900));
      expect(f.stage, ClawStage.seek);
      expect(f.travel, greaterThan(0));
      expect(f.scanAway, lessThan(1));
      expect(f.travel + f.scanAway, closeTo(1, 0.0001));
    });

    test('the claw reaches the target column before descending', () {
      final f = ClawGrabTimeline.frameAt(_at(1280));
      expect(f.travel, closeTo(1, 0.01));
      expect(f.descend, 0);
    });
  });

  group('frameAt', () {
    test('starts parked, open, empty', () {
      final f = ClawGrabTimeline.frameAt(0);
      expect(f.travel, 0);
      expect(f.scanAway, 0);
      expect(f.descend, 0);
      expect(f.open, 1);
      expect(f.held, isFalse);
      expect(f.ejected, 0);
    });

    test('ends at the chute, open, empty — the settle beat', () {
      final f = ClawGrabTimeline.frameAt(1);
      expect(f.stage, ClawStage.reveal);
      expect(f.carry, 1);
      expect(f.descend, 0);
      expect(f.open, 1);
      expect(f.held, isFalse);
      expect(f.ejected, 1);
    });

    test('the claw is fully down before the prongs start closing', () {
      final atClose = ClawGrabTimeline.frameAt(_at(1900));
      expect(atClose.descend, closeTo(1, 0.01));
      expect(atClose.open, closeTo(1, 0.05));
    });

    test('the ball is not held until the prongs are closing', () {
      // The ordering bug worth guarding: a ball held during descent looks like
      // it jumped into the claw.
      for (final ms in [0, 300, 520, 900, 1280, 1600, 1900]) {
        expect(
          ClawGrabTimeline.frameAt(_at(ms)).held,
          isFalse,
          reason: 'held too early at ${ms}ms',
        );
      }
    });

    test('the ball is held by the end of the grab step', () {
      expect(ClawGrabTimeline.frameAt(_at(2300)).held, isTrue);
      expect(ClawGrabTimeline.frameAt(_at(2420)).held, isTrue);
    });

    test('the prongs stay shut while the ball is lifted', () {
      final lifting = ClawGrabTimeline.frameAt(_at(2700));
      expect(lifting.stage, ClawStage.lift);
      expect(lifting.open, 0);
      expect(lifting.held, isTrue);
      expect(lifting.descend, lessThan(1));
    });

    test('the ball is carried to the chute still held', () {
      // The follow-through: without this the ball stops existing over the pile
      // and the chute below fills by magic.
      final carrying = ClawGrabTimeline.frameAt(_at(3300));
      expect(carrying.stage, ClawStage.carry);
      expect(carrying.held, isTrue);
      expect(carrying.descend, 0);
      expect(carrying.carry, greaterThan(0));
    });

    test('the claw is up and at the chute before the ball releases', () {
      final releasing = ClawGrabTimeline.frameAt(_at(3700));
      expect(releasing.stage, ClawStage.release);
      expect(releasing.descend, 0);
      expect(releasing.carry, 1);
      expect(releasing.ejected, greaterThan(0));
    });

    test('the ball is let go during the release, not after', () {
      final late = ClawGrabTimeline.frameAt(_at(3850));
      expect(late.held, isFalse);
      expect(late.ejected, greaterThan(0.5));
    });

    test('every value stays in range across the whole grab', () {
      for (var ms = 0; ms <= _grab; ms += 10) {
        final f = ClawGrabTimeline.frameAt(_at(ms));
        expect(f.travel, inInclusiveRange(0, 1), reason: 'travel at ${ms}ms');
        expect(
          f.scanAway,
          inInclusiveRange(0, 1),
          reason: 'scanAway at ${ms}ms',
        );
        expect(f.carry, inInclusiveRange(0, 1), reason: 'carry at ${ms}ms');
        expect(f.descend, inInclusiveRange(0, 1), reason: 'descend at ${ms}ms');
        expect(f.open, inInclusiveRange(0, 1), reason: 'open at ${ms}ms');
        expect(f.ejected, inInclusiveRange(0, 1), reason: 'ejected at ${ms}ms');
      }
    });

    test('every stage is reached exactly in order', () {
      // Guards against a milestone typo silently skipping a step — which is
      // how `scan` and `carry` went missing in the first place.
      final seen = <ClawStage>[];
      for (var ms = 0; ms <= _grab; ms += 5) {
        final s = ClawGrabTimeline.frameAt(_at(ms)).stage;
        if (seen.isEmpty || seen.last != s) seen.add(s);
      }
      expect(seen, ClawStage.values);
    });

    test('out-of-range t does not throw or escape the range', () {
      for (final t in [-1.0, -0.001, 1.001, 2.0]) {
        final f = ClawGrabTimeline.frameAt(t);
        expect(f.open, inInclusiveRange(0, 1));
        expect(f.descend, inInclusiveRange(0, 1));
      }
    });

    test('the descent is monotonic', () {
      // Overshoot here would read as the claw bouncing off the glass floor.
      double prev = -1;
      for (var ms = 1280; ms <= 1900; ms += 10) {
        final d = ClawGrabTimeline.frameAt(_at(ms)).descend;
        expect(
          d,
          greaterThanOrEqualTo(prev - 0.0001),
          reason: 'dip at ${ms}ms',
        );
        prev = d;
      }
    });
  });
}
