import 'package:get/get_connect/http/src/response/response.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/checkout_prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_config_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_history_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:waddy_app/features/xp/domain/repositories/xp_repository_interface.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service_interface.dart';

class XpService implements XpServiceInterface {
  final XpRepositoryInterface xpRepositoryInterface;

  XpService({required this.xpRepositoryInterface});

  @override
  Future<Map<String, dynamic>?> getLevelDetails() async {
    return await xpRepositoryInterface.getLevelDetails();
  }

  @override
  Future<Response> acknowledgeLevelUps({List<int>? transactionIds}) async {
    return await xpRepositoryInterface.acknowledgeLevelUps(
      transactionIds: transactionIds,
    );
  }

  @override
  Future<ChallengeModel?> getChallenges() async {
    return await xpRepositoryInterface.getChallenges();
  }

  @override
  Future<Response> claimChallenge(int challengeId) async {
    return await xpRepositoryInterface.claimChallenge(challengeId);
  }

  @override
  Future<PrizeModel?> getPrizes() async {
    return await xpRepositoryInterface.getPrizes();
  }

  @override
  Future<Response> claimPrize(int prizeId) async {
    return await xpRepositoryInterface.claimPrize(prizeId);
  }

  @override
  Future<List<CheckoutPrize>> getCheckoutPrizes(double orderAmount) async {
    return await xpRepositoryInterface.getCheckoutPrizes(orderAmount);
  }

  @override
  Future<XpConfigModel?> getXpConfig() async {
    return await xpRepositoryInterface.getXpConfig();
  }

  @override
  Future<XpHistoryModel?> getHistory({int limit = 20, int offset = 0}) async {
    return await xpRepositoryInterface.getHistory(limit: limit, offset: offset);
  }

  @override
  Future<XpLeaderboardModel?> getLeaderboard({
    String type = 'global',
    String period = 'alltime',
  }) async {
    return await xpRepositoryInterface.getLeaderboard(
      type: type,
      period: period,
    );
  }
}
