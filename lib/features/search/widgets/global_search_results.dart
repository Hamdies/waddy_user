import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/item/screens/mart_product_screen.dart';
import 'package:waddy_app/features/search/controllers/search_controller.dart'
    as search;
import 'package:waddy_app/features/search/domain/models/global_search_model.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/features/store/widgets/store_product_card.dart';
import 'package:waddy_app/util/app_design_tokens.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Results of the Home dashboard's global search ("Mart Global Search" 4b):
/// a tab strip by kind of place, Offers / Free delivery chips, then one block
/// per store — logo, name, delivery line, perks, and a rail of the products
/// that matched.
///
/// With a [scope] other than [SearchScope.all] — the Restaurants and Groceries
/// homes' searches ("Mart Restaurant Search", "Mart Grocery Search") — the
/// same blocks drop the tab strip (everything is one kind of place), gain a Top
/// rated chip and a "N stores for …" line; restaurants also carry cuisines on
/// the delivery line.
///
/// Stores, not products, are the unit: the dashboard has no module, so the
/// same item at a restaurant and a grocer are different orders from different
/// places, and the shopper picks the place first.
class GlobalSearchResults extends StatelessWidget {
  final search.SearchController controller;
  final String query;
  final VoidCallback onRetry;
  final SearchScope scope;

  const GlobalSearchResults({
    super.key,
    required this.controller,
    required this.query,
    required this.onRetry,
    this.scope = SearchScope.all,
  });

  static const Color _ink = Color(0xFF1A1F1E);
  static const Color _inkMuted = Color(0xFF6B7876);
  static const Color _mintFill = Color(0xFFE6F4F3);
  static const Color _mintBorder = Color(0xFFB9ECDD);
  static const Color _line = Color(0xFFD4F0E8);

