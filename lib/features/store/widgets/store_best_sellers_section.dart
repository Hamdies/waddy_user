import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/widgets/store_product_card.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// The supermarket page's best sellers (Mart Store Page v4): a header, a
/// white hero card with the tilted "Top 10" sticker between the two top
/// packs, then aisle chips over a rail of ranked cards.
///
/// ```
///   Best sellers
///   By total orders at this store
///   ┌──────────────────────────────────┐
///   │  [pk]   ╭──────────────╮   [pk]  │  hero card
///   │         │ Top 10 best  │         │  (packs = the #1 and #2 photos)
///   │         ╰──────────────╯         │
///   │      Most ordered at Store       │
///   └──────────────────────────────────┘
///   (All) (Dairy) (Snacks) …              aisle chips
///   ┌#1─────┐ ┌#2─────┐ ┌#3──           ranked cards
/// ```
///
/// Every claim is one the data can back. [items] come from the `popular`
/// sort, which orders by lifetime `order_count` — so ranks, "Top 10" and the
/// order counts only appear once enough has actually sold ([_kMinRanked]).
/// Before that the section is "Top picks": header, chips and cards — no hero,
/// no ranks, no numbers, because a ranking over all-zero counts would be
/// made up. Nothing here says
/// "this week": the backend keeps no weekly count.
class StoreBestSellersSection extends StatefulWidget {
  final List<Item> items;
  final String storeName;

  /// The store's main categories, in admin order. Only the ones with an item
  /// in the ranking become chips.
  final List<CategoryModel> categories;

  const StoreBestSellersSection({
    super.key,
    required this.items,
    required this.storeName,
    required this.categories,
  });

  /// Fewest sold items that make a ranking worth a hero.
  static const int _kMinRanked = 3;

  /// The sticker's "Top N" and the rail's cap, once that many have sold.
  static const int _kTopN = 10;

  /// Below this an order count reads as weak rather than as proof.
  static const int _kMinOrdersShown = 10;

  @override
  State<StoreBestSellersSection> createState() =>
      _StoreBestSellersSectionState();
}

class _StoreBestSellersSectionState extends State<StoreBestSellersSection> {
  /// The selected aisle chip; null is "All".
  int? _categoryId;

  /// An item's MAIN category. `category_id` is the sub-category; the main one
  /// only rides in `category_ids`, at position 1.
  static int? _mainCategoryOf(Item item) {
    for (final c in item.categoryIds ?? const <CategoryIds>[]) {
      if (c.position == 1) return c.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final List<Item> sold =
        widget.items.where((i) => (i.orderCount ?? 0) > 0).toList();
    final bool ranked = sold.length >= StoreBestSellersSection._kMinRanked;
    final bool topN = sold.length >= StoreBestSellersSection._kTopN;

    // Ranked: only what has sold, capped at the sticker's N. The list arrives
    // sorted by order count, so the rank is the position.
    final List<Item> pool =
        ranked
            ? sold.take(StoreBestSellersSection._kTopN).toList()
            : widget.items;
    final List<_Ranked> entries = [
      for (int i = 0; i < pool.length; i++)
        _Ranked(pool[i], ranked ? i + 1 : null),
    ];

    // Chips for the aisles that have something here, in the store's order.
    final Set<int?> present = {
      for (final e in entries) _mainCategoryOf(e.item),
    };
    final List<CategoryModel> chips =
        widget.categories.where((c) => present.contains(c.id)).toList();
    final bool showChips = chips.length >= 2;
    final int? selected =
        showChips && chips.any((c) => c.id == _categoryId) ? _categoryId : null;
    final List<_Ranked> visible =
        selected == null
            ? entries
            : entries
                .where((e) => _mainCategoryOf(e.item) == selected)
                .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 32, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ranked ? 'best_sellers'.tr : 'top_picks'.tr,
                style: waddyBold.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: displayTracking(-0.4),
                  color: WaddyColors.ink,
                ),
              ),
              if (ranked) ...[
                const SizedBox(height: 2),
                Text(
                  'ranked_by_total_orders'.tr,
                  style: waddyRegular.copyWith(
                    fontSize: 12,
                    color: WaddyColors.inkLight,
                  ),
                ),
              ],
            ],
          ),
        ),
        // The hero only once there is a ranking to announce. Unranked, its
        // sticker said "Top picks" under a header saying "Top picks" — 128
        // points that pushed the first products down and told nothing.
        if (ranked)
          _Hero(
            packs: pool.take(2).toList(),
            topN: topN ? StoreBestSellersSection._kTopN : null,
            ranked: ranked,
            storeName: widget.storeName,
          ),
        if (showChips)
          SizedBox(
            height: (ranked ? 14 : 0) + 36 + 16,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsetsDirectional.fromSTEB(
                20,
                ranked ? 14 : 0,
                20,
                16,
              ),
              children: [
                _Chip(
                  label: 'all'.tr,
                  selected: selected == null,
                  onTap: () => setState(() => _categoryId = null),
                ),
                for (final c in chips) ...[
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  _Chip(
                    label: c.name ?? '',
                    selected: selected == c.id,
                    onTap: () => setState(() => _categoryId = c.id),
                  ),
                ],
              ],
            ),
          )
        else
          const SizedBox(height: 16),
        // A Row, not a fixed-height ListView: the cards size to their text at
        // the viewer's text scale, and there are at most a dozen of them.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < visible.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  StoreProductCard(
                    key: ValueKey<int?>(visible[i].item.id),
                    item: visible[i].item,
                    rank: visible[i].rank,
                    footer:
                        ranked &&
                                (visible[i].item.orderCount ?? 0) >=
                                    StoreBestSellersSection._kMinOrdersShown
                            ? _OrdersLine(orders: visible[i].item.orderCount!)
                            : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Ranked {
  final Item item;
  final int? rank;
  const _Ranked(this.item, this.rank);
}

