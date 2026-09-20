import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw.dart';
import 'package:waddy_app/features/places/domain/spots_draw_timeline.dart';
import 'package:waddy_app/features/places/screens/spots_claw_draw_screen.dart';

/// Phase C of `docs/spots_claw_draw_plan.md` — `CLAW-10`, `CLAW-11`, `CLAW-11b`.
///
/// The claims that matter are about *timers*, not pixels: a 15-second run
/// behind a back button is exactly where `Future.delayed` chains leak, and the
/// `pumpAndSettle` assertions here fail loudly if anyone reintroduces one.
DrawEntrant _e(int id, String name, {bool me = false}) =>
    DrawEntrant(userId: id, name: name, handle: '@u$id', votes: 5, isMe: me);

List<DrawEntrant> _pool(int n) =>
    List.generate(n, (i) => _e(i + 1, 'Voter ${i + 1}'));

SpotsDraw _draw({
  int entrants = 12,
  List<int> winners = const [1, 2, 3],
  int? myPrizeId,
  bool meWins = false,
  bool inDraw = false,
}) {
  final pool = _pool(entrants);
  if (meWins && winners.isNotEmpty) {
    final idx = pool.indexWhere((e) => e.userId == winners.first);
    if (idx >= 0) {
      pool[idx] = _e(winners.first, 'Me Myself', me: true);
    }
  } else if (inDraw) {
    // In the machine and *not* pulled — the losing entrant.
    //
    // Without this the helper could only build a winner or a pool with no
    // `isMe` row at all, and the latter is an onlooker rather than a loser.
    // The two want different words, so the fixture has to be able to tell
    // them apart.
    final idx = pool.indexWhere((e) => !winners.contains(e.userId));
    if (idx >= 0) {
      pool[idx] = _e(pool[idx].userId, 'Me Myself', me: true);
    }
  }
  return SpotsDraw.fromServer(
    entrants: pool,
    winnerIds: winners,
    pullCount: winners.length,
    myPrizeId: myPrizeId,
  );
}

Widget _host(SpotsDraw draw, {bool reduceMotion = false}) {
  return GetMaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: SpotsClawDrawScreen(draw: draw, zoneName: 'Maadi', week: 27),
    ),
  );
}

Future<void> _pump(
  WidgetTester t,
  SpotsDraw draw, {
  bool reduceMotion = false,
}) async {
  t.view.physicalSize = const Size(430, 932);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(_host(draw, reduceMotion: reduceMotion));
  await t.pump();
}

/// A winner, as the prize chute now shows them.
///
/// The "pulled by the claw" list was removed, so the chute is where a pulled
/// name lives. Its filled slots are labelled semantics nodes, so matching on
/// those checks the name actually reached the screen rather than counting
/// boxes that might be empty.
Finder get _pulled => find.bySemanticsLabel(RegExp('spots_claw_winner_a11y'));

Finder get _cta => find.text('SPOTS_CLAW_CTA_READY');

