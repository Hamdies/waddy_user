import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/places/domain/models/place_prize_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw_demo.dart';

/// The debug launcher's padding helper.
///
/// Tested because it is the thing that will be judged: the screen gets looked
/// at through this, so if it pads wrong, the wrong screen gets approved. The
/// claims that matter are that the real prize survives the padding and that
/// the losing case genuinely cannot celebrate.
PlacePrize _prize({int id = 331}) => PlacePrize(
  id: id,
  period: '2026-W34',
  code: 'WD7K-3XQ2',
  status: 'active',
  placeId: 12,
  placeTitle: 'Cairo Coffee',
);

void main() {
  group('fromPrize — the real win', () {
    test('the user is pulled first and keeps their real prize id', () {
      final draw = SpotsDrawDemo.fromPrize(_prize(), myName: 'Ahmed H.');

      expect(draw.winnerIds.first, -1, reason: 'the user is winner #1');
      expect(draw.myPrizeId, 331, reason: 'routes to the genuine voucher');
      expect(draw.iWon, isTrue);
    });

    test('the machine is full enough to judge', () {
      final draw = SpotsDrawDemo.fromPrize(_prize());

      // Exactly fills the cabinet's 12 slots — every ball on screen is a real
      // entrant, and the ~1000 who did not fit are stated by the overflow
      // plate rather than faked as extra balls.
      expect(draw.entrants.length, 12);
      expect(draw.displayTotal, greaterThan(500));
      expect(draw.displayTotal, greaterThan(draw.entrants.length));
    });

    test('the user is the only real identity in it', () {
      final draw = SpotsDrawDemo.fromPrize(_prize(), myName: 'Ahmed H.');

      expect(draw.entrants.where((e) => e.isMe).length, 1);
      expect(draw.entrants.first.name, 'Ahmed H.');
      // Every padded id is negative, so a demo entrant can never collide with
      // or be mistaken for a real user id.
      expect(draw.entrants.every((e) => e.userId < 0), isTrue);
    });

    test('an empty name falls back rather than rendering blank', () {
      expect(
        SpotsDrawDemo.fromPrize(_prize(), myName: '   ').entrants.first.name,
        'You',
      );
      expect(SpotsDrawDemo.fromPrize(_prize()).entrants.first.name, 'You');
    });

    test('a full run pulls the user first, then fakes', () {
      final draw = SpotsDrawDemo.fromPrize(_prize()).start().finish();

      expect(draw.winners.first.isMe, isTrue);
      expect(draw.winners.first.rank, 1);
      expect(draw.winners.skip(1).every((w) => !w.isMe), isTrue);
      expect(draw.winners.length, 5);
    });

    test('no entrant is pulled twice', () {
      final draw = SpotsDrawDemo.fromPrize(_prize()).start().finish();
      final ids = draw.winners.map((w) => w.userId).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('the same seed gives the same draw', () {
      // Reproducible, so a screenshot can be compared against a later one.
      final a = SpotsDrawDemo.fromPrize(_prize(), seed: 5);
      final b = SpotsDrawDemo.fromPrize(_prize(), seed: 5);
      expect(a.winnerIds, b.winnerIds);
      expect(
        a.entrants.map((e) => e.name).toList(),
        b.entrants.map((e) => e.name).toList(),
      );
    });
  });

  group('losing — the half a winner never sees', () {
    test('the user is in the machine and never pulled', () {
      final draw = SpotsDrawDemo.losing(myName: 'Ahmed H.');

      expect(draw.entrants.any((e) => e.isMe), isTrue);
      expect(draw.winnerIds.contains(-1), isFalse);
    });

    test('there is nothing to celebrate', () {
      final draw = SpotsDrawDemo.losing();
      expect(draw.myPrizeId, isNull);
      expect(draw.iWon, isFalse);
    });

    test('after a full run the user is among the losers', () {
      final draw = SpotsDrawDemo.losing().start().finish();

      expect(draw.winners.any((w) => w.isMe), isFalse);
      expect(draw.losers.any((l) => l.isMe), isTrue);
      expect(draw.iWon, isFalse);
    });

    test('it still pulls a full set of winners', () {
      final draw = SpotsDrawDemo.losing().start().finish();
      expect(draw.winners.length, 5);
    });
  });

  group('padding never exceeds the name pool', () {
    test('asking for more entrants than names does not repeat or crash', () {
      final draw = SpotsDrawDemo.fromPrize(_prize(), entrants: 200);
      final names = draw.entrants.skip(1).map((e) => e.name).toList();

      expect(() => draw.start().finish(), returnsNormally);
      // Capped at the pool rather than cycling — a machine with four
      // "Farida N."s reads as broken, not full.
      expect(names.toSet().length, names.length);
    });

    test('a tiny machine still works', () {
      // `SpotsDraw` is immutable: `start().finish()` returns a new draw and
      // leaves the original untouched. Asserting on the pre-run object finds
      // an empty winners list — which is correct, and not what this is about.
      final run =
          SpotsDrawDemo.fromPrize(
            _prize(),
            entrants: 2,
            pulls: 5,
          ).start().finish();

      // Two entrants, five requested pulls: takes both and stops.
      expect(run.winners.length, 2);
      expect(run.winners.first.isMe, isTrue);
    });
  });
}
