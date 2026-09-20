import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class Dimensions {
  // Type scale — Major Third (×1.25) from base 14sp
  static double fontSizeOverSmall =
      Get.context!.width >= 1300 ? 12 : 10; // micro
  static double fontSizeExtraSmall =
      Get.context!.width >= 1300 ? 14 : 12; // label
  static double fontSizeSmall =
      Get.context!.width >= 1300 ? 16 : 14; // body (base)
  static double fontSizeDefault = Get.context!.width >= 1300 ? 16 : 14; // body
  static double fontSizeLarge = Get.context!.width >= 1300 ? 20 : 18; // title
  static double fontSizeExtraLarge =
      Get.context!.width >= 1300 ? 26 : 22; // headline
  static double fontSizeOverLarge =
      Get.context!.width >= 1300 ? 34 : 28; // display

  // Spacing — 4pt grid
  static const double paddingSizeExtraSmall = 4.0;
  static const double paddingSizeSmall = 8.0;
  static const double paddingSizeMedium = 12.0;
  static const double paddingSizeDefault = 16.0;
  static const double paddingSizeLarge = 20.0;
  static const double paddingSizeExtraLarge = 24.0;
  static const double paddingSizeExtremeLarge = 32.0;
  static const double paddingSizeExtraOverLarge = 40.0;

  // Corner radius — 4pt grid, aligned with AppDesignTokens
  static const double radiusExtraSmall = 4.0; // progress bars, indicators
  static const double radiusSmall = 8.0; // badges, chips, small inputs
  static const double radiusMedium = 8.0;
  static const double radiusDefault = 12.0; // buttons, standard containers
  static const double radiusLarge = 16.0; // cards
  static const double radiusExtraLarge = 24.0; // modals, bottom sheets

  /// Space a scrolling page must leave below its last element so the
  /// dashboard's bottom nav never covers content.
  ///
  /// The nav is a Stack overlay, not a `bottomNavigationBar`, so nothing
  /// subtracts it from the scroll view's constraints — every page has to
  /// reserve it by hand. Callers used to hardcode 80, which is a guess that
  /// only lands on one class of device: the bar is 58 plus the gesture inset,
  /// so 80 leaves 22 of slack on a 3-button phone and runs 12 *under* the bar
  /// on a gesture-nav one, clipping the last row of the feed.
  static double bottomNavReserve(BuildContext context) =>
      58 + MediaQuery.paddingOf(context).bottom + paddingSizeLarge;

  /// Space a scrolling page must leave when `PillCartBar` is the bottom bar
  /// instead of the nav — on food/grocery, where the cart bar REPLACES the nav.
  ///
  /// The pill is 56 with 12 above and below, and the reward strip adds ~46 more
  /// when it is showing. This reserves for BOTH tiers: a page that reserved
  /// only the pill clipped its last row every time the strip appeared, and the
  /// strip appears on most stores. Screens that can measure the bar's real
  /// height should prefer that (see `PillCartBar.onHeightChanged`); this is the
  /// fixed fallback for feeds that cannot.
  static double cartBarReserve(BuildContext context) =>
      126 + MediaQuery.paddingOf(context).bottom;

  /// Smallest square a tappable control may occupy, per Material's touch
  /// guidance. The *visual* may be smaller — see `Pressable.minSize`, which
  /// grows the hit box without redrawing the control.
  static const double minTapTarget = 48;

  /// Upper bound on content width, applied as `SizedBox(width: maxContentWidth)`
  /// around page bodies.
  ///
  /// Was `maxContentWidth`, sized for the desktop web shell that no longer exists.
  /// It is kept rather than deleted because it is not dead: a `SizedBox` width
  /// is clamped by the parent's constraints, so on a phone (<= ~440pt) this
  /// resolves to "fill the available width" at every call site. Dropping it or
  /// swapping in `double.infinity` would change behaviour anywhere the parent
  /// hands down unbounded width, so only the misleading name changed.
  static const double maxContentWidth = 1170;
  static const int messageInputLength = 1000;

  static const double pickMapIconSize = 100.0;
}
