import 'dart:async';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/home/widgets/views/top_restaurants_view.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/home/widgets/current_order_widget.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_celebrate_button_wrapper.dart';
import 'package:waddy_app/theme/light_theme.dart';

class ModuleView extends StatelessWidget {
  final SplashController splashController;
  const ModuleView({super.key, required this.splashController});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Current Order — elevated hero when active, tight spacing otherwise
        if (AuthHelper.isLoggedIn()) const CurrentOrderWidget(),
SizedBox(height: AuthHelper.isLoggedIn() ? Dimensions.paddingSizeLarge : 0),
        // 1. Modules grid — primary action, generous top breathing room
        splashController.moduleList != null
            ? splashController.moduleList!.isNotEmpty
                ? RamadanCelebrateButtonWrapper(
                  child: _buildModulesLayout(context, splashController),
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

        // Section divider — generous gap before secondary content
        const SizedBox(height: Dimensions.paddingSizeExtremeLarge),

        // 2. Quick Delivery — secondary section, clearly subordinate
        const TopRestaurantsView(),

        const SizedBox(height: Dimensions.paddingSizeLarge),

        // 3. Food Offers — tertiary content
        const _FoodOffersSection(),

        const SizedBox(height: 80),
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
    const double cardSize = 105.0; // Dominant primary action — hero size

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
              if (i > 0) const SizedBox(width: 20),
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
        if (hiddenGemModule != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _FullWidthShimmerGemCard(
              module: hiddenGemModule,
              onTap: () => splashController.switchModule(hiddenGemIndex, true),
            ),
          ),
        ],
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
      end: 0.96,
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

    return Semantics(
      button: true,
      label: widget.module.moduleName ?? '',
      child: GestureDetector(
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
              // Text label below image — medium weight, clear hierarchy
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  widget.module.moduleName ?? '',
                  style: robotoMedium.copyWith(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    letterSpacing: 0.1,
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
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  Timer? _rotationTimer;
  int _frontIndex = 0;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeaturedPlaces();
    });

    _rotationTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) setState(() => _frontIndex = (_frontIndex + 1) % 3);
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
    _rotationTimer?.cancel();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'places_to_visit'.tr,
      child: GestureDetector(
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
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: WaddyColors.mintSurface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: WaddyColors.shadowTeal,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'places_to_visit'.tr,
                        style: robotoBold.copyWith(
                          fontSize: 14,
                          color: WaddyColors.primary,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: WaddyColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'top_spots'.tr.toUpperCase(),
                          style: robotoBold.copyWith(
                            fontSize: 9,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStackedImages(),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: WaddyColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStackedImages() {
    return GetBuilder<PlacesController>(
      builder: (placesController) {
        final allPlaces = placesController.places?.take(3).toList() ?? [];

        if (allPlaces.isEmpty) {
          return _buildPlaceholderImages();
        }

        final count = allPlaces.length;
        final frontIdx = _frontIndex % count;
        final rightIdx = (frontIdx + 1) % count;
        final leftIdx = count > 2 ? (frontIdx + 2) % count : -1;

        const animDuration = Duration(milliseconds: 600);
        const animCurve = Curves.easeInOut;

        // Render in z-order: left → right → front (front last = on top)
        final List<int> zOrder = [
          if (leftIdx >= 0) leftIdx,
          rightIdx,
          frontIdx,
        ];

        return SizedBox(
          width: 76,
          height: 52,
          child: Stack(
            children: zOrder.map((i) {
              final isFront = i == frontIdx;
              final double size = isFront ? 38.0 : 32.0;
              final double left = i == frontIdx
                  ? (76 - 38) / 2.0 // 19 — centered
                  : i == rightIdx
                      ? 76.0 - 32.0 // 44 — right
                      : 0.0; // 0 — left
              final double top = (52 - size) / 2;

              return AnimatedPositioned(
                key: ValueKey(i),
                duration: animDuration,
                curve: animCurve,
                left: left,
                top: top,
                width: size,
                height: size,
                child: AnimatedContainer(
                  duration: animDuration,
                  curve: animCurve,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: isFront
                        ? const [
                            BoxShadow(
                              color: WaddyColors.shadowTeal,
                              offset: Offset(0, 2),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildPlaceImageContent(allPlaces[i].image),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildPlaceImageContent(String? imageUrl) {
    return imageUrl != null && imageUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: WaddyColors.amberSurface,
              child: const Icon(
                Icons.place,
                color: WaddyColors.inkLight,
                size: 16,
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: WaddyColors.amberSurface,
              child: const Icon(
                Icons.place,
                color: WaddyColors.inkLight,
                size: 16,
              ),
            ),
          )
        : Container(
            color: WaddyColors.amberSurface,
            child: const Icon(
              Icons.place,
              color: WaddyColors.inkLight,
              size: 16,
            ),
          );
  }

  Widget _buildPlaceholderImages() {
    return SizedBox(
      width: 76,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                border: Border.all(color: WaddyColors.primarySurface, width: 1.5),
              ),
              child: const Icon(Icons.place, color: WaddyColors.inkLight, size: 14),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                border: Border.all(color: WaddyColors.primarySurface, width: 1.5),
              ),
              child: const Icon(Icons.place, color: WaddyColors.inkLight, size: 14),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: WaddyColors.shadowTeal,
                  offset: Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(Icons.place, color: WaddyColors.inkMid, size: 18),
          ),
        ],
      ),
    );
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
          padding: const EdgeInsets.only(top: Dimensions.paddingSizeDefault),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: WaddyColors.coral,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'food_offers'.tr,
                      style: robotoBold.copyWith(
                        fontSize: 16,
                        color: WaddyColors.ink,
                      ),
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
    final hasDiscount = item.discount != null && item.discount! > 0;

    return Semantics(
      button: true,
      label: item.name ?? '',
      child: GestureDetector(
        onTap: () => Get.toNamed(
          RouteHelper.getItemDetailsRoute(item.id, false),
        ),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 105,
                width: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: WaddyColors.surfaceRaised,
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
                              color: WaddyColors.coral,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.discountType == 'percent'
                                  ? '${item.discount!.toInt()}% ${'off'.tr.toUpperCase()}'
                                  : '${PriceConverter.convertPrice(item.discount)} ${'off'.tr.toUpperCase()}',
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
              Text(
                item.name ?? '',
                style: robotoMedium.copyWith(
                  fontSize: 13,
                  color: WaddyColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.storeName ?? '',
                      style: robotoRegular.copyWith(
                        fontSize: 11,
                        color: WaddyColors.inkLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.price != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: WaddyColors.mintSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        PriceConverter.convertPrice(item.price),
                        style: robotoBold.copyWith(
                          fontSize: 11,
                          color: WaddyColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
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
