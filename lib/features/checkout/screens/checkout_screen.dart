import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:waddy_app/common/widgets/address_widget.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/checkout/domain/models/place_order_body_model.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_dropdown.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/common/widgets/not_logged_in_screen.dart';
import 'package:waddy_app/helper/guest_gate_helper.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_screen_shimmer_view.dart';
import 'package:waddy_app/features/checkout/widgets/payment_method_bottom_sheet.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/checkout/widgets/bottom_section.dart';
import 'package:waddy_app/features/checkout/widgets/top_section.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:flutter/material.dart';
import 'package:waddy_app/features/checkout/domain/models/checkout_pricing.dart';
import 'package:waddy_app/features/checkout/helpers/checkout_calculation_helper.dart';
import 'package:waddy_app/features/checkout/helpers/order_payload_builder.dart';
import 'package:waddy_app/theme/light_theme.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartModel?>? cartList;
  final bool fromCart;
  final int? storeId;
  const CheckoutScreen({
    super.key,
    required this.fromCart,
    required this.cartList,
    required this.storeId,
  });

  @override
  CheckoutScreenState createState() => CheckoutScreenState();
}

class CheckoutScreenState extends State<CheckoutScreen> {
  final ScrollController _scrollController = ScrollController();
  final JustTheController tooltipController1 = JustTheController();
  final JustTheController tooltipController2 = JustTheController();
  final JustTheController tooltipController3 = JustTheController();

  // CS-01, partially open. The pricing that used to be computed in `build()`
  // is a `CheckoutPricing` snapshot now, and the three tooltip fields that
  // went with it are locals. These four remain State because, unlike those,
  // they are genuinely read outside the `build()` that writes them —
  // `_setSinglePaymentActive` and the place-order handler both consult them.
  //
  // Making them locals means threading four more values through
  // `_buildBottomPlaceOrderButton` and `_orderPlaceButton`, which already take
  // eleven positional parameters each. They belong on `CheckoutController`
  // with the rest of the order's options; that is Phase 5's shape, not a
  // by-product of the pricing move.
  double? _taxPercent = 0;
  bool? _isCashOnDeliveryActive = false;
  bool? _isDigitalPaymentActive = false;
  bool _isOfflinePaymentActive = false;
  List<CartModel?>? _cartList;
  bool _isWalletActive = false;
  String _deliveryChargeForView = '';

  List<AddressModel> address = [];
  bool canCheckSmall = false;
  double? _payableAmount = 0;

  final CheckoutCalculationHelper _calcHelper = CheckoutCalculationHelper();

  final TextEditingController guestContactPersonNameController =
      TextEditingController();
  final TextEditingController guestContactPersonNumberController =
      TextEditingController();
  final TextEditingController guestEmailController = TextEditingController();
  final TextEditingController guestPasswordController = TextEditingController();
  final TextEditingController guestConfirmPasswordController =
      TextEditingController();
  final FocusNode guestNumberNode = FocusNode();
  final FocusNode guestEmailNode = FocusNode();
  final FocusNode guestPasswordNode = FocusNode();
  final FocusNode guestConfirmPasswordNode = FocusNode();

  bool _firstTimeCheckPayment = false;
  bool _calledOrderTax = false;
  bool _authPromptLogged = false;

  @override
  void initState() {
    super.initState();

    initCall();
  }

  Future<void> initCall() async {
    bool isLoggedIn = AuthHelper.isLoggedIn();
    Get.find<CheckoutController>().resetOrderTax();
    Get.find<CheckoutController>().initAdditionData();
    Get.find<CheckoutController>().streetNumberController.text =
        AddressHelper.getUserAddressFromSharedPref()?.streetNumber ?? '';
    Get.find<CheckoutController>().houseController.text =
        AddressHelper.getUserAddressFromSharedPref()?.house ?? '';
    Get.find<CheckoutController>().floorController.text =
        AddressHelper.getUserAddressFromSharedPref()?.floor ?? '';
    Get.find<CheckoutController>().couponController.text = '';

    Get.find<CheckoutController>().clearPrevData();
    Get.find<CheckoutController>().getDmTipMostTapped();
    Get.find<CheckoutController>().setPreferenceTimeForView(
      '',
      isUpdate: false,
    );

    Get.find<CheckoutController>().getOfflineMethodList();

    if (Get.find<CheckoutController>().isCreateAccount) {
      Get.find<CheckoutController>().toggleCreateAccount(willUpdate: false);
    }

    if (Get.find<CheckoutController>().isPartialPay) {
      Get.find<CheckoutController>().changePartialPayment(isUpdate: false);
    }

    if (isLoggedIn) {
      if (Get.find<ProfileController>().userInfoModel == null) {
        Get.find<ProfileController>().getUserInfo();
      }

      Get.find<CouponController>().getCouponList();

      if (Get.find<AddressController>().addressList == null) {
        Get.find<AddressController>().getAddressList();
      }
    }

    if (widget.storeId == null) {
      _cartList = [];
      widget.fromCart
          ? _cartList!.addAll(Get.find<CartController>().cartList)
          : _cartList!.addAll(widget.cartList!);
      if (_cartList != null && _cartList!.isNotEmpty) {
        Get.find<CheckoutController>().initCheckoutData(
          _cartList![0]!.item!.storeId,
        );
      }
    }
    if (widget.storeId != null) {
      Get.find<CheckoutController>().initCheckoutData(widget.storeId);
      Get.find<CouponController>().removeCouponData(false);
    }
    Get.find<CheckoutController>().pickPrescriptionImage(
      isRemove: true,
      isCamera: false,
    );
    _isWalletActive =
        Get.find<SplashController>().configModel.customerWalletStatus == 1;
    Get.find<CheckoutController>().updateTips(
      Get.find<CheckoutController>().getSharedPrefDmTipIndex().isNotEmpty
          ? int.parse(Get.find<CheckoutController>().getSharedPrefDmTipIndex())
          : 0,
      notify: false,
    );
    Get.find<CheckoutController>().tipController.text =
        Get.find<CheckoutController>().selectedTips != -1
            ? AppConstants.tips[Get.find<CheckoutController>().selectedTips]
            : '';

    if (_cartList != null && _cartList!.isNotEmpty) {
      double checkoutTotal = 0;
      for (CartModel? cart in _cartList!) {
        checkoutTotal +=
            (cart?.discountedPrice ?? cart?.price ?? 0) * (cart?.quantity ?? 1);
      }
      AnalyticsHelper.logInitiateCheckout(
        total: checkoutTotal,
        itemCount: _cartList!.length,
      );
    }
  }

