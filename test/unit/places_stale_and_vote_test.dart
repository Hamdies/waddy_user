import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/models/place_vote_model.dart';
import 'package:waddy_app/features/places/domain/services/places_service_interface.dart';

/// Two defects that only exist while a request is in flight:
///  * a slow answer for an earlier tap overwriting a newer one (bug 4), and
///  * Undo after a switched vote deleting the user's only vote (bug 5).
/// Both need a fake whose answers the test releases by hand.
class _Service implements PlacesServiceInterface {
  final Map<int, Completer<({Place? place, int? statusCode})>> details = {};
  final List<Completer<PlaceList?>> placePages = [];
  final List<String> votes = []; // "vote:ID", "switch:ID", "remove:ID"

  /// The spot the fake server currently holds this week's vote on.
  int? serverVote;

  @override
  Future<({Place? place, int? statusCode})> getPlaceDetails(int placeId) {
    final c = Completer<({Place? place, int? statusCode})>();
    details[placeId] = c;
    return c.future;
  }

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
  }) {
    final c = Completer<PlaceList?>();
    placePages.add(c);
    return c.future;
  }

  @override
  Future<VoteStatus?> getVoteStatus(int placeId) async =>
      VoteStatus(hasVoted: serverVote == placeId);

  @override
  Future<Response> submitVote(
    int placeId,
    int? rating,
    String? comment, {
    String? imagePath,
    bool switchVote = false,
  }) async {
    if (serverVote != null && serverVote != placeId && !switchVote) {
      return Response(
        statusCode: 409,
        body: {
          'code': 'already_voted_this_week',
          'current_vote': {'place_id': serverVote, 'place_title': 'Old spot'},
        },
      );
    }
    if (serverVote == placeId) {
      return const Response(
        statusCode: 200,
        body: {'success': true, 'action': 'unchanged'},
      );
    }
    votes.add('${switchVote ? 'switch' : 'vote'}:$placeId');
    serverVote = placeId;
    return Response(
      statusCode: 200,
      body: {'success': true, 'action': switchVote ? 'switched' : 'created'},
    );
  }

  @override
  Future<Response> removeVote(int placeId) async {
    votes.add('remove:$placeId');
    if (serverVote == placeId) serverVote = null;
    return const Response(statusCode: 200, body: {'success': true});
  }

  // Everything the post-vote refresh touches resolves empty.
  @override
  Future<PlaceList?> getLeaderboard({
    String? period,
    int? zoneId,
    int? limit,
    DataSourceEnum source = DataSourceEnum.client,
  }) async => null;

  @override
  Future<TopVoterList?> getTopVoters({
    int? zoneId,
    int limit = 10,
    DataSourceEnum source = DataSourceEnum.client,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Place _place(int id) => Place(id: id, title: 'Spot $id', votesCount: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Service service;
  late PlacesController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
    Get.put<SharedPreferences>(await SharedPreferences.getInstance());
    service = _Service();
    c = PlacesController(placesServiceInterface: service);
    Get.put<PlacesController>(c);
  });

  group('stale responses', () {
    test('a slow spot A answer does not overwrite spot B', () async {
      final a = c.getPlaceDetails(1);
      final b = c.getPlaceDetails(2);

      service.details[2]!.complete((place: _place(2), statusCode: 200));
      await b;
      service.details[1]!.complete((place: _place(1), statusCode: 200));
      await a;

      expect(c.placeDetails?.id, 2);
      expect(c.isDetailsLoading, isFalse);
    });

    test('a page-2 asked under the old filters is not merged in', () async {
      final first = c.getPlaces();
      service.placePages[0].complete(
        PlaceList(places: [_place(1)], totalSize: 40, offset: 1),
      );
      await first;

      final page2 = c.getPlaces(offset: 2); // old sort, still in flight
      final reloaded = c.getPlaces(reload: true, sort: 'distance');

      service.placePages[2].complete(
        PlaceList(places: [_place(9)], totalSize: 1, offset: 1),
      );
      await reloaded;
      service.placePages[1].complete(
        PlaceList(places: [_place(2)], totalSize: 40, offset: 2),
      );
      await page2;

      expect(c.places!.map((p) => p.id), [9]);
    });
  });

  group('vote flow', () {
    test('a vote from a card never touches the details slot', () async {
      expect(await c.submitVote(2, null, silent: true), isTrue);

      expect(service.details, isEmpty, reason: 'no details fetch for spot 2');
      expect(c.placeDetails, isNull);
      expect(c.lastVoteAction, 'created');
    });

    test('voting on the open spot refreshes it behind the answer', () async {
      c.seedPlaceDetails(_place(2));
      expect(await c.submitVote(2, null, silent: true), isTrue);

      // Returned already; the status is optimistic and the refresh is pending.
      expect(c.voteStatus?.hasVoted, isTrue);
      expect(c.voteStatus?.weeklyVotePlaceId, 2);
      expect(service.details.containsKey(2), isTrue);
    });

    test('voting twice for the same spot is reported as unchanged', () async {
      await c.submitVote(2, null, silent: true);
      service.votes.clear();

      expect(await c.submitVote(2, null, silent: true), isTrue);
      expect(c.lastVoteAction, 'unchanged');
      expect(service.votes, isEmpty);
    });

    test('undo after a switch puts the vote back on the old spot', () async {
      service.serverVote = 1;
      c.confirmVoteSwitch = (_) async => true;

      expect(await c.submitVote(2, null, silent: true), isTrue);
      expect(c.lastVoteAction, 'switched');
      expect(service.serverVote, 2);

      expect(await c.undoVote(2), isTrue);
      expect(service.serverVote, 1);
      expect(service.votes, ['switch:2', 'remove:2', 'vote:1']);
    });

    test('a plain vote undoes to no vote', () async {
      await c.submitVote(2, null, silent: true);
      expect(await c.undoVote(2), isTrue);

      expect(service.serverVote, isNull);
      expect(service.votes, ['vote:2', 'remove:2']);
    });

    test('declining the switch leaves the vote where it was', () async {
      service.serverVote = 1;
      c.confirmVoteSwitch = (_) async => false;

      expect(await c.submitVote(2, null, silent: true), isFalse);
      expect(service.serverVote, 1);
    });
  });
}
