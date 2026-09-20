import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw_geometry.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_ball.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_cabinet.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_marquee.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_masthead.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_winner_row.dart';

/// Phase B of `docs/spots_claw_draw_plan.md` — `CLAW-05 … CLAW-09` at rest.
///
/// The design is a fixed 430px canvas and overflow is the most likely
/// regression, so every widget is pumped at the narrowest phone we support and
/// at 2.0 text scale. Translations are not loaded here, so `.tr` yields raw
/// keys — which are *longer* than most of the English copy and therefore a
/// slightly pessimistic layout test. That is the right direction to be wrong in.
///
/// This is the project's first `test/widget/` file.
DrawEntrant _e(
  int id,
  String name, {
  int votes = 3,
  int rank = 0,
  bool me = false,
}) => DrawEntrant(
  userId: id,
  name: name,
  handle: '@user$id',
  votes: votes,
  rank: rank,
  isMe: me,
);

List<DrawEntrant> _pool(int n) =>
    List.generate(n, (i) => _e(i + 1, 'Voter ${i + 1}'));

/// The three widths that matter: smallest supported phone, the design canvas,
/// and a large phone.
const _widths = <double>[320, 430, 480];

/// `GetMaterialApp`, not `MaterialApp`.
///
/// `Dimensions` resolves its type scale from `Get.context!` at static-init
/// time, so any widget reaching a `waddy*` text style through it throws a null
/// check under a plain `MaterialApp`. The `MediaQuery` sits *inside* the app so
/// it is the one the widgets actually read, rather than being replaced by the
/// app's own.
Widget _host(
  Widget child, {
  double textScale = 1.0,
  bool reduceMotion = false,
}) {
  return GetMaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  required double width,
  double textScale = 1.0,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = Size(width, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _host(child, textScale: textScale, reduceMotion: reduceMotion),
  );
  await tester.pump();
}

