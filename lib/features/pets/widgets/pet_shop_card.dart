import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/common/widgets/card_design/store_list_card.dart'
    show kMinRatingsToShow;
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_row_card.dart'
    show kMaxPlausibleDeliveryKm;
import 'package:waddy_app/features/location/widgets/coming_soon_delivery.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// A pet shop on the hub, as the design draws it (screen 01 "Pet shops near
/// you"): cover photo with the deal badge on it, the logo overlapping its
/// bottom edge, then name, "★ 4.8 · 600 m · EGP 15 delivery" and the ETA
/// pill.
///
/// Keeps the rules the food/grocery row card established: a rating only
/// once enough reviews stand behind it, no implausible distance, a closed
/// shop dimmed, and out of zone the fee/ETA collapse to "Coming soon".
class PetShopCard extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;

  const PetShopCard({super.key, required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool open = store.open == 1;
    final String? deal = _deal;

    final Widget card = Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 14),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge - 4),
        border: Border.all(color: WaddyColors.divider, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 132,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                    child: CustomImage(
                      image: store.coverPhotoFullUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (deal != null)
                  PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 26),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: WaddyColors.primary,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedPawPrint,
                            size: 12,
                            color: WaddyColors.mint,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            deal,
                            style: waddyBold.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: WaddyColors.mint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                PositionedDirectional(
                  start: 12,
                  bottom: -18,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: WaddyColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: WaddyColors.surface, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: WaddyColors.primary.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CustomImage(
                        image: store.logoFullUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyBold.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: displayTracking(-0.3),
                          color: WaddyColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ZoneAware(
                        builder:
                            (_) => Text(
                              _meta(includeFee: !isComingSoon),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: waddyRegular.copyWith(
                                fontSize: 12,
                                color: WaddyColors.inkLight,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                ZoneAware(
                  builder: (_) {
                    if (isComingSoon) return const ComingSoonChip();
                    final String? eta = _eta;
                    if (eta == null) return const SizedBox.shrink();
                    return Container(
                      constraints: const BoxConstraints(minHeight: 28),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            open
                                ? WaddyColors.mintSurfaceDeep
                                : WaddyColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        open ? eta : 'closed'.tr,
                        style: waddyBold.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color:
                              open ? WaddyColors.primary : WaddyColors.inkLight,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeMedium),
      child: Pressable(
        onTap: onTap,
        semanticLabel: store.name,
        scale: WaddyMotion.pressCard,
        child: open ? card : Opacity(opacity: 0.7, child: card),
      ),
    );
  }

  /// "15% off" on the cover, or "Free delivery" when that's the perk.
  String? get _deal {
    final Discount? discount = store.discount;
    final double value = discount?.discount ?? 0;
    if (value > 0) {
      return discount!.discountType == 'percent'
          ? '${value.toStringAsFixed(0)}% ${'off'.tr}'
          : '${PriceConverter.convertPrice(value)} ${'off'.tr}';
    }
    if (_freeDelivery) return 'free_delivery'.tr;
    return null;
  }

  bool get _freeDelivery =>
      store.freeDelivery == true || store.minimumShippingCharge == 0;

  /// "★ 4.8 · 600 m · EGP 15 delivery", each part only when it's true.
  String _meta({required bool includeFee}) {
    final double? rating = store.avgRating;
    final bool showRating =
        rating != null &&
        rating > 0 &&
        (store.ratingCount ?? 0) >= kMinRatingsToShow;
    final double? km = store.distance;
    final String? distance =
        km == null || km <= 0 || km > kMaxPlausibleDeliveryKm
            ? null
            : km < 1
            ? 'distance_m'.trParams({'n': '${(km * 1000).round()}'})
            : 'distance_km'.trParams({'n': km.toStringAsFixed(1)});
    final double? fee = store.minimumShippingCharge;
    return [
      if (showRating) '★ ${rating.toStringAsFixed(1)}',
      if (distance != null) distance,
      if (includeFee)
        _freeDelivery
            ? 'free_delivery'.tr
            : fee == null
            ? null
            : 'pet_shop_fee'.trParams({
              'fee': PriceConverter.convertPrice(fee),
            }),
    ].whereType<String>().join(' · ');
  }

  String? get _eta {
    final String? raw = store.deliveryTime?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.contains('min') ? raw : '$raw ${'min'.tr}';
  }
}
