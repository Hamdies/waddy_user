import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class OrderEtaBadge extends StatelessWidget {
  final int? minutes;

  const OrderEtaBadge({super.key, required this.minutes});

  @override
  Widget build(BuildContext context) {
    final int minEta = minutes ?? 0;
    final int maxEta = minEta > 0 ? minEta + 10 : 0;

    final double badgeSize = ResponsiveHelper.isMobile(context) ? 160 : 200;
    final double badgeFontSize = ResponsiveHelper.isMobile(context) ? 12 : 14;
    final double badgeEtaFontSize =
        ResponsiveHelper.isMobile(context) ? 36 : 44;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: badgeSize,
          height: badgeSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C5B54), Color(0xFF163F41)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A262A).withValues(alpha: 0.40),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'arrival_in'.tr,
                style: robotoRegular.copyWith(
                  fontSize: badgeFontSize,
                  color: Colors.white.withValues(alpha: 0.92),
                  letterSpacing: 0.6,
                ),
              ),
              SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(
                minEta > 0 ? '$minEta-$maxEta' : '--',
                style: robotoBold.copyWith(
                  fontSize: badgeEtaFontSize,
                  color: const Color(0xFF1EF2A0),
                  height: 0.95,
                ),
              ),
              SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Text(
                'mins'.tr,
                style: robotoRegular.copyWith(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.92),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -18,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.isMobile(context) ? 24 : 32,
              vertical: Dimensions.paddingSizeExtraSmall,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: const Color(0xFF1EF2A0).withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1EF2A0).withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'on_time'.tr,
              style: robotoBold.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: const Color(0xFF184541),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
