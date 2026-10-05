import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/scratch_card/widgets/scratch_flip_card.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// "A lucky card comes in the bag with your order": how the printed card
/// works, in three steps. Opened from any scratch-card teaser.
class ScratchCardSheet extends StatelessWidget {
  const ScratchCardSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x8C0A1412),
      builder: (_) => const ScratchCardSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        Dimensions.paddingSizeExtraLarge,
        Dimensions.paddingSizeSmall,
        Dimensions.paddingSizeExtraLarge,
        Dimensions.paddingSizeExtremeLarge + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimensions.radiusExtraLarge),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: WaddyColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            Container(
              height: 170,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: WaddyColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const ScratchFlipCard(width: 115, height: 130),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            Text(
              'scratch_sheet_label'.tr,
              textAlign: TextAlign.center,
              style: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: WaddyColors.mintInk,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            Text(
              'scratch_sheet_title'.tr,
              textAlign: TextAlign.center,
              style: waddyBold.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: WaddyColors.ink,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            for (int i = 1; i <= 3; i++) ...[
              if (i > 1) const SizedBox(height: Dimensions.paddingSizeMedium),
              _Step(number: i, text: 'scratch_sheet_step$i'.tr),
            ],
            const SizedBox(height: Dimensions.paddingSizeLarge),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: WaddyColors.mint,
                  foregroundColor: WaddyColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault + 2,
                    ),
                  ),
                ),
                child: Text(
                  'scratch_sheet_got_it'.tr,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    fontWeight: FontWeight.w800,
                    color: WaddyColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeMedium),
            Text(
              'scratch_sheet_terms'.tr,
              textAlign: TextAlign.center,
              style: waddyMedium.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: WaddyColors.inkLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;
  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: WaddyColors.mintSurface,
          ),
          child: Text(
            '$number',
            style: waddyBold.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              fontWeight: FontWeight.w800,
              color: WaddyColors.mintInk,
            ),
          ),
        ),
        const SizedBox(width: Dimensions.paddingSizeMedium),
        Expanded(
          child: Text(
            text,
            style: waddyMedium.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              height: 1.4,
              color: WaddyColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
