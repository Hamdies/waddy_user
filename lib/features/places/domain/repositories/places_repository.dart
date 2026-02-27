import 'package:image_picker/image_picker.dart';
import 'package:get/get_connect/http/src/response/response.dart';
import 'package:sixam_mart/api/api_client.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/features/places/domain/repositories/places_repository_interface.dart';

class PlacesRepository implements PlacesRepositoryInterface {
  final ApiClient apiClient;

  PlacesRepository({required this.apiClient});

  @override
  Future<Response> getCategories() async {
    return await apiClient.getData(AppConstants.placesCategoriesUri);
  }

  @override
  Future<Response> getPlaces({
    int? categoryId,
    String? search,
    double? lat,
    double? lng,
    String? sort,
    List<int>? tagIds,
    int offset = 1,
  }) async {
    String uri = '${AppConstants.placesUri}?offset=$offset';
    if (categoryId != null) uri += '&category_id=$categoryId';
    if (search != null && search.isNotEmpty) uri += '&search=$search';
    if (lat != null) uri += '&lat=$lat';
    if (lng != null) uri += '&lng=$lng';
    if (sort != null && sort.isNotEmpty) uri += '&sort_by=$sort';
    if (tagIds != null && tagIds.isNotEmpty) {
      uri += '&tag_ids=${tagIds.join(',')}';
    }
    return await apiClient.getData(uri);
  }

  @override
  Future<Response> getLeaderboard({String? period}) async {
    String uri = AppConstants.placesLeaderboardUri;
    if (period != null && period.isNotEmpty) {
      uri += '?period=$period';
    }
    return await apiClient.getData(uri);
  }

  @override
  Future<Response> getTrending() async {
    return await apiClient.getData(AppConstants.placesTrendingUri);
  }

  @override
  Future<Response> getTags() async {
    return await apiClient.getData(AppConstants.placesTagsUri);
  }

  @override
  Future<Response> getFeaturedBanners() async {
    return await apiClient.getData(AppConstants.placesBannersUri);
  }

  @override
  Future<Response> getPlaceDetails(int placeId) async {
    return await apiClient.getData('${AppConstants.placesUri}/$placeId');
  }

  @override
  Future<Response> getPlaceReviews(int placeId, {int offset = 1}) async {
    return await apiClient.getData(
      '${AppConstants.placesUri}/$placeId/reviews?offset=$offset',
    );
  }

  @override
  Future<Response> submitVote(int placeId, int rating, String? comment, {String? imagePath}) async {
    if (imagePath != null && imagePath.isNotEmpty) {
      return await apiClient.postMultipartData(
        '${AppConstants.placesUri}/$placeId/vote',
        {
          'rating': rating.toString(),
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
        [MultipartBody('image', XFile(imagePath))],
      );
    }
    return await apiClient.postData('${AppConstants.placesUri}/$placeId/vote', {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  @override
  Future<Response> removeVote(int placeId) async {
    return await apiClient.deleteData(
      '${AppConstants.placesUri}/$placeId/vote',
    );
  }

  @override
  Future<Response> getVoteStatus(int placeId) async {
    return await apiClient.getData(
      '${AppConstants.placesUri}/$placeId/vote-status',
    );
  }

  @override
  Future<Response> reportVote(int voteId, String reason) async {
    return await apiClient.postData(
      '${AppConstants.placesUri}/votes/$voteId/report',
      {'reason': reason},
    );
  }

  @override
  Future<Response> getFavorites() async {
    return await apiClient.getData(AppConstants.placesFavoritesUri);
  }

  @override
  Future<Response> addFavorite(int placeId) async {
    return await apiClient.postData(
      '${AppConstants.placesUri}/$placeId/favorite',
      {},
    );
  }

  @override
  Future<Response> removeFavorite(int placeId) async {
    return await apiClient.deleteData(
      '${AppConstants.placesUri}/$placeId/favorite',
    );
  }

  @override
  Future<Response> toggleFavorite(int placeId) async {
    return await apiClient.postData(
      '${AppConstants.placesUri}/$placeId/toggle-favorite',
      {},
    );
  }

  @override
  Future<Response> getMySubmissions() async {
    return await apiClient.getData(AppConstants.placesSubmissionsMyUri);
  }

  @override
  Future<Response> submitPlace(Map<String, String> fields, {String? imagePath}) async {
    if (imagePath != null && imagePath.isNotEmpty) {
      return await apiClient.postMultipartData(
        AppConstants.placesSubmissionsUri,
        fields,
        [MultipartBody('image', XFile(imagePath))],
      );
    }
    return await apiClient.postData(AppConstants.placesSubmissionsUri, fields);
  }

  @override
  Future<Response> getSubmissionDetail(int submissionId) async {
    return await apiClient.getData(
      '${AppConstants.placesSubmissionsUri}/$submissionId',
    );
  }
}
