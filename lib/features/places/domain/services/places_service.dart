import 'package:flutter/foundation.dart';
import 'package:get/get_connect/http/src/response/response.dart';
import 'package:waddy_app/features/places/domain/models/place_category_model.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/models/place_banner_model.dart';
import 'package:waddy_app/features/places/domain/models/place_vote_model.dart';
import 'package:waddy_app/features/places/domain/models/place_review_model.dart';
import 'package:waddy_app/features/places/domain/models/place_submission_model.dart';
import 'package:waddy_app/features/places/domain/models/place_winner_model.dart';
import 'package:waddy_app/features/places/domain/models/place_prize_model.dart';
import 'package:waddy_app/features/places/domain/models/spots_draw_round_model.dart';
import 'package:waddy_app/features/places/domain/repositories/places_repository_interface.dart';
import 'package:waddy_app/features/places/domain/services/places_service_interface.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';

class PlacesService implements PlacesServiceInterface {
  final PlacesRepositoryInterface placesRepositoryInterface;

  PlacesService({required this.placesRepositoryInterface});

  @override
  Future<List<PlaceCategory>?> getCategories({
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    Response response = await placesRepositoryInterface.getCategories(
      source: source,
    );
    if (response.statusCode == 200 && response.body != null) {
      try {
        final result = PlaceCategoryList.fromJson(response.body).categories;
        return result;
      } catch (e) {
        debugPrint('❌ [SERVICE] getCategories() - Parse error: $e');
        return null;
      }
    }
    debugPrint(
      '⚠️ [SERVICE] getCategories() - Returning null (status: ${response.statusCode})',
    );
    return null;
  }

  @override
  Future<List<PlaceZone>?> getZones({
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    Response response = await placesRepositoryInterface.getZones(
      source: source,
    );
    if (response.statusCode == 200 && response.body != null) {
      try {
        final result = PlaceZoneList.fromJson(response.body).zones;
        return result;
      } catch (e) {
        debugPrint('❌ [SERVICE] getZones() - Parse error: $e');
        return null;
      }
    }
    debugPrint(
      '⚠️ [SERVICE] getZones() - Returning null (status: ${response.statusCode})',
    );
    return null;
  }

  @override
  Future<PlaceList?> getPlaces({
    int? categoryId,
    String? search,
    double? lat,
    double? lng,
    String? sort,
    List<int>? tagIds,
    int? zoneId,
    int offset = 1,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    Response response = await placesRepositoryInterface.getPlaces(
      categoryId: categoryId,
      search: search,
      lat: lat,
      lng: lng,
      sort: sort,
      tagIds: tagIds,
      zoneId: zoneId,
      offset: offset,
      source: source,
    );
    if (response.statusCode == 200 && response.body != null) {
      return PlaceList.fromJson(response.body);
    }
    return null;
  }

  @override
  Future<PlaceList?> getLeaderboard({
    String? period,
    int? zoneId,
    int? limit,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    Response response = await placesRepositoryInterface.getLeaderboard(
      period: period,
      zoneId: zoneId,
      limit: limit,
      source: source,
    );
    if (response.statusCode == 200 && response.body != null) {
      try {
        final result = PlaceList.fromJson(response.body);
        return result;
      } catch (e) {
        debugPrint('❌ [SERVICE] getLeaderboard() - Parse error: $e');
        return null;
      }
    }
    debugPrint(
      '⚠️ [SERVICE] getLeaderboard() - Returning null (status: ${response.statusCode})',
    );
    return null;
  }

  @override
  Future<PlaceList?> getTrending() async {
    Response response = await placesRepositoryInterface.getTrending();
    if (response.statusCode == 200 && response.body != null) {
      return PlaceList.fromJson(response.body);
    }
    return null;
  }

  @override
  Future<PlaceWinner?> getLatestWinner({int? zoneId}) async {
    Response response = await placesRepositoryInterface.getLatestWinner(
      zoneId: zoneId,
    );
    if (response.statusCode == 200 && response.body?['data'] != null) {
      try {
        return PlaceWinner.fromJson(response.body['data']);
      } catch (e) {
        debugPrint('❌ [SERVICE] getLatestWinner() - Parse error: $e');
      }
    }
    return null;
  }

  @override
  Future<List<PlaceWinner>?> getWinners({int? zoneId, int limit = 24}) async {
    Response response = await placesRepositoryInterface.getWinners(
      zoneId: zoneId,
      limit: limit,
    );
    if (response.statusCode == 200 && response.body?['data'] is List) {
      try {
        return (response.body['data'] as List)
            .map((e) => PlaceWinner.fromJson(e))
            .toList();
      } catch (e) {
        debugPrint('❌ [SERVICE] getWinners() - Parse error: $e');
      }
    }
    return null;
  }

  @override
  Future<List<PlaceTag>?> getTags() async {
    Response response = await placesRepositoryInterface.getTags();
    if (response.statusCode == 200 && response.body != null) {
      final data = response.body['data'] ?? response.body;
      if (data is List) {
        return data.map((e) => PlaceTag.fromJson(e)).toList();
      }
    }
    return null;
  }

  @override
  Future<List<PlaceBanner>?> getFeaturedBanners() async {
    Response response = await placesRepositoryInterface.getFeaturedBanners();
    if (response.statusCode == 200 && response.body != null) {
      return PlaceBannerList.fromJson(response.body).banners;
    }
    return null;
  }

  @override
  Future<TopVoterList?> getTopVoters({
    int? zoneId,
    int limit = 10,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    Response response = await placesRepositoryInterface.getTopVoters(
      zoneId: zoneId,
      limit: limit,
      source: source,
    );
    if (response.statusCode == 200 && response.body != null) {
      try {
        final result = TopVoterList.fromJson(response.body);
        return result;
      } catch (e) {
        debugPrint('❌ [SERVICE] getTopVoters() - Parse error: $e');
        return null;
      }
    }
    debugPrint(
      '⚠️ [SERVICE] getTopVoters() - Returning null (status: ${response.statusCode})',
    );
    return null;
  }

  @override
  Future<PlacePrizeList?> getMyPrizes() async {
    Response response = await placesRepositoryInterface.getMyPrizes();
    if (response.statusCode == 200 && response.body != null) {
      try {
        return PlacePrizeList.fromJson(response.body);
      } catch (e) {
        debugPrint('❌ [SERVICE] getMyPrizes() - Parse error: $e');
        return null;
      }
    }
    debugPrint(
      '⚠️ [SERVICE] getMyPrizes() - Returning null (status: ${response.statusCode})',
    );
    return null;
  }

  @override
  Future<List<RecentWinner>?> getRecentWinners({int limit = 10}) async {
    Response response = await placesRepositoryInterface.getRecentWinners(
      limit: limit,
    );
    if (response.statusCode == 200 && response.body?['data'] is List) {
      try {
        return (response.body['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((e) => RecentWinner.fromJson(e))
            .toList();
      } catch (e) {
        debugPrint('❌ [SERVICE] getRecentWinners() - Parse error: $e');
      }
    }
    return null;
  }

  @override
  Future<({SpotsDrawRound? round, int? statusCode})> getDraw({
    String? period,
  }) async {
    final Response response = await placesRepositoryInterface.getDraw(
      period: period,
    );
    if (response.statusCode == 200 && response.body is Map<String, dynamic>) {
      try {
        return (
          round: SpotsDrawRound.fromJson(response.body as Map<String, dynamic>),
          statusCode: response.statusCode,
        );
      } catch (e) {
        debugPrint('❌ [SERVICE] getDraw() - Parse error: $e');
        return (round: null, statusCode: response.statusCode);
      }
    }
    return (round: null, statusCode: response.statusCode);
  }

  @override
  Future<({Place? place, int? statusCode})> getPlaceDetails(int placeId) async {
    Response response = await placesRepositoryInterface.getPlaceDetails(
      placeId,
    );
    if (response.statusCode == 200 && response.body != null) {
      var data = response.body['data'] ?? response.body;
      return (place: Place.fromJson(data), statusCode: response.statusCode);
    }
    return (place: null, statusCode: response.statusCode);
  }

  @override
  Future<PlaceReviewList?> getPlaceReviews(
    int placeId, {
    int offset = 1,
  }) async {
    Response response = await placesRepositoryInterface.getPlaceReviews(
      placeId,
      offset: offset,
    );
    if (response.statusCode == 200 && response.body != null) {
      return PlaceReviewList.fromJson(response.body);
    }
    return null;
  }

  @override
  Future<Response> submitVote(
    int placeId,
    int? rating,
    String? comment, {
    String? imagePath,
    bool switchVote = false,
  }) async {
    return await placesRepositoryInterface.submitVote(
      placeId,
      rating,
      comment,
      imagePath: imagePath,
      switchVote: switchVote,
    );
  }

  @override
  Future<Response> submitReview(
    int placeId,
    int? rating,
    String? review, {
    String? imagePath,
  }) async {
    return await placesRepositoryInterface.submitReview(
      placeId,
      rating,
      review,
      imagePath: imagePath,
    );
  }

  @override
  Future<Response> removeReview(int placeId) async {
    return await placesRepositoryInterface.removeReview(placeId);
  }

  @override
  Future<Response> removeVote(int placeId) async {
    return await placesRepositoryInterface.removeVote(placeId);
  }

  @override
  Future<VoteStatus?> getVoteStatus(int placeId) async {
    Response response = await placesRepositoryInterface.getVoteStatus(placeId);
    if (response.statusCode == 200 && response.body != null) {
      return VoteStatus.fromJson(response.body);
    }
    return null;
  }

  @override
  Future<Response> reportVote(int voteId, String reason) async {
    return await placesRepositoryInterface.reportVote(voteId, reason);
  }

  @override
  Future<PlaceList?> getFavorites() async {
    Response response = await placesRepositoryInterface.getFavorites();
    if (response.statusCode == 200 && response.body != null) {
      return PlaceList.fromJson(response.body);
    }
    return null;
  }

  @override
  Future<Response> toggleFavorite(int placeId) async {
    return await placesRepositoryInterface.toggleFavorite(placeId);
  }

  @override
  Future<PlaceSubmissionList?> getMySubmissions() async {
    Response response = await placesRepositoryInterface.getMySubmissions();
    if (response.statusCode == 200 && response.body != null) {
      return PlaceSubmissionList.fromJson(response.body);
    }
    return null;
  }

  @override
  Future<Response> submitPlace(
    Map<String, String> fields, {
    String? imagePath,
  }) async {
    return await placesRepositoryInterface.submitPlace(
      fields,
      imagePath: imagePath,
    );
  }

  @override
  Future<PlaceSubmission?> getSubmissionDetail(int submissionId) async {
    Response response = await placesRepositoryInterface.getSubmissionDetail(
      submissionId,
    );
    if (response.statusCode == 200 && response.body != null) {
      var data = response.body['data'] ?? response.body;
      return PlaceSubmission.fromJson(data);
    }
    return null;
  }
}
