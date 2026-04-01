import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Provides security measures to protect against fake/fraudulent orders.
///
/// - Rate limiting: prevents rapid-fire order submissions
/// - Idempotency key: prevents duplicate order submissions
/// - Device fingerprint: ties orders to a specific device
/// - Order signature: HMAC signature to detect tampering
class OrderSecurityHelper {
  static final OrderSecurityHelper _instance = OrderSecurityHelper._internal();
  factory OrderSecurityHelper() => _instance;
  OrderSecurityHelper._internal();

  static const _minOrderIntervalSeconds = 30;
  static const _orderSignatureSecret = 'waddi_order_sec_2026';

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

  /// Generate HMAC-SHA256 signature for order data to detect tampering.
  String generateOrderSignature(Map<String, dynamic> orderData) {
    final sortedKeys = orderData.keys.toList()..sort();
    final dataString = sortedKeys
        .where((k) => orderData[k] != null)
        .map((k) => '$k=${orderData[k]}')
        .join('&');
    final hmac = Hmac(sha256, utf8.encode(_orderSignatureSecret));
    final digest = hmac.convert(utf8.encode(dataString));
    return digest.toString();
  }

  /// Get or compute a device fingerprint for fraud detection.
  String getDeviceFingerprint() {
    if (_cachedDeviceFingerprint != null) return _cachedDeviceFingerprint!;

    String rawFingerprint;
    try {
      if (Platform.isAndroid) {
        rawFingerprint = 'android_${Platform.operatingSystemVersion}_${Platform.localHostname}';
      } else if (Platform.isIOS) {
        rawFingerprint = 'ios_${Platform.operatingSystemVersion}_${Platform.localHostname}';
      } else {
        rawFingerprint = '${Platform.operatingSystem}_${Platform.operatingSystemVersion}';
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
