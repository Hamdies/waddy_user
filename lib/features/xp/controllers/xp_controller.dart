import 'package:get/get.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/xp/domain/models/xp_level_model.dart';
import 'package:waddy_app/features/xp/domain/models/level_up_event_model.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/checkout_prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_config_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_history_model.dart';
import 'package:waddy_app/features/xp/domain/models/user_streak_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service_interface.dart';

class XpController extends GetxController implements GetxService {
  final XpServiceInterface xpServiceInterface;

  XpController({required this.xpServiceInterface});

  // ============================================
  // REBUILD SCOPES
  // ============================================
  //
  // Every `update()` in this controller used to be bare, and the 28
  // `GetBuilder<XpController>` sites reach well past the XP tab — into
  // checkout, home, profile, menu and orders. A challenge-tab tap repainted
  // the checkout prize selector.
  //
  // These ids split the controller's state into the units the UI actually
  // subscribes to. A builder that passes one of them is woken only by the
  // fetches and actions that touch that state; a builder with no id still
  // sees everything, which is the right default for the few surfaces that
  // genuinely read across (the levels screen's masthead, say).

  /// Level, XP total, streak and the pending level-up queue.
  static const String idLevel = 'xp-level';

  /// Daily/weekly challenge lists, their loading flag, and the selected tab.
  static const String idChallenges = 'xp-challenges';

  /// Prize lists, their loading flag, and the selected filter.
  static const String idPrizes = 'xp-prizes';

  /// Leaderboard rows, the selected period and its loading flag.
  static const String idLeaderboard = 'xp-leaderboard';

  /// XP transaction history and its loading flag.
  static const String idHistory = 'xp-history';

  /// The checkout prize list, its loading flag and the current selection —
  /// the money path, so it is deliberately its own scope.
  static const String idCheckoutPrizes = 'xp-checkout-prizes';

  /// Server XP config: rates, multipliers, max level, the "ways to earn"
  /// values. Changes once per session, but several surfaces read it.
  static const String idConfig = 'xp-config';

  /// The nav badge's one bit: whether anything is claimable right now. Fired
  /// alongside [idChallenges] and [idPrizes], since both can flip it.
  static const String idBadge = 'xp-badge';

