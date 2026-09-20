import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/domain/models/checkout_prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_config_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_history_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service_interface.dart';

/// Phase 0 of `docs/xp_module_plan.md` — the safety net, written before the
/// fixes so the findings are visible as failures rather than as prose.
///
/// Four groups, matching the plan:
///   - `calculateEstimatedXpForItems` against the backend's per-item floor,
///     because an overshoot here is a promise broken to the customer at
///     checkout (`X-12`).
///   - `xpToNextReward` across its three branches, including the fallback
///     nobody exercises (`X-12`).
///   - `hasUnclaimedRewards`, which drives the nav badge (`X-12`).
///   - checkout-prize staleness (`X-02`) — **expected to fail today**. The
///     cache latches on a boolean, so the second fetch at a different order
///     amount never happens and a stale free-delivery selection survives into
///     the total.
class _FakeXpService implements XpServiceInterface {
  _FakeXpService({this.config, this.challenges, this.prizes});

  final XpConfigModel? config;
  final ChallengeModel? challenges;
  final PrizeModel? prizes;

  /// What the server would return for each order amount. `getCheckoutPrizes`
  /// answers from here, so a test can model a threshold the cart crosses.
  List<CheckoutPrize> Function(double orderAmount) prizesFor =
      (_) => const <CheckoutPrize>[];

  /// Every amount the controller actually asked the server about. The `X-02`
  /// test reads this: a cart that changed amount should appear twice.
  final List<double> checkoutPrizeRequests = <double>[];

  @override
  Future<List<CheckoutPrize>> getCheckoutPrizes(double orderAmount) async {
    checkoutPrizeRequests.add(orderAmount);
    return prizesFor(orderAmount);
  }

  @override
  Future<XpConfigModel?> getXpConfig() async => config;

  @override
  Future<Map<String, dynamic>?> getLevelDetails() async => null;

  @override
  Future<ChallengeModel?> getChallenges() async => challenges;

  @override
  Future<PrizeModel?> getPrizes() async => prizes;

