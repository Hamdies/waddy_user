import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';

/// Mirrors LocationGate.hasUsableAddress. The real getter reads shared prefs
/// through GetX, which needs a full DI container; the DECISION is pure, so it
/// is pinned here against the same inputs.
///
/// Keep in sync with LocationGate.hasUsableAddress.
bool hasUsableAddress(AddressModel? saved) {
  bool valid(String? v) =>
      v != null && v.isNotEmpty && v != 'null' && double.tryParse(v) != null;
  return valid(saved?.latitude) && valid(saved?.longitude);
}

AddressModel addr(String? lat, String? lng, {List<int>? zoneIds}) =>
    AddressModel(latitude: lat, longitude: lng, zoneIds: zoneIds);

void main() {
  group('LocationGate.hasUsableAddress', () {
    test('real in-zone position is usable', () {
      expect(hasUsableAddress(addr('30.116', '31.319', zoneIds: [3])), isTrue);
    });

    // The whole point of Step A: out of zone is a REAL place we don't serve.
    // The gate must let these users through, not trap them in the picker.
    test('real OUT OF ZONE position is still usable', () {
      expect(hasUsableAddress(addr('30.116', '31.319', zoneIds: [])), isTrue);
    });

    group('absent location must NOT pass the gate', () {
      test('null address', () {
        expect(hasUsableAddress(null), isFalse);
      });

      test('cleared address (empty AddressModel)', () {
        expect(hasUsableAddress(AddressModel()), isFalse);
      });

      // AddressModel.fromJson stringifies nulls, so a cleared address that has
      // round-tripped through shared prefs holds the literal string 'null'.
      test("stringified nulls from a prefs round-trip", () {
        expect(hasUsableAddress(addr('null', 'null')), isFalse);
      });

      test('empty strings', () {
        expect(hasUsableAddress(addr('', '')), isFalse);
      });

      test('non-numeric garbage', () {
        expect(hasUsableAddress(addr('abc', 'def')), isFalse);
      });

      test('half an address (latitude only)', () {
        expect(hasUsableAddress(addr('30.116', null)), isFalse);
      });
    });

    test('boundary coordinates (0,0) are numerically valid', () {
      // Null Island is a real coordinate. Rejecting it would be a guess about
      // intent; the zone lookup is what decides whether we serve it.
      expect(hasUsableAddress(addr('0', '0')), isTrue);
    });

    test('negative coordinates are valid', () {
      expect(hasUsableAddress(addr('-33.86', '-151.20')), isTrue);
    });
  });
}
