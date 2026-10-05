import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/common/widgets/section_error_view.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_semantics.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/home/widgets/views/top_restaurants_view.dart';
import 'package:waddy_app/features/location/widgets/coming_soon_delivery.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Columns in the grid. Four (~76pt tiles on a 360pt phone, ~80 on 390): at
/// three the logos were ~110pt, bigger than anything else above the fold, and
/// the grid read as the page's headline rather than a shortcut into it.
const int _kColumns = 4;

/// Two full rows. The grid is a shortcut to the names people already know,
/// not the catalogue — the list below is the catalogue.
const int _kMaxBrands = _kColumns * 2;

const double _kGap = Dimensions.paddingSizeMedium;

/// Tile corner radius. Default (12), not Large: on a ~78pt tile a 16pt corner
/// rounds the logo's own corners off.
const double _kTileRadius = Dimensions.radiusDefault;

/// Tile to its perk line. Tight: the collar belongs to the logo above it.
const double _kBadgeGap = Dimensions.paddingSizeSmall;

/// Fits the compact [OfferCollarBadge], whose disc sets the row height. Fixed
/// so a tile with no perk keeps the same baseline as its neighbours.
const double _kBadgeRow = 24;

/// "Top brands": the zone's popular grocers as a 4×2 grid of square logo
/// tiles, each carrying its best perk underneath in the offer collar the food
/// rail uses.
///
/// Unnumbered on purpose: the order is the admin's, but it is a selection, not
/// a chart, so there is no rank to claim.
///
/// Fed by the admin's featured stores, in the order the admin set
/// (`featured_order`). A brand the admin hasn't featured is not shown, and with
/// none featured the section hides rather than inventing a list.
/// The admin-featured stores for the current module, in the admin's order, or
/// null while the list is still loading.
///
/// The featured list is shared with the aggregated dashboard, where it spans
/// every module, so on first entry to a module it can still hold the dashboard's
/// stores until the module's own fetch lands. Narrowing by module id keeps
/// another module's brands out of the grid in that window. Stores with no
/// `module_id` are kept — a thin payload is not evidence of a foreign store.
List<Store>? _featuredBrands(StoreListController controller) {
  final List<Store>? all = controller.featuredStoreList;
  if (all == null) return null;
  final int? moduleId = Get.find<SplashController>().module?.id;
  final List<Store> own =
      moduleId == null
          ? all
          : all
              .where((s) => s.moduleId == null || s.moduleId == moduleId)
              .toList();
  return rankFeaturedStores(own);
}

class ModuleTopBrandsGrid extends StatelessWidget {
  /// Builds the screen argument for the store route (module-specific).

  const ModuleTopBrandsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.featuredId,
      builder: (storeController) {
        final List<Store>? stores = _featuredBrands(storeController);

        if (stores == null) {
          // Null covers both in-flight and failed; both lists are fetched
          // under HomeSection.fastest, so its error flag tells them apart.
          return GetBuilder<HomeController>(
            id: HomeSection.fastest,
            builder: (homeController) {
              if (!homeController.hasError(HomeSection.fastest)) {
                return const _TopBrandsShimmer();
              }
              return SectionErrorView(
                headline: 'top_brands'.tr,
                onRetry: () => HomeScreen.loadData(true),
              );
            },
          );
        }
        if (stores.isEmpty) return const SizedBox.shrink();

        final List<Store> brands = stores.take(_kMaxBrands).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeRailHeader(
              headline: 'top_brands'.tr,
              subtitle: 'hand_picked_for_you'.tr,
              onSeeAll:
                  () => Get.toNamed(RouteHelper.getAllStoreRoute('featured')),
            ),
            _BrandGrid(
              count: brands.length,
              itemBuilder:
                  (index) => _BrandTile(store: brands[index], index: index),
            ),
          ],
        );
      },
    );
  }
}

/// Lays tiles out in rows of [_kColumns] with equal gaps, sized from the
/// available width. A plain Column of Rows rather than a GridView: six cells
/// never need laziness, and a GridView inside a sliver box wants a fixed
/// child aspect ratio, which the text-scaled badge row can't promise.
class _BrandGrid extends StatelessWidget {
  final int count;
  final Widget Function(int index) itemBuilder;

