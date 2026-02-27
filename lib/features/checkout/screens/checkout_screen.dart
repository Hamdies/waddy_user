import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:sixam_mart/common/widgets/address_widget.dart';
import 'package:sixam_mart/features/address/controllers/address_controller.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/coupon/controllers/coupon_controller.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/checkout/domain/models/place_order_body_model.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/cart/domain/models/cart_model.dart';
import 'package:sixam_mart/common/models/config_model.dart';
import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';
import 'package:sixam_mart/features/checkout/controllers/checkout_controller.dart';
import 'package:sixam_mart/features/store/domain/models/store_model.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/date_converter.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_button.dart';
import 'package:sixam_mart/common/widgets/custom_dropdown.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/footer_view.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/common/widgets/not_logged_in_screen.dart';
import 'package:sixam_mart/features/checkout/widgets/checkout_screen_shimmer_view.dart';
import 'package:sixam_mart/features/checkout/widgets/payment_method_bottom_sheet.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/checkout/widgets/bottom_section.dart';
import 'package:sixam_mart/features/checkout/widgets/top_section.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:flutter/material.dart';
import 'package:sixam_mart/features/checkout/helpers/checkout_calculation_helper.dart';

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
  double badWeatherChargeForToolTip = 0;
  double extraChargeForToolTip = 0;
  bool isPassedVariationPrice = false;

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
        AddressHelper.getUserAddressFromSharedPref()!.streetNumber ?? '';
    Get.find<CheckoutController>().houseController.text =
        AddressHelper.getUserAddressFromSharedPref()!.house ?? '';
    Get.find<CheckoutController>().floorController.text =
        AddressHelper.getUserAddressFromSharedPref()!.floor ?? '';
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
      if (GetPlatform.isWeb) {
        await Get.find<CartController>().getCartDataOnline();
      }
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
        Get.find<SplashController>().configModel!.customerWalletStatus == 1;
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
  }

  void _setSinglePaymentActive() {
    if ((!_firstTimeCheckPayment &&
            !_isCashOnDeliveryActive! &&
            _isDigitalPaymentActive! &&
            Get.find<SplashController>()
                    .configModel!
                    .activePaymentMethodList!
                    .length ==
                1) &&
        ((!_isWalletActive && AuthHelper.isLoggedIn()) ||
            !AuthHelper.isLoggedIn())) {
      Future.delayed(const Duration(milliseconds: 600), () {
        Get.find<CheckoutController>().setPaymentMethod(2, isUpdate: false);
        Get.find<CheckoutController>().changeDigitalPaymentName(
          Get.find<SplashController>()
              .configModel!
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
        Get.find<SplashController>().configModel!.moduleConfig!.module;
    bool guestCheckoutPermission =
        AuthHelper.isGuestLoggedIn() &&
        Get.find<SplashController>().configModel!.guestCheckoutStatus!;
    bool isLoggedIn = AuthHelper.isLoggedIn();
    bool isGuestLogIn = AuthHelper.isGuestLoggedIn();

    final Color primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 20, color: primaryColor),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
        title: Text(
          'checkout'.tr,
          style: robotoBold.copyWith(fontSize: 18, color: Colors.black87),
        ),
      ),
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body:
          guestCheckoutPermission || AuthHelper.isLoggedIn()
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
                  _isDigitalPaymentActive = _calcHelper.checkDigitalPaymentActive(
                    store: checkoutController.store,
                  );
                  _isOfflinePaymentActive =
                      Get.find<SplashController>()
                          .configModel!
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
                  return GetBuilder<XpController>(
                    builder: (xpController) {
                      return GetBuilder<CouponController>(
                        builder: (couponController) {
                          double? maxCodOrderAmount;

                          if (moduleData != null) {
                            maxCodOrderAmount =
                                moduleData.maximumCodOrderAmount;
                          }
                          double price = _calcHelper.calculatePrice(
                            store: checkoutController.store,
                            cartList: _cartList,
                          );
                          double addOns = _calcHelper.calculateAddonsPrice(
                            store: checkoutController.store,
                            cartList: _cartList,
                          );
                          double variations = _calcHelper.calculateVariationPrice(
                            store: checkoutController.store,
                            cartList: _cartList,
                            calculateWithoutDiscount: true,
                          );
                          double? itemDiscountPrice = _calcHelper.calculateDiscountPrice(
                            store: checkoutController.store,
                            cartList: _cartList,
                            price: price,
                            addOns: addOns,
                            calStoreDiscount: false,
                          );
                          double? storeDiscountPrice = _calcHelper.calculateDiscountPrice(
                            store: checkoutController.store,
                            cartList: _cartList,
                            price: price,
                            addOns: addOns,
                            calStoreDiscount: true,
                          );

                          double extraDiscount = _calcHelper.getExtraDiscountPrice(
                            storeDiscountPrice,
                            itemDiscountPrice,
                          );
                          double? discount = _calcHelper.getDiscountPrice(
                            storeDiscountPrice,
                            itemDiscountPrice,
                          );
                          double couponDiscount = PriceConverter.toFixed(
                            couponController.discount!,
                          );

                          double subTotal = _calcHelper.calculateSubTotal(
                            price: price,
                            addOns: addOns,
                            variations: variations,
                            cartList: _cartList,
                          );

                          double referralDiscount = _calcHelper.calculateReferralDiscount(
                            subTotal,
                            discount,
                            couponDiscount,
                          );

                          double orderAmount = _calcHelper.calculateOrderAmount(
                            price: price,
                            variations: variations,
                            discount: discount,
                            addOns: addOns,
                            couponDiscount: couponDiscount,
                            cartList: _cartList,
                            referralDiscount: referralDiscount,
                          );

                          Future.delayed(const Duration(milliseconds: 50), () {
                            if (checkoutController.isFirstTime ||
                                (couponController.discount! > 0 &&
                                    !checkoutController.isFirstTime &&
                                    !_calledOrderTax)) {
                              if (couponController.discount! > 0) {
                                _calledOrderTax = true;
                              }
                              List<OnlineCart> carts = [];

                              if (widget.storeId == null) {
                                for (
                                  int index = 0;
                                  index < _cartList!.length;
                                  index++
                                ) {
                                  CartModel cart = _cartList![index]!;
                                  List<int?> addOnIdList = [];
                                  List<int?> addOnQtyList = [];
                                  for (var addOn in cart.addOnIds!) {
                                    addOnIdList.add(addOn.id);
                                    addOnQtyList.add(addOn.quantity);
                                  }

                                  List<OrderVariation> variations = [];
                                  if (Get.find<SplashController>()
                                      .getModuleConfig(cart.item!.moduleType)
                                      .newVariation!) {
                                    for (
                                      int i = 0;
                                      i < cart.item!.foodVariations!.length;
                                      i++
                                    ) {
                                      if (cart.foodVariations![i].contains(
                                        true,
                                      )) {
                                        variations.add(
                                          OrderVariation(
                                            name:
                                                cart
                                                    .item!
                                                    .foodVariations![i]
                                                    .name,
                                            values: OrderVariationValue(
                                              label: [],
                                            ),
                                          ),
                                        );
                                        for (
                                          int j = 0;
                                          j <
                                              cart
                                                  .item!
                                                  .foodVariations![i]
                                                  .variationValues!
                                                  .length;
                                          j++
                                        ) {
                                          if (cart.foodVariations![i][j]!) {
                                            variations[variations.length - 1]
                                                .values!
                                                .label!
                                                .add(
                                                  cart
                                                      .item!
                                                      .foodVariations![i]
                                                      .variationValues![j]
                                                      .level,
                                                );
                                          }
                                        }
                                      }
                                    }
                                  }
                                  carts.add(
                                    OnlineCart(
                                      cart.id,
                                      cart.item!.id,
                                      cart.isCampaign! ? cart.item!.id : null,
                                      cart.discountedPrice.toString(),
                                      '',
                                      Get.find<SplashController>()
                                              .getModuleConfig(
                                                cart.item!.moduleType,
                                              )
                                              .newVariation!
                                          ? null
                                          : cart.variation,
                                      Get.find<SplashController>()
                                              .getModuleConfig(
                                                cart.item!.moduleType,
                                              )
                                              .newVariation!
                                          ? variations
                                          : null,
                                      cart.quantity,
                                      addOnIdList,
                                      cart.addOns,
                                      addOnQtyList,
                                      'Item',
                                      itemType:
                                          !widget.fromCart
                                              ? "AppModelsItemCampaign"
                                              : null,
                                    ),
                                  );
                                }
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
                                    checkoutController.getSelectedInstructionsText(),
                                partialPayment:
                                    checkoutController.isPartialPay ? 1 : 0,
                                guestId:
                                    isGuestLogIn
                                        ? int.parse(AuthHelper.getGuestId())
                                        : 0,
                                isBuyNow: widget.fromCart ? 0 : 1,
                                extraPackagingAmount:
                                    Get.find<CartController>().needExtraPackage && checkoutController.store != null
                                        ? checkoutController
                                            .store!
                                            .extraPackagingAmount
                                        : 0,
                                createNewUser:
                                    checkoutController.isCreateAccount ? 1 : 0,
                                password: guestPasswordController.text,
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

                          double additionalCharge =
                              Get.find<SplashController>()
                                      .configModel!
                                      .additionalChargeStatus!
                                  ? Get.find<SplashController>()
                                      .configModel!
                                      .additionCharge!
                                  : 0;
                          double
                          originalCharge = _calcHelper.calculateOriginalDeliveryCharge(
                            store: checkoutController.store,
                            address:
                                AddressHelper.getUserAddressFromSharedPref()!,
                            distance: checkoutController.distance,
                            extraCharge: checkoutController.extraCharge,
                            surgePrice: checkoutController.surgePrice?.price,
                            surgePriceType:
                                checkoutController.surgePrice?.priceType,
                          );
                          double deliveryCharge = _calcHelper.calculateDeliveryCharge(
                            store: checkoutController.store,
                            address:
                                AddressHelper.getUserAddressFromSharedPref()!,
                            distance: checkoutController.distance,
                            extraCharge: checkoutController.extraCharge,
                            orderType: checkoutController.orderType!,
                            orderAmount: orderAmount,
                            surgePrice: checkoutController.surgePrice?.price,
                            surgePriceType:
                                checkoutController.surgePrice?.priceType,
                          );
                          badWeatherChargeForToolTip = _calcHelper.badWeatherChargeForToolTip;
                          extraChargeForToolTip = _calcHelper.extraChargeForToolTip;
                          isPassedVariationPrice = _calcHelper.isPassedVariationPrice;

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

                          double extraPackagingCharge =
                              widget.storeId != null
                                  ? 0
                                  : _calcHelper.calculateExtraPackagingCharge(
                                    checkoutController,
                                  );

                          double total = _calcHelper.calculateTotal(
                            subTotal: subTotal,
                            deliveryCharge: deliveryCharge,
                            discount: discount,
                            couponDiscount: couponDiscount,
                            taxIncluded: (checkoutController.taxIncluded == 1),
                            tax: checkoutController.orderTax!,
                            orderType: checkoutController.orderType!,
                            tips: checkoutController.tips,
                            additionalCharge: additionalCharge,
                            extraPackagingCharge: extraPackagingCharge,
                          );

                          bool isPrescriptionRequired =
                              _checkPrescriptionRequired();

                          total = total - referralDiscount;

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
                                  ResponsiveHelper.isDesktop(context)
                                      ? Container(
                                        height: 64,
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.10),
                                        child: Center(
                                          child: Text(
                                            'checkout'.tr,
                                            style: robotoMedium,
                                          ),
                                        ),
                                      )
                                      : const SizedBox(),

                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      physics: const BouncingScrollPhysics(),
                                      child: FooterView(
                                        child: SizedBox(
                                          width: Dimensions.webMaxWidth,
                                          child:
                                              ResponsiveHelper.isDesktop(
                                                    context,
                                                  )
                                                  ? Padding(
                                                    padding: const EdgeInsets.only(
                                                      top:
                                                          Dimensions
                                                              .paddingSizeLarge,
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Expanded(
                                                          flex: 6,
                                                          child: TopSection(
                                                            checkoutController:
                                                                checkoutController,
                                                            charge:
                                                                originalCharge,
                                                            deliveryCharge:
                                                                deliveryCharge,
                                                            addressList:
                                                                addressList,
                                                            tomorrowClosed:
                                                                tomorrowClosed,
                                                            todayClosed:
                                                                todayClosed,
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
                                                            isWalletActive:
                                                                _isWalletActive,
                                                            storeId:
                                                                widget.storeId,
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
                                                            guestEmailNode:
                                                                guestEmailNode,
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
                                                        ),
                                                        const SizedBox(
                                                          width:
                                                              Dimensions
                                                                  .paddingSizeLarge,
                                                        ),

                                                        Expanded(
                                                          flex: 4,
                                                          child: BottomSection(
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
                                                            deliveryCharge:
                                                                deliveryCharge,
                                                            todayClosed:
                                                                todayClosed,
                                                            tomorrowClosed:
                                                                tomorrowClosed,
                                                            orderAmount:
                                                                orderAmount,
                                                            maxCodOrderAmount:
                                                                maxCodOrderAmount,
                                                            storeId:
                                                                widget.storeId,
                                                            taxPercent:
                                                                _taxPercent,
                                                            price: price,
                                                            addOns: addOns,
                                                            isPrescriptionRequired:
                                                                isPrescriptionRequired,
                                                            checkoutButton: _orderPlaceButton(
                                                              checkoutController,
                                                              todayClosed,
                                                              tomorrowClosed,
                                                              orderAmount,
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
                                                            extraDiscount:
                                                                extraDiscount,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                  : Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      TopSection(
                                                        checkoutController:
                                                            checkoutController,
                                                        charge: originalCharge,
                                                        deliveryCharge:
                                                            deliveryCharge,
                                                        addressList:
                                                            addressList,
                                                        tomorrowClosed:
                                                            tomorrowClosed,
                                                        todayClosed:
                                                            todayClosed,
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
                                                        isWalletActive:
                                                            _isWalletActive,
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
                                                        guestEmailNode:
                                                            guestEmailNode,
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
                                                        deliveryCharge:
                                                            deliveryCharge,
                                                        todayClosed:
                                                            todayClosed,
                                                        tomorrowClosed:
                                                            tomorrowClosed,
                                                        orderAmount:
                                                            orderAmount,
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
                                                        extraDiscount:
                                                            extraDiscount,
                                                      ),
                                                    ],
                                                  ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  ResponsiveHelper.isDesktop(context)
                                      ? const SizedBox()
                                      : _buildBottomPlaceOrderButton(
                                          checkoutController,
                                          todayClosed,
                                          tomorrowClosed,
                                          orderAmount,
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
              : NotLoggedInScreen(
                callBack: (value) {
                  initCall();
                  setState(() {});
                },
              ),
    );
  }

  Widget _buildBottomPlaceOrderButton(
    CheckoutController checkoutController,
    bool todayClosed,
    bool tomorrowClosed,
    double orderAmount,
    double? deliveryCharge,
    double tax,
    double? discount,
    double total,
    double? maxCodOrderAmount,
    bool isPrescriptionRequired,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: _orderPlaceButton(
          checkoutController,
          todayClosed,
          tomorrowClosed,
          orderAmount,
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
    double? deliveryCharge,
    double tax,
    double? discount,
    double total,
    double? maxCodOrderAmount,
    bool isPrescriptionRequired,
  ) {
    return Container(
      width: Dimensions.webMaxWidth,
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
                    bool isGuestLogIn = AuthHelper.isGuestLoggedIn();
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

                    if (isGuestLogIn &&
                        checkoutController.guestAddress == null &&
                        checkoutController.orderType != 'take_away') {
                      showCustomSnackBar(
                        'please_setup_your_delivery_address_first'.tr,
                      );
                    } else if (isGuestLogIn &&
                        checkoutController.orderType == 'take_away' &&
                        guestContactPersonNameController.text.isEmpty) {
                      showCustomSnackBar('please_enter_contact_person_name'.tr);
                    } else if (isGuestLogIn &&
                        checkoutController.orderType == 'take_away' &&
                        guestContactPersonNumberController.text.isEmpty) {
                      showCustomSnackBar(
                        'please_enter_contact_person_number'.tr,
                      );
                    } else if (isGuestLogIn &&
                        checkoutController.orderType == 'take_away' &&
                        guestEmailController.text.isEmpty) {
                      showCustomSnackBar(
                        'please_enter_contact_person_email'.tr,
                      );
                    } else if (isGuestLogIn &&
                        checkoutController.isCreateAccount &&
                        guestPasswordController.text.isEmpty) {
                      showCustomSnackBar('enter_password'.tr);
                    } else if (isGuestLogIn &&
                        checkoutController.isCreateAccount &&
                        guestConfirmPasswordController.text.isEmpty) {
                      showCustomSnackBar('enter_confirm_password'.tr);
                    } else if (isGuestLogIn &&
                        checkoutController.isCreateAccount &&
                        (guestPasswordController.text !=
                            guestConfirmPasswordController.text)) {
                      showCustomSnackBar(
                        'confirm_password_does_not_matched'.tr,
                      );
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
                      if (ResponsiveHelper.isDesktop(context)) {
                        Get.dialog(
                          Dialog(
                            backgroundColor: Colors.transparent,
                            child: PaymentMethodBottomSheet(
                              isCashOnDeliveryActive: _isCashOnDeliveryActive!,
                              isDigitalPaymentActive: _isDigitalPaymentActive!,
                              isWalletActive: _isWalletActive,
                              storeId: widget.storeId,
                              totalPrice: total,
                              isOfflinePaymentActive: _isOfflinePaymentActive,
                            ),
                          ),
                        );
                      } else {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder:
                              (con) => PaymentMethodBottomSheet(
                                isCashOnDeliveryActive:
                                    _isCashOnDeliveryActive!,
                                isDigitalPaymentActive:
                                    _isDigitalPaymentActive!,
                                isWalletActive: _isWalletActive,
                                storeId: widget.storeId,
                                totalPrice: total,
                                isOfflinePaymentActive: _isOfflinePaymentActive,
                              ),
                        );
                      }
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
                                .configModel!
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
                                  .configModel!
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
                        checkoutController.distance == -1 &&
                        deliveryCharge == -1) {
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
                      AddressModel? finalAddress =
                          isGuestLogIn
                              ? checkoutController.guestAddress
                              : address[checkoutController.addressIndex!];

                      if (isGuestLogIn &&
                          checkoutController.orderType == 'take_away') {
                        String number =
                            checkoutController.countryDialCode! +
                            guestContactPersonNumberController.text;
                        finalAddress = AddressModel(
                          contactPersonName:
                              guestContactPersonNameController.text,
                          contactPersonNumber: number,
                          address:
                              AddressHelper.getUserAddressFromSharedPref()!
                                  .address!,
                          latitude:
                              AddressHelper.getUserAddressFromSharedPref()!
                                  .latitude,
                          longitude:
                              AddressHelper.getUserAddressFromSharedPref()!
                                  .longitude,
                          zoneId:
                              AddressHelper.getUserAddressFromSharedPref()!
                                  .zoneId,
                          email: guestEmailController.text,
                        );
                      }

                      if (!isGuestLogIn &&
                          finalAddress!.contactPersonNumber == 'null') {
                        finalAddress.contactPersonNumber =
                            Get.find<ProfileController>().userInfoModel!.phone;
                      }

                      if (widget.storeId == null) {
                        List<OnlineCart> carts = [];
                        for (
                          int index = 0;
                          index < _cartList!.length;
                          index++
                        ) {
                          CartModel cart = _cartList![index]!;
                          List<int?> addOnIdList = [];
                          List<int?> addOnQtyList = [];
                          for (var addOn in cart.addOnIds!) {
                            addOnIdList.add(addOn.id);
                            addOnQtyList.add(addOn.quantity);
                          }

                          List<OrderVariation> variations = [];
                          if (Get.find<SplashController>()
                              .getModuleConfig(cart.item!.moduleType)
                              .newVariation!) {
                            for (
                              int i = 0;
                              i < cart.item!.foodVariations!.length;
                              i++
                            ) {
                              if (cart.foodVariations![i].contains(true)) {
                                variations.add(
                                  OrderVariation(
                                    name: cart.item!.foodVariations![i].name,
                                    values: OrderVariationValue(label: []),
                                  ),
                                );
                                for (
                                  int j = 0;
                                  j <
                                      cart
                                          .item!
                                          .foodVariations![i]
                                          .variationValues!
                                          .length;
                                  j++
                                ) {
                                  if (cart.foodVariations![i][j]!) {
                                    variations[variations.length - 1]
                                        .values!
                                        .label!
                                        .add(
                                          cart
                                              .item!
                                              .foodVariations![i]
                                              .variationValues![j]
                                              .level,
                                        );
                                  }
                                }
                              }
                            }
                          }
                          carts.add(
                            OnlineCart(
                              cart.id,
                              cart.item!.id,
                              cart.isCampaign! ? cart.item!.id : null,
                              cart.discountedPrice.toString(),
                              '',
                              Get.find<SplashController>()
                                      .getModuleConfig(cart.item!.moduleType)
                                      .newVariation!
                                  ? null
                                  : cart.variation,
                              Get.find<SplashController>()
                                      .getModuleConfig(cart.item!.moduleType)
                                      .newVariation!
                                  ? variations
                                  : null,
                              cart.quantity,
                              addOnIdList,
                              cart.addOns,
                              addOnQtyList,
                              'Item',
                              itemType:
                                  !widget.fromCart
                                      ? "AppModelsItemCampaign"
                                      : null,
                            ),
                          );
                        }

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
                          orderAmount: total,
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
                          address: finalAddress!.address,
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
                              isGuestLogIn
                                  ? finalAddress.streetNumber ?? ''
                                  : checkoutController
                                      .streetNumberController
                                      .text
                                      .trim(),
                          house:
                              isGuestLogIn
                                  ? finalAddress.house ?? ''
                                  : checkoutController.houseController.text
                                      .trim(),
                          floor:
                              isGuestLogIn
                                  ? finalAddress.floor ?? ''
                                  : checkoutController.floorController.text
                                      .trim(),
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
                          guestId:
                              isGuestLogIn
                                  ? int.parse(AuthHelper.getGuestId())
                                  : 0,
                          isBuyNow: widget.fromCart ? 0 : 1,
                          guestEmail: isGuestLogIn ? finalAddress.email : null,
                          extraPackagingAmount:
                              Get.find<CartController>().needExtraPackage
                                  ? checkoutController
                                      .store!
                                      .extraPackagingAmount
                                  : 0,
                          createNewUser:
                              checkoutController.isCreateAccount ? 1 : 0,
                          password: guestPasswordController.text,
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
                          finalAddress!.address!,
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
              context.width > Dimensions.webMaxWidth
                  ? Dimensions.webMaxWidth - 50
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
                    context.width > Dimensions.webMaxWidth
                        ? Dimensions.webMaxWidth - 50
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
            .configModel!
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
