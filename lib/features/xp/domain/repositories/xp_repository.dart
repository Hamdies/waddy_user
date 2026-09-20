import 'package:get/get_connect.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/checkout_prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_config_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_history_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:waddy_app/features/xp/domain/repositories/xp_repository_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

class XpRepository implements XpRepositoryInterface {
  final ApiClient apiClient;

  XpRepository({required this.apiClient});

  @override
  Future<ChallengeModel?> getChallenges() async {
    ChallengeModel? challengeModel;
    Response response = await apiClient.getData(AppConstants.xpChallengesUri);
    if (response.statusCode == 200) {
      challengeModel = ChallengeModel.fromJson(response.body);
    }
    return challengeModel;
  }

  @override
  Future<Response> claimChallenge(int challengeId) async {
    return await apiClient.postData(
      '${AppConstants.xpClaimChallengeUri}$challengeId/claim',
      {},
    );
  }

  @override
  Future<PrizeModel?> getPrizes() async {
    PrizeModel? prizeModel;
    Response response = await apiClient.getData(AppConstants.xpPrizesUri);
    if (response.statusCode == 200) {
      prizeModel = PrizeModel.fromJson(response.body);
    }
    return prizeModel;
  }

  @override
  Future<Response> claimPrize(int prizeId) async {
    return await apiClient.postData(
      '${AppConstants.xpClaimPrizeUri}$prizeId/claim',
      {},
    );
  }

  @override
  Future<List<CheckoutPrize>> getCheckoutPrizes(double orderAmount) async {
    List<CheckoutPrize> prizes = [];
    Response response = await apiClient.getData(
      '${AppConstants.xpCheckoutPrizesUri}?order_amount=$orderAmount',
    );
    if (response.statusCode == 200 && response.body?['prizes'] != null) {
      prizes =
          (response.body['prizes'] as List)
              .map((p) => CheckoutPrize.fromJson(p))
              .toList();
    }
    return prizes;
  }

  @override
  Future<XpConfigModel?> getXpConfig() async {
    XpConfigModel? xpConfigModel;
    Response response = await apiClient.getData(AppConstants.xpConfigUri);

    if (response.statusCode == 200) {
      xpConfigModel = XpConfigModel.fromJson(response.body);
    }
    return xpConfigModel;
  }

  @override
  Future<Map<String, dynamic>?> getLevelDetails() async {
    Response response = await apiClient.getData(AppConstants.xpLevelDetailsUri);
    if (response.statusCode == 200) {
      return response.body;
    }
    return null;
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
  Future<XpHistoryModel?> getHistory({int limit = 20, int offset = 0}) async {
    XpHistoryModel? historyModel;
    Response response = await apiClient.getData(
      '${AppConstants.xpHistoryUri}?limit=$limit&offset=$offset',
    );
    if (response.statusCode == 200) {
      historyModel = XpHistoryModel.fromJson(response.body);
    }
    return historyModel;
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
    if (response.statusCode == 200) {
      leaderboardModel = XpLeaderboardModel.fromJson(response.body);
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
