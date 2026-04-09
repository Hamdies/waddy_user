import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/places/domain/models/place_category_model.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/models/place_banner_model.dart';
import 'package:waddy_app/features/places/domain/models/place_vote_model.dart';
import 'package:waddy_app/features/places/domain/models/place_review_model.dart';
import 'package:waddy_app/features/places/domain/models/place_submission_model.dart';
import 'package:waddy_app/features/places/domain/services/places_service_interface.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';

class PlacesController extends GetxController implements GetxService {
  final PlacesServiceInterface placesServiceInterface;

  PlacesController({required this.placesServiceInterface});

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

  // ─── Reviews ───
  PlaceReviewList? _reviewList;
  List<PlaceReview>? get reviews => _reviewList?.reviews;
  int? get totalReviews => _reviewList?.totalSize;
  bool _isReviewsLoading = false;
  bool get isReviewsLoading => _isReviewsLoading;

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

  // ─── Zones ───
  List<PlaceZone>? _zones;
  List<PlaceZone>? get zones => _zones;
  bool _isZonesLoading = false;
  bool get isZonesLoading => _isZonesLoading;

  // ═══════════════════════════════════════════════════════════════
  // FETCH METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Fetch zones for filter chips
  Future<void> getZones({bool reload = false, bool notify = true}) async {
    if (_zones != null && !reload) return;
    if (notify) {
      _isZonesLoading = true;
      update();
    }

    debugPrint('📡 [PLACES] getZones() - Calling API...');
    _zones = await placesServiceInterface.getZones();
    debugPrint('📥 [PLACES] getZones() - Response: ${_zones?.length ?? 0} zones');
    if (_zones != null && _zones!.isNotEmpty) {
      debugPrint('   Zones: ${_zones!.map((z) => z.displayName ?? z.name).join(', ')}');
    } else {
      debugPrint('   ⚠️ Zones response is null or empty!');
    }
    _isZonesLoading = false;
    update();
  }

