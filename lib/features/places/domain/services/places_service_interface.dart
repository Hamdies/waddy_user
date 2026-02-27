import 'package:get/get_connect/http/src/response/response.dart';
import 'package:sixam_mart/features/places/domain/models/place_category_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_banner_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_vote_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_review_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_submission_model.dart';

abstract class PlacesServiceInterface {
  /// Get all place categories
  Future<List<PlaceCategory>?> getCategories();

  /// Get places with optional filters
  Future<PlaceList?> getPlaces({
    int? categoryId,
    String? search,
    double? lat,
    double? lng,
    String? sort,
    List<int>? tagIds,
    int offset = 1,
  });

  /// Get leaderboard (top voted places)
  Future<PlaceList?> getLeaderboard({String? period});

  /// Get trending/rising places
  Future<PlaceList?> getTrending();

  /// Get all available tags
  Future<List<PlaceTag>?> getTags();

  /// Get featured banners
  Future<List<PlaceBanner>?> getFeaturedBanners();

  /// Get place details
  Future<Place?> getPlaceDetails(int placeId);

  /// Get paginated reviews for a place
  Future<PlaceReviewList?> getPlaceReviews(int placeId, {int offset = 1});

  /// Submit or update vote (now supports photo)
  Future<Response> submitVote(int placeId, int rating, String? comment, {String? imagePath});

  /// Remove vote
  Future<Response> removeVote(int placeId);

  /// Get vote status
  Future<VoteStatus?> getVoteStatus(int placeId);

  /// Report a vote
  Future<Response> reportVote(int voteId, String reason);

  /// Get user's favorite places
  Future<PlaceList?> getFavorites();

  /// Toggle favorite
  Future<Response> toggleFavorite(int placeId);

  /// Get user's submissions
  Future<PlaceSubmissionList?> getMySubmissions();

  /// Submit a new hidden gem
  Future<Response> submitPlace(Map<String, String> fields, {String? imagePath});

  /// Get submission detail
  Future<PlaceSubmission?> getSubmissionDetail(int submissionId);
}
