import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/widgets/banner_view.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_design_tokens.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/home/widgets/current_order_widget.dart';

class GroceryHomeScreen extends StatefulWidget {
  const GroceryHomeScreen({super.key});

  @override
  State<GroceryHomeScreen> createState() => _GroceryHomeScreenState();
}

class _GroceryHomeScreenState extends State<GroceryHomeScreen>
    with TickerProviderStateMixin {
  static const double _sectionGapXS = 8;
  static const double _sectionGapS = 12;
  static const double _sectionGapM = 16;
  static const double _sectionGapL = 24;

  int? _selectedCategoryId;
  bool _filterOffers = false;
  bool _filterUnder30 = false;
  bool _filterFreeDelivery = false;

  late final AnimationController _categoryAnimController;
  late final Animation<double> _categoryFadeAnim;
  late final AnimationController _freshBadgeController;
  late final Animation<double> _freshBadgeAnim;

  // Store slideshow for "All Stores" category
  int _storeSlideIndex = 0;
  Timer? _storeSlideTimer;

  void _startStoreSlideshow() {
    _storeSlideTimer?.cancel();
    _storeSlideTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _storeSlideIndex++);
    });
  }

  @override
  void dispose() {
    _categoryAnimController.dispose();
    _freshBadgeController.dispose();
    _storeSlideTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _categoryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _categoryFadeAnim = CurvedAnimation(
      parent: _categoryAnimController,
      curve: Curves.easeOutCubic,
    );
    _freshBadgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _freshBadgeAnim = CurvedAnimation(
      parent: _freshBadgeController,
      curve: Curves.easeInOut,
    );
    _categoryAnimController.forward();
    _startStoreSlideshow();
    _loadData();
  }

  void _loadData() {
    Get.find<CategoryController>().getCategoryList(false);
    if (Get.find<AddressController>().addressList == null) {
      Get.find<AddressController>().getAddressList();
    }
  }

  void _onCategoryTap(int? categoryId) {
    setState(() {
      _selectedCategoryId =
          (_selectedCategoryId == categoryId) ? null : categoryId;
    });
  }

  List<Store> _filterStores(List<Store>? stores) {
    if (stores == null) return [];
    List<Store> result = stores;

    // Category filter
    if (_selectedCategoryId != null) {
      result =
          result.where((store) {
            return store.categoryIds != null &&
                store.categoryIds!.contains(_selectedCategoryId);
          }).toList();
    }

    // Offers filter
    if (_filterOffers) {
      result =
          result.where((store) {
            return store.discount != null &&
                store.discount!.discount != null &&
                store.discount!.discount! > 0;
          }).toList();
    }

    // Under 30 min filter
    if (_filterUnder30) {
      result =
          result.where((store) {
            if (store.deliveryTime == null || store.deliveryTime!.isEmpty) {
              return false;
            }
            final parts = store.deliveryTime!.split('-');
            final maxTime = int.tryParse(parts.last.trim()) ?? 999;
            return maxTime <= 30;
          }).toList();
    }

    // Free delivery filter
    if (_filterFreeDelivery) {
      result =
          result.where((store) {
            return store.freeDelivery == true;
          }).toList();
    }

    return result;
  }

  bool get _hasActiveChipFilter =>
      _filterOffers || _filterUnder30 || _filterFreeDelivery;

  bool get _hasAnyBrowseFilters =>
      _selectedCategoryId != null || _hasActiveChipFilter;

  void _clearAllBrowseFilters() {
    _selectedCategoryId = null;
    _filterOffers = false;
    _filterUnder30 = false;
    _filterFreeDelivery = false;
  }

  void _showBrowseRefineSheet(BuildContext context) {
    final categoryController = Get.find<CategoryController>();
    final categories = categoryController.categoryList ?? [];
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              void syncSheet(void Function() update) {
                setState(update);
                setSheetState(() {});
              }

              Widget buildCategoryTile({
                required String label,
                String? imageUrl,
                required bool isSelected,
                required VoidCallback onTap,
              }) {
                return _PressableScale(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 92,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isSelected
                                ? primaryColor.withValues(alpha: 0.22)
                                : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? accentColor.withValues(alpha: 0.15)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child:
                                imageUrl != null && imageUrl.isNotEmpty
                                    ? CustomImage(
                                      image: imageUrl,
                                      fit: BoxFit.cover,
                                    )
                                    : Icon(
                                      Icons.storefront_rounded,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : Colors.grey.shade500,
                                    ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: robotoMedium.copyWith(
                            fontSize: 11,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              Widget buildFilterTile({
                required String label,
                required bool isActive,
                required VoidCallback onTap,
                required IconData icon,
              }) {
                return _PressableScale(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? primaryColor : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isActive ? primaryColor : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.check_circle_rounded : icon,
                          size: 16,
                          color: isActive ? accentColor : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: robotoMedium.copyWith(
                            fontSize: 12,
                            color: isActive ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'apply_filters'.tr,
                            style: robotoBold.copyWith(
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed:
                              _hasAnyBrowseFilters
                                  ? () {
                                    syncSheet(_clearAllBrowseFilters);
                                  }
                                  : null,
                          child: Text('reset'.tr),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'browse_all_stores'.tr,
                      style: robotoMedium.copyWith(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        buildCategoryTile(
                          label: 'all_stores'.tr,
                          isSelected: _selectedCategoryId == null,
                          onTap:
                              () => syncSheet(() {
                                _selectedCategoryId = null;
                              }),
                        ),
                        ...categories.map(
                          (category) => buildCategoryTile(
                            label: category.name ?? '',
                            imageUrl: category.imageFullUrl,
                            isSelected: _selectedCategoryId == category.id,
                            onTap:
                                () => syncSheet(() {
                                  _selectedCategoryId = category.id;
                                }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'filter'.tr,
                      style: robotoMedium.copyWith(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        buildFilterTile(
                          label: 'offers'.tr,
                          isActive: _filterOffers,
                          onTap:
                              () => syncSheet(
                                () => _filterOffers = !_filterOffers,
                              ),
                          icon: Icons.local_offer_outlined,
                        ),
                        buildFilterTile(
                          label: 'under_30_mins'.tr,
                          isActive: _filterUnder30,
                          onTap:
                              () => syncSheet(
                                () => _filterUnder30 = !_filterUnder30,
                              ),
                          icon: Icons.access_time_rounded,
                        ),
                        buildFilterTile(
                          label: 'free_delivery'.tr,
                          isActive: _filterFreeDelivery,
                          onTap:
                              () => syncSheet(
                                () =>
                                    _filterFreeDelivery = !_filterFreeDelivery,
                              ),
                          icon: Icons.delivery_dining_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Get.back(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text('done'.tr),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── App Bar ──
        _buildAppBar(context),

        // ── Search Bar ──
        _buildSearchBar(context),

        // ── Current Order Status ──
        const CurrentOrderWidget(),
        const SizedBox(height: _sectionGapM),

        // Re-Order (Buy Again) — first if exists
        _buildBuyAgainSection(context),

        // "Big brands near you" — hero horizontal store cards
        _buildBigBrandsSection(context),

        // Browse area is grouped as one visual band to reduce section noise.
        _buildBrowseSection(context),

        const SizedBox(height: _sectionGapL),

        // Banner — single, optional, now treated as a secondary promo.
        const BannerView(isFeatured: false, showRamadanWrapper: false),

        const SizedBox(height: _sectionGapL),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // APP BAR — Talabat style (← Deliver to address)
  // ═══════════════════════════════════════════
  Widget _buildAppBar(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Get.find<SplashController>().setModule(null);
                Get.find<StoreController>().resetStoreData();
              },
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // "Deliver to" + address
          Expanded(
            child: _PressableScale(
              onTap:
                  () => Get.toNamed(RouteHelper.getAccessLocationRoute('home')),
              child: Row(
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'deliver_to'.tr,
                              style: robotoRegular.copyWith(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ),
                        Builder(
                          builder: (context) {
                            final address =
                                AddressHelper.getUserAddressFromSharedPref();
                            return Text(
                              address?.address ?? 'Select Location',
                              style: robotoMedium.copyWith(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cart button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Get.toNamed(RouteHelper.getCartRoute()),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedShoppingBag02,
                        size: 21,
                        color: primaryColor,
                      ),
                    ),
                    GetBuilder<CartController>(
                      builder: (cartController) {
                        return cartController.cartList.isNotEmpty
                            ? Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                height: 18,
                                width: 18,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    cartController.cartList.length.toString(),
                                    style: robotoBold.copyWith(
                                      fontSize: 9,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            : const SizedBox();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // SEARCH BAR — Talabat style (simple, full width)
  // ═══════════════════════════════════════════
  Widget _buildSearchBar(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        12,
        Dimensions.paddingSizeDefault,
        0,
      ),
      child: _PressableScale(
        onTap: () => Get.toNamed(RouteHelper.getSearchRoute()),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search, size: 20, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'search_products_or_stores'.tr,
                  style: robotoRegular.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              ScaleTransition(
                scale: _freshBadgeAnim,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.eco_rounded, size: 18, color: accentColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // MAADI BEST NEARBY — modern cards with top items
  // ═══════════════════════════════════════════
  Widget _buildBigBrandsSection(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<StoreController>(
      builder: (storeController) {
        final stores =
            storeController.popularStoreList ?? storeController.latestStoreList;

        if (stores == null) {
          return _buildBigBrandsShimmer();
        }
        if (stores.isEmpty) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.only(bottom: _sectionGapL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title + View All
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IntrinsicWidth(
                      child: Stack(
                        children: [
                          Positioned(
                            bottom: 2,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Text(
                            'best_store_nearby'.tr,
                            style: robotoBold.copyWith(
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _PressableScale(
                      onTap:
                          () => Get.toNamed(
                            RouteHelper.getAllStoreRoute(
                              'popular',
                              isNearbyStore: true,
                            ),
                          ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.secondaryNeon.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'view_all'.tr,
                              style: robotoMedium.copyWith(
                                fontSize: 12,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Horizontal store cards
              SizedBox(
                height: 155,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: stores.length > 8 ? 8 : stores.length,
                  padding: const EdgeInsets.only(
                    left: Dimensions.paddingSizeDefault,
                  ),
                  itemBuilder: (context, index) {
                    return _buildBestNearbyCard(
                      context,
                      stores[index],
                      primaryColor,
                      accentColor,
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

  // ═══════════════════════════════════════════
  // STICKER SYSTEM — ribbon flags that poke out
  // ═══════════════════════════════════════════
  List<_StickerData> _getStickersForStore(Store store) {
    final stickers = <_StickerData>[];

    if (store.featured == 1) {
      stickers.add(
        const _StickerData(
          text: 'FAST',
          icon: Icons.electric_bolt,
          bgColor: Color(0xFF134E4A),
          textColor: Color(0xFF1EF2A0),
          rotation: -0.05,
        ),
      );
    }

    if (store.deliveryTime != null && store.deliveryTime!.isNotEmpty) {
      final parts = store.deliveryTime!.split('-');
      final maxTime = int.tryParse(parts.last.trim()) ?? 999;
      if (maxTime <= 30) {
        stickers.add(
          const _StickerData(
            text: '30 MIN',
            icon: Icons.schedule_rounded,
            bgColor: Color(0xFFFFD600),
            textColor: Color(0xFF3E2700),
            rotation: 0.06,
          ),
        );
      }
    }

    if (store.freeDelivery == true) {
      stickers.add(
        const _StickerData(
          text: 'FREE',
          icon: Icons.local_shipping_rounded,
          bgColor: Color(0xFFFF5252),
          textColor: Colors.white,
          rotation: -0.04,
        ),
      );
    }

    if (store.discount != null &&
        store.discount!.discount != null &&
        store.discount!.discount! > 0) {
      stickers.add(
        const _StickerData(
          text: 'DEAL',
          icon: Icons.local_offer_rounded,
          bgColor: Color(0xFFFF6D00),
          textColor: Colors.white,
          rotation: 0.05,
        ),
      );
    }

    if (store.avgRating != null && store.avgRating! >= 4.5) {
      stickers.add(
        const _StickerData(
          text: 'TOP',
          icon: Icons.workspace_premium_rounded,
          bgColor: Color(0xFF7C4DFF),
          textColor: Colors.white,
          rotation: -0.05,
        ),
      );
    }

    if ((store.ratingCount ?? 0) < 5 && stickers.length < 2) {
      stickers.add(
        const _StickerData(
          text: 'NEW',
          icon: Icons.auto_awesome_rounded,
          bgColor: Color(0xFF00E676),
          textColor: Color(0xFF0D3B2E),
          rotation: 0.07,
        ),
      );
    }

    return stickers.take(1).toList();
  }

  // ── Ribbon sticker widget — flag shape, rotated ──
  Widget _buildRibbonSticker(_StickerData sticker, {bool compact = false}) {
    return Transform.rotate(
      angle: sticker.rotation,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: sticker.bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
            topRight: Radius.circular(3),
            bottomRight: Radius.circular(3),
          ),
          boxShadow: [
            BoxShadow(
              color: sticker.bgColor.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sticker.icon != null) ...[
              Icon(
                sticker.icon,
                size: compact ? 10 : 12,
                color: sticker.textColor,
              ),
              SizedBox(width: compact ? 3 : 4),
            ],
            Text(
              sticker.text,
              style: robotoBold.copyWith(
                fontSize: compact ? 8 : 9.5,
                color: sticker.textColor,
                letterSpacing: 0.6,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // BEST NEARBY CARD — full-bleed magazine style
  // ═══════════════════════════════════════════
  Widget _buildBestNearbyCard(
    BuildContext context,
    Store store,
    Color primaryColor,
    Color accentColor,
  ) {
    final bool isOpen = store.open == 1;
    final stickers = _getStickersForStore(store);

    return _PressableScale(
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: StoreScreen(store: store, fromModule: false),
          ),
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── Full-bleed cover image ──
              Positioned.fill(
                child: CustomImage(
                  image: store.coverPhotoFullUrl ?? '',
                  fit: BoxFit.cover,
                ),
              ),

              // ── Bold gradient overlay — bottom heavy ──
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

              // ── Closed overlay ──
              if (!isOpen)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Text(
                            'CLOSED',
                            style: robotoBold.copyWith(
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

              // ── Logo floating top-left ──
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(10),
                    child: CustomImage(
                      image: store.logoFullUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              // ── Single sticker ribbon — right edge ──
              if (stickers.isNotEmpty && isOpen)
                Positioned(
                  top: 12,
                  right: 0,
                  child: _buildRibbonSticker(stickers.first),
                ),

              // ── Bottom info overlay ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store name — big bold white
                      Text(
                        store.name ?? '',
                        style: robotoBold.copyWith(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Delivery time pill
                      if (store.deliveryTime != null)
                        _buildInfoPill(
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

  // ── Small info pill for cards ──
  Widget _buildInfoPill({
    required IconData icon,
    required String text,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 3),
          Text(
            text,
            style: robotoBold.copyWith(fontSize: 10, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBigBrandsShimmer() {
    return Padding(
      padding: const EdgeInsets.only(bottom: _sectionGapL),
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
                  borderRadius: BorderRadius.circular(6),
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
              padding: const EdgeInsets.only(
                left: Dimensions.paddingSizeDefault,
              ),
              itemBuilder:
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Shimmer(
                      child: Container(
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
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

  // ═══════════════════════════════════════════
  // BUY AGAIN — Normal + Ramadan themed
  // ═══════════════════════════════════════════
  Widget _buildBuyAgainSection(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<HomeController>(
      builder: (homeController) {
        final bool isRamadan = homeController.isRamadanCelebrationActive;

        return GetBuilder<StoreController>(
          builder: (storeController) {
            final stores = storeController.visitAgainStoreList;
            if (stores == null || stores.isEmpty) return const SizedBox();

            if (isRamadan) {
              return _buildRamadanBuyAgain(
                context,
                stores,
                primaryColor,
                accentColor,
              );
            }
            return _buildNormalBuyAgain(
              context,
              stores,
              primaryColor,
              accentColor,
            );
          },
        );
      },
    );
  }

  // ── Normal (non-Ramadan) Buy Again ──
  Widget _buildNormalBuyAgain(
    BuildContext context,
    List<Store> stores,
    Color primaryColor,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _sectionGapM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Text(
              'buy_again'.tr,
              style: robotoBold.copyWith(fontSize: 18, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Text(
              'a_quick_way_to_find_your_go_to_items'.tr,
              style: robotoRegular.copyWith(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              itemCount: stores.length > 5 ? 5 : stores.length,
              itemBuilder: (context, index) {
                return _buildBuyAgainCard(
                  context,
                  stores[index],
                  primaryColor,
                  accentColor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyAgainCard(
    BuildContext context,
    Store store,
    Color primaryColor,
    Color accentColor,
  ) {
    final items = store.items ?? [];
    final int totalItems = store.itemCount ?? items.length;
    final displayItems = items.take(4).toList();
    final int remaining = totalItems - displayItems.length;

    return _PressableScale(
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: StoreScreen(store: store, fromModule: false),
          ),
      child: Container(
        width: 168,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CustomImage(
                        image: store.logoFullUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name ?? '',
                          style: robotoBold.copyWith(
                            fontSize: 12.5,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (store.deliveryTime != null)
                          Text(
                            '${store.deliveryTime}',
                            style: robotoRegular.copyWith(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child:
                    displayItems.isNotEmpty
                        ? GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 5,
                                crossAxisSpacing: 5,
                              ),
                          itemCount:
                              displayItems.length > 4 ? 4 : displayItems.length,
                          itemBuilder: (context, index) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(7),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: CustomImage(
                                  image: displayItems[index].imageFullUrl ?? '',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        )
                        : Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
              ),
            ),
            if (remaining > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+$remaining ${'more'.tr}',
                    style: robotoMedium.copyWith(
                      fontSize: 10.5,
                      color: primaryColor,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // RAMADAN-THEMED BUY AGAIN — compact & stylish
  // ═══════════════════════════════════════════
  static const Color _ramadanGold = Color(0xFFD4AF37);

  Widget _buildRamadanBuyAgain(
    BuildContext context,
    List<Store> stores,
    Color primaryColor,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _sectionGapM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ramadan header with marker highlight ──
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Row(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedRamadhan01,
                  color: _ramadanGold,
                  size: 22,
                ),
                const SizedBox(width: 8),
                // Title with gold marker underline
                Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: -3,
                      right: -3,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: _ramadanGold.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      'ramadan_reorder'.tr,
                      style: robotoBold.copyWith(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Text(
              'ramadan_reorder_subtitle'.tr,
              style: robotoRegular.copyWith(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Horizontal store cards — Ramadan style ──
          SizedBox(
            height: 162,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              itemCount: stores.length > 6 ? 6 : stores.length,
              itemBuilder: (context, index) {
                return _buildRamadanChip(context, stores[index], primaryColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRamadanChip(
    BuildContext context,
    Store store,
    Color primaryColor,
  ) {
    final items = store.items ?? [];
    final displayItems = items.take(3).toList();

    return _PressableScale(
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: StoreScreen(store: store, fromModule: false),
          ),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _ramadanGold.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: _ramadanGold.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Gradient background
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFFDF5), Color(0xFFFFF8E7)],
                    ),
                  ),
                ),
              ),

              // Decorative top-right crescent
              Positioned(
                top: -6,
                right: -4,
                child: Icon(
                  Icons.nightlight_round,
                  size: 44,
                  color: _ramadanGold.withValues(alpha: 0.06),
                ),
              ),
              // Decorative bottom-left star cluster
              Positioned(
                bottom: 12,
                left: 6,
                child: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: _ramadanGold.withValues(alpha: 0.08),
                ),
              ),

              // Card content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store logo + name
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                            border: Border.all(
                              color: _ramadanGold.withValues(alpha: 0.25),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _ramadanGold.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CustomImage(
                              image: store.logoFullUrl ?? '',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.name ?? '',
                                style: robotoBold.copyWith(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (store.deliveryTime != null)
                                Text(
                                  '${store.deliveryTime}',
                                  style: robotoRegular.copyWith(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Item thumbnails — elevated white cards
                    Row(
                      children: [
                        ...displayItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                  BoxShadow(
                                    color: _ramadanGold.withValues(alpha: 0.06),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(5),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: CustomImage(
                                  image: item.imageFullUrl ?? '',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (items.length > 3)
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _ramadanGold.withValues(alpha: 0.15),
                                  _ramadanGold.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+${items.length - 3}',
                              style: robotoBold.copyWith(
                                fontSize: 11,
                                color: const Color(0xFF8B6914),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const Spacer(),

                    // Re-order CTA button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _ramadanGold.withValues(alpha: 0.18),
                            _ramadanGold.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _ramadanGold.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.refresh_rounded,
                            size: 13,
                            color: Color(0xFF8B6914),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ramadan_reorder'.tr,
                            style: robotoMedium.copyWith(
                              fontSize: 11,
                              color: const Color(0xFF8B6914),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // "Browse all stores" HEADING
  // ═══════════════════════════════════════════
  Widget _buildBrowseAllStoresHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        0,
        Dimensions.paddingSizeDefault,
        10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'browse_all_stores'.tr,
              style: robotoBold.copyWith(fontSize: 18, color: Colors.black87),
            ),
          ),
          if (_hasAnyBrowseFilters)
            TextButton(
              onPressed: () => setState(_clearAllBrowseFilters),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
              child: Text('reset'.tr),
            ),
        ],
      ),
    );
  }

  Widget _buildBrowseSection(BuildContext context) {
    final Color sectionTint = Theme.of(
      context,
    ).primaryColor.withValues(alpha: 0.025);
    final Color borderTint = Theme.of(
      context,
    ).secondaryHeaderColor.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: sectionTint,
        border: Border(
          top: BorderSide(color: borderTint),
          bottom: BorderSide(color: borderTint),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrowseAllStoresHeader(context),
          _buildCategoryCircles(context),
          const SizedBox(height: _sectionGapXS),
          _buildRefineButton(context),
          const SizedBox(height: _sectionGapS),
          _buildStoreList(context),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CATEGORY CARDS — rounded square with animated All Stores
  // ═══════════════════════════════════════════
  Widget _buildCategoryCircles(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<CategoryController>(
      builder: (categoryController) {
        if (categoryController.categoryList == null) {
          return _buildCategoryCirclesShimmer();
        }
        if (categoryController.categoryList!.isEmpty) {
          return const SizedBox();
        }

        final allCategories = categoryController.categoryList!;
        final visibleCategories =
            allCategories.length > 3
                ? allCategories.take(3).toList()
                : allCategories;

        // Get store covers for "All Stores" slideshow
        final storeController = Get.find<StoreController>();
        final stores =
            storeController.popularStoreList ??
            storeController.latestStoreList ??
            [];

        return FadeTransition(
          opacity: _categoryFadeAnim,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                ),
                children: List.generate(visibleCategories.length + 1, (index) {
                  if (index == 0) {
                    return _buildAllStoresItem(
                      context: context,
                      isSelected: _selectedCategoryId == null,
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                      stores: stores,
                      onTap: () => _onCategoryTap(null),
                    );
                  }
                  final category = visibleCategories[index - 1];
                  return _buildCategoryItem(
                    context: context,
                    isSelected: _selectedCategoryId == category.id,
                    label: category.name ?? '',
                    imageUrl: category.imageFullUrl,
                    primaryColor: primaryColor,
                    accentColor: accentColor,
                    onTap: () => _onCategoryTap(category.id),
                    index: index,
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── "All Stores" with animated store image slideshow ──
  Widget _buildAllStoresItem({
    required BuildContext context,
    required bool isSelected,
    required Color primaryColor,
    required Color accentColor,
    required List<Store> stores,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: _PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 82,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSelected ? primaryColor : Colors.grey.shade100,
                  border: Border.all(
                    color:
                        isSelected
                            ? accentColor.withValues(alpha: 0.5)
                            : Colors.grey.shade200,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child:
                      stores.isNotEmpty
                          ? AnimatedSwitcher(
                            duration: const Duration(milliseconds: 600),
                            child: CustomImage(
                              key: ValueKey<int>(
                                _storeSlideIndex % stores.length,
                              ),
                              image:
                                  stores[_storeSlideIndex % stores.length]
                                      .logoFullUrl ??
                                  '',
                              fit: BoxFit.cover,
                              width: 66,
                              height: 66,
                            ),
                          )
                          : Icon(
                            Icons.storefront_rounded,
                            size: 26,
                            color:
                                isSelected
                                    ? Colors.white
                                    : Colors.grey.shade500,
                          ),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: robotoMedium.copyWith(
                  fontSize: isSelected ? 11 : 10.5,
                  color: isSelected ? primaryColor : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(
                  'all_stores'.tr,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(top: 4),
                width: isSelected ? 20 : 0,
                height: isSelected ? 3 : 0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Category item — rounded square card ──
  Widget _buildCategoryItem({
    required BuildContext context,
    required bool isSelected,
    required String label,
    required String? imageUrl,
    required Color primaryColor,
    required Color accentColor,
    required VoidCallback onTap,
    required int index,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: _PressableScale(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 82,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rounded square image — full bleed
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color:
                        isSelected
                            ? accentColor.withValues(alpha: 0.1)
                            : Colors.grey.shade50,
                    border: Border.all(
                      color:
                          isSelected
                              ? accentColor.withValues(alpha: 0.5)
                              : Colors.grey.shade200,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                            : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CustomImage(
                      image: imageUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Label
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: robotoMedium.copyWith(
                    fontSize: isSelected ? 11 : 10.5,
                    color: isSelected ? primaryColor : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Selection underline bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(top: 4),
                  width: isSelected ? 20 : 0,
                  height: isSelected ? 3 : 0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCirclesShimmer() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 110,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
          itemBuilder:
              (context, index) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    Shimmer(
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.grey.shade200,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Shimmer(
                      child: Container(
                        width: 50,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildRefineButton(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    final int activeFilterCount =
        (_selectedCategoryId != null ? 1 : 0) +
        (_filterOffers ? 1 : 0) +
        (_filterUnder30 ? 1 : 0) +
        (_filterFreeDelivery ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: _PressableScale(
        onTap: () => _showBrowseRefineSheet(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.tune_rounded, size: 18, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'filter'.tr,
                      style: robotoMedium.copyWith(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeFilterCount > 0
                          ? 'apply_filters'.tr
                          : 'try_different_filters'.tr,
                      style: robotoRegular.copyWith(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (activeFilterCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    activeFilterCount.toString(),
                    style: robotoBold.copyWith(
                      fontSize: 11,
                      color: primaryColor,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STORE LIST — Talabat style vertical cards
  // ═══════════════════════════════════════════
  Widget _buildStoreList(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<StoreController>(
      builder: (storeController) {
        final allStores = storeController.storeModel?.stores;
        final filteredStores = _filterStores(allStores);

        if (allStores == null) {
          return _buildStoreListShimmer();
        }

        if (filteredStores.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeExtraLarge,
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 52,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    (_selectedCategoryId != null || _hasActiveChipFilter)
                        ? 'no_stores_in_category'.tr
                        : 'no_store_available'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (_selectedCategoryId != null || _hasActiveChipFilter)
                        ? 'try_different_filters'.tr
                        : 'try_different_category'.tr,
                    style: robotoRegular.copyWith(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_hasAnyBrowseFilters) ...[
                    const SizedBox(height: 14),
                    _PressableScale(
                      onTap: () => setState(_clearAllBrowseFilters),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'reset'.tr,
                          style: robotoMedium.copyWith(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          child: Column(
            children:
                filteredStores.map((store) {
                  return _buildStoreCard(
                    context,
                    store,
                    primaryColor,
                    accentColor,
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // STORE CARD — Full-bleed cover + tilted items + sticker
  // ═══════════════════════════════════════════
  Widget _buildStoreCard(
    BuildContext context,
    Store store,
    Color primaryColor,
    Color accentColor,
  ) {
    final bool isOpen = store.open == 1;
    final stickers = _getStickersForStore(store);

    // Trigger fetch of recommended items for this store
    final storeController = Get.find<StoreController>();
    if (!storeController.storeRecommendedItems.containsKey(store.id)) {
      storeController.fetchStoreRecommendedItems(store.id!);
    }

    return _PressableScale(
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: StoreScreen(store: store, fromModule: false),
          ),
      child: Opacity(
        opacity: isOpen ? 1.0 : 0.55,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // ── Full-bleed cover ──
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: CustomImage(
                    image: store.coverPhotoFullUrl ?? '',
                    fit: BoxFit.cover,
                  ),
                ),

                // ── Gradient overlay — bottom heavy ──
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
                        stops: const [0.0, 0.2, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── Closed overlay ──
                if (!isOpen)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Text(
                              'CLOSED',
                              style: robotoBold.copyWith(
                                fontSize: 14,
                                color: Colors.black87,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Logo floating top-left ──
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(10),
                      child: CustomImage(
                        image: store.logoFullUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                // ── Single sticker ribbon — right edge ──
                if (stickers.isNotEmpty && isOpen)
                  Positioned(
                    top: 12,
                    right: 0,
                    child: _buildRibbonSticker(stickers.first),
                  ),

                // ── Tilted top items — bottom right ──
                if (isOpen)
                  Positioned(
                    bottom: 38,
                    right: 14,
                    child: GetBuilder<StoreController>(
                      builder: (sc) {
                        final items = sc.storeRecommendedItems[store.id];
                        if (items == null || items.isEmpty) {
                          return const SizedBox();
                        }
                        final topItems = items.take(3).toList();
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(topItems.length, (i) {
                            final angles = [-0.15, 0.1, -0.08];
                            final offsets = [6.0, 0.0, 4.0];
                            return Transform.translate(
                              offset: Offset(0, offsets[i % 3]),
                              child: Transform.rotate(
                                angle: angles[i % 3],
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CustomImage(
                                      image: topItems[i].imageFullUrl ?? '',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),

                // ── Bottom info overlay ──
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.name ?? '',
                                style: robotoBold.copyWith(
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              if (store.deliveryTime != null)
                                _buildInfoPill(
                                  icon: Icons.schedule_rounded,
                                  text: '${store.deliveryTime}',
                                  bgColor: accentColor,
                                  textColor: primaryColor,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreListShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Column(
        children: List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Shimmer(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// STICKER DATA MODEL
// ═══════════════════════════════════════════
class _StickerData {
  final String text;
  final IconData? icon;
  final Color bgColor;
  final Color textColor;
  final double rotation;

  const _StickerData({
    required this.text,
    this.icon,
    required this.bgColor,
    required this.textColor,
    this.rotation = 0.0,
  });
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap();
      },
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
