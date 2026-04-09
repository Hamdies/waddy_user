import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/home/widgets/components/deal_rush_painter.dart';

/// A visually stunning promotional banner with animated carousel of deal items
/// Displays discounted items with marquee light animations and rotating food images
class DealRushBannerWidget extends StatefulWidget {
  const DealRushBannerWidget({super.key});

  @override
  State<DealRushBannerWidget> createState() => _DealRushBannerWidgetState();
}

class _DealRushBannerWidgetState extends State<DealRushBannerWidget>
    with TickerProviderStateMixin {
  late AnimationController _lightAnimationController;
  late AnimationController _carouselController;
  late PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  // Design colors
  static const Color _primaryTeal = Color(0xFF134E4A);
  static const Color _neonGreen = Color(0xFF1EF2A0);
  static const Color _accentGold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _lightAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _carouselController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pageController = PageController(viewportFraction: 0.85, initialPage: 0);

    // Auto-scroll carousel every 3 seconds
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _autoScrollCarousel();
    });
  }

  void _autoScrollCarousel() {
    final itemController = Get.find<ItemController>();
    final items = itemController.discountedItemList;
    if (items != null && items.isNotEmpty && _pageController.hasClients) {
      _currentPage = (_currentPage + 1) % items.length.clamp(1, 5);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _lightAnimationController.dispose();
    _carouselController.dispose();
    _pageController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ItemController>(
      builder: (itemController) {
        List<Item>? discountedItems = itemController.discountedItemList;

        if (discountedItems == null) {
          return const DealRushShimmerView();
        }

        if (discountedItems.isEmpty) {
          return const SizedBox();
        }

        // Take up to 5 items for the carousel
        final displayItems = discountedItems.take(5).toList();

        return GestureDetector(
          onTap:
              () => Get.toNamed(RouteHelper.getItemViewAllScreen(false, true)),
          child: Container(
            margin: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              gradient:  LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryTeal, _primaryTeal.withValues(alpha: 0.8), _primaryTeal],
                stops: [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _neonGreen.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child: Stack(
                children: [
                  // Animated background with decorative elements
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _lightAnimationController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: DealRushPainter(
                            primaryColor: _primaryTeal,
                            accentColor: _neonGreen,
                            animationValue:
                                _lightAnimationController.value * 10,
                          ),
                        );
                      },
                    ),
                  ),

                  // Content layout
                  Row(
                    children: [
                      // Left side: Title and tagline
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(
                            Dimensions.paddingSizeLarge,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'special'.tr,
                                style: robotoMedium.copyWith(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: _neonGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),

                              Text(
                                'DEAL',
                                style: robotoBlack.copyWith(
                                  fontSize: 46,
                                  color: _accentGold,
                                  height: 0.95,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),

                              Text(
                                'RUSH',
                                style: robotoBlack.copyWith(
                                  fontSize: 46,
                                  color: _accentGold,
                                  height: 0.95,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Container(
                                width: 70,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: _accentGold,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),

                              const SizedBox(height: 12),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '⚡',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'LIMITED TIME',
                                      style: robotoBold.copyWith(
                                        fontSize: 10,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right side: Rotating food items
                      Expanded(
                        flex: 5,
                        child: _buildFoodCarousel(displayItems),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFoodCarousel(List<Item> items) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: items.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            return _buildFoodItem(items[index], isMainItem: true);
          },
        ),

        if (items.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: _buildPageIndicator(items.length),
          ),
      ],
    );
  }

  Widget _buildFoodItem(Item item, {bool isMainItem = false}) {
    final discount = item.discount ?? 0;
    final discountType = item.discountType ?? 'percent';
    final price = item.price ?? 0;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              border: Border.all(
                color: _neonGreen.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _neonGreen.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: CustomImage(
                        image: item.imageFullUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                if (price > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        if (discount > 0)
                          Text(
                            '${price.toStringAsFixed(0)} LE',
                            style: robotoMedium.copyWith(
                              fontSize: 13,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.grey,
                              decorationThickness: 2,
                            ),
                          ),
                        if (discount > 0) const SizedBox(height: 2),
                        Text(
                          '${_calculateDiscountedPrice(price, discount, discountType).toStringAsFixed(0)} LE',
                          style: robotoBold.copyWith(
                            fontSize: 18,
                            color: _primaryTeal,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (discount > 0)
            Positioned(
              bottom: 50,
              left: 5,
              child: _buildPriceBadge(discount, discountType),
            ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int itemCount) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _neonGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            itemCount.clamp(0, 5),
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? _neonGreen
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
                boxShadow: _currentPage == index
                    ? [
                        BoxShadow(
                          color: _neonGreen.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateDiscountedPrice(num price, num discount, String discountType) {
    if (discountType == 'percent') {
      return (price - (price * discount / 100)).toDouble();
    } else {
      return (price - discount).toDouble();
    }
  }

  Widget _buildPriceBadge(num discount, String discountType) {
    final discountText =
        discountType == 'percent'
            ? '${discount.toInt()}%'
            : '${discount.toInt()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _neonGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _neonGreen.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🔥',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            discountText,
            style: robotoBold.copyWith(
              fontSize: 14,
              color: _primaryTeal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            'OFF',
            style: robotoBold.copyWith(
              fontSize: 11,
              color: _primaryTeal,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer loading placeholder for Deal Rush banner
class DealRushShimmerView extends StatelessWidget {
  const DealRushShimmerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      duration: const Duration(seconds: 2),
      enabled: true,
      child: Container(
        margin: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        height: 220,
        decoration: BoxDecoration(
          color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        ),
        child: Row(
          children: [
            // Left shimmer content
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 100,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Right shimmer content
            Expanded(
              flex: 5,
              child: Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).shadowColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension for sin function on double
extension DoubleMathExtension on double {
  double sin() => _sin(this);

  static double _sin(double x) {
    // Simple sin approximation using dart:math would require import
    // Using Taylor series approximation for small values
    x = x % (3.14159265359 * 2);
    if (x > 3.14159265359) x -= 3.14159265359 * 2;
    double result = x;
    double term = x;
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
}
