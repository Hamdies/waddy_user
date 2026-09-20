import 'package:get/get_connect/http/src/response/response.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';

abstract class PlacesRepositoryInterface {
  /// Get all place categories
  Future<Response> getCategories({DataSourceEnum source});

  /// Get all zones for filter chips
  Future<Response> getZones({DataSourceEnum source});

  /// Get all places with optional filters
  Future<Response> getPlaces({
    int? categoryId,
    String? search,
    double? lat,
    double? lng,
    String? sort,
    List<int>? tagIds,
    int? zoneId,
    int offset = 1,
    DataSourceEnum source,
  });

  /// Get leaderboard (top voted places)
  Future<Response> getLeaderboard({
    String? period,
    int? zoneId,
    int? limit,
    DataSourceEnum source,
  });

  /// Get trending/rising places
  Future<Response> getTrending();

  Future<Response> getLatestWinner({int? zoneId});

  Future<Response> getWinners({int? zoneId, int limit = 24});

  /// Get all available tags
  Future<Response> getTags();

  /// Get featured banners
  Future<Response> getFeaturedBanners();

  /// Get place details
  Future<Response> getPlaceDetails(int placeId);

  /// Get paginated reviews for a place
  Future<Response> getPlaceReviews(int placeId, {int offset = 1});

  /// Get top voters
  Future<Response> getTopVoters({
    int? zoneId,
    int limit = 10,
    DataSourceEnum source,
  });

  Future<Response> getMyPrizes();

  /// The claw-machine replay for [period], or the last closed period when
  /// omitted. Public — a losing voter and a passer-by both get the machine.
  Future<Response> getDraw({String? period});

  Future<Response> getRecentWinners({int limit = 10});

  /// Submit or update vote (requires auth) — now supports photo
  Future<Response> submitVote(
    int placeId,
    int? rating,
    String? comment, {
    String? imagePath,
    bool switchVote = false,
  });

  /// Submit or update the caller's review (independent of voting)
  Future<Response> submitReview(
    int placeId,
    int? rating,
    String? review, {
    String? imagePath,
  });

  /// Remove the caller's review (leaves any vote intact)
  Future<Response> removeReview(int placeId);

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
