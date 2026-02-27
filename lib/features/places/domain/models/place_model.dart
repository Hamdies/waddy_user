class Place {
  final int id;
  final String title;
  final String? description;
  final int? categoryId;
  final String? categoryName;
  final double rating;
  final int votesCount;
  final int? rank;
  final String? image;
  final double? lat;
  final double? lng;
  final String? address;
  final String? phone;
  final String? website;
  final String? instagram;
  final bool? isOpen;
  final bool? isOpenNow;
  final bool? isFavorited;
  final int favoritesCount;
  final dynamic openingHours;
  final List<PlaceImage>? gallery;
  final List<PlaceTag>? tags;

  Place({
    required this.id,
    required this.title,
    this.description,
    this.categoryId,
    this.categoryName,
    this.rating = 0.0,
    this.votesCount = 0,
    this.rank,
    this.image,
    this.lat,
    this.lng,
    this.address,
    this.phone,
    this.website,
    this.instagram,
    this.isOpen,
    this.isOpenNow,
    this.isFavorited,
    this.favoritesCount = 0,
    this.openingHours,
    this.gallery,
    this.tags,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? '',
      description: json['description'],
      categoryId: json['category_id'],
      categoryName: json['category_name'] ?? json['category']?['name'],
      rating:
          _parseDouble(
            json['rating'] ?? json['votes_avg_rating'] ?? json['avg_rating'],
          ) ??
          0.0,
      votesCount: json['votes_count'] ?? 0,
      rank: json['rank'],
      image: json['image'] ?? json['image_full_url'],
      lat: _parseDouble(json['lat'] ?? json['latitude']),
      lng: _parseDouble(json['lng'] ?? json['longitude']),
      address: json['address'],
      phone: json['phone'],
      website: json['website'],
      instagram: json['instagram'],
      isOpen: json['is_open'],
      isOpenNow: json['is_open_now'],
      isFavorited: json['is_favorited'],
      favoritesCount: json['favorites_count'] ?? 0,
      openingHours: json['opening_hours'],
      gallery: json['gallery'] != null
          ? (json['gallery'] as List).map((e) => PlaceImage.fromJson(e)).toList()
          : (json['images'] != null
              ? (json['images'] as List).map((e) => PlaceImage.fromJson(e)).toList()
              : null),
      tags: json['tags'] != null
          ? (json['tags'] as List).map((e) => PlaceTag.fromJson(e)).toList()
          : null,
    );
  }

  /// Safely parse a value to double (handles both String and numeric types)
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'category_name': categoryName,
      'rating': rating,
      'votes_count': votesCount,
      'rank': rank,
      'image': image,
      'lat': lat,
      'lng': lng,
      'address': address,
      'phone': phone,
      'website': website,
      'instagram': instagram,
      'is_open': isOpen,
      'is_open_now': isOpenNow,
      'is_favorited': isFavorited,
      'favorites_count': favoritesCount,
      'opening_hours': openingHours,
      'gallery': gallery?.map((e) => e.toJson()).toList(),
      'tags': tags?.map((e) => e.toJson()).toList(),
    };
  }
}

class PlaceImage {
  final int id;
  final int placeId;
  final String image;
  final int sortOrder;
  final bool isPrimary;

  PlaceImage({
    required this.id,
    required this.placeId,
    required this.image,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  factory PlaceImage.fromJson(Map<String, dynamic> json) {
    return PlaceImage(
      id: json['id'] ?? 0,
      placeId: json['place_id'] ?? 0,
      image: json['image'] ?? json['image_full_url'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'place_id': placeId, 'image': image,
    'sort_order': sortOrder, 'is_primary': isPrimary,
  };
}

class PlaceTag {
  final int id;
  final String name;
  final String? nameAr;
  final String? icon;

  PlaceTag({
    required this.id,
    required this.name,
    this.nameAr,
    this.icon,
  });

  factory PlaceTag.fromJson(Map<String, dynamic> json) {
    return PlaceTag(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameAr: json['name_ar'],
      icon: json['icon'],
    );
  }

  String get localizedName => nameAr ?? name;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'name_ar': nameAr, 'icon': icon,
  };
}

class PlaceList {
  final List<Place> places;
  final int? totalSize;
  final int? offset;
  final String? period; // For leaderboard

  PlaceList({required this.places, this.totalSize, this.offset, this.period});

  factory PlaceList.fromJson(Map<String, dynamic> json) {
    return PlaceList(
      places:
          json['data'] != null
              ? (json['data'] as List)
                  .map((item) => Place.fromJson(item))
                  .toList()
              : [],
      totalSize: json['total_size'] ?? json['total'],
      offset: json['offset'],
      period: json['period'],
    );
  }
}
