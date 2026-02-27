import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/features/places/domain/models/place_category_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_banner_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_vote_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_review_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_submission_model.dart';
import 'package:sixam_mart/features/places/domain/services/places_service_interface.dart';

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
  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  String _sortBy = 'rating';
  String get sortBy => _sortBy;

  // ═══════════════════════════════════════════════════════════════
  // FETCH METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Fetch categories
  Future<void> getCategories({bool reload = false, bool notify = true}) async {
    if (_categories != null && !reload) return;
    if (notify) {
      _isCategoriesLoading = true;
      update();
    }

    _categories = await placesServiceInterface.getCategories();
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
  Future<void> getLeaderboard({String? period, bool reload = false, bool notify = true}) async {
    if (_leaderboardList != null && !reload && period == null) return;
    if (notify) {
      _isLeaderboardLoading = true;
      update();
    } else {
      _isLeaderboardLoading = true;
    }

    _leaderboardList = await placesServiceInterface.getLeaderboard(
      period: period,
    );
    _isLeaderboardLoading = false;
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

  /// Set banner index
  void setCurrentBannerIndex(int index) {
    _currentBannerIndex = index;
    update();
  }

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZATION & CLEANUP
  // ═══════════════════════════════════════════════════════════════

  /// Initialize places module data
  Future<void> initializePlacesData() async {
    // Batch all loading flags into a single update() to avoid
    // multiple update() calls colliding during the build phase.
    _isCategoriesLoading = true;
    _isTagsLoading = true;
    _isBannersLoading = true;
    _isPlacesLoading = true;
    _isLeaderboardLoading = true;
    _isTrendingLoading = true;
    update();

    try {
      await Future.wait([
        getCategories(notify: false),
        getTags(notify: false),
        getFeaturedBanners(notify: false),
        getPlaces(reload: true, notify: false),
        getLeaderboard(notify: false),
        getTrending(notify: false),
      ]);
    } catch (e) {
      debugPrint('PlacesController.initializePlacesData error: $e');
    }
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
    _selectedCategoryId = null;
    _searchQuery = '';
    _sortBy = 'rating';
    _currentBannerIndex = 0;
    update();
  }
}
