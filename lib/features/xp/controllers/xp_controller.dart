import 'package:get/get.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/xp/domain/models/xp_level_model.dart';
import 'package:waddy_app/features/xp/domain/models/level_up_event_model.dart';
import 'package:waddy_app/features/xp/domain/models/challenge_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/checkout_prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_config_model.dart';
import 'package:waddy_app/features/xp/domain/models/user_streak_model.dart';
import 'package:waddy_app/features/xp/domain/models/xp_json.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service_interface.dart';

/// Things that change XP state, for [XpController.refreshAfter].
enum XpEvent { orderPlaced, orderDelivered, prizeClaimed, challengeClaimed }

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
    // No body: ApiClient's own failure (status 1 = no connection) carries its
    // message in statusText.
    final text = response.statusText;
    if (response.statusCode == 1 && text != null && text.isNotEmpty) {
      return text;
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
    // Only prizes where claiming does something: a free delivery has no claim
    // step, so counting it lit the badge until a no-op claim (X-26).
    if (_prizeModel?.needsClaimPrizes.isNotEmpty ?? false) return true;
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

  // Whether the last attempt at each payload failed (non-200, or a payload
  // that would not parse). A failed *refresh* keeps the data already shown;
  // these let a screen with nothing to show say "couldn't load" instead of
  // rendering an outage as an empty list (X-13).
  bool _challengesFailed = false;
  bool get challengesFailed => _challengesFailed;
  bool _prizesFailed = false;
  bool get prizesFailed => _prizesFailed;

  /// When each payload last arrived, for [revalidate].
  final Map<String, DateTime> _fetchedAt = {};

  /// A tab visit refetches anything older than this. Short enough that an
  /// order delivered a minute ago shows up, long enough that flicking between
  /// tabs is free.
  static const Duration _staleAfter = Duration(seconds: 30);

  bool _isStale(String id) {
    final at = _fetchedAt[id];
    return at == null || DateTime.now().difference(at) > _staleAfter;
  }

  // ============================================
  // SINGLE FLIGHT (X-45)
  // ============================================
  //
  // A tab visit, a claim's refresh and a push could each fire the same fetch,
  // and GetConnect gives no ordering, so an older response could land last
  // and overwrite a newer one. Now one request per payload is in flight.
  //
  // Joining is only safe when the caller wants "recent". After a mutation
  // (a claim, a delivered order), a request that left *before* it carries the
  // old state, so [fresh] callers queue one follow-up fetch behind the
  // running one instead. Any number of fresh callers share that one
  // follow-up.

  final Map<String, Future<void>> _inFlight = {};
  final Map<String, Future<void>> _queued = {};

  Future<void> _single(
    String id,
    Future<void> Function() fetch, {
    bool fresh = false,
  }) {
    final running = _inFlight[id];
    if (running != null) {
      if (!fresh) return running;
      return _queued[id] ??= running.then((_) {
        _queued.remove(id);
        return _single(id, fetch);
      });
    }
    // Registered before any `then` above, so the slot is free by the time a
    // queued follow-up starts. Removes only its own entry: logout clears the
    // map, and a request started after that must not be evicted by an older
    // one finishing.
    late final Future<void> f;
    f = fetch().whenComplete(() {
      if (identical(_inFlight[id], f)) _inFlight.remove(id);
    });
    _inFlight[id] = f;
    return f;
  }

  /// Challenges claimed today, kept on screen in their "claimed" state. The
  /// server stops returning a challenge once it is claimed and assigns the
  /// next one only after midnight, so without this the card vanishes the
  /// moment its reward lands (X-30).
  final List<Challenge> _claimedToday = [];
  DateTime? _claimedTodayDate;

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
    _celebratedIds.addAll(events.map((e) => e.transactionId));
    return events;
  }

  /// Level-ups already handed to the UI this session (X-34). Kept for the
  /// session rather than cleared on ack: an ack that fails replays next app
  /// open, which is the documented recovery, not a mid-session repeat.
  final Set<int> _celebratedIds = {};

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
  Future<void> getChallenges({bool reload = false, bool fresh = false}) async {
    if (_challengeModel != null && !reload) return;
    return _single(idChallenges, _fetchChallenges, fresh: fresh);
  }

  Future<void> _fetchChallenges() async {
    _isChallengesLoading = true;
    update([idChallenges]);

    try {
      final result = await xpServiceInterface.getChallenges();
      _challengesFailed = result == null;
      if (result != null) {
        _challengeModel = _withClaimedToday(result);
        _fetchedAt[idChallenges] = DateTime.now();
      }
    } catch (e, s) {
      _challengesFailed = true;
      swallow('xp challenges fetch', e, s, true);
    } finally {
      _isChallengesLoading = false;
      update([idChallenges, idBadge]);
    }
  }

  /// Merge today's claimed challenges back into a fetched model, dropping them
  /// once the day has turned.
  ChallengeModel _withClaimedToday(ChallengeModel model) {
    final now = DateTime.now();
    final d = _claimedTodayDate;
    if (d == null ||
        d.year != now.year ||
        d.month != now.month ||
        d.day != now.day) {
      _claimedToday.clear();
      return model;
    }
    List<Challenge> merge(List<Challenge> fetched, String type) => [
      ...fetched,
      ..._claimedToday.where(
        (c) => c.type == type && fetched.every((f) => f.id != c.id),
      ),
    ];
    return ChallengeModel(
      dailyChallenges: merge(model.dailyChallenges, 'daily'),
      weeklyChallenges: merge(model.weeklyChallenges, 'weekly'),
      dailyResetTime: model.dailyResetTime,
      weeklyResetTime: model.weeklyResetTime,
    );
  }

  Challenge? _findChallenge(int id) {
    final model = _challengeModel;
    if (model == null) return null;
    for (final c in [...model.dailyChallenges, ...model.weeklyChallenges]) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Claim a completed challenge
  Future<bool> claimChallenge(int challengeId) async {
    _claimingChallengeId = challengeId;
    update([idChallenges]);

    Response response = await xpServiceInterface.claimChallenge(challengeId);

    _claimingChallengeId = null;

    if (response.statusCode == 200) {
      // Keep the card on screen as claimed (X-30), then refresh what the claim
      // changed in parallel (X-20). A level-up it caused lands in
      // [pendingLevelUps] for the caller to celebrate.
      final claimed = _findChallenge(challengeId);
      if (claimed != null) {
        _claimedTodayDate = DateTime.now();
        _claimedToday
          ..removeWhere((c) => c.id == challengeId)
          ..add(claimed.asClaimed());
        final model = _challengeModel;
        if (model != null) {
          List<Challenge> mark(List<Challenge> list) => [
            for (final c in list) c.id == challengeId ? c.asClaimed() : c,
          ];
          _challengeModel = ChallengeModel(
            dailyChallenges: mark(model.dailyChallenges),
            weeklyChallenges: mark(model.weeklyChallenges),
            dailyResetTime: model.dailyResetTime,
            weeklyResetTime: model.weeklyResetTime,
          );
        }
      }
      update([idChallenges, idBadge]);
      await refreshAfter(XpEvent.challengeClaimed);
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
  Future<void> getPrizes({bool reload = false, bool fresh = false}) async {
    if (_prizeModel != null && !reload) return;
    return _single(idPrizes, _fetchPrizes, fresh: fresh);
  }

  Future<void> _fetchPrizes() async {
    _isPrizesLoading = true;
    update([idPrizes]);

    try {
      final result = await xpServiceInterface.getPrizes();
      _prizesFailed = result == null;
      if (result != null) {
        _prizeModel = result;
        _fetchedAt[idPrizes] = DateTime.now();
      }
    } catch (e, s) {
      _prizesFailed = true;
      swallow('xp prizes fetch', e, s, true);
    } finally {
      _isPrizesLoading = false;
      update([idPrizes, idBadge]);
    }
  }

  /// Claim a prize (using user's prize instance ID, NOT prize_id)
  Future<bool> claimPrize(int prizeInstanceId) async {
    _claimingPrizeId = prizeInstanceId;
    update([idPrizes]);

    Response response = await xpServiceInterface.claimPrize(prizeInstanceId);

    _claimingPrizeId = null;

    if (response.statusCode == 200) {
      // Feedback first, then the refetch (X-44): the snackbar used to wait
      // on two round trips.
      // A discount prize comes back with the personal coupon it was minted
      // into — say where it went, since that is where it gets spent.
      final body = response.body;
      final couponCode =
          body is Map && body['prize'] is Map
              ? body['prize']['coupon_code']
              : null;
      showCustomSnackBar(
        couponCode is String && couponCode.isNotEmpty
            ? 'xp_coupon_added'.trParams({'code': couponCode})
            : 'prize_claimed_successfully'.tr,
        isError: false,
      );
      update([idPrizes, idBadge]);
      // Both the prize list and the level payload's `is_claimed` changed.
      await refreshAfter(XpEvent.prizeClaimed);
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

    try {
      _checkoutPrizes = await xpServiceInterface.getCheckoutPrizes(orderAmount);
    } catch (e, s) {
      // No list means nothing offered — and nothing selectable, so a stale
      // selection is dropped below rather than trusted.
      _checkoutPrizes = [];
      swallow('xp checkout prizes fetch', e, s, true);
    }
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
    return _single(idConfig, _fetchXpConfig);
  }

  Future<void> _fetchXpConfig() async {
    _isXpConfigLoading = true;
    update([idConfig]);

    try {
      final result = await xpServiceInterface.getXpConfig();
      if (result != null) {
        _xpConfig = result;
        _fetchedAt[idConfig] = DateTime.now();
      }
    } catch (e, s) {
      swallow('xp config fetch', e, s, true);
    } finally {
      _isXpConfigLoading = false;
      update([idConfig]);
    }
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

  /// The XP a cart will earn, exactly as the server awards it: per line, on the
  /// unit price *before* the item discount (PlaceNewOrder passes the
  /// undiscounted price to the detail row, and XP is computed from that row).
  /// The one estimate every pre-order surface should show (X-23).
  int estimateForCart(List<CartModel> items, String? moduleType) {
    return calculateEstimatedXpForItems([
      for (final c in items) (price: c.price ?? 0, quantity: c.quantity ?? 1),
    ], moduleType);
  }

  /// The per-line XP estimate of the order just placed, handed over by
  /// checkout before the cart is cleared, so the success screen can show the
  /// same number the cart promised. Null for orders not placed from the cart.
  int? lastOrderXpEstimate;

  /// Fetch merged level details (replaces separate getCurrentLevel + getAllLevels)
  Future<void> getLevelDetails({bool reload = false, bool fresh = false}) async {
    if (_currentLevel != null && _levelsListModel != null && !reload) return;
    return _single(idLevel, _fetchLevelDetails, fresh: fresh);
  }

  Future<void> _fetchLevelDetails() async {
    _isLevelLoading = true;
    _isLevelsLoading = true;
    update([idLevel]);

    try {
      final data = await xpServiceInterface.getLevelDetails();
      if (data != null) {
        _currentLevel = XpLevelModel.fromJson(data);
        _levelsListModel = LevelsListModel.fromJson(data);
        _fetchedAt[idLevel] = DateTime.now();

        final streak = xpMap(data['streak']);
        if (streak != null) _streak = UserStreakModel.fromJson(streak);

        // Queue any level-ups the server says we haven't celebrated yet,
        // minus the ones already handed to the UI: their ack goes out only
        // after the dialog closes, so until then the server still lists them
        // and a fetch in between would replay the celebration (X-34).
        if (data['pending_level_ups'] is List) {
          _pendingLevelUps =
              xpMapList(data['pending_level_ups'])
                  .map(LevelUpEvent.fromJson)
                  .where((e) => !_celebratedIds.contains(e.transactionId))
                  .toList();
        }
      }
    } catch (e, s) {
      swallow('xp level details fetch', e, s, true);
    } finally {
      _isLevelLoading = false;
      _isLevelsLoading = false;
      update([idLevel]);
    }
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

    try {
      final result = await xpServiceInterface.getLeaderboard(
        type: type,
        period: _leaderboardPeriod,
      );
      if (result != null) _leaderboardModel = result;
    } catch (e, s) {
      swallow('xp leaderboard fetch', e, s, true);
    } finally {
      _isLeaderboardLoading = false;
      update([idLeaderboard]);
    }
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
    _streak = null;
    _leaderboardModel = null;
    _pendingLevelUps = [];
    _challengesFailed = false;
    _prizesFailed = false;
    _fetchedAt.clear();
    _claimedToday.clear();
    _claimedTodayDate = null;
    _celebratedIds.clear();
    // Forget requests made under the old session, so the next login's fetch
    // starts its own instead of joining one sent with the old token.
    _inFlight.clear();
    _queued.clear();
    // Every XP builder is id-scoped, and an id builder never hears a bare
    // `update()` (get 4.7.3), so logout used to repaint none of them (X-46).
    update([
      idLevel,
      idChallenges,
      idPrizes,
      idLeaderboard,
      idCheckoutPrizes,
      idConfig,
      idBadge,
    ]);
  }

  // ============================================
  // FRESHNESS (X-19, X-20)
  // ============================================

  /// Everything the XP tab shows, fetched in parallel. [force] refetches even
  /// fresh payloads (pull-to-refresh); otherwise only stale ones go out, so a
  /// tab visit revalidates what the user is looking at without re-requesting
  /// what just arrived. Cached data stays on screen while this runs.
  ///
  /// [fresh] is for callers reacting to a change on the server: a request
  /// already in flight predates it, so they wait for a new one (X-45).
  Future<void> revalidate({bool force = false, bool fresh = false}) async {
    await Future.wait([
      if (force || _isStale(idLevel))
        getLevelDetails(reload: true, fresh: fresh),
      if (force || _isStale(idChallenges))
        getChallenges(reload: true, fresh: fresh),
      if (force || _isStale(idPrizes)) getPrizes(reload: true, fresh: fresh),
      if (force || _isStale(idConfig)) getXpConfig(reload: true),
    ]);
  }

  /// Refresh what an event changed, in parallel.
  Future<void> refreshAfter(XpEvent event) async {
    switch (event) {
      case XpEvent.orderDelivered:
        // XP, challenge progress, streak, maybe a level and its prizes.
        await revalidate(force: true, fresh: true);
        break;
      case XpEvent.orderPlaced:
        await getPrizes(reload: true, fresh: true);
        break;
      case XpEvent.prizeClaimed:
        await Future.wait([
          getPrizes(reload: true, fresh: true),
          getLevelDetails(reload: true, fresh: true),
        ]);
        break;
      case XpEvent.challengeClaimed:
        await Future.wait([
          getChallenges(reload: true, fresh: true),
          getLevelDetails(reload: true, fresh: true),
        ]);
        break;
    }
  }

  /// An order went through. If it spent a free-delivery prize, that prize is
  /// now `used`, but the selection and the amount-keyed cache would carry it
  /// into the next checkout of the same basket, where the quote shows free
  /// delivery and the server charges it (X-15). Drop both, then refetch.
  void afterOrderPlaced() {
    _selectedCheckoutPrize = null;
    _checkoutPrizes = [];
    _checkoutPrizesFetchedFor = null;
    update([idCheckoutPrizes]);
    refreshAfter(XpEvent.orderPlaced);
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
}
