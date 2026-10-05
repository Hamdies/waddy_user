part of '../store_screen.dart';

/// The aisle page's sections (Mart Store Page v4): category tiles, Buy
/// again, the grouped aisle rails, the remaining aisles as tiles, the
/// store-wide discount banner, the reviews preview and bundles. A part file
/// shares its library, so private members resolve as in store_screen.dart.
extension _StoreAislesSections on _StoreScreenState {
  // ═══════════════════════════════════════════════════════════════
  // CATEGORIES — the grocery home's store-type tiles, two rows of four;
  // the last slot is "+N / View all" when there are more
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCategoriesRow(
    BuildContext context,
    StorePageController storeController,
    List<CategoryModel> categories,
  ) {
    void showAll() => showAllStoreCategoriesSheet(
      categories: categories,
      onCategoryTap: (category) => _openCategory(storeController, category),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No "See all" here: the grid's last tile is "+N · View all" when
        // there are more, and two ways to one sheet was one too many.
        StoreSectionHeader(
          title: 'shop_by_category'.tr,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 14),
        ),
        StoreCategoryTiles(
          categories: categories,
          onCategoryTap: (category) => _openCategory(storeController, category),
          onViewAll: showAll,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUY AGAIN — what this customer got in their last orders here
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBuyAgain() {
    return GetBuilder<StorePageController>(
      tag: _page.tag,
      id: StorePageController.buyAgainId,
      builder: (storeController) {
        final buyAgain = storeController.buyAgain;
        if (buyAgain == null || buyAgain.lines.isEmpty) {
          return const SizedBox.shrink();
        }
        final int orders = buyAgain.orderCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreSectionHeader(
              title: 'buy_again'.tr,
              subtitle:
                  orders > 1
                      ? 'from_your_last_n_orders_here'.trParams({
                        'n': '$orders',
                      })
                      : 'from_your_last_order_here'.tr,
            ),
            _CardRail(items: [for (final l in buyAgain.lines) l.item]),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MORE AISLES — the aisles past the grouped rails, as tiles
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMoreAisles(
    StorePageController storeController,
    List<CategoryModel> categories,
    Map<int, int> itemCounts,
  ) {
    final bool oddCount = categories.length.isOdd;
    Widget tile(CategoryModel category) => _AisleTile(
      category: category,
      itemCount: itemCounts[category.id],
      onTap: () => _openCategory(storeController, category),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StoreSectionHeader(title: 'more_aisles'.tr),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Odd count: the first aisle takes a full row, so the grid
              // under it closes square.
              if (oddCount) ...[
                tile(categories.first),
                const SizedBox(height: 10),
              ],
              for (int i = oddCount ? 1 : 0; i < categories.length; i += 2) ...[
                if (i > (oddCount ? 1 : 0)) const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tile(categories[i])),
                      const SizedBox(width: 10),
                      Expanded(child: tile(categories[i + 1])),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CAN'T FIND SOMETHING — the page's last word: search the whole store
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCantFind(Store store) {
    final int count = store.itemCount ?? 0;
    final String line =
        count > 0
            ? 'search_all_n_items_at'.trParams({
              'n': '$count',
              'store': store.name ?? '',
            })
            : 'search_everything_at'.trParams({'store': store.name ?? ''});

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
      child: PressableScale(
        semanticLabel: 'cant_find_something'.tr,
        onTap: () => Get.toNamed(RouteHelper.getSearchStoreItemRoute(store.id)),
        child: Container(
          // The page's last word sits on the aisle panels' mint, with the
          // teal-and-mint pair the add controls use — not a white form row.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [WaddyColors.mintSurfaceDeep, WaddyColors.mintSurface],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: WaddyColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: WaddyColors.mint,
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'cant_find_something'.tr,
                      style: waddyBold.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: WaddyColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: waddyRegular.copyWith(
                        fontSize: 13,
                        color: WaddyColors.inkMid,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: WaddyColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                  color: WaddyColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // REVIEWS PREVIEW — shows first 3 reviews + "See all" link
  // ═══════════════════════════════════════════════════════════════
  Widget _buildReviewsPreview(
    BuildContext context,
    Store store,
    Color primaryColor,
  ) {
    return GetBuilder<ReviewController>(
      builder: (reviewController) {
        final reviews = reviewController.storeReviewList;
        if (reviews == null || reviews.isEmpty) return const SizedBox.shrink();

        final previewReviews =
            reviews.length > 3 ? reviews.sublist(0, 3) : reviews;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'reviews'.tr,
                          style: waddyBold.copyWith(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if ((store.avgRating ?? 0) > 0) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            store.avgRating!.toStringAsFixed(1),
                            style: waddyBold.copyWith(
                              fontSize: 13,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          Text(
                            ' (${store.ratingCount ?? 0})',
                            style: waddyRegular.copyWith(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap:
                        () => Get.to(
                          () => ReviewScreen(
                            storeID: store.id.toString(),
                            storeName: store.name,
                            store: store,
                          ),
                        ),
                    child: Text(
                      'view_all'.tr,
                      style: waddyMedium.copyWith(
                        fontSize: 12,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (store.ratings != null && store.ratings!.length >= 5)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRatingBars(store, primaryColor),
                ),
              ...previewReviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < (review.rating ?? 0)
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 14,
                                color: Colors.amber.shade600,
                              ),
                            ),
                            const Spacer(),
                            if (review.customerName != null)
                              Text(
                                review.customerName!,
                                style: waddyMedium.copyWith(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        if (review.comment != null &&
                            review.comment!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            review.comment!,
                            style: waddyRegular.copyWith(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (review.itemName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            review.itemName!,
                            style: waddyRegular.copyWith(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRatingBars(Store store, Color primaryColor) {
    final ratings = store.ratings!;
    final total = ratings.fold<int>(0, (sum, r) => sum + r);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: List.generate(5, (index) {
        final starNum = 5 - index;
        final count = starNum <= ratings.length ? ratings[starNum - 1] : 0;
        final fraction = count / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Text(
                '$starNum',
                style: waddyMedium.copyWith(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(primaryColor),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  '$count',
                  style: waddyRegular.copyWith(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STORE BUNDLES / COLLECTIONS — horizontal scrollable bundle cards
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStoreBundlesSection(
    BuildContext context,
    StorePageController storeController,
    Color primaryColor,
  ) {
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    final bundles = storeController.storeBundleList!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2_rounded, size: 18, color: primaryColor),
              const SizedBox(width: 6),
              Text(
                'bundles'.tr,
                style: waddyBold.copyWith(
                  fontSize: 17,
                  color: Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: bundles.length,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final bundle = bundles[index];
              final itemCount = bundle.items?.length ?? 0;
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bundle image or item thumbnails grid
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child:
                          bundle.imageFullUrl != null &&
                                  bundle.imageFullUrl!.isNotEmpty
                              ? CustomImage(
                                image: bundle.imageFullUrl!,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                              : Container(
                                height: 100,
                                width: double.infinity,
                                color: primaryColor.withValues(alpha: 0.06),
                                child: _buildBundleItemThumbnails(
                                  bundle,
                                  primaryColor,
                                ),
                              ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                      child: Text(
                        bundle.name ?? '',
                        style: waddyBold.copyWith(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (bundle.description != null &&
                        bundle.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          bundle.description!,
                          style: waddyRegular.copyWith(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: Row(
                        children: [
                          if (bundle.price != null && bundle.price! > 0)
                            Text(
                              PriceConverter.convertPrice(bundle.price),
                              style: waddyBold.copyWith(
                                fontSize: 14,
                                color: primaryColor,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$itemCount ${'items'.tr}',
                              style: waddyMedium.copyWith(
                                fontSize: 10,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBundleItemThumbnails(
    StoreBundleModel bundle,
    Color primaryColor,
  ) {
    final items = bundle.items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Icon(
          Icons.inventory_2_rounded,
          size: 40,
          color: primaryColor.withValues(alpha: 0.3),
        ),
      );
    }
    final displayItems = items.length > 4 ? items.sublist(0, 4) : items;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children:
            displayItems
                .map(
                  (item) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      height: 42,
                      width: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CARD RAIL — a horizontal row of StoreProductCards
// ═══════════════════════════════════════════════════════════════
class _CardRail extends StatelessWidget {
  final List<Item> items;
  final bool bordered;
  final double inset;

  /// After the last card — an aisle's "See all" tile, stretched to the
  /// cards' height.
  final Widget? trailing;

  const _CardRail({
    required this.items,
    this.bordered = true,
    this.inset = 20,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // A Row, not a fixed-height ListView: the cards size to their text at
    // the viewer's text scale, and a rail holds at most a dozen.
    // Stretched to the tallest card, so a one-line name's card ends level
    // with its neighbours instead of short.
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          StoreProductCard(
            key: ValueKey<int?>(items[i].id),
            item: items[i],
            bordered: bordered,
          ),
        ],
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsetsDirectional.fromSTEB(inset, 0, inset, 4),
      child: IntrinsicHeight(child: row),
    );
  }
}

/// Row tiles two deep, scrolling sideways in columns.
class _RowGrid extends StatelessWidget {
  final List<Item> items;

  /// After the last column — the aisle's "See all" tile, two rows tall.
  final Widget? trailing;

  const _RowGrid({required this.items, this.trailing});

  @override
  Widget build(BuildContext context) {
    final Widget row = Row(
      crossAxisAlignment:
          trailing != null
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i += 2) ...[
          if (i > 0) const SizedBox(width: 10),
          Column(
            children: [
              StoreProductRow(key: ValueKey<int?>(items[i].id), item: items[i]),
              if (i + 1 < items.length) ...[
                const SizedBox(height: 10),
                StoreProductRow(
                  key: ValueKey<int?>(items[i + 1].id),
                  item: items[i + 1],
                ),
              ],
            ],
          ),
        ],
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(20, 2, 20, 4),
      child: trailing != null ? IntrinsicHeight(child: row) : row,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AISLE GROUP — a few aisles behind tabs, one rail at a time
// ═══════════════════════════════════════════════════════════════

/// The two looks the grouped rails alternate, in page order: a mint panel,
/// then an open section of row tiles.
///
/// Dark teal is not one of them. It belongs to the offers panel
/// (`StoreSpecialOfferView`), so on this page dark means "on sale" and
/// nothing else — it used to fall on whichever aisle came third by position,
/// which gave a two-item Condiments aisle the page's heaviest treatment.
enum _AisleStyle { mint, rows }

typedef _AisleRail =
    Widget Function(
      CategoryModel category, {
      required Widget placeholder,
      required Widget Function(List<Item> items) builder,
    });

class _AisleGroup extends StatefulWidget {
  final List<CategoryModel> categories;
  final _AisleStyle style;

  /// Active items per aisle, when the store details carried them.
  final Map<int, int> itemCounts;

  /// The page's rail fetcher — see `_StoreScreenState._rail`.
  final _AisleRail rail;
  final ValueChanged<CategoryModel> onSeeAll;

  const _AisleGroup({
    super.key,
    required this.categories,
    required this.style,
    required this.itemCounts,
    required this.rail,
    required this.onSeeAll,
  });

  /// Cards per tab before "See all" takes over.
  static const int _kMaxItems = 10;

  @override
  State<_AisleGroup> createState() => _AisleGroupState();
}

class _AisleGroupState extends State<_AisleGroup> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final bool mint = widget.style == _AisleStyle.mint;
    final double inset = mint ? 16 : 20;
    final int index = _selected.clamp(0, widget.categories.length - 1);
    final CategoryModel category = widget.categories[index];
    final int? count = widget.itemCounts[category.id];

    final Widget items = KeyedSubtree(
      // A new aisle remounts the rail: an id-scoped GetBuilder keeps the id
      // it subscribed with, so reusing it would listen to the old aisle.
      key: ValueKey<int?>(category.id),
      child: widget.rail(
        category,
        placeholder: _ItemsPlaceholder(rows: !mint),
        builder: (all) {
          final List<Item> shown = all.take(_AisleGroup._kMaxItems).toList();
          // "See all" only when it leads somewhere new: the store's count
          // says the aisle holds more than is on screen, or — without a
          // count — the rail itself came back with more than it shows.
          final bool more =
              count != null ? count > shown.length : all.length > shown.length;
          return _AisleItems(
            items: shown,
            rows: !mint,
            inset: inset,
            seeAll:
                more
                    ? _SeeAll(
                      count: count,
                      onTap: () => widget.onSeeAll(category),
                    )
                    : null,
          );
        },
      ),
    );

    // The aisles ARE the heading: one aisle is a plain title, several are
    // title-sized tabs. A title over pill chips named the selected aisle
    // twice, 60px apart, and rewrote itself on every tab change.
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AisleHeading(
          categories: widget.categories,
          selected: index,
          onMint: mint,
          inset: inset,
          onSelect: (i) => setState(() => _selected = i),
        ),
        const SizedBox(height: Dimensions.paddingSizeMedium),
        items,
      ],
    );

    return mint
        ? Container(
          margin: const EdgeInsets.fromLTRB(12, 32, 12, 0),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [WaddyColors.mintSurfaceDeep, WaddyColors.mintSurface],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: body,
        )
        : Padding(padding: const EdgeInsets.only(top: 32), child: body);
  }
}

/// An aisle's items, laid out for how many there are. Up to two cards (or
/// three rows) fill the width rather than scrolling: a short aisle in a
/// sideways rail left a third of the panel empty and read as broken.
class _AisleItems extends StatelessWidget {
  final List<Item> items;
  final bool rows;
  final double inset;

  /// The way on to the whole aisle, when it holds more than is shown.
  final _SeeAll? seeAll;

  const _AisleItems({
    required this.items,
    required this.rows,
    required this.inset,
    required this.seeAll,
  });

  static const int _kFitCards = 2;
  static const int _kFitRows = 3;

  @override
  Widget build(BuildContext context) {
    final bool fits = items.length <= (rows ? _kFitRows : _kFitCards);
    if (!fits) {
      final Widget? tile = seeAll?.asTile();
      return rows
          ? _RowGrid(items: items, trailing: tile)
          : _CardRail(
            items: items,
            bordered: false,
            inset: inset,
            trailing: tile,
          );
    }

    final List<Widget> lines = [
      if (!rows && items.length == _kFitCards)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: StoreProductCard(
                    key: ValueKey<int?>(items[i].id),
                    item: items[i],
                    bordered: false,
                    cardWidth: null,
                  ),
                ),
              ],
            ],
          ),
        )
      else
        // One card alone is a row tile: a lone 136 card is the same empty
        // panel, just with less in it.
        for (final Item item in items)
          StoreProductRow(
            key: ValueKey<int?>(item.id),
            item: item,
            width: null,
          ),
      if (seeAll != null) seeAll!.asBar(),
    ];

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(inset, 0, inset, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            lines[i],
          ],
        ],
      ),
    );
  }
}

/// "See all 13" — as a tile at the end of a rail, or a bar under a short
/// aisle's items.
class _SeeAll {
  final int? count;
  final VoidCallback onTap;

  const _SeeAll({required this.count, required this.onTap});

  String get _label =>
      count != null
          ? 'store_see_all_n'.trParams({'n': '$count'})
          : 'store_see_all'.tr;

  Widget asTile() => _SeeAllTile(label: _label, onTap: onTap);

  Widget asBar() => Builder(
    builder: (context) {
      final bool rtl = Directionality.of(context) == TextDirection.rtl;
      return Pressable(
        onTap: onTap,
        semanticLabel: _label,
        scale: WaddyMotion.pressControl,
        child: Container(
          height: Dimensions.minTapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: WaddyColors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _label,
                style: waddyBold.copyWith(
                  fontSize: 13,
                  color: WaddyColors.primary,
                ),
              ),
              Icon(
                rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                size: 18,
                color: WaddyColors.primary,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SeeAllTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SeeAllTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return PressableScale(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(color: WaddyColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: WaddyColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                size: 20,
                color: WaddyColors.mint,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: waddyBold.copyWith(
                fontSize: 13,
                height: 1.25,
                color: WaddyColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The group's heading. One aisle: its name as a title. Several: the names
/// as title-sized tabs, the selected one at full ink over a short bar —
/// mint on the open page, teal on the mint panel, where mint would vanish.
class _AisleHeading extends StatelessWidget {
  final List<CategoryModel> categories;
  final int selected;
  final bool onMint;
  final double inset;
  final ValueChanged<int> onSelect;

  const _AisleHeading({
    required this.categories,
    required this.selected,
    required this.onMint,
    required this.inset,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final Color ink = onMint ? WaddyColors.primary : WaddyColors.ink;
    final TextStyle style = waddyBold.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: displayTracking(-0.4),
      color: ink,
    );

    if (categories.length == 1) {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(inset, 0, inset, 0),
        child: Text(
          categories.first.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      );
    }

    final Color bar = onMint ? WaddyColors.primary : WaddyColors.mint;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsetsDirectional.fromSTEB(inset - 4, 0, inset - 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < categories.length; i++)
            Semantics(
              selected: i == selected,
              child: Pressable(
                semanticLabel: categories[i].name,
                scale: WaddyMotion.pressControl,
                onTap: () => onSelect(i),
                child: Padding(
                  // 4 + the next tab's 4: tabs sit 20 apart, and each keeps a
                  // 48 hit height without crowding its neighbours.
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 16, 0),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: WaddyMotion.fast,
                          curve: WaddyMotion.easeOut,
                          style: style.copyWith(
                            // 0.5 keeps a resting tab at 3:1 — large bold text.
                            color:
                                i == selected
                                    ? ink
                                    : ink.withValues(alpha: 0.5),
                          ),
                          child: Text(categories[i].name ?? '', maxLines: 1),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: WaddyMotion.fast,
                          curve: WaddyMotion.easeOut,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                i == selected ? bar : bar.withValues(alpha: 0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One of the aisles past the grouped rails: photo, name, item count.
class _AisleTile extends StatelessWidget {
  final CategoryModel category;
  final int? itemCount;
  final VoidCallback onTap;

  const _AisleTile({
    required this.category,
    required this.itemCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      semanticLabel: category.name,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 10, 8),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: WaddyColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    WaddyColors.mintSurfaceDeep,
                    WaddyColors.mintSurface,
                  ],
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomImage(
                image: category.imageFullUrl ?? '',
                variants: category.imageVariants,
                fit: BoxFit.contain,
                decodeWidth: 120,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: waddyBold.copyWith(
                      fontSize: 13,
                      height: 1.2,
                      color: WaddyColors.ink,
                    ),
                  ),
                  if (itemCount != null && itemCount! > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      itemCountLabel(itemCount!),
                      style: waddyRegular.copyWith(
                        fontSize: 11,
                        color: WaddyColors.inkLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PLACEHOLDERS — held at the loaded height, so arrivals don't shove the page
// ═══════════════════════════════════════════════════════════════
Widget _shimmerBlock(double width, double height, double radius) => Container(
  width: width,
  height: height,
  decoration: BoxDecoration(
    color: Colors.grey.shade200,
    borderRadius: BorderRadius.circular(radius),
  ),
);

/// A section's header and a row of card-sized blocks, while its rail loads.
class _RailPlaceholder extends StatelessWidget {
  const _RailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _shimmerBlock(140, 22, Dimensions.radiusExtraSmall),
            ),
            const SizedBox(height: 12),
            const _ItemsPlaceholder(rows: false, shimmer: false),
          ],
        ),
      ),
    );
  }
}

/// Just the items' blocks — an aisle tab whose rail is loading.
class _ItemsPlaceholder extends StatelessWidget {
  final bool rows;
  final bool shimmer;

  const _ItemsPlaceholder({required this.rows, this.shimmer = true});

  @override
  Widget build(BuildContext context) {
    final Widget blocks = SizedBox(
      height: rows ? 74 * 2 + 10 : 226,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder:
            (_, __) =>
                rows
                    ? Column(
                      children: [
                        _shimmerBlock(StoreProductRow.defaultWidth, 74, 15),
                        const SizedBox(height: 10),
                        _shimmerBlock(StoreProductRow.defaultWidth, 74, 15),
                      ],
                    )
                    : _shimmerBlock(
                      StoreProductCard.width,
                      226,
                      Dimensions.radiusLarge,
                    ),
      ),
    );
    return shimmer ? Shimmer(child: blocks) : blocks;
  }
}
