import 'package:waddy_app/features/coupon/domain/models/coupon_model.dart';

/// What the apply endpoint answered.
///
/// [errorCode] is set only for refusals the app words itself: the printed
/// scratch-card ones and the wrong-code lockout (docs/scratch_card_plan.md,
/// SC-06). Any other failure leaves both fields null, as before.
class CouponApplyResult {
  final CouponModel? coupon;
  final String? errorCode;

  /// For `card_limit`: the date (yyyy-MM-dd) the account can take a card again.
  final String? availableOn;

  const CouponApplyResult({this.coupon, this.errorCode, this.availableOn});

  /// The error codes that carry their own copy in the app.
  static const Set<String> worded = {
    'card_already_used',
    'card_expired',
    'card_not_active',
    'card_limit',
    'too_many_attempts',
  };
}
