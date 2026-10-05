import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class XpRepositoryInterface implements RepositoryInterface {
  Future<dynamic> getLevelDetails();
  Future<dynamic> acknowledgeLevelUps({List<int>? transactionIds});
  Future<dynamic> getChallenges();
  Future<dynamic> claimChallenge(int challengeId);
  Future<dynamic> getPrizes();
  Future<dynamic> claimPrize(int prizeId);
  Future<dynamic> getCheckoutPrizes(double orderAmount);
  Future<dynamic> getXpConfig();
  Future<dynamic> getLeaderboard({
    String type = 'global',
    String period = 'alltime',
  });
}
