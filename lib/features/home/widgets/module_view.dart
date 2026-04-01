import 'package:lottie/lottie.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/features/home/widgets/views/top_restaurants_view.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/home/widgets/current_order_widget.dart';
import 'package:sixam_mart/features/home/widgets/ramadan/ramadan_celebrate_button_wrapper.dart';

class ModuleView extends StatelessWidget {
  final SplashController splashController;
  const ModuleView({super.key, required this.splashController});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Current Order (top priority — show active order first, above everything)
        if (AuthHelper.isLoggedIn()) const Padding(
          padding: EdgeInsets.only(top: 5, bottom: 5),
          child: CurrentOrderWidget(),
        ),

        const SizedBox(height: 4),

        // 1. Modules grid - custom layout with Ramadan decorations
        splashController.moduleList != null
            ? splashController.moduleList!.isNotEmpty
                ? RamadanCelebrateButtonWrapper(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildModulesLayout(context, splashController),
                  ),
                )
                : Center(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: Dimensions.paddingSizeSmall,
                    ),
                    child: Text('no_module_found'.tr),
                  ),
                )
            : ModuleShimmer(isEnabled: splashController.moduleList == null),

        const SizedBox(height: 8),

        // 2. Speed Mode — nearest best restaurants (replaces Featured Stores)
        const TopRestaurantsView(),

        const SizedBox(height: 4),

        // 3. Food Offers — discounted food items (replaces Trending Now)
        const _FoodOffersSection(),

        const SizedBox(height: 100),
      ],
    );
  }

  /// Builds module layout with:
  /// - Normal modules (Grocery, Food, Pharmacy) in horizontal row
  /// - Hidden Gem as full-width card below with shimmer animation
  Widget _buildModulesLayout(
    BuildContext context,
    SplashController splashController,
  ) {
    final modules = splashController.moduleList!;
    const double cardSize = 95.0; // Larger cards for visual hierarchy

    // Separate normal modules from Hidden Gem
    final normalModules = <dynamic>[];
    dynamic hiddenGemModule;
    int hiddenGemIndex = -1;

    for (int i = 0; i < modules.length; i++) {
      final module = modules[i];
      final isHiddenGem =
          module.moduleName?.toLowerCase().contains('hidden') == true ||
          module.moduleName?.toLowerCase().contains('gem') == true;

      if (isHiddenGem) {
        hiddenGemModule = module;
        hiddenGemIndex = i;
      } else {
        normalModules.add({'module': module, 'index': i});
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Normal modules in centered row with fixed gaps
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < normalModules.length; i++) ...[
              if (i > 0) const SizedBox(width: 24),
              _ModuleCard(
                module: normalModules[i]['module'],
                cardSize: cardSize,
                onTap:
                    () => splashController.switchModule(
                      normalModules[i]['index'],
                      true,
                    ),
              ),
            ],
          ],
        ),

        // Hidden Gem full-width card below
        if (hiddenGemModule != null)
          Padding(
            padding: const EdgeInsets.only(
              top: 20,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: _FullWidthShimmerGemCard(
              module: hiddenGemModule,
              onTap: () => splashController.switchModule(hiddenGemIndex, true),
            ),
          ),
      ],
    );
  }
}

/// Square module card with gradient overlay and text below
class _ModuleCard extends StatefulWidget {
  final dynamic module;
  final double cardSize;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.module,
    required this.cardSize,
    required this.onTap,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: SizedBox(
          width: widget.cardSize,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Square image card with gradient and shadow
              Container(
                width: widget.cardSize,
                height: widget.cardSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background image
                      CustomImage(
                        image: '${widget.module.iconFullUrl}',
                        fit: BoxFit.cover,
                        width: widget.cardSize,
                        height: widget.cardSize,
                      ),
                      // Soft gradient overlay using theme colors
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor.withValues(alpha: 0.05),
                              secondaryColor.withValues(alpha: 0.12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Text label below image
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.module.moduleName ?? '',
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Tilted offer chip below the name
              // Padding(
              //   padding: const EdgeInsets.only(top: 4),
              //   child: Transform.rotate(
              //     angle: -0.05,
              //     child: Container(
              //       padding: const EdgeInsets.symmetric(
              //         horizontal: 8,
              //         vertical: 3,
              //       ),
              //       decoration: BoxDecoration(
              //         color: primaryColor,
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //       child: Text(
              //         _getModuleSubtitle(
              //           widget.module.moduleName ?? '',
              //         ).toUpperCase(),
              //         style: robotoBold.copyWith(
              //           fontSize: 7.5,
              //           color: Colors.white,
              //           letterSpacing: 0.3,
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width Places to Visit card with featured place images
class _FullWidthShimmerGemCard extends StatefulWidget {
  final dynamic module;
  final VoidCallback onTap;

  const _FullWidthShimmerGemCard({required this.module, required this.onTap});

  @override
  State<_FullWidthShimmerGemCard> createState() =>
      _FullWidthShimmerGemCardState();
}

class _FullWidthShimmerGemCardState extends State<_FullWidthShimmerGemCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Scale animation for press effect
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // Shimmer stripe animation - slow continuous loop
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    // Fetch featured places if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeaturedPlaces();
    });
  }

