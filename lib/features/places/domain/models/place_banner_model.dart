import 'package:waddy_app/util/image_url.dart';

class PlaceBanner {
  final int id;
  final String title;
  final String? description;
  final String? image;

  /// `default`, `category`, `place` or `external` — see the `type` column on
  /// `place_banners`.
  final String type;

  /// Destination for a `type == 'external'` banner. The API key is
  /// `external_link`.
  final String? link;

  /// The API sends one integer under `data` whose meaning depends on [type]:
  /// a `place_categories` id for `category`, a `places` id for `place`. It is
  /// split here so call sites do not have to re-read [type] to know what they
  /// are holding.
  final int? categoryId;
  final int? placeId;

  final bool isFeatured;

  PlaceBanner({
    required this.id,
    required this.title,
    this.description,
    this.image,
    this.type = 'default',
    this.link,
    this.categoryId,
    this.placeId,
    this.isFeatured = false,
  });

  factory PlaceBanner.fromJson(Map<String, dynamic> json) {
    final String type = json['type'] ?? 'default';
    final int? target = _asInt(json['data']);

    return PlaceBanner(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      // `PlaceBanner::getImageFullUrlAttribute` is serialised under `image` by
      // the API controller, so `image` is already an absolute URL there.
      image: pickImageUrl([json['image_full_url'], json['image']]),
      type: type,
      link: json['external_link'] ?? json['link'],
      categoryId:
          type == 'category' ? (target ?? _asInt(json['category_id'])) : null,
      placeId: type == 'place' ? (target ?? _asInt(json['place_id'])) : null,
      isFeatured: json['is_featured'] ?? false,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image': image,
      'type': type,
      'external_link': link,
      'data': categoryId ?? placeId,
      'is_featured': isFeatured,
    };
  }
}

class PlaceBannerList {
  final List<PlaceBanner> banners;

  PlaceBannerList({required this.banners});

  factory PlaceBannerList.fromJson(Map<String, dynamic> json) {
    return PlaceBannerList(
      banners:
          json['data'] != null
              ? (json['data'] as List)
                  .map((item) => PlaceBanner.fromJson(item))
                  .toList()
              : [],
    );
  }
}
