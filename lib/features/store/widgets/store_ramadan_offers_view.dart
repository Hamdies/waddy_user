import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';

/// Store-specific Ramadan Offers — carousel style with scrolling banner.
/// Accepts [items] (discounted) + [storeName] directly.
/// Visually distinct from StoreRamadanStallView (which is horizontal cards).
class StoreRamadanOffersView extends StatefulWidget {
  final List<Item> items;
  final String storeName;
  const StoreRamadanOffersView({super.key, required this.items, required this.storeName});

  @override
  State<StoreRamadanOffersView> createState() => _StoreRamadanOffersViewState();
}

class _StoreRamadanOffersViewState extends State<StoreRamadanOffersView>
    with SingleTickerProviderStateMixin {
  late AnimationController _bannerController;
  final CarouselSliderController _carouselController = CarouselSliderController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final displayItems =
        widget.items.length > 12 ? widget.items.sublist(0, 12) : widget.items;
    final Color primary = Theme.of(context).primaryColor;
    final Color accent = Theme.of(context).secondaryHeaderColor;
    final Color primaryDark = HSLColor.fromColor(primary)
        .withLightness(
            (HSLColor.fromColor(primary).lightness - 0.04).clamp(0.0, 1.0))
        .toColor();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 20, 12, 0),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Header ───
          _buildHeader(primary, primaryDark, accent),

          // ─── Decorative divider ───
          _buildDecorativeDivider(accent),

          const SizedBox(height: 8),

          // ─── Carousel ───
          CarouselSlider.builder(
            carouselController: _carouselController,
            itemCount: displayItems.length,
            itemBuilder: (context, index, realIndex) {
              return _buildOfferCard(context, displayItems[index], primary, accent);
            },
            options: CarouselOptions(
              height: 280,
              viewportFraction: 0.48,
              enlargeCenterPage: true,
              enlargeFactor: 0.15,
              enableInfiniteScroll: displayItems.length > 2,
              autoPlay: displayItems.length > 1,
              autoPlayInterval: const Duration(seconds: 4),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.easeInOutCubic,
              pauseAutoPlayOnTouch: true,
              onPageChanged: (index, reason) {
                if (mounted) setState(() => _currentPage = index);
              },
            ),
          ),

          // ─── Page indicators ───
          _buildPageIndicators(displayItems.length, accent),

          // ─── Scrolling banner ───
          _buildScrollingBanner(primaryDark, accent),
        ],
      ),
    );
  }

  Widget _buildHeader(Color primary, Color primaryDark, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Store name badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primaryDark, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  offset: const Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_offer_rounded, size: 16, color: primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Ramadan Offers',
                    style: robotoBold.copyWith(
                      fontSize: 16,
                      color: primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Store name subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.nightlight_round, color: accent, size: 14),
              const SizedBox(width: 6),
              Text(
                widget.storeName,
                style: robotoMedium.copyWith(fontSize: 12, color: accent),
              ),
              const SizedBox(width: 6),
              Icon(Icons.star, color: accent, size: 12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeDivider(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: accent.withValues(alpha: 0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.mosque_rounded, size: 14, color: accent.withValues(alpha: 0.5)),
          ),
          Expanded(child: Container(height: 1, color: accent.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _buildOfferCard(BuildContext context, Item item, Color primary, Color accent) {
    double price = item.price ?? 0;
    double discount = item.discount ?? 0;
    double discountPrice =
        PriceConverter.convertWithDiscount(price, discount, item.discountType)!;
    bool hasDiscount = discount > 0;

    return GestureDetector(
      onTap: () => Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, false)),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: const Offset(0, 3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  height: 95,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      fit: BoxFit.contain,
                      height: 95,
                      width: double.infinity,
                    ),
                  ),
                ),
                // Discount badge
                if (hasDiscount)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE84D4F),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.discountType == 'percent'
                            ? '-${item.discount?.toInt()}%'
                            : '-${PriceConverter.convertPrice(item.discount ?? 0)}',
                        style: robotoBold.copyWith(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Name
            Text(
              item.name ?? '',
              style: robotoBold.copyWith(fontSize: 14, color: primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Price row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasDiscount)
                  Text(
                    PriceConverter.convertPrice(price),
                    style: robotoMedium.copyWith(
                      fontSize: 10,
                      color: Colors.grey[500],
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.grey[500],
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                if (hasDiscount) const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasDiscount
                        ? PriceConverter.convertPrice(discountPrice)
                        : PriceConverter.convertPrice(price),
                    style: robotoBold.copyWith(fontSize: 14, color: accent),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Add button
            GestureDetector(
              onTap: () => Get.find<ItemController>().itemDirectlyAddToCart(item, context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'ADD',
                    style: robotoBold.copyWith(
                      fontSize: 13,
                      color: primary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicators(int count, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _currentPage == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? accent
                  : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildScrollingBanner(Color bgColor, Color accent) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(13),
          bottomRight: Radius.circular(13),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(13),
          bottomRight: Radius.circular(13),
        ),
        child: AnimatedBuilder(
          animation: _bannerController,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  left: -(_bannerController.value * 500),
                  child: Row(
                    children: List.generate(4, (_) => _buildBannerRow(accent)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBannerRow(Color accent) {
    return Row(
      children: [
        _buildBannerText('RAMADAN'),
        _buildBannerStar(accent),
        _buildBannerText('OFFERS'),
        _buildBannerStar(accent),
        _buildBannerText(widget.storeName.toUpperCase()),
        _buildBannerStar(accent),
      ],
    );
  }

  Widget _buildBannerText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: robotoBold.copyWith(fontSize: 12, color: Colors.white, letterSpacing: 1),
      ),
    );
  }

  Widget _buildBannerStar(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.star, color: accent, size: 12),
    );
  }
}
