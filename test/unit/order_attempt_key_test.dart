import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/checkout/domain/models/place_order_body_model.dart';
import 'package:waddy_app/helper/order_attempt_key.dart';

/// A retry must carry the key of the attempt it retries.
///
/// The failure these guard against: the first request times out on a slow
/// connection, the order WAS created, the customer taps again, and a fresh key
/// makes the server treat it as a second order. The fake network below does
/// exactly that — time out, then answer.
void main() {
  late DateTime clock;
  late int issued;
  late OrderAttemptKey attempt;

  setUp(() {
    clock = DateTime(2026, 10, 5, 12);
    issued = 0;
    attempt = OrderAttemptKey(
      now: () => clock,
      generate: () => 'key-${++issued}',
    );
  });

  Response timeout() =>
      const Response(statusCode: 1, statusText: 'no internet');
  Response placed({bool replayed = false}) => Response(
    statusCode: 200,
    body: <String, dynamic>{'order_id': 42, 'replayed': replayed},
  );
  Response inProgress() => const Response(
    statusCode: 409,
    body: <String, dynamic>{
      'errors': <Map<String, String>>[
        <String, String>{'code': 'order_in_progress', 'message': 'wait'},
      ],
    },
  );
  Response rejected() => const Response(
    statusCode: 203,
    body: <String, dynamic>{
      'errors': <Map<String, String>>[
        <String, String>{'code': 'coupon', 'message': 'invalid'},
      ],
    },
  );

  Map<String, String> order({String coupon = '', String address = 'Maadi'}) =>
      <String, String>{
        'cart': '[{"item_id":1,"quantity":2}]',
        'coupon_code': coupon,
        'address': address,
        'payment_method': 'cash_on_delivery',
      };

  group('OrderAttemptKey', () {
    test('the same contents keep the same key', () {
      final String fp = OrderAttemptKey.fingerprintOf(order());
      expect(attempt.keyFor(fp), attempt.keyFor(fp));
      expect(issued, 1);
    });

    test('a changed cart, coupon or address rotates it', () {
      final String base = attempt.keyFor(
        OrderAttemptKey.fingerprintOf(order()),
      );

      final String cart = attempt.keyFor(
        OrderAttemptKey.fingerprintOf(<String, String>{
          ...order(),
          'cart': '[{"item_id":1,"quantity":3}]',
        }),
      );
      final String coupon = attempt.keyFor(
        OrderAttemptKey.fingerprintOf(order(coupon: 'SAVE10')),
      );
      final String address = attempt.keyFor(
        OrderAttemptKey.fingerprintOf(
          order(coupon: 'SAVE10', address: 'Zamalek'),
        ),
      );

      expect(<String>{base, cart, coupon, address}, hasLength(4));
    });

    test('going back to the old contents is still a new attempt', () {
      final String a = attempt.keyFor(OrderAttemptKey.fingerprintOf(order()));
      attempt.keyFor(OrderAttemptKey.fingerprintOf(order(coupon: 'X')));
      final String again = attempt.keyFor(
        OrderAttemptKey.fingerprintOf(order()),
      );
      expect(again, isNot(a));
    });

    test('a key older than 50 minutes is replaced', () {
      final String fp = OrderAttemptKey.fingerprintOf(order());
      final String first = attempt.keyFor(fp);

      clock = clock.add(const Duration(minutes: 49));
      expect(attempt.keyFor(fp), first);

      clock = clock.add(const Duration(minutes: 2)); // 51 minutes in
      expect(attempt.keyFor(fp), isNot(first));
    });

    test('clear() ends the attempt', () {
      final String fp = OrderAttemptKey.fingerprintOf(order());
      final String first = attempt.keyFor(fp);
      attempt.clear();
      expect(attempt.keyFor(fp), isNot(first));
    });

    test('field order, and the key fields themselves, do not matter', () {
      final String a = OrderAttemptKey.fingerprintOf(<String, String>{
        'a': '1',
        'b': '2',
      });
      final String b = OrderAttemptKey.fingerprintOf(<String, String>{
        'b': '2',
        'a': '1',
        'idempotency_key': 'old',
        'device_fingerprint': 'phone',
      });
      expect(a, b);
    });

    test('a different attachment is a different order', () {
      final String a = OrderAttemptKey.fingerprintOf(
        order(),
        attachments: <String>['/tmp/rx1.jpg'],
      );
      final String b = OrderAttemptKey.fingerprintOf(
        order(),
        attachments: <String>['/tmp/rx2.jpg'],
      );
      expect(a, isNot(b));
    });
  });

  group('sendOrderAttempt over a flaky network', () {
    test('a timeout then a retry sends the same key both times', () async {
      final List<String> sent = <String>[];
      final List<Response> replies = <Response>[
        timeout(),
        placed(replayed: true),
      ];

      Future<Response> send(String key) async {
        sent.add(key);
        return replies.removeAt(0);
      }

      final Response first = await sendOrderAttempt(
        attemptKey: attempt,
        fields: order(),
        send: send,
      );
      expect(first.statusCode, 1, reason: 'the customer sees a failure');

      final Response retry = await sendOrderAttempt(
        attemptKey: attempt,
        fields: order(),
        send: send,
      );

      expect(retry.statusCode, 200);
      expect(sent, <String>['key-1', 'key-1']);
    });

    test('changing the order between the two taps rotates the key', () async {
      final List<String> sent = <String>[];
      Future<Response> send(String key) async {
        sent.add(key);
        return timeout();
      }

      await sendOrderAttempt(attemptKey: attempt, fields: order(), send: send);
      await sendOrderAttempt(
        attemptKey: attempt,
        fields: order(coupon: 'SAVE10'),
        send: send,
      );

      expect(sent, <String>['key-1', 'key-2']);
    });

    test(
      'a success clears the key, so the next order gets a new one',
      () async {
        final List<String> sent = <String>[];
        Future<Response> send(String key) async {
          sent.add(key);
          return placed();
        }

        await sendOrderAttempt(
          attemptKey: attempt,
          fields: order(),
          send: send,
        );
        await sendOrderAttempt(
          attemptKey: attempt,
          fields: order(),
          send: send,
        );

        expect(sent, <String>['key-1', 'key-2']);
      },
    );

    test('a rejection keeps the key for the retry', () async {
      final List<String> sent = <String>[];
      final List<Response> replies = <Response>[rejected(), placed()];
      Future<Response> send(String key) async {
        sent.add(key);
        return replies.removeAt(0);
      }

      await sendOrderAttempt(attemptKey: attempt, fields: order(), send: send);
      await sendOrderAttempt(attemptKey: attempt, fields: order(), send: send);

      expect(sent, <String>['key-1', 'key-1']);
    });

    test('409 order_in_progress is waited out on the same key', () async {
      final List<String> sent = <String>[];
      final List<Response> replies = <Response>[
        inProgress(),
        inProgress(),
        placed(replayed: true),
      ];
      Future<Response> send(String key) async {
        sent.add(key);
        return replies.removeAt(0);
      }

      final Response result = await sendOrderAttempt(
        attemptKey: attempt,
        fields: order(),
        inProgressDelay: Duration.zero,
        send: send,
      );

      expect(result.statusCode, 200);
      expect(sent, <String>['key-1', 'key-1', 'key-1']);
    });

    test('a 409 that never clears is returned, not retried forever', () async {
      int calls = 0;
      final Response result = await sendOrderAttempt(
        attemptKey: attempt,
        fields: order(),
        inProgressRetries: 2,
        inProgressDelay: Duration.zero,
        send: (String key) async {
          calls++;
          return inProgress();
        },
      );

      expect(calls, 3, reason: 'one attempt plus two retries');
      expect(isOrderInProgress(result), isTrue);
    });

    test('other 409s are not mistaken for "in progress"', () {
      expect(
        isOrderInProgress(
          const Response(
            statusCode: 409,
            body: <String, dynamic>{
              'errors': <Map<String, String>>[
                <String, String>{'code': 'duplicate_order'},
              ],
            },
          ),
        ),
        isFalse,
      );
      expect(isOrderInProgress(const Response(statusCode: 409)), isFalse);
      expect(isOrderInProgress(timeout()), isFalse);
    });
  });

  group('with a real PlaceOrderBodyModel', () {
    PlaceOrderBodyModel body({String? coupon, String address = 'Maadi'}) =>
        PlaceOrderBodyModel(
          cart: <OnlineCart>[],
          couponDiscountAmount: 0,
          couponCode: coupon,
          orderAmount: 100,
          orderType: 'delivery',
          paymentMethod: 'cash_on_delivery',
          storeId: 3,
          distance: 2.5,
          discountAmount: 0,
          orderNote: '',
          address: address,
          receiverDetails: null,
          parcelCategoryId: null,
          chargePayer: null,
          dmTips: '0',
          unavailableItemNote: '',
          cutlery: 0,
          partialPayment: 0,
          guestId: 0,
          isBuyNow: 0,
          extraPackagingAmount: 0,
          createNewUser: 0,
          password: null,
        );

    String fp(PlaceOrderBodyModel b) =>
        OrderAttemptKey.fingerprintOf(b.toJson());

    test('setting the key and fingerprint does not change the attempt', () {
      final PlaceOrderBodyModel b = body();
      final String before = fp(b);
      b.idempotencyKey = 'k';
      b.deviceFingerprint = 'd' * 64;
      expect(fp(b), before);
    });

    test('a coupon or an address changes it', () {
      final String base = fp(body());
      expect(fp(body(coupon: 'SAVE10')), isNot(base));
      expect(fp(body(address: 'Zamalek')), isNot(base));
      expect(fp(body()), base);
    });
  });

  group('every order path sends a retry-stable key', () {
    String read(String path) => File(path).readAsStringSync();

    test('checkout (and offline pay), prescription and parcel use it', () {
      final String checkout = read(
        'lib/features/checkout/controllers/checkout_controller.dart',
      );
      // placeOrder (also the offline-payment path) and placePrescriptionOrder.
      expect('sendOrderAttempt('.allMatches(checkout).length, 2);
      expect(
        read('lib/features/parcel/controllers/parcel_controller.dart'),
        contains('sendOrderAttempt('),
      );
    });

    test('nothing mints a fresh key per tap any more', () {
      for (final FileSystemEntity f in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('order_attempt_key.dart')) continue;
        final String code = f.readAsStringSync();
        expect(
          code.contains('generateIdempotencyKey'),
          isFalse,
          reason: '${f.path} mints its own key',
        );
      }
    });
  });
}
