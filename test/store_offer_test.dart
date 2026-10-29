import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/store/domain/models/store_offer.dart';

void main() {
  StoreOffer offer(String type, {double value = 50, double min = 200, String from = '15:00', String to = '17:59'}) =>
      StoreOffer.fromJson({'id': 1, 'type': type, 'value': value, 'min_order': min, 'start_date': '2026-11-01', 'end_date': '2026-11-30', 'start_time': from, 'end_time': to})!;

  test('live inside the dates and the daily hours, like the server', () {
    final o = offer('amount');
    expect(o.isLive(DateTime(2026, 11, 10, 15, 0)), isTrue);
    expect(o.isLive(DateTime(2026, 11, 10, 17, 59)), isTrue);
    expect(o.isLive(DateTime(2026, 11, 10, 18, 0)), isFalse);
    expect(o.isLive(DateTime(2026, 10, 31, 16, 0)), isFalse);
    expect(o.isLive(DateTime(2026, 12, 1, 16, 0)), isFalse);
  });

  test('hours may run past midnight', () {
    final o = offer('free_delivery', from: '22:00', to: '02:00');
    expect(o.isLive(DateTime(2026, 11, 10, 23, 30)), isTrue);
    expect(o.isLive(DateTime(2026, 11, 11, 1, 59)), isTrue);
    expect(o.isLive(DateTime(2026, 11, 10, 12, 0)), isFalse);
  });

  test('amount off needs the minimum and never beats the basket', () {
    expect(offer('amount').amountOff(199.99), 0);
    expect(offer('amount').amountOff(200), 50);
    expect(offer('amount', min: 0).amountOff(30), 30);
    expect(offer('percent').amountOff(500), 0);
  });

  test('a list from the store JSON skips garbage', () {
    expect(StoreOffer.listFromJson([{'id': 2, 'type': 'amount', 'value': '25', 'min_order': '100', 'start_date': '2026-11-01', 'end_date': '2026-11-02'}, 'x']).single.value, 25);
    expect(StoreOffer.listFromJson(null), isEmpty);
  });
}
