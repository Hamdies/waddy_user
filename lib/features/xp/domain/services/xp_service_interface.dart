import 'package:get/get_connect/http/src/response/response.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_level_model.dart';
import 'package:sixam_mart/features/xp/domain/models/challenge_model.dart';
import 'package:sixam_mart/features/xp/domain/models/prize_model.dart';
import 'package:sixam_mart/features/xp/domain/models/checkout_prize_model.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_config_model.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_history_model.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_leaderboard_model.dart';

abstract class XpServiceInterface {
  Future<XpLevelModel?> getCurrentLevel();
  Future<LevelsListModel?> getAllLevels();
  Future<Map<String, dynamic>?> getLevelDetails();
  Future<ChallengeModel?> getChallenges();
  Future<Response> claimChallenge(int challengeId);
  Future<PrizeModel?> getPrizes();
  Future<Response> claimPrize(int prizeId);
  Future<List<CheckoutPrize>> getCheckoutPrizes(double orderAmount);
  Future<XpConfigModel?> getXpConfig();
  Future<XpHistoryModel?> getHistory({int limit = 20, int offset = 0});
  Future<XpLeaderboardModel?> getLeaderboard({String type = 'global'});
}
