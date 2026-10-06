import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/places/domain/repositories/places_repository.dart';
import 'package:waddy_app/util/app_constants.dart';

/// The vote POST used to go through ApiClient's default error handling, which
/// swaps every non-200 for an empty `Response()`. The server's 409
/// `already_voted_this_week` — the thing that opens the "switch your vote?"
/// dialog — therefore never reached the controller. These pin that the
/// repository asks for the raw response and passes the 409 through intact.
class _CannedApi extends ApiClient {
  _CannedApi(SharedPreferences prefs)
    : super(appBaseUrl: AppConstants.baseUrl, sharedPreferences: prefs);

  Response next = const Response(statusCode: 200);
  bool? lastHandleError;

  @override
  Future<Response> postData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
    int? timeout,
    bool handleError = true,
    bool showError = true,
  }) async {
    lastHandleError = handleError;
    // Mirror the real client: with handleError on, a non-200 is emptied.
    if (handleError && next.statusCode != 200) return const Response();
    return next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CannedApi api;
  late PlacesRepository repository;

  setUp(() async {
    Get.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = _CannedApi(await SharedPreferences.getInstance());
    repository = PlacesRepository(apiClient: api);
  });

  test(
    'a 409 keeps its status and body so the switch dialog can open',
    () async {
      api.next = const Response(
        statusCode: 409,
        body: {
          'code': 'already_voted_this_week',
          'current_vote': {'place_id': 7, 'place_title': 'Costa'},
        },
      );

      final response = await repository.submitVote(34, null, null);

      expect(api.lastHandleError, isFalse);
      expect(response.statusCode, 409);
      expect(response.body['code'], 'already_voted_this_week');
      expect(response.body['current_vote']['place_title'], 'Costa');
    },
  );

  test('a normal vote still returns its 200', () async {
    api.next = const Response(statusCode: 200, body: {'action': 'created'});

    final response = await repository.submitVote(34, null, null);

    expect(response.statusCode, 200);
    expect(response.body['action'], 'created');
  });
}
