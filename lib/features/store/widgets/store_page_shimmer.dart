import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/widgets/store_product_card.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// Which grocery store page is loading. Food keeps
/// `StoreDetailsScreenShimmerWidget`, shaped like its photo-cover hero.
enum StorePageShimmerLayout {
  /// Supermarket (`StoreScreen`): category tiles, a ranked rail, an aisle
  /// panel.
  mart,

  /// Butcher, greengrocer, pet shop…: a card rail, then the menu rows.
  specialty,
}

/// A grocery store page in outline, drawn on the real mint header so the page
/// lands without a jump: same gradient, same back · identity · basket row,
/// same search field and promise chips.
///
/// The back button works, so a slow store can be left. When the store from the
/// list is in hand, its name and logo show in the header straight away. That's
/// the part the shopper tapped on, so it shouldn't flicker to a bar.
class StorePageShimmer extends StatelessWidget {
  final StorePageShimmerLayout layout;
  final Store? store;

  const StorePageShimmer({
    super.key,
    this.layout = StorePageShimmerLayout.mart,
    this.store,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WaddyColors.canvas,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(store: store),
            if (layout == StorePageShimmerLayout.mart) ...[
              const _Title(top: 4),
              const _CategoryTiles(),
              const _Title(),
              const _CardRail(),
              const _MintPanel(),
            ] else ...[
              const _Title(),
              const _CardRail(),
              const _Title(),
              const _Tabs(),
              const _MenuRows(),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────

/// One shimmer block. A teal-tinted grey ([WaddyColors.divider]): the raised
/// surface tone is a shade off the canvas and reads as nothing loading.
Widget _bone({
  double? width,
  required double height,
  double radius = Dimensions.radiusSmall,
  Color color = WaddyColors.divider,
}) => Container(
  width: width,
  height: height,
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
  ),
);

class _Header extends StatelessWidget {
  final Store? store;

  const _Header({required this.store});

  @override
  Widget build(BuildContext context) {
    final String? name = store?.name;
    // White bones on the mint, as the header's own white controls.
    final Color onMint = WaddyColors.surface.withValues(alpha: 0.7);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: StoreHeroBannerWidget.gradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeSmall,
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeExtraLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _Back(),
                  const SizedBox(width: 6),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: WaddyColors.surface,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                      border: Border.all(color: WaddyColors.surface, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        (store?.logoFullUrl ?? '').isNotEmpty
                            ? CustomImage(
                              image: store!.logoFullUrl!,
                              variants: store!.logoVariants,
                              fit: BoxFit.contain,
                            )
                            : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child:
                        name != null && name.isNotEmpty
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: waddyBold.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: displayTracking(-0.4),
                                    color: WaddyColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Shimmer(
                                  child: _bone(
                                    width: 56,
                                    height: 10,
                                    color: onMint,
                                  ),
                                ),
                              ],
                            )
                            : Shimmer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _bone(width: 140, height: 16, color: onMint),
                                  const SizedBox(height: 6),
                                  _bone(width: 56, height: 10, color: onMint),
                                ],
                              ),
                            ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: WaddyColors.surface,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Shimmer(
                child: Container(
                  height: Dimensions.minTapTarget,
                  decoration: BoxDecoration(
                    color: WaddyColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeDefault,
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: _bone(width: 150, height: 12),
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeMedium),
              Shimmer(
                child: Row(
                  children: [
                    for (final double w in const [96, 132, 128]) ...[
                      _bone(width: w, height: 30, radius: 999, color: onMint),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Get.back(),
      semanticLabel: 'back'.tr,
      scale: WaddyMotion.pressControl,
      child: SizedBox(
        width: 40,
        height: 48,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: WaddyColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: WaddyColors.primary.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded,
              size: 18,
              color: WaddyColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A section title bar at `StoreSectionHeader`'s insets.
class _Title extends StatelessWidget {
  final double top;

  const _Title({this.top = 32});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, top, 20, 14),
      child: Shimmer(child: _bone(width: 170, height: 22)),
    );
  }
}

/// "Shop by category": two rows of four rounded tiles, each with its label.
class _CategoryTiles extends StatelessWidget {
  const _CategoryTiles();

  @override
  Widget build(BuildContext context) {
    Widget tile() => Expanded(
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: _bone(height: double.infinity, radius: 18),
          ),
          const SizedBox(height: 7),
          _bone(width: 52, height: 11),
        ],
      ),
    );
    Widget row() => Row(
      children: [
        for (int i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: Dimensions.paddingSizeMedium),
          tile(),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Shimmer(
        child: Column(
          children: [
            row(),
            const SizedBox(height: Dimensions.paddingSizeMedium),
            row(),
          ],
        ),
      ),
    );
  }
}

/// A [StoreProductCard] in outline: photo, two name lines, price.
class _Card extends StatelessWidget {
  final bool onMint;

  const _Card({this.onMint = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: StoreProductCard.width,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(
          color: onMint ? Colors.transparent : WaddyColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bone(
            height: 120,
            radius: Dimensions.radiusDefault,
            color: WaddyColors.surfaceRaised,
          ),
          // Name, size, then the price on the foot — the card's own order.
          const SizedBox(height: 10),
          _bone(width: 120, height: 12),
          const SizedBox(height: 6),
          _bone(width: 84, height: 12),
          const Spacer(),
          _bone(width: 64, height: 18),
        ],
      ),
    );
  }
}

class _CardRail extends StatelessWidget {
  final bool onMint;
  final double inset;

  const _CardRail({this.onMint = false, this.inset = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: StoreProductCard.railHeight(context),
      child: Shimmer(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: inset),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, __) => _Card(onMint: onMint),
        ),
      ),
    );
  }
}

/// The supermarket's first aisle group: mint panel, tab titles, cards.
class _MintPanel extends StatelessWidget {
  const _MintPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Shimmer(
              child: Row(
                children: [
                  _bone(width: 120, height: 22, color: WaddyColors.surface),
                  const SizedBox(width: 20),
                  _bone(width: 90, height: 22, color: WaddyColors.surface),
                ],
              ),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeMedium),
          const _CardRail(onMint: true, inset: 16),
        ],
      ),
    );
  }
}

/// The specialty page's pinned category tabs.
class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Shimmer(
        child: Row(
          children: [
            for (final double w in const [112, 96, 104]) ...[
              _bone(width: w, height: 36, radius: 999),
              const SizedBox(width: Dimensions.paddingSizeSmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// Menu rows: photo on the end, name, two blurb lines, price.
class _MenuRows extends StatelessWidget {
  const _MenuRows();

  @override
  Widget build(BuildContext context) {
    Widget row() => Container(
      height: 102,
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: WaddyColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bone(width: 150, height: 14),
                  const SizedBox(height: 8),
                  _bone(width: 190, height: 10),
                  const SizedBox(height: 6),
                  _bone(width: 120, height: 10),
                  const SizedBox(height: 10),
                  _bone(width: 64, height: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          _bone(
            width: 84,
            height: 84,
            radius: Dimensions.radiusDefault,
            color: WaddyColors.surfaceRaised,
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Shimmer(
        child: Column(
          children: [
            for (int i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              row(),
            ],
          ],
        ),
      ),
    );
  }
}