  /// Fetch categories
  Future<void> getCategories({bool reload = false, bool notify = true}) async {
    if (_categories != null && !reload) return;
    if (notify) {
      _isCategoriesLoading = true;
      update();
    }

    debugPrint('📡 [PLACES] getCategories() - Calling API...');
    _categories = await placesServiceInterface.getCategories();
    debugPrint('📥 [PLACES] getCategories() - Response: ${_categories?.length ?? 0} categories');
    if (_categories != null && _categories!.isNotEmpty) {
      debugPrint('   Categories: ${_categories!.map((c) => c.name).join(', ')}');
    } else {
      debugPrint('   ⚠️ Categories response is null or empty!');
    }
    _isCategoriesLoading = false;
    update();
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
  }) async {
    if (offset == 1 || reload) {
      _isPlacesLoading = true;
      if (notify) update();
    }

    PlaceList? result = await placesServiceInterface.getPlaces(
      categoryId: categoryId ?? _selectedCategoryId,
      search: search ?? _searchQuery,
      lat: lat,
      lng: lng,
      sort: sort ?? _sortBy,
      tagIds: tagIds ?? (_selectedTagIds.isNotEmpty ? _selectedTagIds : null),
      zoneId: zoneId ?? _selectedZoneId,
      offset: offset,
    );

    if (result != null) {
      if (offset == 1 || reload) {
        _placeList = result;
      } else {
        _placeList = PlaceList(
          places: [...(_placeList?.places ?? []), ...result.places],
          totalSize: result.totalSize,
          offset: result.offset,
        );
      }
    }

    _isPlacesLoading = false;
    update();
  }

  /// Fetch leaderboard
  Future<void> getLeaderboard({
    String? period,
    int? zoneId,
    int? limit,
    bool reload = false,
    bool notify = true,
  }) async {
    if (_leaderboardList != null && !reload && period == null) return;
    if (notify) {
      _isLeaderboardLoading = true;
      update();
    } else {
      _isLeaderboardLoading = true;
    }

    debugPrint('📡 [PLACES] getLeaderboard() - Calling API (zoneId: ${zoneId ?? _selectedZoneId}, limit: $limit)...');
    _leaderboardList = await placesServiceInterface.getLeaderboard(
      period: period,
      zoneId: zoneId ?? _selectedZoneId,
      limit: limit,
    );
    debugPrint('📥 [PLACES] getLeaderboard() - Response: ${_leaderboardList?.places.length ?? 0} places');
    if (_leaderboardList != null && _leaderboardList!.places.isNotEmpty) {
      debugPrint('   Places: ${_leaderboardList!.places.map((p) => '${p.title}(${p.votesCount} votes)').join(', ')}');
    } else {
      debugPrint('   ⚠️ Leaderboard response is null or empty!');
    }
    _isLeaderboardLoading = false;
    update();
  }

  /// Fetch top voters
  Future<void> getTopVoters({int? zoneId, int limit = 10, bool reload = false, bool notify = true}) async {
    if (_topVotersList != null && !reload) return;
    if (notify) {
      _isTopVotersLoading = true;
      update();
    } else {
      _isTopVotersLoading = true;
    }

    debugPrint('📡 [PLACES] getTopVoters() - Calling API (zoneId: ${zoneId ?? _selectedZoneId}, limit: $limit)...');
    _topVotersList = await placesServiceInterface.getTopVoters(
      zoneId: zoneId ?? _selectedZoneId,
      limit: limit,
    );
    debugPrint('📥 [PLACES] getTopVoters() - Response: ${_topVotersList?.voters.length ?? 0} voters');
    if (_topVotersList != null && _topVotersList!.voters.isNotEmpty) {
      debugPrint('   Voters: ${_topVotersList!.voters.map((v) => '${v.name}(${v.votesCount} votes)').join(', ')}');
    } else {
      debugPrint('   ⚠️ TopVoters response is null or empty!');
    }
    _isTopVotersLoading = false;
    update();
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
  Future<void> getFeaturedBanners({bool reload = false, bool notify = true}) async {
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
  Future<void> getPlaceDetails(int placeId) async {
    _isDetailsLoading = true;
    _placeDetails = null;
    update();

    _placeDetails = await placesServiceInterface.getPlaceDetails(placeId);
    _isDetailsLoading = false;
    update();
  }

  /// Fetch paginated reviews for a place
  Future<void> getPlaceReviews(int placeId, {int offset = 1, bool reload = false}) async {
    if (offset == 1 || reload) {
      _isReviewsLoading = true;
      update();
    }

    PlaceReviewList? result = await placesServiceInterface.getPlaceReviews(
      placeId,
      offset: offset,
    );

    if (result != null) {
      if (offset == 1 || reload) {
        _reviewList = result;
      } else {
        _reviewList = PlaceReviewList(
          reviews: [...(_reviewList?.reviews ?? []), ...result.reviews],
          totalSize: result.totalSize,
          offset: result.offset,
        );
      }
    }

    _isReviewsLoading = false;
    update();
  }

  // ═══════════════════════════════════════════════════════════════
  // VOTING
  // ═══════════════════════════════════════════════════════════════

  /// Check vote status
  Future<void> getVoteStatus(int placeId) async {
    _voteStatus = await placesServiceInterface.getVoteStatus(placeId);
    update();
  }

  /// Submit vote (now supports photo)
  Future<bool> submitVote(int placeId, int rating, {String? comment, String? imagePath}) async {
    _isVoting = true;
    update();

    var response = await placesServiceInterface.submitVote(
      placeId,
      rating,
      comment,
      imagePath: imagePath,
    );
    _isVoting = false;

    if (response.statusCode == 200) {
      showCustomSnackBar('vote_submitted_successfully'.tr, isError: false);
      await getPlaceDetails(placeId);
      await getVoteStatus(placeId);
      update();
      return true;
    } else {
      showCustomSnackBar(
        response.body?['message'] ?? 'failed_to_submit_vote'.tr,
        isError: true,
      );
      update();
      return false;
    }
  }

  /// Remove vote
  Future<bool> removeVote(int placeId) async {
    _isVoting = true;
    update();

    var response = await placesServiceInterface.removeVote(placeId);
    _isVoting = false;

    if (response.statusCode == 200) {
      showCustomSnackBar('vote_removed_successfully'.tr, isError: false);
      _voteStatus = VoteStatus(hasVoted: false);
      await getPlaceDetails(placeId);
      update();
      return true;
    } else {
      showCustomSnackBar(
        response.body?['message'] ?? 'failed_to_remove_vote'.tr,
        isError: true,
      );
      update();
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
    update();

    _favoritesList = await placesServiceInterface.getFavorites();
    _isFavoritesLoading = false;
    update();
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
  Future<bool> submitNewPlace(Map<String, String> fields, {String? imagePath}) async {
    _isSubmitting = true;
    update();

    var response = await placesServiceInterface.submitPlace(fields, imagePath: imagePath);
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
    update();
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
    _sortBy = sort;
    update();
    getPlaces(reload: true);
  }

  /// Set zone filter
  void setSelectedZone(int? zoneId) {
    _selectedZoneId = zoneId;
    update();
    // Refresh leaderboard, places, and top voters when zone changes
    getLeaderboard(zoneId: zoneId, limit: 3, reload: true);
    getTopVoters(zoneId: zoneId, reload: true);
    getPlaces(zoneId: zoneId, reload: true);
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
  Future<void> initializePlacesData({bool reload = false}) async {
    // Prevent double initialization
    if (_isInitializing) {
      debugPrint('⏭️ [PLACES] initializePlacesData() - Already initializing, skipping...');
      return;
    }
    if (_isInitialized && !reload) {
      debugPrint('⏭️ [PLACES] initializePlacesData() - Already initialized, skipping (call with reload: true to force)');
      return;
    }

    _isInitializing = true;
    debugPrint('══════════════════════════════════════════════════════════════');
    debugPrint('🚀 [PLACES] initializePlacesData() STARTED (reload: $reload)');
    debugPrint('══════════════════════════════════════════════════════════════');

    // Set loading flags and show shimmer
    _isZonesLoading = true;
    _isCategoriesLoading = true;
    _isLeaderboardLoading = true;
    _isTopVotersLoading = true;
    _isPlacesLoading = true;
    update();

    try {
      // Call APIs
      debugPrint('📡 [PLACES] Calling APIs in parallel...');
      await Future.wait([
        getZones(reload: reload, notify: false),
        getCategories(reload: reload, notify: false),
        getLeaderboard(limit: 3, reload: reload, notify: false),
        getTopVoters(reload: reload, notify: false),
        getPlaces(reload: reload, notify: false),
      ]);
      debugPrint('✅ [PLACES] All API calls completed');
    } catch (e, stackTrace) {
      debugPrint('❌ [PLACES] initializePlacesData error: $e');
      debugPrint('❌ [PLACES] StackTrace: $stackTrace');
    }

    // Log current state before fallback check
    debugPrint('────────────────────────────────────────────────────────────────');
    debugPrint('📊 [PLACES] API Response Status:');
    debugPrint('   Zones: ${_zones?.length ?? 0} zones');
    debugPrint('   Categories: ${_categories?.length ?? 0} items');
    debugPrint('   Leaderboard: ${_leaderboardList?.places.length ?? 0} places');
    debugPrint('   Top Voters: ${_topVotersList?.voters.length ?? 0} voters');
    debugPrint('────────────────────────────────────────────────────────────────');

    // If leaderboard is empty, fetch real places as fallback for podium
    if (_leaderboardList == null || _leaderboardList!.places.isEmpty) {
      debugPrint('📡 [PLACES] Leaderboard empty - fetching real places as podium fallback...');
      try {
        final fallbackPlaces = await placesServiceInterface.getPlaces(offset: 1);
        if (fallbackPlaces != null && fallbackPlaces.places.isNotEmpty) {
          _leaderboardList = PlaceList(
            places: fallbackPlaces.places.take(3).toList(),
            totalSize: fallbackPlaces.places.take(3).length,
          );
          debugPrint('✅ [PLACES] Loaded ${_leaderboardList!.places.length} real places for podium: ${_leaderboardList!.places.map((p) => p.title).join(', ')}');
        } else {
          debugPrint('⚠️ [PLACES] No places available at all');
        }
      } catch (e) {
        debugPrint('❌ [PLACES] Failed to fetch fallback places: $e');
      }
    }

    // Clear loading flags
    _isZonesLoading = false;
    _isCategoriesLoading = false;
    _isLeaderboardLoading = false;
    _isTopVotersLoading = false;
    _isInitializing = false;
    _isInitialized = true;
    update();

    debugPrint('══════════════════════════════════════════════════════════════');
    debugPrint('🎉 [PLACES] initializePlacesData() COMPLETED');
    debugPrint('══════════════════════════════════════════════════════════════');
  }

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
    _reviewList = null;
    _voteStatus = null;
    _favoritesList = null;
    _submissionsList = null;
    _topVotersList = null;
    _selectedCategoryId = null;
    _selectedZoneId = null;
    _searchQuery = '';
    _sortBy = 'rating';
    _currentBannerIndex = 0;
    update();
  }
}
