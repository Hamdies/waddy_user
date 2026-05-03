import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

const Color _kDark     = WaddyColors.primary;       // #134E4A deep teal
const Color _kAccent   = WaddyColors.primaryLight;  // #1D706A teal 400
const Color _kDarkText = WaddyColors.ink;           // #1A1F1E
const Color _kSubText  = WaddyColors.inkLight;      // #6B7876
const Color _kStar     = WaddyColors.mint;          // electric mint

class TopRestaurantsView extends StatelessWidget {
  const TopRestaurantsView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreController>(
      builder: (storeController) {
        List<Store>? allStores = storeController.featuredStoreList;
        List<Store>? restaurantList;

        if (allStores != null) {
          final splashController = Get.find<SplashController>();
          final modules = splashController.moduleList;

          int? foodModuleId;
          if (modules != null) {
            for (var module in modules) {
              if (module.moduleType?.toLowerCase() == AppConstants.food.toLowerCase()) {
                foodModuleId = module.id;
                break;
              }
            }
          }

          if (foodModuleId != null) {
            restaurantList = allStores.where((store) => store.moduleId == foodModuleId).toList();
          } else {
            restaurantList = allStores;
          }
        }

        if (restaurantList != null && restaurantList.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DailyDealsBanner(),
              const SizedBox(height: 8),
              restaurantList != null
                  ? SizedBox(
                      height: 218,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: restaurantList.length > 8 ? 8 : restaurantList.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return _StaggeredCardEntrance(
                            index: index,
                            child: _RestaurantCard(store: restaurantList![index]),
                          );
                        },
                      ),
                    )
                  : const _CardsShimmer(),
            ],
          ),
        );
      },
    );
  }
}

class _DailyDealsBanner extends StatelessWidget {
  const _DailyDealsBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'fastest_in_maadii'.tr,
                  style: robotoBold.copyWith(
                    fontSize: 18,
                    color: _kDark,
                    height: 1.0,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'top_restaurants_subtitle'.tr,
                  style: robotoRegular.copyWith(
                    fontSize: 11,
                    color: _kAccent,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Compact pill badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
           
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
               Lottie.asset(
                  'assets/animation/flash-sale.json',
                  width: 48,
                  height: 48,
                ),
              
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatefulWidget {
  final Store store;
  const _RestaurantCard({required this.store});

  @override
  State<_RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<_RestaurantCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _isFavorited = false;

  // Heart burst controller
  late final AnimationController _heartCtrl;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.6), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final storeController = Get.find<StoreController>();
      final id = widget.store.id;
      if (id == null) return;
      final existing = storeController.storeRecommendedItems[id];
      if (existing == null || existing.isEmpty) {
        storeController.fetchStoreRecommendedItems(id);
      }
    });
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    HapticFeedback.lightImpact();
    setState(() => _isFavorited = !_isFavorited);
    _heartCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;

