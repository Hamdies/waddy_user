import 'package:get/get.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';

class CheckoutCalculationHelper {
  bool isPassedVariationPrice = false;
  double extraChargeForToolTip = 0;
  double badWeatherChargeForToolTip = 0;

  double calculatePrice({
    required Store? store,
    required List<CartModel?>? cartList,
  }) {
    double price = 0;
    if (cartList != null) {
      for (var cartModel in cartList) {
        if (Get.find<SplashController>()
            .getModuleConfig(cartModel!.item!.moduleType)
            .newVariation!) {
          price = price + (cartModel.item!.price! * cartModel.quantity!);
        } else {
          price = calculateVariationPrice(store: store, cartList: cartList);
        }
      }
    }
    return PriceConverter.toFixed(price);
  }

  double calculateAddonsPrice({
    required Store? store,
    required List<CartModel?>? cartList,
  }) {
    double addOns = 0;
    if (store != null && cartList != null) {
      for (var cartModel in cartList) {
        List<AddOns> addOnList = [];
        for (var addOnId in cartModel!.addOnIds!) {
          for (AddOns addOns in cartModel.item!.addOns!) {
            if (addOns.id == addOnId.id) {
              addOnList.add(addOns);
              break;
            }
          }
        }
        for (int index = 0; index < addOnList.length; index++) {
          addOns =
              addOns +
              (addOnList[index].price! * cartModel.addOnIds![index].quantity!);
        }
      }
    }
    return PriceConverter.toFixed(addOns);
  }

  double calculateVariationPrice({
    required Store? store,
    required List<CartModel?>? cartList,
    bool calculateDiscount = false,
    bool calculateWithoutDiscount = false,
  }) {
    double variationPrice = 0;
    double variationDiscount = 0;
    if (store != null && cartList != null) {
      for (var cartModel in cartList) {
        double? discount = cartModel!.item!.discount;
        String? discountType = cartModel.item!.discountType;

        if (Get.find<SplashController>()
            .getModuleConfig(cartModel.item!.moduleType)
            .newVariation!) {
          isPassedVariationPrice = true;
          for (
            int index = 0;
            index < cartModel.item!.foodVariations!.length;
            index++
          ) {
            for (
              int i = 0;
              i <
                  cartModel
                      .item!
                      .foodVariations![index]
                      .variationValues!
                      .length;
              i++
            ) {
              if (cartModel.foodVariations![index][i]!) {
                variationPrice +=
                    (PriceConverter.convertWithDiscount(
                          cartModel
                              .item!
                              .foodVariations![index]
                              .variationValues![i]
                              .optionPrice!,
                          discount,
                          discountType,
                          isFoodVariation: true,
                        )! *
                        cartModel.quantity!);
                variationDiscount +=
                    (cartModel
                            .item!
                            .foodVariations![index]
                            .variationValues![i]
                            .optionPrice! *
                        cartModel.quantity!);
              }
            }
          }
        } else {
          String variationType = '';
          for (int i = 0; i < cartModel.variation!.length; i++) {
            variationType = cartModel.variation![i].type!;
          }

          if (cartModel.item!.variations!.isNotEmpty) {
            for (Variation variation in cartModel.item!.variations!) {
              if (variation.type == variationType) {
                variationPrice += (variation.price! * cartModel.quantity!);
                break;
              }
            }
          } else {
            variationDiscount +=
                (PriceConverter.convertWithDiscount(
                      cartModel.item!.price!,
                      discount,
                      discountType,
                    )! *
                    cartModel.quantity!);
            variationPrice += (cartModel.item!.price! * cartModel.quantity!);
          }
        }
      }
    }
    if (calculateDiscount) {
      return (variationDiscount - variationPrice);
    } else if (calculateWithoutDiscount) {
      return variationDiscount;
    } else {
      return variationPrice;
    }
  }

