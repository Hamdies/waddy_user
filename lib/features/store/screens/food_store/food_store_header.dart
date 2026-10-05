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
          _buildStatsStrip(context, store),

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

  /// Delivery time · delivered by · fee.
  ///
  /// These render identically in and out of zone. An out-of-zone visitor is
  /// browsing, not buying: a half-empty strip told them something was wrong
  /// without telling them what, and the answer ("we don't deliver here yet")
  /// is one they only need at the moment they act. That moment is add-to-cart,
  /// where [CartController.addToCartOnline] raises the NO DELIVERY sheet — so
  /// the honesty is enforced at the gate rather than by hollowing out the page
  /// ahead of it. The numbers themselves stay true: they describe the store,
  /// not a promise to this address.
  Widget _buildStatsStrip(BuildContext context, Store store) {
    final bool freeDelivery = store.freeDelivery ?? false;
    final String? time =
        (store.deliveryTime ?? '').trim().isEmpty
            ? null
            : store.deliveryTime!.trim();

    final double minimum = store.minimumOrder ?? 0;

    // Who actually carries the order.
    //
    // `selfDeliverySystem == 1` is the store running its own fleet on its own
    // per-km rates — the checkout calculator branches on exactly this flag to
    // decide whose shipping charges to apply, so it is a real operational
    // difference and not a cosmetic one. The cell used to answer "Waddy" for
    // every store, which made it decoration; naming the restaurant when the
    // restaurant is the courier is what makes it worth its third of the row.
    //
    // It also sets expectations the two couriers genuinely differ on — live
    // tracking and support reach Waddy's riders, not a restaurant's.
    final bool selfDelivery = store.selfDeliverySystem == 1;
    final String courier =
        selfDelivery
            ? (store.name ?? (_isShop ? 'store'.tr : 'restaurant'.tr))
            : AppConstants.appName;

    // What the fee cell can honestly claim.
    //
    // `StoreDeliveryFee` runs the same ladder checkout runs, so the number
    // quoted here is the number charged later — and it returns null instead of
    // guessing when the rates or the distance cannot be trusted. Where it
    // returns null the minimum order takes the slot, exactly as before.
    final double? fee = StoreDeliveryFee.estimate(
      store: store,
      address: AddressHelper.getUserAddressFromSharedPref(),
    );

    final List<Widget> cells = [
      if (time != null)
        _statCell(
          label: 'delivery_time'.tr,
          value: time,
          valueColor: WaddyColors.primary,
        ),
      _statCell(
        label: 'delivered_by'.tr,
        value: courier,
        valueColor: WaddyColors.ink,
        valueMaxLines: 2,
      ),
      // Free delivery strikes the fee it replaced rather than just saying
      // "Free": the struck number is what makes free read as a SAVING instead
      // of as this store's ordinary price. With no computable fee there is
      // nothing to strike, and an invented "was" price would manufacture a
      // discount that does not exist — so that case shows the word alone.
      if (freeDelivery || fee != null)
        _feeCell(freeDelivery: freeDelivery, fee: fee),
      // The minimum is its own cell rather than the fee's fallback. Both facts
      // can be true at once — a store CAN deliver free above a minimum — and
      // the old either/or hid the minimum from exactly those stores, which are
      // the ones where knowing it matters most. It only renders when the fee
      // cell did not already fill the row, so the strip stays at three.
      if (!freeDelivery && fee == null && minimum > 0)
        _statCell(
          label: 'minimum_order'.tr,
          value: PriceConverter.convertPrice(minimum),
          valueColor: WaddyColors.ink,
        ),
    ];

    // Everything droppable dropped — an empty bordered box is worse than no
    // box.
    if (cells.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: WaddyColors.divider),
        borderRadius: BorderRadius.circular(15),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < cells.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: WaddyColors.divider,
                ),
              Expanded(child: cells[i]),
            ],
          ],
        ),
      ),
    );
  }

  /// The delivery-fee cell, which is the only one that shows two values.
  ///
  /// Free delivery is a SAVING, and a saving needs the thing it saved you from
  /// — so the fee this store would otherwise have charged is struck through
  /// beside a green "Free". The same grammar the menu rows use for a
  /// discounted price, which is why it reads instantly here.
  ///
  /// Three shapes:
  ///   • free, fee known    → `35 LE  Free`   (struck grey, then green)
  ///   • free, fee unknown  → `Free`          (nothing to strike)
  ///   • not free           → `35 LE`         (plain ink)
  Widget _feeCell({required bool freeDelivery, required double? fee}) {
    final String? feeLabel =
        fee == null ? null : PriceConverter.convertPrice(fee);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'delivery_fee'.tr,
            textAlign: TextAlign.center,
            style: waddyMedium.copyWith(
              fontSize: 11.5,
              color: WaddyColors.inkLight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Wrap, not Row: at the system's larger text sizes "35 LE Free" does
          // not fit a third of the screen on one line, and a struck price that
          // ellipsizes away leaves a bare "Free" that has lost its point.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            children: [
              if (feeLabel != null)
                Text(
                  feeLabel,
                  style: waddyBold.copyWith(
                    fontSize: 14,
                    // Struck only when something replaced it. Without free
                    // delivery this IS the price, and striking it would say
                    // the opposite of what is true.
                    color:
                        freeDelivery ? WaddyColors.inkMuted : WaddyColors.ink,
                    decoration:
                        freeDelivery ? TextDecoration.lineThrough : null,
                    decorationColor: WaddyColors.inkMuted,
                  ),
                  maxLines: 1,
                ),
              if (freeDelivery)
                Text(
                  'free'.tr,
                  style: waddyBold.copyWith(
                    fontSize: 14,
                    color: WaddyColors.mintInk,
                  ),
                  maxLines: 1,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// One cell of the stats strip.
  ///
  /// [valueMaxLines] exists for the courier cell. Every other value here is a
  /// short token ("20-35", "Free", "120 LE") that cannot overflow a third of
  /// the screen, but the courier's value is a STORE NAME — and a name clipped
  /// to "Vinny's Piz…" fails at the one job this cell has, which is saying who
  /// is carrying the order. It gets a second line; the rest stay at one so a
  /// long translation cannot silently make the strip taller.
  Widget _statCell({
    required String label,
    required String value,
    required Color valueColor,
    int valueMaxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Two lines, not one. At the system's larger text sizes a
          // single-line "Delivery Time" truncated to "Delivery T…" — the cell
          // stopped naming its own number, which is the one thing a label has
          // to do. Wrapping costs a few points of height the strip can absorb;
          // ellipsis cost the meaning.
          Text(
            label,
            textAlign: TextAlign.center,
            style: waddyMedium.copyWith(
              fontSize: 11.5,
              color: WaddyColors.inkLight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: waddyBold.copyWith(fontSize: 14, color: valueColor),
            maxLines: valueMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
