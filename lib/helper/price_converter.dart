import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:get/get.dart';
import 'package:waddy_app/util/styles.dart';

class PriceConverter {
  /// Returns localized currency symbol: "LE" for English, "ج.م" for Arabic
  static String _getCurrencySymbol() {
    final locale = Get.locale?.languageCode ?? 'en';
    if (locale == 'ar') {
      return 'ج.م';
    }
    return 'LE'; // Default to "LE" (Egyptian Pounds) instead of "E£"
  }

  static String convertPrice(
    double? price, {
    double? discount,
    String? discountType,
    bool forDM = false,
    bool isFoodVariation = false,
    String? formatedStringPrice,
  }) {
    if (discount != null && discountType != null) {
      if (discountType == 'amount' && !isFoodVariation) {
        price = price! - discount;
      } else if (discountType == 'percent') {
        price = price! - ((discount / 100) * price);
      }
    }
    bool isRightSide =
        Get.find<SplashController>().configModel!.currencySymbolDirection ==
        'right';
    String currencySymbol = _getCurrencySymbol();

    return '${isRightSide ? '' : '$currencySymbol '}'
        '${formatedStringPrice ?? toFixed(price!).toStringAsFixed(forDM ? 0 : Get.find<SplashController>().configModel!.digitAfterDecimalPoint!).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
        '${isRightSide ? ' $currencySymbol' : ''}';
  }

  static Widget convertAnimationPrice(
    double? price, {
    double? discount,
    String? discountType,
    bool forDM = false,
    TextStyle? textStyle,
  }) {
    if (discount != null && discountType != null) {
      if (discountType == 'amount') {
        price = price! - discount;
      } else if (discountType == 'percent') {
        price = price! - ((discount / 100) * price);
      }
    }
    bool isRightSide =
        Get.find<SplashController>().configModel!.currencySymbolDirection ==
        'right';
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedFlipCounter(
        duration: const Duration(milliseconds: 500),
        value: toFixed(price!),
        textStyle: textStyle ?? robotoMedium,
        fractionDigits:
            forDM
                ? 0
                : Get.find<SplashController>()
                    .configModel!
                    .digitAfterDecimalPoint!,
        prefix: isRightSide ? '' : '${_getCurrencySymbol()} ',
        suffix: isRightSide ? '${_getCurrencySymbol()} ' : '',
      ),
    );
  }

  static double? convertWithDiscount(
    double? price,
    double? discount,
    String? discountType, {
    bool isFoodVariation = false,
  }) {
    if (discountType == 'amount' && !isFoodVariation) {
      price = price! - discount!;
    } else if (discountType == 'percent') {
      price = price! - ((discount! / 100) * price);
    }
    return price;
  }

  static double calculation(
    double amount,
    double? discount,
    String type,
    int quantity,
  ) {
    double calculatedAmount = 0;
    if (type == 'amount' || type == 'fixed') {
      calculatedAmount = discount! * quantity;
    } else if (type == 'percent') {
      calculatedAmount = (discount! / 100) * (amount * quantity);
    }
    return calculatedAmount;
  }

  static String percentageCalculation(
    String price,
    String discount,
    String discountType,
  ) {
    return '$discount${discountType == 'percent' ? '%' : _getCurrencySymbol()} OFF';
  }

  static double toFixed(double val) {
    num mod = power(
      10,
      Get.find<SplashController>().configModel!.digitAfterDecimalPoint!,
    );
    return (((val * mod).toPrecision(
          Get.find<SplashController>().configModel!.digitAfterDecimalPoint!,
        )).floor().toDouble() /
        mod);
  }

  static int power(int x, int n) {
    int retval = 1;
    for (int i = 0; i < n; i++) {
      retval *= x;
    }
    return retval;
  }
}
