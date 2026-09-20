import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw.dart';
import 'package:waddy_app/features/places/domain/spots_draw_demo.dart';
import 'package:waddy_app/features/places/domain/spots_draw_geometry.dart';

/// Phase A of `docs/spots_claw_draw_plan.md` — `CLAW-01`, `CLAW-03`.
///
/// The state machine is where this screen's correctness lives. The animation
/// can only ever be wrong in ways a user shrugs at; the pull order, the
/// confetti gate and the initials getter can be wrong in ways that either
/// crash the screen or celebrate the wrong person.
///
/// The `initials` group is the design's crash set: its `ini()` does
/// `n.split(" ")` then `w[0][0]` and throws on inputs the backend really
/// sends.
DrawEntrant _e(int id, String name, {int votes = 0, bool isMe = false}) =>
    DrawEntrant(userId: id, name: name, votes: votes, isMe: isMe);

List<DrawEntrant> _pool(int n) =>
    List.generate(n, (i) => _e(i + 1, 'User ${i + 1}', votes: n - i));

void main() {
  group('DrawEntrant.initials', () {
    test('two words take first + last initial', () {
      expect(_e(1, 'Farida Nabil').initials, 'FN');
    });

    test('masked backend name ("Farida N.") works', () {
      expect(_e(1, 'Farida N.').initials, 'FN');
    });

    test('three words use first and last, not the middle', () {
      expect(_e(1, 'Mohamed Ali Hassan').initials, 'MH');
    });

    test('single word takes one letter', () {
      expect(_e(1, 'Farida').initials, 'F');
    });

    test('empty name falls back to ?', () {
      expect(_e(1, '').initials, '?');
    });

    test('whitespace-only name falls back to ?', () {
      expect(_e(1, '   ').initials, '?');
    });

    test('leading and trailing spaces are ignored', () {
      // A user with no f_name masks to " N." — a leading space is real.
      expect(_e(1, '  Farida Nabil  ').initials, 'FN');
      expect(_e(1, ' N.').initials, 'N');
    });

    test('collapsed inner whitespace does not create empty initials', () {
      expect(_e(1, 'Farida\t\tNabil').initials, 'FN');
    });

    test('Arabic name keeps its letters', () {
      expect(_e(1, 'فريدة نبيل').initials, 'فن');
    });
  });

  group('fromServer', () {
    test('replays the server order exactly, never a random one', () {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(12),
        winnerIds: const [7, 2, 11],
      );

      final run = draw.start().finish();
      expect(run.winners.map((w) => w.userId).toList(), [7, 2, 11]);
      expect(run.winners.map((w) => w.rank).toList(), [1, 2, 3]);
    });

    test('a winner id with no entrant row is dropped, not thrown on', () {
      // CLAW-Z4: a backfilled period has winners whose entrants were never
      // recorded. This must render, not crash.
      final draw = SpotsDraw.fromServer(
        entrants: [_e(1, 'A'), _e(2, 'B')],
        winnerIds: const [1, 999, 2],
      );

      expect(draw.winnerIds, [1, 2]);
      expect(draw.start().finish().winners.length, 2);
    });

    test('empty round goes straight to done, never to picking', () {
      final draw = SpotsDraw.fromServer(
        entrants: const [],
        winnerIds: const [],
      );

      expect(draw.isEmpty, isTrue);
      expect(draw.phase, DrawPhase.done);
      expect(draw.ctaEnabled, isFalse);
      expect(draw.start().phase, DrawPhase.done);
    });

    test('fewer entrants than pulls pulls all of them and terminates', () {
      final draw = SpotsDraw.fromServer(
        entrants: [_e(1, 'A'), _e(2, 'B')],
        winnerIds: const [1, 2],
        pullCount: 5,
      );

      expect(draw.effectivePulls, 2);
      final run = draw.start().finish();
      expect(run.winners.length, 2);
      expect(run.phase, DrawPhase.done);
    });

    test('pullCount clamps to the supported ceiling', () {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(30),
        winnerIds: const [1],
        pullCount: 99,
      );
      expect(draw.pullCount, SpotsDraw.maxPulls);
    });

    test('totalEntrants carries the true pool, not the sampled one', () {
      // CLAW-Z1 caps the stored pool; the copy must state the real number.
      final draw = SpotsDraw.fromServer(
        entrants: _pool(60),
        winnerIds: const [1],
        totalEntrants: 143,
      );
      expect(draw.displayTotal, 143);
    });

    test('displayTotal falls back to what we can see when null', () {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(12),
        winnerIds: const [1],
      );
      expect(draw.displayTotal, 12);
    });
  });

  group('phases', () {
    test('order is ready -> picking -> done', () {
      var draw = SpotsDraw.fromServer(
        entrants: _pool(12),
        winnerIds: const [1, 2],
      );
      expect(draw.phase, DrawPhase.ready);

      draw = draw.start();
      expect(draw.phase, DrawPhase.picking);

      draw = draw.pullNext();
      expect(draw.phase, DrawPhase.picking);

      draw = draw.pullNext();
      expect(draw.phase, DrawPhase.done);
    });

    test('CTA is disabled outside ready', () {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(12),
        winnerIds: const [1, 2],
      );

      expect(draw.ctaEnabled, isTrue);
      expect(draw.start().ctaEnabled, isFalse);
      expect(draw.start().finish().ctaEnabled, isFalse);
      expect(const SpotsDraw().ctaEnabled, isFalse);
    });

    test('a second start mid-run does not restart the draw', () {
      final started =
          SpotsDraw.fromServer(
            entrants: _pool(12),
            winnerIds: const [1, 2, 3],
          ).start().pullNext();

      final again = started.start();
      expect(again.winners.length, 1);
      expect(again.phase, DrawPhase.picking);
    });

    test('pullNext outside picking is a no-op', () {
      final ready = SpotsDraw.fromServer(
        entrants: _pool(12),
        winnerIds: const [1],
      );
      expect(ready.pullNext().winners, isEmpty);
    });

    test('pullNext past the last winner settles on done', () {
      var draw =
          SpotsDraw.fromServer(
            entrants: _pool(12),
            winnerIds: const [1],
          ).start();

      draw = draw.pullNext().pullNext().pullNext();
      expect(draw.phase, DrawPhase.done);
      expect(draw.winners.length, 1);
    });
  });

  group('a full run', () {
    test('never pulls the same entrant twice', () {
      var draw =
          SpotsDraw.fromServer(
            entrants: _pool(12),
            winnerIds: const [5, 1, 9, 3, 11],
          ).start();

      while (draw.phase == DrawPhase.picking) {
        draw = draw.pullNext();
      }

      final ids = draw.winners.map((w) => w.userId).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.length, 5);
    });

    test('five pulls — the live default, not the design 3', () {
      final draw =
          SpotsDraw.fromServer(
            entrants: _pool(20),
            winnerIds: const [2, 4, 6, 8, 10],
            pullCount: 5,
          ).start().finish();

      expect(draw.winners.length, 5);
      expect(draw.winners.map((w) => w.rank).toList(), [1, 2, 3, 4, 5]);
    });

    test('losers are everyone not pulled', () {
      final draw =
          SpotsDraw.fromServer(
            entrants: _pool(12),
            winnerIds: const [1, 2, 3],
          ).start().finish();

      expect(draw.losers.length, 9);
      expect(draw.losers.any((l) => l.userId == 1), isFalse);
    });

    test('finish matches a stepped run exactly', () {
      final base = SpotsDraw.fromServer(
        entrants: _pool(12),
        winnerIds: const [7, 2, 11, 4],
      );

      var stepped = base.start();
      while (stepped.phase == DrawPhase.picking) {
        stepped = stepped.pullNext();
      }
      final skipped = base.start().finish();

      expect(
        skipped.winners.map((w) => w.userId).toList(),
        stepped.winners.map((w) => w.userId).toList(),
      );
      expect(
        skipped.winners.map((w) => w.rank).toList(),
        stepped.winners.map((w) => w.rank).toList(),
      );
    });

    test('finish mid-run completes the remaining pulls', () {
      final draw =
          SpotsDraw.fromServer(
            entrants: _pool(12),
            winnerIds: const [7, 2, 11],
          ).start().pullNext().finish();

      expect(draw.winners.map((w) => w.userId).toList(), [7, 2, 11]);
      expect(draw.phase, DrawPhase.done);
    });
  });

  group('the confetti gate', () {
    test('no prize id means no celebration', () {
      final draw = SpotsDraw.fromServer(
        entrants: [_e(1, 'A'), _e(2, 'B', isMe: true)],
        winnerIds: const [1],
      );
      expect(draw.iWon, isFalse);
    });

    test('a prize id means the user won', () {
      final draw = SpotsDraw.fromServer(
        entrants: [_e(1, 'A', isMe: true), _e(2, 'B')],
        winnerIds: const [1],
        myPrizeId: 331,
      );
      expect(draw.iWon, isTrue);
    });

    test('being an entrant is not winning', () {
      // The trap: `isMe` is true for every voter who opens the screen.
      final draw =
          SpotsDraw.fromServer(
            entrants: [_e(1, 'A'), _e(2, 'Me', isMe: true)],
            winnerIds: const [1],
          ).start().finish();

      expect(draw.entrants.any((e) => e.isMe), isTrue);
      expect(draw.iWon, isFalse);
    });
  });

  group('the visible pile — every winner is in the glass', () {
    // The trap: a real round can have a thousand voters and the pile holds
    // twelve. If the claw reached for someone who was not already on screen,
    // the screen would have to conjure a thirteenth ball mid-grab or swap one
    // silently — and a user who screenshots the pile could prove it changed.
    // That reads as a rigged machine, which is the one accusation a prize draw
    // cannot survive.

    test('a thousand-entrant round still shows every winner', () {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(1000),
        // Winners scattered deep in the pool, well past the twelve slots.
        winnerIds: const [4, 517, 22, 918, 301],
      );

      final visible = draw.visibleEntrants(12).map((e) => e.userId).toSet();
      for (final id in draw.winnerIds) {
        expect(
          visible.contains(id),
          isTrue,
          reason: 'winner \$id not in glass',
        );
      }
      expect(visible.length, 12);
    });

    test('winners come first, losers fill the rest', () {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(1000),
        winnerIds: const [900, 901, 902],
      );

      final visible = draw.visibleEntrants(12);
      expect(visible.take(3).map((e) => e.userId).toList(), [900, 901, 902]);
      expect(visible.length, 12);
    });

    test('a payload in the wrong order is corrected, not trusted', () {
      // The backend sorts winners first, but ordering is not a guarantee —
      // a cache or a re-sort could undo it, and the failure would be silent.
      final reversed = _pool(50).reversed.toList();
      final draw = SpotsDraw.fromServer(
        entrants: reversed,
        winnerIds: const [1, 2, 3],
      );

      final visible = draw.visibleEntrants(12).map((e) => e.userId).toSet();
      expect(visible.containsAll([1, 2, 3]), isTrue);
    });

    test('a small round is returned untouched', () {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(5),
        winnerIds: const [3],
      );
      expect(draw.visibleEntrants(12).length, 5);
      expect(draw.visibleEntrants(12), draw.entrants);
    });

    test('more winners than slots still all fit', () {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(1000),
        winnerIds: const [1, 2, 3, 4, 5, 6, 7, 8],
        pullCount: 8,
      );
      final visible = draw.visibleEntrants(12).map((e) => e.userId).toSet();
      expect(visible.containsAll(draw.winnerIds), isTrue);
    });

    test('no entrant appears twice in the glass', () {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(1000),
        winnerIds: const [4, 517, 22],
      );
      final ids = draw.visibleEntrants(12).map((e) => e.userId).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('the overflow states the true pool, not the visible twelve', () {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(60),
        winnerIds: const [1],
        totalEntrants: 1000,
      );
      // 1000 in the machine, 12 on screen — the plate must say 988, so the
      // hidden 940 are acknowledged rather than pretended away.
      expect(SpotsDrawGeometry.overflowCount(draw.displayTotal), 988);
    });
  });

  group('pile geometry', () {
    test('slots are unique and inside the design box', () {
      for (var i = 0; i < SpotsDrawGeometry.visibleSlots; i++) {
        final slot = SpotsDrawGeometry.pileSlot(i);
        expect(slot.dx, inInclusiveRange(0, SpotsDrawGeometry.gridWidth));
        expect(slot.dy, inInclusiveRange(0, SpotsDrawGeometry.gridHeight));
        expect(
          slot.dx + SpotsDrawGeometry.ballSize,
          lessThanOrEqualTo(SpotsDrawGeometry.gridWidth),
        );
        expect(
          slot.dy + SpotsDrawGeometry.ballSize,
          lessThanOrEqualTo(SpotsDrawGeometry.gridHeight),
        );
      }
      expect(
        SpotsDrawGeometry.pile.toSet().length,
        SpotsDrawGeometry.pile.length,
      );
    });

    test('wraps past the twelfth entrant instead of running off the end', () {
      // The design hardcodes 12 voters into 12 slots and indexes directly.
      expect(SpotsDrawGeometry.pileSlot(12), SpotsDrawGeometry.pileSlot(0));
      expect(SpotsDrawGeometry.pileSlot(25), SpotsDrawGeometry.pileSlot(1));
      expect(() => SpotsDrawGeometry.pileSlot(999), returnsNormally);
    });

    test('a negative index does not throw', () {
      expect(SpotsDrawGeometry.pileSlot(-1), SpotsDrawGeometry.pile.first);
    });

    test('the claw stays inside the glass for every slot', () {
      for (var i = 0; i < SpotsDrawGeometry.visibleSlots; i++) {
        final x = SpotsDrawGeometry.clawXFor(i);
        expect(x, greaterThanOrEqualTo(SpotsDrawGeometry.ballSize / 2));
        expect(
          x,
          lessThanOrEqualTo(
            SpotsDrawGeometry.gridWidth - SpotsDrawGeometry.ballSize / 2,
          ),
        );
      }
    });

    test('overflow counts only what is hidden', () {
      expect(SpotsDrawGeometry.overflowCount(143), 131);
      expect(SpotsDrawGeometry.overflowCount(12), 0);
      expect(SpotsDrawGeometry.overflowCount(3), 0);
      expect(SpotsDrawGeometry.overflowCount(0), 0);
    });
  });

  group('SpotsDraw.local (fixtures only)', () {
    test('a seeded Random is deterministic', () {
      final a = SpotsDraw.local(entrants: _pool(12), random: Random(42));
      final b = SpotsDraw.local(entrants: _pool(12), random: Random(42));
      expect(a.winnerIds, b.winnerIds);
    });

    test('never picks the same entrant twice', () {
      final draw = SpotsDraw.local(
        entrants: _pool(12),
        pulls: 5,
        random: Random(7),
      );
      expect(draw.winnerIds.toSet().length, draw.winnerIds.length);
    });

    test('a pool smaller than the pull count drains without looping', () {
      final draw = SpotsDraw.local(
        entrants: _pool(2),
        pulls: 5,
        random: Random(1),
      );
      expect(draw.winnerIds.length, 2);
    });

    test('an empty pool terminates', () {
      final draw = SpotsDraw.local(entrants: const [], random: Random(1));
      expect(draw.winnerIds, isEmpty);
      expect(draw.phase, DrawPhase.done);
    });
  });

  /// The chute's end-of-run label is driven by this, and it is the one place
  /// the screen makes a claim *about the user* rather than about the machine.
  /// Getting it wrong means telling someone they lost a draw they never
  /// entered, or telling a winner they are not in it.
  group('outcome', () {
    SpotsDraw draw({required bool isMe, int? prize}) => SpotsDraw.fromServer(
      entrants: [
        _e(1, 'Nour E.', isMe: isMe),
        _e(2, 'Aya M.'),
        _e(3, 'Omar K.'),
      ],
      winnerIds: const [2],
      pullCount: 1,
      myPrizeId: prize,
    );

    test('a pulled entrant with a prize has won', () {
      final d = draw(isMe: true, prize: 42).finish();
      expect(d.iWon, isTrue);
      expect(d.iEntered, isTrue);
      expect(d.outcome, DrawOutcome.won);
    });

    test('an entrant with no prize has lost', () {
      final d = draw(isMe: true).finish();
      expect(d.iWon, isFalse);
      expect(d.iEntered, isTrue);
      expect(d.outcome, DrawOutcome.lost);
    });

    test('a guest is an onlooker, not a loser', () {
      // No `is_me` row at all — the endpoint only sets it on an authed
      // request, so this is every guest. Reporting "you're not in" here would
      // be a statement about a draw they never entered.
      final d = draw(isMe: false).finish();
      expect(d.iEntered, isFalse);
      expect(d.outcome, DrawOutcome.onlooker);
    });
  });

  /// The chute slot is ~56pt wide and the server does not bound the first
  /// name, so this is what keeps a long name from ellipsizing away the
  /// initial that distinguishes two people with the same first name.
  group('shortName', () {
    test('a name that fits is untouched', () {
      expect(_e(1, 'Hassan B.').shortName, 'Hassan B.');
    });

    test('a long first name keeps the initial', () {
      // The bug this exists for: "Mariam ..." dropped the "A." entirely.
      expect(_e(1, 'Mariam Abdelrahman').shortName, 'Mariam A.');
    });

    test('an unmasked full name is reduced to first plus initial', () {
      expect(
        _e(1, 'Abdelrahman Mohamed Abdelaziz Elsayed').shortName,
        'Abdelrah… E.',
      );
    });

    test('a single long word is clamped, not crashed', () {
      expect(_e(1, 'Bartholomewwwwwwwwwwwww').shortName, 'Bartholomew…');
    });

    test('degenerate names do not throw', () {
      expect(_e(1, '').shortName, '');
      expect(_e(1, '   ').shortName, '');
      expect(_e(1, ' N.').shortName, 'N.');
    });

    test('a name outside the BMP is not sliced mid-surrogate', () {
      final s = _e(1, '${'😀' * 14} K.').shortName;
      // The test that matters: what comes back is still valid text, and the
      // clamp counted characters rather than code units.
      expect(s.runes.length, lessThan(22));
      expect(s.endsWith('K.'), isTrue);
    });
  });

  /// The debug entry points on the prizes screen.
  ///
  /// These exist to let a build be judged by eye, which only works if the
  /// button labelled WIN produces a win. It did not: with no prize row on the
  /// account it fell through to `losing()`, so WIN showed the losing screen —
  /// no confetti, no win sting, "not this week" on the CTA.
  group('the demo builders', () {
    test('WIN produces a win, with the user as pull #1', () {
      final d = SpotsDrawDemo.winning(myName: 'Ahmed').finish();
      expect(d.outcome, DrawOutcome.won);
      expect(d.winnerIds.first, -1);
      // No real voucher behind a demo win, so the CTA must not offer to open
      // one — see `hasVoucher`.
      expect(d.hasVoucher, isFalse);
    });

    test('a real prize keeps its voucher route', () {
      expect(
        SpotsDraw.fromServer(
          entrants: [_e(1, 'Me', isMe: true)],
          winnerIds: const [1],
          pullCount: 1,
          myPrizeId: 331,
        ).hasVoucher,
        isTrue,
      );
    });

    test('LOSE produces an entrant who lost, not an onlooker', () {
      final d = SpotsDrawDemo.losing(myName: 'Ahmed').finish();
      expect(d.outcome, DrawOutcome.lost);
      expect(d.iEntered, isTrue);
    });

    test('both pull the same number', () {
      // A WIN demo pulling five against a LOSE demo pulling three would be
      // comparing two different screens.
      expect(
        SpotsDrawDemo.winning().effectivePulls,
        SpotsDrawDemo.losing().effectivePulls,
      );
      expect(
        SpotsDrawDemo.winning().effectivePulls,
        SpotsDrawDemo.defaultPulls,
      );
    });
  });
}