/// "**48** orders", with the number in semibold wherever the language puts it.
class _OrdersLine extends StatelessWidget {
  final int orders;
  const _OrdersLine({required this.orders});

  @override
  Widget build(BuildContext context) {
    final String text = 'n_orders'.trParams({'n': '$orders'});
    final int at = text.indexOf('$orders');
    return Text.rich(
      TextSpan(
        children:
            at < 0
                ? [TextSpan(text: text)]
                : [
                  TextSpan(text: text.substring(0, at)),
                  TextSpan(
                    text: '$orders',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: WaddyColors.inkMid,
                    ),
                  ),
                  TextSpan(text: text.substring(at + '$orders'.length)),
                ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: waddyRegular.copyWith(fontSize: 11, color: WaddyColors.inkLight),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HERO — white card, tilted sticker, the top two packs bobbing at its sides
// ═══════════════════════════════════════════════════════════════
class _Hero extends StatelessWidget {
  final List<Item> packs;
  final int? topN;
  final bool ranked;
  final String storeName;

  const _Hero({
    required this.packs,
    required this.topN,
    required this.ranked,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: WaddyColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (packs.isNotEmpty)
            PositionedDirectional(
              start: 7,
              bottom: 6,
              child: _FloatingPack(item: packs[0], delayed: false),
            ),
          if (packs.length > 1)
            PositionedDirectional(
              end: 7,
              bottom: 6,
              child: _FloatingPack(item: packs[1], delayed: true),
            ),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Scales down rather than overflowing at large text sizes.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Transform.rotate(
                      angle: -0.052, // -3°
                      child: _Sticker(topN: topN, ranked: ranked),
                    ),
                  ),
                ),
                if (ranked) ...[
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(
                      'most_ordered_at_store'.trParams({'store': storeName}),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: waddyBold.copyWith(
                        fontSize: 12,
                        color: WaddyColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sticker extends StatelessWidget {
  final int? topN;
  final bool ranked;

  const _Sticker({required this.topN, required this.ranked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: WaddyColors.primary,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        boxShadow: [
          // The hard mint "ledge" under the sticker, then a soft drop.
          const BoxShadow(color: WaddyColors.mint, offset: Offset(0, 4)),
          BoxShadow(
            color: WaddyColors.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child:
          topN != null
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'top_n'.trParams({'n': '$topN'}),
                    maxLines: 1,
                    style: waddyDisplayFace(
                      34,
                      weight: FontWeight.w900,
                      color: WaddyColors.mint,
                      tracking: -0.045,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'best_sellers_line_1'.tr,
                        style: waddyDisplayFace(
                          13,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'best_sellers_line_2'.tr,
                        style: waddyDisplayFace(
                          13,
                          weight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              )
              : Text(
                ranked ? 'best_sellers'.tr : 'top_picks'.tr,
                maxLines: 1,
                style: waddyDisplayFace(
                  30,
                  weight: FontWeight.w900,
                  color: WaddyColors.mint,
                  tracking: -0.033,
                  height: 1,
                ),
              ),
    );
  }
}

/// One product photo bobbing in place. Still under reduced motion.
class _FloatingPack extends StatefulWidget {
  final Item item;

  /// Half a cycle behind, so the two packs never move in step.
  final bool delayed;

  const _FloatingPack({required this.item, required this.delayed});

  @override
  State<_FloatingPack> createState() => _FloatingPackState();
}

class _FloatingPackState extends State<_FloatingPack>
    with SingleTickerProviderStateMixin {
  static const Duration _kCycle = Duration(milliseconds: 3200);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kCycle,
    value: widget.delayed ? 0.5 : 0,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 0 → -5 → 0 on an ease-in-out, like the design's CSS bob.
        final double t = _controller.value;
        final double wave = t < 0.5 ? t * 2 : (1 - t) * 2;
        final double dy = -5 * Curves.easeInOut.transform(wave);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: SizedBox(
        width: 58,
        height: 74,
        child: CustomImage(
          image: widget.item.imageFullUrl ?? '',
          variants: widget.item.imageVariants,
          fit: BoxFit.contain,
          decodeWidth: 120,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AISLE CHIP
// ═══════════════════════════════════════════════════════════════
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      onTap: onTap,
      child: AnimatedContainer(
        duration: WaddyMotion.fast,
        curve: WaddyMotion.easeOut,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? WaddyColors.primary : WaddyColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? WaddyColors.primary : WaddyColors.divider,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: waddyMedium.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : WaddyColors.inkMid,
          ),
        ),
      ),
    );
  }
}
