/// An offer a store runs and pays for (store app → Offers), as listed in the
/// store's `active_offers`. A % offer also arrives as the store's `discount`,
/// which the app already shows and prices; amount-off and free delivery
/// only come through here.
class StoreOffer {
  final int id;
  final String type; // percent | amount | free_delivery
  final double value;
  final double minOrder;
  final double? maxDiscount;
  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;

  const StoreOffer({required this.id, required this.type, required this.value, required this.minOrder,
    this.maxDiscount, required this.startDate, required this.endDate, required this.startTime, required this.endTime});

  static StoreOffer? fromJson(dynamic json) {
    if (json is! Map) return null;
    double num0(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;
    return StoreOffer(
      id: int.tryParse('${json['id']}') ?? 0,
      type: '${json['type'] ?? ''}',
      value: num0(json['value']),
      minOrder: num0(json['min_order']),
      maxDiscount: json['max_discount'] == null ? null : num0(json['max_discount']),
      startDate: '${json['start_date'] ?? ''}',
      endDate: '${json['end_date'] ?? ''}',
      startTime: '${json['start_time'] ?? '00:00'}',
      endTime: '${json['end_time'] ?? '23:59'}',
    );
  }

  static List<StoreOffer> listFromJson(dynamic json) =>
      json is List ? json.map(StoreOffer.fromJson).whereType<StoreOffer>().toList() : const [];

  /// Same rule as the server (StoreOfferService::windowOpen): inside the
  /// dates and the daily hours, which may run past midnight. The budget is
  /// the server's to check; an offer that ran out disappears from the list.
  bool isLive(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    final String day = '${now.year}-${two(now.month)}-${two(now.day)}';
    if (day.compareTo(startDate.substring(0, startDate.length.clamp(0, 10))) < 0 ||
        day.compareTo(endDate.substring(0, endDate.length.clamp(0, 10))) > 0) {
      return false;
    }
    final String t = '${two(now.hour)}:${two(now.minute)}';
    final String from = startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
    final String to = endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
    return from.compareTo(to) <= 0 ? (t.compareTo(from) >= 0 && t.compareTo(to) <= 0) : (t.compareTo(from) >= 0 || t.compareTo(to) <= 0);
  }

  /// EGP off a basket of [subtotal] for an amount offer (server: amountOff).
  double amountOff(double subtotal) => type != 'amount' || subtotal <= 0 || subtotal < minOrder ? 0 : (value < subtotal ? value : subtotal);
}
