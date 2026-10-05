import 'package:get/get_connect/http/src/response/response.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/checkout_prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_config_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';

abstract class XpServiceInterface {
  Future<Map<String, dynamic>?> getLevelDetails();
  Future<Response> acknowledgeLevelUps({List<int>? transactionIds});
  Future<ChallengeModel?> getChallenges();
  Future<Response> claimChallenge(int challengeId);
  Future<PrizeModel?> getPrizes();
  Future<Response> claimPrize(int prizeId);
  Future<List<CheckoutPrize>> getCheckoutPrizes(double orderAmount);
  Future<XpConfigModel?> getXpConfig();
  Future<XpLeaderboardModel?> getLeaderboard({
    String type = 'global',
    String period = 'alltime',
  });
}