  void _loadFeaturedPlaces() {
    try {
      if (!Get.isRegistered<PlacesController>()) return;

      final placesController = Get.find<PlacesController>();

      if (placesController.places == null || placesController.places!.isEmpty) {
        placesController.getPlaces(reload: true);
      }
    } catch (e) {
      debugPrint('Error loading featured places: $e');
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          width: double.infinity,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                primaryColor,
                secondaryColor.withValues(alpha: 0.85),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  // Location pin icon — compact circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    child:  Lottie.asset(
                      'assets/animation/gem.json',
                     
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Text content
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Places to Visit',
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Top spots in Maadi ✨',
                            style: robotoRegular.copyWith(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right: stacked images
                  _buildStackedImages(primaryColor, secondaryColor),
                  const SizedBox(width: 6),
                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withValues(alpha: 0.75),
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStackedImages(Color primaryColor, Color secondaryColor) {
    return GetBuilder<PlacesController>(
      builder: (placesController) {
        final places = placesController.places?.take(3).toList() ?? [];

        if (places.isEmpty) {
          // Show placeholder images when no data
          return _buildPlaceholderImages(secondaryColor);
        }

        return SizedBox(
          width: 76,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (places.length > 2)
                Positioned(
                  left: 0,
                  child: Transform.rotate(
                    angle: -0.15,
                    child: _buildPlaceImage(places[2].image, secondaryColor),
                  ),
                ),
              if (places.length > 1)
                Positioned(
                  right: 0,
                  child: Transform.rotate(
                    angle: 0.15,
                    child: _buildPlaceImage(places[1].image, secondaryColor),
                  ),
                ),
              if (places.isNotEmpty)
                Positioned(
                  child: _buildPlaceImage(
                    places[0].image,
                    secondaryColor,
                    isFront: true,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceImage(
    String? imageUrl,
    Color borderColor, {
    bool isFront = false,
  }) {
    return Container(
      width: isFront ? 38 : 32,
      height: isFront ? 38 : 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: isFront ? 0.9 : 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder:
                      (_, __) => Container(
                        color: borderColor.withValues(alpha: 0.3),
                        child: Icon(
                          Icons.place,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                  errorWidget:
                      (_, __, ___) => Container(
                        color: borderColor.withValues(alpha: 0.3),
                        child: Icon(
                          Icons.place,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                )
                : Container(
                  color: borderColor.withValues(alpha: 0.3),
                  child: Icon(Icons.place, color: Colors.white54, size: 20),
                ),
      ),
    );
  }

  Widget _buildPlaceholderImages(Color secondaryColor) {
    return SizedBox(
      width: 76,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: secondaryColor.withValues(alpha: 0.3),
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: const Icon(Icons.place, color: Colors.white38, size: 14),
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Transform.rotate(
              angle: 0.15,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: secondaryColor.withValues(alpha: 0.3),
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: const Icon(Icons.place, color: Colors.white38, size: 14),
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: secondaryColor.withValues(alpha: 0.4),
              border: Border.all(color: Colors.white70, width: 2),
            ),
            child: const Icon(Icons.place, color: Colors.white60, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for animated diagonal shimmer stripes
class _ShimmerStripesPainter extends CustomPainter {
  final double progress;
  final Color stripeColor;

  _ShimmerStripesPainter({required this.progress, required this.stripeColor});

  @override
  void paint(Canvas canvas, Size size) {
    const int stripeCount = 4;
    const double stripeWidth = 30.0;
    const double angle = 0.5; // ~30 degrees

    // Calculate total travel distance for stripes
    final double totalWidth =
        size.width + size.height * angle + stripeWidth * stripeCount * 2;
    final double startOffset = -stripeWidth * stripeCount - size.height * angle;

    for (int i = 0; i < stripeCount; i++) {
      // Calculate position of each stripe
      final double baseX = startOffset + (i * stripeWidth * 2);
      final double animatedX = baseX + (progress * totalWidth);

      // Calculate opacity - center stripes more opaque
      final double normalizedPos =
          (i - stripeCount / 2).abs() / (stripeCount / 2);
      final double opacity = 0.15 - (normalizedPos * 0.08);

      final paint =
          Paint()
            ..color = stripeColor.withValues(alpha: opacity)
            ..style = PaintingStyle.fill;

      final path = Path();

      // Draw diagonal stripe
      path.moveTo(animatedX, 0);
      path.lineTo(animatedX + stripeWidth, 0);
      path.lineTo(animatedX + stripeWidth - size.height * angle, size.height);
      path.lineTo(animatedX - size.height * angle, size.height);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ShimmerStripesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Food Offers section — shows discounted food items only (not grocery)
class _FoodOffersSection extends StatelessWidget {
  const _FoodOffersSection();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ItemController>(
      builder: (itemController) {
        final allItems = itemController.popularItemList;
        if (allItems == null || allItems.isEmpty) return const SizedBox.shrink();

        // Filter: only food module items with discounts
        final splashController = Get.find<SplashController>();
        final modules = splashController.moduleList;

        int? foodModuleId;
        if (modules != null) {
          for (var module in modules) {
            if (module.moduleType?.toLowerCase() ==
                AppConstants.food.toLowerCase()) {
              foodModuleId = module.id;
              break;
            }
          }
        }

        List<Item> offerItems;
        if (foodModuleId != null) {
          offerItems = allItems
              .where((item) =>
                  item.moduleId == foodModuleId &&
                  item.discount != null &&
                  item.discount! > 0)
              .toList();
        } else {
          // Fallback: show all items with discounts
          offerItems = allItems
              .where(
                  (item) => item.discount != null && item.discount! > 0)
              .toList();
        }

        if (offerItems.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      'food_offers'.tr,
                      style: robotoBold.copyWith(fontSize: 17),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 175,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 16),
                  itemCount: offerItems.length > 10 ? 10 : offerItems.length,
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _FoodOfferCard(item: offerItems[index]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FoodOfferCard extends StatelessWidget {
  final Item item;
  const _FoodOfferCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final accentColor = Theme.of(context).secondaryHeaderColor;
    final hasDiscount = item.discount != null && item.discount! > 0;

    return GestureDetector(
      onTap: () => Get.toNamed(
        RouteHelper.getItemDetailsRoute(item.id, false),
      ),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with offer badge
            Container(
              height: 105,
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomImage(
                      image: '${item.imageFullUrl}',
                      fit: BoxFit.cover,
                    ),
                    if (hasDiscount)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.discountType == 'percent'
                                ? '${item.discount!.toInt()}% OFF'
                                : '\$${item.discount!.toInt()} OFF',
                            style: robotoBold.copyWith(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Item name
            Text(
              item.name ?? '',
              style: robotoMedium.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Store name + price
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.storeName ?? '',
                    style: robotoRegular.copyWith(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.price != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '\$${item.price!.toStringAsFixed(0)}',
                      style: robotoBold.copyWith(
                        fontSize: 11,
                        color: primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ModuleShimmer extends StatelessWidget {
  final bool isEnabled;
  const ModuleShimmer({super.key, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: Dimensions.paddingSizeSmall,
        crossAxisSpacing: Dimensions.paddingSizeSmall,
        childAspectRatio: (1 / 1),
      ),
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      itemCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            color: Theme.of(context).cardColor,
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1),
            ],
          ),
          child: Shimmer(
            duration: const Duration(seconds: 2),
            enabled: isEnabled,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    color: Colors.grey[300],
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                Center(
                  child: Container(
                    height: 15,
                    width: 50,
                    color: Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AddressShimmer extends StatelessWidget {
  final bool isEnabled;
  const AddressShimmer({super.key, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: Dimensions.paddingSizeSmall),

        SizedBox(
          height: 70,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: 5,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeSmall,
            ),
            itemBuilder: (context, index) {
              return Container(
                width: 300,
                padding: const EdgeInsets.only(
                  right: Dimensions.paddingSizeSmall,
                ),
                child: Container(
                  padding: EdgeInsets.all(
                    ResponsiveHelper.isDesktop(context)
                        ? Dimensions.paddingSizeDefault
                        : Dimensions.paddingSizeSmall,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: ResponsiveHelper.isDesktop(context) ? 50 : 40,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Expanded(
                        child: Shimmer(
                          duration: const Duration(seconds: 2),
                          enabled: isEnabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 15,
                                width: 100,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(
                                height: Dimensions.paddingSizeExtraSmall,
                              ),
                              Container(
                                height: 10,
                                width: 150,
                                color: Colors.grey[300],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
