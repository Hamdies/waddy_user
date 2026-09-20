import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:get/get_connect/http/src/response/response.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/api/local_client.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/features/places/domain/repositories/places_repository_interface.dart';

class PlacesRepository implements PlacesRepositoryInterface {
  final ApiClient apiClient;

  PlacesRepository({required this.apiClient});

  /// A GET that persists its body to the drift response cache, and can serve
  /// that body back without touching the network.
  ///
  /// Every other feature in the app (category, brands, flash sale, banners)
  /// already goes through `LocalClient`; Spots was the one screen that always
  /// paid a full round trip before it could draw anything, which is why a
  /// warm relaunch looked no faster than a cold one.
  ///
  /// The parsing stays in `PlacesService`: this hands back a `Response` whose
  /// `body` is the decoded JSON either way, so nothing downstream can tell a
  /// cache hit from a live one.
  Future<Response> _cachedGet(
    String uri, {
    required String cacheId,
    required DataSourceEnum source,
  }) async {
    if (source == DataSourceEnum.local) {
      final String? cached = await LocalClient.organize(
        DataSourceEnum.local,
        cacheId,
        null,
        null,
      );
      if (cached != null && cached.isNotEmpty) {
        try {
          return Response(statusCode: 200, body: jsonDecode(cached));
        } catch (_) {
          // A corrupt entry is not worth failing over — fall through to the
          // network and let the fresh response overwrite it.
        }
      }
      return const Response(statusCode: 204);
    }

    final Response response = await apiClient.getData(uri);
    if (response.statusCode == 200 && response.body != null) {
      LocalClient.organize(
        DataSourceEnum.client,
        cacheId,
        jsonEncode(response.body),
        apiClient.getHeader(),
      );
    }
    return response;
  }

