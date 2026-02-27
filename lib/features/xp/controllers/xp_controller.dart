import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_level_model.dart';
import 'package:sixam_mart/features/xp/domain/models/challenge_model.dart';
import 'package:sixam_mart/features/xp/domain/models/prize_model.dart';
import 'package:sixam_mart/features/xp/domain/models/checkout_prize_model.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_config_model.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_history_model.dart';
import 'package:sixam_mart/features/xp/domain/models/user_streak_model.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:sixam_mart/features/xp/domain/services/xp_service_interface.dart';

class XpController extends GetxController implements GetxService {
  final XpServiceInterface xpServiceInterface;

  XpController({required this.xpServiceInterface});

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

  // Flag to prevent re-fetching checkout prizes
  bool _checkoutPrizesFetched = false;
  bool get checkoutPrizesFetched => _checkoutPrizesFetched;

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

  // Leaderboard
  XpLeaderboardModel? _leaderboardModel;
  XpLeaderboardModel? get leaderboardModel => _leaderboardModel;
  bool _isLeaderboardLoading = false;
  bool get isLeaderboardLoading => _isLeaderboardLoading;

  /// Max level from config (fallback 10)
  int get maxLevel => _xpConfig?.maxLevel ?? 10;

  /// Fetch current user's XP level
  Future<void> getCurrentLevel({bool reload = false}) async {
    if (_currentLevel != null && !reload) return;

    _isLevelLoading = true;
    Future.microtask(() => update());

    _currentLevel = await xpServiceInterface.getCurrentLevel();

    _isLevelLoading = false;
    update();
  }

  /// Fetch all levels for the roadmap
  Future<void> getAllLevels({bool reload = false}) async {
    if (_levelsListModel != null && !reload) return;

    _isLevelsLoading = true;
    Future.microtask(() => update());

    // Get the current XP from the currentLevel model (fetched from /current-level endpoint)
    final userCurrentXp = _currentLevel?.currentXp ?? 0;
    final userCurrentLevel = _currentLevel?.currentLevel ?? 1;
    
    _levelsListModel = await xpServiceInterface.getAllLevels();
    
    // If the levels API didn't return currentXp, recalculate using the currentLevel data
    if (_levelsListModel != null && _levelsListModel!.currentXp == 0 && userCurrentXp > 0) {
      // Recalculate which levels should be unlocked based on actual XP
      final recalculatedLevels = _levelsListModel!.levels.map((level) {
        final isUnlocked = userCurrentXp >= level.xpRequired;
        
        return Level(
          level: level.level,
          name: level.name,
          xpRequired: level.xpRequired,
          description: level.description,
          badgeImage: level.badgeImage,
          isUnlocked: isUnlocked,
          isCurrent: level.level == userCurrentLevel,
          prizes: level.prizes,
        );
      }).toList();
      
      _levelsListModel = LevelsListModel(
        levels: recalculatedLevels,
        currentLevel: userCurrentLevel,
        currentXp: userCurrentXp,
        xpForNextLevel: _levelsListModel!.xpForNextLevel,
        xpToNextLevel: _levelsListModel!.xpToNextLevel,
        progressPercentage: _levelsListModel!.progressPercentage,
      );
    }

    _isLevelsLoading = false;
    update();
  }

  /// Fetch challenges (daily & weekly)
  Future<void> getChallenges({bool reload = false}) async {
    if (_challengeModel != null && !reload) return;

    _isChallengesLoading = true;
    Future.microtask(() => update());

    _challengeModel = await xpServiceInterface.getChallenges();

    _isChallengesLoading = false;
    update();
  }

  /// Claim a completed challenge
  Future<bool> claimChallenge(int challengeId) async {
    _claimingChallengeId = challengeId;
    update();

    Response response = await xpServiceInterface.claimChallenge(challengeId);

    _claimingChallengeId = null;

    if (response.statusCode == 200) {
      // Refresh challenges and level after claiming
      await getChallenges(reload: true);
      await getCurrentLevel(reload: true);
      showCustomSnackBar('challenge_claimed_successfully'.tr, isError: false);
      update();
      return true;
    } else {
      String message =
          response.body['message'] ?? 'failed_to_claim_challenge'.tr;
      showCustomSnackBar(message);
      update();
      return false;
    }
  }

  /// Fetch prizes
  Future<void> getPrizes({bool reload = false}) async {
    if (_prizeModel != null && !reload) return;

    _isPrizesLoading = true;
    Future.microtask(() => update());

    _prizeModel = await xpServiceInterface.getPrizes();

    _isPrizesLoading = false;
    update();
  }

  /// Claim a prize (using user's prize instance ID, NOT prize_id)
  Future<bool> claimPrize(int prizeInstanceId) async {
    _claimingPrizeId = prizeInstanceId;
    update();

    Response response = await xpServiceInterface.claimPrize(prizeInstanceId);

    _claimingPrizeId = null;

    if (response.statusCode == 200) {
      // Refresh prizes after claiming
      await getPrizes(reload: true);
      showCustomSnackBar('prize_claimed_successfully'.tr, isError: false);
      update();
      return true;
    } else {
      String message = response.body['message'] ?? 'failed_to_claim_prize'.tr;
      showCustomSnackBar(message);
      update();
      return false;
    }
  }

