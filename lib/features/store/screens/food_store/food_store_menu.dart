part of '../food_store_screen.dart';

/// The items: restaurant menu rows (with their discount ribbon and add /
/// stepper controls), the shop variant's product grid, the order-again rail,
/// the empty state and the row shimmers. Moved out of food_store_screen.dart
/// unchanged.
extension _FoodStoreMenu on _FoodStoreScreenState {
  // ═══════════════════════════════════════════
  // SHOP VARIANT (D3) — product grid
  // ═══════════════════════════════════════════

  /// The selected tab's products as a 2-column tile grid — the grocery card
  /// the aisle page uses, one size up. [items] null is the first page still in
  /// flight.
  Widget _buildShopGrid(List<Item>? items) {
    const int columns = 2;
    const double side = 15;
    const double gap = Dimensions.paddingSizeMedium;
    if (items != null && items.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyMenu());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(side, 12, side, 0),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final double width =
              (constraints.crossAxisExtent - gap * (columns - 1)) / columns;
          final SliverGridDelegate grid =
              SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: gap,
                mainAxisSpacing: Dimensions.paddingSizeLarge,
                mainAxisExtent: ShopProductTile.heightFor(context, width),
              );
          if (items == null) {
            return SliverGrid.builder(
              gridDelegate: grid,
              itemCount: columns * 3,
              itemBuilder: (_, __) => ShopProductTilePlaceholder(width: width),
            );
          }
          return SliverGrid.builder(
            gridDelegate: grid,
            itemCount: items.length,
            itemBuilder:
                (context, index) =>
                    ShopProductTile(item: items[index], decodeWidth: 280),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ORDER AGAIN — horizontal rail
  // ═══════════════════════════════════════════
  Widget _buildOrderAgainRail(BuildContext context, List<Item> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'order_again'.tr,
                style: waddyBold.copyWith(
                  fontSize: 20,
                  color: WaddyColors.ink,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'recommended_for_you'.tr,
                style: waddyRegular.copyWith(
                  fontSize: 13,
                  color: WaddyColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(15, 2, 15, 6),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _buildOrderAgainCard(context, items[i]),
          ),
        ),
      ],
    );
  }

  /// Compact horizontal reorder card: thumbnail, name + price, and a pill
  /// that adds the item straight back to the cart — no detail sheet detour,
  /// since "order again" already implies the guest knows what they want.
  Widget _buildOrderAgainCard(BuildContext context, Item item) {
    final ItemPrice price = ItemPrice.of(item);

    return SizedBox(
      width: 264,
      child: Material(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap:
              () => Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, true)),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: WaddyColors.divider),
              boxShadow: [
                BoxShadow(
                  color: WaddyColors.primary.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ColoredBox(
                    color: const Color(0xFFF1F4F3),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      fit: BoxFit.cover,
                      height: 64,
                      width: 64,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name ?? '',
                        style: waddyMedium.copyWith(
                          fontSize: 13,
                          color: WaddyColors.ink,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      PriceTag(price: price),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // The app's add control, in its small pill: the regular one
                // would leave the name no room beside it in this card.
                SizedBox(
                  height: Dimensions.minTapTarget,
                  child: AddToCartControl(item: item, inset: 0, compact: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // MENU ROW — text left, thumbnail + add right
  // ═══════════════════════════════════════════
  /// The store-wide promotion as a percentage, or null when the store runs
  /// none or runs a flat-amount one.
  ///
  /// Only a PERCENT promotion is comparable to a row's own derived percentage.
  /// A flat "20 LE off" applies differently to every item, so there is no
  /// single number a row could match it against — those stores get the ribbon
  /// on every discounted row, which is correct, because the row's percentage
  /// really is news the header banner did not give.
  int? _storeWidePercent(Store store) {
    final discount = store.discount;
    if (discount == null) return null;
    if (discount.discountType != 'percent') return null;
    final double value = discount.discount ?? 0;
    if (value <= 0) return null;
    return value.round();
  }

  Widget _buildMenuRow(
    BuildContext context,
    Item item, {
    required int? storeWidePercent,
  }) {
    final ItemPrice price = ItemPrice.of(item);
    // "Customizable" promises options on the detail sheet, so only show it
    // when the item genuinely has some.
    final bool customizable =
        (item.variations?.isNotEmpty ?? false) ||
        (item.foodVariations?.isNotEmpty ?? false) ||
        (item.addOns?.isNotEmpty ?? false);
    // A single 5-star review used to be enough to crown an item "bestseller",
    // which made the badge meaningless on a new store — the state most stores
    // are in. A floor of 10 ratings is the point where the average is saying
    // something about the item rather than about one diner.
    final bool bestseller =
        (item.avgRating ?? 0) >= 4.5 && (item.ratingCount ?? 0) >= 10;

    return InkWell(
      onTap: () => Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, true)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: WaddyColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          item.name ?? '',
                          style: waddyMedium.copyWith(
                            fontSize: 16,
                            color: WaddyColors.ink,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (bestseller) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: WaddyColors.coralSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'bestseller'.tr,
                            style: waddyBold.copyWith(
                              fontSize: 10.5,
                              color: WaddyColors.coralInk,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if ((item.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.description!.trim(),
                      style: waddyRegular.copyWith(
                        fontSize: 13,
                        color: WaddyColors.inkLight,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Every discounted item wears the collar, the same one the
                  // store cards and every other product surface use.
                  //
                  // It used to render only where the row's percentage differed
                  // from the store-wide promotion, so a 25%-off store did not
                  // repeat "25% OFF" on every row. Consistency across the app
                  // won (docs/price_add_controls_plan.md D2); flip
                  // [_kCollarOnlyWhenNews] to bring the exception rule back if
                  // it reads as noise on a device.
                  if (price.onSale &&
                      (!_kCollarOnlyWhenNews ||
                          _ribbonEarnsItsPlace(
                            priceBefore: price.was,
                            priceAfter: price.now,
                            storeWidePercent: storeWidePercent,
                          ))) ...[
                    const SizedBox(height: 10),
                    OfferCollarBadge.forPrice(price, compact: true)!,
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PriceTag(price: price, size: PriceTagSize.regular),
                      if (customizable)
                        Text(
                          'customizable'.tr,
                          style: waddyMedium.copyWith(
                            fontSize: 12.5,
                            color: WaddyColors.inkLight,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // The control straddles the photo's bottom edge at the trailing
            // corner: half on the plate, half below it (D1). The 40pt `+` and
            // the 112pt stepper it grows into would bury a third of a 110pt
            // photo if they sat fully on it; straddling keeps the food in
            // view and the control anchored to the item it belongs to. The
            // box below the photo reserves that half, so the next row's
            // divider never runs under it.
            SizedBox(
              width: 110,
              height: 110 + _kControlOverhang,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ColoredBox(
                      color: const Color(0xFFF1F4F3),
                      child: CustomImage(
                        image: item.imageFullUrl ?? '',
                        fit: BoxFit.cover,
                        height: 110,
                        width: 110,
                      ),
                    ),
                  ),
                  // Pinned by its trailing edge: the pill grows toward the
                  // start across the photo, so the `+` the finger is on does
                  // not move out from under it.
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    height: Dimensions.minTapTarget,
                    child: AddToCartControl(item: item, inset: 4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Whether this row's discount is news the header banner has not given.
  ///
  /// True when the store runs no comparable store-wide percentage, or when
  /// this row's own percentage differs from it. The 1-point tolerance absorbs
  /// rounding: a 25% store promotion lands on individual prices as 24.6% or
  /// 25.4% depending on where the cents fall, and a row that is really just
  /// the store promotion must not claim to be an exception because of a
  /// half-piastre.
  bool _ribbonEarnsItsPlace({
    required double priceBefore,
    required double priceAfter,
    required int? storeWidePercent,
  }) {
    if (storeWidePercent == null) return true;
    if (priceBefore <= 0) return false;
    final int percentOff = ((1 - (priceAfter / priceBefore)) * 100).round();
    return (percentOff - storeWidePercent).abs() > 1;
  }

  Widget _buildEmptyMenu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 40),
      child: Center(
        child: Column(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedRestaurant01,
              size: 48,
              color: WaddyColors.divider,
            ),
            const SizedBox(height: 12),
            Text(
              'no_item_available'.tr,
              textAlign: TextAlign.center,
              style: waddyMedium.copyWith(
                fontSize: 14,
                color: WaddyColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuRowShimmer() => _menuRowShimmer();
}

/// Shared between the live pagination shimmer and [_FoodStoreScreenShimmer]'s
/// initial-load skeleton, so both stay in sync with the real menu row shape.
Widget _menuRowShimmer() {
  Widget bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: WaddyColors.surfaceRaised,
      borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
    ),
  );

  return Shimmer(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: WaddyColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(160, 14),
                const SizedBox(height: 9),
                bar(double.infinity, 11),
                const SizedBox(height: 5),
                bar(180, 11),
                const SizedBox(height: 12),
                bar(64, 13),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: WaddyColors.surfaceRaised,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Loading skeleton for [FoodStoreScreen] — mirrors the real hero, header,
/// stats strip, tab bar, and menu rows so nothing jumps once data lands.
class _FoodStoreScreenShimmer extends StatelessWidget {
  const _FoodStoreScreenShimmer();

  Widget _bar(double w, double h, {BorderRadius? radius}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: WaddyColors.surfaceRaised,
      borderRadius:
          radius ?? BorderRadius.circular(Dimensions.radiusExtraSmall),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── HERO ───
          Shimmer(
            child: SizedBox(
              height: _kCoverHeight + _kLogoOverhang,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: _kCoverHeight,
                    color: WaddyColors.surfaceRaised,
                  ),
                  Positioned(
                    left: 15,
                    bottom: 0,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: WaddyColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: WaddyColors.surface,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── HEADER ───
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 18),
            child: Shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(180, 20),
                  const SizedBox(height: 9),
                  _bar(120, 12),
                  const SizedBox(height: 16),
                  _bar(double.infinity, 62, radius: BorderRadius.circular(15)),
                ],
              ),
            ),
          ),

          // ─── DIVIDER BAND ───
          const SizedBox(
            height: 8,
            child: ColoredBox(color: Color(0xFFF1F4F3)),
          ),

          // ─── TAB BAR ───
          SizedBox(
            height: _kTabBarHeight,
            child: Shimmer(
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  _bar(64, 15),
                  const SizedBox(width: 20),
                  _bar(64, 15),
                  const SizedBox(width: 20),
                  _bar(64, 15),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: WaddyColors.divider),

          // ─── MENU TITLE ───
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 0),
            child: Shimmer(child: _bar(140, 20)),
          ),

          // ─── MENU ROWS ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(children: List.generate(5, (_) => _menuRowShimmer())),
          ),
        ],
      ),
    );
  }
}
