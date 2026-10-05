import 'package:waddy_app/features/coupon/domain/models/coupon_apply_result.dart';
import 'package:waddy_app/features/coupon/domain/models/coupon_model.dart';

abstract class CouponServiceInterface {
  Future<List<CouponModel>?> getCouponList();
  Future<CouponApplyResult> applyCoupon(String couponCode, int? storeID);
}
