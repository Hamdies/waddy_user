class PlaceCategory {
  final int id;
  final String name;
  final String? icon;
  final int placesCount;

  PlaceCategory({
    required this.id,
    required this.name,
    this.icon,
    this.placesCount = 0,
  });

  factory PlaceCategory.fromJson(Map<String, dynamic> json) {
    return PlaceCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'],
      placesCount: json['places_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'icon': icon, 'places_count': placesCount};
  }
}

class PlaceCategoryList {
  final List<PlaceCategory> categories;

  PlaceCategoryList({required this.categories});

  factory PlaceCategoryList.fromJson(Map<String, dynamic> json) {
    return PlaceCategoryList(
      categories:
          json['data'] != null
              ? (json['data'] as List)
                  .map((item) => PlaceCategory.fromJson(item))
                  .toList()
              : [],
    );
  }
}
