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
      comment: json['review'] ?? json['comment'],
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

  /// Whether the caller has REVIEWED this place — a separate, permanent act
  /// from voting, so it has its own flag rather than being inferred from
  /// [hasVoted] or from the vote carrying review text.
  final bool hasReviewed;
  final PlaceVote? vote;

  /// Where this week's single vote currently sits (any place), null if unused
  final int? weeklyVotePlaceId;
  final String? weeklyVotePlaceTitle;

  VoteStatus({
    required this.hasVoted,
    this.hasReviewed = false,
    this.vote,
    this.weeklyVotePlaceId,
    this.weeklyVotePlaceTitle,
  });

  factory VoteStatus.fromJson(Map<String, dynamic> json) {
    final weekly = json['weekly_vote'];
    return VoteStatus(
      hasVoted: json['has_voted'] ?? json['voted'] ?? false,
      hasReviewed: json['has_reviewed'] == true,
      // Prefer the dedicated `review` object; fall back to the legacy `vote`
      // payload so an app talking to an older backend still prefills.
      vote:
          json['review'] != null
              ? PlaceVote.fromJson(json['review'])
              : json['vote'] != null
              ? PlaceVote.fromJson(json['vote'])
              : null,
      weeklyVotePlaceId: weekly is Map ? weekly['place_id'] : null,
      weeklyVotePlaceTitle: weekly is Map ? weekly['place_title'] : null,
    );
  }
}
