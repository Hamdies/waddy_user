import 'package:get/get.dart';

class Dimensions {
  // Type scale — Major Third (×1.25) from base 14sp
  static double fontSizeOverSmall = Get.context!.width >= 1300 ? 12 : 10;   // micro
  static double fontSizeExtraSmall = Get.context!.width >= 1300 ? 14 : 12;  // label
  static double fontSizeSmall = Get.context!.width >= 1300 ? 16 : 14;       // body (base)
  static double fontSizeDefault = Get.context!.width >= 1300 ? 16 : 14;     // body
  static double fontSizeLarge = Get.context!.width >= 1300 ? 20 : 18;       // title
  static double fontSizeExtraLarge = Get.context!.width >= 1300 ? 26 : 22;  // headline
  static double fontSizeOverLarge = Get.context!.width >= 1300 ? 34 : 28;   // display

  static const double paddingSizeExtraSmall = 5.0;
  static const double paddingSizeSmall = 10.0;
  static const double paddingSizeDefault = 15.0;
  static const double paddingSizeLarge = 20.0;
  static const double paddingSizeExtraLarge = 25.0;
  static const double paddingSizeExtremeLarge = 30.0;
  static const double paddingSizeExtraOverLarge = 35.0;

  static const double radiusSmall = 5.0;
  static const double radiusMedium = 8.0;
  static const double radiusDefault = 10.0;
  static const double radiusLarge = 15.0;
  static const double radiusExtraLarge = 20.0;

  static const double webMaxWidth = 1170;
  static const int messageInputLength = 1000;

  static const double pickMapIconSize = 100.0;
}
