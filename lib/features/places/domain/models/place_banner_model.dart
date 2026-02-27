class PlaceBanner {
  final int id;
  final String title;
  final String? image;
  final String type; // 'default', 'category', 'place'
  final String? link;
  final int? categoryId;
  final int? placeId;

  PlaceBanner({
    required this.id,
    required this.title,
    this.image,
    this.type = 'default',
    this.link,
    this.categoryId,
    this.placeId,
  });

  factory PlaceBanner.fromJson(Map<String, dynamic> json) {
    return PlaceBanner(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      image: json['image'] ?? json['image_full_url'],
      type: json['type'] ?? 'default',
      link: json['link'],
      categoryId: json['category_id'],
      placeId: json['place_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'type': type,
      'link': link,
      'category_id': categoryId,
      'place_id': placeId,
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