  /// Fetch checkout prizes (free_delivery prizes available for current order amount)
  Future<void> getCheckoutPrizes(double orderAmount) async {
    _isCheckoutPrizesLoading = true;
    Future.microtask(() => update());

    _checkoutPrizes = await xpServiceInterface.getCheckoutPrizes(orderAmount);
    _checkoutPrizesFetched = true; // Mark as fetched to prevent re-calls

    // Clear any previously selected prize if it's no longer available
    if (_selectedCheckoutPrize != null) {
      final stillAvailable = _checkoutPrizes.any(
        (p) => p.id == _selectedCheckoutPrize!.id,
      );
      if (!stillAvailable) {
        _selectedCheckoutPrize = null;
      }
    }

    _isCheckoutPrizesLoading = false;
    update();
  }

  /// Select a checkout prize for free delivery
  void selectCheckoutPrize(CheckoutPrize? prize) {
    _selectedCheckoutPrize = prize;
    update();
  }

  /// Clear selected checkout prize
  void clearSelectedCheckoutPrize() {
    _selectedCheckoutPrize = null;
    update();
  }

  /// Change challenge tab (daily/weekly)
  void changeChallengeTab(int index) {
    _selectedChallengeTab = index;
    update();
  }

  /// Change prize filter
  void changePrizeFilter(int index) {
    _selectedPrizeFilter = index;
    update();
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
    Future.microtask(() => update());

    _xpConfig = await xpServiceInterface.getXpConfig();

    _isXpConfigLoading = false;
    update();
  }

  /// Calculate estimated XP for a given order amount and module type
  /// Uses config if available, otherwise uses default formula: 10 + floor(amount * 0.1)
  int calculateEstimatedXp(double orderAmount, String? moduleType) {
    if (_xpConfig != null) {
      return _xpConfig!.calculateEstimatedXp(orderAmount, moduleType);
    }
    // Fallback calculation: base 10 XP + 10% of order amount
    // This ensures users always see estimated XP even if config isn't loaded
    return 10 + (orderAmount * 0.1).floor();
  }

  /// Fetch merged level details (replaces separate getCurrentLevel + getAllLevels)
  Future<void> getLevelDetails({bool reload = false}) async {
    if (_currentLevel != null && _levelsListModel != null && !reload) return;

    _isLevelLoading = true;
    _isLevelsLoading = true;
    Future.microtask(() => update());

    final data = await xpServiceInterface.getLevelDetails();

    if (data != null) {
      _currentLevel = XpLevelModel.fromJson(data);
      _levelsListModel = LevelsListModel.fromJson(data);

      // Parse streak if present
      if (data['streak'] != null) {
        _streak = UserStreakModel.fromJson(data['streak']);
      }
    }

    _isLevelLoading = false;
    _isLevelsLoading = false;
    update();
  }

  /// Fetch XP history
  Future<void> getHistory({bool reload = false, int limit = 20, int offset = 0}) async {
    if (_historyModel != null && !reload && offset == 0) return;

    _isHistoryLoading = true;
    Future.microtask(() => update());

    final result = await xpServiceInterface.getHistory(limit: limit, offset: offset);

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
    update();
  }

  /// Fetch leaderboard
  Future<void> getLeaderboard({bool reload = false, String type = 'global'}) async {
    if (_leaderboardModel != null && !reload) return;

    _isLeaderboardLoading = true;
    Future.microtask(() => update());

    _leaderboardModel = await xpServiceInterface.getLeaderboard(type: type);

    _isLeaderboardLoading = false;
    update();
  }

  /// Clear all data (on logout)
  void clearXpData() {
    _currentLevel = null;
    _levelsListModel = null;
    _challengeModel = null;
    _prizeModel = null;
    _checkoutPrizes = [];
    _selectedCheckoutPrize = null;
    _checkoutPrizesFetched = false;
    _xpConfig = null;
    _historyModel = null;
    _streak = null;
    _leaderboardModel = null;
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

  // Loading state for level badge claim
  bool _isClaimingLevelBadge = false;
  bool get isClaimingLevelBadge => _isClaimingLevelBadge;

  /// Claim level badge using challenge ID
  Future<bool> claimLevelBadge(int challengeId) async {
    _isClaimingLevelBadge = true;
    Future.microtask(() => update());

    Response response = await xpServiceInterface.claimChallenge(challengeId);

    _isClaimingLevelBadge = false;

    if (response.statusCode == 200) {
      // Refresh level data after claiming
      await getCurrentLevel(reload: true);
      showCustomSnackBar('founding_badge_claimed'.tr, isError: false);
      update();
      return true;
    } else {
      String message = response.body?['message'] ?? 'failed_to_claim_badge'.tr;
      showCustomSnackBar(message);
      update();
      return false;
    }
  }
}
