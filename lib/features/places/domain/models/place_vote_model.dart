class PlaceVote {
  final int id;
  final int placeId;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final bool hasVoted;

  PlaceVote({
    required this.id,
    required this.placeId,
    required this.rating,
    this.comment,
    this.createdAt,
    this.hasVoted = false,
  });

  factory PlaceVote.fromJson(Map<String, dynamic> json) {
    return PlaceVote(
      id: json['id'] ?? 0,
      placeId: json['place_id'] ?? 0,
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'])
              : null,
      hasVoted: json['has_voted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'place_id': placeId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt?.toIso8601String(),
      'has_voted': hasVoted,
    };
  }
}

class VoteStatus {
  final bool hasVoted;
  final PlaceVote? vote;

  VoteStatus({required this.hasVoted, this.vote});

  factory VoteStatus.fromJson(Map<String, dynamic> json) {
    return VoteStatus(
      hasVoted: json['has_voted'] ?? json['voted'] ?? false,
      vote: json['vote'] != null ? PlaceVote.fromJson(json['vote']) : null,
    );
  }
}