  void _setSinglePaymentActive() {
    if ((!_firstTimeCheckPayment &&
            !_isCashOnDeliveryActive! &&
            _isDigitalPaymentActive! &&
            Get.find<SplashController>()
                    .configModel
                    .activePaymentMethodList!
                    .length ==
                1) &&
        ((!_isWalletActive && AuthHelper.isLoggedIn()) ||
            !AuthHelper.isLoggedIn())) {
      Future.delayed(const Duration(milliseconds: 600), () {
        Get.find<CheckoutController>().setPaymentMethod(2, isUpdate: false);
        Get.find<CheckoutController>().changeDigitalPaymentName(
          Get.find<SplashController>()
              .configModel
              .activePaymentMethodList![0]
              .getWay!,
          willUpdate: false,
        );
        _firstTimeCheckPayment = true;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();

    guestContactPersonNameController.dispose();
    guestContactPersonNumberController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Module? module =
        Get.find<SplashController>().configModel.moduleConfig!.module;
    bool isLoggedIn = AuthHelper.isLoggedIn();

    final Color primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: WaddyColors.canvas,
      appBar: AppBar(
        backgroundColor: WaddyColors.surface,
        elevation: 0.5,
        surfaceTintColor: WaddyColors.surface,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            size: 20,
            color: primaryColor,
          ),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
        title: Text(
          'checkout'.tr,
          style: waddyBold.copyWith(fontSize: 18, color: WaddyColors.ink),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: WaddyColors.divider),
        ),
      ),
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body:
          AuthHelper.isLoggedIn()
              ? GetBuilder<CheckoutController>(
                builder: (checkoutController) {
                  List<DropdownItem<int>> addressList = _getDropdownAddressList(
                    context: context,
                    addressList: Get.find<AddressController>().addressList,
                    store: checkoutController.store,
                  );
                  address = _getAddressList(
                    addressList: Get.find<AddressController>().addressList,
                    store: checkoutController.store,
                  );

                  bool todayClosed = false;
                  bool tomorrowClosed = false;
                  Pivot? moduleData = _calcHelper.getModuleData(
                    store: checkoutController.store,
                  );
                  _isCashOnDeliveryActive = _calcHelper.checkCODActive(
                    store: checkoutController.store,
                  );
                  _isDigitalPaymentActive = _calcHelper
                      .checkDigitalPaymentActive(
                        store: checkoutController.store,
                      );
                  _isOfflinePaymentActive =
                      Get.find<SplashController>()
                          .configModel
                          .offlinePaymentStatus! &&
                      _calcHelper.checkZoneOfflinePaymentOnOff(
                        addressModel:
                            AddressHelper.getUserAddressFromSharedPref(),
                        checkoutController: checkoutController,
                      );
                  if (checkoutController.store != null) {
                    todayClosed = checkoutController.isStoreClosed(
                      true,
                      checkoutController.store!.active!,
                      checkoutController.store!.schedules,
                    );
                    tomorrowClosed = checkoutController.isStoreClosed(
                      false,
                      checkoutController.store!.active!,
                      checkoutController.store!.schedules,
                    );
                    _taxPercent = checkoutController.store!.tax;
                  }
                  // Reads nothing off `xpController` directly, but the
                  // pricing below calls `_calcHelper.calculatePrice`, which
                  // resolves `selectedCheckoutPrize` through `Get.find` —
                  // so the total is only correct if this tree repaints when
                  // the selection changes. Scoped to that and nothing else.
                  return GetBuilder<XpController>(
                    id: XpController.idCheckoutPrizes,
                    builder: (xpController) {
                      return GetBuilder<CouponController>(
                        builder: (couponController) {
                          double? maxCodOrderAmount;

                          if (moduleData != null) {
                            maxCodOrderAmount =
                                moduleData.maximumCodOrderAmount;
                          }
                          // CS-01 / CS-09: the fourteen chained calculations
                          // that used to run here — each feeding the next, and
                          // writing their intermediates back onto State — are
                          // one immutable snapshot now. `build()` formats
                          // these numbers; it no longer produces them.
                          //
                          // The locals below are kept so the ~40 places that
                          // read them downstream still read a name, not a
                          // field chain.
                          final double additionalCharge =
                              Get.find<SplashController>()
                                      .configModel
                                      .additionalChargeStatus!
                                  ? Get.find<SplashController>()
                                      .configModel
                                      .additionCharge!
                                  : 0;
                          final double extraPackagingCharge =
                              widget.storeId != null
                                  ? 0
                                  : _calcHelper.calculateExtraPackagingCharge(
                                    checkoutController,
                                  );

                          final CheckoutPricing
                          pricing = CheckoutPricing.calculate(
                            helper: _calcHelper,
                            store: checkoutController.store,
                            cartList: _cartList,
                            address:
                                AddressHelper.getUserAddressFromSharedPref()!,
                            distance: checkoutController.distance,
                            extraCharge: checkoutController.extraCharge,
                            orderType: checkoutController.orderType!,
                            couponDiscount: PriceConverter.toFixed(
                              couponController.discount!,
                            ),
                            tips: checkoutController.tips,
                            additionalCharge: additionalCharge,
                            extraPackagingCharge: extraPackagingCharge,
                            taxIncluded: checkoutController.taxIncluded == 1,
                            tax: checkoutController.orderTax!,
                            surgePrice: checkoutController.surgePrice?.price,
                            surgePriceType:
                                checkoutController.surgePrice?.priceType,
                          );

                          final double price = pricing.price;
                          final double addOns = pricing.addOns;
                          final double variations = pricing.variations;
                          final double extraDiscount = pricing.extraDiscount;
                          final double discount = pricing.discount;
                          final double subTotal = pricing.subTotal;
                          final double referralDiscount =
                              pricing.referralDiscount;
                          final double orderAmount = pricing.orderAmount;

                          // Deferred out of the build phase, not delayed.
                          // This was `Future.delayed(50ms)` — enough to get a
                          // network call out of `build()`, but an arbitrary
                          // wait on top of a screen that is already gated
                          // behind the store fetch. A post-frame callback runs
                          // as soon as this frame is painted, which is the
                          // earliest it is safe to start.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (checkoutController.isFirstTime ||
                                (couponController.discount! > 0 &&
                                    !checkoutController.isFirstTime &&
                                    !_calledOrderTax)) {
                              if (couponController.discount! > 0) {
                                _calledOrderTax = true;
                              }
                              List<OnlineCart> carts = [];

                              if (widget.storeId == null) {
                                carts = OrderPayloadBuilder.buildCartLines(
                                  cartList: _cartList,
                                  isCampaign: !widget.fromCart,
                                );
                              }
                              PlaceOrderBodyModel
                              placeOrderBody = PlaceOrderBodyModel(
                                cart: carts,
                                couponDiscountAmount:
                                    Get.find<CouponController>().discount,
                                distance: checkoutController.distance,
                                orderAmount:
                                    widget.storeId == null ? subTotal : 0,
                                orderNote:
                                    checkoutController.noteController.text,
                                orderType: checkoutController.orderType,
                                paymentMethod:
                                    checkoutController.paymentMethodIndex == 0
                                        ? 'cash_on_delivery'
                                        : checkoutController
                                                .paymentMethodIndex ==
                                            1
                                        ? 'wallet'
                                        : checkoutController
                                                .paymentMethodIndex ==
                                            2
                                        ? 'digital_payment'
                                        : 'offline_payment',
                                couponCode:
                                    (Get.find<CouponController>().discount! >
                                                0 ||
                                            (Get.find<CouponController>()
                                                        .coupon !=
                                                    null &&
                                                Get.find<CouponController>()
                                                    .freeDelivery))
                                        ? Get.find<CouponController>()
                                            .coupon!
                                            .code
                                        : null,
                                storeId:
                                    (widget.storeId == null)
                                        ? _cartList![0]!.item!.storeId
                                        : widget.storeId,
                                discountAmount: discount,
                                receiverDetails: null,
                                parcelCategoryId: null,
                                chargePayer: null,
                                dmTips:
                                    (checkoutController.orderType ==
                                                'take_away' ||
                                            checkoutController
                                                    .tipController
                                                    .text ==
                                                'not_now')
                                        ? ''
                                        : checkoutController.tipController.text
                                            .trim(),
                                cutlery:
                                    Get.find<CartController>().addCutlery
                                        ? 1
                                        : 0,
                                unavailableItemNote:
                                    Get.find<CartController>()
                                                .notAvailableIndex !=
                                            -1
                                        ? Get.find<CartController>()
                                            .notAvailableList[Get.find<
                                              CartController
                                            >()
                                            .notAvailableIndex]
                                        : '',
                                deliveryInstruction:
                                    checkoutController
                                        .getSelectedInstructionsText(),
                                partialPayment:
                                    checkoutController.isPartialPay ? 1 : 0,
                                guestId: 0,
                                isBuyNow: widget.fromCart ? 0 : 1,
                                extraPackagingAmount:
                                    Get.find<CartController>()
                                                .needExtraPackage &&
                                            checkoutController.store != null
                                        ? checkoutController
                                            .store!
                                            .extraPackagingAmount
                                        : 0,
                                createNewUser: 0,
                                password: '',
                                isPrescriptionOrder:
                                    widget.storeId == null ? false : true,
                                usePrizeId:
                                    Get.find<XpController>()
                                        .selectedCheckoutPrize
                                        ?.id,
                              );

                              checkoutController.getOrderTax(placeOrderBody);
                            }
                          });

                          final double originalCharge =
                              pricing.originalDeliveryCharge;
                          final double deliveryCharge = pricing.deliveryCharge;
                          // CS-01 / CS-09: locals, not State. These were three
                          // fields written from `build()` and read a few lines
                          // later in the same `build()` — never across frames —
                          // so the field was only ever a way to carry a value
                          // down the widget tree without naming it.
                          final double badWeatherChargeForToolTip =
                              pricing.badWeatherChargeForToolTip;
                          final double extraChargeForToolTip =
                              pricing.extraChargeForToolTip;
                          final bool isPassedVariationPrice =
                              pricing.isPassedVariationPrice;

                          if (checkoutController.orderType != 'take_away' &&
                              checkoutController.store != null) {
                            _deliveryChargeForView =
                                (checkoutController.orderType == 'delivery'
                                            ? checkoutController
                                                .store!
                                                .freeDelivery!
                                            : true) ||
                                        deliveryCharge == 0
                                    ? 'free'.tr
                                    : deliveryCharge != -1
                                    ? PriceConverter.convertPrice(
                                      deliveryCharge,
                                    )
                                    : 'calculating'.tr;
                          }

                          // Already net of the referral discount.
                          final double total = pricing.total;

                          bool isPrescriptionRequired =
                              _checkPrescriptionRequired();

                          if (widget.storeId != null) {
                            checkoutController.setPaymentMethod(
                              0,
                              isUpdate: false,
                            );
                          }
                          checkoutController.setTotalAmount(
                            total -
                                (checkoutController.isPartialPay
                                    ? Get.find<ProfileController>()
                                        .userInfoModel!
                                        .walletBalance!
                                    : 0),
                          );

                          if (_payableAmount !=
                                  checkoutController.viewTotalPrice &&
                              checkoutController.distance != null &&
                              isLoggedIn) {
                            _payableAmount = checkoutController.viewTotalPrice;
                            showCashBackSnackBar();
                          }

                          _setSinglePaymentActive();

                          return (checkoutController.distance != null &&
                                  checkoutController.store != null)
                              ? Column(
                                children: [
                                  const SizedBox(),

                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      physics: const BouncingScrollPhysics(),
                                      child: FooterView(
                                        child: SizedBox(
                                          width: Dimensions.maxContentWidth,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              TopSection(
                                                checkoutController:
                                                    checkoutController,
                                                charge: originalCharge,
                                                deliveryCharge: deliveryCharge,
                                                addressList: addressList,
                                                tomorrowClosed: tomorrowClosed,
                                                todayClosed: todayClosed,
                                                module: module,
                                                price: price,
                                                discount: discount,
                                                addOns: addOns,
                                                address: address,
                                                cartList: _cartList,
                                                isCashOnDeliveryActive:
                                                    _isCashOnDeliveryActive!,
                                                isDigitalPaymentActive:
                                                    _isDigitalPaymentActive!,
                                                isWalletActive: _isWalletActive,
                                                storeId: widget.storeId,
                                                total: total,
                                                isOfflinePaymentActive:
                                                    _isOfflinePaymentActive,
                                                guestNameTextEditingController:
                                                    guestContactPersonNameController,
                                                guestNumberTextEditingController:
                                                    guestContactPersonNumberController,
                                                guestNumberNode:
                                                    guestNumberNode,
                                                guestEmailController:
                                                    guestEmailController,
                                                guestEmailNode: guestEmailNode,
                                                tooltipController1:
                                                    tooltipController1,
                                                tooltipController2:
                                                    tooltipController2,
                                                dmTipsTooltipController:
                                                    tooltipController3,
                                                guestPasswordController:
                                                    guestPasswordController,
                                                guestConfirmPasswordController:
                                                    guestConfirmPasswordController,
                                                guestPasswordNode:
                                                    guestPasswordNode,
                                                guestConfirmPasswordNode:
                                                    guestConfirmPasswordNode,
                                                variationPrice:
                                                    isPassedVariationPrice
                                                        ? variations
                                                        : 0,
                                                deliveryChargeForView:
                                                    _deliveryChargeForView,
                                                badWeatherCharge:
                                                    badWeatherChargeForToolTip,
                                                extraChargeForToolTip:
                                                    extraChargeForToolTip,
                                              ),

                                              BottomSection(
                                                checkoutController:
                                                    checkoutController,
                                                total: total,
                                                module: module!,
                                                subTotal: subTotal,
                                                discount: discount,
                                                couponController:
                                                    couponController,
                                                taxIncluded:
                                                    (checkoutController
                                                            .taxIncluded ==
                                                        1),
                                                tax:
                                                    checkoutController
                                                        .orderTax!,
                                                deliveryCharge: deliveryCharge,
                                                todayClosed: todayClosed,
                                                tomorrowClosed: tomorrowClosed,
                                                orderAmount: orderAmount,
                                                maxCodOrderAmount:
                                                    maxCodOrderAmount,
                                                storeId: widget.storeId,
                                                taxPercent: _taxPercent,
                                                price: price,
                                                addOns: addOns,
                                                isPrescriptionRequired:
                                                    isPrescriptionRequired,
                                                checkoutButton:
                                                    _orderPlaceButton(
                                                      checkoutController,
                                                      todayClosed,
                                                      tomorrowClosed,
                                                      orderAmount,
                                                      subTotal,
                                                      deliveryCharge,
                                                      checkoutController
                                                          .orderTax!,
                                                      discount,
                                                      total,
                                                      maxCodOrderAmount,
                                                      isPrescriptionRequired,
                                                    ),
                                                referralDiscount:
                                                    referralDiscount,
                                                variationPrice:
                                                    isPassedVariationPrice
                                                        ? variations
                                                        : 0,
                                                extraDiscount: extraDiscount,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  _buildBottomPlaceOrderButton(
                                    checkoutController,
                                    todayClosed,
                                    tomorrowClosed,
                                    orderAmount,
                                    subTotal,
                                    deliveryCharge,
                                    checkoutController.orderTax!,
                                    discount,
                                    total,
                                    maxCodOrderAmount,
                                    isPrescriptionRequired,
                                  ),
                                ],
                              )
                              : const CheckoutScreenShimmerView();
                        },
                      );
                    },
                  );
                },
              )
              : (Get.find<SplashController>()
                      .configModel
                      .checkoutAuthSheetStatus ==
                  true)
              ? _buildCheckoutLoginPrompt()
              : NotLoggedInScreen(
                callBack: (value) {
                  initCall();
                  setState(() {});
                },
              ),
    );
  }