  double calculateDiscountPrice({
    required Store? store,
    required List<CartModel?>? cartList,
    required double price,
    required double addOns,
    required bool calStoreDiscount,
  }) {
    double discount = 0;
    if (store != null && cartList != null) {
      for (var cartModel in cartList) {
        double? dis =
            (store.discount != null &&
                        DateConverter.isAvailable(
                          store.discount!.startTime,
                          store.discount!.endTime,
                        )) &&
                    calStoreDiscount
                ? store.discount!.discount
                : cartModel!.item!.discount;

        String? disType =
            (store.discount != null &&
                        DateConverter.isAvailable(
                          store.discount!.startTime,
                          store.discount!.endTime,
                        )) &&
                    calStoreDiscount
                ? 'percent'
                : cartModel?.item!.discountType;

        if (Get.find<SplashController>()
            .getModuleConfig(cartModel!.item!.moduleType)
            .newVariation!) {
          double d =
              ((cartModel.item!.price! -
                      PriceConverter.convertWithDiscount(
                        cartModel.item!.price!,
                        dis,
                        disType,
                      )!) *
                  cartModel.quantity!);
          discount = discount + d;
          if (disType == 'percent' && discount != 0) {
            discount =
                discount + calculateFoodVariationDiscount(cartModel: cartModel);
          }
        } else {
          String variationType = '';
          double variationPrice = 0;
          double variationWithoutDiscountPrice = 0;
          for (int i = 0; i < cartModel.variation!.length; i++) {
            variationType = cartModel.variation![i].type!;
          }
          if (cartModel.item!.variations!.isNotEmpty) {
            for (Variation variation in cartModel.item!.variations!) {
              if (variation.type == variationType) {
                variationPrice +=
                    (PriceConverter.convertWithDiscount(
                          variation.price!,
                          dis,
                          disType,
                        )! *
                        cartModel.quantity!);
                variationWithoutDiscountPrice +=
                    (variation.price! * cartModel.quantity!);
                break;
              }
            }
            discount =
                discount + (variationWithoutDiscountPrice - variationPrice);
          } else {
            double d =
                ((cartModel.item!.price! -
                        PriceConverter.convertWithDiscount(
                          cartModel.item!.price!,
                          dis,
                          disType,
                        )!) *
                    cartModel.quantity!);
            discount = discount + d;
          }
        }
      }
    }

    if (calStoreDiscount) {
      if (store != null && store.discount != null) {
        if (store.discount!.maxDiscount != 0 &&
            store.discount!.maxDiscount! < discount) {
          discount = store.discount!.maxDiscount!;
        }
        if (store.discount!.minPurchase != 0 &&
            store.discount!.minPurchase! > (price + addOns)) {
          discount = 0;
        }
      }
    }
    return PriceConverter.toFixed(discount);
  }

  double getDiscountPrice(double storeDiscountPrice, double itemDiscountPrice) {
    if (storeDiscountPrice > itemDiscountPrice) {
      return storeDiscountPrice;
    }
    return itemDiscountPrice;
  }

  double getExtraDiscountPrice(
    double storeDiscountPrice,
    double itemDiscountPrice,
  ) {
    if (storeDiscountPrice > itemDiscountPrice) {
      return storeDiscountPrice - itemDiscountPrice;
    }
    return 0;
  }

  double calculateFoodVariationDiscount({required CartModel? cartModel}) {
    double variationPrice = 0;
    double variationDiscount = 0;
    if (cartModel != null) {
      double? discount = cartModel.item!.discount;
      String? discountType = cartModel.item!.discountType;
      for (
        int index = 0;
        index < cartModel.item!.foodVariations!.length;
        index++
      ) {
        for (
          int i = 0;
          i < cartModel.item!.foodVariations![index].variationValues!.length;
          i++
        ) {
          if (cartModel.foodVariations![index][i]!) {
            variationPrice +=
                (PriceConverter.convertWithDiscount(
                      cartModel
                          .item!
                          .foodVariations![index]
                          .variationValues![i]
                          .optionPrice!,
                      discount,
                      discountType,
                      isFoodVariation: true,
                    )! *
                    cartModel.quantity!);
            variationDiscount +=
                (cartModel
                        .item!
                        .foodVariations![index]
                        .variationValues![i]
                        .optionPrice! *
                    cartModel.quantity!);
          }
        }
      }
    }
    return (variationDiscount - variationPrice);
  }

