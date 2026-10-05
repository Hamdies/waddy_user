import 'dart:math' as math;
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
        Get.find<SplashController>()
            .configModelOrNull
            ?.currencySymbolDirection ==
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
        Get.find<SplashController>()
            .configModelOrNull
            ?.currencySymbolDirection ==
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

  /// Rounds a list of amounts for DISPLAY so the rounded parts add up to the
  /// rounded whole (largest-remainder rounding).
  ///
  /// Rounding each line on its own does not: 33.75 + 82.5 shows as 34 + 83 =
  /// 117 next to a total of 116.25 → 116, and a customer adding up the cart
  /// finds it 1 LE off. The server charges the rounded whole (it sums the
  /// unrounded lines, `PlaceNewOrder.php`), so the whole is the fixed point
  /// and the lines give way: the line with the largest rounding remainder
  /// takes the extra unit. Display only — never feed these back into pricing.
  static List<double> allocateRounded(List<double> values, {int? digits}) {
    if (values.isEmpty) return const [];
    digits ??= _digitsAfterDecimal;
    final double scale = math.pow(10, digits).toDouble();
    final List<double> scaled = [for (final v in values) v * scale];
    final List<int> floors = [for (final v in scaled) v.floor()];
    final int target =
        (roundLikeServer(values.fold(0.0, (a, b) => a + b), digits) * scale)
            .round();
    int diff = target - floors.fold(0, (a, b) => a + b);
    final List<int> order = List<int>.generate(
      values.length,
      (i) => i,
    )..sort((a, b) => (scaled[b] - floors[b]).compareTo(scaled[a] - floors[a]));
    for (int k = 0; diff > 0 && k < order.length; k++, diff--) {
      floors[order[k]] += 1;
    }
    for (int k = order.length - 1; diff < 0 && k >= 0; k--, diff++) {
      floors[order[k]] -= 1;
    }
    return [for (final f in floors) f / scale];
  }

  /// Digits the server is configured to round to.
  ///
  /// Both sides read the same business setting: the backend's
  /// `round_up_to_digit` is served to the app as `digit_after_decimal_point`
  /// (ConfigController). Falls back to 2 rather than throwing — a config that
  /// has not loaded should not crash price formatting, which runs on nearly
  /// every screen.
  static int get _digitsAfterDecimal =>
      Get.find<SplashController>().configModelOrNull?.digitAfterDecimalPoint ??
      2;
}
