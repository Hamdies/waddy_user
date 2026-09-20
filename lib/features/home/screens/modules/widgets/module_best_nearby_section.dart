import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/section_error_view.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_ribbon_sticker.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_section_header.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_semantics.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// "Popular restaurants" / "Best store nearby": horizontal full-bleed
/// magazine-style store cards fed by popular (fallback latest) stores.
class ModuleBestNearbySection extends StatelessWidget {
  final String title;
  final ModuleStickerStyle stickerStyle;
  final String closedLabel;
  final double bottomPadding;
  final double shimmerBottomPadding;

  /// Builds the screen argument for the store route (module-specific).
  final Object Function(Store store) storeScreenBuilder;

  const ModuleBestNearbySection({
    super.key,
    required this.title,
    required this.stickerStyle,
    required this.closedLabel,
    required this.storeScreenBuilder,
    this.bottomPadding = 24,
    this.shimmerBottomPadding = 24,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<StoreController>(
      builder: (storeController) {
        final stores =
            storeController.popularStoreList ?? storeController.latestStoreList;
        if (stores == null) {
          // Null means "not loaded" — which covers both "still in flight" and
          // "the fetch failed" (`G-06`). Told apart, they need opposite
          // treatment: in flight is a shimmer, failed is a retry row, and
          // before this the failed case shimmered for the rest of the session.
          // Both lists are fetched under `HomeSection.fastest`, so that is the
          // id whose failure state answers the question.
          return GetBuilder<HomeController>(
            id: HomeSection.fastest,
            builder: (homeController) {
              if (!homeController.hasError(HomeSection.fastest)) {
                return ModuleBestNearbyShimmer(
                  bottomPadding: shimmerBottomPadding,
                );
              }
              return Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: SectionErrorView(
                  headline: title,
                  onRetry: () => HomeScreen.loadData(true),
                ),
              );
            },
          );
        }
        // Genuinely empty stays quiet: a zone with nothing open is a fact, not
        // something the user can retry their way out of.
        if (stores.isEmpty) return const SizedBox();

        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModuleSectionHeader(
                title: title,
                onViewAll:
                    () => Get.toNamed(
                      RouteHelper.getAllStoreRoute(
                        'popular',
                        isNearbyStore: true,
                      ),
                    ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 155,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: stores.length > 8 ? 8 : stores.length,
                  padding: const EdgeInsetsDirectional.only(
                    start: Dimensions.paddingSizeDefault,
                  ),
                  itemBuilder: (context, index) {
                    return _BestNearbyCard(
                      store: stores[index],
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                      stickerStyle: stickerStyle,
                      closedLabel: closedLabel,
                      storeScreenBuilder: storeScreenBuilder,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BestNearbyCard extends StatelessWidget {
  final Store store;
  final Color primaryColor;
  final Color accentColor;
  final ModuleStickerStyle stickerStyle;
  final String closedLabel;
  final Object Function(Store store) storeScreenBuilder;

  const _BestNearbyCard({
    required this.store,
    required this.primaryColor,
    required this.accentColor,
    required this.stickerStyle,
    required this.closedLabel,
    required this.storeScreenBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOpen = store.open == 1;
    final stickers = moduleStickersForStore(store, stickerStyle);

    return PressableScale(
      semanticLabel: moduleStoreSemanticLabel(store),
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: storeScreenBuilder(store),
          ),
      child: Container(
        width: 210,
        margin: const EdgeInsetsDirectional.only(
          end: Dimensions.paddingSizeMedium,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomImage(
                  image: store.coverPhotoFullUrl ?? '',
                  fit: BoxFit.cover,
                  variants: store.coverPhotoVariants,
                  // Positioned.fill leaves `width` null, so the decode would
                  // otherwise be sized to the screen rather than to this
                  // 210pt card.
                  decodeWidth: 210,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        primaryColor.withValues(alpha: 0.6),
                        primaryColor.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.3, 0.70, 1.0],
                    ),
                  ),
                ),
              ),
              if (!isOpen)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.paddingSizeLarge,
                            vertical: Dimensions.paddingSizeSmall,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusExtraSmall,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Text(
                            closedLabel,
                            style: waddyBold.copyWith(
                              fontSize: 16,
                              color: Colors.black87,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              PositionedDirectional(
                top: 12,
                start: 12,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    child: CustomImage(
                      image: store.logoFullUrl ?? '',
                      fit: BoxFit.cover,
                      variants: store.logoVariants,
                      decodeWidth: 44,
                    ),
                  ),
                ),
              ),
              if (stickers.isNotEmpty && isOpen)
                PositionedDirectional(
                  top: 12,
                  end: 0,
                  child: ModuleRibbonSticker(sticker: stickers.first),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name ?? '',
                        style: waddyBold.copyWith(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (store.deliveryTime != null)
                        ModuleInfoPill(
                          icon: Icons.schedule_rounded,
                          text: '${store.deliveryTime}',
                          bgColor: accentColor,
                          textColor: primaryColor,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModuleBestNearbyShimmer extends StatelessWidget {
  final double bottomPadding;

  const ModuleBestNearbyShimmer({super.key, this.bottomPadding = 24});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Shimmer(
              child: Container(
                width: 180,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 185,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              padding: const EdgeInsetsDirectional.only(
                start: Dimensions.paddingSizeDefault,
              ),
              itemBuilder:
                  (context, index) => Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: Dimensions.paddingSizeMedium,
                    ),
                    child: Shimmer(
                      child: Container(
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusLarge,
                          ),
                        ),
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
