import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';

/// Magazine-style Special Offer View - Retro catalog design with bright colors

class SpecialOfferView extends StatefulWidget {
  final bool isFood;
  final bool isShop;
  const SpecialOfferView({super.key, required this.isFood, required this.isShop});

  @override
  State<SpecialOfferView> createState() => _SpecialOfferViewState();
}

class _SpecialOfferViewState extends State<SpecialOfferView> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final CarouselSliderController _carouselController = CarouselSliderController();
  int _currentPage = 0;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // DESIGN CONSTANTS - Centralized for easy maintenance & tablet/foldable adaptation
  // ═══════════════════════════════════════════════════════════════════════════
  
  // Colors (from light_theme.dart)
  static const Color primaryTeal = Color(0xFF134E4A);
  static const Color accentGreen = Color(0xFF1EF2A0);
  static const Color ovalBackground = Color(0xFFE0F2F1);
  static const Color starColor = Color(0xFF1EF2A0);
  
  // Card dimensions (adjusted to prevent overflow)
  static const double kCardWidth = 160.0;
  static const double kCardPadding = 8.0;
  static const double kCardBorderRadius = 12.0;
  
  // Image dimensions
  static const double kImageWidth = 140.0;
  static const double kImageHeight = 90.0;
  static const double kImageBorderRadius = 10.0;
  
  // Typography sizes (WCAG-compliant, supports dynamic type scaling)
  static const double kProductNameSize = 14.0;
  static const double kOriginalPriceSize = 11.0;
  static const double kDiscountPriceSize = 16.0;
  static const double kDiscountBadgeSize = 12.0;
  static const double kAddButtonTextSize = 11.0;
  static const double kBannerTextSize = 13.0;
  static const double kDecorativeTextSize = 15.0;
  
  // Carousel settings
  static const double kCarouselHeight = 240.0;
  static const double kCarouselViewportFraction = 0.46;
  static const Duration kAutoPlayInterval = Duration(seconds: 4);
  static const Duration kAutoPlayAnimationDuration = Duration(milliseconds: 800);

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
    return GetBuilder<HomeController>(builder: (homeController) {
      return GetBuilder<ItemController>(builder: (itemController) {
        List<Item>? discountedItemList = itemController.discountedItemList;

        if (discountedItemList == null) {
          return const MagazineShimmerView();
        }

        if (discountedItemList.isEmpty) {
          return const SizedBox();
        }

        // Limit to 12 items max for carousel
        final displayItems = discountedItemList.length > 12 
            ? discountedItemList.sublist(0, 12) 
            : discountedItemList;

        final isRamadanMode = homeController.showRamadanDecorations;

        final container = Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: Dimensions.paddingSizeDefault,
          ),
          decoration: BoxDecoration(
            color: primaryTeal,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentGreen, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Magazine Header with Ramadan lights wrapper
              isRamadanMode
                  ? RamadanStringLightWrapper(
                      child: _buildMagazineHeader(context),
                      showTopString: false,
                      showBottomString: true,
                      alwaysOn: true,
                    )
                  : _buildMagazineHeader(context),
              
              // Decorative text row (CRAZY BIG style)
              
              _buildDecorativeTextRow(),
              SizedBox(height: 10,),
              // Carousel Product List with proper infinite scroll
              CarouselSlider.builder(
                  carouselController: _carouselController,
                  itemCount: displayItems.length,
                  itemBuilder: (context, index, realIndex) {
                    return _buildMagazineProductCard(context, displayItems[index], index + 1);
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
              
              // Page Indicators
              _buildPageIndicators(displayItems.length),
              
              // Bottom scrolling banner
              _buildScrollingBanner(),
            ],
          ),
        );

        return container;
      });
    });
  }

  Widget _buildMagazineHeader(BuildContext context) {
    return GestureDetector(
        onTap: () => Get.toNamed(RouteHelper.getItemViewAllScreen(false, true)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Stack(
            children: [
              // Main title with retro style
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentGreen,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0D3D38), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    'Ramadan Waddy Offers'.tr.toUpperCase(),
                    style: robotoBold.copyWith(
                      fontSize: 18,
                      color: primaryTeal,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(1, 1),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Small "BY WADDI" text
              
            ],
          ),
        ),
      );
  }

  Widget _buildDecorativeTextRow() {
    return GetBuilder<HomeController>(builder: (homeController) {
      final isRamadanMode = homeController.showRamadanDecorations;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: isRamadanMode
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
               
                ],
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
    });
  }

  Widget _buildDecorativeText(String text, Color color) {
    return Stack(
      children: [
        // Shadow/outline
        Text(
          text,
          style: robotoBold.copyWith(
            fontSize: kDecorativeTextSize,
            color: const Color(0xFF0D3D38),
            letterSpacing: 1,
          ),
        ),
        // Main text
        Positioned(
          left: -1,
          top: -1,
          child: Text(
            text,
            style: robotoBold.copyWith(
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
    return const Icon(
      Icons.star,
      color: starColor,
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
              color: _currentPage == index ? accentGreen : Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMagazineProductCard(BuildContext context, Item item, int number) {
    double price = item.price ?? 0;
    double discount = item.discount ?? 0;
    double discountPrice = PriceConverter.convertWithDiscount(price, discount, item.discountType)!;
    bool hasDiscount = discount > 0;
    
    // Use PriceConverter for proper localized currency display
    String originalPriceDisplay = PriceConverter.convertPrice(price);
    String discountPriceDisplay = PriceConverter.convertPrice(discountPrice);
    
    // Build semantic label for accessibility
    String semanticLabel = item.name ?? 'Product';
    if (hasDiscount) {
      semanticLabel += ', discounted from $originalPriceDisplay to $discountPriceDisplay';
      if (item.discountType == 'percent') {
        semanticLabel += ', ${item.discount?.toInt()}% off';
      }
    } else {
      semanticLabel += ', price $originalPriceDisplay';
    }
    semanticLabel += '. Double tap to view details and add to cart.';

    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: () => Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, false)),
        child: Container(
          width: kCardWidth,
          padding: EdgeInsets.all(kCardPadding),
          constraints: const BoxConstraints(
            maxHeight: 230.0,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kCardBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Product image
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
                  // Discount badge (if applicable)
                  if (hasDiscount)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.discountType == 'percent'
                              ? '-${item.discount?.toInt()}%'
                              : '-${PriceConverter.convertPrice(item.discount ?? 0)}',
                          style: robotoBold.copyWith(
                            fontSize: kDiscountBadgeSize,
                            color: Colors.white,
                          ),
                          textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Product name (with dynamic type scaling)
              Flexible(
                child: Text(
                  item.name ?? '',
                  style: robotoBold.copyWith(
                    fontSize: kProductNameSize,
                    color: primaryTeal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3)),
                ),
              ),
              const SizedBox(height: 4),
              // Price tag - original price strikethrough + discounted price in green box (inline row)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Original price (strikethrough if discounted)
                  if (hasDiscount)
                    Text(
                      originalPriceDisplay,
                      style: robotoMedium.copyWith(
                        fontSize: kOriginalPriceSize,
                        color: Colors.grey[600],
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.grey[600],
                      ),
                      textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3)),
                    ),
                  if (hasDiscount) const SizedBox(width: 6),
                  // Discounted/Current price in primary rounded box with secondary text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryTeal,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hasDiscount ? discountPriceDisplay : originalPriceDisplay,
                      style: robotoBold.copyWith(
                        fontSize: kDiscountPriceSize,
                        color: accentGreen,
                      ),
                      textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Add button - simple green rounded button with ADD text
              Semantics(
                button: true,
                label: 'Add ${item.name ?? "item"} to cart',
                child: GestureDetector(
                  onTap: () {
                    Get.find<ItemController>().itemDirectlyAddToCart(item, context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: accentGreen,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: accentGreen.withOpacity(0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'ADD',
                        style: robotoBold.copyWith(
                          fontSize: 14,
                          color: primaryTeal,
                          letterSpacing: 1,
                        ),
                        textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollingBanner() {
    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFF0D3D38),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  left: -(_animController.value * 400),
                  child: Row(
                    children: List.generate(3, (index) => _buildBannerContent()),
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
    return GetBuilder<HomeController>(builder: (homeController) {
      final isRamadanMode = homeController.showRamadanDecorations;
      return Row(
        children: isRamadanMode
            ? [
                _buildBannerItem('RAMADAN'),
                _buildBannerStar(),
                _buildBannerItem('IS'),
                _buildBannerStar(),
                _buildBannerItem('EASIER'),
                _buildBannerStar(),
                _buildBannerItem('WITH'),
                _buildBannerStar(),
                _buildBannerItem('WADDY'),
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
    });
  }

  Widget _buildBannerItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: robotoBold.copyWith(
          fontSize: kBannerTextSize,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildBannerStar() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.star, color: starColor, size: 14),
    );
  }
}

// Magazine-style shimmer view with app theme colors
class MagazineShimmerView extends StatelessWidget {
  const MagazineShimmerView({super.key});

  static const Color primaryTeal = Color(0xFF134E4A);
  static const Color accentGreen = Color(0xFF1EF2A0);
  static const Color ovalBackground = Color(0xFFE0F2F1);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeSmall,
      ),
      decoration: BoxDecoration(
        color: primaryTeal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentGreen, width: 4),
      ),
      child: Shimmer(
        duration: const Duration(seconds: 2),
        color: accentGreen,
        colorOpacity: 0.3,
        enabled: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header shimmer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Center(
                child: Container(
                  width: 180,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentGreen.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            // Decorative text row shimmer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  return Container(
                    width: index % 2 == 0 ? 50 : 16,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accentGreen.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            // Product grid shimmer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: [
                  _buildProductRowShimmer(),
                  const SizedBox(height: 8),
                  _buildProductRowShimmer(),
                ],
              ),
            ),
            // Bottom banner shimmer
            Container(
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF0D3D38),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRowShimmer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        return Container(
          width: 110,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Image shimmer
              Container(
                width: 90,
                height: 80,
                decoration: BoxDecoration(
                  color: ovalBackground.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 6),
              // Name shimmer
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: accentGreen.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              // Price tag shimmer
              Container(
                width: 60,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: primaryTeal.withOpacity(0.3), width: 1.5),
                ),
              ),
              const SizedBox(height: 6),
              // Add button shimmer
              Container(
                width: double.infinity,
                height: 26,
                decoration: BoxDecoration(
                  color: accentGreen.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// Keep old shimmer for backwards compatibility
class ItemShimmerView extends StatelessWidget {
  const ItemShimmerView({super.key});

  @override
  Widget build(BuildContext context) {
    return const MagazineShimmerView();
  }
}