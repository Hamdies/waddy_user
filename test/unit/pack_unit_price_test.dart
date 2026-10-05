import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/store/helpers/pack_size.dart';

void main() {
  group('PackSize.unitPrice', () {
    test('a small volume is priced per 100 ml', () {
      final r = PackSize.unitPrice('220 ml', 100)!;
      expect(r.per, '100 ml');
      expect(r.price, closeTo(45.45, 0.01));
    });

    test('a small weight is priced per 100 g', () {
      final r = PackSize.unitPrice('250 g', 50)!;
      expect(r.per, '100 g');
      expect(r.price, closeTo(20, 0.001));
    });

    test('a litre or more is priced per L, a kilo or more per kg', () {
      expect(PackSize.unitPrice('1.5 L', 60)!.per, 'L');
      expect(PackSize.unitPrice('1.5 L', 60)!.price, closeTo(40, 0.001));
      expect(PackSize.unitPrice('2 kg', 90)!.per, 'kg');
      expect(PackSize.unitPrice('2 kg', 90)!.price, closeTo(45, 0.001));
    });

    test('a multipack counts every unit in it', () {
      final r = PackSize.unitPrice('6 × 200 ml', 120)!;
      expect(r.per, 'L');
      expect(r.price, closeTo(100, 0.001));
    });

    test('a pack that already IS the measure says nothing', () {
      expect(PackSize.unitPrice('100 ml', 110), isNull);
      expect(PackSize.unitPrice('1 kg', 80), isNull);
      expect(PackSize.unitPrice('100 g', 20), isNull);
    });

    test('counts, junk and free items have no per-unit price', () {
      expect(PackSize.unitPrice('52 pcs', 200), isNull);
      expect(PackSize.unitPrice(null, 100), isNull);
      expect(PackSize.unitPrice('220 ml', 0), isNull);
    });
  });
}
