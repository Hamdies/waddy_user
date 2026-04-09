import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

enum VerificationCodeVariant { standard, compact }

class VerificationCodeWidget extends StatelessWidget {
  final String otp;
  final VerificationCodeVariant variant;

  const VerificationCodeWidget({
    super.key,
    required this.otp,
    this.variant = VerificationCodeVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    return variant == VerificationCodeVariant.standard
        ? _buildStandard(context)
        : _buildCompact(context);
  }

  Widget _buildStandard(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 16,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          'delivery_verification_code'.tr,
          style: robotoMedium.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeSmall,
            vertical: Dimensions.paddingSizeExtraSmall,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            otp.split('').join(' '),
            style: robotoBold.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              color: Theme.of(context).primaryColor,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    final bool isSmallScreen = MediaQuery.sizeOf(context).width < 380;

    return Align(
      alignment: Alignment.center,
      child: Container(
       width: double.infinity,
       height: isSmallScreen ? 60 : 70,
        decoration: BoxDecoration(
          color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isSmallScreen ? 24 : 26,
                  height: isSmallScreen ? 24 : 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF184541),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: const Color(0xFF6FCF97),
                    size: isSmallScreen ? 14 : 15,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VERIFICATION CODE',
                      style: robotoBold.copyWith(
                        fontSize: isSmallScreen ? 7.5 : 8.5,
                        color: const Color(0xFF112E2C),
                        height: 1,
                      ),
                    ),
                    Text(
                      'SHARE WITH DRIVER ONLY',
                      style: robotoRegular.copyWith(
                        fontSize: isSmallScreen ? 5.5 : 6.5,
                        color: const Color(0xFF4A6B66),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: otp.split('').map((digit) {
                return Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 2.5 : 3,
                  ),
                  width: isSmallScreen ? 22 : 24,
                  height: isSmallScreen ? 26 : 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    digit,
                    style: robotoBold.copyWith(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: const Color(0xFF112E2C),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
