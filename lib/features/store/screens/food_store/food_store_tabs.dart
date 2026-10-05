part of '../food_store_screen.dart';

/// The sticky category tab strip and the all-categories sheet. Moved out of
/// food_store_screen.dart unchanged, except that selecting a tab calls the
/// State's `_selectTab` (setState is protected).
extension _FoodStoreTabs on _FoodStoreScreenState {
  // ═══════════════════════════════════════════
  // STICKY CATEGORY TABS
  // ═══════════════════════════════════════════
  Widget _buildCategoryTabs(
    BuildContext context,
    List<CategoryModel> categories,
    int activeTab, {
    required int allItemCount,
    required Map<int, List<Item>> groupedItems,
    required bool elevated,
  }) {
    final List<String> labels = [
      _allTabLabel,
      ...categories.map((c) => c.name ?? ''),
    ];

    return Container(
      height: _kTabBarHeight,
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        border: const Border(bottom: BorderSide(color: WaddyColors.divider)),
        // Lift it only once it is actually pinned over content; a permanent
        // shadow reads as a seam when the page is at rest.
        boxShadow:
            elevated
                ? [
                  BoxShadow(
                    color: WaddyColors.primary.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: Row(
        children: [
          // The strip cuts every label at the same hard vertical line, and a
          // cut through a WORD ("Bakery & Pas") reads as text that failed to
          // render rather than as content that continues. The fade turns the
          // same geometry into "there is more, scroll" — and is already what
          // the home rails use, so the two agree about what an edge means.
          Expanded(
            child: TrailingFade(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: labels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 20),
                itemBuilder: (_, i) {
                  final bool active = i == activeTab;
                  return Semantics(
                    button: true,
                    selected: active,
                    child: InkWell(
                      onTap: () {
                        if (_selectedTabIndex == i) return;
                        _selectTab(i);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.only(top: 14, bottom: 11),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  active
                                      ? WaddyColors.primary
                                      : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          labels[i],
                          style: (active ? waddyBold : waddyMedium).copyWith(
                            fontSize: 15,
                            color:
                                active
                                    ? WaddyColors.primary
                                    : WaddyColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ─── MENU CATEGORIES SHEET ───
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: WaddyColors.divider)),
            ),
            child: Semantics(
              button: true,
              label: _categoriesLabel,
              child: InkWell(
                onTap:
                    () => _openMenuCategoriesSheet(
                      context,
                      categories,
                      activeTab,
                      allItemCount: allItemCount,
                      groupedItems: groupedItems,
                    ),
                // Labelled, not iconographic.
                //
                // A ☰ beside a scrolling tab strip is genuinely ambiguous: it
                // could be the app's global menu, a filter, or the overflow of
                // the tabs themselves — and the icon cannot tell you which.
                // Guessing wrong costs a tap into a sheet you did not want.
                //
                // The word "All" plus a chevron says both things an icon could
                // not: that this lists the SAME categories the strip is
                // scrolling, and that it opens rather than navigates. The count
                // is what makes it worth opening — "All 9" tells you the strip
                // has more than the two labels you can see, which is exactly
                // the question a clipped tab raises.
                child: Container(
                  height: _kTabBarHeight,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${'all'.tr} ${labels.length}',
                        style: waddyBold.copyWith(
                          fontSize: 13,
                          color: WaddyColors.ink,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: WaddyColors.inkLight,
                      ),
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

  /// Lists every tab (full menu + categories) with how many items are
  /// currently loaded under each, letting the guest jump straight to one
  /// instead of scrubbing the horizontal tab strip.
  void _openMenuCategoriesSheet(
    BuildContext context,
    List<CategoryModel> categories,
    int activeTab, {
    required int allItemCount,
    required Map<int, List<Item>> groupedItems,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.78,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: WaddyColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: WaddyColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'close'.tr,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () => Navigator.of(sheetContext).pop(),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: WaddyColors.surfaceRaised,
                                shape: BoxShape.circle,
                              ),
                              child: const HugeIcon(
                                icon: HugeIcons.strokeRoundedCancel01,
                                size: 15,
                                color: WaddyColors.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          _categoriesLabel,
                          style: waddyBold.copyWith(
                            fontSize: 18,
                            color: WaddyColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: categories.length + 1,
                      itemBuilder: (_, i) {
                        final bool active = i == activeTab;
                        final String label =
                            i == 0
                                ? _allTabLabel
                                : (categories[i - 1].name ?? '');
                        final int count =
                            i == 0
                                ? allItemCount
                                : (groupedItems[categories[i - 1].id]?.length ??
                                    0);
                        return Semantics(
                          button: true,
                          selected: active,
                          child: InkWell(
                            onTap: () {
                              _selectTab(i);
                              Navigator.of(sheetContext).pop();
                            },
                            child: Container(
                              padding: EdgeInsets.only(
                                left: active ? 13 : 16,
                                top: 15,
                                bottom: 15,
                                right: 5,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color:
                                        active
                                            ? WaddyColors.ink
                                            : Colors.transparent,
                                    width: 3,
                                  ),
                                  bottom: const BorderSide(
                                    color: WaddyColors.divider,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    label,
                                    style: (active ? waddyBold : waddyMedium)
                                        .copyWith(
                                          fontSize: 15,
                                          color:
                                              active
                                                  ? WaddyColors.ink
                                                  : WaddyColors.inkMid,
                                        ),
                                  ),
                                  Text(
                                    '$count',
                                    style: waddyRegular.copyWith(
                                      fontSize: 15,
                                      color: WaddyColors.inkLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Pins the category strip. Rebuilds its child with `overlapsContent` so the
/// strip grows a shadow only once it is actually floating over the list.
///
/// [pinnedInset] is how far down from the scroll view's top edge the strip
/// should come to rest — the height of the scrolled header overlay, which is
/// painted in a [Stack] ABOVE this scroll view and would otherwise cover the
/// pinned strip completely.
///
/// It is spent as collapsed extent rather than as padding on the child: a
/// pinned header stops at `minExtent`, so growing minExtent by the inset is
/// what actually moves the resting position down. The child keeps its own
/// [height] and is pushed to the bottom of that box, so the strip's own
/// geometry is unchanged and only the gap above it grows. While the strip is
/// still scrolling toward its rest position that gap is transparent — the
/// hero and header scroll through it — so nothing is drawn in the inset here;
/// the overlay is what fills it once the two meet.
class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final double pinnedInset;
  final Widget Function(bool overlapping) builder;

  const _StickyTabDelegate({
    required this.height,
    required this.builder,
    this.pinnedInset = 0,
  });

  @override
  double get minExtent => height + pinnedInset;

  @override
  double get maxExtent => height + pinnedInset;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final Widget strip = builder(overlapsContent || shrinkOffset > 0);
    if (pinnedInset <= 0) return strip;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [SizedBox(height: pinnedInset), strip],
    );
  }

  @override
  bool shouldRebuild(_StickyTabDelegate old) =>
      old.height != height ||
      old.pinnedInset != pinnedInset ||
      old.builder != builder;
}
