import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/location/widgets/coming_soon_delivery.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Visual language of the sticker set — food uses playful long labels,
/// grocery uses terse ones. Same rules, different skins.
enum ModuleStickerStyle { food, grocery }

class ModuleStickerData {
  final String text;
  final IconData? icon;
  final Color bgColor;
  final Color textColor;
  final double rotation;

  const ModuleStickerData({
    required this.text,
    this.icon,
    required this.bgColor,
    required this.textColor,
    this.rotation = 0.0,
  });
}

/// Parses "30-45", "10-20 min", "1-2 hours" into the max minutes, or null.
int? maxDeliveryMinutes(String? deliveryTime) {
  if (deliveryTime == null || deliveryTime.isEmpty) return null;
  final parts = deliveryTime.split('-');
  final digits = parts.last.replaceAll(RegExp(r'[^0-9]'), '');
  final value = int.tryParse(digits);
  if (value == null) return null;
  return deliveryTime.contains('hour') ? value * 60 : value;
}

List<ModuleStickerData> moduleStickersForStore(
  Store store,
  ModuleStickerStyle style,
) {
  final bool food = style == ModuleStickerStyle.food;
  final stickers = <ModuleStickerData>[];

  // Out of zone, suppress only the DELIVERY claims ("Speedy", "Under 30 min",
  // "Free delivery") — they'd contradict the "Coming soon" chip on the same
  // card. Rating and discount stickers stay: they're true regardless of whether
  // we deliver there yet, and keeping them is the point of letting people
  // browse in the first place.
  final bool outOfZone = isComingSoon;

  if (store.featured == 1 && !outOfZone) {
    stickers.add(
      ModuleStickerData(
        text: food ? 'sticker_speedy'.tr : 'sticker_fast'.tr,
        icon: food ? Icons.delivery_dining_rounded : Icons.electric_bolt,
        bgColor: const Color(0xFF134E4A),
        textColor: const Color(0xFF1EF2A0),
        rotation: food ? -0.08 : -0.05,
      ),
    );
  }

  final maxTime = maxDeliveryMinutes(store.deliveryTime);
  if (maxTime != null && maxTime <= 30 && !outOfZone) {
    stickers.add(
      ModuleStickerData(
        text: food ? 'sticker_quick_bites'.tr : 'sticker_30_min'.tr,
        icon: food ? Icons.timer_rounded : Icons.schedule_rounded,
        bgColor: const Color(0xFFFFD600),
        textColor: const Color(0xFF3E2700),
        rotation: food ? 0.1 : 0.06,
      ),
    );
  }

  if (store.freeDelivery == true && !outOfZone) {
    stickers.add(
      ModuleStickerData(
        text: food ? 'sticker_free_delivery'.tr : 'sticker_free'.tr,
        icon:
            food
                ? Icons.delivery_dining_outlined
                : Icons.local_shipping_rounded,
        bgColor: const Color(0xFFFF5252),
        textColor: Colors.white,
        rotation: food ? -0.06 : -0.04,
      ),
    );
  }

  if (store.discount != null &&
      store.discount!.discount != null &&
      store.discount!.discount! > 0) {
    stickers.add(
      ModuleStickerData(
        text: food ? 'sticker_hot_deals'.tr : 'sticker_deal'.tr,
        icon:
            food
                ? Icons.local_fire_department_rounded
                : Icons.local_offer_rounded,
        bgColor: const Color(0xFFFF6D00),
        textColor: Colors.white,
        rotation: food ? 0.08 : 0.05,
      ),
    );
  }

  if (store.avgRating != null && store.avgRating! >= 4.5) {
    stickers.add(
      ModuleStickerData(
        text: food ? 'sticker_top_rated'.tr : 'sticker_top'.tr,
        icon: food ? Icons.restaurant_rounded : Icons.workspace_premium_rounded,
        bgColor: const Color(0xFF7C4DFF),
        textColor: Colors.white,
        rotation: food ? -0.07 : -0.05,
      ),
    );
  }

  if ((store.ratingCount ?? 0) < 5 && stickers.length < 2) {
    stickers.add(
      ModuleStickerData(
        text: food ? 'sticker_new_tastes'.tr : 'sticker_new'.tr,
        icon: Icons.auto_awesome_rounded,
        bgColor: const Color(0xFF00E676),
        textColor: const Color(0xFF0D3B2E),
        rotation: food ? 0.12 : 0.07,
      ),
    );
  }

  return stickers.take(1).toList();
}

/// Flag-shaped rotated ribbon that pokes out of store cards.
class ModuleRibbonSticker extends StatelessWidget {
  final ModuleStickerData sticker;
  final bool compact;

  const ModuleRibbonSticker({
    super.key,
    required this.sticker,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: sticker.rotation,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: sticker.bgColor,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(Dimensions.radiusSmall),
            bottomStart: Radius.circular(Dimensions.radiusSmall),
            topEnd: Radius.circular(3),
            bottomEnd: Radius.circular(3),
          ),
          boxShadow: [
            BoxShadow(
              color: sticker.bgColor.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sticker.icon != null) ...[
              Icon(
                sticker.icon,
                size: compact ? 10 : 12,
                color: sticker.textColor,
              ),
              SizedBox(width: compact ? 3 : 4),
            ],
            Text(
              sticker.text,
              style: waddyBold.copyWith(
                fontSize: compact ? 8 : 9.5,
                color: sticker.textColor,
                letterSpacing: 0.6,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small icon+text pill used on card overlays (delivery time etc.).
class ModuleInfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bgColor;
  final Color textColor;

  const ModuleInfoPill({
    super.key,
    required this.icon,
    required this.text,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
        vertical: Dimensions.paddingSizeExtraSmall,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 3),
          Text(text, style: waddyBold.copyWith(fontSize: 10, color: textColor)),
        ],
      ),
    );
  }
}