void main() {
  group('ClawCabinet', () {
    testWidgets('renders at rest with no overflow at every width', (t) async {
      for (final w in _widths) {
        await _pumpAt(
          t,
          ClawCabinet(entrants: _pool(12)),
          width: w,
          reduceMotion: true,
        );
        _expectNoOverflow(t, reason: 'overflow at ${w}px');
        expect(find.byType(ClawBall), findsNWidgets(12));
      }
    });

    testWidgets('renders at 1.3 and 2.0 text scale without overflow', (
      t,
    ) async {
      for (final scale in [1.3, 2.0]) {
        await _pumpAt(
          t,
          ClawCabinet(entrants: _pool(12)),
          width: 430,
          textScale: scale,
          reduceMotion: true,
        );
        _expectNoOverflow(t, reason: 'overflow at scale $scale');
      }
    });

    testWidgets('caps the pile at the slot count and states the rest', (
      t,
    ) async {
      await _pumpAt(
        t,
        ClawCabinet(entrants: _pool(40), totalEntrants: 143),
        width: 430,
        reduceMotion: true,
      );

      // 40 entrants, 12 slots — the cabinet draws exactly 12 and no more.
      //
      // The overflow count itself is no longer stated on the cabinet: the
      // rail strip's text was removed, and the pool size now lives on the CTA
      // ("+N more in the claw"), which this widget-level test cannot see.
      // What stays asserted here is the cabinet's own job — it caps the pile
      // rather than trying to draw forty circles.
      expect(
        find.byType(ClawBall),
        findsNWidgets(SpotsDrawGeometry.visibleSlots),
      );
    });

    testWidgets('draws everyone when the pool fits in the glass', (t) async {
      await _pumpAt(
        t,
        ClawCabinet(entrants: _pool(5), totalEntrants: 5),
        width: 430,
        reduceMotion: true,
      );
      expect(find.byType(ClawBall), findsNWidgets(5));
    });

    testWidgets('an empty round renders a cabinet, not an exception', (
      t,
    ) async {
      await _pumpAt(
        t,
        const ClawCabinet(entrants: []),
        width: 430,
        reduceMotion: true,
      );
      expect(find.byType(ClawCabinet), findsOneWidget);
      expect(find.byType(ClawBall), findsNothing);
    });

    testWidgets('the held ball leaves the pile', (t) async {
      await _pumpAt(
        t,
        ClawCabinet(entrants: _pool(12), heldEntrantId: 3),
        width: 430,
        reduceMotion: true,
      );
      // 11 in the pile + 1 in the jaws = 12 drawn, none duplicated.
      expect(find.byType(ClawBall), findsNWidgets(12));
    });

    testWidgets('every lighting mode paints', (t) async {
      for (final mode in ClawLighting.values) {
        await _pumpAt(
          t,
          ClawCabinet(entrants: _pool(12), lighting: mode),
          width: 430,
          reduceMotion: true,
        );
        _expectNoOverflow(t, reason: 'overflow in $mode');
      }
    });
  });

  group('ClawMasthead', () {
    testWidgets('renders and pulses without overflow', (t) async {
      for (final w in _widths) {
        await _pumpAt(
          t,
          const ClawMasthead(eyebrow: 'Maadi · Week 27 · Voter draw'),
          width: w,
        );
        _expectNoOverflow(t, reason: 'overflow at ${w}px');
      }
    });

    testWidgets('the wordmark scales down rather than clipping at 2.0', (
      t,
    ) async {
      await _pumpAt(
        t,
        const ClawMasthead(eyebrow: 'Maadi · Week 27 · Voter draw'),
        width: 320,
        textScale: 2.0,
      );
      _expectNoOverflow(t);
      expect(find.byType(FittedBox), findsWidgets);
    });

    testWidgets('a very long eyebrow ellipsises instead of overflowing', (
      t,
    ) async {
      await _pumpAt(
        t,
        const ClawMasthead(
          eyebrow:
              'A zone name long enough to break a nowrap layout twice over',
        ),
        width: 320,
        textScale: 1.6,
      );
      _expectNoOverflow(t);
    });

    testWidgets('no pending timers after unmount while pulsing', (t) async {
      await _pumpAt(
        t,
        const ClawMasthead(eyebrow: 'Maadi · Week 27'),
        width: 430,
      );
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpWidget(const SizedBox.shrink());
      // Fails loudly if the pulse controller outlives the widget.
      expect(t.binding.transientCallbackCount, 0);
    });
  });

  group('ClawMarquee', () {
    testWidgets('holds static under reduced motion', (t) async {
      await _pumpAt(t, const ClawMarquee(), width: 430, reduceMotion: true);
      expect(t.binding.transientCallbackCount, 0);
      _expectNoOverflow(t);
    });

    testWidgets('stops when told it is off-screen', (t) async {
      await _pumpAt(t, const ClawMarquee(running: true), width: 430);
      await t.pump(const Duration(milliseconds: 200));

      await t.pumpWidget(_host(const ClawMarquee(running: false)));
      await t.pump();
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('disposes cleanly mid-scroll', (t) async {
      await _pumpAt(t, const ClawMarquee(), width: 430);
      await t.pump(const Duration(seconds: 2));
      await t.pumpWidget(const SizedBox.shrink());
      expect(t.binding.transientCallbackCount, 0);
    });
  });

  group('ClawWinnerRow', () {
    testWidgets('renders at every width and scale without overflow', (t) async {
      for (final w in _widths) {
        await _pumpAt(
          t,
          ClawWinnerRow(entrant: _e(1, 'Farida Nabil', votes: 14, rank: 1)),
          width: w,
          textScale: 2.0,
          reduceMotion: true,
        );
        _expectNoOverflow(t, reason: 'overflow at ${w}px');
      }
    });

    testWidgets('a long name ellipsises', (t) async {
      await _pumpAt(
        t,
        ClawWinnerRow(
          entrant: _e(1, 'Abdelrahman Mohamed Abdelaziz Elsayed', rank: 1),
        ),
        width: 320,
        textScale: 1.5,
        reduceMotion: true,
      );
      _expectNoOverflow(t);
    });

    testWidgets('an empty name falls back rather than rendering blank', (
      t,
    ) async {
      await _pumpAt(
        t,
        ClawWinnerRow(entrant: _e(1, '', rank: 1)),
        width: 430,
        reduceMotion: true,
      );
      expect(find.text('spots_a_waddi_voter'), findsOneWidget);
    });

    testWidgets('only a tappable row exposes a chevron', (t) async {
      await _pumpAt(
        t,
        ClawWinnerRow(entrant: _e(1, 'Farida N.', rank: 1)),
        width: 430,
        reduceMotion: true,
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      await _pumpAt(
        t,
        ClawWinnerRow(
          entrant: _e(1, 'Farida N.', rank: 1, me: true),
          onTap: () {},
        ),
        width: 430,
        reduceMotion: true,
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('a tappable row fires once', (t) async {
      var taps = 0;
      await _pumpAt(
        t,
        ClawWinnerRow(
          entrant: _e(1, 'Farida N.', rank: 1, me: true),
          onTap: () => taps++,
        ),
        width: 430,
        reduceMotion: true,
      );

      await t.tap(find.byType(ClawWinnerRow));
      await t.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('ClawBall', () {
    testWidgets('a degenerate name does not crash the ball', (t) async {
      for (final name in ['', '   ', 'X', 'فريدة نبيل']) {
        await _pumpAt(
          t,
          ClawBall(entrant: _e(1, name), index: 0),
          width: 430,
          reduceMotion: true,
        );
        expect(find.byType(ClawBall), findsOneWidget);
      }
    });

    testWidgets('a photo renders instead of initials', (t) async {
      await _pumpAt(
        t,
        const ClawBall(
          entrant: DrawEntrant(
            userId: 1,
            name: 'Farida Nabil',
            image: 'https://cdn.waddi.test/u/1.jpg',
          ),
          index: 0,
        ),
        width: 430,
        reduceMotion: true,
      );

      // The face is the point of the screen; the monogram is the fallback.
      expect(find.text('FN'), findsNothing);
      expect(find.byType(ClipOval), findsOneWidget);
    });

    testWidgets('no photo falls back to initials', (t) async {
      for (final none in [null, '', '   ']) {
        await _pumpAt(
          t,
          ClawBall(
            entrant: DrawEntrant(userId: 1, name: 'Farida Nabil', image: none),
            index: 0,
          ),
          width: 430,
          reduceMotion: true,
        );
        expect(find.text('FN'), findsOneWidget, reason: 'for \'$none\'');
      }
    });

    testWidgets('the lost variant shows its badge', (t) async {
      await _pumpAt(
        t,
        ClawBall(
          entrant: _e(1, 'Farida N.'),
          index: 0,
          state: ClawBallState.lost,
        ),
        width: 430,
        reduceMotion: true,
      );
      expect(find.text('😢'), findsOneWidget);
    });

    testWidgets('initials do not grow with text scale', (t) async {
      // The ball is a fixed circle; initials that scaled would spill out of it.
      await _pumpAt(
        t,
        ClawBall(entrant: _e(1, 'Farida Nabil'), index: 0),
        width: 430,
        textScale: 3.0,
        reduceMotion: true,
      );
      _expectNoOverflow(t);
    });
  });
}

/// Asserts the last pump reported no layout overflow.
///
/// Flutter surfaces a `RenderFlex` overflow as a *caught* framework exception,
/// not a thrown one: a bare `pumpWidget` passes happily over a yellow-striped
/// screen. `takeException()` is the only thing that actually sees it, so every
/// layout claim in this file goes through here.
void _expectNoOverflow(WidgetTester tester, {String? reason}) {
  expect(tester.takeException(), isNull, reason: reason);
}