  const _BrandGrid({required this.count, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    final int rows = (count / _kColumns).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Column(
        children: [
          for (int r = 0; r < rows; r++) ...[
            if (r > 0) const SizedBox(height: _kGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int c = 0; c < _kColumns; c++) ...[
                  if (c > 0) const SizedBox(width: _kGap),
                  Expanded(
                    // An empty Expanded keeps a short last row's tiles the
                    // same width as the full rows above it.
                    child:
                        r * _kColumns + c < count
                            ? itemBuilder(r * _kColumns + c)
                            : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  final Store store;

  /// Position in the grid; staggers each tile's perk rotation.
  final int index;

  const _BrandTile({required this.store, required this.index});

  @override
  Widget build(BuildContext context) {
    final bool isOpen = store.open == 1;

    return PressableScale(
      semanticLabel: moduleStoreSemanticLabel(store),
      onTap: () => StoreNavigator.open(store),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                // Mint plate while the logo loads, same as the store rows.
                color: WaddyColors.mintSurface,
                borderRadius: BorderRadius.circular(_kTileRadius),
                border: Border.all(color: WaddyColors.divider),
                boxShadow: const [
                  BoxShadow(
                    color: WaddyColors.shadowTeal,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomImage(
                    image: store.logoFullUrl ?? '',
                    variants: store.logoVariants,
                    fit: BoxFit.cover,
                  ),
                  if (!isOpen)
                    Container(
                      color: WaddyColors.primary.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeSmall,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: WaddyColors.mint,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusSmall,
                          ),
                        ),
                        child: Text(
                          'closed'.tr,
                          style: waddyBold.copyWith(
                            fontSize: 11,
                            height: 1.3,
                            color: WaddyColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: _kBadgeGap),
          SizedBox(
            // Grows with the font setting (capped like the food rail's rows)
            // so a large-text user's label isn't clipped at the descenders.
            height:
                _kBadgeRow *
                MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3),
            child: Center(child: _BrandPerk(store: store, index: index)),
          ),
        ],
      ),
    );
  }
}

/// How long each perk holds before the next one slides in.
const Duration _kPerkHold = Duration(milliseconds: 2600);

/// Per-tile head start, so the grid's collars turn over in a ripple rather
/// than all flipping on the same frame.
const Duration _kPerkStagger = Duration(milliseconds: 220);

/// The line under a tile: the brand's store-wide discount and free delivery as
/// offer collars, shown one at a time, rotating — or, when it has neither,
/// "Up to X% off" if any of its items is marked down. With none of
/// those it falls back to its delivery time as quiet text, so every tile says
/// something and the row never reads as a missing badge.
class _BrandPerk extends StatefulWidget {
  final Store store;
  final int index;

  const _BrandPerk({required this.store, required this.index});

  @override
  State<_BrandPerk> createState() => _BrandPerkState();
}

class _BrandPerkState extends State<_BrandPerk> {
  Timer? _timer;
  int _shown = 0;

  /// A store-wide offer (discount or free delivery) outranks the item-level
  /// claim: when the brand has either, those are what the tile rotates, and
  /// "Up to X% off" appears only for a brand with neither.
  List<OfferCollarBadge> _collars() {
    final Store store = widget.store;
    final List<OfferCollarBadge> storeWide =
        [
          OfferCollarBadge.forDiscount(store, compact: true),
          OfferCollarBadge.forFreeDelivery(store, compact: true),
        ].whereType<OfferCollarBadge>().toList();
    if (storeWide.isNotEmpty) return storeWide;
    return [
      OfferCollarBadge.forMaxItemDiscount(store, compact: true),
    ].whereType<OfferCollarBadge>().toList();
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(_kPerkStagger * (widget.index % _kColumns), _start);
  }

  void _start() {
    _timer = Timer.periodic(_kPerkHold, (_) {
      if (!mounted) return;
      // Hold still while another route covers the home screen, and for
      // anyone who asked the system for less motion.
      if (!TickerMode.valuesOf(context).enabled ||
          MediaQuery.disableAnimationsOf(context)) {
        return;
      }
      if (_collars().length < 2) return;
      setState(() => _shown++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Store store = widget.store;
    return ZoneAware(
      builder: (context) {
        if (isComingSoon) return const ComingSoonText(fontSize: 11);

        final List<OfferCollarBadge> collars = _collars();
        // FittedBox: at three columns on a narrow phone a long label
        // ("Free delivery" in Arabic) can outrun ~100pt; shrinking it a
        // touch beats ellipsizing the one word that matters.
        if (collars.isNotEmpty) {
          final int at = _shown % collars.length;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            // Out first, then in: the two collars share one slot, so a plain
            // cross-fade paints both on top of each other for half the swap.
            switchInCurve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
            switchOutCurve: const Interval(0.6, 1.0, curve: Curves.easeInCubic),
            transitionBuilder:
                (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.45),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
            child: FittedBox(
              key: ValueKey<int>(at),
              fit: BoxFit.scaleDown,
              child: collars[at],
            ),
          );
        }

        final String? time = store.deliveryTime;
        if (time == null || time.isEmpty) return const SizedBox.shrink();
        // Scaled down rather than ellipsized: "40-60 min" on a ~78pt tile
        // would otherwise lose the unit, which is the half that says what the
        // number means.
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                size: 11,
                color: WaddyColors.inkLight,
              ),
              const SizedBox(width: 3),
              Text(
                time.contains('min') ? time : '$time ${'min'.tr}',
                style: waddyMedium.copyWith(
                  fontSize: 11,
                  color: WaddyColors.inkLight,
                ),
                maxLines: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBrandsShimmer extends StatelessWidget {
  const _TopBrandsShimmer();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: WaddyColors.divider,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
    );

    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              0,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeMedium,
            ),
            child: bar(140, 22),
          ),
          _BrandGrid(
            count: _kMaxBrands,
            itemBuilder:
                (_) => Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: WaddyColors.divider,
                          borderRadius: BorderRadius.circular(_kTileRadius),
                        ),
                      ),
                    ),
                    const SizedBox(height: _kBadgeGap),
                    SizedBox(
                      height: _kBadgeRow,
                      child: Center(child: bar(56, 14)),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}