    return GetBuilder<StoreController>(
      builder: (storeController) {
        List<Item> items = storeController.storeRecommendedItems[store.id] ?? [];

        final String imageUrl = items.isNotEmpty
            ? (items.first.imageFullUrl ?? '')
            : (store.coverPhotoFullUrl ?? '');

        final discountInfo = _getDiscountInfo(store);

        // Show if free delivery OR there's a W+ benefit to surface
        final bool showBenefit = store.freeDelivery == true ||
            (discountInfo != null) ||
            (store.minimumShippingCharge != null && (store.minimumShippingCharge ?? 0) > 0);

        final String benefitLabel = discountInfo != null
            ? discountInfo.label
            : store.freeDelivery == true
                ? 'free_delivery'.tr
                : PriceConverter.convertPrice(store.minimumShippingCharge);

        final String logoUrl = store.logoFullUrl ?? '';

        return GestureDetector(
          onTap: () => _navigateToStore(),
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.955 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
            width: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _kDark.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cover image ──────────────────────────────────────────
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: SizedBox(
                    height: 118,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomImage(
                          image: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        // Bottom gradient for legibility
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          height: 48,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.38),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (discountInfo != null)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _kDark,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                discountInfo.label,
                                style: robotoBold.copyWith(
                                  fontSize: 10,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Semantics(
                            button: true,
                            label: 'favourite'.tr,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _toggleFavorite,
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      shape: BoxShape.circle,
                                      boxShadow: const [
                                        BoxShadow(
                                          color: WaddyColors.shadowTeal,
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: AnimatedBuilder(
                                      animation: _heartScale,
                                      builder: (_, __) => Transform.scale(
                                        scale: _heartScale.value,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 250),
                                          transitionBuilder: (child, anim) =>
                                              ScaleTransition(scale: anim, child: child),
                                          child: Icon(
                                            _isFavorited
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            key: ValueKey(_isFavorited),
                                            size: 16,
                                            color: _isFavorited ? WaddyColors.coral : _kDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Announcement — bottom overlay
                        if (store.announcementActive == true &&
                            store.announcementMessage != null &&
                            store.announcementMessage!.isNotEmpty)
                          Positioned(
                            bottom: 5,
                            left: 8,
                            right: 8,
                            child: Text(
                              store.announcementMessage!,
                              style: robotoBold.copyWith(
                                fontSize: 10,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Info area ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo + store name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade100,
                              border: Border.all(
                                color: WaddyColors.primarySurface,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: CustomImage(
                                image: logoUrl,
                                fit: BoxFit.cover,
                                width: 34,
                                height: 34,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              store.name ?? '',
                              style: robotoBold.copyWith(
                                fontSize: 12,
                                color: _kDarkText,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // ── Rating · delivery time ───────────────────────
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: _kStar, size: 13),
                          const SizedBox(width: 2),
                          Text(
                            (store.avgRating ?? 0).toStringAsFixed(1),
                            style: robotoBold.copyWith(fontSize: 11, color: _kDarkText),
                          ),
                          if (store.ratingCount != null && store.ratingCount! > 0) ...[
                            Text(
                              ' (${store.ratingCount})',
                              style: robotoRegular.copyWith(fontSize: 10, color: _kSubText),
                            ),
                          ],
                          if (store.deliveryTime != null) ...[
                            Text(
                              ' · ',
                              style: robotoRegular.copyWith(fontSize: 10, color: _kSubText),
                            ),
                            Flexible(
                              child: Text(
                                '${store.deliveryTime}',
                                style: robotoRegular.copyWith(fontSize: 10, color: _kSubText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // ── W+ benefit row ────────────────────────────────
                      if (showBenefit) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: _kDark,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'W',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                benefitLabel,
                                style: robotoRegular.copyWith(
                                  fontSize: 10,
                                  color: _kSubText,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ), // AnimatedScale
        );
      },
    );
  }

  _DiscountBadgeInfo? _getDiscountInfo(Store store) {
    final discount = store.discount;
    if (discount == null || (discount.discount ?? 0) <= 0) return null;

    if (discount.discountType == 'percent') {
      final pct = discount.discount!.toInt();
      return _DiscountBadgeInfo(
        label: '$pct% ${'off'.tr.toLowerCase()}',
      );
    } else {
      return _DiscountBadgeInfo(
        label: '${PriceConverter.convertPrice(discount.discount)} ${'off'.tr.toLowerCase()}',
      );
    }
  }

  void _navigateToStore() {
    final store = widget.store;
    final splashController = Get.find<SplashController>();
    if (splashController.moduleList != null) {
      for (ModuleModel module in splashController.moduleList!) {
        if (module.id == store.moduleId) {
          splashController.setModule(module);
          break;
        }
      }
    }
    Get.toNamed(
      RouteHelper.getStoreRoute(id: store.id, page: 'module'),
      arguments: StoreScreen(store: store, fromModule: true),
    );
  }
}

class _DiscountBadgeInfo {
  final String label;
  const _DiscountBadgeInfo({required this.label});
}

// ── Staggered entrance: fade + slide-up per card index ───────────────────────
class _StaggeredCardEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredCardEntrance({required this.index, required this.child});

  @override
  State<_StaggeredCardEntrance> createState() => _StaggeredCardEntranceState();
}

class _StaggeredCardEntranceState extends State<_StaggeredCardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    // Stagger: 60ms per card, max 300ms delay
    final delay = Duration(milliseconds: (widget.index * 60).clamp(0, 300));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

class _CardsShimmer extends StatelessWidget {
  const _CardsShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 218,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _kDark.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image shimmer
                Shimmer(
                  duration: const Duration(seconds: 2),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Container(
                      height: 118,
                      color: WaddyColors.primarySurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo + name shimmer
                      Row(
                        children: [
                          Shimmer(
                            duration: const Duration(seconds: 2),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: WaddyColors.primarySurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Shimmer(
                                  duration: const Duration(seconds: 2),
                                  child: Container(
                                    height: 11,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: WaddyColors.primarySurface.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Shimmer(
                                  duration: const Duration(seconds: 2),
                                  child: Container(
                                    height: 11,
                                    width: 60,
                                    decoration: BoxDecoration(
                                      color: WaddyColors.primarySurface.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Shimmer(
                        duration: const Duration(seconds: 2),
                        child: Container(
                          height: 10,
                          width: 110,
                          decoration: BoxDecoration(
                            color: WaddyColors.primarySurface.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Shimmer(
                        duration: const Duration(seconds: 2),
                        child: Container(
                          height: 10,
                          width: 80,
                          decoration: BoxDecoration(
                            color: WaddyColors.primarySurface.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
