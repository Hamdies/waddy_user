import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/spots_draw_round_model.dart';
import 'package:waddy_app/features/places/domain/services/places_service_interface.dart';
import 'package:waddy_app/features/places/screens/spots_claw_draw_loader_screen.dart';
import 'package:waddy_app/features/places/screens/spots_claw_draw_screen.dart';
import 'package:waddy_app/features/places/widgets/claw_draw_entry_card.dart';

/// The two new ways into the claw: the loader a push or a voucher opens, and
/// the home card. Translations are not loaded, so `.tr` yields raw keys.

SpotsDrawRound _round({int? myPrizeId, bool empty = false}) =>
    SpotsDrawRound.fromJson({
      'data': {
        'period': '2026-W27',
        'place': {'id': 12, 'title': 'Koshary'},
        'pull_count': 1,
        'total_entrants': 3,
        'entrants':
            empty
                ? []
                : [
                  {'user_id': 1, 'name': 'Farida N.', 'votes': 4, 'rank': 1},
                  {'user_id': 2, 'name': 'Omar S.', 'votes': 2, 'rank': 0},
                ],
        'winner_ids': empty ? [] : [1],
        'my_prize_id': myPrizeId,
      },
    });

class _Service implements PlacesServiceInterface {
  ({SpotsDrawRound? round, int? statusCode}) next = (
    round: null,
    statusCode: 1,
  );
  int calls = 0;

  @override
  Future<({SpotsDrawRound? round, int? statusCode})> getDraw({
    String? period,
  }) async {
    calls++;
    return next;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GetMaterialApp(home: child));
}

void main() {
  late _Service service;
  late PlacesController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
    service = _Service();
    controller = Get.put(PlacesController(placesServiceInterface: service));
  });

  group('SpotsClawDrawLoaderScreen', () {
    testWidgets('a junk period never reaches the network', (tester) async {
      await _pump(tester, const SpotsClawDrawLoaderScreen(period: '9'));
      await tester.pump();

      expect(service.calls, 0);
      expect(find.text('SPOTS_CLAW_NOT_READY_TITLE'), findsOneWidget);
      expect(find.text('SPOTS_RETRY'), findsNothing);
    });

    testWidgets('a failure offers a retry, and the retry recovers', (
      tester,
    ) async {
      await _pump(tester, const SpotsClawDrawLoaderScreen(period: '2026-W27'));
      await tester.pump();

      expect(find.text('SPOTS_CLAW_LOAD_FAILED_TITLE'), findsOneWidget);

      service.next = (round: _round(), statusCode: 200);
      await tester.tap(find.text('SPOTS_RETRY'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, 2);
      expect(find.byType(SpotsClawDrawScreen), findsOneWidget);
      // Leave nothing running: the claw idles on a repeating sway.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a handed-over round plays without a round trip', (
      tester,
    ) async {
      await _pump(tester, SpotsClawDrawLoaderScreen(initialRound: _round()));
      await tester.pump();

      expect(service.calls, 0);
      expect(find.byType(SpotsClawDrawScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('ClawDrawEntryCard', () {
    Widget host() => const Scaffold(body: ClawDrawEntryCard());

    testWidgets('renders nothing before a round has a draw', (tester) async {
      await _pump(tester, host());
      expect(find.text('SPOTS_CLAW_WATCH_DRAW'), findsNothing);
    });

    testWidgets('renders nothing for a round nobody voted in', (tester) async {
      service.next = (round: _round(empty: true), statusCode: 200);
      await _pump(tester, host());
      await controller.getLatestDraw();
      await tester.pump();
      expect(find.text('SPOTS_CLAW_WATCH_DRAW'), findsNothing);
    });

    testWidgets('appears once the draw lands, and congratulates a winner', (
      tester,
    ) async {
      service.next = (round: _round(myPrizeId: 331), statusCode: 200);
      await _pump(tester, host());
      await controller.getLatestDraw();
      await tester.pump();

      expect(find.text('SPOTS_CLAW_WATCH_DRAW'), findsOneWidget);
      expect(find.text('SPOTS_CLAW_CARD_TITLE_WON'), findsOneWidget);
    });

    testWidgets('fits the narrowest phone at 2x text, LTR and RTL', (
      tester,
    ) async {
      service.next = (round: _round(), statusCode: 200);
      await controller.getLatestDraw();
      for (final dir in TextDirection.values) {
        tester.view.physicalSize = const Size(320, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          GetMaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Directionality(textDirection: dir, child: host()),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
