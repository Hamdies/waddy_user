import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/features/places/domain/services/places_analytics.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/cache_ttl_helper.dart';
import 'package:waddy_app/features/places/domain/models/place_category_model.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/models/place_banner_model.dart';
import 'package:waddy_app/features/places/domain/models/place_vote_model.dart';
import 'package:waddy_app/features/places/domain/models/place_winner_model.dart';
import 'package:waddy_app/features/places/domain/models/place_prize_model.dart';
import 'package:waddy_app/features/places/domain/models/place_review_model.dart';
import 'package:waddy_app/features/places/domain/models/place_submission_model.dart';
import 'package:waddy_app/features/places/domain/services/places_service_interface.dart';
import 'package:waddy_app/features/places/domain/spots_stage.dart';
import 'package:waddy_app/features/places/widgets/vote_switch_dialog.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';

class PlacesController extends GetxController implements GetxService {
  final PlacesServiceInterface placesServiceInterface;

  PlacesController({required this.placesServiceInterface});

  // ─── Rebuild scopes ───
  // `update()` with no argument rebuilds every GetBuilder watching this
  // controller — on the Spots home that is six sections, including the
  // podium, on every one of the seven init responses. These ids let each
  // fetch repaint only the section it actually changed.
  static const String idLeaderboard = 'places_leaderboard';
  static const String idTopVoters = 'places_top_voters';
  static const String idPlaces = 'places_list';
  static const String idWinners = 'places_winners';
  static const String idMasthead = 'places_masthead';
  static const String idFilters = 'places_filters';
  static const String idDetails = 'places_details';

  /// The reviews block on the details screen, separate from [idDetails].
  ///
  /// The whole details screen was one `GetBuilder(id: idDetails)` and
  /// `getPlaceReviews` notified it on entry *and* exit — so loading page two
  /// of the reviews repainted the cover photo, the gallery and the embedded
  /// `GoogleMap` twice. See `S-05`.
  static const String idReviews = 'places_reviews';

  /// Every home section at once — for the init/refresh cycle, where the
  /// loading flags of all of them flip together.
  static const List<String> idAllHome = [
    idLeaderboard,
    idTopVoters,
    idPlaces,
    idWinners,
    idMasthead,
    idFilters,
  ];

  // ─── Categories ───
  List<PlaceCategory>? _categories;
  List<PlaceCategory>? get categories => _categories;
  bool _isCategoriesLoading = false;
  bool get isCategoriesLoading => _isCategoriesLoading;

  // ─── Places ───
  PlaceList? _placeList;
  List<Place>? get places => _placeList?.places;
  int? get totalPlaces => _placeList?.totalSize;
  bool _isPlacesLoading = false;
  bool get isPlacesLoading => _isPlacesLoading;

  /// The last places page the server actually served — the same reasoning as
  /// [_reviewsPage]: a page number derived from `length ~/ perPage` stalls the
  /// moment a row is dropped, and "load more" silently becomes a no-op.
  int _placesPage = 1;
  int get nextPlacesPage => _placesPage + 1;

  /// Whether the catalogue holds more than the pages loaded so far.
  ///
  /// The home rendered `totalPlaces` — the server's count of the whole
  /// catalogue — as a header stat over a single unpaginated page, so it said
  /// "48 SPOTS" above ten rows. Now the list can actually reach 48. See
  /// `S-09`.
  bool get hasMorePlaces {
    final int total = _placeList?.totalSize ?? 0;
    return (_placeList?.places.length ?? 0) < total;
  }

  /// Separate from [isPlacesLoading], which covers the first page only —
  /// without it an append has no progress row and a double scroll-trigger
  /// fetches the same page twice.
  bool _isLoadingMorePlaces = false;
  bool get isLoadingMorePlaces => _isLoadingMorePlaces;

  // ─── Leaderboard ───
  PlaceList? _leaderboardList;
  List<Place>? get leaderboard => _leaderboardList?.places;
  String? get leaderboardPeriod => _leaderboardList?.period;
  bool _isLeaderboardLoading = false;
  bool get isLeaderboardLoading => _isLeaderboardLoading;

  // ─── Trending ───
  PlaceList? _trendingList;
  List<Place>? get trending => _trendingList?.places;
  bool _isTrendingLoading = false;
  bool get isTrendingLoading => _isTrendingLoading;

  // ─── Tags ───
  List<PlaceTag>? _tags;
  List<PlaceTag>? get tags => _tags;
  List<int> _selectedTagIds = [];
  List<int> get selectedTagIds => _selectedTagIds;
  bool _isTagsLoading = false;
  bool get isTagsLoading => _isTagsLoading;

  // ─── Banners ───
  List<PlaceBanner>? _banners;
  List<PlaceBanner>? get banners => _banners;
  bool _isBannersLoading = false;
  bool get isBannersLoading => _isBannersLoading;
  int _currentBannerIndex = 0;
  int get currentBannerIndex => _currentBannerIndex;

  // ─── Place Details ───
  Place? _placeDetails;
  Place? get placeDetails => _placeDetails;
  bool _isDetailsLoading = false;
  bool get isDetailsLoading => _isDetailsLoading;

  /// HTTP status of the last failed details fetch, so the screen can name the
  /// actual cause instead of blaming the network for a deleted spot.
  int? _detailsErrorStatus;
  int? get detailsErrorStatus => _detailsErrorStatus;

  // ─── Reviews ───
  PlaceReviewList? _reviewList;
  List<PlaceReview>? get reviews => _reviewList?.reviews;
  int? get totalReviews => _reviewList?.totalSize;

  /// The last review page the server actually served. Derived page numbers
  /// (`length ~/ perPage + 1`) stall the moment de-duplication drops an item:
  /// the count stops advancing, the same page is requested forever, and
  /// "load more" becomes a no-op button.
  int _reviewsPage = 1;
  int get nextReviewsPage => _reviewsPage + 1;
  bool get hasMoreReviews {
    final total = _reviewList?.totalSize ?? 0;
    return (_reviewList?.reviews.length ?? 0) < total;
  }

  bool _isReviewsLoading = false;
  bool get isReviewsLoading => _isReviewsLoading;

