import 'package:get/get_connect/http/src/response/response.dart';
import 'package:waddy_app/features/places/domain/models/place_category_model.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/models/place_banner_model.dart';
import 'package:waddy_app/features/places/domain/models/place_vote_model.dart';
import 'package:waddy_app/features/places/domain/models/place_winner_model.dart';
import 'package:waddy_app/features/places/domain/models/place_prize_model.dart';
import 'package:waddy_app/features/places/domain/models/place_review_model.dart';
import 'package:waddy_app/features/places/domain/models/place_submission_model.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';

abstract class PlacesServiceInterface {
  /// Get all place categories
  Future<List<PlaceCategory>?> getCategories({DataSourceEnum source});

  /// Get all zones for filter chips
  Future<List<PlaceZone>?> getZones({DataSourceEnum source});

  /// Get places with optional filters
  Future<PlaceList?> getPlaces({
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
  Future<PlaceList?> getLeaderboard({
    String? period,
    int? zoneId,
    int? limit,
    DataSourceEnum source,
  });

  /// Get trending/rising places
  Future<PlaceList?> getTrending();

  Future<PlaceWinner?> getLatestWinner({int? zoneId});

  Future<List<PlaceWinner>?> getWinners({int? zoneId, int limit = 24});

  /// Get all available tags
  Future<List<PlaceTag>?> getTags();

  /// Get featured banners
  Future<List<PlaceBanner>?> getFeaturedBanners();

  /// Get place details.
  ///
  /// Returns the HTTP status alongside the place so the details screen can
  /// tell a deleted spot (404) from an unreachable network, instead of
  /// reporting every failure as "no internet".
  Future<({Place? place, int? statusCode})> getPlaceDetails(int placeId);

  /// Get paginated reviews for a place
  Future<PlaceReviewList?> getPlaceReviews(int placeId, {int offset = 1});

  /// Get top voters
  Future<TopVoterList?> getTopVoters({
    int? zoneId,
    int limit = 10,
    DataSourceEnum source,
  });

  Future<PlacePrizeList?> getMyPrizes();

  Future<List<RecentWinner>?> getRecentWinners({int limit = 10});

  /// Submit or update vote (now supports photo)
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