  double calculateOrderAmount({
    required double price,
    required double variations,
    required double discount,
    required double addOns,
    required double couponDiscount,
    required List<CartModel?>? cartList,
    required double referralDiscount,
  }) {
    double orderAmount = 0;
    double variationPrice = 0;
    if (cartList != null &&
        cartList.isNotEmpty &&
        Get.find<SplashController>()
            .getModuleConfig(cartList[0]?.item?.moduleType)
            .newVariation!) {
      variationPrice = variations;
    }
    orderAmount =
        (price + variationPrice - discount) +
        addOns -
        couponDiscount -
        referralDiscount;
    // Clamped at zero. A coupon or referral bonus larger than the cart used to
    // drive this negative — a 200 EGP coupon on a 50 EGP cart produced -150 —
    // and this figure is what the free-delivery threshold and the delivery
    // tiers are judged against. The server recomputes the charge, so a
    // negative here was a wrong *quote* rather than a wrong charge, but
    // "the customer owes minus 150" is not a state the rest of checkout should
    // have to reason about. Nothing is owed below zero.
    if (orderAmount < 0) {
      orderAmount = 0;
    }
    return PriceConverter.toFixed(orderAmount);
  }

  double calculateSubTotal({
    required double price,
    required double addOns,
    required double variations,
    required List<CartModel?>? cartList,
  }) {
    double subTotal = 0;
    bool isFoodVariation = false;

    if (cartList != null && cartList.isNotEmpty) {
      isFoodVariation =
          Get.find<SplashController>()
              .getModuleConfig(cartList[0]!.item!.moduleType)
              .newVariation!;
    }
    if (isFoodVariation) {
      subTotal = price + addOns + variations;
    } else {
      subTotal = price;
    }

    return subTotal;
  }

  /// The subtotal as the cart bars show it: net of the item discount.
  ///
  /// `CS-03`: subtotal had two independent implementations —
  /// [calculateSubTotal] here and `CartController.calculationCart`, which
  /// walked the cart again to reach a *different* number. For a cart with a
  /// 10% item discount the cart bar showed 180 and the checkout screen 200,
  /// which is `CC-14`'s mechanism: checkout reports the subtotal gross and
  /// lists the discount as its own row, while the pre-checkout bars show the
  /// figure the customer will actually pay.
  ///
  /// Both are wanted — they answer different questions — so the merge keeps
  /// both meanings and removes only the second implementation. This states the
  /// cart's meaning in terms of the checkout's, so the two can no longer drift.
  double calculateNetSubTotal({
    required Store? store,
    required List<CartModel?>? cartList,
  }) {
    final double price = calculatePrice(store: store, cartList: cartList);
    final double addOns = calculateAddonsPrice(
      store: store,
      cartList: cartList,
    );
    final double variations = calculateVariationPrice(
      store: store,
      cartList: cartList,
      calculateWithoutDiscount: true,
    );
    final double subTotal = calculateSubTotal(
      price: price,
      addOns: addOns,
      variations: variations,
      cartList: cartList,
    );
    final double itemDiscount = calculateDiscountPrice(
      store: store,
      cartList: cartList,
      price: price,
      addOns: addOns,
      calStoreDiscount: false,
    );
    return PriceConverter.toFixed(subTotal - itemDiscount);
  }

