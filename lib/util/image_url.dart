import 'package:waddy_app/util/app_constants.dart';

/// Picks the first usable image URL out of a list of API candidates.
///
/// The Spots endpoints are inconsistent about which key carries an image and
/// what that key holds. `Place` overrides its `image`/`cover_image` accessors
/// to return `asset('storage/places/...')`, so those columns arrive as absolute
/// URLs. `PlaceVote` instead appends a separate `image_url` accessor and leaves
/// the raw `image` column as a bare filename. `PlaceBanner` sends its
/// `image_full_url` accessor under the key `image`. Callers therefore pass the
/// keys they might get, best first, and let this sort it out:
///
/// ```dart
/// image: pickImageUrl([json['image_full_url'], json['image']]),
/// ```
///
/// A candidate is used when it is an absolute `http(s)` URL, or a path that
/// can be resolved against [AppConstants.baseUrl]. Everything else is skipped
/// so a later candidate can win: nulls, empty and whitespace-only strings, the
/// literal `"null"` that a few PHP casts emit, and bare filenames like
/// `abc.jpg` — those name a file in a storage folder this side cannot know, so
/// there is no URL to build and requesting one would only fail into the
/// placeholder anyway.
///
/// Returns null when no candidate is usable, which is what every `CustomImage`
/// call site already handles by falling back to its placeholder.
String? pickImageUrl(List<dynamic> candidates) {
  for (final dynamic candidate in candidates) {
    if (candidate is! String) continue;

    final String value = candidate.trim();
    if (value.isEmpty || value == 'null' || value == 'undefined') continue;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    // A rooted or nested path is resolvable against the API host; a bare
    // filename is not.
    if (value.startsWith('/')) {
      return '${AppConstants.baseUrl}$value';
    }
    if (value.contains('/')) {
      return '${AppConstants.baseUrl}/$value';
    }
  }
  return null;
}
