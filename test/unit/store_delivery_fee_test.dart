import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/helpers/store_delivery_fee.dart';

/// An address whose zone publishes [pivot] for zone 1.
AddressModel _addressWithRates(Pivot pivot) {
  return AddressModel(
    zoneData: [
      ZoneData(id: 1, modules: [Modules(id: 7, pivot: pivot)]),
    ],
  );
}

Pivot _distanceRates({
  double perKm = 5,
  double min = 15,
  double? max = 60,
  int zoneId = 1,
}) => Pivot(
  zoneId: zoneId,
  moduleId: 7,
  deliveryChargeType: 'distance',
  perKmShippingCharge: perKm,
  minimumShippingCharge: min,
  maximumShippingCharge: max,
);

Store _store({
  double? distance,
  int selfDeliverySystem = 0,
  int zoneId = 1,
  double? perKm,
  double? min,
  double? max,
}) => Store(
  id: 1,
  name: 'Zooba Maadi',
  zoneId: zoneId,
  distance: distance,
  selfDeliverySystem: selfDeliverySystem,
  perKmShippingCharge: perKm,
  minimumShippingCharge: min,
  maximumShippingCharge: max,
);

void main() {
  group('per-km zone rates', () {
    test('a real Maadi distance yields the per-km charge', () {
      // 4 km x 5 = 20, above the 15 minimum and below the 60 ceiling.
      final fee = StoreDeliveryFee.estimate(
        store: _store(distance: 4),
        address: _addressWithRates(_distanceRates()),
      );
      expect(fee, 20);
    });

    test('a short trip is lifted to the zone minimum', () {
      // 1 km x 5 = 5, below the 15 minimum.
      final fee = StoreDeliveryFee.estimate(
        store: _store(distance: 1),
        address: _addressWithRates(_distanceRates()),
      );
      expect(fee, 15);
    });

    test('a long trip is capped at the zone maximum', () {
      // 30 km x 5 = 150, above the 60 ceiling.
      final fee = StoreDeliveryFee.estimate(
        store: _store(distance: 30),
        address: _addressWithRates(_distanceRates()),
      );
      expect(fee, 60);
    });
  });

  group('refuses to quote on untrustworthy data', () {
    test('the 269 km Maadi store yields no fee, not a 1,300 LE one', () {
      // The exact value observed on the store screen for a Maadi Sarayat
      // restaurant. Multiplying it would have rendered a confident, absurd
      // price; the cell must fall back instead.
      final fee = StoreDeliveryFee.estimate(
        store: _store(distance: 269.4),
        address: _addressWithRates(_distanceRates()),
      );
      expect(fee, isNull);
    });

    test('the -1 unknown-distance sentinel yields no fee', () {
      final fee = StoreDeliveryFee.estimate(
        store: _store(distance: -1),
        address: _addressWithRates(_distanceRates()),
      );
      expect(fee, isNull);
    });

    test('a missing distance yields no fee', () {
      final fee = StoreDeliveryFee.estimate(
        store: _store(distance: null),
        address: _addressWithRates(_distanceRates()),
      );
      expect(fee, isNull);
    });

    test('no saved address yields no fee', () {
      expect(
        StoreDeliveryFee.estimate(store: _store(distance: 4), address: null),
        isNull,
      );
    });

    test('rates for a different zone do not apply to this store', () {
      final fee = StoreDeliveryFee.estimate(
        store: _store(distance: 4, zoneId: 2),
        address: _addressWithRates(_distanceRates()),
      );
      expect(fee, isNull);
    });
  });

  group('fixed-charge zones', () {
    test('quote a flat fee without consulting distance at all', () {
      // The branch the distance bug cannot reach: even at 269 km a fixed zone
      // charges its flat rate, so it is still safe to quote.
      final fee = StoreDeliveryFee.estimate(
        store: _store(distance: 269.4),
        address: _addressWithRates(
          Pivot(
            zoneId: 1,
            moduleId: 7,
            deliveryChargeType: 'fixed',
            fixedShippingCharge: 25,
          ),
        ),
      );
      expect(fee, 25);
    });

    test('a zero flat fee is not a quote', () {
      final fee = StoreDeliveryFee.estimate(
        store: _store(distance: 4),
        address: _addressWithRates(
          Pivot(
            zoneId: 1,
            moduleId: 7,
            deliveryChargeType: 'fixed',
            fixedShippingCharge: 0,
          ),
        ),
      );
      expect(fee, isNull);
    });
  });

  group('self-delivery stores', () {
    test('use their own rates, not the zone table', () {
      // Store charges 10/km; the zone says 5/km. The store wins.
      final fee = StoreDeliveryFee.estimate(
        store: _store(
          distance: 3,
          selfDeliverySystem: 1,
          perKm: 10,
          min: 0,
          max: 100,
        ),
        address: _addressWithRates(_distanceRates()),
      );
      expect(fee, 30);
    });

    test('are still refused on an implausible distance', () {
      final fee = StoreDeliveryFee.estimate(
        store: _store(
          distance: 269.4,
          selfDeliverySystem: 1,
          perKm: 10,
          min: 0,
        ),
        address: _addressWithRates(_distanceRates()),
      );
      expect(fee, isNull);
    });

    test('quote with no zone rates present at all', () {
      final fee = StoreDeliveryFee.estimate(
        store: _store(distance: 3, selfDeliverySystem: 1, perKm: 10, min: 0),
        address: AddressModel(zoneData: []),
      );
      expect(fee, 30);
    });
  });
}
