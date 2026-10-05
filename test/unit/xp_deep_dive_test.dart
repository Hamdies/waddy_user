import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/domain/models/checkout_prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/user_streak_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_config_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service_interface.dart';

/// Part 3 of `docs/xp_module_plan.md` — the 2026-09-27 deep dive. Each group
/// pins one finding so it cannot quietly come back.
class _Service implements XpServiceInterface {
  /// Answers for successive `getChallenges` calls; the last one repeats.
  List<ChallengeModel? Function()> challenges = [() => null];
  int _challengeCalls = 0;
  List<CheckoutPrize> Function(double) prizesFor = (_) => const [];
  final List<double> checkoutRequests = [];
  XpConfigModel? config;

  @override
  Future<ChallengeModel?> getChallenges() async {
    final i = _challengeCalls.clamp(0, challenges.length - 1);
    _challengeCalls++;
    return challenges[i]();
  }

  @override
  Future<List<CheckoutPrize>> getCheckoutPrizes(double orderAmount) async {
    checkoutRequests.add(orderAmount);
    return prizesFor(orderAmount);
  }

  @override
  Future<XpConfigModel?> getXpConfig() async => config;

  @override
  Future<Map<String, dynamic>?> getLevelDetails() async => null;

  @override
  Future<PrizeModel?> getPrizes() async => null;


  @override
  Future<XpLeaderboardModel?> getLeaderboard({
    String type = 'global',
    String period = 'alltime',
  }) async => null;

  @override
  Future<Response> claimChallenge(int challengeId) async =>
      const Response(statusCode: 200);

  @override
  Future<Response> claimPrize(int prizeId) async =>
      const Response(statusCode: 200);

  @override
  Future<Response> acknowledgeLevelUps({List<int>? transactionIds}) async =>
      const Response(statusCode: 200);
}

Challenge _challenge(int id, String status, {DateTime? expiresAt}) => Challenge(
  id: id,
  type: 'daily',
  title: 'Order something',
  description: '',
  xpReward: 50,
  status: status,
  expiresAt: expiresAt,
);

void main() {
  group('challenges `[]` crash (2026-09-27)', () {
    test('an empty PHP array for `challenges` parses as no challenges', () {
      final model = ChallengeModel.fromJson({
        'challenges': [],
        'has_daily': false,
        'has_weekly': false,
      });
      expect(model.dailyChallenges, isEmpty);
      expect(model.weeklyChallenges, isEmpty);
    });

    test('numbers arriving as strings still parse', () {
      final c = Challenge.fromJson({
        'id': '12',
        'xp_reward': '50',
        'challenge_type': 'min_order_amount',
        'progress': {'amount_spent': '120.5', 'target': '250'},
      });
      expect(c.id, 12);
      expect(c.xpReward, 50);
      expect(c.currentProgress, 120);
      expect(c.targetProgress, 250);
    });
  });

  group('X-13 · a failed fetch never wedges its spinner', () {
    test('a throwing service leaves the loading flag down', () async {
      final service = _Service()..challenges = [() => throw StateError('boom')];
      final xp = XpController(xpServiceInterface: service);
      await xp.getChallenges(reload: true);
      expect(xp.isChallengesLoading, isFalse);
      expect(xp.challengesFailed, isTrue);
    });

    test('a failed refresh keeps what was already shown', () async {
      final service =
          _Service()
            ..challenges = [
              () => ChallengeModel(dailyChallenges: [_challenge(1, 'active')]),
              () => null,
            ];
      final xp = XpController(xpServiceInterface: service);
      await xp.getChallenges(reload: true);
      await xp.getChallenges(reload: true);
      expect(xp.challengeModel?.dailyChallenges.single.id, 1);
      expect(xp.challengesFailed, isTrue);
    });
  });

  group('X-15 · a spent prize does not survive into the next order', () {
    test('the same basket after an order refetches and drops the selection',
        () async {
      final service = _Service();
      var spent = false;
      service.prizesFor =
          (_) =>
              spent
                  ? const []
                  : [
                    CheckoutPrize(
                      id: 9,
                      title: 'Free delivery',
                      type: 'free_delivery',
                    ),
                  ];
      final xp = XpController(xpServiceInterface: service);

      await xp.syncCheckoutPrizes(180);
      xp.selectCheckoutPrize(xp.checkoutPrizes.single);
      expect(xp.selectedCheckoutPrize?.id, 9);

      spent = true;
      xp.afterOrderPlaced();
      expect(xp.selectedCheckoutPrize, isNull);

      await xp.syncCheckoutPrizes(180);
      expect(service.checkoutRequests, [180, 180]);
      expect(xp.selectedCheckoutPrize, isNull);
    });
  });

  group('X-17 · a broken streak is not shown as alive', () {
    String day(int daysAgo) {
      final d = DateTime.now().subtract(Duration(days: daysAgo));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    test('last active yesterday keeps the streak', () {
      final s = UserStreakModel.fromJson({
        'current_streak': 5,
        'last_activity_date': day(1),
      });
      expect(s.currentStreak, 5);
    });

    test('last active three days ago is no streak', () {
      final s = UserStreakModel.fromJson({
        'current_streak': 5,
        'last_activity_date': day(3),
      });
      expect(s.currentStreak, 0);
    });
  });

  group('X-18 / X-29 · a challenge past its deadline is not active', () {
    test('expired "active" rows read as expired, with no time left', () {
      final c = _challenge(
        1,
        'active',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(c.isActive, isFalse);
      expect(c.isExpired, isTrue);
      expect(c.timeLeft, isNull);
    });

    test('a live challenge counts down from its own deadline', () {
      final c = _challenge(
        1,
        'active',
        expiresAt: DateTime.now().add(const Duration(hours: 3)),
      );
      expect(c.isActive, isTrue);
      expect(c.timeLeft!.inHours, 2); // 2h 59m…
    });
  });

  group('X-30 · a claimed quest stays on screen', () {
    test('the card survives the refetch that no longer returns it', () async {
      final service =
          _Service()
            ..challenges = [
              () => ChallengeModel(
                dailyChallenges: [_challenge(7, 'completed')],
              ),
              // After the claim the server returns nothing for today.
              () => ChallengeModel(),
            ];
      final xp = XpController(xpServiceInterface: service);
      await xp.getChallenges(reload: true);

      final ok = await xp.claimChallenge(7);
      expect(ok, isTrue);
      final daily = xp.challengeModel!.dailyChallenges;
      expect(daily.single.id, 7);
      expect(daily.single.isClaimed, isTrue);
      expect(xp.hasUnclaimedRewards, isFalse);
    });
  });

  group('X-23 · the cart estimate matches the server', () {
    test('per line, on the undiscounted unit price', () {
      final service =
          _Service()
            ..config = XpConfigModel(
              levelingEnabled: true,
              xpPerOrder: 20,
              xpPerReview: 30,
              xpPerCurrencyUnit: 0.1,
              multipliers: const {'food': 1.0},
            );
      final xp = XpController(xpServiceInterface: service);
      return xp.getXpConfig().then((_) {
        CartModel line(double price, double discounted, int qty) => CartModel(
          null,
          price,
          discounted,
          const [],
          const [],
          price - discounted,
          qty,
          const [],
          const [],
          false,
          null,
          null,
          null,
        );
        // Server: 20 + floor(95 × 1 × 0.1) + floor(33 × 3 × 0.1)
        //       = 20 + 9 + 9 = 38. The discounted price must not be used.
        final estimate = xp.estimateForCart([
          line(95, 80, 1),
          line(33, 30, 3),
        ], 'food');
        expect(estimate, 38);
      });
    });
  });
}
