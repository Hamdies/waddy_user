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
  final String? coverImage;
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
  final PlaceZone? zone;

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
    this.coverImage,
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
    this.zone,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? '',
      description: json['description'],
      categoryId: json['category_id'],
      categoryName: _safeCategoryName(json['category_name'], json['category']),
      rating:
          _parseDouble(
            json['rating'] ?? json['votes_avg_rating'] ?? json['avg_rating'],
          ) ??
          0.0,
      votesCount: json['votes_count'] ?? 0,
      rank: json['rank'],
      image: json['image'] ?? json['image_full_url'],
      coverImage: json['cover_image'] ?? json['cover_image_full_url'],
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
      gallery: _parseGallery(json['gallery']) ?? _parseGallery(json['images']),
      tags: _parseTags(json['tags']),
      zone: _parseZone(json['zone']),
    );
  }

  /// Safely parse category name from either a direct string or nested object
  static String? _safeCategoryName(dynamic directValue, dynamic categoryObj) {
    if (directValue is String) return directValue;
    if (categoryObj is Map<String, dynamic>) {
      return categoryObj['name'] as String?;
    }
    return null;
  }

  /// Safely parse gallery list, handling various response formats
  static List<PlaceImage>? _parseGallery(dynamic galleryData) {
    try {
      if (galleryData == null || galleryData is String) return null;
      if (galleryData is List) {
        return galleryData
            .whereType<Map<String, dynamic>>()
            .map((e) => PlaceImage.fromJson(e))
            .toList();
      }
    } catch (e) {
      print('Error parsing gallery: $e');
    }
    return null;
  }

  /// Safely parse tags list, handling various response formats
  static List<PlaceTag>? _parseTags(dynamic tagsData) {
    try {
      if (tagsData == null || tagsData is String) return null;
      if (tagsData is List) {
        return tagsData
            .whereType<Map<String, dynamic>>()
            .map((e) => PlaceTag.fromJson(e))
            .toList();
      }
    } catch (e) {
      print('Error parsing tags: $e');
    }
    return null;
  }

  /// Safely parse zone object, handling various response formats
  static PlaceZone? _parseZone(dynamic zoneData) {
    try {
      if (zoneData == null || zoneData is String) return null;
      if (zoneData is Map<String, dynamic>) {
        return PlaceZone.fromJson(zoneData);
      }
    } catch (e) {
      print('Error parsing zone: $e');
    }
    return null;
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
      'cover_image': coverImage,
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
      'zone': zone?.toJson(),
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

/// Zone model for place location

class PlaceZone {
  final int id;
  final String? name;
  final String? displayName;

  PlaceZone({required this.id, this.name, this.displayName});

  factory PlaceZone.fromJson(Map<String, dynamic> json) {
    return PlaceZone(
      id: json['id'] ?? 0,
      name: json['name'],
      displayName: json['display_name'] ?? json['name'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'display_name': displayName,
  };
}

class PlaceZoneList {
  final List<PlaceZone> zones;

  PlaceZoneList({required this.zones});

  factory PlaceZoneList.fromJson(Map<String, dynamic> json) {
    return PlaceZoneList(
      zones: json['data'] != null
          ? (json['data'] as List)
              .map((item) => PlaceZone.fromJson(item))
              .toList()
          : [],
    );
  }
}

/// Top Voter model for leaderboard display

class TopVoter {
  final int id;
  final int? position;
  final String name;
  final String? avatar;
  final int votesCount;

  TopVoter({
    required this.id,
    this.position,
    required this.name,
    this.avatar,
    this.votesCount = 0,
  });

  factory TopVoter.fromJson(Map<String, dynamic> json) {
    return TopVoter(
      id: json['id'] ?? json['user_id'] ?? 0,
      position: json['position'],
      name: json['username'] ?? json['name'] ?? json['user']?['name'] ?? '',
      avatar: json['image'] ?? json['image_full_url'] ?? json['avatar'] ?? json['user']?['image_full_url'] ?? json['user']?['avatar'],
      votesCount: json['votes_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': position,
    'username': name,
    'image': avatar,
    'votes_count': votesCount,
  };
}

/// Top Voter List wrapper

class TopVoterList {
  final List<TopVoter> voters;
  final String? period;

  TopVoterList({required this.voters, this.period});

  factory TopVoterList.fromJson(Map<String, dynamic> json) {
    return TopVoterList(
      voters: json['data'] != null
          ? (json['data'] as List).map((e) => TopVoter.fromJson(e)).toList()
          : [],
      period: json['period'],
    );
  }
}
