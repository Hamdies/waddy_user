part of '../food_store_screen.dart';

/// Name, store type, address, rating, delivery stats and offers under the
/// hero. Moved out of food_store_screen.dart unchanged.
extension _FoodStoreHeader on _FoodStoreScreenState {
  // ═══════════════════════════════════════════
  // HEADER — name, rating card, stats strip, promo
  // ═══════════════════════════════════════════
  Widget _buildStoreHeader(BuildContext context, Store store) {
    final bool hasRating = (store.avgRating ?? 0) > 0;
    final String cuisines = (store.cuisineNames ?? const <String>[])
        .where((c) => c.trim().isNotEmpty)
        .join(', ');

    // "0.4 km away · Road 9, Maadi" — either half can be absent, so build the
    // parts and join rather than hardcoding the separator.
    //
    // Distance leads. The line is clamped to one row, and an Egyptian address
    // ("Road 9, Maadi Sarayat, Cairo Governorate") is long enough to eat the
    // whole row on its own — putting the address first truncated the distance
    // mid-number and rendered "… · 3143.6…". The short, high-value half is the
    // one that has to survive the ellipsis.
    //
    // The distance is also gated on the same plausibility ceiling
    // `StoreDeliveryFee` applies before it will quote a fee. A backend that
    // hands back 3143.6 km for a Maadi store is handing back garbage, and a
    // screen that refuses to price from a number should not print it either.
    final double? distanceKm =
        (store.distance ?? 0) > 0 &&
                store.distance! <= StoreDeliveryFee.maxPlausibleKm
            ? store.distance
            : null;

    final List<String> whereParts = [
      if (distanceKm != null)
        '${distanceKm.toStringAsFixed(1)} ${'km'.tr} ${'away'.tr}',
      if ((store.address ?? '').trim().isNotEmpty) store.address!.trim(),
    ];

    return Padding(
      // Top pad clears the logo tile overhanging the cover.
      padding: const EdgeInsets.fromLTRB(15, 46, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name ?? '',
                      style: waddyBold.copyWith(
                        fontSize: 26,
                        color: WaddyColors.ink,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                    // For a shop this is its store type ("Butchers &
                    // seafood"): grocery store types are cuisines server-side.
                    if (cuisines.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        cuisines,
                        style: waddyMedium.copyWith(
                          fontSize: 14,
                          color: WaddyColors.inkMid,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (whereParts.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        whereParts.join(' · '),
                        style: waddyRegular.copyWith(
                          fontSize: 14,
                          color: WaddyColors.inkMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (hasRating) ...[
                const SizedBox(width: 12),
                _buildRatingCard(context, store),
              ],
            ],
          ),

          const SizedBox(height: 12),
          StoreStatsStrip(store: store, isShop: _isShop),

          if (_hasAnyOffer(store)) ...[
            const SizedBox(height: 10),
            _buildOfferBadges(context, store),
          ],
        ],
      ),
    );
  }

  /// The rating opens the reviews screen — it is the most-tapped number on
  /// this screen, so it must not be inert.
  Widget _buildRatingCard(BuildContext context, Store store) {
    final int count = store.ratingCount ?? 0;

    return Semantics(
      button: true,
      label: '${store.avgRating!.toStringAsFixed(1)} ${'ratings'.tr}',
      child: Material(
        color: WaddyColors.primarySurface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap:
              () => Get.to(
                () => ReviewScreen(
                  storeID: store.id.toString(),
                  storeName: store.name,
                  store: store,
                ),
              ),
          child: Container(
            width: 74,
            padding: const EdgeInsets.fromLTRB(0, 9, 0, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedStar,
                      size: 15,
                      color: WaddyColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      store.avgRating!.toStringAsFixed(1),
                      style: waddyBold.copyWith(
                        fontSize: 17,
                        color: WaddyColors.primary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                if (count > 0) ...[
                  const SizedBox(height: 2),
                  // The "+" only goes on a number that has actually been
                  // rounded DOWN to a milestone. "12+ ratings" for exactly 12
                  // is a small lie told for no gain, and it is the kind a user
                  // catches by opening the reviews screen and counting.
                  Text(
                    '${count >= 50 ? '${(count ~/ 50) * 50}+' : '$count'}'
                    '\n${'ratings'.tr}',
                    textAlign: TextAlign.center,
                    style: waddyMedium.copyWith(
                      fontSize: 11,
                      color: WaddyColors.inkMid,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // OFFERS ROW — one collar badge per promise
  // ═══════════════════════════════════════════
  //
  // Promotions are CORAL in this app, not amber.
  //
  // Amber already carries three unrelated jobs — it IS `warning`, it is the
  // in-transit order status, and it is the "soon" tag. A discount is the
  // opposite of a caution, and sharing a hue with the warning token meant the
  // happiest strip on the screen wore the app's alarm colour.
  //
  // Coral is the documented "CTAs, urgency, fun" tertiary, and the menu rows
  // below ALREADY use `coralSurface` for their per-item discount ribbons, so a
  // user scanning the screen learns "coral = a saving" exactly once.
  //
  // Free delivery is mint for the same reason, and both now use
  // [OfferCollarBadge] — the shape every offer in the app wears, so this
  // screen and the browse row that led here make the same promise the same
  // way.
  //
  /// Whether this store has anything to put on the offers row.
  static bool _hasAnyOffer(Store store) =>
      (store.discount?.discount ?? 0) > 0 ||
      store.freeDelivery == true ||
      store.minimumShippingCharge == 0;

  /// Every offer the store actually has, not just the discount.
  ///
  /// This used to be a discount-only banner, so a store whose perk was free
  /// delivery showed nothing at all here — the browse row that sent the user
  /// in promised "Free delivery" and the store page it opened stayed silent
  /// about it. Both facts are the same kind of promise, so both wear the
  /// collar and both appear.
  ///
  /// Compact, and wrapped rather than rowed: two badges at full size crowded
  /// the header on a small phone, and this is a supporting line under the
  /// stats strip, not the headline of the screen.
  Widget _buildOfferBadges(BuildContext context, Store store) {
    final discount = store.discount;
    final bool hasDiscount = (discount?.discount ?? 0) > 0;
    final bool hasFreeDelivery =
        store.freeDelivery == true || store.minimumShippingCharge == 0;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (hasDiscount)
          OfferCollarBadge(
            label:
                '${discount!.discountType == 'percent' ? '${discount.discount!.toInt()}%' : PriceConverter.convertPrice(discount.discount!)} ${'off_select_items'.tr}',
            tone: OfferCollarTone.sale,
            compact: true,
          ),
        if (hasFreeDelivery)
          OfferCollarBadge(
            label: 'free_delivery'.tr,
            tone: OfferCollarTone.delivery,
            compact: true,
          ),
      ],
    );
  }
}
