import 'package:get/get.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/coupon/domain/models/coupon_model.dart';
import 'package:waddy_app/features/coupon/domain/repositories/coupon_repository_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

class CouponRepository implements CouponRepositoryInterface {
  final ApiClient apiClient;
  CouponRepository({required this.apiClient});

  @override
  Future getList({int? offset, bool couponList = false}) async {
    if (couponList) {
      return await _getCouponList();
    }
  }

  Future<List<CouponModel>?> _getCouponList() async {
    List<CouponModel>? couponList;
    Response response = await apiClient.getData(AppConstants.couponUri);
    if (response.statusCode == 200) {
      couponList = [];
      response.body.forEach((category) {
        CouponModel coupon = CouponModel.fromJson(category);
        coupon.toolTip = JustTheController();
        couponList!.add(coupon);
      });
    }
    return couponList;
  }

  @override
  Future<CouponModel?> applyCoupon(String couponCode, int? storeID) async {
    CouponModel? couponModel;
    Response response = await apiClient.getData(
      '${AppConstants.couponApplyUri}$couponCode&store_id=$storeID',
    );
    if (response.statusCode == 200) {
      couponModel = CouponModel.fromJson(response.body);
    }
    return couponModel;
  }

  @override
  @override
  Future add(value) {
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    throw UnimplementedError();
  }

  @override
  Future get(String? id) {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int? id) {
    throw UnimplementedError();
  }
}
