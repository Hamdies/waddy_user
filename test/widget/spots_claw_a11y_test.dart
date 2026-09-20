import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw.dart';
import 'package:waddy_app/features/places/domain/spots_draw_fixtures.dart';
import 'package:waddy_app/features/places/screens/spots_claw_draw_screen.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_cabinet.dart';
import 'package:waddy_app/util/dimensions.dart';

/// `CLAW-13` — the accessibility claims, asserted rather than assumed.
///
/// Each of these corresponds to a line in §6 of the plan. They are cheap to
/// write alongside the feature and nearly impossible to retrofit, because by
/// then the thing they constrain has shipped.
Widget _host(SpotsDraw draw, {bool reduce = false, double scale = 1.0}) {
  return GetMaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduce,
        textScaler: TextScaler.linear(scale),
      ),
      child: SpotsClawDrawScreen(draw: draw, zoneName: 'Maadi', week: 27),
    ),
  );
}

Future<void> _pump(
  WidgetTester t,
  SpotsDraw draw, {
  bool reduce = false,
  double scale = 1.0,
  double width = 430,
}) async {
  t.view.physicalSize = Size(width, 932);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(_host(draw, reduce: reduce, scale: scale));
  await t.pump();
}

SpotsDraw get _draw => SpotsDrawFixtures.threePulls;

