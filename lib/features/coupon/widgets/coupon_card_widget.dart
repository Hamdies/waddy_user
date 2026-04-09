import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/coupon/domain/models/coupon_model.dart';
import 'package:waddy_app/features/coupon/widgets/scratch_card_dialog.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/styles.dart';

class CouponCardWidget extends StatelessWidget {
  final CouponModel coupon;
  final int index;

  const CouponCardWidget({
    super.key,
    required this.coupon,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor; // Dark teal
    final accentColor = Theme.of(context).colorScheme.secondary; // Neon green

    final expiryText =
        coupon.expireDate != null
            ? DateConverter.stringToReadableString(coupon.expireDate!)
            : '';

    return GestureDetector(
      onTap: () => showScratchCardDialog(context, coupon),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, right: 4),
        child: Stack(
          children: [
            // Neo shadow (hard offset)
            Positioned(
              bottom: 0,
              right: 0,
              left: 4,
              top: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            // Main card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primaryColor, width: 2.5),
              ),
              child: Row(
                children: [
                  // Left - Mystery badge (hidden until scratched)
                  Container(
                    width: 85,
                    height: 75,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryColor, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '?',
                          style: robotoBold.copyWith(
                            fontSize: 32,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          'MYSTERY',
                          style: robotoBold.copyWith(
                            fontSize: 9,
                            color: primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Right - Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Title row with scratch badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                coupon.title ?? 'Special Offer',
                                style: robotoBold.copyWith(
                                  fontSize: 15,
                                  color: primaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildNeoBadge(
                              'Scratch',
                              primaryColor,
                              accentColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Expiry
                        if (expiryText.isNotEmpty)
                          _buildInfoRow(
                            Icons.schedule_rounded,
                            expiryText,
                            Colors.grey[600]!,
                          ),
                        const SizedBox(height: 4),

                        // Min purchase
                        _buildInfoRow(
                          Icons.shopping_bag_outlined,
                          '${'min_purchase'.tr}: ${PriceConverter.convertPrice(coupon.minPurchase)}',
                          Colors.grey[600]!,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeoBadge(String text, Color primary, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: primary, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, color: accent, size: 12),
          const SizedBox(width: 4),
          Text(text, style: robotoBold.copyWith(fontSize: 10, color: accent)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: robotoRegular.copyWith(fontSize: 11, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
