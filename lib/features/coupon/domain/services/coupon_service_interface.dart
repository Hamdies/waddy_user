import 'package:waddy_app/features/coupon/domain/models/coupon_model.dart';

abstract class CouponServiceInterface {
  Future<List<CouponModel>?> getCouponList();
  Future<CouponModel?> applyCoupon(String couponCode, int? storeID);
}
