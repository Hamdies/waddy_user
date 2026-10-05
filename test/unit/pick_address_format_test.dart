import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/location/helpers/pick_address_format.dart';

/// The pick-map card shows two lines of address. They must never say the same
/// thing twice, and the first one must never be machine output.
///
/// The screen previously printed the whole `formatted_address` in bold and then
/// printed it again minus its first segment in grey, so the real Maadi address
/// below rendered as six lines that were ~55% the same characters — with a
/// Google plus code as the loudest text on the card.
void main() {
  const String fallback = 'Searching address...';

  ({String headline, String detail}) split(String raw) =>
      splitPickAddress(raw, fallback: fallback);

  group('the address off a real device', () {
    // Verbatim from a Mi 9T screenshot of the pin dropped in Maadi.
    const String maadi =
        'X755+8JM, Mostafa Kamel, Maadi Al Khabiri Ash Sharqeyah, '
        'Maadi, Cairo Governorate 4211111, Egypt';

    test('leads with the street, not the plus code', () {
      expect(split(maadi).headline, 'Mostafa Kamel');
    });

    test('never repeats the headline in the detail line', () {
      final r = split(maadi);
      expect(r.detail.contains(r.headline), isFalse);
    });

    test('drops the governorate and country tail', () {
      final r = split(maadi);
      expect(r.detail, 'Maadi Al Khabiri Ash Sharqeyah, Maadi');
      expect(r.detail, isNot(contains('Egypt')));
      expect(r.detail, isNot(contains('4211111')));
    });
  });

  group('plus codes', () {
    test('are dropped when a real name follows', () {
      expect(split('9C4F+2X, Alexandria, Egypt').headline, 'Alexandria');
    });

    test('are kept when they are all there is', () {
      // A plus code still beats a blank card.
      expect(split('X755+8JM').headline, 'X755+8JM');
    });

    test('a normal first segment is never mistaken for one', () {
      expect(split('Mostafa Kamel, Maadi').headline, 'Mostafa Kamel');
    });
  });

  group('Arabic addresses', () {
    test('split on the same separator without mangling the script', () {
      final r = split('شارع مصطفى كامل, المعادي, القاهرة, مصر');
      expect(r.headline, 'شارع مصطفى كامل');
      expect(r.detail, 'المعادي, القاهرة');
    });
  });

  group('degenerate input', () {
    test('an empty string falls back rather than printing nothing', () {
      expect(split('').headline, fallback);
    });

    test('whitespace only falls back', () {
      expect(split('   ').headline, fallback);
    });

    test('separators only never become the name of a place', () {
      expect(split(',,,,').headline, fallback);
    });

    test('a single segment has no detail line to duplicate', () {
      final r = split('Egypt');
      expect(r.headline, 'Egypt');
      expect(r.detail, isEmpty);
    });

    test('empty segments are skipped, not rendered as blanks', () {
      final r = split('Maadi, , , Cairo');
      expect(r.headline, 'Maadi');
      expect(r.detail, 'Cairo');
    });
  });
}