  @override
  Future<XpHistoryModel?> getHistory({int limit = 20, int offset = 0}) async =>
      null;

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

/// The config the estimate tests measure against: a flat 10 XP per order and
/// 0.1 XP per currency unit, with food at a 2× multiplier.
XpConfigModel _config({
  bool enabled = true,
  int xpPerOrder = 10,
  double rate = 0.1,
  Map<String, double> multipliers = const {'food': 2.0},
}) {
  return XpConfigModel(
    levelingEnabled: enabled,
    xpPerOrder: xpPerOrder,
    xpPerReview: 5,
    xpPerCurrencyUnit: rate,
    multipliers: multipliers,
  );
}

Challenge _challenge({required int id, required String status}) {
  return Challenge(
    id: id,
    type: 'daily',
    title: 'Order something',
    description: 'Place one order today',
    xpReward: 20,
    status: status,
  );
}

Prize _prize({required int id, required String status, DateTime? expiresAt}) {
  return Prize(
    id: id,
    level: 3,
    type: 'free_delivery',
    title: 'Free delivery',
    status: status,
    expiresAt: expiresAt,
  );
}

CheckoutPrize _checkoutPrize({required int id, double? minOrderAmount}) {
  return CheckoutPrize(
    id: id,
    title: 'Free delivery',
    type: 'free_delivery',
    minOrderAmount: minOrderAmount,
  );
}

void main() {
  tearDown(Get.reset);

  // ───────────────────────────────────────────────────────────────
  // X-12 · the estimate the cart promises
  // ───────────────────────────────────────────────────────────────
  //
  // The backend floors XP per line. `calculateEstimatedXp` floors once over
  // the whole order, which reads high — that difference is why the per-item
  // variant exists, and it is what these pin.
  group('X-12 · estimated XP', () {
    late XpController controller;

    setUp(() async {
      controller = XpController(
        xpServiceInterface: _FakeXpService(config: _config()),
      );
      await controller.getXpConfig();
    });

    test('per-item floors each line, not the total', () {
      // 3 lines of 15.5 at 2× and 0.1/unit = 3.1 each → floor 3 → 9 + flat 10.
      final lines = <({double price, int quantity})>[
        (price: 15.5, quantity: 1),
        (price: 15.5, quantity: 1),
        (price: 15.5, quantity: 1),
      ];
      expect(controller.calculateEstimatedXpForItems(lines, 'food'), 19);
    });

    test('the whole-order estimate overshoots the same basket', () {
      // 46.5 at 2× and 0.1/unit = 9.3 → floor 9 → 19 … but per-line it is 19
      // too here; the gap opens on fractions that survive the sum.
      final lines = <({double price, int quantity})>[
        (price: 10.7, quantity: 1),
        (price: 10.7, quantity: 1),
      ];
      // Per line: 2.14 → 2 each → 4 + 10 = 14.
      expect(controller.calculateEstimatedXpForItems(lines, 'food'), 14);
      // Whole order: 21.4 × 0.2 = 4.28 → 4 + 10 = 14 — equal here, but the
      // aggregate can never read *lower*, which is the property that matters.
      expect(
        controller.calculateEstimatedXp(21.4, 'food'),
        greaterThanOrEqualTo(
          controller.calculateEstimatedXpForItems(lines, 'food'),
        ),
      );
    });

    test('quantity multiplies inside the floor', () {
      // 3 × 15.5 on one line = 46.5 at 2× and 0.1 = 9.3 → floor 9 → 19.
      final lines = <({double price, int quantity})>[
        (price: 15.5, quantity: 3),
      ];
      expect(controller.calculateEstimatedXpForItems(lines, 'food'), 19);
    });

    test('an unknown module gets no multiplier', () {
      final lines = <({double price, int quantity})>[(price: 100, quantity: 1)];
      expect(controller.calculateEstimatedXpForItems(lines, 'grocery'), 20);
    });

    test('returns 0 before the config lands, rather than guessing', () {
      final bare = XpController(xpServiceInterface: _FakeXpService());
      expect(
        bare.calculateEstimatedXpForItems(<({double price, int quantity})>[
          (price: 100, quantity: 1),
        ], 'food'),
        0,
      );
      expect(bare.calculateEstimatedXp(100, 'food'), 0);
    });

    test('levelling disabled awards nothing, not the flat bonus', () async {
      final off = XpController(
        xpServiceInterface: _FakeXpService(config: _config(enabled: false)),
      );
      await off.getXpConfig();
      expect(
        off.calculateEstimatedXpForItems(<({double price, int quantity})>[
          (price: 100, quantity: 1),
        ], 'food'),
        0,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────
  // X-12 · the cart bar's "next prize" arithmetic
  // ───────────────────────────────────────────────────────────────
  group('X-12 · xpToNextReward', () {
    /// Build a controller whose level state is already populated, by feeding
    /// `getLevelDetails` the server shape it parses.
    Future<XpController> withLevels({
      required int currentLevel,
      required int currentXp,
      required int xpToNextLevel,
      required List<Map<String, dynamic>> levels,
    }) async {
      final service = _FakeLevelService({
        'current_level': currentLevel,
        'current_xp': currentXp,
        'xp_to_next_level': xpToNextLevel,
        'levels': levels,
        'all_levels': levels,
      });
      final controller = XpController(xpServiceInterface: service);
      await controller.getLevelDetails();
      return controller;
    }

    Map<String, dynamic> level(
      int number, {
      required int xpRequired,
      List<Map<String, dynamic>> prizes = const [],
    }) {
      return {
        'level_number': number,
        'name': 'Level $number',
        'xp_required': xpRequired,
        'prizes': prizes,
      };
    }

    Map<String, dynamic> prize({required int id, required bool claimed}) {
      return {
        'id': id,
        'type': 'free_delivery',
        'title': 'Free delivery',
        'is_claimed': claimed,
      };
    }

    test('an unclaimed prize ahead gives the XP gap to its level', () async {
      final controller = await withLevels(
        currentLevel: 2,
        currentXp: 150,
        xpToNextLevel: 50,
        levels: [
          level(1, xpRequired: 0),
          level(2, xpRequired: 100),
          level(3, xpRequired: 200, prizes: [prize(id: 1, claimed: false)]),
        ],
      );
      expect(controller.xpToNextReward, 50);
      expect(controller.nextRewardLevel, 3);
      expect(controller.nextReward?.id, 1);
    });

    test('a claimed prize is skipped for the next unclaimed one', () async {
      final controller = await withLevels(
        currentLevel: 2,
        currentXp: 150,
        xpToNextLevel: 50,
        levels: [
          level(2, xpRequired: 100),
          level(3, xpRequired: 200, prizes: [prize(id: 1, claimed: true)]),
          level(4, xpRequired: 400, prizes: [prize(id: 2, claimed: false)]),
        ],
      );
      expect(controller.nextRewardLevel, 4);
      expect(controller.xpToNextReward, 250);
    });

    test('no prize ahead falls back to the plain next level', () async {
      final controller = await withLevels(
        currentLevel: 2,
        currentXp: 150,
        xpToNextLevel: 50,
        levels: [level(2, xpRequired: 100), level(3, xpRequired: 200)],
      );
      expect(controller.nextReward, isNull);
      expect(controller.nextRewardLevel, isNull);
      expect(controller.xpToNextReward, 50);
    });

    test('an already-passed requirement clamps at 0, never negative', () async {
      // The user has more XP than the prize level asks for — the level-up
      // hasn't been processed yet. The bar must not read a negative gap.
      final controller = await withLevels(
        currentLevel: 2,
        currentXp: 500,
        xpToNextLevel: 0,
        levels: [
          level(2, xpRequired: 100),
          level(9, xpRequired: 300, prizes: [prize(id: 1, claimed: false)]),
        ],
      );
      expect(controller.xpToNextReward, 0);
    });

    test('everything is null before the fetches land', () {
      final bare = XpController(xpServiceInterface: _FakeXpService());
      expect(bare.nextReward, isNull);
      expect(bare.nextRewardLevel, isNull);
      expect(bare.xpToNextReward, 0);
    });
  });

  // ───────────────────────────────────────────────────────────────
  // X-12 · the nav badge
  // ───────────────────────────────────────────────────────────────
  //
  // The controller documents why this is tied to a claimable action rather
  // than lit permanently. That rationale is only worth anything if the false
  // case stays false.
  group('X-12 · hasUnclaimedRewards', () {
    /// Populate the controller the way the app does — through the fetches —
    /// so the getter is exercised over state the parse path could produce.
    Future<XpController> loaded({
      ChallengeModel? challenges,
      PrizeModel? prizes,
    }) async {
      final controller = XpController(
        xpServiceInterface: _FakeXpService(
          challenges: challenges,
          prizes: prizes,
        ),
      );
      await controller.getChallenges();
      await controller.getPrizes();
      return controller;
    }

    test('false before the fetches land — the honest answer', () {
      final controller = XpController(xpServiceInterface: _FakeXpService());
      expect(controller.hasUnclaimedRewards, isFalse);
    });

    test('false when challenges are loaded but none is claimable', () async {
      final controller = await loaded(
        challenges: ChallengeModel(
          dailyChallenges: [_challenge(id: 1, status: 'active')],
          weeklyChallenges: [_challenge(id: 2, status: 'claimed')],
        ),
      );
      expect(controller.hasUnclaimedRewards, isFalse);
    });

    test('true on a completed daily challenge', () async {
      final controller = await loaded(
        challenges: ChallengeModel(
          dailyChallenges: [_challenge(id: 1, status: 'completed')],
        ),
      );
      expect(controller.hasUnclaimedRewards, isTrue);
    });

    test('true on a completed weekly challenge', () async {
      final controller = await loaded(
        challenges: ChallengeModel(
          weeklyChallenges: [_challenge(id: 2, status: 'completed')],
        ),
      );
      expect(controller.hasUnclaimedRewards, isTrue);
    });

    test('true on a claimable prize even with no challenges', () async {
      final controller = await loaded(
        prizes: PrizeModel(usablePrizes: [_prize(id: 1, status: 'unlocked')]),
      );
      expect(controller.hasUnclaimedRewards, isTrue);
    });

    test('false when every prize is already used', () async {
      final controller = await loaded(
        prizes: PrizeModel(usablePrizes: [_prize(id: 1, status: 'used')]),
      );
      expect(controller.hasUnclaimedRewards, isFalse);
    });

    test('an expired unlocked prize is not claimable', () async {
      final controller = await loaded(
        prizes: PrizeModel(
          usablePrizes: [
            _prize(
              id: 1,
              status: 'unlocked',
              expiresAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
          ],
        ),
      );
      expect(controller.hasUnclaimedRewards, isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────
  // X-01 · rebuild scoping
  // ───────────────────────────────────────────────────────────────
  //
  // The reason this matters is reach: the 26 `GetBuilder<XpController>` sites
  // run through checkout, home, profile, menu and orders, so a bare `update()`
  // from a challenge-tab tap used to repaint the checkout prize block.
  //
  // `GetBuilder` subscribes by id, so the property worth pinning is which ids
  // each action fires. These assert the two the plan calls the cheapest wins —
  // a tab tap and a filter change must not name `idCheckoutPrizes` — and that
  // the money path stays isolated in the other direction.
  group('X-01 · update() is scoped', () {
    /// Record the ids each action notifies, by subscribing to the controller
    /// the way `GetBuilder` does.
    List<Object> idsFiredBy(void Function(XpController) action) {
      final controller = XpController(xpServiceInterface: _FakeXpService());
      final fired = <Object>[];
      controller.addListenerId(XpController.idLevel, () {
        fired.add(XpController.idLevel);
      });
      controller.addListenerId(XpController.idChallenges, () {
        fired.add(XpController.idChallenges);
      });
      controller.addListenerId(XpController.idPrizes, () {
        fired.add(XpController.idPrizes);
      });
      controller.addListenerId(XpController.idCheckoutPrizes, () {
        fired.add(XpController.idCheckoutPrizes);
      });
      controller.addListenerId(XpController.idLeaderboard, () {
        fired.add(XpController.idLeaderboard);
      });
      action(controller);
      return fired;
    }

    test('a challenge tab tap does not touch checkout', () {
      final fired = idsFiredBy((c) => c.changeChallengeTab(1));
      expect(fired, [XpController.idChallenges]);
    });

    test('a prize filter change does not touch checkout', () {
      final fired = idsFiredBy((c) => c.changePrizeFilter(2));
      expect(fired, [XpController.idPrizes]);
    });

    test('selecting a checkout prize wakes only checkout', () {
      final fired = idsFiredBy(
        (c) =>
            c.selectCheckoutPrize(_checkoutPrize(id: 1, minOrderAmount: 100)),
      );
      expect(fired, [XpController.idCheckoutPrizes]);
    });

    test('clearing the selection wakes only checkout', () {
      final fired = idsFiredBy((c) => c.clearSelectedCheckoutPrize());
      expect(fired, [XpController.idCheckoutPrizes]);
    });

    test(
      'a checkout fetch never wakes the levels or leaderboard surfaces',
      () async {
        final service = _FakeXpService();
        service.prizesFor = (_) => <CheckoutPrize>[_checkoutPrize(id: 7)];
        final controller = XpController(xpServiceInterface: service);

        var levelRebuilds = 0;
        var leaderboardRebuilds = 0;
        var checkoutRebuilds = 0;
        controller.addListenerId(XpController.idLevel, () => levelRebuilds++);
        controller.addListenerId(
          XpController.idLeaderboard,
          () => leaderboardRebuilds++,
        );
        controller.addListenerId(
          XpController.idCheckoutPrizes,
          () => checkoutRebuilds++,
        );

        await controller.syncCheckoutPrizes(200);

        expect(checkoutRebuilds, greaterThan(0));
        expect(levelRebuilds, 0);
        expect(leaderboardRebuilds, 0);
      },
    );

    // The badge is the one cross-cutting bit: both fetches can flip it, so
    // both must name it or the nav dot goes stale.
    test('the challenge and prize fetches both wake the nav badge', () async {
      for (final fetch in <Future<void> Function(XpController)>[
        (c) => c.getChallenges(),
        (c) => c.getPrizes(),
      ]) {
        final controller = XpController(xpServiceInterface: _FakeXpService());
        var badgeRebuilds = 0;
        controller.addListenerId(XpController.idBadge, () => badgeRebuilds++);
        await fetch(controller);
        expect(badgeRebuilds, greaterThan(0));
      }
    });
  });

  // ───────────────────────────────────────────────────────────────
  // X-02 · checkout prizes go stale when the cart changes
  // ───────────────────────────────────────────────────────────────
  //
  // EXPECTED TO FAIL before Phase 1.
  //
  // `getCheckoutPrizes` itself always hits the network; the latch lives in the
  // caller. `bottom_section.dart:95` gates the fetch on `checkoutPrizesFetched`,
  // which `getCheckoutPrizes` sets true and nothing ever sets back. So the
  // screen asks once, at whatever the amount happened to be, and never again.
  //
  // `syncCheckoutPrizes` below is the shape Phase 1 should give the controller:
  // the caller hands it the current amount and the controller decides whether
  // that is new information. These tests drive it, so they pin the fix rather
  // than the current gate's internals.
  //
  // The second test is the money one: a selected free-delivery prize the user
  // no longer qualifies for stays selected, and
  // `checkout_calculation_helper.dart:473` reads it straight into the total.
  group('X-02 · checkout prizes track the order amount', () {
    late _FakeXpService service;
    late XpController controller;

    /// A free-delivery prize that only exists at or above EGP 150.
    setUp(() {
      service = _FakeXpService();
      service.prizesFor =
          (amount) =>
              amount >= 150
                  ? <CheckoutPrize>[_checkoutPrize(id: 7, minOrderAmount: 150)]
                  : const <CheckoutPrize>[];
      controller = XpController(xpServiceInterface: service);
    });

    test('crossing the threshold upward surfaces the prize', () async {
      await controller.syncCheckoutPrizes(120);
      expect(controller.checkoutPrizes, isEmpty);

      // The user adds an item. The cart is now worth the prize.
      await controller.syncCheckoutPrizes(180);
      expect(service.checkoutPrizeRequests, [120, 180]);
      expect(controller.checkoutPrizes.single.id, 7);
    });

    test('falling below the threshold clears a stale selection', () async {
      await controller.syncCheckoutPrizes(180);
      controller.selectCheckoutPrize(controller.checkoutPrizes.single);
      expect(controller.selectedCheckoutPrize, isNotNull);

      // The user removes an item, dropping under the minimum.
      await controller.syncCheckoutPrizes(120);
      expect(controller.checkoutPrizes, isEmpty);
      expect(
        controller.selectedCheckoutPrize,
        isNull,
        reason:
            'a free-delivery prize the user no longer qualifies for must '
            'not survive into the order total',
      );
    });

    test('the same amount does not re-hit the network', () async {
      await controller.syncCheckoutPrizes(180);
      await controller.syncCheckoutPrizes(180);
      expect(service.checkoutPrizeRequests, [180]);
    });

    test('a zero amount is not worth a request', () async {
      await controller.syncCheckoutPrizes(0);
      expect(service.checkoutPrizeRequests, isEmpty);
    });

    test('a concurrent sync at the same amount only asks once', () async {
      await Future.wait([
        controller.syncCheckoutPrizes(180),
        controller.syncCheckoutPrizes(180),
      ]);
      expect(service.checkoutPrizeRequests, [180]);
    });
  });
}

/// A service that answers `getLevelDetails` with a fixed server payload, so
/// the reward getters can be exercised through the real parse path.
class _FakeLevelService extends _FakeXpService {
  _FakeLevelService(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<Map<String, dynamic>?> getLevelDetails() async => payload;
}
