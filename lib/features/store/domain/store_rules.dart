import 'package:geolocator/geolocator.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/util/parse.dart';

/// Questions a [Store] answers about itself (ST-14).
///
/// These lived on `StoreController`, so checkout and every store card
/// `Get.find`-ed a 1,600-line controller to call a function of a store they
/// already held — and a card that asked could not be built without that
/// controller registered.
extension StoreRules on Store {
  /// The server's live flag: open right now and not deactivated.
  bool get isOpenNow => open == 1 && (active ?? false);

  /// The store-wide discount amount, 0 when there is none.
  double get discountValue => discount?.discount ?? 0;

  /// The store-wide discount's type, `percent` when it does not say.
  String get discountTypeOrPercent => discount?.discountType ?? 'percent';

  /// Closed all day today (or tomorrow): inactive, or no schedule row for
  /// that weekday. See [StoreSchedule.isClosed].
  bool isClosedOn({required bool today, DateTime? now}) =>
      StoreSchedule.isClosed(
        today: today,
        active: active ?? false,
        schedules: schedules,
        now: now,
      );

  /// Open at this moment by its own schedule. See [StoreSchedule.isOpenNow].
  bool isOpenBySchedule({DateTime? now}) => StoreSchedule.isOpenNow(
    active: active ?? false,
    schedules: schedules,
    now: now,
  );

  /// Raw `HH:mm:ss` closing time of the schedule row open right now, or null
  /// when the store is closed, has no matching row, or runs all day (a
  /// 23:59 close would read as "Open until 11:59 PM", which says nothing).
  String? closesAt({DateTime? now}) {
    if (!isOpenNow) return null;
    final int weekday = StoreSchedule._backendWeekday(now ?? DateTime.now());
    for (final Schedules s in schedules ?? const <Schedules>[]) {
      if (s.day != weekday || s.closingTime == null) continue;
      if (!DateConverter.isAvailable(s.openingTime, s.closingTime, time: now)) {
        continue;
      }
      if (s.closingTime!.startsWith('23:59')) return null;
      return s.closingTime;
    }
    return null;
  }

  /// Kilometres from the user's saved address, or null when either end has
  /// no usable coordinates.
  ///
  /// **Nullable, not a `-1` sentinel.** The delivery-charge path already
  /// carries a `-1` "not computable" marker, and §14.1 of the hardening plan
  /// records what that cost: `calculateTotal` added it blindly and knocked a
  /// pound off the displayed total. An unknown distance is absent.
  double? distanceFromUserKm() {
    final double? storeLat = Parse.coordinate(latitude);
    final double? storeLng = Parse.coordinate(longitude);
    if (storeLat == null || storeLng == null) return null;
    final AddressModel? address = AddressHelper.getUserAddressFromSharedPref();
    final double? userLat = Parse.coordinate(address?.latitude);
    final double? userLng = Parse.coordinate(address?.longitude);
    if (userLat == null || userLng == null) return null;
    return Geolocator.distanceBetween(storeLat, storeLng, userLat, userLng) /
        1000;
  }
}

/// Schedule arithmetic on the raw fields, for callers that hold the fields
/// rather than the [Store] (checkout's time-slot code).
///
/// Weekdays follow the backend: 0 = Sunday … 6 = Saturday, where Dart says
/// 7 for Sunday. [now] is for tests; production reads the clock — `DateTime.now()`
/// for the weekday and the splash controller's server-calibrated time for the
/// opening hours, exactly as the controller methods these replace did.
class StoreSchedule {
  StoreSchedule._();

  static int _backendWeekday(DateTime date) =>
      date.weekday == DateTime.sunday ? 0 : date.weekday;

  static bool isClosed({
    required bool today,
    required bool active,
    required List<Schedules>? schedules,
    DateTime? now,
  }) {
    if (!active) return true;
    DateTime date = now ?? DateTime.now();
    if (!today) date = date.add(const Duration(days: 1));
    final int weekday = _backendWeekday(date);
    // A store with no schedule rows has no open day. The controller version
    // dereferenced `schedules!` here, and a thin payload threw instead.
    return !(schedules ?? const <Schedules>[]).any(
      (Schedules s) => s.day == weekday,
    );
  }

  static bool isOpenNow({
    required bool active,
    required List<Schedules>? schedules,
    DateTime? now,
  }) {
    if (isClosed(today: true, active: active, schedules: schedules, now: now)) {
      return false;
    }
    final int weekday = _backendWeekday(now ?? DateTime.now());
    return (schedules ?? const <Schedules>[]).any(
      (Schedules s) =>
          s.day == weekday &&
          DateConverter.isAvailable(s.openingTime, s.closingTime, time: now),
    );
  }
}
