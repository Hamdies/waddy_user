import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_category_model.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/models/place_winner_model.dart';
import 'package:waddy_app/features/places/domain/services/places_service_interface.dart';

/// The Spots home used to gate its first paint on `Future.wait` over seven
/// calls, and to treat any one of them throwing as a whole-screen error. Both
/// were invisible to the analyzer and to a widget test that stubs a happy
/// path, so they are pinned here against a service that can fail selectively
/// and that distinguishes a cache read from a network one.
class _FakePlacesService implements PlacesServiceInterface {
  _FakePlacesService();

  /// Endpoints that should throw instead of returning.
  final Set<String> failing = <String>{};

  /// Endpoints that have a cached (local-source) payload available.
  final Set<String> cached = <String>{};

  /// Every call, in order, tagged with the source it was made against.
  final List<String> calls = <String>[];

  Place _place(int id) => Place(id: id, title: 'Spot $id', votesCount: id);

  T? _serve<T>(String name, DataSourceEnum source, T value) {
    calls.add('$name:${source.name}');
    if (failing.contains(name)) throw Exception('$name failed');
    if (source == DataSourceEnum.local && !cached.contains(name)) return null;
    return value;
  }

  @override
  Future<List<PlaceZone>?> getZones({
    DataSourceEnum source = DataSourceEnum.client,
  }) async =>
      _serve('zones', source, <PlaceZone>[PlaceZone(id: 1, name: 'Maadi')]);

  @override
  Future<List<PlaceCategory>?> getCategories({
    DataSourceEnum source = DataSourceEnum.client,
  }) async => _serve('categories', source, <PlaceCategory>[
    PlaceCategory(id: 1, name: 'Cafe'),
  ]);

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
  }) async => _serve(
    'places',
    source,
    PlaceList(places: <Place>[_place(1), _place(2)], totalSize: 2, offset: 1),
  );

  @override
  Future<PlaceList?> getLeaderboard({
    String? period,
    int? zoneId,
    int? limit,
    DataSourceEnum source = DataSourceEnum.client,
  }) async => _serve(
    'leaderboard',
    source,
    PlaceList(places: <Place>[_place(3)], totalSize: 1, offset: 1),
  );

  @override
  Future<TopVoterList?> getTopVoters({
    int? zoneId,
    int limit = 10,
    DataSourceEnum source = DataSourceEnum.client,
  }) async =>
      _serve('topVoters', source, TopVoterList(voters: const <TopVoter>[]));

  @override
  Future<PlaceWinner?> getLatestWinner({int? zoneId}) async {
    calls.add('latestWinner:client');
    if (failing.contains('latestWinner'))
      throw Exception('latestWinner failed');
    return null;
  }

  @override
  Future<List<RecentWinner>?> getRecentWinners({int limit = 10}) async =>
      _serve('recentWinners', DataSourceEnum.client, const <RecentWinner>[]);

  // ── Unused by initialization ────────────────────────────────────
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

  PlacesController controllerFor(_FakePlacesService service) {
    final PlacesController controller = PlacesController(
      placesServiceInterface: service,
    );
    Get.put<PlacesController>(controller);
    return controller;
  }

  test('one dead endpoint no longer blanks the whole screen', () async {
    final _FakePlacesService service =
        _FakePlacesService()..failing.add('topVoters');
    final PlacesController controller = controllerFor(service);

    await controller.initializePlacesData();

    // The six healthy calls landed, so there is a board to draw...
    expect(controller.leaderboard, isNotNull);
    expect(controller.places, hasLength(2));
    // ...and the error card must stay away even though one call threw.
    expect(controller.hasInitError, isFalse);
  });

  test('total failure is still an error state', () async {
    final _FakePlacesService service =
        _FakePlacesService()
          ..failing.addAll(<String>[
            'zones',
            'categories',
            'places',
            'leaderboard',
            'topVoters',
            'latestWinner',
            'recentWinners',
          ]);
    final PlacesController controller = controllerFor(service);

    await controller.initializePlacesData();

    expect(controller.hasAnyHomeData, isFalse);
    expect(controller.hasInitError, isTrue);
  });

  test('a cache hit paints before any network call is made', () async {
    final _FakePlacesService service =
        _FakePlacesService()..cached.addAll(<String>['leaderboard', 'places']);
    final PlacesController controller = controllerFor(service);

    await controller.initializePlacesData();

    final int firstClientCall = service.calls.indexWhere(
      (String c) => c.endsWith(':client'),
    );
    final int firstLocalCall = service.calls.indexWhere(
      (String c) => c.endsWith(':local'),
    );

    expect(firstLocalCall, isNonNegative, reason: 'cache pass must run');
    expect(
      firstLocalCall,
      lessThan(firstClientCall),
      reason: 'the cache is read before the network is touched',
    );
    expect(controller.leaderboard, isNotNull);
  });

  test('a cold cache goes straight to the network and still loads', () async {
    final _FakePlacesService service = _FakePlacesService();
    final PlacesController controller = controllerFor(service);

    await controller.initializePlacesData();

    expect(controller.places, hasLength(2));
    expect(controller.hasInitError, isFalse);
    // Nothing may be left pinned to a skeleton once init returns.
    expect(controller.isPlacesLoading, isFalse);
    expect(controller.isLeaderboardLoading, isFalse);
    expect(controller.isTopVotersLoading, isFalse);
  });
}
