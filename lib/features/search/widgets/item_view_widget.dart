import 'package:waddy_app/features/search/controllers/search_controller.dart'
    as search;
import 'package:waddy_app/features/search/widgets/search_store_row.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/no_data_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/item_view.dart';

class ItemViewWidget extends StatelessWidget {
  final bool isItem;
  const ItemViewWidget({super.key, required this.isItem});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      body: GetBuilder<search.SearchController>(
        builder: (searchController) {
          // The restaurants tab gets the flat search row rather than the browse
          // card ItemsView draws: a result list is scanned for a name, not
          // browsed, so it drops the card surface and fits roughly twice as many
          // per screen. Items keep ItemsView — that grid is shared with ten
          // other callers and its layout is not this screen's to change.
          if (isItem) {
            return _buildStoreResults(context, searchController);
          }

          return SingleChildScrollView(
            child: FooterView(
              child: SizedBox(
                width: Dimensions.maxContentWidth,
                child: ItemsView(
                  isStore: isItem,
                  items: searchController.searchItemList,
                  stores: searchController.searchStoreList,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoreResults(
    BuildContext context,
    search.SearchController searchController,
  ) {
    final stores = searchController.searchStoreList;

    if (stores == null) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          Dimensions.paddingSizeDefault,
          Dimensions.paddingSizeSmall,
          Dimensions.paddingSizeDefault,
          Dimensions.paddingSizeExtraLarge,
        ),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder:
            (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
            ),
        itemBuilder: (context, index) => const _StoreRowShimmer(),
      );
    }

    if (stores.isEmpty) {
      return NoDataScreen(text: 'no_store_found'.tr);
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeSmall,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeExtraLarge + MediaQuery.paddingOf(context).bottom,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: stores.length,
      separatorBuilder:
          (context, index) => Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
      itemBuilder: (context, index) => SearchStoreRow(store: stores[index]),
    );
  }
}

/// The loading placeholder for a [SearchStoreRow] — same 88pt thumbnail and
/// same three text lines, so results do not jump when they land.
///
/// The shared [ItemShimmer] is not reusable here: it puts an `Expanded` inside
/// a `Column`, which needs the bounded height the browse grid gives it and
/// overflows in a scroll view.
class _StoreRowShimmer extends StatelessWidget {
  const _StoreRowShimmer();

  @override
  Widget build(BuildContext context) {
    final bar = Theme.of(context).shadowColor.withValues(alpha: 0.35);

    Widget line(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bar,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge - 2),
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeDefault),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                line(150, 13),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                line(100, 10),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                line(70, 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