  /// Separate from [isReviewsLoading], which only ever covers the first page.
  /// Without this the "load more" row had no way to show progress — its spinner
  /// branch was unreachable — and nothing stopped a double tap from appending
  /// the same page twice.
  bool _isLoadingMoreReviews = false;
  bool get isLoadingMoreReviews => _isLoadingMoreReviews;

  // ─── Voting ───
  VoteStatus? _voteStatus;
  VoteStatus? get voteStatus => _voteStatus;
  bool _isVoting = false;
  bool get isVoting => _isVoting;

  // ─── Favorites ───
  PlaceList? _favoritesList;
  List<Place>? get favorites => _favoritesList?.places;
  bool _isFavoritesLoading = false;
  bool get isFavoritesLoading => _isFavoritesLoading;

  // ─── Submissions ───
  PlaceSubmissionList? _submissionsList;
  List<PlaceSubmission>? get submissions => _submissionsList?.submissions;
  bool _isSubmissionsLoading = false;
  bool get isSubmissionsLoading => _isSubmissionsLoading;
  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  // ─── Filters ───
  int? _selectedCategoryId;
  int? get selectedCategoryId => _selectedCategoryId;
  int? _selectedZoneId;
  int? get selectedZoneId => _selectedZoneId;
  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  String _sortBy = 'rating';
  String get sortBy => _sortBy;

  // ─── Initialization State ───
  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _hasInitError = false;
  bool get hasInitError => _hasInitError;

  /// TTL stamp key for the cached home payload. Spots data moves on a weekly
  /// voting cycle, but votes land continuously, so a short window keeps the
  /// board honest while still making a relaunch instant.
  static const String _homeCacheKey = 'places_home';
  static const Duration homeCacheTtl = Duration(minutes: 3);

  /// How many of the init calls threw on the last cycle. Drives the "nothing
  /// arrived at all" error card without letting one bad endpoint hide six
  /// good ones.
  int _initFailures = 0;

  /// Whether anything renderable arrived — used to choose between the full
  /// error card (nothing to show) and stale data with an inline retry.
  bool get hasAnyHomeData =>
      _leaderboardList != null || _placeList != null || _topVotersList != null;

  // ─── Top Voters ───
  TopVoterList? _topVotersList;
  List<TopVoter>? get topVoters => _topVotersList?.voters;
  bool _isTopVotersLoading = false;
  bool get isTopVotersLoading => _isTopVotersLoading;

  // ─── Current User Rank (derived from top voters) ───
  int? get currentUserRank {
    try {
      final userId = Get.find<ProfileController>().userInfoModel?.id;
      if (userId == null || topVoters == null) return null;
      final match = topVoters!.where((v) => v.id == userId);
      if (match.isEmpty) return null;
      return match.first.position ?? (topVoters!.indexOf(match.first) + 1);
    } catch (_) {
      return null;
    }
  }

  int? get currentUserVotes {
    try {
      final userId = Get.find<ProfileController>().userInfoModel?.id;
      if (userId == null || topVoters == null) return null;
      final match = topVoters!.where((v) => v.id == userId);
      if (match.isEmpty) return null;
      return match.first.votesCount;
    } catch (_) {
      return null;
    }
  }

  // ─── Race push topics ───
  int? _subscribedZoneTopic;

