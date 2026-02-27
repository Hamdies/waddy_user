import 'package:get/get_connect/http/src/response/response.dart';
import 'package:sixam_mart/features/places/domain/models/place_category_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_banner_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_vote_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_review_model.dart';
import 'package:sixam_mart/features/places/domain/models/place_submission_model.dart';
import 'package:sixam_mart/features/places/domain/repositories/places_repository_interface.dart';
import 'package:sixam_mart/features/places/domain/services/places_service_interface.dart';

class PlacesService implements PlacesServiceInterface {
  final PlacesRepositoryInterface placesRepositoryInterface;

  PlacesService({required this.placesRepositoryInterface});

  @override
  Future<List<PlaceCategory>?> getCategories() async {
    Response response = await placesRepositoryInterface.getCategories();
    if (response.statusCode == 200 && response.body != null) {
      return PlaceCategoryList.fromJson(response.body).categories;
    }
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
    int offset = 1,
  }) async {
    Response response = await placesRepositoryInterface.getPlaces(
      categoryId: categoryId,
      search: search,
      lat: lat,
      lng: lng,
      sort: sort,
      tagIds: tagIds,
      offset: offset,
    );
    if (response.statusCode == 200 && response.body != null) {
      return PlaceList.fromJson(response.body);
    }
    return null;
  }

  @override
  Future<PlaceList?> getLeaderboard({String? period}) async {
    Response response = await placesRepositoryInterface.getLeaderboard(
      period: period,
    );
    if (response.statusCode == 200 && response.body != null) {
      return PlaceList.fromJson(response.body);
    }
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
