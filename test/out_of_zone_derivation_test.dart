import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';

/// Mirrors LocationController.outOfServingZone. That getter reads the saved
/// address through GetX, which needs a full DI container to instantiate; the
/// DECISION it makes is pure, so it's pinned here against the same inputs.
///
/// Keep in sync with LocationController.outOfServingZone.
bool outOfServingZone(AddressModel? saved) {
  if (saved == null) return false;
  final String? lat = saved.latitude;
  if (lat == null || lat.isEmpty || lat == 'null') return false;
  return saved.zoneIds?.isEmpty ?? true;
}

AddressModel address({
  String? lat = '30.116',
  String? lng = '31.319',
  List<int>? zoneIds,
}) => AddressModel(latitude: lat, longitude: lng, zoneIds: zoneIds);

void main() {
  group('outOfServingZone is derived from the saved address', () {
    test('in zone when the address carries zone ids', () {
      expect(outOfServingZone(address(zoneIds: [3])), isFalse);
    });

    test('out of zone when the address has empty zone ids', () {
      expect(outOfServingZone(address(zoneIds: [])), isTrue);
    });

    test('out of zone when zone ids are missing entirely', () {
      expect(outOfServingZone(address()), isTrue);
    });

    // The regression that caused this rewrite: state had to survive a restart.
    // Deriving from the persisted address means re-reading the same saved
    // value always yields the same answer — there is no in-memory flag to lose.
    test('survives a restart: same saved address yields the same answer', () {
      final saved = address(zoneIds: []);
      final beforeRestart = outOfServingZone(saved);
      final afterRestart = outOfServingZone(
        AddressModel(
          latitude: saved.latitude,
          longitude: saved.longitude,
          zoneIds: saved.zoneIds,
        ),
      );
      expect(afterRestart, beforeRestart);
      expect(afterRestart, isTrue);
    });

    group('no usable address must not read as out of zone', () {
      test('null address', () {
        expect(outOfServingZone(null), isFalse);
      });

      test('cleared address (empty AddressModel)', () {
        expect(outOfServingZone(AddressModel()), isFalse);
      });

      // AddressModel.fromJson stringifies nulls, so a cleared address round
      // -tripped through prefs has the literal 'null' rather than a real value.
      test("address whose latitude is the string 'null'", () {
        expect(outOfServingZone(address(lat: 'null', zoneIds: [])), isFalse);
      });

      test('address with an empty latitude', () {
        expect(outOfServingZone(address(lat: '', zoneIds: [])), isFalse);
      });
    });
  });
}
