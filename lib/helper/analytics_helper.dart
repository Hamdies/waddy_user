import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Funnel analytics for the browse-first onboarding flow. Every call is
/// fire-and-forget and swallow-safe: analytics must never break a user flow.
///
/// Commerce events additionally fan out to Meta (facebook_app_events) so ad
/// campaigns can optimize on registrations, carts and purchases. Add TikTok
/// here later — call sites stay single-call.
class AnalyticsHelper {
  AnalyticsHelper._();

  static final FacebookAppEvents _fb = FacebookAppEvents();

  /// The app operates in Egypt only; Meta wants an ISO currency code and the
  /// backend config only exposes a display symbol.
  static const String _currency = 'EGP';

  static Future<void> log(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {}
  }

  /// For failures we also want visible in Crashlytics (e.g. cart sync).
  static Future<void> logError(
    String name,
    Object error, [
    StackTrace? stack,
  ]) async {
    try {
      await FirebaseAnalytics.instance.logEvent(name: name);
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: name,
      );
    } catch (_) {}
  }

  static Future<void> logCompleteRegistration({String? method}) async {
    try {
      await FirebaseAnalytics.instance.logSignUp(
        signUpMethod: method ?? 'phone',
      );
    } catch (_) {}
    try {
      await _fb.logCompletedRegistration(registrationMethod: method ?? 'phone');
    } catch (_) {}
  }

  static Future<void> logAddToCart({
    required int? itemId,
    required String? itemName,
    required double price,
    int quantity = 1,
  }) async {
    try {
      await FirebaseAnalytics.instance.logAddToCart(
        currency: _currency,
        value: price * quantity,
        items: [
          AnalyticsEventItem(
            itemId: itemId?.toString(),
            itemName: itemName,
            price: price,
            quantity: quantity,
          ),
        ],
      );
    } catch (_) {}
    try {
      await _fb.logAddToCart(
        id: itemId?.toString() ?? '',
        type: 'product',
        currency: _currency,
        price: price * quantity,
      );
    } catch (_) {}
  }

  static Future<void> logInitiateCheckout({
    required double total,
    required int itemCount,
  }) async {
    try {
      await FirebaseAnalytics.instance.logBeginCheckout(
        currency: _currency,
        value: total,
      );
    } catch (_) {}
    try {
      await _fb.logInitiatedCheckout(
        totalPrice: total,
        currency: _currency,
        numItems: itemCount,
      );
    } catch (_) {}
  }

  /// The conversion Meta optimizes on. `order_id` rides along so the
  /// Conversions API purchase (Phase 2, server-side) can be deduplicated
  /// against this event.
  static Future<void> logPurchase({
    required double amount,
    required String? orderId,
  }) async {
    try {
      await FirebaseAnalytics.instance.logPurchase(
        currency: _currency,
        value: amount,
        transactionId: orderId,
      );
    } catch (_) {}
    try {
      // _eventId must mirror the Conversions API event_id
      // ("purchase_{order_id}") so Meta deduplicates the two sources.
      await _fb.logPurchase(
        amount: amount,
        currency: _currency,
        parameters:
            orderId != null
                ? {'order_id': orderId, '_eventId': 'purchase_$orderId'}
                : null,
      );
    } catch (_) {}
  }
}
