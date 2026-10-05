/// Turns a raw geocoder `formatted_address` into the two lines the pick-map
/// card shows.
///
/// The card used to print the whole address in 18px bold and then print it
/// AGAIN, minus its first segment, in 16px grey — six lines of type saying one
/// thing, most of the characters duplicated. Reading an address twice registers
/// as a bug at the exact moment the app is asking to be trusted with where you
/// live, so the two lines here are guaranteed not to overlap.
///
/// Lives outside the widget so the parsing is testable on its own: it is the
/// part that meets real backend data, and Google returns plus codes, empty
/// segments and Arabic scripts on the same endpoint.
library;

/// A headline (the place) and a supporting line that locates it. [detail] is
/// empty when the address has nothing further to say.
typedef PickAddressLines = ({String headline, String detail});

/// Open Location Code ("X755+8JM"): 4+ base-20 chars, a '+', then 2+ more.
/// Google prefixes one whenever it has no street name for the point.
final RegExp _plusCode = RegExp(
  r'^[23456789CFGHJMPQRVWX]{4,}\+[23456789CFGHJMPQRVWX]{2,}$',
);

final RegExp _hasMeaning = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Splits [raw] into a headline and a detail line.
///
/// A leading plus code is dropped when something better follows it: it is
/// machine language, no one describes their home as "X755+8JM", and as the
/// loudest text on the card it reads like an error code. It is KEPT when it is
/// all there is, since a plus code still beats a blank card.
///
/// [fallback] is returned as the headline when [raw] carries no letters or
/// digits at all (","  or "   "), so punctuation never becomes the name of a
/// place.
PickAddressLines splitPickAddress(String raw, {required String fallback}) {
  final parts =
      raw.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  if (parts.isEmpty) {
    final String trimmed = raw.trim();
    return (
      headline: _hasMeaning.hasMatch(trimmed) ? trimmed : fallback,
      detail: '',
    );
  }

  if (parts.length > 1 && _plusCode.hasMatch(parts.first)) {
    parts.removeAt(0);
  }

  return (
    headline: parts.first,
    // Two segments is enough to place the headline (district + city).
    // "Cairo Governorate 4211111, Egypt" adds nothing a local needs, and
    // every extra segment costs a line the confirm button needs.
    detail: parts.skip(1).take(2).join(', '),
  );
}