  double calculateOriginalDeliveryCharge({
    required Store? store,
    required AddressModel address,
    required double? distance,
    required double? extraCharge,
    double? surgePrice,
    String? surgePriceType,
  }) {
    double deliveryCharge = -1;

    Pivot? moduleData;
    if (store != null) {
      for (ZoneData zData in address.zoneData!) {
        for (Modules m in zData.modules!) {
          if (m.id == Get.find<SplashController>().module!.id &&
              m.pivot!.zoneId == store.zoneId) {
            moduleData = m.pivot;
            break;
          }
        }
      }
    }
    double perKmCharge = 0;
    double minimumCharge = 0;
    double? maximumCharge = 0;
    if (store != null &&
        distance != null &&
        distance != -1 &&
        store.selfDeliverySystem == 1) {
      perKmCharge = store.perKmShippingCharge!;
      minimumCharge = store.minimumShippingCharge!;
      maximumCharge = store.maximumShippingCharge;
    } else if (store != null &&
        distance != null &&
        distance != -1 &&
        moduleData != null &&
        moduleData.deliveryChargeType == 'distance') {
      perKmCharge = moduleData.perKmShippingCharge!;
      minimumCharge = moduleData.minimumShippingCharge!;
      maximumCharge = moduleData.maximumShippingCharge;
    } else if (store != null &&
        moduleData != null &&
        moduleData.deliveryChargeType == 'fixed') {
      perKmCharge = moduleData.fixedShippingCharge ?? 0;
      minimumCharge = moduleData.fixedShippingCharge ?? 0;
      maximumCharge = moduleData.fixedShippingCharge ?? 0;
    }
    if (store != null && distance != null) {
      deliveryCharge = distance * perKmCharge;

      if (deliveryCharge < minimumCharge) {
        deliveryCharge = minimumCharge;
      } else if (maximumCharge != null && deliveryCharge > maximumCharge) {
        deliveryCharge = maximumCharge;
      }
    }

    if (store != null && store.selfDeliverySystem == 0 && extraCharge != null) {
      extraChargeForToolTip = extraCharge;
      deliveryCharge = deliveryCharge + extraCharge;
    }

    if (store != null &&
        store.selfDeliverySystem == 0 &&
        surgePrice != null &&
        surgePrice > 0) {
      if (surgePriceType == 'percent') {
        badWeatherChargeForToolTip = (deliveryCharge * (surgePrice / 100));
        deliveryCharge = deliveryCharge + (deliveryCharge * (surgePrice / 100));
      } else {
        badWeatherChargeForToolTip = surgePrice;
        deliveryCharge = deliveryCharge + surgePrice;
      }
    }

    return deliveryCharge;
  }

  double calculateDeliveryCharge({
    required Store? store,
    required AddressModel address,
    required double? distance,
    required double? extraCharge,
    required double orderAmount,
    required String orderType,
    double? surgePrice,
    String? surgePriceType,
  }) {
    double deliveryCharge = calculateOriginalDeliveryCharge(
      store: store,
      address: address,
      distance: distance,
      extraCharge: extraCharge,
      surgePrice: surgePrice,
      surgePriceType: surgePriceType,
    );

    final ConfigModel configModel = Get.find<SplashController>().configModel;

    final xpController = Get.find<XpController>();
    final hasXpFreeDelivery =
        xpController.selectedCheckoutPrize != null &&
        xpController.selectedCheckoutPrize!.isFreeDelivery;

    // The sentinel stops here. calculateOriginalDeliveryCharge returns -1 for
    // "not computable" (no store, or no distance yet), and calculateTotal adds
    // whatever it is handed — so the sentinel used to show up as a one-pound
    // discount on the displayed total. The screen guards SUBMISSION on -1
    // (checkout_screen.dart:1021) but not the figure it renders while the user
    // waits for a distance. Callers that need to distinguish "not yet known"
    // from "free" read originalDeliveryCharge, which still carries it.
    if (deliveryCharge < 0) {
      deliveryCharge = 0;
    }

    if (orderType == 'take_away' ||
        (store != null && store.freeDelivery!) ||
        (configModel.adminFreeDelivery?.status == true &&
            (configModel.adminFreeDelivery?.type != null &&
                configModel.adminFreeDelivery?.type ==
                    'free_delivery_to_all_store')) ||
        (configModel.adminFreeDelivery?.status == true &&
            (configModel.adminFreeDelivery?.type != null &&
                configModel.adminFreeDelivery?.type ==
                    'free_delivery_by_order_amount') &&
            (configModel.adminFreeDelivery?.freeDeliveryOver != null &&
                orderAmount >=
                    configModel.adminFreeDelivery!.freeDeliveryOver!)) ||
        Get.find<CouponController>().freeDelivery ||
        hasXpFreeDelivery) {
      deliveryCharge = 0;
    }

    return PriceConverter.toFixed(deliveryCharge);
  }

