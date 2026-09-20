import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_category_model.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/models/place_winner_model.dart';
import 'package:waddy_app/features/places/domain/services/places_service_interface.dart';
import 'package:waddy_app/features/places/domain/spots_round.dart';
import 'package:waddy_app/features/places/domain/spots_stage.dart';

/// Phase 0 of `docs/spots_module_plan.md` — the audit reproducing itself before
/// anything is changed.
///
/// `places_init_test.dart` already pins the init path (partial failure, total
/// failure, cache-before-network). This covers what the rest of the plan is
/// about: the two pure domain types that drive the home's composition and its
/// deadline, and the tie semantics the board's credibility rests on.
///
/// The last group is expected to FAIL on a clean checkout. That is the point:
/// `S-09` says the section header counts the server's catalogue while the list
/// renders one page, and a finding worth fixing should be visible here first.
class _FakePlacesService implements PlacesServiceInterface {
  _FakePlacesService({List<Place>? places, List<Place>? board})
    : _places = places ?? const <Place>[],
      _board = board ?? const <Place>[];

  final List<Place> _places;
  final List<Place> _board;

  /// What the server says the full catalogue holds, independent of how many
  /// rows this page actually carries. The gap between the two is `S-09`.
  int? placesTotalSize;

  @override
  Future<PlaceList?> getPlaces({
    int? categoryId,
    String? search,
    double? lat,
    double? lng,
    String? sort,
    List<int>? tagIds,
    int? zoneId,
    int offset = 1,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    if (source == DataSourceEnum.local) return null;
    return PlaceList(
      places: _places,
      totalSize: placesTotalSize ?? _places.length,
      offset: offset,
    );
  }

  @override
  Future<PlaceList?> getLeaderboard({
    String? period,
    int? zoneId,
    int? limit,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    if (source == DataSourceEnum.local) return null;
    return PlaceList(places: _board, totalSize: _board.length, offset: 1);
  }

  @override
  Future<List<PlaceZone>?> getZones({
    DataSourceEnum source = DataSourceEnum.client,
  }) async =>
      source == DataSourceEnum.local
          ? null
          : <PlaceZone>[PlaceZone(id: 1, name: 'Maadi')];

  @override
  Future<List<PlaceCategory>?> getCategories({
    DataSourceEnum source = DataSourceEnum.client,
  }) async =>
      source == DataSourceEnum.local
          ? null
          : <PlaceCategory>[PlaceCategory(id: 1, name: 'Cafe')];

  @override
  Future<TopVoterList?> getTopVoters({
    int? zoneId,
    int limit = 10,
    DataSourceEnum source = DataSourceEnum.client,
  }) async =>
      source == DataSourceEnum.local
          ? null
          : TopVoterList(voters: const <TopVoter>[]);

  @override
  Future<PlaceWinner?> getLatestWinner({int? zoneId}) async => null;

  @override
  Future<List<RecentWinner>?> getRecentWinners({int limit = 10}) async =>
      const <RecentWinner>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Zones only, with a switchable failure — the one endpoint whose null-vs-empty
/// distinction `S-10` is about.
class _ZoneService implements PlacesServiceInterface {
  bool fails = false;
  List<PlaceZone> zones = <PlaceZone>[PlaceZone(id: 1, name: 'Maadi')];

  @override
  Future<List<PlaceZone>?> getZones({
    DataSourceEnum source = DataSourceEnum.client,
  }) async => fails ? null : zones;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
    Get.put<SharedPreferences>(await SharedPreferences.getInstance());
  });

  Place spot(int id, {required int votes, double rating = 0}) =>
      Place(id: id, title: 'Spot $id', votesCount: votes, rating: rating);

  Future<PlacesController> boardOf(List<Place> places) async {
    final PlacesController controller = PlacesController(
      placesServiceInterface: _FakePlacesService(places: places),
    );
    Get.put<PlacesController>(controller);
    await controller.getPlaces();
    return controller;
  }

  // ───────────────────────────────────────────────────────────────
  // S-03 · the stage thresholds
  // ───────────────────────────────────────────────────────────────
  //
  // `LiveNewsBar` carries its own literal `5` beside `warmThreshold = 5`. They
  // agree today by coincidence, not by construction. Pinning the boundaries
  // means moving either one without the other breaks a test rather than
  // silently letting the hero and the ticker disagree about the same board.
  group('S-03 · SpotsStage boundaries', () {
    test('an empty board is cold', () {
      expect(SpotsStage.fromHeat(0), SpotsStage.cold);
    });

    test('cold up to the warm threshold, warm at it', () {
      expect(
        SpotsStage.fromHeat(SpotsStage.warmThreshold - 1),
        SpotsStage.cold,
      );
      expect(SpotsStage.fromHeat(SpotsStage.warmThreshold), SpotsStage.warm);
    });

    test('warm up to the hot threshold, hot at it', () {
      expect(SpotsStage.fromHeat(SpotsStage.hotThreshold - 1), SpotsStage.warm);
      expect(SpotsStage.fromHeat(SpotsStage.hotThreshold), SpotsStage.hot);
    });

    test('hasBoard is false only while cold', () {
      expect(SpotsStage.cold.hasBoard, isFalse);
      expect(SpotsStage.warm.hasBoard, isTrue);
      expect(SpotsStage.hot.hasBoard, isTrue);
    });

    // The home does NOT gate sections on this — every section renders and
    // owns its empty state. `stage` drives copy: `WeeklyTop3Section` reframes
    // its hero below `isHot`, and `LiveNewsBar` leads with an invitation while
    // cold instead of a marquee of one-vote counts.
    test('the predicates the copy switches on', () {
      expect(SpotsStage.cold.isHot, isFalse);
      expect(SpotsStage.warm.isHot, isFalse);
      expect(SpotsStage.hot.isHot, isTrue);
      expect(SpotsStage.cold.isCold, isTrue);
      expect(SpotsStage.warm.isCold, isFalse);
    });

    // The value the home is meant to compose from, derived end to end.
    test('roundHeat sums the board and drives the stage', () async {
      final PlacesController cold = await boardOf(<Place>[
        spot(1, votes: 2),
        spot(2, votes: 1),
      ]);
      expect(cold.roundHeat, 3);
      expect(cold.stage, SpotsStage.cold);

      Get.reset();
      Get.put<SharedPreferences>(await SharedPreferences.getInstance());

      final PlacesController hot = await boardOf(<Place>[
        spot(1, votes: 20),
        spot(2, votes: 9),
      ]);
      expect(hot.roundHeat, 29);
      expect(hot.stage, SpotsStage.hot);
    });
  });

  // ───────────────────────────────────────────────────────────────
  // S-12 · the deadline
  // ───────────────────────────────────────────────────────────────
  //
  // The label/timer seam is fixed (one instant, every label derived from it),
  // but the weekday arithmetic was only ever verified by hand. `8 - weekday`
  // is exactly the kind of expression that is right until someone "simplifies"
  // it, and on a Monday the failure mode is a deadline a full week out.
  group('S-12 · SpotsRound.lockAt', () {
    test('every weekday resolves to the next Monday at midnight', () {
      // 2026-09-14 is a Monday; walk one full week from it.
      for (int offset = 0; offset < 7; offset++) {
        final DateTime day = DateTime(2026, 9, 14 + offset, 10, 30);
        final DateTime lock = SpotsRound.lockAt(day);

        expect(lock.weekday, DateTime.monday, reason: 'from ${day.weekday}');
        expect(lock.hour, 0);
        expect(lock.minute, 0);
        expect(lock.isAfter(day), isTrue, reason: 'lock must be ahead');
        // The whole point: never a week out. Monday 10:30 locks in 6 days,
        // not 13.
        expect(lock.difference(day).inDays, lessThan(7));
      }
    });

    test('remaining never goes negative', () {
      final DateTime past = DateTime(
        2026,
        9,
        21,
        0,
        0,
      ).add(const Duration(seconds: 1));
      expect(SpotsRound.remaining(past).isNegative, isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────
  // S-12 · tie semantics
  // ───────────────────────────────────────────────────────────────
  //
  // Position in a sorted list is not rank. Two spots on one vote each are
  // tied, and printing them as 01 and 02 asserts an order the votes do not
  // support — on a cold board that is most of the screen's credibility.
  group('S-12 · rankOf / isTiedAt', () {
    test('ties share a rank and the next rank skips', () async {
      // 5, 3, 3, 1 → ranks 1, 2, 2, 4.
      final PlacesController c = await boardOf(<Place>[
        spot(1, votes: 5),
        spot(2, votes: 3),
        spot(3, votes: 3),
        spot(4, votes: 1),
      ]);

      expect(c.rankOf(1), 1);
      expect(c.rankOf(2), 2);
      expect(c.rankOf(3), 2, reason: 'equal votes must share a rank');
      expect(c.rankOf(4), 4, reason: 'rank 3 is consumed by the tie');
    });

    test('isTiedAt agrees with rankOf', () async {
      final PlacesController c = await boardOf(<Place>[
        spot(1, votes: 5),
        spot(2, votes: 3),
        spot(3, votes: 3),
      ]);

      expect(c.isTiedAt(1), isFalse);
      expect(c.isTiedAt(2), isTrue);
      expect(c.isTiedAt(3), isTrue);
      expect(c.rankOf(2), c.rankOf(3));
    });

    test('a place off the board has no rank rather than a wrong one', () async {
      final PlacesController c = await boardOf(<Place>[spot(1, votes: 5)]);
      expect(c.rankOf(999), isNull);
      expect(c.isTiedAt(999), isFalse);
    });

    // `liveStandings` is memoised on the identity of the two lists it derives
    // from (`S-08`). Two things must stay true: repeated reads give the same
    // answer, and a new payload is actually picked up rather than served from
    // a stale memo.
    test('the memo is stable and invalidates on new data', () async {
      final _FakePlacesService service = _FakePlacesService(
        places: <Place>[spot(1, votes: 3), spot(2, votes: 1)],
      );
      final PlacesController c = PlacesController(
        placesServiceInterface: service,
      );
      Get.put<PlacesController>(c);
      await c.getPlaces();

      final List<Place> first = c.liveStandings;
      expect(identical(c.liveStandings, first), isTrue, reason: 'memoised');
      expect(c.roundHeat, 4);

      // A fresh fetch replaces `_placeList`, so the memo key no longer
      // matches and the standings must be recomputed.
      final PlacesController c2 = PlacesController(
        placesServiceInterface: _FakePlacesService(
          places: <Place>[spot(1, votes: 30), spot(2, votes: 1)],
        ),
      );
      Get.put<PlacesController>(c2, tag: 'second');
      await c2.getPlaces();
      expect(c2.roundHeat, 31);
    });

    test('the returned standings cannot be mutated by a caller', () async {
      final PlacesController c = await boardOf(<Place>[spot(1, votes: 3)]);
      expect(
        () => c.liveStandings.add(spot(9, votes: 99)),
        throwsUnsupportedError,
        reason: 'a shared memo must not be mutable in place',
      );
    });

    // Zero-vote spots are not in the race; ranking them would put a spot
    // nobody voted for on a leaderboard.
    test('unvoted spots stay off the standings', () async {
      final PlacesController c = await boardOf(<Place>[
        spot(1, votes: 3),
        spot(2, votes: 0),
      ]);

      expect(c.liveStandings.map((Place p) => p.id), <int>[1]);
      expect(c.rankOf(2), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────
  // S-10 · zones: failed is not the same as empty
  // ───────────────────────────────────────────────────────────────
  //
  // The filter sheet gated on `isZonesLoading` alone, and `getZones` clears
  // that flag on failure as well as success — so a dead endpoint rendered
  // nothing at all, which reads as "this city has no areas" rather than as an
  // error. These pin the three states the sheet now tells apart.
  group('S-10 · zone fetch states', () {
    test('a failed fetch is distinguishable from an empty one', () async {
      final _ZoneService service = _ZoneService()..fails = true;
      final PlacesController controller = PlacesController(
        placesServiceInterface: service,
      );
      Get.put<PlacesController>(controller);

      await controller.getZones();

      expect(controller.zones, isNull);
      expect(controller.isZonesLoading, isFalse);
      expect(
        controller.zonesFailed,
        isTrue,
        reason: 'a null response must be reported, not rendered as empty',
      );
    });

    test('an empty list is an answer, not a failure', () async {
      final _ZoneService service = _ZoneService()..zones = <PlaceZone>[];
      final PlacesController controller = PlacesController(
        placesServiceInterface: service,
      );
      Get.put<PlacesController>(controller);

      await controller.getZones();

      expect(controller.zones, isEmpty);
      expect(controller.zonesFailed, isFalse);
    });

    test('a retry after a failure recovers', () async {
      final _ZoneService service = _ZoneService()..fails = true;
      final PlacesController controller = PlacesController(
        placesServiceInterface: service,
      );
      Get.put<PlacesController>(controller);

      await controller.getZones();
      expect(controller.zonesFailed, isTrue);

      service.fails = false;
      await controller.getZones(reload: true);

      expect(controller.zonesFailed, isFalse);
      expect(controller.zones, hasLength(1));
    });
  });

  // ───────────────────────────────────────────────────────────────
  // S-09 · the header's count must be reachable
  // ───────────────────────────────────────────────────────────────
  //
  // The section header renders `totalPlaces` — the server's count of the whole
  // catalogue — and the home only ever loaded page one, so it claimed "48
  // SPOTS" above ten rows with no way to reach the rest. `F-01`'s defect in a
  // milder form: a headline that is not true of the data beneath it.
  //
  // The fix was to make the claim true rather than to shrink it, so what these
  // pin is that the list can actually get there.
  group('S-09 · places pagination', () {
    test('the catalogue count is reachable by paging', () async {
      final _PagedPlacesService service = _PagedPlacesService(
        total: 5,
        pageSize: 2,
      );
      final PlacesController c = PlacesController(
        placesServiceInterface: service,
      );
      Get.put<PlacesController>(c);

      await c.getPlaces();
      expect(c.places, hasLength(2));
      expect(c.totalPlaces, 5);
      expect(c.hasMorePlaces, isTrue);

      await c.getPlaces(offset: c.nextPlacesPage);
      expect(c.places, hasLength(4));
      expect(c.hasMorePlaces, isTrue);

      await c.getPlaces(offset: c.nextPlacesPage);
      expect(c.places, hasLength(5));
      expect(
        c.hasMorePlaces,
        isFalse,
        reason: 'the header count is now what the list actually holds',
      );
    });

    test('a repeated row is not appended twice', () async {
      // A spot removed between two fetches shifts the window, so the next page
      // can carry a row that is already on screen.
      final _PagedPlacesService service = _PagedPlacesService(
        total: 4,
        pageSize: 2,
        overlap: true,
      );
      final PlacesController c = PlacesController(
        placesServiceInterface: service,
      );
      Get.put<PlacesController>(c);

      await c.getPlaces();
      await c.getPlaces(offset: c.nextPlacesPage);

      final List<int> ids = c.places!.map((Place p) => p.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'no duplicate ids');
    });

    // Changing the order must restart the list, not append the new order's
    // page two onto the old order's page one.
    test('changing the sort resets pagination', () async {
      final _PagedPlacesService service = _PagedPlacesService(
        total: 6,
        pageSize: 2,
      );
      final PlacesController c = PlacesController(
        placesServiceInterface: service,
      );
      Get.put<PlacesController>(c);

      await c.getPlaces();
      await c.getPlaces(offset: c.nextPlacesPage);
      expect(c.places, hasLength(4));

      c.setSortBy('votes');
      // `setSortBy` fires `getPlaces(reload: true)` without awaiting it.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(c.sortBy, 'votes');
      expect(c.places, hasLength(2), reason: 'back to page one');
      expect(c.nextPlacesPage, 2);
    });

    test('a concurrent append is dropped rather than doubled', () async {
      final _PagedPlacesService service = _PagedPlacesService(
        total: 6,
        pageSize: 2,
      );
      final PlacesController c = PlacesController(
        placesServiceInterface: service,
      );
      Get.put<PlacesController>(c);

      await c.getPlaces();
      final int callsAfterFirst = service.calls;

      // The scroll trigger fires on every frame inside the zone — two appends
      // launched together must produce one request, not two.
      await Future.wait(<Future<void>>[
        c.getPlaces(offset: 2),
        c.getPlaces(offset: 2),
      ]);

      expect(service.calls - callsAfterFirst, 1);
      expect(c.places, hasLength(4));
    });
  });
}

/// A catalogue that actually pages, for the `S-09` group.
class _PagedPlacesService implements PlacesServiceInterface {
  _PagedPlacesService({
    required this.total,
    required this.pageSize,
    this.overlap = false,
  });

  final int total;
  final int pageSize;

  /// Serve each page one row early, so page 2 repeats page 1's last row —
  /// what a deletion between fetches looks like from the client.
  final bool overlap;

  int calls = 0;

  @override
  Future<PlaceList?> getPlaces({
    int? categoryId,
    String? search,
    double? lat,
    double? lng,
    String? sort,
    List<int>? tagIds,
    int? zoneId,
    int offset = 1,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    if (source == DataSourceEnum.local) return null;
    calls++;
    // Let a concurrent caller reach the in-flight guard before this resolves.
    await Future<void>.delayed(Duration.zero);

    int start = (offset - 1) * pageSize;
    if (overlap && offset > 1) start -= 1;
    final int end = (start + pageSize).clamp(0, total);

    return PlaceList(
      places: <Place>[
        for (int i = start; i < end; i++)
          Place(id: i + 1, title: 'Spot ${i + 1}', votesCount: i),
      ],
      totalSize: total,
      offset: offset,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