  /// Pull a human-readable message out of an API error response.
  /// Backend shape is `{errors: [{code, message}]}`; falls back to a top-level
  /// `message`, then the provided default.
  String _extractError(Response response, String fallback) {
    final body = response.body;
    if (body is Map) {
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty && errors.first is Map) {
        final msg = errors.first['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
      final msg = body['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return fallback;
  }

  // Current level state
  XpLevelModel? _currentLevel;
  XpLevelModel? get currentLevel => _currentLevel;

  // All levels for roadmap
  LevelsListModel? _levelsListModel;
  LevelsListModel? get levelsListModel => _levelsListModel;

  // Challenges
  ChallengeModel? _challengeModel;
  ChallengeModel? get challengeModel => _challengeModel;

  // Prizes
  PrizeModel? _prizeModel;
  PrizeModel? get prizeModel => _prizeModel;

  /// Whether the Rewards tab currently holds something the user can act on:
  /// a finished challenge or an unlocked prize waiting to be claimed.
  ///
  /// This backs the nav badge. A dot that is always lit is decoration, and it
  /// teaches people to ignore the one time it means something — so the badge
  /// is tied to a claim being available and nothing else. False until the
  /// challenge/prize calls land, which is the honest answer: we don't know yet.
  bool get hasUnclaimedRewards {
    if (_prizeModel?.claimablePrizes.isNotEmpty ?? false) return true;
    final ChallengeModel? challenges = _challengeModel;
    if (challenges == null) return false;
    return challenges.dailyChallenges.any((c) => c.canClaim) ||
        challenges.weeklyChallenges.any((c) => c.canClaim);
  }

  // Checkout prizes (available for free delivery at checkout)
  List<CheckoutPrize> _checkoutPrizes = [];
  List<CheckoutPrize> get checkoutPrizes => _checkoutPrizes;

  CheckoutPrize? _selectedCheckoutPrize;
  CheckoutPrize? get selectedCheckoutPrize => _selectedCheckoutPrize;

  // Loading states
  bool _isLevelLoading = false;
  bool get isLevelLoading => _isLevelLoading;

  bool _isLevelsLoading = false;
  bool get isLevelsLoading => _isLevelsLoading;

  bool _isChallengesLoading = false;
  bool get isChallengesLoading => _isChallengesLoading;

  bool _isPrizesLoading = false;
  bool get isPrizesLoading => _isPrizesLoading;

  int? _claimingChallengeId;
  bool get isClaimingChallenge => _claimingChallengeId != null;
  bool isClaimingChallengeId(int id) => _claimingChallengeId == id;

  int? _claimingPrizeId;
  bool get isClaimingPrize => _claimingPrizeId != null;
  bool isClaimingPrizeId(int id) => _claimingPrizeId == id;

  bool _isCheckoutPrizesLoading = false;
  bool get isCheckoutPrizesLoading => _isCheckoutPrizesLoading;

  /// The order amount the current [_checkoutPrizes] list was fetched for, or
  /// null if nothing has been fetched yet.
  ///
  /// Eligibility depends on the amount — the request carries `order_amount`
  /// and each `CheckoutPrize` carries `min_order_amount` — so caching on a
  /// boolean would freeze the list at whatever the cart was worth the first
  /// time checkout opened. A user who adds an item and crosses a prize's
  /// threshold would never be told they qualified; a user who removes one
  /// would keep a free-delivery prize they no longer qualify for, and
  /// `checkout_calculation_helper.dart` reads that selection straight into the
  /// order total. Keying on the amount is what makes both of those correct.
  double? _checkoutPrizesFetchedFor;

  bool get checkoutPrizesFetched => _checkoutPrizesFetchedFor != null;

  /// Amounts within this much of each other are the same cart as far as
  /// eligibility goes. Guards against refetching on float noise while staying
  /// far below any realistic `min_order_amount` step.
  static const double _checkoutAmountEpsilon = 0.01;

  // XP Config (for live XP counter)
  XpConfigModel? _xpConfig;
  XpConfigModel? get xpConfig => _xpConfig;

  bool _isXpConfigLoading = false;
  bool get isXpConfigLoading => _isXpConfigLoading;

  // Selected challenge tab (0 = daily, 1 = weekly)
  int _selectedChallengeTab = 0;
  int get selectedChallengeTab => _selectedChallengeTab;

  // Selected prize filter (0 = all, 1 = claimable, 2 = claimed, 3 = expired)
  int _selectedPrizeFilter = 0;
  int get selectedPrizeFilter => _selectedPrizeFilter;

  // History
  XpHistoryModel? _historyModel;
  XpHistoryModel? get historyModel => _historyModel;
  bool _isHistoryLoading = false;
  bool get isHistoryLoading => _isHistoryLoading;

  // Streak
  UserStreakModel? _streak;
  UserStreakModel? get streak => _streak;

  // Unacknowledged level-ups awaiting their "Level Up!" celebration. Populated
  // from `pending_level_ups` on each getLevelDetails; consumed + acknowledged by
  // the UI (see takePendingLevelUps / acknowledgeLevelUps).
  List<LevelUpEvent> _pendingLevelUps = [];
  List<LevelUpEvent> get pendingLevelUps => _pendingLevelUps;

  /// Hand the queued level-ups to the UI and clear them locally so a rebuild
  /// doesn't re-show the celebration. The server rows stay until the UI calls
  /// [acknowledgeLevelUps], so a crash mid-celebration still recovers next fetch.
  List<LevelUpEvent> takePendingLevelUps() {
    final events = _pendingLevelUps;
    _pendingLevelUps = [];
    return events;
  }

  /// Tell the server these level-ups have been celebrated so they're not
  /// re-sent. Fire-and-forget: a failure just means it replays next open.
  Future<void> acknowledgeLevelUps(List<int> transactionIds) async {
    if (transactionIds.isEmpty) return;
    try {
      await xpServiceInterface.acknowledgeLevelUps(
        transactionIds: transactionIds,
      );
    } catch (e, s) {
      // Replays next open, so the user loses nothing — but a server that keeps
      // rejecting acknowledgements means level-ups celebrate forever.
      swallow('xp level-up acknowledge', e, s, true);
    }
  }

  // Leaderboard
  XpLeaderboardModel? _leaderboardModel;
  XpLeaderboardModel? get leaderboardModel => _leaderboardModel;
  bool _isLeaderboardLoading = false;
  bool get isLeaderboardLoading => _isLeaderboardLoading;

  /// Max level from config (fallback 10)
  int get maxLevel => _xpConfig?.maxLevel ?? 10;

  /// Fetch challenges (daily & weekly)
  Future<void> getChallenges({bool reload = false}) async {
    if (_challengeModel != null && !reload) return;

    _isChallengesLoading = true;
    update([idChallenges]);

    _challengeModel = await xpServiceInterface.getChallenges();

    _isChallengesLoading = false;
    update([idChallenges, idBadge]);
  }

  /// Claim a completed challenge
  Future<bool> claimChallenge(int challengeId) async {
    _claimingChallengeId = challengeId;
    update([idChallenges]);

    Response response = await xpServiceInterface.claimChallenge(challengeId);

    _claimingChallengeId = null;

    if (response.statusCode == 200) {
      // Refresh challenges and level after claiming
      await getChallenges(reload: true);
      await getLevelDetails(reload: true);
      showCustomSnackBar('challenge_claimed_successfully'.tr, isError: false);
      update([idChallenges, idBadge]);
      return true;
    } else {
      showCustomSnackBar(
        _extractError(response, 'failed_to_claim_challenge'.tr),
      );
      update([idChallenges]);
      return false;
    }
  }

  /// Fetch prizes
  Future<void> getPrizes({bool reload = false}) async {
    if (_prizeModel != null && !reload) return;

    _isPrizesLoading = true;
    update([idPrizes]);

    _prizeModel = await xpServiceInterface.getPrizes();

    _isPrizesLoading = false;
    update([idPrizes, idBadge]);
  }

  /// Claim a prize (using user's prize instance ID, NOT prize_id)
  Future<bool> claimPrize(int prizeInstanceId) async {
    _claimingPrizeId = prizeInstanceId;
    update([idPrizes]);

    Response response = await xpServiceInterface.claimPrize(prizeInstanceId);

    _claimingPrizeId = null;

    if (response.statusCode == 200) {
      // Refresh prizes after claiming
      await getPrizes(reload: true);
      showCustomSnackBar('prize_claimed_successfully'.tr, isError: false);
      update([idPrizes, idBadge]);
      return true;
    } else {
      showCustomSnackBar(_extractError(response, 'failed_to_claim_prize'.tr));
      update([idPrizes]);
      return false;
    }
  }

  /// Bring the checkout prize list in line with the cart's current value.
  ///
  /// This is what checkout calls on every build: it is cheap when nothing has
  /// changed and refetches when the amount has moved, so eligibility and the
  /// order total cannot drift apart. Returns without touching the network when
  /// the amount is not worth a request or was already fetched.
  Future<void> syncCheckoutPrizes(double orderAmount) async {
    if (orderAmount <= 0) return;
    if (_isCheckoutPrizesLoading &&
        _inFlightCheckoutAmount != null &&
        (_inFlightCheckoutAmount! - orderAmount).abs() <
            _checkoutAmountEpsilon) {
      return;
    }
    if (_checkoutPrizesFetchedFor != null &&
        (_checkoutPrizesFetchedFor! - orderAmount).abs() <
            _checkoutAmountEpsilon) {
      return;
    }
    await getCheckoutPrizes(orderAmount);
  }

  /// The amount a fetch is currently in flight for, so two builds in the same
  /// frame don't both fire the same request.
  double? _inFlightCheckoutAmount;

  /// Fetch checkout prizes (free_delivery prizes available for current order
  /// amount). Prefer [syncCheckoutPrizes] from the UI — this always hits the
  /// network.
  Future<void> getCheckoutPrizes(double orderAmount) async {
    _isCheckoutPrizesLoading = true;
    _inFlightCheckoutAmount = orderAmount;
    update([idCheckoutPrizes]);

    _checkoutPrizes = await xpServiceInterface.getCheckoutPrizes(orderAmount);
    _checkoutPrizesFetchedFor = orderAmount;

    // Re-validate the selection against what the user actually qualifies for
    // now. This runs on every fetch, which is the point: the amount-keyed
    // cache is what guarantees a fetch happens when the cart changes.
    if (_selectedCheckoutPrize != null) {
      final stillAvailable = _checkoutPrizes.any(
        (p) => p.id == _selectedCheckoutPrize!.id,
      );
      if (!stillAvailable) {
        _selectedCheckoutPrize = null;
      }
    }

    _isCheckoutPrizesLoading = false;
    _inFlightCheckoutAmount = null;
    update([idCheckoutPrizes]);
  }

  /// Select a checkout prize for free delivery
  void selectCheckoutPrize(CheckoutPrize? prize) {
    _selectedCheckoutPrize = prize;
    update([idCheckoutPrizes]);
  }

  /// Clear selected checkout prize
  void clearSelectedCheckoutPrize() {
    _selectedCheckoutPrize = null;
    update([idCheckoutPrizes]);
  }

  /// Change challenge tab (daily/weekly)
  void changeChallengeTab(int index) {
    _selectedChallengeTab = index;
    update([idChallenges]);
  }

  /// Change prize filter
  void changePrizeFilter(int index) {
    _selectedPrizeFilter = index;
    update([idPrizes]);
  }

  /// Get filtered prizes based on selected filter
  List<Prize> get filteredPrizes {
    if (_prizeModel == null) return [];

    switch (_selectedPrizeFilter) {
      case 1: // Claimable
        return _prizeModel!.claimablePrizes;
      case 2: // Claimed
        return _prizeModel!.claimedPrizes;
      case 3: // Expired
        return _prizeModel!.expiredPrizes;
      default: // All
        return _prizeModel!.prizes;
    }
  }

  /// Get current challenges based on tab
  List<Challenge> get currentChallenges {
    if (_challengeModel == null) return [];

    return _selectedChallengeTab == 0
        ? _challengeModel!.dailyChallenges
        : _challengeModel!.weeklyChallenges;
  }

  /// Fetch XP config (for live XP counter)
  Future<void> getXpConfig({bool reload = false}) async {
    if (_xpConfig != null && !reload) {
      return;
    }

    _isXpConfigLoading = true;
    update([idConfig]);

    _xpConfig = await xpServiceInterface.getXpConfig();

    _isXpConfigLoading = false;
    update([idConfig]);
  }

  /// Calculate estimated XP for a whole-order amount.
  /// Returns 0 until the config has loaded, rather than showing a guessed
  /// value that may not match what the server will actually award.
  int calculateEstimatedXp(double orderAmount, String? moduleType) {
    if (_xpConfig == null) return 0;
    return _xpConfig!.calculateEstimatedXp(orderAmount, moduleType);
  }

  /// Calculate estimated XP from cart line items — matches the backend's
  /// per-item floor exactly, so the cart/checkout promise doesn't overshoot.
  int calculateEstimatedXpForItems(
    List<({double price, int quantity})> lines,
    String? moduleType,
  ) {
    if (_xpConfig == null) return 0;
    return _xpConfig!.calculateEstimatedXpForItems(lines, moduleType);
  }

  /// Fetch merged level details (replaces separate getCurrentLevel + getAllLevels)
  Future<void> getLevelDetails({bool reload = false}) async {
    if (_currentLevel != null && _levelsListModel != null && !reload) return;

    _isLevelLoading = true;
    _isLevelsLoading = true;
    update([idLevel]);

    final data = await xpServiceInterface.getLevelDetails();

    if (data != null) {
      _currentLevel = XpLevelModel.fromJson(data);
      _levelsListModel = LevelsListModel.fromJson(data);

      // Parse streak if present
      if (data['streak'] != null) {
        _streak = UserStreakModel.fromJson(data['streak']);
      }

      // Queue any level-ups the server says we haven't celebrated yet.
      final pending = data['pending_level_ups'];
      if (pending is List) {
        _pendingLevelUps =
            pending
                .whereType<Map<String, dynamic>>()
                .map(LevelUpEvent.fromJson)
                .toList();
      }
    }

    _isLevelLoading = false;
    _isLevelsLoading = false;
    update([idLevel]);
  }

  /// Fetch XP history
  Future<void> getHistory({
    bool reload = false,
    int limit = 20,
    int offset = 0,
  }) async {
    if (_historyModel != null && !reload && offset == 0) return;

    _isHistoryLoading = true;
    update([idHistory]);

    final result = await xpServiceInterface.getHistory(
      limit: limit,
      offset: offset,
    );

    if (offset > 0 && _historyModel != null && result != null) {
      // Append for pagination
      _historyModel = XpHistoryModel(
        history: [..._historyModel!.history, ...result.history],
        totalEarned: result.totalEarned,
        totalItems: result.totalItems,
      );
    } else {
      _historyModel = result;
    }

    _isHistoryLoading = false;
    update([idHistory]);
  }

  /// Selected leaderboard period: 'alltime' | 'weekly' | 'monthly'.
  String _leaderboardPeriod = 'alltime';
  String get leaderboardPeriod => _leaderboardPeriod;

  /// Fetch leaderboard for the current (or given) period.
  Future<void> getLeaderboard({
    bool reload = false,
    String type = 'global',
    String? period,
  }) async {
    if (period != null && period != _leaderboardPeriod) {
      _leaderboardPeriod = period;
      reload = true;
    }
    if (_leaderboardModel != null && !reload) return;

    _isLeaderboardLoading = true;
    update([idLeaderboard]);

    _leaderboardModel = await xpServiceInterface.getLeaderboard(
      type: type,
      period: _leaderboardPeriod,
    );

    _isLeaderboardLoading = false;
    update([idLeaderboard]);
  }

  /// Switch the leaderboard period and refetch.
  Future<void> changeLeaderboardPeriod(String period) async {
    if (period == _leaderboardPeriod) return;
    await getLeaderboard(reload: true, period: period);
  }

  /// Clear all data (on logout)
  void clearXpData() {
    _currentLevel = null;
    _levelsListModel = null;
    _challengeModel = null;
    _prizeModel = null;
    _checkoutPrizes = [];
    _selectedCheckoutPrize = null;
    _checkoutPrizesFetchedFor = null;
    _inFlightCheckoutAmount = null;
    _xpConfig = null;
    _historyModel = null;
    _streak = null;
    _leaderboardModel = null;
    _pendingLevelUps = [];
    update();
  }

  /// Initialize all XP data (uses merged endpoint)
  Future<void> initializeXpData() async {
    await Future.wait([
      getLevelDetails(reload: true),
      getChallenges(reload: true),
    ]);
  }

  // ============================================
  // NEXT REWARD HELPERS (for cart bar display)
  // ============================================

  /// Get the next unclaimed reward from upcoming levels
  LevelPrize? get nextReward {
    if (_levelsListModel == null || _currentLevel == null) return null;

    final currentLvl = _currentLevel!.currentLevel;

    // Look through levels higher than current
    for (final level in _levelsListModel!.levels) {
      if (level.level > currentLvl && level.prizes.isNotEmpty) {
        // Return first unclaimed prize from this level
        for (final prize in level.prizes) {
          if (!prize.isClaimed) {
            return prize;
          }
        }
      }
    }
    return null;
  }

  /// Get the level number where the next reward is
  int? get nextRewardLevel {
    if (_levelsListModel == null || _currentLevel == null) return null;

    final currentLvl = _currentLevel!.currentLevel;

    for (final level in _levelsListModel!.levels) {
      if (level.level > currentLvl && level.prizes.isNotEmpty) {
        for (final prize in level.prizes) {
          if (!prize.isClaimed) {
            return level.level;
          }
        }
      }
    }
    return null;
  }

  /// Get XP needed to reach the next reward
  int get xpToNextReward {
    if (_levelsListModel == null || _currentLevel == null) return 0;

    final currentXp = _currentLevel!.currentXp;
    final currentLvl = _currentLevel!.currentLevel;

    // Find the level with the next reward
    for (final level in _levelsListModel!.levels) {
      if (level.level > currentLvl && level.prizes.isNotEmpty) {
        for (final prize in level.prizes) {
          if (!prize.isClaimed) {
            // XP needed = level's XP requirement - current XP
            return (level.xpRequired - currentXp).clamp(0, level.xpRequired);
          }
        }
      }
    }
    return _currentLevel!.xpToNextLevel;
  }

  /// Get emoji icon for a reward type
  String getRewardIcon(String type) {
    switch (type.toLowerCase()) {
      case 'free_delivery':
        return '🚚';
      case 'discount':
        return '💰';
      case 'wallet_credit':
        return '💳';
      case 'badge':
        return '🏅';
      case 'free_item':
        return '🎁';
      default:
        return '🎯';
    }
  }

  /// Get readable name for a reward type
  String getRewardName(String type) {
    switch (type.toLowerCase()) {
      case 'free_delivery':
        return 'Free Delivery';
      case 'discount':
        return 'Discount';
      case 'wallet_credit':
        return 'Wallet Credit';
      case 'badge':
        return 'Badge';
      case 'free_item':
        return 'Free Item';
      default:
        return 'Reward';
    }
  }
}
