import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class CouponRepositoryInterface extends RepositoryInterface {
  @override
  Future getList({int? offset, bool couponList = false});
  Future<dynamic> applyCoupon(String couponCode, int? storeID);
}