  @override
  Widget build(BuildContext context) {
    final List<GlobalSearchStore>? loaded = controller.globalStores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scope == SearchScope.all) _Tabs(controller: controller),
        Expanded(
          child:
              loaded == null
                  ? const _Skeleton()
                  : controller.globalFailed
                  ? _Message(
                    title: 'something_went_wrong'.tr,
                    body: null,
                    actionLabel: 'try_again'.tr,
                    onAction: onRetry,
                  )
                  : _List(controller: controller, query: query, scope: scope),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  final search.SearchController controller;
  const _Tabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    final List<(SearchKind?, String)> tabs = <(SearchKind?, String)>[
      (null, 'all'.tr),
      (SearchKind.restaurants, 'restaurants'.tr),
      (SearchKind.groceries, 'gs_groceries'.tr),
      (SearchKind.shops, 'gs_shops'.tr),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: GlobalSearchResults._line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeLarge,
        ),
        child: Row(
          children: [
            for (final (SearchKind? kind, String label) in tabs)
              _Tab(
                label: label,
                count:
                    controller.globalStores == null
                        ? null
                        : controller.globalCount(kind),
                selected: controller.globalKind == kind,
                onTap: () => controller.setGlobalKind(kind),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      onTap: onTap,
      child: Container(
        height: 46,
        margin: const EdgeInsetsDirectional.only(end: 22),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 3,
              color:
                  selected ? AppDesignTokens.primaryDark : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: (selected ? waddyBold : waddyMedium).copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color:
                    selected
                        ? AppDesignTokens.primaryDark
                        : GlobalSearchResults._inkMuted,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: waddyMedium.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: GlobalSearchResults._inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  final search.SearchController controller;
  final String query;
  final SearchScope scope;
  const _List({
    required this.controller,
    required this.query,
    required this.scope,
  });

  @override
  Widget build(BuildContext context) {
    final List<GlobalSearchStore> stores = controller.globalVisible;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        bottom:
            Dimensions.paddingSizeExtraLarge +
            MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeMedium + 2,
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeSmall + 2,
          ),
          child: Row(
            children: [
              _FilterChip(
                label: 'offers'.tr,
                on: controller.globalOffersOnly,
                onTap: controller.toggleGlobalOffers,
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              _FilterChip(
                label: 'free_delivery'.tr,
                on: controller.globalFreeOnly,
                onTap: controller.toggleGlobalFree,
              ),
              if (scope != SearchScope.all) ...[
                const SizedBox(width: Dimensions.paddingSizeSmall),
                _FilterChip(
                  label: 'gs_top_rated'.tr,
                  on: controller.globalTopOnly,
                  onTap: controller.toggleGlobalTop,
                ),
              ],
            ],
          ),
        ),

        if (scope != SearchScope.all && stores.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimensions.paddingSizeLarge,
              Dimensions.paddingSizeExtraSmall,
              Dimensions.paddingSizeLarge,
              Dimensions.paddingSizeExtraSmall,
            ),
            child: Text(
              (scope == SearchScope.restaurants
                      ? 'gs_restaurants_for'
                      : 'gs_stores_for')
                  .trParams({'n': '${stores.length}', 'q': query}),
              style: waddyRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall - 1,
                color: GlobalSearchResults._inkMuted,
              ),
            ),
          ),

        if (stores.isEmpty)
          _Message(
            title:
                scope == SearchScope.all
                    ? '${'no_matches_for'.tr} “$query”'
                    : scope == SearchScope.restaurants
                    ? 'gs_no_restaurants'.tr
                    : 'gs_no_stores'.tr,
            body:
                scope == SearchScope.all
                    ? 'gs_try_another'.tr
                    : 'gs_try_remove_filter'.tr,
          )
        else
          for (final GlobalSearchStore store in stores)
            _StoreBlock(
              key: ValueKey<int?>(store.id),
              store: store,
              withCuisines: scope == SearchScope.restaurants,
            ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.96,
      minSize: Dimensions.minTapTarget,
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeMedium + 2,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              on ? AppDesignTokens.primaryDark : GlobalSearchResults._mintFill,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color:
                on
                    ? AppDesignTokens.primaryDark
                    : GlobalSearchResults._mintBorder,
          ),
        ),
        child: Text(
          label,
          style: waddyMedium.copyWith(
            fontSize: Dimensions.fontSizeSmall - 1,
            color: on ? Colors.white : AppDesignTokens.primaryDark,
          ),
        ),
      ),
    );
  }
}

class _StoreBlock extends StatelessWidget {
  final GlobalSearchStore store;

  /// Restaurant search appends the cuisines to the delivery line.
  final bool withCuisines;
  const _StoreBlock({
    super.key,
    required this.store,
    this.withCuisines = false,
  });

  void _openStore() => StoreNavigator.open(
    Store(
      id: store.id,
      name: store.name,
      logoFullUrl: store.logoUrl,
      moduleId: store.moduleId,
    ),
    page: 'search',
  );

  /// The product page of an item from a module the user is not in: switch to
  /// that module first, as every other tap that lands on a thing does.
  void _openItem(Item item) {
    if (item.moduleId != null) {
      Get.find<SplashController>().activateModuleFor(item.moduleId);
    }
    MartProductScreen.open(item);
  }

  String get _kindLabel {
    switch (store.kind) {
      case SearchKind.restaurants:
        return 'restaurant'.tr;
      case SearchKind.groceries:
        return 'gs_grocery_one'.tr;
      case SearchKind.shops:
        return 'gs_shop_one'.tr;
    }
  }

