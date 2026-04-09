import 'package:flutter/foundation.dart';
import 'package:get/get_connect/http/src/response/response.dart';
import 'package:waddy_app/features/places/domain/models/place_category_model.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/models/place_banner_model.dart';
import 'package:waddy_app/features/places/domain/models/place_vote_model.dart';
import 'package:waddy_app/features/places/domain/models/place_review_model.dart';
import 'package:waddy_app/features/places/domain/models/place_submission_model.dart';
import 'package:waddy_app/features/places/domain/repositories/places_repository_interface.dart';
import 'package:waddy_app/features/places/domain/services/places_service_interface.dart';

class PlacesService implements PlacesServiceInterface {
  final PlacesRepositoryInterface placesRepositoryInterface;

  PlacesService({required this.placesRepositoryInterface});

  @override
  Future<List<PlaceCategory>?> getCategories() async {
    debugPrint('🔵 [SERVICE] getCategories() - Calling repository...');
    Response response = await placesRepositoryInterface.getCategories();
    debugPrint('🔵 [SERVICE] getCategories() - Response status: ${response.statusCode}');
    debugPrint('🔵 [SERVICE] getCategories() - Response body: ${response.body}');
    if (response.statusCode == 200 && response.body != null) {
      try {
        final result = PlaceCategoryList.fromJson(response.body).categories;
        debugPrint('✅ [SERVICE] getCategories() - Parsed ${result?.length ?? 0} categories');
        return result;
      } catch (e) {
        debugPrint('❌ [SERVICE] getCategories() - Parse error: $e');
        return null;
      }
    }
    debugPrint('⚠️ [SERVICE] getCategories() - Returning null (status: ${response.statusCode})');
    return null;
  }

  @override
  Future<List<PlaceZone>?> getZones() async {
    debugPrint('🔵 [SERVICE] getZones() - Calling repository...');
    Response response = await placesRepositoryInterface.getZones();
    debugPrint('🔵 [SERVICE] getZones() - Response status: ${response.statusCode}');
    debugPrint('🔵 [SERVICE] getZones() - Response body: ${response.body}');
    if (response.statusCode == 200 && response.body != null) {
      try {
        final result = PlaceZoneList.fromJson(response.body).zones;
        debugPrint('✅ [SERVICE] getZones() - Parsed ${result.length} zones');
        return result;
      } catch (e) {
        debugPrint('❌ [SERVICE] getZones() - Parse error: $e');
        return null;
      }
    }
    debugPrint('⚠️ [SERVICE] getZones() - Returning null (status: ${response.statusCode})');
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
  }) async {
    debugPrint('🔵 [SERVICE] getLeaderboard() - Calling repository (zoneId: $zoneId, limit: $limit)...');
    Response response = await placesRepositoryInterface.getLeaderboard(
      period: period,
      zoneId: zoneId,
      limit: limit,
    );
    debugPrint('🔵 [SERVICE] getLeaderboard() - Response status: ${response.statusCode}');
    debugPrint('🔵 [SERVICE] getLeaderboard() - Response body: ${response.body}');
    if (response.statusCode == 200 && response.body != null) {
      try {
        final result = PlaceList.fromJson(response.body);
        debugPrint('✅ [SERVICE] getLeaderboard() - Parsed ${result.places.length} places');
        return result;
      } catch (e) {
        debugPrint('❌ [SERVICE] getLeaderboard() - Parse error: $e');
        return null;
      }
    }
    debugPrint('⚠️ [SERVICE] getLeaderboard() - Returning null (status: ${response.statusCode})');
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
  Future<TopVoterList?> getTopVoters({int? zoneId, int limit = 10}) async {
    debugPrint('🔵 [SERVICE] getTopVoters() - Calling repository (zoneId: $zoneId, limit: $limit)...');
    Response response = await placesRepositoryInterface.getTopVoters(
      zoneId: zoneId,
      limit: limit,
    );
    debugPrint('🔵 [SERVICE] getTopVoters() - Response status: ${response.statusCode}');
    debugPrint('🔵 [SERVICE] getTopVoters() - Response body: ${response.body}');
    if (response.statusCode == 200 && response.body != null) {
      try {
        final result = TopVoterList.fromJson(response.body);
        debugPrint('✅ [SERVICE] getTopVoters() - Parsed ${result.voters.length} voters');
        return result;
      } catch (e) {
        debugPrint('❌ [SERVICE] getTopVoters() - Parse error: $e');
        return null;
      }
    }
    debugPrint('⚠️ [SERVICE] getTopVoters() - Returning null (status: ${response.statusCode})');
    return null;
  }

  @override
  Future<Place?> getPlaceDetails(int placeId) async {
    Response response = await placesRepositoryInterface.getPlaceDetails(
      placeId,
    );
    if (response.statusCode == 200 && response.body != null) {
      var data = response.body['data'] ?? response.body;
      return Place.fromJson(data);
    }
    return null;
  }

  @override
  Future<PlaceReviewList?> getPlaceReviews(int placeId, {int offset = 1}) async {
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
  Future<Response> submitVote(int placeId, int rating, String? comment, {String? imagePath}) async {
    return await placesRepositoryInterface.submitVote(placeId, rating, comment, imagePath: imagePath);
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
  Future<Response> submitPlace(Map<String, String> fields, {String? imagePath}) async {
    return await placesRepositoryInterface.submitPlace(fields, imagePath: imagePath);
  }

  @override
  Future<PlaceSubmission?> getSubmissionDetail(int submissionId) async {
    Response response = await placesRepositoryInterface.getSubmissionDetail(submissionId);
    if (response.statusCode == 200 && response.body != null) {
      var data = response.body['data'] ?? response.body;
      return PlaceSubmission.fromJson(data);
    }
    return null;
  }
}
