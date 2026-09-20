import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:get/get.dart';
import 'package:waddy_app/util/money.dart';
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
        Get.find<SplashController>().configModelOrNull?.currencySymbolDirection ==
        'right';
    String currencySymbol = _getCurrencySymbol();

    return '${isRightSide ? '' : '$currencySymbol '}'
        '${formatedStringPrice ?? toFixed(price!).toStringAsFixed(forDM ? 0 : _digitsAfterDecimal).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
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
        Get.find<SplashController>().configModelOrNull?.currencySymbolDirection ==
        'right';
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedFlipCounter(
        duration: const Duration(milliseconds: 500),
        value: toFixed(price!),
        textStyle: textStyle ?? waddyMedium,
        fractionDigits: forDM ? 0 : _digitsAfterDecimal,
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

  /// Rounds a price the way the server does.
  ///
  /// This used to `.floor()`, which truncated: 10.999 displayed as 10.99 while
  /// `PlaceNewOrder.php` rounded the same value to 11.00 and charged that. The
  /// customer saw one total and paid another, on every order. The backend uses
  /// PHP `round()` for `order_amount`, `delivery_charge`, `total_tax_amount`
  /// and every per-item price, so the client must match it exactly — see
  /// [roundLikeServer] and `test/contract/rounding_parity_test.dart`.
  static double toFixed(double val) {
    return roundLikeServer(val, _digitsAfterDecimal);
  }

  /// Digits the server is configured to round to.
  ///
  /// Both sides read the same business setting: the backend's
  /// `round_up_to_digit` is served to the app as `digit_after_decimal_point`
  /// (ConfigController). Falls back to 2 rather than throwing — a config that
  /// has not loaded should not crash price formatting, which runs on nearly
  /// every screen.
  static int get _digitsAfterDecimal =>
      Get.find<SplashController>().configModelOrNull?.digitAfterDecimalPoint ?? 2;
}
