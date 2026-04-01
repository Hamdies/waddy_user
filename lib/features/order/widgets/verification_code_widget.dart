import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

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
          padding: EdgeInsets.symmetric(
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
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
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
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF184541),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF6FCF97),
                    size: 15,
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VERIFICATION CODE',
                      style: robotoBold.copyWith(
                        fontSize: 8,
                        color: const Color(0xFF112E2C),
                      ),
                    ),
                    Text(
                      'SHARE WITH DRIVER ONLY',
                      style: robotoRegular.copyWith(
                        fontSize: 6,
                        color: const Color(0xFF4A6B66),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: otp.split('').map((digit) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 24,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
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
                      fontSize: 10,
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
