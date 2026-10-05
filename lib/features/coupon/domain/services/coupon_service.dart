import 'package:waddy_app/features/coupon/domain/models/coupon_apply_result.dart';
import 'package:waddy_app/features/coupon/domain/models/coupon_model.dart';
import 'package:waddy_app/features/coupon/domain/repositories/coupon_repository_interface.dart';
import 'package:waddy_app/features/coupon/domain/services/coupon_service_interface.dart';

class CouponService implements CouponServiceInterface {
  final CouponRepositoryInterface couponRepositoryInterface;
  CouponService({required this.couponRepositoryInterface});

  @override
  Future<List<CouponModel>?> getCouponList() async {
    return await couponRepositoryInterface.getList(couponList: true);
  }

  @override
  Future<CouponApplyResult> applyCoupon(String couponCode, int? storeID) async {
    return await couponRepositoryInterface.applyCoupon(couponCode, storeID);
  }
}
