import 'package:get/get_connect/http/src/response/response.dart';

abstract class PlacesRepositoryInterface {
  /// Get all place categories
  Future<Response> getCategories();

  /// Get all places with optional filters
  Future<Response> getPlaces({
    int? categoryId,
    String? search,
    double? lat,
    double? lng,
    String? sort,
    List<int>? tagIds,
    int offset = 1,
  });

  /// Get leaderboard (top voted places)
  Future<Response> getLeaderboard({String? period});

  /// Get trending/rising places
  Future<Response> getTrending();

  /// Get all available tags
  Future<Response> getTags();

  /// Get featured banners
  Future<Response> getFeaturedBanners();

  /// Get place details
  Future<Response> getPlaceDetails(int placeId);

  /// Get paginated reviews for a place
  Future<Response> getPlaceReviews(int placeId, {int offset = 1});

  /// Submit or update vote (requires auth) — now supports photo
  Future<Response> submitVote(int placeId, int rating, String? comment, {String? imagePath});

  /// Remove vote (requires auth)
  Future<Response> removeVote(int placeId);

  /// Check vote status (requires auth)
  Future<Response> getVoteStatus(int placeId);

  /// Report a vote
  Future<Response> reportVote(int voteId, String reason);

  /// Get user's favorite places
  Future<Response> getFavorites();

  /// Add place to favorites
  Future<Response> addFavorite(int placeId);

  /// Remove place from favorites
  Future<Response> removeFavorite(int placeId);

  /// Toggle favorite
  Future<Response> toggleFavorite(int placeId);

  /// Get user's submissions
  Future<Response> getMySubmissions();

  /// Submit a new hidden gem
  Future<Response> submitPlace(Map<String, String> fields, {String? imagePath});

  /// Get submission detail
  Future<Response> getSubmissionDetail(int submissionId);
}
