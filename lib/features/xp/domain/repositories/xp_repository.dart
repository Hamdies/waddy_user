import 'package:get/get_connect.dart';
import 'package:sixam_mart/api/api_client.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_level_model.dart';
import 'package:sixam_mart/features/xp/domain/models/challenge_model.dart';
import 'package:sixam_mart/features/xp/domain/models/prize_model.dart';
import 'package:sixam_mart/features/xp/domain/models/checkout_prize_model.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_config_model.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_history_model.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:sixam_mart/features/xp/domain/repositories/xp_repository_interface.dart';
import 'package:sixam_mart/util/app_constants.dart';

class XpRepository implements XpRepositoryInterface {
  final ApiClient apiClient;

  XpRepository({required this.apiClient});

  @override
  Future<XpLevelModel?> getCurrentLevel() async {
    XpLevelModel? xpLevelModel;
    Response response = await apiClient.getData(AppConstants.xpLevelUri);
    if (response.statusCode == 200) {
      xpLevelModel = XpLevelModel.fromJson(response.body);
    }
    return xpLevelModel;
  }

  @override
  Future<LevelsListModel?> getAllLevels() async {
    LevelsListModel? levelsListModel;
    Response response = await apiClient.getData(AppConstants.xpLevelsUri);
    if (response.statusCode == 200) {
      levelsListModel = LevelsListModel.fromJson(response.body);
    }
    return levelsListModel;
  }

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
    if (response.statusCode == 200 && response.body != null) {
      if (response.body is List) {
        prizes =
            (response.body as List)
                .map((p) => CheckoutPrize.fromJson(p))
                .toList();
      } else if (response.body['prizes'] != null) {
        prizes =
            (response.body['prizes'] as List)
                .map((p) => CheckoutPrize.fromJson(p))
                .toList();
      }
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
  Future<XpLeaderboardModel?> getLeaderboard({String type = 'global'}) async {
    XpLeaderboardModel? leaderboardModel;
    Response response = await apiClient.getData(
      '${AppConstants.xpLeaderboardUri}?type=$type',
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
