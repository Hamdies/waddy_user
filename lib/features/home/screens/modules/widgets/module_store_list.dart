import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/sliver_paginated_list.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Vertical browse list for module home screens: shimmer while loading,
/// empty state with optional reset action, else an infinite-scrolling
/// paginated list (12 stores per page, driven by the outer scroll view).
///
/// Sliver-only. There used to be a box twin built on `PaginatedListView`, whose
/// page was `Column(children: stores.map(cardBuilder))` — every card in the
/// catalogue constructed the moment the list was laid out. Both module homes
/// that used it now render as slivers, so it was deleted rather than left to
/// drift out of sync with this one.
///
/// Returns a sliver, so it must be placed in a `CustomScrollView`'s `slivers:`
/// — not inside a `Column`.
class ModuleStoreListSliver extends StatelessWidget {
  final ScrollController scrollController;
  final StoreModel? storeModel;
  final Widget Function(Store store) cardBuilder;

  /// Shown while [storeModel] is null. Pass an ordinary box widget — it is
  /// wrapped in a `SliverToBoxAdapter` here.
  final Widget shimmer;

  /// Rendered glyph for the empty state — see [ModuleStoreListEmpty.icon] for
  /// why this is a `Widget` rather than an [IconData].
  final Widget emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final bool isLastInScrollView;

  const ModuleStoreListSliver({
    super.key,
    required this.scrollController,
    required this.storeModel,
    required this.cardBuilder,
    required this.shimmer,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.isLastInScrollView = false,
  });

  @override
  Widget build(BuildContext context) {
    final stores = storeModel?.stores;

    if (stores == null) {
      return SliverToBoxAdapter(child: shimmer);
    }

    if (stores.isEmpty) {
      return SliverToBoxAdapter(
        child: ModuleStoreListEmpty(
          icon: emptyIcon,
          title: emptyTitle,
          subtitle: emptySubtitle,
          isLastInScrollView: isLastInScrollView,
        ),
      );
    }

    return SliverPaginatedList(
      scrollController: scrollController,
      itemsPerPage: 12,
      totalSize: storeModel!.totalSize,
      offset: storeModel!.offset,
      onPaginate:
          (int? offset) async =>
              await Get.find<StoreController>().getStoreList(offset!, false),
      itemCount: stores.length,
      itemBuilder: (context, index) => cardBuilder(stores[index]),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      // The cart bar, not the nav, is the bottom overlay on food/grocery —
      // and it is taller than the nav whenever its reward strip shows.
      bottomReserve:
          isLastInScrollView ? Dimensions.cartBarReserve(context) : 0,
    );
  }
}

/// Empty state for the store list. A plain box widget: the caller wraps it.
class ModuleStoreListEmpty extends StatelessWidget {
  /// The rendered glyph, already sized and coloured by the caller — a `Widget`
  /// rather than an [IconData] so callers can pass either a Material `Icon` or
  /// a `HugeIcon`, whose glyphs are path data and not font codepoints.
  final Widget icon;
  final String title;
  final String subtitle;
  final bool isLastInScrollView;

  const ModuleStoreListEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLastInScrollView = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Dimensions.paddingSizeDefault,
        right: Dimensions.paddingSizeDefault,
        top: Dimensions.paddingSizeExtraLarge,
        bottom:
            Dimensions.paddingSizeExtraLarge +
            (isLastInScrollView ? Dimensions.cartBarReserve(context) : 0),
      ),
      child: Center(
        child: Column(
          children: [
            icon,
            const SizedBox(height: 14),
            Text(
              title,
              style: waddyMedium.copyWith(
                fontSize: 15,
                // inkMid, not a mid grey: this is the line that tells the user
                // why the list is empty, and it was rendering at a weight the
                // eye skips.
                color: WaddyColors.inkMid,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: waddyRegular.copyWith(
                fontSize: 12,
                // Was grey.shade400 — 2.29:1 on white, effectively invisible
                // on the line that names the fix. inkLight is 4.59:1.
                color: WaddyColors.inkLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
