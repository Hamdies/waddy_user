import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/services/places_service_interface.dart';
import 'package:waddy_app/features/places/domain/spots_round.dart';

class _Board implements PlacesServiceInterface {
  List<Place> board = [];

  @override
  Future<PlaceList?> getLeaderboard({
    String? period,
    int? zoneId,
    int? limit,
    DataSourceEnum source = DataSourceEnum.client,
  }) async => PlaceList(places: board, totalSize: board.length, offset: 1);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Place _p(int id, int votes, double rating) =>
    Place(id: id, title: 'Spot $id', votesCount: votes, rating: rating);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpotsRound.lockAt', () {
    // Run under a DST zone to bite: `TZ=Africa/Cairo flutter test` (Egypt) or
    // `TZ=Europe/London`. In UTC it passes trivially.
    test('is always Monday 00:00 sharp, for every day of the year', () {
      for (int d = 0; d < 366; d++) {
        final now = DateTime(2026, 1, 1, 12).add(Duration(days: d));
        final lock = SpotsRound.lockAt(now);
        expect(lock.weekday, DateTime.monday, reason: '$now');
        expect(
          [lock.hour, lock.minute, lock.second],
          [0, 0, 0],
          reason: 'lock for $now landed at $lock',
        );
        expect(lock.isAfter(now), isTrue, reason: '$now');
      }
    });
  });

  group('rank movement', () {
    late _Board service;
    late PlacesController c;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      Get.reset();
      Get.put<SharedPreferences>(await SharedPreferences.getInstance());
      service = _Board();
      c = PlacesController(placesServiceInterface: service);
      Get.put<PlacesController>(c);
    });

    test('tied spots swapping list order do not show arrows', () async {
      service.board = [_p(1, 5, 4.0), _p(2, 3, 4.5), _p(3, 3, 4.0)];
      await c.getLeaderboard(reload: true);
      await c.refreshRankDeltas();

      // Same votes, tie-break by rating flips: 3 now sorts above 2.
      service.board = [_p(1, 5, 4.0), _p(2, 3, 3.0), _p(3, 3, 4.0)];
      c = PlacesController(placesServiceInterface: service);
      Get.put<PlacesController>(c);
      await c.getLeaderboard(reload: true);
      await c.refreshRankDeltas();

      expect(c.rankOf(2), 2);
      expect(c.rankOf(3), 2);
      expect(c.rankDeltaFor(2), 0);
      expect(c.rankDeltaFor(3), 0);
    });

    test('a spot that really overtakes another shows the climb', () async {
      service.board = [_p(1, 5, 4.0), _p(2, 3, 4.0)];
      await c.getLeaderboard(reload: true);
      await c.refreshRankDeltas();

      service.board = [_p(2, 6, 4.0), _p(1, 5, 4.0)];
      await c.getLeaderboard(reload: true);
      await c.refreshRankDeltas();

      expect(c.rankDeltaFor(2), 1);
      expect(c.rankDeltaFor(1), -1);
    });

    test('old weeks\' snapshots are dropped', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'places_rank_snapshot_2026-W01_all': '{}',
        'places_rank_snapshot_2026-W02_3': '{}',
      });
      Get.reset();
      Get.put<SharedPreferences>(await SharedPreferences.getInstance());
      service = _Board()..board = [_p(1, 5, 4.0)];
      c = PlacesController(placesServiceInterface: service);
      Get.put<PlacesController>(c);
      await c.getLeaderboard(reload: true);
      await c.refreshRankDeltas();

      final keys = (await SharedPreferences.getInstance()).getKeys();
      expect(
        keys.where((k) => k.startsWith('places_rank_snapshot_')).length,
        1,
      );
      expect(keys.contains('places_rank_snapshot_2026-W01_all'), isFalse);
    });
  });
}