  /// Everyone on the Spots screen hears about overall lead changes
  Future<void> subscribeRaceTopics() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('places_race_all');
    } catch (e) {
      debugPrint('race topic subscribe failed: $e');
    }
  }

  /// Zone topic follows the selected zone filter
  Future<void> _updateZoneRaceTopic(int? zoneId) async {
    if (_subscribedZoneTopic == zoneId) return;
    try {
      if (_subscribedZoneTopic != null) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(
          'places_race_zone_$_subscribedZoneTopic',
        );
      }
      if (zoneId != null) {
        await FirebaseMessaging.instance.subscribeToTopic(
          'places_race_zone_$zoneId',
        );
      }
      _subscribedZoneTopic = zoneId;
    } catch (e) {
      debugPrint('zone race topic update failed: $e');
    }
  }

  // ─── Weekly Champion (the news) ───
  PlaceWinner? _latestWinner;
  PlaceWinner? get latestWinner => _latestWinner;
  bool _isWinnerLoading = false;
  bool get isWinnerLoading => _isWinnerLoading;

  List<PlaceWinner>? _winnersHistory;
  List<PlaceWinner>? get winnersHistory => _winnersHistory;
  bool _isWinnersHistoryLoading = false;
  bool get isWinnersHistoryLoading => _isWinnersHistoryLoading;

  /// Last closed week's champion (zone-scoped when a zone is selected)
  Future<void> getLatestWinner({
    bool reload = false,
    bool notify = true,
  }) async {
    if (_latestWinner != null && !reload) return;
    _isWinnerLoading = true;
    // Scoped both ways. The entry rebuild is the expensive one — it is what
    // paints the spinner — and it was the unscoped half, so showing a loader
    // on the winners strip repainted the board, the podium and the whole
    // places list with it. See `S-04`.
    if (notify) update([idWinners, idMasthead]);

    _latestWinner = await placesServiceInterface.getLatestWinner(
      zoneId: _selectedZoneId,
    );
    _isWinnerLoading = false;
    if (notify) update([idWinners, idMasthead]);
  }

  /// Hall of fame — past weekly champions
  Future<void> getWinnersHistory({bool reload = false}) async {
    if (_winnersHistory != null && !reload) return;
    _isWinnersHistoryLoading = true;
    update();

    _winnersHistory = await placesServiceInterface.getWinners(
      zoneId: _selectedZoneId,
    );
    _isWinnersHistoryLoading = false;
    update();
  }

  // ─── Recent Winners (people, not venues) ───
  // Kept separate from both winnersHistory (venues) and topVoters (a ranking):
  // one list mixing them would imply voting more improves your chances, which
  // is exactly the impression the random draw exists to avoid.
  List<RecentWinner>? _recentWinners;
  List<RecentWinner>? get recentWinners => _recentWinners;
  bool _isRecentWinnersLoading = false;
  bool get isRecentWinnersLoading => _isRecentWinnersLoading;

  Future<void> getRecentWinners({
    bool reload = false,
    bool notify = true,
  }) async {
    if (_recentWinners != null && !reload) return;
    if (notify) {
      _isRecentWinnersLoading = true;
      // Scoped to match the exit notify below — the entry rebuild is the one
      // that paints the skeleton, and it was the unscoped half.
      update([idWinners]);
    }

    _recentWinners = await placesServiceInterface.getRecentWinners(limit: 10);
    _isRecentWinnersLoading = false;
    if (notify) update([idWinners]);
  }

  // ─── My Prizes (voter draw vouchers) ───
  PlacePrizeList? _prizes;
  List<PlacePrize> get activePrizes => _prizes?.active ?? const [];
  List<PlacePrize> get prizeHistory => _prizes?.history ?? const [];
  bool _isPrizesLoading = false;
  bool get isPrizesLoading => _isPrizesLoading;
  bool get hasPrizesLoaded => _prizes != null;

  /// The live voucher the masthead badge and the win-card point at.
  PlacePrize? get featuredPrize =>
      activePrizes.isNotEmpty ? activePrizes.first : null;

  Future<void> getMyPrizes({bool reload = false, bool notify = true}) async {
    if (_prizes != null && !reload) return;
    if (notify) {
      _isPrizesLoading = true;
      update([idMasthead]);
    }

    _prizes = await placesServiceInterface.getMyPrizes();
    _isPrizesLoading = false;
    await _syncCelebratedPrizes();
    update([idMasthead]);
  }

  // ─── Win-card celebration gate ───
  // The shareable card is offered once per prize. Persisted so a relaunch
  // doesn't re-congratulate someone for a voucher they already shared.
  static const String _celebratedPrizesKey = 'spots_celebrated_prizes';
  Set<int> _celebratedPrizeIds = {};

  Future<void> _syncCelebratedPrizes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _celebratedPrizeIds =
          (prefs.getStringList(_celebratedPrizesKey) ?? const [])
              .map(int.tryParse)
              .whereType<int>()
              .toSet();
    } catch (e) {
      debugPrint('⚠️ [PLACES] celebrated prizes read error: $e');
    }
  }

  /// A live prize the user hasn't been congratulated for yet, if any.
  PlacePrize? get uncelebratedPrize {
    for (final prize in activePrizes) {
      if (!_celebratedPrizeIds.contains(prize.id)) return prize;
    }
    return null;
  }

  Future<void> markPrizeCelebrated(int prizeId) async {
    if (!_celebratedPrizeIds.add(prizeId)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _celebratedPrizesKey,
        _celebratedPrizeIds.map((id) => id.toString()).toList(),
      );
    } catch (e) {
      debugPrint('⚠️ [PLACES] celebrated prizes write error: $e');
    }
    // Only the masthead's prize badge reads this.
    update([idMasthead]);
  }

  // ─── Live Standings (race mode) ───
  // When no spot has hit the official podium threshold yet, we still rank
  // everything with votes this week and show movement like a stock ticker.
  Map<int, int> _rankDeltas =
      {}; // placeId -> (previousRank - currentRank); + means climbed
  Set<int> _newEntries = {}; // placeIds that just appeared on the board
  Map<int, int>? _lastComputedRanks; // in-session snapshot, per selected zone

  // Memo for [liveStandings], keyed on the identity of the two lists it is
  // derived from.
  //
  // It is a getter, so every read used to copy, filter, sort and take — and
  // `rankOf`, `isTiedAt` and `roundHeat` (and therefore `stage`) each call it
  // again internally. One build of `WeeklyTop3Section` alone came to seven
  // sorts, plus one in the ticker and two more in the podium's empty state.
  //
  // Keyed on identity rather than invalidated at each assignment site: there
  // are five places that write `_placeList` or `_leaderboardList`, and a memo
  // that depends on remembering to clear it at all five is a memo that will be
  // stale the first time someone adds a sixth. See `S-08`.
  List<Place>? _standingsMemo;
  PlaceList? _standingsFromPlaces;
  PlaceList? _standingsFromBoard;

  /// Current ranking by this week's votes — official leaderboard when it
  /// exists, otherwise derived from the places list (votes > 0), top 5.
  List<Place> get liveStandings {
    if (_standingsMemo != null &&
        identical(_standingsFromPlaces, _placeList) &&
        identical(_standingsFromBoard, _leaderboardList)) {
      return _standingsMemo!;
    }

    final source =
        (leaderboard != null && leaderboard!.isNotEmpty)
            ? leaderboard!
            : (places ?? []).where((p) => p.votesCount > 0).toList();
    final list = List<Place>.from(source);
    list.sort((a, b) {
      final byVotes = b.votesCount.compareTo(a.votesCount);
      return byVotes != 0 ? byVotes : b.rating.compareTo(a.rating);
    });

    _standingsFromPlaces = _placeList;
    _standingsFromBoard = _leaderboardList;
    // Unmodifiable so a caller cannot sort or trim the shared list in place —
    // with a memo behind it, that would corrupt every later read.
    return _standingsMemo = List<Place>.unmodifiable(list.take(5));
  }

  /// Total votes cast across this week's board — the one number that says how
  /// far the round has actually been played.
  int get roundHeat =>
      liveStandings.fold<int>(0, (sum, p) => sum + p.votesCount);

  /// Which sections the home screen has earned the right to draw.
  ///
  /// Every section on Spots home reads this instead of deciding for itself,
  /// so the hero and the ticker can no longer disagree about whether the race
  /// has started.
  SpotsStage get stage => SpotsStage.fromHeat(roundHeat);

  /// Competition rank for a place, ties shared — 1, 2, 2, 4 rather than
  /// 1, 2, 3, 4.
  ///
  /// Position in a sorted list is not rank. Two spots on one vote each are
  /// tied, and printing them as `01` and `02` states an order the votes do not
  /// support; on a cold board that is most of the screen's credibility.
  /// Null when the place is not on the board.
  int? rankOf(int placeId) {
    final standings = liveStandings;
    final index = standings.indexWhere((p) => p.id == placeId);
    if (index < 0) return null;
    final votes = standings[index].votesCount;
    // Rank is one more than the number of places strictly ahead of it.
    return standings.where((p) => p.votesCount > votes).length + 1;
  }

  /// True when at least one other place on the board shares this one's vote
  /// count — the caller renders "T2" rather than "02".
  bool isTiedAt(int placeId) {
    final standings = liveStandings;
    final index = standings.indexWhere((p) => p.id == placeId);
    if (index < 0) return false;
    final votes = standings[index].votesCount;
    return standings.where((p) => p.votesCount == votes).length > 1;
  }

  /// How many places are in this week's race in total — the size of the field
  /// the home card is showing the top two of.
  ///
  /// Null unless the backend reports a total, and deliberately so: neither
  /// list length is a population. The leaderboard is requested with `limit: 3`
  /// and [getPlaces] is paginated, so counting either under-reports — telling
  /// a user "3 places" when twelve are competing is worse than showing no
  /// number at all. Callers must handle null by saying nothing about size.
  int? get contenderTotal =>
      _leaderboardList?.totalSize ?? _placeList?.totalSize;

  /// Rank movement since last look: >0 climbed, <0 dropped, 0 held, null unknown
  int? rankDeltaFor(int placeId) => _rankDeltas[placeId];

  /// True when the place wasn't on the board last time the user looked
  bool isNewOnBoard(int placeId) => _newEntries.contains(placeId);

  String get _standingsSnapshotKey {
    // ISO week, matching the backend voting period (e.g. 2026-W28).
    // UTC-normalized dates so DST can't skew the day arithmetic.
    final local = DateTime.now();
    final today = DateTime.utc(local.year, local.month, local.day);
    final thursday = today.add(Duration(days: 4 - today.weekday));
    final firstDay = DateTime.utc(thursday.year, 1, 1);
    final week = (thursday.difference(firstDay).inDays ~/ 7) + 1;
    final period = '${thursday.year}-W${week.toString().padLeft(2, '0')}';
    return 'places_rank_snapshot_${period}_${_selectedZoneId ?? 'all'}';
  }

  /// Recompute ▲/▼ movement vs the last seen ranking and persist the new one
  Future<void> refreshRankDeltas() async {
    final standings = liveStandings;
    if (standings.isEmpty) return;
    final current = <int, int>{
      for (int i = 0; i < standings.length; i++) standings[i].id: i + 1,
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<int, int>? previous = _lastComputedRanks;
      if (previous == null) {
        final raw = prefs.getString(_standingsSnapshotKey);
        if (raw != null) {
          previous = (jsonDecode(raw) as Map<String, dynamic>).map(
            (k, v) => MapEntry(int.parse(k), v as int),
          );
        }
      }
      _rankDeltas = {};
      _newEntries = {};
      current.forEach((id, rank) {
        final prevRank = previous?[id];
        if (prevRank == null) {
          _newEntries.add(id);
        } else {
          _rankDeltas[id] = prevRank - rank;
        }
      });
      _lastComputedRanks = current;
      await prefs.setString(
        _standingsSnapshotKey,
        jsonEncode(current.map((k, v) => MapEntry(k.toString(), v))),
      );
    } catch (e) {
      debugPrint('⚠️ [PLACES] refreshRankDeltas error: $e');
    }
    update([idLeaderboard, idTopVoters]);
  }

  // ─── Zones ───
  List<PlaceZone>? _zones;
  List<PlaceZone>? get zones => _zones;
  bool _isZonesLoading = false;
  bool get isZonesLoading => _isZonesLoading;

  /// Whether the last zones fetch came back at all.
  ///
  /// `_zones` alone cannot tell a failed request from a zone list that is
  /// genuinely empty — both leave it null — so the filter sheet collapsed to
  /// nothing on a failure, with no error and no retry. Same distinction
  /// `CuisineController` draws with its own `loaded` flag. See `S-10`.
  bool _zonesLoaded = false;
  bool get zonesFailed => !_isZonesLoading && !_zonesLoaded;

  /// Display name of the currently selected zone (null when "ALL")
  String? get selectedZoneName {
    if (_selectedZoneId == null || _zones == null) return null;
    for (final z in _zones!) {
      if (z.id == _selectedZoneId) return z.displayName ?? z.name;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // FETCH METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Fetch zones for filter chips
  Future<void> getZones({
    bool reload = false,
    bool notify = true,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    if (_zones != null && !reload) return;
    if (notify) {
      _isZonesLoading = true;
      update([idFilters]);
    }

    final List<PlaceZone>? fetched = await placesServiceInterface.getZones(
      source: source,
    );
    // A null response is a failure; an empty list is an answer. Only the
    // latter counts as loaded, and a cache miss must not mark the network
    // attempt as having succeeded.
    if (fetched != null) {
      _zones = fetched;
      _zonesLoaded = true;
    }
    if (_zones == null || _zones!.isEmpty) {
      debugPrint('⚠️ [PLACES] zones response is null or empty');
    }
    _isZonesLoading = false;
    if (notify) update([idFilters]);
  }

  /// Fetch categories
  Future<void> getCategories({
    bool reload = false,
    bool notify = true,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    if (_categories != null && !reload) return;
    if (notify) {
      _isCategoriesLoading = true;
      update([idFilters]);
    }

    _categories = await placesServiceInterface.getCategories(source: source);
    if (_categories == null || _categories!.isEmpty) {
      debugPrint('⚠️ [PLACES] categories response is null or empty');
    }
    _isCategoriesLoading = false;
    if (notify) update([idFilters]);
  }

  /// Fetch places with filters
  Future<void> getPlaces({
    int? categoryId,
    String? search,
    double? lat,
    double? lng,
    String? sort,
    List<int>? tagIds,
    int? zoneId,
    int offset = 1,
    bool reload = false,
    bool notify = true,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    final bool isFirstPage = offset == 1 || reload;

    // Drop a concurrent append: the scroll trigger fires on every scroll frame
    // near the bottom, so without this one flick queues several requests for
    // the same page and all of them get merged in.
    if (!isFirstPage && _isLoadingMorePlaces) return;

    if (isFirstPage) {
      _isPlacesLoading = true;
      _placesPage = 1;
    } else {
      _isLoadingMorePlaces = true;
    }
    if (notify) update([idPlaces]);

    // 'distance' sort needs the user's location — use the saved address
    final effectiveSort = sort ?? _sortBy;
    if (effectiveSort == 'distance' && lat == null && lng == null) {
      final address = AddressHelper.getUserAddressFromSharedPref();
      lat = double.tryParse(address?.latitude ?? '');
      lng = double.tryParse(address?.longitude ?? '');
    }

    PlaceList? result = await placesServiceInterface.getPlaces(
      categoryId: categoryId ?? _selectedCategoryId,
      search: search ?? _searchQuery,
      lat: lat,
      lng: lng,
      sort: effectiveSort,
      tagIds: tagIds ?? (_selectedTagIds.isNotEmpty ? _selectedTagIds : null),
      zoneId: zoneId ?? _selectedZoneId,
      offset: offset,
      source: source,
    );

    if (result != null) {
      _placesPage = result.offset ?? offset;
      if (isFirstPage) {
        _placeList = result;
      } else {
        // De-duplicate by id, as the reviews merge does. A spot removed
        // between two page fetches shifts the window, so the next page can
        // repeat a row that is already on screen.
        final List<Place> merged = [...(_placeList?.places ?? <Place>[])];
        final Set<int> seen = merged.map((Place p) => p.id).toSet();
        for (final Place place in result.places) {
          if (seen.add(place.id)) merged.add(place);
        }
        _placeList = PlaceList(
          places: merged,
          totalSize: result.totalSize,
          offset: result.offset,
        );
      }
    }

    _isPlacesLoading = false;
    _isLoadingMorePlaces = false;
    if (notify) update([idPlaces]);
  }

  /// Fetch leaderboard
  Future<void> getLeaderboard({
    String? period,
    int? zoneId,
    int? limit,
    bool reload = false,
    bool notify = true,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    if (_leaderboardList != null && !reload && period == null) return;
    _isLeaderboardLoading = true;
    if (notify) update([idLeaderboard]);

    _leaderboardList = await placesServiceInterface.getLeaderboard(
      period: period,
      zoneId: zoneId ?? _selectedZoneId,
      limit: limit,
      source: source,
    );
    if (_leaderboardList == null || _leaderboardList!.places.isEmpty) {
      debugPrint('⚠️ [PLACES] leaderboard response is null or empty');
    }
    _isLeaderboardLoading = false;
    if (notify) update([idLeaderboard]);
  }

  /// Fetch top voters
  Future<void> getTopVoters({
    int? zoneId,
    int limit = 10,
    bool reload = false,
    bool notify = true,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    if (_topVotersList != null && !reload) return;
    _isTopVotersLoading = true;
    if (notify) update([idTopVoters]);

    _topVotersList = await placesServiceInterface.getTopVoters(
      zoneId: zoneId ?? _selectedZoneId,
      limit: limit,
      source: source,
    );
    if (_topVotersList == null || _topVotersList!.voters.isEmpty) {
      debugPrint('⚠️ [PLACES] top-voters response is null or empty');
    }
    _isTopVotersLoading = false;
    if (notify) update([idTopVoters]);
  }

  /// Fetch trending places
  Future<void> getTrending({bool reload = false, bool notify = true}) async {
    if (_trendingList != null && !reload) return;
    if (notify) {
      _isTrendingLoading = true;
      update();
    } else {
      _isTrendingLoading = true;
    }

    _trendingList = await placesServiceInterface.getTrending();
    _isTrendingLoading = false;
    update();
  }

  /// Fetch tags
  Future<void> getTags({bool reload = false, bool notify = true}) async {
    if (_tags != null && !reload) return;
    if (notify) {
      _isTagsLoading = true;
      update();
    } else {
      _isTagsLoading = true;
    }

    _tags = await placesServiceInterface.getTags();
    _isTagsLoading = false;
    update();
  }

  /// Fetch featured banners
  Future<void> getFeaturedBanners({
    bool reload = false,
    bool notify = true,
  }) async {
    if (_banners != null && !reload) return;
    if (notify) {
      _isBannersLoading = true;
      update();
    } else {
      _isBannersLoading = true;
    }

    _banners = await placesServiceInterface.getFeaturedBanners();
    _isBannersLoading = false;
    update();
  }

  /// Fetch place details
  /// Adopt the list's copy of a spot as the details payload, so the screen has
  /// something to draw on its first frame.
  ///
  /// Marked partial: the list payload has no gallery, opening hours or links,
  /// so the screen still shows those sections as loading and the fetch in
  /// flight replaces this wholesale when it lands.
  void seedPlaceDetails(Place place) {
    if (_placeDetails?.id == place.id) return;
    _placeDetails = place;
    _isDetailsPartial = true;
    _detailsErrorStatus = null;
  }

  /// Whether [placeDetails] is the abbreviated list copy rather than a full
  /// fetch. Sections that only exist in the full payload use this to show a
  /// placeholder instead of an empty state that would read as "no photos".
  bool _isDetailsPartial = false;
  bool get isDetailsPartial => _isDetailsPartial;

  Future<void> getPlaceDetails(int placeId) async {
    PlacesAnalytics.log(
      'details_view',
      placeId: placeId,
      zoneId: _selectedZoneId,
      oncePerSession: true,
    );
    _isDetailsLoading = true;
    _detailsErrorStatus = null;
    // Only clear when switching places — keeps the screen stable on refresh
    if (_placeDetails != null && _placeDetails!.id != placeId) {
      _placeDetails = null;
      _isDetailsPartial = false;
    }
    update([idDetails]);

    final result = await placesServiceInterface.getPlaceDetails(placeId);
    if (result.place != null) {
      _placeDetails = result.place;
      _isDetailsPartial = false;
    } else {
      // A seeded spot stays on screen when the top-up fails — the user is
      // still looking at real data, so an error card would be a regression.
      if (!_isDetailsPartial) _detailsErrorStatus = result.statusCode;
    }
    _isDetailsLoading = false;
    update([idDetails]);
  }

  /// Fetch paginated reviews for a place
  Future<void> getPlaceReviews(
    int placeId, {
    int offset = 1,
    bool reload = false,
  }) async {
    final bool isFirstPage = offset == 1 || reload;

    // Drop a concurrent load-more: without this a double tap fires two requests
    // for the same page and both get appended.
    if (!isFirstPage && _isLoadingMoreReviews) return;

    if (isFirstPage) {
      _isReviewsLoading = true;
      _reviewsPage = 1;
    } else {
      _isLoadingMoreReviews = true;
    }
    update([idReviews]);

    PlaceReviewList? result = await placesServiceInterface.getPlaceReviews(
      placeId,
      offset: offset,
    );

    if (result != null) {
      _reviewsPage = result.offset ?? offset;
      if (isFirstPage) {
        _reviewList = result;
      } else {
        // De-duplicate by id. The page cursor is derived from how many reviews
        // are already loaded, so a partial page (a review deleted or flagged
        // between fetches) makes the next request repeat a page — appending it
        // blind would show the same review twice.
        final merged = [...(_reviewList?.reviews ?? <PlaceReview>[])];
        final seen = merged.map((r) => r.id).toSet();
        for (final review in result.reviews) {
          if (seen.add(review.id)) merged.add(review);
        }
        _reviewList = PlaceReviewList(
          reviews: merged,
          totalSize: result.totalSize,
          offset: result.offset,
        );
      }
    }

    _isReviewsLoading = false;
    _isLoadingMoreReviews = false;
    update([idReviews]);
  }

  // ═══════════════════════════════════════════════════════════════
  // VOTING
  // ═══════════════════════════════════════════════════════════════

  /// Check vote status
  Future<void> getVoteStatus(int placeId) async {
    _voteStatus = await placesServiceInterface.getVoteStatus(placeId);
    update([idDetails]);
  }

  /// Submit vote (now supports photo).
  /// One vote per user per week — a 409 means the vote is parked on another
  /// spot; we confirm with the user and retry with switchVote.
  Future<bool> submitVote(
    int placeId,
    int? rating, {
    String? comment,
    String? imagePath,
    bool switchVote = false,
    bool silent = false,
  }) async {
    // No notify: `_isVoting` has no readers anywhere in the app, so every
    // `update()` around it repainted six sections to record a flag nothing
    // renders. The vote's visible feedback is the confetti and the undo
    // snackbar the caller shows, plus the refetched board below. See `S-04`.
    _isVoting = true;

    var response = await placesServiceInterface.submitVote(
      placeId,
      rating,
      comment,
      imagePath: imagePath,
      switchVote: switchVote,
    );
    _isVoting = false;

    if (response.statusCode == 409 &&
        response.body?['code'] == 'already_voted_this_week') {
      final currentTitle =
          response.body?['current_vote']?['place_title']?.toString() ?? '';
      final confirmed = await showVoteSwitchDialog(currentTitle);
      if (confirmed == true) {
        return submitVote(
          placeId,
          rating,
          comment: comment,
          imagePath: imagePath,
          switchVote: true,
          silent: silent,
        );
      }
      return false;
    }

    if (response.statusCode == 200) {
      // A silent vote is announced by the undo snackbar the caller shows;
      // stacking a second toast on top of it just covers the undo action.
      if (!silent) {
        showCustomSnackBar('vote_submitted_successfully'.tr, isError: false);
      }
      await getPlaceDetails(placeId);
      await getVoteStatus(placeId);
      // Refresh rankings so podium/top voters reflect the new vote,
      // then recompute ▲/▼ movement once fresh data is in.
      //
      // `notify: false` on all three is deliberate and now actually pays:
      // `refreshRankDeltas` repaints the board and the podium once, together,
      // instead of each response repainting on arrival. The trailing bare
      // `update()` that used to sit here undid exactly that.
      Future.wait([
        getLeaderboard(limit: 3, reload: true, notify: false),
        getTopVoters(reload: true, notify: false),
        getPlaces(reload: true, notify: false),
      ]).then((_) {
        refreshRankDeltas();
        update([idPlaces]);
      });
      return true;
    } else {
      showCustomSnackBar(
        response.body?['message'] ?? 'failed_to_submit_vote'.tr,
        isError: true,
      );
      return false;
    }
  }

  /// Submit or update a review. Independent of voting: this never casts,
  /// moves or removes a vote, and the review outlives the weekly round.
  Future<bool> submitReview(
    int placeId,
    int? rating, {
    String? review,
    String? imagePath,
  }) async {
    // `_isVoting` notifies nothing — see `submitVote`.
    _isVoting = true;

    final response = await placesServiceInterface.submitReview(
      placeId,
      rating,
      review,
      imagePath: imagePath,
    );
    _isVoting = false;

    if (response.statusCode == 200) {
      // No success toast: the sheet closes on `true` and the review list
      // refreshes behind it, so the user watches their own review appear.
      // All three of these already notify `idDetails`, so the trailing
      // full-screen `update()` that used to follow them was pure waste.
      await getPlaceDetails(placeId);
      await getPlaceReviews(placeId, reload: true);
      await getVoteStatus(placeId);
      return true;
    }
    showCustomSnackBar(
      response.body?['message'] ?? 'failed_to_submit_review'.tr,
      isError: true,
    );
    return false;
  }

  /// Remove the caller's review. Leaves their vote untouched.
  Future<bool> removeReview(int placeId) async {
    _isVoting = true;

    final response = await placesServiceInterface.removeReview(placeId);
    _isVoting = false;

    if (response.statusCode == 200) {
      // Silent for the same reason as submit: the sheet closes and the review
      // visibly disappears from the refreshed list. Each call notifies
      // `idDetails` on its own.
      await getPlaceDetails(placeId);
      await getPlaceReviews(placeId, reload: true);
      await getVoteStatus(placeId);
      return true;
    }
    showCustomSnackBar(
      response.body?['message'] ?? 'failed_to_remove_review'.tr,
      isError: true,
    );
    return false;
  }

  /// Remove vote
  Future<bool> removeVote(int placeId, {bool silent = false}) async {
    // See `submitVote`: `_isVoting` has no readers, so it notifies nothing.
    _isVoting = true;

    var response = await placesServiceInterface.removeVote(placeId);
    _isVoting = false;

    if (response.statusCode == 200) {
      if (!silent) {
        showCustomSnackBar('vote_removed_successfully'.tr, isError: false);
      }
      _voteStatus = VoteStatus(hasVoted: false);
      await getPlaceDetails(placeId);
      Future.wait([
        getLeaderboard(limit: 3, reload: true, notify: false),
        getTopVoters(reload: true, notify: false),
        getPlaces(reload: true, notify: false),
      ]).then((_) {
        refreshRankDeltas();
        update([idPlaces]);
      });
      return true;
    } else {
      showCustomSnackBar(
        response.body?['message'] ?? 'failed_to_remove_vote'.tr,
        isError: true,
      );
      return false;
    }
  }

  /// Report a review
  Future<bool> reportReview(int voteId, String reason) async {
    var response = await placesServiceInterface.reportVote(voteId, reason);
    if (response.statusCode == 200) {
      showCustomSnackBar('report_submitted'.tr, isError: false);
      return true;
    } else {
      showCustomSnackBar(
        response.body?['message'] ?? 'failed_to_report'.tr,
        isError: true,
      );
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // FAVORITES
  // ═══════════════════════════════════════════════════════════════

  /// Fetch user's favorite places
  Future<void> getFavorites({bool reload = false}) async {
    if (_favoritesList != null && !reload) return;
    _isFavoritesLoading = true;
    // The heart on the details screen is the only thing favourites render on
    // a Spots surface; the home's cards do not show favourite state.
    update([idDetails]);

    _favoritesList = await placesServiceInterface.getFavorites();
    _isFavoritesLoading = false;
    update([idDetails]);
  }

  /// Toggle favorite for a place
  Future<bool> toggleFavorite(int placeId) async {
    var response = await placesServiceInterface.toggleFavorite(placeId);
    if (response.statusCode == 200) {
      // Refresh favorites list
      getFavorites(reload: true);
      // Update place details if viewing
      if (_placeDetails != null && _placeDetails!.id == placeId) {
        getPlaceDetails(placeId);
      }
      return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════════
  // SUBMISSIONS
  // ═══════════════════════════════════════════════════════════════

  /// Fetch user's submissions
  Future<void> getMySubmissions({bool reload = false}) async {
    if (_submissionsList != null && !reload) return;
    _isSubmissionsLoading = true;
    update();

    _submissionsList = await placesServiceInterface.getMySubmissions();
    _isSubmissionsLoading = false;
    update();
  }

  /// Submit a new hidden gem
  Future<bool> submitNewPlace(
    Map<String, String> fields, {
    String? imagePath,
  }) async {
    _isSubmitting = true;
    update();

    var response = await placesServiceInterface.submitPlace(
      fields,
      imagePath: imagePath,
    );
    _isSubmitting = false;

    if (response.statusCode == 200 || response.statusCode == 201) {
      showCustomSnackBar('submission_sent_successfully'.tr, isError: false);
      getMySubmissions(reload: true);
      update();
      return true;
    } else {
      showCustomSnackBar(
        response.body?['message'] ?? 'failed_to_submit'.tr,
        isError: true,
      );
      update();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // FILTERS & UI STATE
  // ═══════════════════════════════════════════════════════════════

  /// Set selected category
  void setSelectedCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    // The chip strip is the only thing that renders the selection; `getPlaces`
    // repaints the list itself when it lands.
    update([idFilters]);
    getPlaces(categoryId: categoryId, reload: true);
  }

  /// Toggle a tag filter
  void toggleTag(int tagId) {
    if (_selectedTagIds.contains(tagId)) {
      _selectedTagIds.remove(tagId);
    } else {
      _selectedTagIds.add(tagId);
    }
    update();
    getPlaces(reload: true);
  }

  /// Clear all tag filters
  void clearTagFilters() {
    _selectedTagIds = [];
    update();
    getPlaces(reload: true);
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    update();
  }

  /// Search places
  void searchPlaces(String query) {
    _searchQuery = query;
    update();
    getPlaces(search: query, reload: true);
  }

  /// Set sort option
  void setSortBy(String sort) {
    if (_sortBy == sort) return;
    _sortBy = sort;
    // The chip strip shows the selection; `getPlaces` repaints the list.
    update([idFilters]);
    getPlaces(reload: true);
  }

  /// Set zone filter
  void setSelectedZone(int? zoneId) {
    _selectedZoneId = zoneId;
    _lastComputedRanks = null; // rank snapshots are per-zone
    _updateZoneRaceTopic(zoneId);
    // The masthead's area line and the sheet's chips are what show the new
    // scope immediately; the four refetches below repaint their own sections.
    update([idMasthead, idFilters]);
    // Refresh leaderboard, places, and top voters when zone changes
    Future.wait([
      getLeaderboard(zoneId: zoneId, limit: 3, reload: true),
      getTopVoters(zoneId: zoneId, reload: true),
      getPlaces(zoneId: zoneId, reload: true),
      getLatestWinner(reload: true, notify: false),
    ]).then((_) => refreshRankDeltas());
  }

  /// Set banner index
  void setCurrentBannerIndex(int index) {
    _currentBannerIndex = index;
    update();
  }

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZATION & CLEANUP
  // ═══════════════════════════════════════════════════════════════

  /// Initialize places module data (home screen only needs categories + leaderboard + top voters)
  void _clearHomeLoadingFlags() {
    _isZonesLoading = false;
    _isCategoriesLoading = false;
    _isLeaderboardLoading = false;
    _isTopVotersLoading = false;
    _isPlacesLoading = false;
    _isRecentWinnersLoading = false;
  }

  Future<void> initializePlacesData({bool reload = false}) async {
    // Prevent double initialization
    if (_isInitializing) {
      debugPrint(
        '⏭️ [PLACES] initializePlacesData() - Already initializing, skipping...',
      );
      return;
    }
    if (_isInitialized && !reload) {
      debugPrint(
        '⏭️ [PLACES] initializePlacesData() - Already initialized, skipping (call with reload: true to force)',
      );
      return;
    }

    _isInitializing = true;

    // ── Phase 1: paint from cache ──────────────────────────────────
    // Serve last session's board before touching the network, so a relaunch
    // shows the screen it showed before instead of a shimmer. Skipped on an
    // explicit reload (pull-to-refresh means "go and ask"), and skipped once
    // anything is already in memory.
    bool servedFromCache = false;
    if (!reload && !hasAnyHomeData) {
      try {
        await Future.wait([
          getZones(notify: false, source: DataSourceEnum.local),
          getCategories(notify: false, source: DataSourceEnum.local),
          getLeaderboard(limit: 3, notify: false, source: DataSourceEnum.local),
          getTopVoters(notify: false, source: DataSourceEnum.local),
          getPlaces(notify: false, source: DataSourceEnum.local),
        ]);
      } catch (e) {
        debugPrint('⚠️ [PLACES] cache prime failed: $e');
      }
      servedFromCache = hasAnyHomeData;
      if (servedFromCache) {
        // Real content is on screen; the network pass below is a silent
        // refresh behind it, so no section may flip back to a skeleton.
        update(idAllHome);
      }
    }

    // Cached data that is still inside its TTL is good enough — skip the
    // network entirely and let the next open (or a pull-to-refresh) fetch.
    if (servedFromCache &&
        !CacheTtlHelper.isStale(_homeCacheKey, ttl: homeCacheTtl)) {
      // The cache fetchers set their own loading flags on the way in (they
      // run the same code path as a network call), so they have to be cleared
      // here too — otherwise this early return leaves the sections that read
      // them pinned to a skeleton over data that is already loaded.
      _clearHomeLoadingFlags();
      _isInitializing = false;
      _isInitialized = true;
      _hasInitError = false;
      update(idAllHome);
      unawaited(refreshRankDeltas());
      return;
    }

    // ── Phase 2: network ───────────────────────────────────────────
    // Loading flags only when there is nothing to show behind them.
    if (!servedFromCache) {
      _isZonesLoading = true;
      _isCategoriesLoading = true;
      _isLeaderboardLoading = true;
      _isTopVotersLoading = true;
      _isPlacesLoading = true;
      _isRecentWinnersLoading = true;
      update(idAllHome);
    }

    subscribeRaceTopics();

    // Each call repaints its own section the moment it lands, rather than the
    // whole screen waiting on the slowest of seven. `notify: true` is what
    // buys that — the ids added above keep it to one section per response,
    // so progressive rendering costs no extra rebuild work.
    //
    // Errors are collected per call instead of aborting the batch: one dead
    // endpoint used to blank the entire screen behind the error card even
    // though the other six had returned perfectly good data.
    Future<void> guard(Future<void> call, String label) async {
      try {
        await call;
      } catch (e) {
        debugPrint('❌ [PLACES] init call "$label" failed: $e');
        _initFailures++;
      }
    }

    _initFailures = 0;
    // `reload` has to be forced once the cache pass filled these fields, or
    // every fetcher's `if (_x != null && !reload) return;` guard would turn
    // the network pass into a no-op and the cached board would never refresh.
    final bool net = reload || servedFromCache;
    await Future.wait([
      guard(getZones(reload: net), 'zones'),
      guard(getCategories(reload: net), 'categories'),
      guard(getLeaderboard(limit: 3, reload: net), 'leaderboard'),
      guard(getTopVoters(reload: net), 'topVoters'),
      guard(getPlaces(reload: net), 'places'),
      guard(getLatestWinner(reload: net), 'latestWinner'),
      guard(getRecentWinners(reload: net), 'recentWinners'),
    ]);
    if (_initFailures == 0) CacheTtlHelper.markFresh(_homeCacheKey);
    // Only a total wipeout is an error state — partial data still renders.
    _hasInitError = !hasAnyHomeData && _initFailures > 0;

    debugPrint(
      '[PLACES] init done — zones:${_zones?.length ?? 0} '
      'cats:${_categories?.length ?? 0} '
      'board:${_leaderboardList?.places.length ?? 0} '
      'voters:${_topVotersList?.voters.length ?? 0}',
    );

    // No fake podium fallback: below the official threshold PodiumSection
    // renders live standings (real votes + movement), never fake ranks.
    //
    // Deliberately not awaited: this is a SharedPreferences read that used to
    // sit between the last response and the first paint. Movement arrows are
    // a decoration on standings that are already on screen, so they can land
    // a frame later.
    unawaited(refreshRankDeltas());

    // Clear ALL loading flags — a failed getPlaces would otherwise leave
    // _isPlacesLoading stuck on true (it only clears itself on success).
    _clearHomeLoadingFlags();
    _isInitializing = false;
    // Only mark initialized on success so a plain retry isn't a no-op.
    if (!_hasInitError) _isInitialized = true;
    update(idAllHome);

    debugPrint(
      '══════════════════════════════════════════════════════════════',
    );
    debugPrint('🎉 [PLACES] initializePlacesData() COMPLETED');
    debugPrint(
      '══════════════════════════════════════════════════════════════',
    );
  }

  /// Retry entry point for the home error card.
  Future<void> retryInitialize() => initializePlacesData(reload: true);

  /// Clear all data
  void clearPlacesData() {
    _categories = null;
    _placeList = null;
    _leaderboardList = null;
    _trendingList = null;
    _tags = null;
    _selectedTagIds = [];
    _banners = null;
    _placeDetails = null;
    _detailsErrorStatus = null;
    _reviewList = null;
    _reviewsPage = 1;
    _voteStatus = null;
    _favoritesList = null;
    _submissionsList = null;
    _topVotersList = null;
    _latestWinner = null;
    _winnersHistory = null;
    _rankDeltas = {};
    _newEntries = {};
    _lastComputedRanks = null;
    _selectedCategoryId = null;
    _selectedZoneId = null;
    _searchQuery = '';
    _sortBy = 'rating';
    _currentBannerIndex = 0;
    _zonesLoaded = false;
    // Everything on the home is now empty, so every home section repaints.
    update(idAllHome);
  }
}
