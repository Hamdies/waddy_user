import 'package:waddy_app/features/places/domain/spots_draw.dart';
import 'package:waddy_app/util/image_url.dart';

/// One closed round's claw draw: the [SpotsDraw] itself plus the context the
/// screen and the home card need around it — which week it was, and which
/// venue was crowned.
///
/// The machine is loaded with the voters of the **winning venue** only
/// (`PrizeDrawService::eligiblePool()` — distinct, unflagged voters for the
/// champion, minus anyone inside the winner cooldown). So the venue is not
/// decoration: it is the answer to "why am I / am I not in there?".
///
/// [SpotsDraw] stays exactly as it was — a pure replay of a decided outcome.
/// This wrapper only carries the envelope fields it has no use for.
class SpotsDrawRound {
  final SpotsDraw draw;

  /// ISO week the draw closed, e.g. `2026-W27`. Null only on a malformed
  /// payload.
  final String? period;

  final int? placeId;
  final String? placeTitle;
  final String? placeImage;

  const SpotsDrawRound({
    required this.draw,
    this.period,
    this.placeId,
    this.placeTitle,
    this.placeImage,
  });

  /// Whether [value] is a period the draw endpoint can serve (`2026-W27`).
  ///
  /// It is interpolated into the request path, so anything else — a junk
  /// deep link, or one of the legacy `9` / `2026-07` periods production still
  /// holds — must never reach the network.
  static bool isValidPeriod(String? value) =>
      value != null && RegExp(r'^\d{4}-W\d{2}$').hasMatch(value);

  /// Week number out of [period] (`2026-W07` → 7), for the masthead eyebrow.
  int? get week {
    final match = RegExp(r'W(\d+)').firstMatch(period ?? '');
    return match == null ? null : int.parse(match.group(1)!);
  }

  /// Parses `GET /places/draw/{period?}` — the whole `{success, data}`
  /// envelope or the bare `data` object, the same tolerance as
  /// [SpotsDraw.fromApi].
  factory SpotsDrawRound.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data =
        json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : json;
    final Map<String, dynamic>? place =
        data['place'] is Map<String, dynamic>
            ? data['place'] as Map<String, dynamic>
            : null;
    final String? title = place?['title']?.toString() ?? place?['name']?.toString();

    return SpotsDrawRound(
      draw: SpotsDraw.fromApi(data),
      period: data['period']?.toString(),
      placeId:
          place?['id'] is int
              ? place!['id'] as int
              : int.tryParse('${place?['id']}'),
      placeTitle: (title == null || title.trim().isEmpty) ? null : title,
      placeImage:
          place == null
              ? null
              : pickImageUrl([place['image_full_url'], place['image']]),
    );
  }
}
