/// The resized/re-encoded image set the backend generates alongside every
/// upload (shipped 2026-08-29).
///
/// Entities carry these as a sibling of the unchanged `*_full_url` string —
/// `logo_variants`, `cover_photo_variants`, `image_variants` — and only when
/// the request opts in with `X-Image-Variants: 1` (set in ApiClient). The
/// original URL is always still there, so a missing or malformed variant map is
/// never fatal: [ImageVariants.fromJson] returns null and callers fall back to
/// the full-size original.
///
/// Measured on the backend's own backfill: a 10,878 B store logo becomes
/// 1,368 B as a WebP thumb, and a 596,165 B promotional banner becomes
/// 11,742 B as a WebP card — 96% smaller across the sample set.
class ImageVariants {
  /// Size name → URL, e.g. `{'thumb': 'https://…/thumb/abc.webp'}`.
  final Map<String, String> webp;
  final Map<String, String> jpg;
  final String? original;

  const ImageVariants({required this.webp, required this.jpg, this.original});

  /// The size ladder, in ascending order of intrinsic width.
  ///
  /// These pixel widths mirror `config/imagevariants.php` on the backend. If a
  /// size is added or resized there, change it here too — picking a variant
  /// assumes these numbers are what the files actually contain, and a wrong
  /// number here means either a blurry image or a wasted decode.
  static const List<(String, int)> ladder = <(String, int)>[
    ('thumb', 150),
    ('card', 400),
    ('hero', 1200),
  ];

  static ImageVariants? fromJson(dynamic json) {
    if (json is! Map) return null;

    Map<String, String> readSet(dynamic raw) {
      if (raw is! Map) return const <String, String>{};
      final Map<String, String> out = <String, String>{};
      raw.forEach((key, value) {
        if (value is String && value.isNotEmpty) {
          out[key.toString()] = value;
        }
      });
      return out;
    }

    final Map<String, String> webp = readSet(json['webp']);
    final Map<String, String> jpg = readSet(json['jpg']);
    final Object? original = json['original'];

    if (webp.isEmpty && jpg.isEmpty) return null;

    return ImageVariants(
      webp: webp,
      jpg: jpg,
      original: original is String && original.isNotEmpty ? original : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'webp': webp,
    'jpg': jpg,
    if (original != null) 'original': original,
  };

  bool get isEmpty => webp.isEmpty && jpg.isEmpty;

  /// Smallest variant that still covers [physicalWidth] device pixels.
  ///
  /// Deliberately picks the first rung *at or above* the requested width rather
  /// than the nearest one: undershooting shows the user a visibly soft image,
  /// while overshooting only costs bytes. When nothing on the ladder is big
  /// enough — a full-bleed hero on a 3x phone — this returns null and the
  /// caller uses the original, which is the correct answer rather than a
  /// fallback.
  ///
  /// WebP is preferred unconditionally: Flutter decodes it natively on both
  /// platforms, and it is where the saving is (the backend's own measurement
  /// found format conversion, not resizing, to be the dominant factor). The
  /// JPEG set exists for consumers that cannot, and is used here only when a
  /// size is missing from the WebP set.
  String? urlFor(double physicalWidth) {
    for (final (String name, int intrinsic) in ladder) {
      if (intrinsic + 0.5 < physicalWidth) continue;
      final String? url = webp[name] ?? jpg[name];
      if (url != null) return url;
    }
    return null;
  }

  /// Intrinsic width of the variant [urlFor] would return, so a caller can cap
  /// its decode at the file's real size instead of asking for more pixels than
  /// the file contains.
  int? intrinsicWidthFor(double physicalWidth) {
    for (final (String name, int intrinsic) in ladder) {
      if (intrinsic + 0.5 < physicalWidth) continue;
      if (webp.containsKey(name) || jpg.containsKey(name)) return intrinsic;
    }
    return null;
  }
}
