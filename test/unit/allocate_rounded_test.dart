import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/helper/price_converter.dart';

/// Cart lines are rounded together so the printed lines add up to the printed
/// total (which is what the server charges: it rounds the unrounded sum).
void main() {
  double sum(List<double> v) => v.fold(0, (a, b) => a + b);

  group('allocateRounded, 0 decimals (LE)', () {
    test('Taameya 33.75 + Hawawshi 82.5 → 34 + 82 = 116, not 34 + 83', () {
      final r = PriceConverter.allocateRounded([33.75, 82.5], digits: 0);
      expect(r, [34, 82]);
      expect(sum(r), 116);
    });

    test('savings follow: 45−34 + 110−82 = 39, the banner figure', () {
      final r = PriceConverter.allocateRounded([33.75, 82.5], digits: 0);
      expect((45 - r[0]) + (110 - r[1]), 39);
    });

    test('three lines: 33.75 + 82.5 + 41.25 = 157.5 → 158', () {
      final r = PriceConverter.allocateRounded([
        33.75,
        82.5,
        41.25,
      ], digits: 0);
      expect(sum(r), 158);
      // 33, 82, 41 floor to 156; the two largest remainders (.75, .5) win.
      expect(r, [34, 83, 41]);
    });

    test('rounding down: 10.4 + 10.4 + 10.4 = 31.2 → 31', () {
      final r = PriceConverter.allocateRounded([10.4, 10.4, 10.4], digits: 0);
      expect(sum(r), 31);
      for (final v in r) {
        expect(v, anyOf(10, 11));
      }
    });

    test('whole numbers pass through untouched', () {
      expect(PriceConverter.allocateRounded([34, 83, 56], digits: 0), [
        34,
        83,
        56,
      ]);
    });

    test('single line equals its own rounding', () {
      expect(PriceConverter.allocateRounded([82.5], digits: 0), [83]);
    });

    test('empty', () {
      expect(PriceConverter.allocateRounded([], digits: 0), isEmpty);
    });
  });

  test('2 decimals: 0.335 ×3 = 1.005 → lines sum to 1.01', () {
    final r = PriceConverter.allocateRounded([
      0.335,
      0.335,
      0.335,
    ], digits: 2);
    expect((sum(r) * 100).round(), 101);
  });
}
