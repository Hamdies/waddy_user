import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_prize_model.dart';
import 'package:waddy_app/features/places/domain/models/spots_draw_round_model.dart';
import 'package:waddy_app/features/places/domain/services/places_service_interface.dart';
import 'package:waddy_app/features/places/domain/spots_draw.dart';
import 'package:waddy_app/helper/notification_helper.dart';

/// The claw going live: the endpoint → service → controller → route chain
/// that `docs/spots_claw_draw_plan.md` §11.6 item 7 recorded as missing, plus
/// the prize-screen rebuild fix the winner's path runs through.

Map<String, dynamic> _payload({
  String period = '2026-W27',
  int? myPrizeId,
  bool meIn = false,
}) => {
  'success': true,
  'data': {
    'period': period,
    'place': {'id': 12, 'title': 'Koshary Abou Tarek', 'image': 'k.png'},
    'pull_count': 2,
    'total_entrants': 143,
    'entrants': [
      {'user_id': 88, 'name': 'Farida N.', 'votes': 14, 'rank': 1},
      {'user_id': 41, 'name': 'Omar S.', 'votes': 3, 'rank': 2},
      {'user_id': 7, 'name': 'Aya M.', 'votes': 2, 'rank': 0, 'is_me': meIn},
    ],
    'winner_ids': [88, 41],
    'my_prize_id': myPrizeId,
  },
};

class _DrawService implements PlacesServiceInterface {
  ({SpotsDrawRound? round, int? statusCode}) next = (
    round: null,
    statusCode: 1,
  );
  PlacePrizeList? prizes;
  final List<String?> periods = [];

  @override
  Future<({SpotsDrawRound? round, int? statusCode})> getDraw({
    String? period,
  }) async {
    periods.add(period);
    return next;
  }

  @override
  Future<PlacePrizeList?> getMyPrizes() async => prizes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlacePrize _prize(int id) => PlacePrize.fromJson({
  'id': id,
  'period': '2026-W27',
  'code': 'WD7K-3XQ$id',
  'status': 'active',
  'place': {'id': 12, 'title': 'Koshary'},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
  });

  group('SpotsDrawRound.fromJson', () {
    test('carries the champion venue and the week around the draw', () {
      final round = SpotsDrawRound.fromJson(_payload(myPrizeId: 331));
      expect(round.period, '2026-W27');
      expect(round.week, 27);
      expect(round.placeId, 12);
      expect(round.placeTitle, 'Koshary Abou Tarek');
      expect(round.draw.winnerIds, [88, 41]);
      expect(round.draw.displayTotal, 143);
      expect(round.draw.outcome, DrawOutcome.won);
    });

    test('accepts the bare data object as well as the envelope', () {
      final bare = _payload()['data'] as Map<String, dynamic>;
      final round = SpotsDrawRound.fromJson(bare);
      expect(round.placeTitle, 'Koshary Abou Tarek');
      expect(round.draw.entrants, hasLength(3));
    });

    test('a voter of the winning venue who was not pulled lost', () {
      final round = SpotsDrawRound.fromJson(_payload(meIn: true));
      expect(round.draw.outcome, DrawOutcome.lost);
    });

    test('a missing venue and a malformed period degrade to null', () {
      final round = SpotsDrawRound.fromJson({
        'data': {'period': '9', 'entrants': [], 'winner_ids': []},
      });
      expect(round.placeTitle, isNull);
      expect(round.week, isNull);
      expect(round.draw.isEmpty, isTrue);
    });

    test('only ISO-week periods may reach the request path', () {
      expect(SpotsDrawRound.isValidPeriod('2026-W27'), isTrue);
      expect(SpotsDrawRound.isValidPeriod('9'), isFalse);
      expect(SpotsDrawRound.isValidPeriod('2026-07'), isFalse);
      expect(SpotsDrawRound.isValidPeriod('../prizes/my'), isFalse);
      expect(SpotsDrawRound.isValidPeriod(null), isFalse);
    });
  });

  group('PlacesController.getLatestDraw', () {
    test('stores the last closed round and notifies the card', () async {
      final service = _DrawService()
        ..next = (round: SpotsDrawRound.fromJson(_payload()), statusCode: 200);
      final c = PlacesController(placesServiceInterface: service);
      var repaints = 0;
      c.addListenerId(PlacesController.idDraw, () => repaints++);

      await c.getLatestDraw();

      expect(c.latestDraw?.period, '2026-W27');
      expect(service.periods, [null]);
      expect(repaints, 1);
    });

    test('a failed refresh keeps the round already on screen', () async {
      final service = _DrawService()
        ..next = (round: SpotsDrawRound.fromJson(_payload()), statusCode: 200);
      final c = PlacesController(placesServiceInterface: service);
      await c.getLatestDraw();

      service.next = (round: null, statusCode: 1);
      await c.getLatestDraw(reload: true);

      expect(c.latestDraw, isNotNull);
    });

    test('a 404 means there is no draw, so the card goes away', () async {
      final service = _DrawService()
        ..next = (round: SpotsDrawRound.fromJson(_payload()), statusCode: 200);
      final c = PlacesController(placesServiceInterface: service);
      await c.getLatestDraw();

      service.next = (round: null, statusCode: 404);
      await c.getLatestDraw(reload: true);

      expect(c.latestDraw, isNull);
    });

    test('fetchDraw does not touch the home card', () async {
      final service = _DrawService()
        ..next = (round: SpotsDrawRound.fromJson(_payload()), statusCode: 200);
      final c = PlacesController(placesServiceInterface: service);

      final result = await c.fetchDraw(period: '2026-W20');

      expect(result.round, isNotNull);
      expect(service.periods, ['2026-W20']);
      expect(c.latestDraw, isNull);
    });
  });

  group('getMyPrizes reaches the prize screens', () {
    test('it notifies idPrizes, which the prize screens listen on', () async {
      final service = _DrawService()
        ..prizes = PlacePrizeList(active: [_prize(1)], history: const []);
      final c = PlacesController(placesServiceInterface: service);
      var repaints = 0;
      c.addListenerId(PlacesController.idPrizes, () => repaints++);

      await c.getMyPrizes();

      expect(repaints, greaterThanOrEqualTo(1));
      expect(c.activePrizes.single.id, 1);
    });

    test('a failed refresh does not erase the vouchers', () async {
      final service = _DrawService()
        ..prizes = PlacePrizeList(active: [_prize(1)], history: const []);
      final c = PlacesController(placesServiceInterface: service);
      await c.getMyPrizes();

      service.prizes = null;
      await c.getMyPrizes(reload: true);

      expect(c.activePrizes.single.id, 1);
    });
  });

  group('round-close push', () {
    test('spots_draw_ready opens the claw for its period', () {
      final body = NotificationHelper.convertNotification({
        'type': 'spots_draw_ready',
        'data_id': '2026-W27',
      });
      expect(body.notificationType, NotificationType.spots_draw);
      expect(body.period, '2026-W27');
    });

    test('the period survives the local-notification payload round trip', () {
      final body = NotificationBodyModel(
        notificationType: NotificationType.spots_draw,
        period: '2026-W27',
      );
      final back = NotificationBodyModel.fromJson(body.toJson());
      expect(back.notificationType, NotificationType.spots_draw);
      expect(back.period, '2026-W27');
    });
  });
}
