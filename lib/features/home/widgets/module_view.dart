import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:sixam_mart/features/banner/controllers/banner_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/home/widgets/banner_view.dart';
import 'package:sixam_mart/features/home/widgets/views/top_restaurants_view.dart';
import 'package:sixam_mart/features/home/widgets/views/top_grocery_stores_view.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/home/widgets/views/top_grocery_view.dart';
import 'package:sixam_mart/features/home/widgets/xp_progress_widget.dart';
import 'package:sixam_mart/features/home/widgets/current_order_widget.dart';
import 'package:sixam_mart/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';
import 'package:sixam_mart/features/home/widgets/ramadan/ramadan_celebrate_button_wrapper.dart';
import 'package:sixam_mart/features/home/widgets/ramadan/ramadan_stall_view.dart';

class ModuleView extends StatelessWidget {
  final SplashController splashController;
  const ModuleView({super.key, required this.splashController});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Current Order (top priority — show active order first)

        // 1. Banner
        GetBuilder<BannerController>(
          builder: (bannerController) {
            return const BannerView(isFeatured: true);
          },
        ),
        if (AuthHelper.isLoggedIn()) const CurrentOrderWidget(),
        // 2. Modules grid - custom layout with Ramadan decorations
        splashController.moduleList != null
            ? splashController.moduleList!.isNotEmpty
                ? RamadanCelebrateButtonWrapper(
                  child: Padding(
                    padding: EdgeInsets.zero,
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

        // 3. XP Progress Widget (for logged-in users)
        if (AuthHelper.isLoggedIn()) const XpProgressWidget(),

        // 4. Top Restaurants (food module only)
        const TopRestaurantsView(),

        // 5. Top Grocery (grocery module only)
        TopGroceryView(),

        const SizedBox(height: 120),
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
    const double cardSize = 90.0; // Square cards

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
              if (i > 0) const SizedBox(width: 30), // Gap between cards
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

        // Hidden Gem full-width card below with breathing room
        if (hiddenGemModule != null)
          Padding(
            padding: const EdgeInsets.only(
              top: 24,
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
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
              // Text label below
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.module.moduleName ?? '',
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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

    // Shimmer stripe animation - continuous loop
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    // Fetch featured places if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeaturedPlaces();
    });
  }

  void _loadFeaturedPlaces() {
    debugPrint('🗺️ [HiddenGem] _loadFeaturedPlaces called');
    try {
      // Check if PlacesController is registered
      if (!Get.isRegistered<PlacesController>()) {
        debugPrint('🗺️ [HiddenGem] PlacesController NOT registered!');
        return;
      }

      final placesController = Get.find<PlacesController>();
      debugPrint('🗺️ [HiddenGem] PlacesController found!');
      debugPrint(
        '🗺️ [HiddenGem] Places count: ${placesController.places?.length ?? 0}',
      );

      // Load places if not loaded
      if (placesController.places == null || placesController.places!.isEmpty) {
        debugPrint('🗺️ [HiddenGem] Fetching places...');
        placesController.getPlaces(reload: true);
      } else {
        // Print available places
        for (var place in placesController.places!.take(3)) {
          debugPrint(
            '🗺️ [HiddenGem] Place: ${place.title}, Image: ${place.image}',
          );
        }
      }
    } catch (e, stack) {
      debugPrint('🗺️ [HiddenGem] Error: $e');
      debugPrint('🗺️ [HiddenGem] Stack: $stack');
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
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                primaryColor,
                primaryColor.withValues(alpha: 0.95),
                secondaryColor.withValues(alpha: 0.7),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Animated shimmer stripes overlay
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _ShimmerStripesPainter(
                        progress: _shimmerController.value,
                        stripeColor: secondaryColor,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),

                // Content row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Left side: Icon + Text
                      Expanded(
                        child: Row(
                          children: [
                            // Location pin icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              child: Icon(
                                Icons.place_rounded,
                                color: secondaryColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Text content
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Places to Visit',
                                    style: robotoMedium.copyWith(
                                      fontSize: Dimensions.fontSizeLarge,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Top spots in Maadi 🌟',
                                    style: robotoRegular.copyWith(
                                      fontSize: Dimensions.fontSizeSmall,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Right side: Stacked place images
                      _buildStackedImages(primaryColor, secondaryColor),

                      const SizedBox(width: 8),

                      // Arrow
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStackedImages(Color primaryColor, Color secondaryColor) {
    return GetBuilder<PlacesController>(
      builder: (placesController) {
        // Use places instead of leaderboard
        final places = placesController.places?.take(3).toList() ?? [];

        debugPrint(
          '🖼️ [HiddenGem] Building images, places count: ${places.length}',
        );
        for (var p in places) {
          debugPrint(
            '🖼️ [HiddenGem] Place: ${p.title}, Image URL: ${p.image}',
          );
        }

        if (places.isEmpty) {
          // Show placeholder images when no data
          return _buildPlaceholderImages(secondaryColor);
        }

        return SizedBox(
          width: 90,
          height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Third image (back) - rotated left
              if (places.length > 2)
                Positioned(
                  left: 0,
                  child: Transform.rotate(
                    angle: -0.15,
                    child: _buildPlaceImage(places[2].image, secondaryColor),
                  ),
                ),
              // Second image (middle) - rotated right
              if (places.length > 1)
                Positioned(
                  right: 0,
                  child: Transform.rotate(
                    angle: 0.15,
                    child: _buildPlaceImage(places[1].image, secondaryColor),
                  ),
                ),
              // First image (front) - center, no rotation
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
      width: isFront ? 48 : 42,
      height: isFront ? 48 : 42,
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
      width: 90,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back left
          Positioned(
            left: 0,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: secondaryColor.withValues(alpha: 0.3),
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: Icon(Icons.place, color: Colors.white38, size: 18),
              ),
            ),
          ),
          // Back right
          Positioned(
            right: 0,
            child: Transform.rotate(
              angle: 0.15,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: secondaryColor.withValues(alpha: 0.3),
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: Icon(Icons.place, color: Colors.white38, size: 18),
              ),
            ),
          ),
          // Front center
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: secondaryColor.withValues(alpha: 0.4),
              border: Border.all(color: Colors.white70, width: 2),
            ),
            child: Icon(Icons.place, color: Colors.white60, size: 22),
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
