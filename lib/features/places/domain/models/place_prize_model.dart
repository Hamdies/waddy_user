/// A voucher won in the weekly voter draw.
///
/// Redeemed in person at the venue, never as an in-app order: the user shows
/// the code at the counter and staff burns it on the venue's redemption page.
class PlacePrize {
  final int id;
  final String period; // e.g. 2026-W32
  final String code; // e.g. WD7K-3XQ2
  final String status; // active | redeemed | expired

  /// Venue counter page with this code prefilled. Scanning the QR opens it,
  /// so staff only have to tap Redeem instead of retyping the code.
  final String? redeemUrl;
  final double? valueCap;
  final String? currency;
  final DateTime? expiresAt;
  final DateTime? redeemedAt;

  /// When the draw awarded it — shown on the details screen.
  final DateTime? wonAt;

  /// Server-computed remainder at fetch time. The screen counts down from
  /// this rather than from [expiresAt], so a wrong device clock can't make a
  /// live voucher look dead (or vice versa).
  final int secondsRemaining;

  final int placeId;
  final String placeTitle;
  final String? placeImage;
  final String? placeCoverImage;
  final String? placeAddress;
  final double? latitude;
  final double? longitude;

  PlacePrize({
    required this.id,
    required this.period,
    required this.code,
    required this.status,
    this.redeemUrl,
    this.valueCap,
    this.currency,
    this.expiresAt,
    this.redeemedAt,
    this.wonAt,
    this.secondsRemaining = 0,
    required this.placeId,
    required this.placeTitle,
    this.placeImage,
    this.placeCoverImage,
    this.placeAddress,
    this.latitude,
    this.longitude,
  });

  bool get isActive => status == 'active';
  bool get isRedeemed => status == 'redeemed';
  bool get isExpired => status == 'expired';

  /// "2026-W32" -> "WEEK 32"
  String get weekLabel {
    final match = RegExp(r'W(\d+)').firstMatch(period);
    return match != null ? 'WEEK ${int.parse(match.group(1)!)}' : period;
  }

  static double? _toDouble(dynamic value) =>
      value is num
          ? value.toDouble()
          : (value is String ? double.tryParse(value) : null);

  factory PlacePrize.fromJson(Map<String, dynamic> json) {
    final place =
        json['place'] is Map<String, dynamic>
            ? json['place'] as Map<String, dynamic>
            : const <String, dynamic>{};

    return PlacePrize(
      id: json['id'] ?? 0,
      period: json['period'] ?? '',
      code: json['code'] ?? '',
      status: json['status'] ?? 'active',
      redeemUrl: json['redeem_url'],
      valueCap: _toDouble(json['value_cap']),
      currency: json['currency'],
      expiresAt:
          json['expires_at'] != null
              ? DateTime.tryParse(json['expires_at'])
              : null,
      redeemedAt:
          json['redeemed_at'] != null
              ? DateTime.tryParse(json['redeemed_at'])
              : null,
      wonAt: json['won_at'] != null ? DateTime.tryParse(json['won_at']) : null,
      secondsRemaining: json['seconds_remaining'] ?? 0,
      placeId: place['id'] ?? 0,
      placeTitle: place['title'] ?? '',
      placeImage: place['image'],
      placeCoverImage: place['cover_image'],
      placeAddress: place['address'],
      latitude: _toDouble(place['latitude']),
      longitude: _toDouble(place['longitude']),
    );
  }
}

/// The `prizes/my` payload: live vouchers, then the archive.
class PlacePrizeList {
  final List<PlacePrize> active;
  final List<PlacePrize> history;

  PlacePrizeList({required this.active, required this.history});

  factory PlacePrizeList.fromJson(Map<String, dynamic> json) {
    final data =
        json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : const <String, dynamic>{};

    List<PlacePrize> parse(dynamic list) =>
        list is List
            ? list
                .whereType<Map<String, dynamic>>()
                .map((e) => PlacePrize.fromJson(e))
                .toList()
            : <PlacePrize>[];

    return PlacePrizeList(
      active: parse(data['active']),
      history: parse(data['history']),
    );
  }
}
