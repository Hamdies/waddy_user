import 'package:get/get.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:waddy_app/api/api_checker.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/coupon/domain/models/coupon_apply_result.dart';
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

  /// Unhandled, so a scratch-card refusal's `code` reaches the promo card
  /// instead of collapsing into "invalid". Every other failure goes through
  /// [ApiChecker] as before (the 401 sweep, no toast).
  @override
  Future<CouponApplyResult> applyCoupon(String couponCode, int? storeID) async {
    Response response = await apiClient.getData(
      '${AppConstants.couponApplyUri}${Uri.encodeQueryComponent(couponCode)}'
      '&store_id=$storeID',
      handleError: false,
    );
    if (response.statusCode == 200) {
      return CouponApplyResult(coupon: CouponModel.fromJson(response.body));
    }
    final dynamic body = response.body;
    if (body is Map && body['errors'] is List && body['errors'].isNotEmpty) {
      final dynamic error = body['errors'][0];
      if (error is Map && CouponApplyResult.worded.contains(error['code'])) {
        return CouponApplyResult(
          errorCode: error['code'],
          availableOn: error['available_on']?.toString(),
        );
      }
    }
    ApiChecker.checkApi(response);
    return const CouponApplyResult();
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