  /// Guest-friendly login gate: instead of the full-screen NotLoggedInScreen,
  /// a short prompt whose button opens the phone+OTP bottom sheet. The cart
  /// survives the login (merged to the server on success). Remotely gated by
  /// checkout_auth_sheet_status.
  Widget _buildCheckoutLoginPrompt() {
    if (!_authPromptLogged) {
      _authPromptLogged = true;
      AnalyticsHelper.log('checkout_auth_prompt_shown');
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 64,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            Text(
              'login_to_place_order'.tr,
              textAlign: TextAlign.center,
              style: waddyBold.copyWith(fontSize: Dimensions.fontSizeLarge),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(
              'auth_verification_code_subtitle'.tr,
              textAlign: TextAlign.center,
              style: waddyRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).disabledColor,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraLarge),
            CustomButton(
              buttonText: 'log_in'.tr,
              onPressed: () {
                // Two-gate sequence: zone check fires FIRST — an out-of-zone
                // guest gets NO DELIVERY instead of being asked to sign up for
                // an order we can't fulfil. See docs/guest_mode_plan.md
                // (Amendments A & D).
                GuestGate.checkoutGuard(() {
                  initCall();
                  if (mounted) setState(() {});
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPlaceOrderButton(
    CheckoutController checkoutController,
    bool todayClosed,
    bool tomorrowClosed,
    double orderAmount,
    // CS-02: the order payload sends this as `order_amount`, matching the tax
    // quote. Threaded through because the pricing lives in `build()` (CS-01);
    // it becomes one field on the snapshot in Phase 2.
    double subTotal,
    double? deliveryCharge,
    double tax,
    double? discount,
    double total,
    double? maxCodOrderAmount,
    bool isPrescriptionRequired,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: WaddyColors.shadowDeep,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: _orderPlaceButton(
          checkoutController,
          todayClosed,
          tomorrowClosed,
          orderAmount,
          subTotal,
          deliveryCharge,
          tax,
          discount,
          total,
          maxCodOrderAmount,
          isPrescriptionRequired,
        ),
      ),
    );
  }

  Widget _orderPlaceButton(
    CheckoutController checkoutController,
    bool todayClosed,
    bool tomorrowClosed,
    double orderAmount,
    // CS-02: the order payload sends this as `order_amount`, matching the tax
    // quote. Threaded through because the pricing lives in `build()` (CS-01);
    // it becomes one field on the snapshot in Phase 2.
    double subTotal,
    double? deliveryCharge,
    double tax,
    double? discount,
    double total,
    double? maxCodOrderAmount,
    bool isPrescriptionRequired,
  ) {
    return Container(
      width: Dimensions.maxContentWidth,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeSmall,
        horizontal: Dimensions.paddingSizeLarge,
      ),
      child: SafeArea(
        child: CustomButton(
          isLoading: checkoutController.isLoading,
          buttonText: 'place_order'.tr,
          onPressed:
              checkoutController.acceptTerms
                  ? () {
                    bool isAvailable = true;
                    DateTime scheduleStartDate = DateTime.now();
                    DateTime scheduleEndDate = DateTime.now();
                    if (checkoutController.timeSlots == null ||
                        checkoutController.timeSlots!.isEmpty) {
                      isAvailable = false;
                    } else {
                      DateTime date =
                          checkoutController.selectedDateSlot == 0
                              ? DateTime.now()
                              : DateTime.now().add(const Duration(days: 1));
                      DateTime startTime =
                          checkoutController
                              .timeSlots![checkoutController.selectedTimeSlot]
                              .startTime!;
                      DateTime endTime =
                          checkoutController
                              .timeSlots![checkoutController.selectedTimeSlot]
                              .endTime!;
                      scheduleStartDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        startTime.hour,
                        startTime.minute + 1,
                      );
                      scheduleEndDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        endTime.hour,
                        endTime.minute + 1,
                      );
                      if (_cartList != null) {
                        for (CartModel? cart in _cartList!) {
                          if (!DateConverter.isAvailable(
                                cart!.item!.availableTimeStarts,
                                cart.item!.availableTimeEnds,
                                time:
                                    checkoutController.store!.scheduleOrder!
                                        ? scheduleStartDate
                                        : null,
                              ) &&
                              !DateConverter.isAvailable(
                                cart.item!.availableTimeStarts,
                                cart.item!.availableTimeEnds,
                                time:
                                    checkoutController.store!.scheduleOrder!
                                        ? scheduleEndDate
                                        : null,
                              )) {
                            isAvailable = false;
                            break;
                          }
                        }
                      }
                    }

                    // Zone gate FIRST — `checkoutGuard` only runs on the guest
                    // LOG IN path above, so a logged-in user whose address is
                    // out of zone (e.g. changed after the cart was built) would
                    // otherwise walk this whole chain and place an order we
                    // cannot fulfil. Read the getter, not `checkoutGuard`: this
                    // chain is sync, the user is already past auth, and
                    // `outOfServingZone` re-reads the saved address off disk on
                    // every call, so it can never be stale at tap time.
                    if (Get.find<LocationController>().outOfServingZone) {
                      AnalyticsHelper.log('place_order_blocked_out_of_zone', {
                        'auth_state':
                            AuthHelper.isLoggedIn() ? 'user' : 'guest',
                      });
                      GuestGate.showNoDeliverySheet(source: 'checkout');
                    } else if (isPrescriptionRequired &&
                        checkoutController.pickedPrescriptions.isEmpty) {
                      showCustomSnackBar(
                        'you_must_upload_prescription_for_this_order'.tr,
                      );
                    } else if (!_isCashOnDeliveryActive! &&
                        !_isDigitalPaymentActive! &&
                        !_isWalletActive) {
                      showCustomSnackBar('no_payment_method_is_enabled'.tr);
                    } else if (checkoutController.paymentMethodIndex == -1) {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder:
                            (con) => PaymentMethodBottomSheet(
                              isCashOnDeliveryActive: _isCashOnDeliveryActive!,
                              isDigitalPaymentActive: _isDigitalPaymentActive!,
                              isWalletActive: _isWalletActive,
                              storeId: widget.storeId,
                              totalPrice: total,
                              isOfflinePaymentActive: _isOfflinePaymentActive,
                            ),
                      );
                    } else if (orderAmount <
                            checkoutController.store!.minimumOrder! &&
                        widget.storeId == null) {
                      showCustomSnackBar(
                        '${'minimum_order_amount_is'.tr} ${checkoutController.store!.minimumOrder}',
                      );
                    } else if (checkoutController
                            .tipController
                            .text
                            .isNotEmpty &&
                        checkoutController.tipController.text != 'not_now' &&
                        double.parse(
                              checkoutController.tipController.text.trim(),
                            ) <
                            0) {
                      showCustomSnackBar('tips_can_not_be_negative'.tr);
                    } else if ((checkoutController.selectedDateSlot == 0 &&
                            todayClosed) ||
                        (checkoutController.selectedDateSlot == 1 &&
                            tomorrowClosed)) {
                      showCustomSnackBar(
                        Get.find<SplashController>()
                                .configModel
                                .moduleConfig!
                                .module!
                                .showRestaurantText!
                            ? 'restaurant_is_closed'.tr
                            : 'store_is_closed'.tr,
                      );
                    } else if (checkoutController.paymentMethodIndex == 0 &&
                        _isCashOnDeliveryActive! &&
                        maxCodOrderAmount != null &&
                        maxCodOrderAmount != 0 &&
                        (total > maxCodOrderAmount) &&
                        widget.storeId == null) {
                      showCustomSnackBar(
                        '${'you_cant_order_more_then'.tr} ${PriceConverter.convertPrice(maxCodOrderAmount)} ${'in_cash_on_delivery'.tr}',
                      );
                    } else if (checkoutController.paymentMethodIndex != 0 &&
                        widget.storeId != null) {
                      showCustomSnackBar('payment_method_is_not_available'.tr);
                    } else if (checkoutController.timeSlots == null ||
                        checkoutController.timeSlots!.isEmpty) {
                      if (checkoutController.store!.scheduleOrder!) {
                        showCustomSnackBar('select_a_time'.tr);
                      } else {
                        showCustomSnackBar(
                          Get.find<SplashController>()
                                  .configModel
                                  .moduleConfig!
                                  .module!
                                  .showRestaurantText!
                              ? 'restaurant_is_closed'.tr
                              : 'store_is_closed'.tr,
                        );
                      }
                    } else if (!isAvailable) {
                      showCustomSnackBar(
                        'one_or_more_products_are_not_available_for_this_selected_time'
                            .tr,
                      );
                    } else if (checkoutController.orderType != 'take_away' &&
                        checkoutController.distance == -1) {
                      // `distance == -1` alone now. This used to also require
                      // `deliveryCharge == -1`, but the sentinel is absorbed
                      // inside calculateDeliveryCharge so that it cannot leak
                      // into the displayed total as a one-pound discount —
                      // so that half of the condition could never fire again.
                      //
                      // The distance check is the real question anyway: a
                      // delivery order whose distance has not resolved cannot
                      // be priced, whatever the charge currently reads.
                      showCustomSnackBar('delivery_fee_not_set_yet'.tr);
                    } else if (widget.storeId != null &&
                        checkoutController.pickedPrescriptions.isEmpty) {
                      showCustomSnackBar(
                        'please_upload_your_prescription_images'.tr,
                      );
                    } else if (!checkoutController.acceptTerms) {
                      showCustomSnackBar(
                        'please_accept_privacy_policy_trams_conditions_refund_policy_first'
                            .tr,
                      );
                    } else {
                      AddressModel finalAddress =
                          address[checkoutController.addressIndex!];

                      if (finalAddress.contactPersonNumber == 'null') {
                        finalAddress.contactPersonNumber =
                            Get.find<ProfileController>().userInfoModel!.phone;
                      }

                      if (widget.storeId == null) {
                        final List<OnlineCart> carts =
                            OrderPayloadBuilder.buildCartLines(
                              cartList: _cartList,
                              isCampaign: !widget.fromCart,
                            );
                        PlaceOrderBodyModel
                        placeOrderBody = PlaceOrderBodyModel(
                          cart: carts,
                          couponDiscountAmount:
                              Get.find<CouponController>().discount,
                          distance: checkoutController.distance,
                          scheduleAt:
                              !checkoutController.store!.scheduleOrder!
                                  ? null
                                  : (checkoutController.selectedDateSlot == 0 &&
                                      checkoutController.selectedTimeSlot == 0)
                                  ? null
                                  : DateConverter.dateToDateAndTime(
                                    scheduleEndDate,
                                  ),
                          // CS-02: the tax quote above sends `subTotal`; this
                          // sent `total`, which already contains delivery,
                          // tips, packaging and the tax figure itself — so the
                          // number the customer was quoted tax on was not the
                          // number the order carried, and the order's was
                          // inflated circularly.
                          //
                          // Settled on `subTotal` after reading the backend
                          // (2026-09-16): `PlaceNewOrder.php` overwrites
                          // `order_amount` with its own figure at `:472` and
                          // `:516` before using it, and `getCalculatedTax`
                          // recomputes `$product_price` from the cart for
                          // non-parcel orders — so today this changes no
                          // charge. It is sent as the quote's figure so that a
                          // future amount- or zone-sensitive tax rule reads
                          // one consistent number instead of two.
                          orderAmount: subTotal,
                          orderNote: checkoutController.noteController.text,
                          orderType: checkoutController.orderType,
                          paymentMethod:
                              checkoutController.paymentMethodIndex == 0
                                  ? 'cash_on_delivery'
                                  : checkoutController.paymentMethodIndex == 1
                                  ? 'wallet'
                                  : checkoutController.paymentMethodIndex == 2
                                  ? 'digital_payment'
                                  : 'offline_payment',
                          couponCode:
                              (Get.find<CouponController>().discount! > 0 ||
                                      (Get.find<CouponController>().coupon !=
                                              null &&
                                          Get.find<CouponController>()
                                              .freeDelivery))
                                  ? Get.find<CouponController>().coupon!.code
                                  : null,
                          storeId: _cartList![0]!.item!.storeId,
                          address: finalAddress.address,
                          latitude: finalAddress.latitude,
                          longitude: finalAddress.longitude,
                          senderZoneId: null,
                          addressType: finalAddress.addressType,
                          contactPersonName:
                              finalAddress.contactPersonName ??
                              '${Get.find<ProfileController>().userInfoModel!.fName} '
                                  '${Get.find<ProfileController>().userInfoModel!.lName}',
                          contactPersonNumber:
                              finalAddress.contactPersonNumber ??
                              Get.find<ProfileController>()
                                  .userInfoModel!
                                  .phone,
                          streetNumber:
                              checkoutController.streetNumberController.text
                                  .trim(),
                          house: checkoutController.houseController.text.trim(),
                          floor: checkoutController.floorController.text.trim(),
                          discountAmount: discount,
                          taxAmount: tax,
                          receiverDetails: null,
                          parcelCategoryId: null,
                          chargePayer: null,
                          dmTips:
                              (checkoutController.orderType == 'take_away' ||
                                      checkoutController.tipController.text ==
                                          'not_now')
                                  ? ''
                                  : checkoutController.tipController.text
                                      .trim(),
                          cutlery:
                              Get.find<CartController>().addCutlery ? 1 : 0,
                          unavailableItemNote:
                              Get.find<CartController>().notAvailableIndex != -1
                                  ? Get.find<CartController>()
                                      .notAvailableList[Get.find<
                                        CartController
                                      >()
                                      .notAvailableIndex]
                                  : '',
                          deliveryInstruction:
                              checkoutController.getSelectedInstructionsText(),
                          partialPayment:
                              checkoutController.isPartialPay ? 1 : 0,
                          guestId: 0,
                          isBuyNow: widget.fromCart ? 0 : 1,
                          guestEmail: null,
                          extraPackagingAmount:
                              Get.find<CartController>().needExtraPackage
                                  ? checkoutController
                                      .store!
                                      .extraPackagingAmount
                                  : 0,
                          createNewUser: 0,
                          password: '',
                          usePrizeId:
                              Get.find<XpController>()
                                  .selectedCheckoutPrize
                                  ?.id,
                        );

                        if (checkoutController.paymentMethodIndex == 3) {
                          Get.toNamed(
                            RouteHelper.getOfflinePaymentScreen(
                              placeOrderBody: placeOrderBody,
                              zoneId: checkoutController.store!.zoneId!,
                              total: checkoutController.viewTotalPrice!,
                              maxCodOrderAmount: maxCodOrderAmount,
                              fromCart: widget.fromCart,
                              isCodActive: _isCashOnDeliveryActive,
                              forParcel: false,
                            ),
                          );
                        } else {
                          checkoutController.placeOrder(
                            placeOrderBody,
                            checkoutController.store!.zoneId,
                            total,
                            maxCodOrderAmount,
                            widget.fromCart,
                            _isCashOnDeliveryActive!,
                            checkoutController.pickedPrescriptions,
                          );
                        }
                      } else {
                        checkoutController.placePrescriptionOrder(
                          widget.storeId,
                          checkoutController.store!.zoneId,
                          checkoutController.distance,
                          finalAddress.address!,
                          finalAddress.longitude!,
                          finalAddress.latitude!,
                          checkoutController.noteController.text,
                          checkoutController.pickedPrescriptions,
                          (checkoutController.orderType == 'take_away' ||
                                  checkoutController.tipController.text ==
                                      'not_now')
                              ? ''
                              : checkoutController.tipController.text.trim(),
                          checkoutController.getSelectedInstructionsText(),
                          0,
                          0,
                          widget.fromCart,
                          _isCashOnDeliveryActive!,
                        );
                      }
                    }
                  }
                  : null,
        ),
      ),
    );
  }