  /// "25–35 mins · 1.2 km", with whichever half the store states.
  String? get _meta {
    final List<String> parts = <String>[];
    if (store.maxDeliveryTime > 0) {
      final String range =
          store.minDeliveryTime > 0
              ? '${store.minDeliveryTime}–${store.maxDeliveryTime}'
              : '${store.maxDeliveryTime}';
      parts.add('$range ${'mins'.tr}');
    }
    if (store.distanceKm != null) {
      parts.add('${store.distanceKm!.toStringAsFixed(1)} ${'km'.tr}');
    }
    if (withCuisines && store.cuisines.isNotEmpty) {
      parts.add(store.cuisines.join(', '));
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final String? meta = _meta;

    return Container(
      padding: const EdgeInsets.only(top: 14, bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GlobalSearchResults._line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            scale: 0.99,
            alignment: AlignmentDirectional.centerStart,
            onTap: _openStore,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              child: Row(
                children: [
                  _Logo(url: store.logoUrl, closed: !store.open),
                  const SizedBox(width: Dimensions.paddingSizeMedium),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                store.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: waddyBold.copyWith(
                                  fontSize: Dimensions.fontSizeDefault + 1,
                                  color: GlobalSearchResults._ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              height: 18,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: GlobalSearchResults._mintFill,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _kindLabel,
                                style: waddyBold.copyWith(
                                  fontSize: 10,
                                  color: AppDesignTokens.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (meta != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: waddyRegular.copyWith(
                                fontSize: Dimensions.fontSizeExtraSmall,
                                color: GlobalSearchResults._inkMuted,
                              ),
                            ),
                          ),
                        if (store.hasOffer || store.freeDelivery)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: [
                                if (store.hasOffer)
                                  _Perk(
                                    label: 'gs_offer_select_items'.trParams({
                                      'pct': '${store.offerPercent}',
                                    }),
                                    filled: true,
                                  ),
                                if (store.freeDelivery)
                                  _Perk(
                                    label: 'free_delivery'.tr,
                                    filled: false,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (store.items.isNotEmpty) ...[
            const SizedBox(height: Dimensions.paddingSizeMedium),
            SizedBox(
              height: StoreProductCard.railHeight(context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                ),
                itemCount: store.items.length,
                separatorBuilder:
                    (_, _) =>
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                itemBuilder:
                    (context, i) => StoreProductCard(
                      item: store.items[i],
                      onOpen: () => _openItem(store.items[i]),
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "25% off select items" on deep teal, "Free delivery" on mint.
class _Perk extends StatelessWidget {
  final String label;
  final bool filled;
  const _Perk({required this.label, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            filled
                ? AppDesignTokens.primaryDark
                : GlobalSearchResults._mintFill,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: waddyBold.copyWith(
          fontSize: 11,
          color:
              filled ? AppDesignTokens.secondaryNeon : const Color(0xFF1D706A),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final String? url;
  final bool closed;
  const _Logo({required this.url, required this.closed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFF1FBF7),
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: GlobalSearchResults._line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomImage(
            image: url ?? '',
            fit: BoxFit.contain,
            fallback: const SizedBox(),
          ),
          if (closed)
            Container(
              color: const Color(0xB31A1F1E),
              alignment: Alignment.center,
              child: Text(
                'closed'.tr,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeExtraOverLarge,
        vertical: 60,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: waddyBold.copyWith(
              fontSize: Dimensions.fontSizeDefault + 2,
              color: GlobalSearchResults._ink,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall - 2),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: waddyRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall - 1,
                color: GlobalSearchResults._inkMuted,
              ),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: Dimensions.paddingSizeDefault),
            Pressable(
              minSize: Dimensions.minTapTarget,
              scale: 0.95,
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: AppDesignTokens.primaryDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Two store headers over blank rails — the shape of the answer on its way.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double w, double h, double r) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F3),
        borderRadius: BorderRadius.circular(r),
      ),
    );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      children: [
        for (int g = 0; g < 2; g++) ...[
          Row(
            children: [
              block(60, 60, Dimensions.radiusLarge),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(140, 14, Dimensions.radiusExtraSmall),
                  const SizedBox(height: 8),
                  block(100, 10, Dimensions.radiusExtraSmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeMedium),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (int i = 0; i < 3; i++) ...[
                  block(StoreProductCard.width, 150, Dimensions.radiusLarge),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                ],
              ],
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraLarge),
        ],
      ],
    );
  }
}
