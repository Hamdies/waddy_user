import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// Full-section error card shown when the home data failed to load and there
/// is nothing renderable — neubrutalist panel with a mint RETRY.
class SpotsErrorCard extends StatelessWidget {
  const SpotsErrorCard({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: Spots.card(),
      padding: const EdgeInsets.all(Spots.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 32, color: Spots.ink3),
          const SizedBox(height: Spots.s12),
          Text('spots_error_title'.tr, style: Spots.display(20)),
          const SizedBox(height: Spots.s8),
          Text(
            'spots_error_body'.tr,
            style: waddyRegular.copyWith(
              fontSize: 13,
              color: Spots.ink2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: Spots.s16),
          SpotsPressable(
            onTap: onRetry,
            dx: 3,
            dy: 3,
            radius: Spots.radiusMd,
            child: Container(
              decoration: Spots.card(
                fill: Spots.mint,
                radius: Spots.radiusMd,
                borderWidth: Spots.borderThin,
                dx: 0,
                dy: 0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: Spots.s20,
                vertical: Spots.s12,
              ),
              child: Text(
                displayCaps('spots_retry'.tr),
                style: Spots.display(13, tracking: 0.02),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