  List<DropdownItem<int>> _getDropdownAddressList({
    required BuildContext context,
    required List<AddressModel>? addressList,
    required Store? store,
  }) {
    List<DropdownItem<int>> dropDownAddressList = [];

    dropDownAddressList.add(
      DropdownItem<int>(
        value: 0,
        child: SizedBox(
          width:
              context.width > Dimensions.maxContentWidth
                  ? Dimensions.maxContentWidth - 50
                  : context.width - 50,
          child: AddressWidget(
            address: AddressHelper.getUserAddressFromSharedPref(),
            fromAddress: false,
            fromCheckout: true,
          ),
        ),
      ),
    );

    if (addressList != null && store != null) {
      for (int index = 0; index < addressList.length; index++) {
        if (addressList[index].zoneIds!.contains(store.zoneId)) {
          dropDownAddressList.add(
            DropdownItem<int>(
              value: index + 1,
              child: SizedBox(
                width:
                    context.width > Dimensions.maxContentWidth
                        ? Dimensions.maxContentWidth - 50
                        : context.width - 50,
                child: AddressWidget(
                  address: addressList[index],
                  fromAddress: false,
                  fromCheckout: true,
                ),
              ),
            ),
          );
        }
      }
    }
    return dropDownAddressList;
  }

  List<AddressModel> _getAddressList({
    required List<AddressModel>? addressList,
    required Store? store,
  }) {
    List<AddressModel> address = [];

    address.add(AddressHelper.getUserAddressFromSharedPref()!);

    if (addressList != null && store != null) {
      for (int index = 0; index < addressList.length; index++) {
        if (addressList[index].zoneIds!.contains(store.zoneId)) {
          address.add(addressList[index]);
        }
      }
    }
    return address;
  }

  bool _checkPrescriptionRequired() {
    if (widget.storeId == null &&
        Get.find<SplashController>()
            .configModel
            .moduleConfig!
            .module!
            .orderAttachment!) {
      for (var cart in _cartList!) {
        if (cart!.item!.isPrescriptionRequired!) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> showCashBackSnackBar() async {
    await Get.find<HomeController>().getCashBackData(_payableAmount!);
    double? cashBackAmount =
        Get.find<HomeController>().cashBackData?.cashbackAmount ?? 0;
    String? cashBackType =
        Get.find<HomeController>().cashBackData?.cashbackType ?? '';
    String text =
        '${'you_will_get'.tr} ${cashBackType == 'amount' ? PriceConverter.convertPrice(cashBackAmount) : '${cashBackAmount.toStringAsFixed(0)}%'} ${'cash_back_after_completing_order'.tr}';
    if (cashBackAmount > 0) {
      showCustomSnackBar(text, isError: false);
    }
  }
}
