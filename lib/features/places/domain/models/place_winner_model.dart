import 'package:waddy_app/util/image_url.dart';

/// A closed week's champion (overall or per zone) — the app's "news".
class PlaceWinner {
  final int id;
  final String period; // e.g. 2026-W28
  final int? zoneId;
  final String? zoneName;
  final int votesCount;
  final double? avgRating;
  final int titlesCount; // how many weekly titles this place holds
  final int placeId;
  final String placeTitle;
  final String? image;
  final String? coverImage;
  final String? categoryName;

  PlaceWinner({
    required this.id,
    required this.period,
    this.zoneId,
    this.zoneName,
    this.votesCount = 0,
    this.avgRating,
    this.titlesCount = 1,
    required this.placeId,
    required this.placeTitle,
    this.image,
    this.coverImage,
    this.categoryName,
  });

  factory PlaceWinner.fromJson(Map<String, dynamic> json) {
    final place =
        json['place'] is Map<String, dynamic>
            ? json['place'] as Map<String, dynamic>
            : const <String, dynamic>{};
    return PlaceWinner(
      id: json['id'] ?? 0,
      period: json['period'] ?? '',
      zoneId: json['zone_id'],
      zoneName: json['zone'],
      votesCount: json['votes_count'] ?? 0,
      avgRating:
          (json['avg_rating'] is num)
              ? (json['avg_rating'] as num).toDouble()
              : null,
      titlesCount: json['titles_count'] ?? 1,
      placeId: place['id'] ?? 0,
      placeTitle: place['title'] ?? '',
      image: place['image'],
      coverImage: place['cover_image'],
      categoryName: place['category'],
    );
  }

  /// "2026-W28" -> "WEEK 28"
  String get weekLabel {
    final match = RegExp(r'W(\d+)').firstMatch(period);
    return match != null ? 'WEEK ${int.parse(match.group(1)!)}' : period;
  }
}

/// A person who won the voter prize — social proof, not a ranking.
///
/// Deliberately a separate type from [PlaceWinner] (a venue) and from
/// TopVoter (a rank): conflating them in one list implies a correlation
/// between voting more and winning, which does not exist.
class RecentWinner {
  final int id;
  final String period;
  final String name; // already trimmed to "Ahmed H." server-side
  final String? avatar;
  final DateTime? wonAt;
  final int placeId;
  final String placeTitle;
  final String? placeImage;

  RecentWinner({
    required this.id,
    required this.period,
    required this.name,
    this.avatar,
    this.wonAt,
    required this.placeId,
    required this.placeTitle,
    this.placeImage,
  });

  factory RecentWinner.fromJson(Map<String, dynamic> json) {
    final place =
        json['place'] is Map<String, dynamic>
            ? json['place'] as Map<String, dynamic>
            : const <String, dynamic>{};
    return RecentWinner(
      id: json['id'] ?? 0,
      period: json['period'] ?? '',
      name: json['username'] ?? '',
      avatar: pickImageUrl([json['image_full_url'], json['image']]),
      wonAt: json['won_at'] != null ? DateTime.tryParse(json['won_at']) : null,
      placeId: place['id'] ?? 0,
      placeTitle: place['title'] ?? '',
      placeImage: place['image'],
    );
  }

  /// "2026-W28" -> "WEEK 28"
  String get weekLabel {
    final match = RegExp(r'W(\d+)').firstMatch(period);
    return match != null ? 'WEEK ${int.parse(match.group(1)!)}' : period;
  }
}