  @override
  Future<Response> getCategories({
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    return _cachedGet(
      AppConstants.placesCategoriesUri,
      cacheId: AppConstants.placesCategoriesUri,
      source: source,
    );
  }

  @override
  Future<Response> getZones({
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    return _cachedGet(
      AppConstants.placesZonesUri,
      cacheId: AppConstants.placesZonesUri,
      source: source,
    );
  }

  @override
  Future<Response> getPlaces({
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
    // Laravel paginates by `page`; keep `offset` for backward compatibility
    String uri = '${AppConstants.placesUri}?page=$offset&offset=$offset';
    if (categoryId != null) uri += '&category_id=$categoryId';
    if (search != null && search.isNotEmpty) {
      uri += '&search=${Uri.encodeQueryComponent(search)}';
    }
    if (lat != null) uri += '&latitude=$lat';
    if (lng != null) uri += '&longitude=$lng';
    if (sort != null && sort.isNotEmpty) uri += '&sort_by=$sort';
    if (tagIds != null && tagIds.isNotEmpty) {
      uri += '&tag_ids=${tagIds.join(',')}';
    }
    if (zoneId != null) uri += '&zone_id=$zoneId';
    // Only the unfiltered first page is worth caching — it is the one the home
    // screen opens on. Caching every filter permutation would fill the table
    // with entries nothing reads twice.
    final bool cacheable =
        offset == 1 &&
        categoryId == null &&
        zoneId == null &&
        (search == null || search.isEmpty);
    if (!cacheable) return await apiClient.getData(uri);
    return _cachedGet(
      uri,
      cacheId: '${AppConstants.placesUri}_home_$sort',
      source: source,
    );
  }

  @override
  Future<Response> getLeaderboard({
    String? period,
    int? zoneId,
    int? limit,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    String uri = AppConstants.placesLeaderboardUri;
    List<String> params = [];
    if (period != null && period.isNotEmpty) params.add('period=$period');
    if (zoneId != null) params.add('zone_id=$zoneId');
    if (limit != null) params.add('limit=$limit');
    if (params.isNotEmpty) uri += '?${params.join('&')}';
    return _cachedGet(
      uri,
      cacheId: '${AppConstants.placesLeaderboardUri}_${zoneId ?? 'all'}_$limit',
      source: source,
    );
  }

  @override
  Future<Response> getTrending() async {
    return await apiClient.getData(AppConstants.placesTrendingUri);
  }

  @override
  Future<Response> getLatestWinner({int? zoneId}) async {
    String uri = '${AppConstants.placesUri}/winners/latest';
    if (zoneId != null) uri += '?zone_id=$zoneId';
    return await apiClient.getData(uri);
  }

  @override
  Future<Response> getWinners({int? zoneId, int limit = 24}) async {
    String uri = '${AppConstants.placesUri}/winners?limit=$limit';
    if (zoneId != null) uri += '&zone_id=$zoneId';
    return await apiClient.getData(uri);
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
      '${AppConstants.placesUri}/$placeId/reviews?page=$offset&offset=$offset',
    );
  }

  @override
  Future<Response> getTopVoters({
    int? zoneId,
    int limit = 10,
    DataSourceEnum source = DataSourceEnum.client,
  }) async {
    String uri = '${AppConstants.placesTopVotersUri}?limit=$limit';
    if (zoneId != null) uri += '&zone_id=$zoneId';
    return _cachedGet(
      uri,
      cacheId: '${AppConstants.placesTopVotersUri}_${zoneId ?? 'all'}_$limit',
      source: source,
    );
  }

  @override
  Future<Response> getMyPrizes() async {
    return await apiClient.getData(AppConstants.placesPrizesMyUri);
  }

  @override
  Future<Response> getDraw({String? period}) async {
    return await apiClient.getData(
      period == null
          ? AppConstants.placesDrawUri
          : '${AppConstants.placesDrawUri}/$period',
    );
  }

  @override
  Future<Response> getRecentWinners({int limit = 10}) async {
    return await apiClient.getData(
      '${AppConstants.placesRecentWinnersUri}?limit=$limit',
    );
  }

  @override
  Future<Response> submitVote(
    int placeId,
    int? rating,
    String? comment, {
    String? imagePath,
    bool switchVote = false,
  }) async {
    // A bare vote carries no rating: the backend validates `rating` as
    // nullable, but a literal `null` in the body still fails `integer|min:1`,
    // so the key must be absent rather than empty.
    if (imagePath != null && imagePath.isNotEmpty) {
      return await apiClient.postMultipartData(
        '${AppConstants.placesUri}/$placeId/vote',
        {
          if (rating != null) 'rating': rating.toString(),
          if (comment != null && comment.isNotEmpty) 'review': comment,
          if (switchVote) 'switch': '1',
        },
        [MultipartBody('image', XFile(imagePath))],
      );
    }
    return await apiClient.postData('${AppConstants.placesUri}/$placeId/vote', {
      if (rating != null) 'rating': rating,
      if (comment != null && comment.isNotEmpty) 'review': comment,
      if (switchVote) 'switch': 1,
    });
  }

  @override
  Future<Response> submitReview(
    int placeId,
    int? rating,
    String? review, {
    String? imagePath,
  }) async {
    if (imagePath != null && imagePath.isNotEmpty) {
      return await apiClient.postMultipartData(
        '${AppConstants.placesUri}/$placeId/review',
        {
          if (rating != null) 'rating': rating.toString(),
          if (review != null && review.isNotEmpty) 'review': review,
        },
        [MultipartBody('image', XFile(imagePath))],
      );
    }
    return await apiClient
        .postData('${AppConstants.placesUri}/$placeId/review', {
          if (rating != null) 'rating': rating,
          if (review != null && review.isNotEmpty) 'review': review,
        });
  }

  @override
  Future<Response> removeReview(int placeId) async {
    return await apiClient.deleteData(
      '${AppConstants.placesUri}/$placeId/review',
    );
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
  Future<Response> submitPlace(
    Map<String, String> fields, {
    String? imagePath,
  }) async {
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