  double calculateTotal({
    required double subTotal,
    required double deliveryCharge,
    required double discount,
    required double couponDiscount,
    required bool taxIncluded,
    required double tax,
    required String orderType,
    required double tips,
    required double additionalCharge,
    required double extraPackagingCharge,
  }) {
    return PriceConverter.toFixed(
      subTotal +
          deliveryCharge -
          discount -
          couponDiscount +
          (taxIncluded ? 0 : tax) +
          ((orderType != 'take_away' &&
                  Get.find<SplashController>().configModel.dmTipsStatus == 1)
              ? tips
              : 0) +
          additionalCharge +
          extraPackagingCharge,
    );
  }

  double calculateReferralDiscount(
    double subTotal,
    double discount,
    double couponDiscount,
  ) {
    double referralDiscount = 0;
    if (Get.find<ProfileController>().userInfoModel != null &&
        Get.find<ProfileController>().userInfoModel!.isValidForDiscount!) {
      if (Get.find<ProfileController>().userInfoModel!.discountAmountType! ==
          "percentage") {
        referralDiscount =
            (Get.find<ProfileController>().userInfoModel!.discountAmount! /
                100) *
            (subTotal - discount - couponDiscount);
      } else {
        referralDiscount =
            Get.find<ProfileController>().userInfoModel!.discountAmount!;
      }
    }
    return PriceConverter.toFixed(referralDiscount);
  }

  double calculateExtraPackagingCharge(CheckoutController checkoutController) {
    if ((checkoutController.store?.extraPackagingStatus ?? true) &&
        (Get.find<CartController>().needExtraPackage)) {
      return checkoutController.store?.extraPackagingAmount ?? 0;
    }
    return 0;
  }

  Pivot? getModuleData({required Store? store}) {
    Pivot? moduleData;
    if (store != null) {
      for (ZoneData zData
          in AddressHelper.getUserAddressFromSharedPref()!.zoneData!) {
        for (Modules m in zData.modules!) {
          if (m.id == Get.find<SplashController>().module!.id &&
              m.pivot!.zoneId == store.zoneId) {
            moduleData = m.pivot;
            break;
          }
        }
      }
    }
    return moduleData;
  }

  bool checkCODActive({required Store? store}) {
    bool isCashOnDeliveryActive = false;
    // Having no saved address is a normal state — first run, and every launch
    // until the location gate resolves one (see AddressHelper). This used to
    // bang through the nullable read and the zone list, so a signed-in user
    // whose address had not loaded yet got a thrown exception in the payment
    // section rather than "no methods available".
    final List<ZoneData>? zones =
        AddressHelper.getUserAddressFromSharedPref()?.zoneData;
    if (store != null && zones != null) {
      for (ZoneData zData in zones) {
        if (zData.id == store.zoneId) {
          isCashOnDeliveryActive =
              (zData.cashOnDelivery ?? false) &&
              (Get.find<SplashController>().configModelOrNull?.cashOnDelivery ??
                  false);
        }
      }
    }
    return isCashOnDeliveryActive;
  }

  bool checkDigitalPaymentActive({required Store? store}) {
    bool isDigitalPaymentActive = false;
    // Same nullable-address reasoning as checkCODActive above.
    final List<ZoneData>? zones =
        AddressHelper.getUserAddressFromSharedPref()?.zoneData;
    if (store != null && zones != null) {
      for (ZoneData zData in zones) {
        if (zData.id == store.zoneId) {
          isDigitalPaymentActive =
              (zData.digitalPayment ?? false) &&
              (Get.find<SplashController>().configModelOrNull?.digitalPayment ??
                  false);
        }
      }
    }
    return isDigitalPaymentActive;
  }

  bool checkZoneOfflinePaymentOnOff({
    required AddressModel? addressModel,
    required CheckoutController checkoutController,
  }) {
    bool? status = false;
    ZoneData? zoneData;
    for (var data in addressModel!.zoneData!) {
      if (data.id == checkoutController.store?.zoneId) {
        zoneData = data;
        break;
      }
    }
    status = zoneData?.offlinePayment ?? false;
    return status;
  }
}
