import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// What the store screen can honestly say a delivery will cost.
///
/// The authoritative number is [CheckoutCalculationHelper.calculateOriginalDeliveryCharge],
/// which runs at checkout with a confirmed address. This is the same ladder —
/// self-delivery rates, then the zone's distance or fixed rates, then the
/// min/max clamp — evaluated early so the store screen can quote a fee before
/// the user commits to anything. The two MUST agree: a screen that promises 25
/// and charges 30 is worse than a screen that promised nothing.
///
/// It returns null rather than guessing. A quote that cannot be trusted is not
/// a quote, and the caller renders a different cell when it gets null.
class StoreDeliveryFee {
  /// Distances beyond this are treated as unusable rather than multiplied.
  ///
  /// Waddy operates inside Maadi — Degla, Sarayat, Corniche — where a real
  /// store is single-digit kilometres away. The store list has been observed
  /// returning distances in the hundreds (a 269.4 km "Maadi Sarayat"), which
  /// is a wrong ORIGIN rather than a real trip. Feeding that into a per-km
  /// rate would render a four-digit fee with total confidence, and a visibly
  /// absurd price on the screen before add-to-cart costs more trust than a
  /// missing cell ever could.
  ///
  /// The ceiling is deliberately far outside the service area: it is a sanity
  /// check on obviously broken data, not a business rule about how far Waddy
  /// will deliver. That rule is the zone, and the zone is enforced elsewhere.
  static const double maxPlausibleKm = 60;

  /// The delivery charge for [store] from the user's saved [address], or null
  /// when no trustworthy number exists.
  ///
  /// Null means: no address or no zone data yet, no matching zone rates for
  /// this store, a distance-based zone whose distance is missing or
  /// implausible, or rates that produce nothing.
  static double? estimate({
    required Store? store,
    required AddressModel? address,
  }) {
    if (store == null || address == null) return null;

    final Pivot? zoneRates = _ratesForStoreZone(store, address);

    // Self-delivery stores carry their own rates and ignore the zone's.
    final bool selfDelivery = store.selfDeliverySystem == 1;

    double perKm;
    double minimum;
    double? maximum;

    if (selfDelivery) {
      perKm = store.perKmShippingCharge ?? 0;
      minimum = store.minimumShippingCharge ?? 0;
      maximum = store.maximumShippingCharge;
    } else if (zoneRates == null) {
      // No rates for this store's zone — nothing to compute from.
      return null;
    } else if (zoneRates.deliveryChargeType == 'fixed') {
      // A flat fee needs no distance at all, so it is quotable even while the
      // distance data is untrustworthy. This is the one branch the 269 km bug
      // cannot reach.
      final double fixed = zoneRates.fixedShippingCharge ?? 0;
      return fixed > 0 ? fixed : null;
    } else {
      perKm = zoneRates.perKmShippingCharge ?? 0;
      minimum = zoneRates.minimumShippingCharge ?? 0;
      maximum = zoneRates.maximumShippingCharge;
    }

    // Everything below here is per-km, so it needs a distance it can believe.
    final double? km = _plausibleDistance(store.distance);
    if (km == null) return null;

    if (perKm <= 0 && minimum <= 0) return null;

    double charge = km * perKm;
    if (charge < minimum) charge = minimum;
    if (maximum != null && maximum > 0 && charge > maximum) charge = maximum;

    return charge > 0 ? charge : null;
  }

  /// The zone rates that apply to [store], matched the way checkout matches
  /// them: the user's zone entry whose module is the active one and whose zone
  /// is the store's.
  ///
  /// [moduleId] is not threaded in here — the store screen is always inside
  /// one module and the address can only hold one pivot per (module, zone)
  /// pair, so matching on the store's zone alone resolves the same row.
  static Pivot? _ratesForStoreZone(Store store, AddressModel address) {
    final List<ZoneData>? zones = address.zoneData;
    if (zones == null) return null;

    for (final ZoneData zone in zones) {
      final List<Modules>? modules = zone.modules;
      if (modules == null) continue;
      for (final Modules m in modules) {
        final Pivot? pivot = m.pivot;
        if (pivot != null && pivot.zoneId == store.zoneId) return pivot;
      }
    }
    return null;
  }

  /// [raw] when it is a distance a Maadi delivery could actually have.
  ///
  /// Rejects null, the -1 sentinel the backend uses for "unknown", zero, and
  /// anything past [maxPlausibleKm].
  static double? _plausibleDistance(double? raw) {
    if (raw == null) return null;
    if (raw <= 0) return null;
    if (raw > maxPlausibleKm) return null;
    return raw;
  }
}
