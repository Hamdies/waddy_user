import 'package:waddy_app/common/widgets/add_to_cart_control.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Store-specific version of SpecialOfferView.
/// Accepts [items] directly instead of pulling from global ItemController.
class StoreSpecialOfferView extends StatefulWidget {
  final List<Item> items;
  const StoreSpecialOfferView({super.key, required this.items});

  @override
  State<StoreSpecialOfferView> createState() => _StoreSpecialOfferViewState();
}

class _StoreSpecialOfferViewState extends State<StoreSpecialOfferView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  int _currentPage = 0;

  // Colors derived from Theme in build methods

  static const double kCardWidth = 160.0;
  static const double kCardPadding = 8.0;
  static const double kCardBorderRadius = 12.0;
  static const double kImageWidth = 140.0;
  static const double kImageHeight = 90.0;
  static const double kImageBorderRadius = 10.0;
  static const double kProductNameSize = 14.0;
  static const double kBannerTextSize = 13.0;
  static const double kDecorativeTextSize = 15.0;
  static const double kCarouselHeight = 240.0;
  static const double kCarouselViewportFraction = 0.46;
  static const Duration kAutoPlayInterval = Duration(seconds: 4);
  static const Duration kAutoPlayAnimationDuration = Duration(
    milliseconds: 800,
  );

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final displayItems =
        widget.items.length > 12 ? widget.items.sublist(0, 12) : widget.items;
    final Color primaryTeal = Theme.of(context).primaryColor;
    final Color accentGreen = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<HomeController>(
      builder: (homeController) {
        final isRamadanMode = homeController.showRamadanDecorations;

        final container = Container(
          margin: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeSmall,
            vertical: Dimensions.paddingSizeMedium,
          ),
          decoration: BoxDecoration(
            color: primaryTeal,
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            border: Border.all(color: accentGreen, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isRamadanMode
                  ? RamadanStringLightWrapper(
                    showTopString: false,
                    showBottomString: true,
                    alwaysOn: true,
                    child: _buildMagazineHeader(context),
                  )
                  : _buildMagazineHeader(context),
              _buildDecorativeTextRow(),
              const SizedBox(height: 10),
              CarouselSlider.builder(
                carouselController: _carouselController,
                itemCount: displayItems.length,
                itemBuilder: (context, index, realIndex) {
                  return _buildMagazineProductCard(
                    context,
                    displayItems[index],
                    index + 1,
                  );
                },
                options: CarouselOptions(
                  height: kCarouselHeight,
                  viewportFraction: kCarouselViewportFraction,
                  enlargeCenterPage: true,
                  enlargeFactor: 0.15,
                  enableInfiniteScroll: true,
                  autoPlay: true,
                  autoPlayInterval: kAutoPlayInterval,
                  autoPlayAnimationDuration: kAutoPlayAnimationDuration,
                  autoPlayCurve: Curves.easeInOutCubic,
                  pauseAutoPlayOnTouch: true,
                  pauseAutoPlayOnManualNavigate: true,
                  onPageChanged: (index, reason) {
                    if (mounted) {
                      setState(() => _currentPage = index);
                    }
                  },
                ),
              ),
              _buildPageIndicators(displayItems.length),
              _buildScrollingBanner(),
            ],
          ),
        );

        return container;
      },
    );
  }

  Widget _buildMagazineHeader(BuildContext context) {
    final Color primaryTeal = Theme.of(context).primaryColor;
    final Color accentGreen = Theme.of(context).secondaryHeaderColor;
    final Color primaryDarker =
        HSLColor.fromColor(primaryTeal)
            .withLightness(
              (HSLColor.fromColor(primaryTeal).lightness - 0.03).clamp(
                0.0,
                1.0,
              ),
            )
            .toColor();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeMedium,
        vertical: Dimensions.paddingSizeSmall,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeLarge,
            vertical: Dimensions.paddingSizeSmall,
          ),
          decoration: BoxDecoration(
            color: accentGreen,
            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            border: Border.all(color: primaryDarker, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Text(
            'special_offer'.tr.toUpperCase(),
            style: waddyBold.copyWith(
              fontSize: 18,
              color: primaryTeal,
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(1, 1),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecorativeTextRow() {
    return GetBuilder<HomeController>(
      builder: (homeController) {
        final isRamadanMode = homeController.showRamadanDecorations;
        final Color accentGreen = Theme.of(context).secondaryHeaderColor;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: Dimensions.paddingSizeExtraSmall,
          ),
          child:
              isRamadanMode
                  ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDecorativeText('CRAZY', accentGreen),
                      _buildStar(),
                      _buildDecorativeText('BIG', accentGreen),
                      _buildStar(),
                      _buildDecorativeText('SALE', accentGreen),
                    ],
                  ),
        );
      },
    );
  }

  Widget _buildDecorativeText(String text, Color color) {
    return Stack(
      children: [
        Text(
          text,
          style: waddyBold.copyWith(
            fontSize: kDecorativeTextSize,
            color: Theme.of(context).primaryColor,
            letterSpacing: 1,
          ),
        ),
        Positioned(
          left: -1,
          top: -1,
          child: Text(
            text,
            style: waddyBold.copyWith(
              fontSize: kDecorativeTextSize,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStar() {
    return Icon(
      Icons.star,
      color: Theme.of(context).secondaryHeaderColor,
      size: 16,
    );
  }

  Widget _buildPageIndicators(int itemCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(itemCount, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _currentPage == index ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color:
                  _currentPage == index
                      ? Theme.of(context).secondaryHeaderColor
                      : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMagazineProductCard(
    BuildContext context,
    Item item,
    int number,
  ) {
    final Color primaryTeal = Theme.of(context).primaryColor;
    final Color accentGreen = Theme.of(context).secondaryHeaderColor;
    final Color ovalBackground = accentGreen.withValues(alpha: 0.08);
    final ItemPrice price = ItemPrice.of(item);

    return GestureDetector(
      onTap: () => Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, false)),
      child: Container(
        width: kCardWidth,
        padding: const EdgeInsets.all(kCardPadding),
        constraints: const BoxConstraints(maxHeight: 230.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kCardBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: kImageWidth,
                  height: kImageHeight,
                  decoration: BoxDecoration(
                    color: ovalBackground,
                    borderRadius: BorderRadius.circular(kImageBorderRadius),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(kImageBorderRadius),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      fit: BoxFit.contain,
                      height: kImageHeight,
                      width: kImageWidth,
                    ),
                  ),
                ),
                if (price.onSale)
                  PositionedDirectional(
                    top: 4,
                    start: 4,
                    child:
                        OfferCollarBadge.forPrice(
                          price,
                          compact: true,
                          onPhoto: true,
                        )!,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                item.name ?? '',
                style: waddyBold.copyWith(
                  fontSize: kProductNameSize,
                  color: primaryTeal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            PriceTag(price: price, oneLine: true),
            SizedBox(
              height: Dimensions.minTapTarget,
              child: AddToCartControl(item: item, inset: 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollingBanner() {
    final Color primaryTeal = Theme.of(context).primaryColor;
    final Color bannerBg =
        HSLColor.fromColor(primaryTeal)
            .withLightness(
              (HSLColor.fromColor(primaryTeal).lightness - 0.03).clamp(
                0.0,
                1.0,
              ),
            )
            .toColor();
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(Dimensions.radiusDefault),
          bottomRight: Radius.circular(Dimensions.radiusDefault),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(Dimensions.radiusDefault),
          bottomRight: Radius.circular(Dimensions.radiusDefault),
        ),
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  left: -(_animController.value * 400),
                  child: Row(
                    children: List.generate(
                      3,
                      (index) => _buildBannerContent(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBannerContent() {
    return GetBuilder<HomeController>(
      builder: (homeController) {
        final isRamadanMode = homeController.showRamadanDecorations;
        return Row(
          children:
              isRamadanMode
                  ? [
                    _buildBannerItem('RAMADAN'),
                    _buildBannerStar(),
                    _buildBannerItem('DEALS'),
                    _buildBannerStar(),
                    _buildBannerItem('IN'),
                    _buildBannerStar(),
                    _buildBannerItem('STORE'),
                    _buildBannerStar(),
                  ]
                  : [
                    _buildBannerItem('SALE'),
                    _buildBannerStar(),
                    _buildBannerItem('EVERYTHING'),
                    _buildBannerStar(),
                    _buildBannerItem('MUST'),
                    _buildBannerStar(),
                    _buildBannerItem('GO!'),
                    _buildBannerStar(),
                  ],
        );
      },
    );
  }

  Widget _buildBannerItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeMedium,
      ),
      child: Text(
        text,
        style: waddyBold.copyWith(
          fontSize: kBannerTextSize,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildBannerStar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
      ),
      child: Icon(
        Icons.star,
        color: Theme.of(context).secondaryHeaderColor,
        size: 14,
      ),
    );
  }
}
