import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Provides security measures to protect against fake/fraudulent orders.
///
/// - Rate limiting: prevents rapid-fire order submissions
/// - Idempotency key: prevents duplicate order submissions (server-enforced)
/// - Device fingerprint: fraud telemetry, not a control
///
/// There is deliberately no client-generated order signature. A client cannot
/// hold a signing secret — whatever the app can use to sign, an attacker who
/// unpacks the APK can use to forge. The previous HMAC also only produced a
/// log line server-side and never blocked an order, so it advertised a
/// protection that did not exist. Tamper-resistance for order amounts comes
/// from the server recomputing `order_amount` itself; a future tamper-evidence
/// scheme would have to be server-issued (server signs a short-lived quote
/// token, client echoes it back).
class OrderSecurityHelper {
  static final OrderSecurityHelper _instance = OrderSecurityHelper._internal();
  factory OrderSecurityHelper() => _instance;
  OrderSecurityHelper._internal();

  static const _minOrderIntervalSeconds = 30;

  DateTime? _lastOrderTime;
  String? _lastIdempotencyKey;
  String? _cachedDeviceFingerprint;

  /// Check if enough time has passed since the last order.
  bool canPlaceOrder() {
    if (_lastOrderTime == null) return true;
    final elapsed = DateTime.now().difference(_lastOrderTime!).inSeconds;
    return elapsed >= _minOrderIntervalSeconds;
  }

  /// Returns seconds remaining before next order can be placed.
  int secondsUntilNextOrder() {
    if (_lastOrderTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastOrderTime!).inSeconds;
    final remaining = _minOrderIntervalSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Record that an order was just placed.
  void recordOrderPlaced() {
    _lastOrderTime = DateTime.now();
  }

  /// Generate a unique idempotency key for this order attempt.
  String generateIdempotencyKey() {
    _lastIdempotencyKey = const Uuid().v4();
    return _lastIdempotencyKey!;
  }

  /// Get the last generated idempotency key.
  String? get lastIdempotencyKey => _lastIdempotencyKey;

  /// Get or compute a device fingerprint for fraud detection.
  String getDeviceFingerprint() {
    if (_cachedDeviceFingerprint != null) return _cachedDeviceFingerprint!;

    String rawFingerprint;
    try {
      if (Platform.isAndroid) {
        rawFingerprint =
            'android_${Platform.operatingSystemVersion}_${Platform.localHostname}';
      } else if (Platform.isIOS) {
        rawFingerprint =
            'ios_${Platform.operatingSystemVersion}_${Platform.localHostname}';
      } else {
        rawFingerprint =
            '${Platform.operatingSystem}_${Platform.operatingSystemVersion}';
      }
    } catch (e) {
      rawFingerprint = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }

    final hash = sha256.convert(utf8.encode(rawFingerprint));
    _cachedDeviceFingerprint = hash.toString();
    return _cachedDeviceFingerprint!;
  }

  /// Validate order data integrity before submission.
  /// Returns null if valid, or an error message string.
  String? validateOrderIntegrity({
    required double orderAmount,
    required String? token,
  }) {
    if (token == null || token.isEmpty) {
      return 'Authentication required to place orders';
    }
    if (orderAmount <= 0) {
      return 'Invalid order amount';
    }
    if (!canPlaceOrder()) {
      return 'Please wait ${secondsUntilNextOrder()} seconds before placing another order';
    }
    return null;
  }
}
