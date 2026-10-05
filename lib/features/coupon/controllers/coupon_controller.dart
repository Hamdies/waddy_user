import 'package:waddy_app/features/coupon/domain/models/coupon_apply_result.dart';
import 'package:waddy_app/features/coupon/domain/models/coupon_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/coupon/domain/services/coupon_service_interface.dart';

class CouponController extends GetxController implements GetxService {
  final CouponServiceInterface couponServiceInterface;
  CouponController({required this.couponServiceInterface});

  List<CouponModel>? _couponList;
  List<CouponModel>? get couponList => _couponList;

  CouponModel? _coupon;
  CouponModel? get coupon => _coupon;

  double? _discount = 0.0;
  double? get discount => _discount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _freeDelivery = false;
  bool get freeDelivery => _freeDelivery;

  /// Why the last apply was refused, when the app has its own words for it
  /// (a scratch-card refusal or the wrong-code lockout). Null otherwise.
  String? _errorCode;
  String? get errorCode => _errorCode;
  String? _errorAvailableOn;
  String? get errorAvailableOn => _errorAvailableOn;

  /// The store the current coupon was applied against, and the order amount
  /// its discount was worked out on. The coupon now outlives one screen — it
  /// can be applied on the cart and carried into checkout — so both are kept
  /// to tell when it has gone stale: a different store's basket, or the same
  /// basket at a different total.
  int? _appliedStoreId;
  double? _appliedOrder;

  /// True when a coupon is in and doing something — a discount or free
  /// delivery. A coupon that failed its minimum sits in [coupon] with a zero
  /// discount, which is not "applied".
  bool get hasAppliedCoupon =>
      _coupon != null && ((_discount ?? 0) > 0 || _freeDelivery);

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  void setCurrentIndex(int index, bool notify) {
    _currentIndex = index;
    if (notify) {
      update();
    }
  }

  Future<void> getCouponList() async {
    List<CouponModel>? couponList =
        await couponServiceInterface.getCouponList();
    if (couponList != null) {
      _couponList = [];
      _couponList!.addAll(couponList);
    }
    update();
  }

  Future<double?> applyCoupon(
    String coupon,
    double order,
    double? deliveryCharge,
    int? storeID,
  ) async {
    _isLoading = true;
    _discount = 0;
    _errorCode = null;
    _errorAvailableOn = null;
    update();
    final CouponApplyResult result = await couponServiceInterface.applyCoupon(
      coupon,
      storeID,
    );
    _errorCode = result.errorCode;
    _errorAvailableOn = result.availableOn;
    final CouponModel? couponModel = result.coupon;
    if (couponModel != null) {
      _coupon = couponModel;
      _appliedStoreId = storeID;
      _appliedOrder = order;
      if (_coupon!.couponType == 'free_delivery') {
        _processFreeDeliveryCoupon(deliveryCharge!, order);
      } else {
        _processCoupon(order);
      }
    } else {
      _discount = 0.0;
    }
    _isLoading = false;
    update();
    return _discount;
  }

  _processFreeDeliveryCoupon(double deliveryCharge, double order) {
    if (deliveryCharge > 0) {
      if (_coupon!.minPurchase! <= order) {
        _discount = 0;
        _freeDelivery = true;
      } else {
        showCustomSnackBar(
          '${'the_minimum_item_purchase_amount_for_this_coupon_is'.tr} '
          '${PriceConverter.convertPrice(_coupon!.minPurchase)} '
          '${'but_you_have'.tr} ${PriceConverter.convertPrice(order)}',
        );
        _coupon = null;
        _discount = 0;
      }
    } else {
      showCustomSnackBar('invalid_code_or'.tr);
    }
  }

  _processCoupon(double order) {
    if (_coupon!.minPurchase != null && _coupon!.minPurchase! <= order) {
      if (_coupon!.discountType == 'percent') {
        if (_coupon!.maxDiscount != null && _coupon!.maxDiscount! > 0) {
          _discount =
              (_coupon!.discount! * order / 100) < _coupon!.maxDiscount!
                  ? (_coupon!.discount! * order / 100)
                  : _coupon!.maxDiscount;
        } else {
          _discount = _coupon!.discount! * order / 100;
        }
      } else {
        _discount = _coupon!.discount;
      }
    } else {
      _discount = 0.0;
      showCustomSnackBar(
        '${'the_minimum_item_purchase_amount_for_this_coupon_is'.tr} '
        '${PriceConverter.convertPrice(_coupon!.minPurchase)} '
        '${'but_you_have'.tr} ${PriceConverter.convertPrice(order)}',
      );
    }
  }

  /// Clears the coupon unless it was applied to [storeId]'s basket.
  ///
  /// Checkout used to clear unconditionally on open, which threw away a code
  /// the user had just applied on the cart one tap earlier.
  void keepOnlyFor(int? storeId, {bool notify = false}) {
    if (_coupon != null && storeId != null && _appliedStoreId == storeId) {
      return;
    }
    removeCouponData(notify);
  }

  /// Re-works the applied coupon's discount for a new order amount, without
  /// a network call.
  ///
  /// The discount is computed once, at apply time, off the basket as it was.
  /// Changing a quantity on the cart afterwards left a percent coupon showing
  /// (and sending) the old figure. A coupon whose minimum the basket no longer
  /// meets is removed outright, with the same message apply would have shown,
  /// rather than lingering as a code worth nothing.
  void refreshForOrder(double order) {
    if (_coupon == null || _appliedOrder == order) return;
    _appliedOrder = order;
    if ((_coupon!.minPurchase ?? 0) > order) {
      showCustomSnackBar(
        '${'the_minimum_item_purchase_amount_for_this_coupon_is'.tr} '
        '${PriceConverter.convertPrice(_coupon!.minPurchase)} '
        '${'but_you_have'.tr} ${PriceConverter.convertPrice(order)}',
      );
      removeCouponData(true);
      return;
    }
    if (!_freeDelivery) _processCoupon(order);
    update();
  }

  void removeCouponData(bool notify) {
    _coupon = null;
    _appliedStoreId = null;
    _appliedOrder = null;
    _isLoading = false;
    _discount = 0.0;
    _freeDelivery = false;
    _errorCode = null;
    _errorAvailableOn = null;
    if (notify) {
      update();
    }
  }
}
