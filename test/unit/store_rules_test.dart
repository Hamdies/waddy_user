import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/domain/store_rules.dart';

/// ST-14: store rules as functions of the store, testable without a
/// controller. Weekdays are the backend's: 0 = Sunday … 6 = Saturday.
void main() {
  // Wednesday 30 Sept 2026, 14:00 — backend weekday 3.
  final DateTime wednesday2pm = DateTime(2026, 9, 30, 14);

  Schedules day(int d, [String open = '09:00', String close = '22:00']) =>
      Schedules(day: d, openingTime: open, closingTime: close);

  group('StoreSchedule.isClosed', () {
    test('inactive is closed whatever the schedule says', () {
      expect(
        StoreSchedule.isClosed(
          today: true,
          active: false,
          schedules: [day(3)],
          now: wednesday2pm,
        ),
        isTrue,
      );
    });

    test('closed when no row exists for the weekday', () {
      expect(
        StoreSchedule.isClosed(
          today: true,
          active: true,
          schedules: [day(4)],
          now: wednesday2pm,
        ),
        isTrue,
      );
      expect(
        StoreSchedule.isClosed(
          today: false, // tomorrow is Thursday = 4
          active: true,
          schedules: [day(4)],
          now: wednesday2pm,
        ),
        isFalse,
      );
    });

    test('Sunday maps to backend day 0, not Dart 7', () {
      final DateTime sunday = DateTime(2026, 10, 4, 12);
      expect(
        StoreSchedule.isClosed(
          today: true,
          active: true,
          schedules: [day(0)],
          now: sunday,
        ),
        isFalse,
      );
    });

    test('a store without schedule rows is closed, not a crash', () {
      expect(
        StoreSchedule.isClosed(
          today: true,
          active: true,
          schedules: null,
          now: wednesday2pm,
        ),
        isTrue,
      );
    });
  });

  group('StoreSchedule.isOpenNow', () {
    test('open inside today\'s hours', () {
      expect(
        StoreSchedule.isOpenNow(
          active: true,
          schedules: [day(3)],
          now: wednesday2pm,
        ),
        isTrue,
      );
    });

    test('closed outside today\'s hours', () {
      expect(
        StoreSchedule.isOpenNow(
          active: true,
          schedules: [day(3, '18:00', '23:00')],
          now: wednesday2pm,
        ),
        isFalse,
      );
    });

    test('another day\'s hours do not count', () {
      expect(
        StoreSchedule.isOpenNow(
          active: true,
          schedules: [day(4)],
          now: wednesday2pm,
        ),
        isFalse,
      );
    });
  });

  group('StoreRules', () {
    test('isOpenNow needs both the live flag and active', () {
      expect(Store(open: 1, active: true).isOpenNow, isTrue);
      expect(Store(open: 0, active: true).isOpenNow, isFalse);
      expect(Store(open: 1, active: false).isOpenNow, isFalse);
      expect(Store(open: 1).isOpenNow, isFalse, reason: 'no active flag');
    });

    test('discount defaults: 0 and percent', () {
      expect(Store().discountValue, 0);
      expect(Store().discountTypeOrPercent, 'percent');
      final Store discounted = Store(
        discount: Discount(discount: 15, discountType: 'amount'),
      );
      expect(discounted.discountValue, 15);
      expect(discounted.discountTypeOrPercent, 'amount');
    });

    test('isClosedOn reads the store\'s own fields', () {
      final Store store = Store(active: true, schedules: [day(3)]);
      expect(store.isClosedOn(today: true, now: wednesday2pm), isFalse);
      expect(store.isClosedOn(today: false, now: wednesday2pm), isTrue);
    });

    test('no coordinates, no distance', () {
      expect(Store().distanceFromUserKm(), isNull);
    });
  });
}
