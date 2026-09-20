import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/domain/spots_draw.dart';
import 'package:waddy_app/features/places/domain/spots_draw_fixtures.dart';
import 'package:waddy_app/features/places/screens/spots_claw_draw_screen.dart';

/// `CLAW-12` — every fixture, rendered and run to completion.
///
/// The fixtures exist to be looked at by a human with
/// `--dart-define=SPOTS_DRAW_PREVIEW=true`, but a case nobody opens is a case
/// nobody checks. Sweeping them here means the awkward-name round and the
/// backfilled period are exercised on every CI run rather than the day someone
/// remembers to preview them.
Widget _host(SpotsDraw draw, {double textScale = 1.0, bool reduce = false}) {
  return GetMaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduce,
      ),
      child: SpotsClawDrawScreen(draw: draw, zoneName: 'Maadi', week: 27),
    ),
  );
}

Future<void> _pump(
  WidgetTester t,
  SpotsDraw draw, {
  double width = 430,
  double textScale = 1.0,
  bool reduce = false,
}) async {
  t.view.physicalSize = Size(width, 932);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(_host(draw, textScale: textScale, reduce: reduce));
  await t.pump();
}

/// A winner, as the chute now shows them.
///
/// The "pulled by the claw" list was removed, so the prize chute is where a
/// pulled name lives. Its filled slots are the labelled semantics nodes, and
/// matching on those checks the name actually reached the screen rather than
/// just counting boxes.
Finder get _pulled => find.bySemanticsLabel(RegExp('spots_claw_winner_a11y'));

void main() {
  test('the preview flag is off unless compiled on', () {
    // The whole point of `bool.fromEnvironment` over a hand-edited const: this
    // cannot be committed as true by accident. If this ever fails, someone has
    // added a default and the fixtures are shipping.
    expect(kSpotsDrawPreview, isFalse);
  });

  group('every fixture renders', () {
    for (final entry in SpotsDrawFixtures.all.entries) {
      testWidgets('${entry.key} — at rest', (t) async {
        await _pump(t, entry.value, reduce: true);
        expect(t.takeException(), isNull);
      });

      testWidgets('${entry.key} — at 320px and 2.0 scale', (t) async {
        await _pump(t, entry.value, width: 320, textScale: 2.0, reduce: true);
        expect(t.takeException(), isNull);
      });

      testWidgets('${entry.key} — runs to completion, no timers', (t) async {
        await _pump(t, entry.value);

        final cta = find.text('SPOTS_CLAW_CTA_READY');
        if (cta.evaluate().isEmpty) {
          // An empty round has no CTA — that is the correct behaviour, not a
          // skipped test.
          expect(entry.value.isEmpty, isTrue);
          return;
        }

        await t.tap(cta);
        await t.pumpAndSettle();

        expect(t.takeException(), isNull);
        expect(t.binding.transientCallbackCount, 0);
        expect(_pulled, findsNWidgets(entry.value.effectivePulls));
      });
    }
  });

  group('the cases only fixtures reach', () {
    testWidgets('awkward names survive a full run', (t) async {
      // Empty, whitespace-only, leading-space, very long, and Arabic — the
      // set that crashes the design's `ini()`.
      await _pump(t, SpotsDrawFixtures.awkwardNames);
      await t.tap(find.text('SPOTS_CLAW_CTA_READY'));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(_pulled, findsNWidgets(3));
    });

    testWidgets('a backfilled period renders with losers unknown', (t) async {
      final draw = SpotsDrawFixtures.backfilled;
      expect(draw.totalEntrants, isNull);

      await _pump(t, draw);
      await t.tap(find.text('SPOTS_CLAW_CTA_READY'));
      await t.pumpAndSettle();

      // Three winners, three entrants, no losers to console.
      expect(_pulled, findsNWidgets(3));
      expect(draw.displayTotal, 3);
      expect(t.takeException(), isNull);
    });

    testWidgets('a sampled pool states the true total, not the sample', (
      t,
    ) async {
      final draw = SpotsDrawFixtures.sampled;
      expect(draw.entrants.length, 60);
      expect(draw.displayTotal, 143);

      await _pump(t, draw, reduce: true);
      expect(t.takeException(), isNull);
    });

    testWidgets('the winning fixture offers the voucher', (t) async {
      // The route to a prize used to hang off a tappable winner row. With the
      // "pulled by the claw" list gone, the done-state CTA carries it — so
      // what is asserted is that a winner is still one tap from their
      // voucher, not which widget happens to own the tap.
      await _pump(t, SpotsDrawFixtures.iWon);
      await t.tap(find.text('SPOTS_CLAW_CTA_READY'));
      await t.pumpAndSettle();

      expect(find.text('SPOTS_CLAW_CTA_SEE_VOUCHER'), findsOneWidget);
    });

    testWidgets('the losing fixture never celebrates', (t) async {
      final draw = SpotsDrawFixtures.iLost;
      // `isMe` is set on an entrant, but there is no prize.
      expect(draw.entrants.any((e) => e.isMe), isTrue);
      expect(draw.iWon, isFalse);

      await _pump(t, draw);
      await t.tap(find.text('SPOTS_CLAW_CTA_READY'));
      await t.pumpAndSettle();

      // The result is the button now, not a panel below the machine.
      expect(find.text('SPOTS_CLAW_CONSOLATION_TITLE'), findsOneWidget);
      // No voucher on offer, and the second line carries the way back in.
      expect(find.text('SPOTS_CLAW_CTA_SEE_VOUCHER'), findsNothing);
      expect(find.text('SPOTS_CLAW_CTA_SUB_LOST'), findsOneWidget);
    });
  });

  group('the randomised fixture', () {
    test('is deterministic for a given seed', () {
      expect(
        SpotsDrawFixtures.randomised(7).winnerIds,
        SpotsDrawFixtures.randomised(7).winnerIds,
      );
    });

    test('differs between seeds', () {
      // Not a correctness claim — just proof the seed is actually threaded
      // through rather than ignored.
      final a = SpotsDrawFixtures.randomised(1).winnerIds;
      final b = SpotsDrawFixtures.randomised(999).winnerIds;
      expect(a, isNot(equals(b)));
    });
  });
}
