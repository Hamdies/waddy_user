import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/domain/models/checkout_prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/reward_state.dart';
import 'package:waddy_app/features/xp/domain/models/xp_config_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_level_model.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service_interface.dart';

/// Part 5 of `docs/xp_module_plan.md` — the 2026-10-04 second pass. Each group
/// pins one finding so it cannot quietly come back.
class _Service implements XpServiceInterface {
  /// When set, `getLevelDetails` waits on it, so a test can hold a request in
  /// flight.
  Completer<void>? gate;
  int levelCalls = 0;
  Map<String, dynamic>? Function() level = () => null;

  @override
  Future<Map<String, dynamic>?> getLevelDetails() async {
    levelCalls++;
    final g = gate;
    if (g != null) await g.future;
    return level();
  }

  @override
  Future<ChallengeModel?> getChallenges() async => null;

  @override
  Future<List<CheckoutPrize>> getCheckoutPrizes(double orderAmount) async =>
      const [];

  @override
  Future<XpConfigModel?> getXpConfig() async => null;

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

Map<String, dynamic> _levelPayload({List<Map<String, dynamic>>? pending}) => {
  'current_level': 2,
  'current_xp': 120,
  'levels': const [],
  if (pending != null) 'pending_level_ups': pending,
};

void main() {
  group('X-31 · one reward state for every surface', () {
    RewardState of(String type, String? status, {DateTime? expiresAt}) =>
        RewardState.of(type: type, status: status, expiresAt: expiresAt);

    test('no instance is locked', () {
      expect(of('discount', null), RewardState.locked);
      expect(of('badge', null), RewardState.locked);
    });

    test('an expired prize is expired, not ready', () {
      expect(of('discount', 'expired'), RewardState.expired);
      final past = DateTime.now().subtract(const Duration(hours: 1));
      expect(of('discount', 'unlocked', expiresAt: past), RewardState.expired);
    });

    test('a claimed discount is ready to use, not used', () {
      expect(of('discount', 'claimed'), RewardState.use);
    });

    test('an unlocked free delivery is used, never claimed (X-26)', () {
      expect(of('free_delivery', 'unlocked'), RewardState.use);
    });

    test('an unlocked wallet credit or discount is claimable', () {
      expect(of('wallet_credit', 'unlocked'), RewardState.claim);
      expect(of('discount', 'unlocked'), RewardState.claim);
    });

    test('an earned badge is a badge, so it never lights the nav dot', () {
      expect(of('badge', 'unlocked'), RewardState.badge);
      final model = PrizeModel(
        usablePrizes: [
          Prize(id: 1, level: 2, type: 'badge', title: 'B', status: 'unlocked'),
        ],
      );
      expect(model.needsClaimPrizes, isEmpty);
      expect(model.livePrizes, isEmpty);
    });

    test('the level payload reads its status, not its flags', () {
      final expired = LevelPrize.fromJson({
        'id': 1,
        'prize_type': 'discount',
        'status': 'expired',
        'is_unlocked': true,
        'is_claimed': false,
      });
      expect(expired.rewardState, RewardState.expired);

      final unspent = LevelPrize.fromJson({
        'id': 2,
        'prize_type': 'discount',
        'status': 'claimed',
        'is_unlocked': true,
        'is_claimed': true,
      });
      expect(unspent.rewardState, RewardState.use);
    });

    test('a payload without `status` falls back to the flags', () {
      final p = LevelPrize.fromJson({
        'id': 3,
        'prize_type': 'wallet_credit',
        'is_unlocked': true,
        'is_claimed': false,
      });
      expect(p.rewardState, RewardState.claim);
    });
  });

  group('X-32 · prizes the server holds back are still listed', () {
    test('`waiting_prizes` is parsed into the owned list', () {
      final model = PrizeModel.fromJson({
        'usable_prizes': const [],
        'used_prizes': const [],
        'expired_prizes': const [],
        'waiting_prizes': [
          {
            'id': 9,
            'prize_type': 'free_delivery',
            'title': 'Free delivery',
            'status': 'claimed',
          },
        ],
      });
      expect(model.prizes.map((p) => p.id), [9]);
      expect(model.livePrizes.map((p) => p.id), [9]);
    });
  });

  group('X-34 · a level-up is celebrated once', () {
    test('a fetch before the ack does not re-queue a taken event', () async {
      final service = _Service()
        ..level =
            () => _levelPayload(
              pending: [
                {'transaction_id': 7, 'level': 3},
              ],
            );
      final controller = XpController(xpServiceInterface: service);

      await controller.getLevelDetails(reload: true);
      expect(controller.takePendingLevelUps().map((e) => e.transactionId), [
        7,
      ]);

      // The server still lists it: the ack goes out after the dialog closes.
      await controller.getLevelDetails(reload: true);
      expect(controller.pendingLevelUps, isEmpty);
    });

    test('a new level-up behind it still comes through', () async {
      var pending = [
        {'transaction_id': 7, 'level': 3},
      ];
      final service = _Service()..level = () => _levelPayload(pending: pending);
      final controller = XpController(xpServiceInterface: service);

      await controller.getLevelDetails(reload: true);
      controller.takePendingLevelUps();
      pending = [
        {'transaction_id': 7, 'level': 3},
        {'transaction_id': 8, 'level': 4},
      ];
      await controller.getLevelDetails(reload: true);
      expect(controller.pendingLevelUps.map((e) => e.transactionId), [8]);
    });
  });

  group('X-45 · one request per payload in flight', () {
    test('overlapping reloads share one request', () async {
      final service = _Service()
        ..gate = Completer<void>()
        ..level = () => _levelPayload();
      final controller = XpController(xpServiceInterface: service);

      final a = controller.getLevelDetails(reload: true);
      final b = controller.getLevelDetails(reload: true);
      service.gate!.complete();
      await Future.wait([a, b]);
      expect(service.levelCalls, 1);
    });

    test('a refresh after a change waits for a request of its own', () async {
      final service = _Service()
        ..gate = Completer<void>()
        ..level = () => _levelPayload();
      final controller = XpController(xpServiceInterface: service);

      final before = controller.getLevelDetails(reload: true);
      // A claim lands while that request is out: it carries the old state.
      final after1 = controller.getLevelDetails(reload: true, fresh: true);
      final after2 = controller.getLevelDetails(reload: true, fresh: true);
      final gate = service.gate!;
      service.gate = null;
      gate.complete();
      await Future.wait([before, after1, after2]);
      // The stale one, then exactly one follow-up shared by both callers.
      expect(service.levelCalls, 2);
    });

    test('logout forgets requests made under the old session', () async {
      final service = _Service()
        ..gate = Completer<void>()
        ..level = () => _levelPayload();
      final controller = XpController(xpServiceInterface: service);

      final old = controller.getLevelDetails(reload: true);
      controller.clearXpData();
      final next = controller.getLevelDetails(reload: true);
      service.gate!.complete();
      await Future.wait([old, next]);
      expect(service.levelCalls, 2);
    });
  });
}
