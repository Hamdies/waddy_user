class PlaceReview {
  final int id;
  final int placeId;
  final int? userId;
  final String? userName;
  final String? userImage;
  final int rating;
  final String? comment;
  final String? imageUrl;
  final DateTime? createdAt;
  final int reportsCount;

  PlaceReview({
    required this.id,
    required this.placeId,
    this.userId,
    this.userName,
    this.userImage,
    required this.rating,
    this.comment,
    this.imageUrl,
    this.createdAt,
    this.reportsCount = 0,
  });

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    return PlaceReview(
      id: json['id'] ?? 0,
      placeId: json['place_id'] ?? 0,
      userId: json['user_id'],
      userName: json['user_name'] ?? json['user']?['f_name'],
      userImage: json['user_image'] ?? json['user']?['image_full_url'],
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      imageUrl: json['image_url'] ?? json['image'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      reportsCount: json['reports_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'place_id': placeId,
    'rating': rating,
    'comment': comment,
    'image_url': imageUrl,
  };
}

class PlaceReviewList {
  final List<PlaceReview> reviews;
  final int? totalSize;
  final int? offset;

  PlaceReviewList({required this.reviews, this.totalSize, this.offset});

  factory PlaceReviewList.fromJson(Map<String, dynamic> json) {
    return PlaceReviewList(
      reviews: json['data'] != null
          ? (json['data'] as List)
              .map((item) => PlaceReview.fromJson(item))
              .toList()
          : [],
      totalSize: json['total_size'] ?? json['total'],
      offset: json['offset'],
    );
  }
}
