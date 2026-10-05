import 'package:get/get_connect.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/checkout_prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_config_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_json.dart';
import 'package:waddy_app/features/xp/domain/repositories/xp_repository_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

class XpRepository implements XpRepositoryInterface {
  final ApiClient apiClient;

  XpRepository({required this.apiClient});

  @override
  Future<ChallengeModel?> getChallenges() async {
    ChallengeModel? challengeModel;
    Response response = await apiClient.getData(AppConstants.xpChallengesUri);
    final body = xpMap(response.body);
    if (response.statusCode == 200 && body != null) {
      challengeModel = ChallengeModel.fromJson(body);
    }
    return challengeModel;
  }

  // Claims pass `handleError: false` (X-33). With the default, ApiClient
  // toasts the server's reason and hands back an empty Response, so the
  // controller toasted a generic fallback on top of it. Now the controller
  // gets the real body and shows one message: the server's.
  @override
  Future<Response> claimChallenge(int challengeId) async {
    return await apiClient.postData(
      '${AppConstants.xpClaimChallengeUri}$challengeId/claim',
      {},
      handleError: false,
    );
  }

  @override
  Future<PrizeModel?> getPrizes() async {
    PrizeModel? prizeModel;
    Response response = await apiClient.getData(AppConstants.xpPrizesUri);
    final body = xpMap(response.body);
    if (response.statusCode == 200 && body != null) {
      prizeModel = PrizeModel.fromJson(body);
    }
    return prizeModel;
  }

  @override
  Future<Response> claimPrize(int prizeId) async {
    return await apiClient.postData(
      '${AppConstants.xpClaimPrizeUri}$prizeId/claim',
      {},
      handleError: false,
    );
  }

  @override
  Future<List<CheckoutPrize>> getCheckoutPrizes(double orderAmount) async {
    List<CheckoutPrize> prizes = [];
    Response response = await apiClient.getData(
      '${AppConstants.xpCheckoutPrizesUri}?order_amount=$orderAmount',
    );
    if (response.statusCode == 200) {
      prizes =
          xpMapList(
            xpMap(response.body)?['prizes'],
          ).map(CheckoutPrize.fromJson).toList();
    }
    return prizes;
  }

  @override
  Future<XpConfigModel?> getXpConfig() async {
    XpConfigModel? xpConfigModel;
    Response response = await apiClient.getData(AppConstants.xpConfigUri);

    final body = xpMap(response.body);
    if (response.statusCode == 200 && body != null) {
      xpConfigModel = XpConfigModel.fromJson(body);
    }
    return xpConfigModel;
  }

  @override
  Future<Map<String, dynamic>?> getLevelDetails() async {
    Response response = await apiClient.getData(AppConstants.xpLevelDetailsUri);
    return response.statusCode == 200 ? xpMap(response.body) : null;
  }

  @override
  Future<Response> acknowledgeLevelUps({List<int>? transactionIds}) async {
    return await apiClient.postData(
      AppConstants.xpAcknowledgeLevelUpsUri,
      transactionIds != null && transactionIds.isNotEmpty
          ? {'transaction_ids': transactionIds}
          : {},
    );
  }


  @override
  Future<XpLeaderboardModel?> getLeaderboard({
    String type = 'global',
    String period = 'alltime',
  }) async {
    XpLeaderboardModel? leaderboardModel;
    Response response = await apiClient.getData(
      '${AppConstants.xpLeaderboardUri}?type=$type&period=$period',
    );
    final body = xpMap(response.body);
    if (response.statusCode == 200 && body != null) {
      leaderboardModel = XpLeaderboardModel.fromJson(body);
    }
    return leaderboardModel;
  }

  @override
  Future add(value) {
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    throw UnimplementedError();
  }

  @override
  Future get(String? id) {
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset}) {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int? id) {
    throw UnimplementedError();
  }
}