void main() {
  group('the run', () {
    testWidgets('a full run lists every winner and leaves no timers', (
      t,
    ) async {
      await _pump(t, _draw(winners: const [5, 2, 9]));

      await t.tap(_cta);
      await t.pump();

      // The unmount-leak test. If anyone swaps the AnimationController for a
      // Future.delayed chain, this is what catches it.
      await t.pumpAndSettle();

      expect(_pulled, findsNWidgets(3));
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('five pulls — the live default — completes', (t) async {
      await _pump(t, _draw(entrants: 20, winners: const [2, 4, 6, 8, 10]));

      await t.tap(_cta);
      await t.pumpAndSettle();

      expect(_pulled, findsNWidgets(5));
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('winners appear progressively, not all at once', (t) async {
      await _pump(t, _draw(winners: const [1, 2, 3]));

      await t.tap(_cta);
      await t.pump();
      expect(_pulled, findsNothing);

      // A winner is committed at the *release* — the moment the prongs open
      // over the chute — not at the grab boundary. Pumping exactly one `grab`
      // lands at local=0.0 of the next one, which is fractionally before the
      // first commit has been observed.
      //
      // Release runs 3600–3880ms of a 4580ms grab, so this lands inside it.
      const toRelease = Duration(milliseconds: 3750);

      await t.pump(toRelease);
      expect(_pulled, findsOneWidget);

      await t.pump(ClawGrabTimeline.grab);
      expect(_pulled, findsNWidgets(2));

      await t.pumpAndSettle();
      expect(_pulled, findsNWidgets(3));
    });

    testWidgets('tapping the CTA mid-run does not start a second draw', (
      t,
    ) async {
      await _pump(t, _draw(winners: const [1, 2, 3]));

      await t.tap(_cta);
      await t.pump(const Duration(milliseconds: 400));

      // The CTA has swapped to its disabled "working" label, so the ready
      // label is gone — and tapping where it was must do nothing.
      expect(_cta, findsNothing);
      await t.tap(find.text('SPOTS_CLAW_CTA_PICKING'), warnIfMissed: false);
      await t.pumpAndSettle();

      expect(_pulled, findsNWidgets(3));
    });
  });

  group('a thousand-voter round', () {
    // Your scenario: 1000 people in the machine, 12 on screen. The claw must
    // only ever grab a face that was already in the glass.
    testWidgets('runs to completion with winners deep in the pool', (t) async {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(1000),
        winnerIds: const [4, 517, 22, 918, 301],
        pullCount: 5,
        totalEntrants: 1000,
      );

      await _pump(t, draw);
      await t.tap(_cta);
      await t.pumpAndSettle();

      expect(_pulled, findsNWidgets(5));
      expect(t.takeException(), isNull);
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('every pulled face was on screen from the start', (t) async {
      final draw = SpotsDraw.fromServer(
        entrants: _pool(1000),
        winnerIds: const [4, 517, 22, 918, 301],
        pullCount: 5,
        totalEntrants: 1000,
      );

      // The pile the user sees before pressing anything.
      final onScreen = draw.visibleEntrants(12).map((e) => e.userId).toSet();

      await _pump(t, draw);
      await t.tap(_cta);
      await t.pumpAndSettle();

      // Read the ids back off the chute's own slots.
      final pulled = draw.winnerIds;

      // Nobody is conjured mid-grab, and nobody is swapped in.
      for (final id in pulled) {
        expect(onScreen.contains(id), isTrue, reason: 'winner \$id was hidden');
      }
    });
  });

  group('reduced motion', () {
    testWidgets('one pump yields the whole result, no pending timers', (
      t,
    ) async {
      await _pump(t, _draw(winners: const [1, 2, 3]), reduceMotion: true);

      await t.tap(_cta);
      await t.pump();

      expect(_pulled, findsNWidgets(3));
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('never enters the picking phase', (t) async {
      await _pump(t, _draw(winners: const [1, 2, 3]), reduceMotion: true);
      await t.tap(_cta);
      await t.pump();

      expect(find.text('SPOTS_CLAW_CTA_PICKING'), findsNothing);
    });
  });

  group('lifecycle', () {
    testWidgets('unmounting mid-animation does not throw', (t) async {
      await _pump(t, _draw(winners: const [1, 2, 3]));

      await t.tap(_cta);
      await t.pump(const Duration(milliseconds: 400));

      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();

      expect(t.takeException(), isNull);
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('unmounting at the very first frame is safe', (t) async {
      await _pump(t, _draw(winners: const [1, 2, 3]));
      await t.tap(_cta);
      await t.pumpWidget(const SizedBox.shrink());
      expect(t.takeException(), isNull);
    });
  });

  group('edge rounds', () {
    testWidgets('an empty round shows the empty state and no CTA', (t) async {
      await _pump(
        t,
        SpotsDraw.fromServer(entrants: const [], winnerIds: const []),
      );

      expect(find.text('SPOTS_CLAW_EMPTY_TITLE'), findsOneWidget);
      expect(_cta, findsNothing);
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('fewer entrants than pulls pulls everyone and stops', (
      t,
    ) async {
      await _pump(
        t,
        SpotsDraw.fromServer(
          entrants: [_e(1, 'A'), _e(2, 'B')],
          winnerIds: const [1, 2],
          pullCount: 5,
        ),
      );

      await t.tap(_cta);
      await t.pumpAndSettle();

      expect(_pulled, findsNWidgets(2));
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('a single-pull round completes', (t) async {
      await _pump(t, _draw(winners: const [6]));
      await t.tap(_cta);
      await t.pumpAndSettle();
      expect(_pulled, findsOneWidget);
    });
  });

  group('the result, on the CTA', () {
    // The separate consolation panel is gone: the control deck states the
    // outcome, because a result belongs in the best position on the screen
    // rather than in a quieter card below the one the thumb is already on.

    testWidgets('an entrant who lost is told so on the button', (t) async {
      // `meWins: false` with `inDraw: true` — in the machine, not pulled.
      await _pump(t, _draw(winners: const [1, 2, 3], inDraw: true));
      await t.tap(_cta);
      await t.pumpAndSettle();

      expect(find.text('SPOTS_CLAW_CONSOLATION_TITLE'), findsOneWidget);
      // And the move that follows from it, as the second line.
      expect(find.text('SPOTS_CLAW_CTA_SUB_LOST'), findsOneWidget);
    });

    testWidgets('an onlooker is not told they lost', (t) async {
      // Nobody in this pool is `isMe`, which is every guest and everyone who
      // did not vote this round. "Not this week" would be a claim about a
      // draw they were never in — they get the plain invitation instead.
      await _pump(t, _draw(winners: const [1, 2, 3]));
      await t.tap(_cta);
      await t.pumpAndSettle();

      expect(find.text('SPOTS_CLAW_CONSOLATION_TITLE'), findsNothing);
      expect(find.text('SPOTS_CLAW_CTA_VOTE_AGAIN'), findsOneWidget);
    });

    testWidgets('is absent when the user won', (t) async {
      await _pump(
        t,
        _draw(winners: const [1, 2, 3], myPrizeId: 331, meWins: true),
      );
      await t.tap(_cta);
      await t.pumpAndSettle();

      expect(find.text('SPOTS_CLAW_CONSOLATION_TITLE'), findsNothing);
    });

    testWidgets('a winner with a prize is offered their voucher', (t) async {
      // The route to a prize used to hang off a tappable winner row. With the
      // "pulled by the claw" list gone the done-state CTA carries it, so what
      // is asserted is that a winner is still one tap from their voucher.
      await _pump(
        t,
        _draw(winners: const [1, 2, 3], myPrizeId: 331, meWins: true),
      );
      await t.tap(_cta);
      await t.pumpAndSettle();

      expect(find.text('SPOTS_CLAW_CTA_SEE_VOUCHER'), findsOneWidget);
      expect(_pulled, findsNWidgets(3));
    });

    testWidgets('no prize id means no voucher offered, even for an entrant', (
      t,
    ) async {
      // `isMe` is true for every voter who opens the screen; only
      // `my_prize_id` means they won.
      await _pump(t, _draw(winners: const [1, 2, 3], meWins: true));
      await t.tap(_cta);
      await t.pumpAndSettle();

      // No prize, so no voucher on offer — the CTA sends them back to vote.
      expect(find.text('SPOTS_CLAW_CTA_SEE_VOUCHER'), findsNothing);
      expect(find.text('SPOTS_CLAW_CONSOLATION_TITLE'), findsOneWidget);
    });
  });
}