void main() {
  group('semantics', () {
    testWidgets('the cabinet is excluded from the tree', (t) async {
      await _pump(t, _draw, reduce: true);

      // Decorative: every identity inside it is repeated below as real text.
      // Without this a screen reader walks a pile of unlabelled circles.
      expect(
        find.ancestor(
          of: find.byType(ClawCabinet),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a winner row reads as one labelled node', (t) async {
      // `addTearDown` is too late: the framework verifies that every
      // SemanticsHandle was disposed *before* tear-downs run. So the dispose
      // has to be inside the test body, and a `try/finally` is what keeps a
      // failing expect from leaving the handle open.
      final handle = t.ensureSemantics();
      try {
        await _pump(t, _draw, reduce: true);

        await t.tap(find.text('SPOTS_CLAW_CTA_READY'));
        // Reduced motion, so the run resolves in one frame — but the rows only
        // exist once it has.
        await t.pumpAndSettle();

        // The row's own label replaces its four child texts, so the reader says
        // one sentence instead of "1", "Farida N.", "@faridaaa", "14 votes".
        // The label is lowercase where the visible text is uppercased: it goes
        // through `trParams` only, never `displayCaps`, because a screen reader
        // spelling out "S-P-O-T-S" would be its own bug.
        expect(
          find.bySemanticsLabel(RegExp('spots_claw_winner_a11y')),
          findsWidgets,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('announcements fire for the phase and each winner', (t) async {
      final announcements = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      // `SemanticsService.sendAnnouncement` goes out over the accessibility
      // channel; intercepting it is the only way to prove the screen actually
      // speaks rather than merely intending to.
      messenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        (dynamic message) async {
          if (message is Map && message['type'] == 'announce') {
            announcements.add('${message['data']?['message']}');
          }
          return null;
        },
      );
      addTearDown(
        () => messenger.setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
      );

      await _pump(t, _draw);
      await t.tap(find.text('SPOTS_CLAW_CTA_READY'));
      await t.pumpAndSettle();

      // One "picking", then one per winner. Announcements are spoken, not
      // displayed, so they never go through `displayCaps` — the raw key stays
      // lowercase here where the on-screen labels are uppercased.
      expect(announcements.length, greaterThanOrEqualTo(4));
      expect(announcements.first, contains('announce_picking'));
      expect(
        announcements.where((a) => a.contains('announce_winner')).length,
        3,
      );
    });
  });

  group('reduced motion', () {
    testWidgets('the screen is fully usable with every animation off', (
      t,
    ) async {
      await _pump(t, _draw, reduce: true);

      await t.tap(find.text('SPOTS_CLAW_CTA_READY'));
      await t.pump();

      // The result is server-decided, so nothing is lost by skipping the show.
      //
      // The finished state offers a real action rather than a dead "that's
      // the draw" label — this fixture's user does not win, so the button
      // sends them back to vote. (Asserted against `_CTA_DONE` until this
      // was noticed: that key was removed when the label became an action,
      // so the check had been failing against a string nothing renders.)
      expect(find.text('SPOTS_CLAW_CTA_VOTE_AGAIN'), findsOneWidget);
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('nothing animates before the draw is started either', (
      t,
    ) async {
      await _pump(t, _draw, reduce: true);
      await t.pump(const Duration(seconds: 1));
      expect(t.binding.transientCallbackCount, 0);
    });
  });

  group('touch targets', () {
    testWidgets('the CTA meets the minimum tap target', (t) async {
      await _pump(t, _draw, reduce: true);

      final size = t.getSize(find.text('SPOTS_CLAW_CTA_READY').first);
      // The label is inside a 52pt row; assert on the tappable ancestor.
      expect(size.height, lessThanOrEqualTo(Dimensions.minTapTarget));

      final cta = t.getSize(
        find
            .ancestor(
              of: find.text('SPOTS_CLAW_CTA_READY'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(cta.height, greaterThanOrEqualTo(Dimensions.minTapTarget));
    });

  });

  group('text scale', () {
    testWidgets('the whole screen survives 2.0 at 320px', (t) async {
      await _pump(t, _draw, reduce: true, scale: 2.0, width: 320);
      expect(t.takeException(), isNull);
    });

    testWidgets('a run at 2.0 completes without overflow', (t) async {
      await _pump(t, _draw, scale: 2.0, width: 320);
      await t.tap(find.text('SPOTS_CLAW_CTA_READY'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('an 18-entrant overflow round holds at 2.0', (t) async {
      await _pump(
        t,
        SpotsDrawFixtures.overflow,
        reduce: true,
        scale: 2.0,
        width: 320,
      );
      expect(t.takeException(), isNull);
    });
  });

  group('RTL', () {
    // GetX holds the locale in global state, so an Arabic test poisons every
    // test that runs after it: `displayCaps` stops uppercasing and the LTR
    // finders silently stop matching. `Get.updateLocale` pumps a frame, so it
    // cannot live in `setUp`/`tearDown` ("inTest is not true") — the reset
    // goes in the test body instead, via `addTearDown` on the binding that is
    // already running.
    testWidgets('renders right-to-left without overflow', (t) async {
      addTearDown(() => Get.locale = const Locale('en', 'US'));
      t.view.physicalSize = const Size(430, 932);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(
        GetMaterialApp(
          locale: const Locale('ar', 'SA'),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SpotsClawDrawScreen(
                draw: _draw,
                zoneName: 'المعادي',
                week: 27,
              ),
            ),
          ),
        ),
      );
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('a full RTL run completes', (t) async {
      addTearDown(() => Get.locale = const Locale('en', 'US'));
      t.view.physicalSize = const Size(430, 932);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(
        GetMaterialApp(
          // The locale, not just the direction: `displayCaps` keys off the
          // script, so a bare `Directionality` still uppercases and would test
          // a combination no real user is ever in.
          locale: const Locale('ar', 'SA'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SpotsClawDrawScreen(draw: _draw, zoneName: 'المعادي'),
          ),
        ),
      );
      await t.pump();

      // Under Arabic, `displayCaps` deliberately leaves text uncased — Arabic
      // has no case, and `toUpperCase()` on it only ever mangles interpolated
      // Latin. So the label is the raw lowercase key here where the LTR tests
      // match an uppercased one. That difference is the behaviour working.
      await t.tap(find.text('spots_claw_cta_ready'));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(t.binding.transientCallbackCount, 0);
    });
  });

  group('the empty round', () {
    testWidgets('offers no pressable control at all', (t) async {
      await _pump(
        t,
        SpotsDraw.fromServer(entrants: const [], winnerIds: const []),
        reduce: true,
      );

      expect(find.text('SPOTS_CLAW_CTA_READY'), findsNothing);
      expect(find.text('SPOTS_CLAW_EMPTY_TITLE'), findsOneWidget);
    });

    testWidgets('a lone entrant still draws', (t) async {
      await _pump(
        t,
        SpotsDraw.fromServer(
          entrants: const [DrawEntrant(userId: 1, name: 'Solo V.', votes: 1)],
          winnerIds: const [1],
        ),
        reduce: true,
      );

      await t.tap(find.text('SPOTS_CLAW_CTA_READY'));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });
}
