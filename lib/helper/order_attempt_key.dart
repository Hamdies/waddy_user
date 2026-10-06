import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

/// The idempotency key of the order the customer is currently trying to place.
///
/// A key is only useful if a retry carries the SAME one. Generating a fresh key
/// per tap (what the app did) makes it worthless exactly when it matters: the
/// first request timed out, the order may well have been created, and the
/// customer taps again. The server answers a repeated key with the original
/// order; a new key is a new order.
///
/// So the key is held for as long as it is still the same attempt:
///
/// - **same contents** — the fingerprint of the request (cart, coupon,
///   address, payment method, notes, attachments…) is unchanged. Change any of
///   them and the customer is asking for a different order, so the key rotates.
/// - **recent enough** — [maxAge], 50 minutes by default. The server answers a
///   replay from the orders table, so it does not forget keys, but a key that
///   old belongs to an attempt the customer has long since walked away from.
/// - **not yet placed** — [clear] on success. The next order is a new one.
///
/// A rejected attempt (bad coupon, store closed) keeps its key: the server no
/// longer burns a key on rejection, so the corrected retry may reuse it, and if
/// the contents changed the fingerprint already rotates it.
class OrderAttemptKey {
  OrderAttemptKey({
    this.maxAge = const Duration(minutes: 50),
    DateTime Function()? now,
    String Function()? generate,
  }) : _now = now ?? DateTime.now,
       _generate = generate ?? (() => const Uuid().v4());

  final Duration maxAge;
  final DateTime Function() _now;
  final String Function() _generate;

  String? _key;
  String? _fingerprint;
  DateTime? _issuedAt;

  /// The key for an attempt with this [fingerprint]: the current one when it
  /// is still the same, recent attempt, a new one otherwise.
  String keyFor(String fingerprint) {
    final DateTime? issued = _issuedAt;
    final bool reusable =
        _key != null &&
        _fingerprint == fingerprint &&
        issued != null &&
        _now().difference(issued) < maxAge;
    if (!reusable) {
      _key = _generate();
      _fingerprint = fingerprint;
      _issuedAt = _now();
    }
    return _key!;
  }

  /// The order was placed (or confirmed as already placed): forget the key.
  void clear() {
    _key = null;
    _fingerprint = null;
    _issuedAt = null;
  }

  /// A stable fingerprint of an order request: [fields] without the keys that
  /// are not about its contents, plus anything uploaded with it.
  ///
  /// Sorted, so the same fields in a different order are the same order.
  static String fingerprintOf(
    Map<String, String> fields, {
    Iterable<String> attachments = const <String>[],
  }) {
    final List<String> names =
        fields.keys
            .where(
              (String k) => k != 'idempotency_key' && k != 'device_fingerprint',
            )
            .toList()
          ..sort();
    final StringBuffer out = StringBuffer();
    for (final String name in names) {
      out
        ..write(name)
        ..write('=')
        ..write(fields[name])
        ..write('\u0000');
    }
    for (final String path in attachments) {
      out
        ..write('file:')
        ..write(path)
        ..write('\u0000');
    }
    return out.toString();
  }
}

/// How the server answers a request for a key that is still being processed:
/// `409` with `errors[0].code == 'order_in_progress'`.
bool isOrderInProgress(Response response) {
  if (response.statusCode != 409) return false;
  final dynamic body = response.body;
  if (body is! Map) return false;
  final dynamic errors = body['errors'];
  return errors is List &&
      errors.isNotEmpty &&
      errors.first is Map &&
      (errors.first as Map)['code'] == 'order_in_progress';
}

/// Sends an order request under a retry-stable idempotency key.
///
/// [send] receives the key and performs the request. The same key goes out on
/// every attempt for the same contents, so:
///
/// - a request that timed out can simply be tapped again: if the order was
///   created the server replies 200 with that order (`replayed: true`), and the
///   customer lands on the success screen instead of a second order;
/// - a `409 order_in_progress` (the first request is still running) is waited
///   out here, a few times, rather than shown as an error.
///
/// A 200, replay or not, clears the key.
Future<Response> sendOrderAttempt({
  required OrderAttemptKey attemptKey,
  required Map<String, String> fields,
  required Future<Response> Function(String idempotencyKey) send,
  Iterable<String> attachments = const <String>[],
  int inProgressRetries = 3,
  Duration inProgressDelay = const Duration(seconds: 2),
}) async {
  final String key = attemptKey.keyFor(
    OrderAttemptKey.fingerprintOf(fields, attachments: attachments),
  );

  Response response = await send(key);
  for (int i = 0; i < inProgressRetries && isOrderInProgress(response); i++) {
    await Future<void>.delayed(inProgressDelay);
    response = await send(key);
  }

  if (response.statusCode == 200) attemptKey.clear();
  return response;
}

/// What to tell the customer when [response] is not a 200: the localized
/// "still being placed" line when the retries ran out on a `409`, otherwise the
/// server's own message.
String? orderFailureMessage(Response response) =>
    isOrderInProgress(response) ? 'order_in_progress'.tr : response.statusText;
