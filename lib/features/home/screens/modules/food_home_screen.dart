import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:sixam_mart/features/address/controllers/address_controller.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/features/category/controllers/category_controller.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/home/widgets/banner_view.dart';
import 'package:sixam_mart/features/store/domain/models/store_model.dart';
import 'package:sixam_mart/features/store/screens/food_store_screen.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/util/app_design_tokens.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/features/home/widgets/current_order_widget.dart';

class FoodHomeScreen extends StatefulWidget {
  const FoodHomeScreen({super.key});

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen>
    with TickerProviderStateMixin {
  int? _selectedCategoryId;
  bool _filterOffers = false;
  bool _filterUnder30 = false;
  bool _filterFreeDelivery = false;

  late final AnimationController _categoryAnimController;
  late final Animation<double> _categoryFadeAnim;

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

  String _selectedSort = 'default';

  void _showSortBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            Text(
              'sort_by'.tr,
              style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            _buildSortOption('default', 'recommended'.tr, Icons.star_rounded),
            _buildSortOption(
              'rating',
              'top_rated'.tr,
              Icons.star_border_rounded,
            ),
            _buildSortOption(
              'distance',
              'nearest_first'.tr,
              Icons.location_on_outlined,
            ),
            _buildSortOption('a_z', 'a_z'.tr, Icons.sort_by_alpha_rounded),
            const SizedBox(height: Dimensions.paddingSizeLarge),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildSortOption(String value, String title, IconData icon) {
    bool isSelected = _selectedSort == value;
    return InkWell(
      onTap: () {
        setState(() => _selectedSort = value);
        Get.back();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade600,
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: Text(
                title,
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color:
                      isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  List<Store> _filterStores(List<Store>? stores) {
    if (stores == null) return [];

    // Start with all stores
    Iterable<Store> filtered = stores;

    // Filter by Category
    if (_selectedCategoryId != null) {
      filtered = filtered.where((store) {
        return store.categoryIds != null &&
            store.categoryIds!.contains(_selectedCategoryId);
      });
    }

    // Filter by Offers (Discount > 0)
    if (_filterOffers) {
      filtered = filtered.where((store) {
        return store.discount != null &&
            store.discount!.discount != null &&
            store.discount!.discount! > 0;
      });
    }

    // Filter by Under 30 Mins
    if (_filterUnder30) {
      filtered = filtered.where((store) {
        if (store.deliveryTime == null || store.deliveryTime!.isEmpty) {
          return false;
        }
        // Delivery time is often formatted as "30-45" or "10-20 min"
        // We extract the maximum time to be safe.
        final parts = store.deliveryTime!.split('-');
        final maxTimeStr = parts.last.replaceAll(RegExp(r'[^0-9]'), '');
        final maxTime = int.tryParse(maxTimeStr) ?? 999;
        return maxTime <= 30;
      });
    }

    // Filter by Free Delivery
    if (_filterFreeDelivery) {
      filtered = filtered.where((store) {
        return store.freeDelivery == true ||
            (store.minimumShippingCharge != null &&
                store.minimumShippingCharge == 0);
      });
    }

    List<Store> result = filtered.toList();

    // Apply Sorting
    switch (_selectedSort) {
      case 'rating':
        result.sort((a, b) => (b.avgRating ?? 0).compareTo(a.avgRating ?? 0));
        break;
      case 'distance':
        result.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
        break;
      case 'a_z':
        result.sort(
          (a, b) => (a.name?.toLowerCase() ?? '').compareTo(
            b.name?.toLowerCase() ?? '',
          ),
        );
        break;
      case 'default':
      default:
        // Already in the default order provided by the API
        break;
    }

    return result;
  }

  bool get _hasActiveChipFilter =>
      _filterOffers ||
      _filterUnder30 ||
      _filterFreeDelivery ||
      _selectedSort != 'default';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAppBar(context),
        _buildSearchBar(context),
        const CurrentOrderWidget(),
        const SizedBox(height: 16),
        _buildOrderAgainSection(context),
        const SizedBox(height: 8),
        _buildPopularRestaurantsSection(context),
        const BannerView(isFeatured: false, showRamadanWrapper: false),
        const SizedBox(height: 20),
        _buildBrowseAllRestaurantsHeader(context),
        _buildCategoryCircles(context),
        const SizedBox(height: 6),
        _buildFilterChips(context),
        const SizedBox(height: 8),
        _buildStoreList(context),
        const SizedBox(height: 20),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // APP BAR
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
          Expanded(
            child: GestureDetector(
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
                              address?.address ?? 'select_location'.tr,
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
  // SEARCH BAR
  // ═══════════════════════════════════════════
  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        12,
        Dimensions.paddingSizeDefault,
        0,
      ),
      child: GestureDetector(
        onTap: () => Get.toNamed(RouteHelper.getSearchRoute()),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 22, color: Colors.grey.shade500),
              const SizedBox(width: 10),
              Text(
                'search_food_or_restaurant'.tr,
                style: robotoRegular.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // POPULAR RESTAURANTS (Big Brands equivalent)
  // ═══════════════════════════════════════════
  Widget _buildPopularRestaurantsSection(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    return GetBuilder<StoreController>(
      builder: (storeController) {
        final stores =
            storeController.popularStoreList ?? storeController.latestStoreList;
        if (stores == null) return _buildBigBrandsShimmer();
        if (stores.isEmpty) return const SizedBox();
        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            'popular_restaurants'.tr,
                            style: robotoBold.copyWith(
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
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
  // STICKER SYSTEM
  // ═══════════════════════════════════════════
  List<_StickerData> _getStickersForStore(Store store) {
    final stickers = <_StickerData>[];
    if (store.featured == 1) {
      stickers.add(
        const _StickerData(
          text: 'SPEEDY 🍕',
          icon: Icons.delivery_dining_rounded,
          bgColor: Color(0xFF134E4A),
          textColor: Color(0xFF1EF2A0),
          rotation: -0.08,
        ),
      );
    }
    if (store.deliveryTime != null && store.deliveryTime!.isNotEmpty) {
      final parts = store.deliveryTime!.split('-');
      final maxTime = int.tryParse(parts.last.trim()) ?? 999;
      if (maxTime <= 30) {
        stickers.add(
          const _StickerData(
            text: 'QUICK BITES 🍔',
            icon: Icons.timer_rounded,
            bgColor: Color(0xFFFFD600),
            textColor: Color(0xFF3E2700),
            rotation: 0.1,
          ),
        );
      }
    }
    if (store.freeDelivery == true) {
      stickers.add(
        const _StickerData(
          text: 'FREE DELIVERY 🛵',
          icon: Icons.delivery_dining_outlined,
          bgColor: Color(0xFFFF5252),
          textColor: Colors.white,
          rotation: -0.06,
        ),
      );
    }
    if (store.discount != null &&
        store.discount!.discount != null &&
        store.discount!.discount! > 0) {
      stickers.add(
        _StickerData(
          text: 'HOT DEALS 🌶️',
          icon: Icons.local_fire_department_rounded,
          bgColor: const Color(0xFFFF6D00),
          textColor: Colors.white,
          rotation: 0.08,
        ),
      );
    }
    if (store.avgRating != null && store.avgRating! >= 4.5) {
      stickers.add(
        const _StickerData(
          text: 'TOP RATED 🍽️',
          icon: Icons.restaurant_rounded,
          bgColor: Color(0xFF7C4DFF),
          textColor: Colors.white,
          rotation: -0.07,
        ),
      );
    }
    if ((store.ratingCount ?? 0) < 5 && stickers.length < 2) {
      stickers.add(
        const _StickerData(
          text: 'NEW TASTES 🧑‍🍳',
          icon: Icons.auto_awesome_rounded,
          bgColor: Color(0xFF00E676),
          textColor: Color(0xFF0D3B2E),
          rotation: 0.12,
        ),
      );
    }
    return stickers.take(1).toList();
  }

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
  // BEST NEARBY CARD
  // ═══════════════════════════════════════════
  Widget _buildBestNearbyCard(
    BuildContext context,
    Store store,
    Color primaryColor,
    Color accentColor,
  ) {
    final bool isOpen = store.open == 1;
    final stickers = _getStickersForStore(store);
    return GestureDetector(
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: FoodStoreScreen(store: store, fromModule: false),
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
              Positioned.fill(
                child: CustomImage(
                  image: store.coverPhotoFullUrl ?? '',
                  fit: BoxFit.cover,
                ),
              ),
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
                            'closed_now'.tr.toUpperCase(),
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
              if (stickers.isNotEmpty && isOpen)
                Positioned(
                  top: 12,
                  right: 0,
                  child: _buildRibbonSticker(stickers.first),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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
                      const SizedBox(height: 4),
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
      padding: const EdgeInsets.only(bottom: 20),
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
  // ORDER AGAIN (Buy Again equivalent)
  // ═══════════════════════════════════════════
  Widget _buildOrderAgainSection(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    return GetBuilder<HomeController>(
      builder: (homeController) {
        final bool isRamadan = homeController.isRamadanCelebrationActive;
        return GetBuilder<StoreController>(
          builder: (storeController) {
            final stores = storeController.visitAgainStoreList;
            if (stores == null || stores.isEmpty) return const SizedBox();
            if (isRamadan)
              return _buildRamadanOrderAgain(
                context,
                stores,
                primaryColor,
                accentColor,
              );
            return _buildNormalOrderAgain(
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

  Widget _buildNormalOrderAgain(
    BuildContext context,
    List<Store> stores,
    Color primaryColor,
    Color accentColor,
  ) {
    // Flatten stores into individual item entries
    final List<_OrderAgainItemData> allItems = [];
    for (final store in stores) {
      if (store.items != null) {
        for (final item in store.items!.take(3)) {
          allItems.add(_OrderAgainItemData(store: store, item: item));
        }
      }
    }
    if (allItems.isEmpty) return const SizedBox();
    final displayItems = allItems.take(10).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Section header ───
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Row(
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
                        'order_again'.tr,
                        style: robotoBold.copyWith(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ─── Compact horizontal item cards ───
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              itemCount: displayItems.length,
              itemBuilder:
                  (context, index) => _buildCompactItemCard(
                    context,
                    displayItems[index],
                    primaryColor,
                    accentColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactItemCard(
    BuildContext context,
    _OrderAgainItemData data,
    Color primaryColor,
    Color accentColor,
  ) {
    final store = data.store;
    final item = data.item;
    final bool hasDiscount =
        item.discount != null &&
        item.discount! > 0 &&
        item.discountType != null;
    final double originalPrice = item.price ?? 0;
    final String formattedPrice = PriceConverter.convertPrice(
      originalPrice,
      discount: item.discount,
      discountType: item.discountType,
    );
    final String originalFormatted = PriceConverter.convertPrice(originalPrice);

    return GestureDetector(
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: FoodStoreScreen(store: store, fromModule: false),
          ),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // ─── Square image with discount badge ───
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Discount tag
                if (hasDiscount)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3D00),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.discountType == 'percent'
                            ? '${item.discount!.toInt()}%'
                            : '-${PriceConverter.convertPrice(item.discount!)}',
                        style: robotoBold.copyWith(
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            // ─── Info column ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Item name
                  Text(
                    item.name ?? '',
                    style: robotoBold.copyWith(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Store name with logo
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CustomImage(
                            image: store.logoFullUrl ?? '',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          store.name ?? '',
                          style: robotoRegular.copyWith(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Price + add button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formattedPrice,
                              style: robotoBold.copyWith(
                                fontSize: 14,
                                color: primaryColor,
                              ),
                            ),
                            if (hasDiscount) ...[
                              const SizedBox(width: 4),
                              Text(
                                originalFormatted,
                                style: robotoRegular.copyWith(
                                  fontSize: 10,
                                  color: Colors.grey.shade400,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // RAMADAN ORDER AGAIN
  // ═══════════════════════════════════════════
  static const Color _ramadanGold = Color(0xFFD4AF37);

  Widget _buildRamadanOrderAgain(
    BuildContext context,
    List<Store> stores,
    Color primaryColor,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        fontSize: 20,
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
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              itemCount: stores.length > 6 ? 6 : stores.length,
              itemBuilder:
                  (context, index) =>
                      _buildRamadanChip(context, stores[index], primaryColor),
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
    return GestureDetector(
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: FoodStoreScreen(store: store, fromModule: false),
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
              Positioned(
                top: -6,
                right: -4,
                child: Icon(
                  Icons.nightlight_round,
                  size: 44,
                  color: _ramadanGold.withValues(alpha: 0.06),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 6,
                child: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: _ramadanGold.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
  // BROWSE ALL RESTAURANTS HEADER
  // ═══════════════════════════════════════════
  Widget _buildBrowseAllRestaurantsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        8,
        Dimensions.paddingSizeDefault,
        12,
      ),
      child: Text(
        'browse_by_cuisine'.tr,
        style: robotoBold.copyWith(fontSize: 18, color: Colors.black87),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CATEGORY CIRCLES
  // ═══════════════════════════════════════════
  Widget _buildCategoryCircles(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    return GetBuilder<CategoryController>(
      builder: (categoryController) {
        if (categoryController.categoryList == null)
          return _buildCategoryCirclesShimmer();
        if (categoryController.categoryList!.isEmpty) return const SizedBox();
        final allCategories = categoryController.categoryList!;
        final storeController = Get.find<StoreController>();
        final stores =
            storeController.popularStoreList ??
            storeController.latestStoreList ??
            [];
        return FadeTransition(
          opacity: _categoryFadeAnim,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                ),
                children: List.generate(allCategories.length + 1, (index) {
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
                  final category = allCategories[index - 1];
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
      child: GestureDetector(
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
                            Icons.restaurant_rounded,
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
                  'all_restaurants'.tr,
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
      builder:
          (context, value, child) => Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          ),
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: GestureDetector(
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

  // ═══════════════════════════════════════════
  // FILTER CHIPS
  // ═══════════════════════════════════════════
  Widget _buildFilterChips(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    final filters = [
      {
        'label': 'sort_by'.tr,
        'icon': Icons.swap_vert_rounded,
        'active': _selectedSort != 'default',
        'isSort': true,
        'onTap': _showSortBottomSheet,
      },
      {
        'label': 'offers'.tr,
        'icon': Icons.local_offer_outlined,
        'active': _filterOffers,
        'isSort': false,
        'onTap': () => setState(() => _filterOffers = !_filterOffers),
      },
      {
        'label': 'under_30_mins'.tr,
        'icon': Icons.access_time_rounded,
        'active': _filterUnder30,
        'isSort': false,
        'onTap': () => setState(() => _filterUnder30 = !_filterUnder30),
      },
      {
        'label': 'free_delivery'.tr,
        'icon': Icons.delivery_dining_outlined,
        'active': _filterFreeDelivery,
        'isSort': false,
        'onTap':
            () => setState(() => _filterFreeDelivery = !_filterFreeDelivery),
      },
    ];
    return Padding(
      padding: const EdgeInsets.only(
        left: Dimensions.paddingSizeDefault,
        bottom: 16,
      ),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: filters.length,
          itemBuilder: (context, index) {
            final filter = filters[index];
            final bool isActive = filter['active'] as bool;
            final VoidCallback onTap = filter['onTap'] as VoidCallback;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isActive ? primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? primaryColor : Colors.grey.shade300,
                      width: 1.2,
                    ),
                    boxShadow:
                        isActive
                            ? [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                            : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isActive
                              ? Icons.check_circle_rounded
                              : filter['icon'] as IconData,
                          key: ValueKey(isActive),
                          size: 16,
                          color: isActive ? accentColor : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        filter['label'] as String,
                        style: robotoMedium.copyWith(
                          fontSize: 12,
                          color: isActive ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (filter['isSort'] == true) ...[
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STORE LIST
  // ═══════════════════════════════════════════
  Widget _buildStoreList(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    return GetBuilder<StoreController>(
      builder: (storeController) {
        final allStores = storeController.storeModel?.stores;
        final filteredStores = _filterStores(allStores);
        if (allStores == null) return _buildStoreListShimmer();
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
                    Icons.restaurant_outlined,
                    size: 52,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    (_selectedCategoryId != null || _hasActiveChipFilter)
                        ? 'no_restaurants_in_category'.tr
                        : 'no_restaurant_available'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'try_different_category'.tr,
                    style: robotoRegular.copyWith(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
                filteredStores
                    .map(
                      (store) => _buildStoreCard(
                        context,
                        store,
                        primaryColor,
                        accentColor,
                      ),
                    )
                    .toList(),
          ),
        );
      },
    );
  }

  Widget _buildStoreCard(
    BuildContext context,
    Store store,
    Color primaryColor,
    Color accentColor,
  ) {
    final bool isOpen = store.open == 1;
    final bool hasDiscount =
        store.discount != null &&
        store.discount!.discount != null &&
        store.discount!.discount! > 0;
    final bool hasFreeDelivery =
        store.freeDelivery == true ||
        (store.minimumShippingCharge != null &&
            store.minimumShippingCharge == 0);

    String cuisines = '';
    if (store.categoryIds != null &&
        store.categoryIds!.isNotEmpty &&
        Get.find<CategoryController>().categoryList != null) {
      List<String> names = [];
      for (int id in store.categoryIds!) {
        for (var cat in Get.find<CategoryController>().categoryList!) {
          if (cat.id == id && cat.name != null) {
            names.add(cat.name!);
            break;
          }
        }
      }
      cuisines = names.join(', ');
    }
    if (cuisines.isEmpty) cuisines = 'Restaurant';

    return GestureDetector(
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: FoodStoreScreen(store: store, fromModule: false),
          ),
      child: Opacity(
        opacity: isOpen ? 1.0 : 0.6,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).secondaryHeaderColor.withValues(
                  alpha: 0.1,
                ), // Soft neon green top
                Theme.of(
                  context,
                ).secondaryHeaderColor.withValues(alpha: 0.4), // Fade out
                Theme.of(context).cardColor, // Blend into card
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(1.5), // creates the border thickness
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18), // Inner border
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── LEFT: Modern Floating Image with Tags ───
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 95, // Slightly larger base
                      height: 95,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          16,
                        ), // Match container
                        child: CustomImage(
                          image: store.coverPhotoFullUrl ?? '',
                          width: 95,
                          height: 95,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Chic tilted Top-Left "Featured / Near You" Tag
                    if (store.featured == 1 ||
                        (store.distance != null && store.distance! < 2))
                      Positioned(
                        top: 8,
                        left: -8, // Hangs off edge slightly
                        child: Transform.rotate(
                          angle: -0.1, // Slight tilt
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF134E4A), Color(0xFF1B6A65)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF134E4A,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              store.featured == 1
                                  ? 'featured'.tr
                                  : 'near_you'.tr,
                              style: robotoBold.copyWith(
                                fontSize: 9,
                                color: const Color(
                                  0xFF1EF2A0,
                                ), // Secondary neon
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Logo overlay beautifully intersecting bottom-right
                    Positioned(
                      bottom: -8,
                      right: -8,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: ClipOval(
                          child: CustomImage(
                            image: store.logoFullUrl ?? '',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    if (!isOpen)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'closed'.tr.toUpperCase(),
                              style: robotoBold.copyWith(
                                fontSize: 10,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // ─── RIGHT: Premium Details ───
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        store.name ?? '',
                        style: robotoBold.copyWith(
                          fontSize: 16,
                          color: Colors.black87,
                          letterSpacing: -0.2, // Tighter brand font vibe
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Subtitles (Cuisines)
                      Text(
                        cuisines,
                        style: robotoRegular.copyWith(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Modern Delivery Info Row

                      // Offers & Delivery Time Row
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.center, // Align items centrally
                        children: [
                          // Delivery Time Pill Highlight
                          if (store.deliveryTime != null &&
                              store.deliveryTime!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(
                                  alpha: 0.9,
                                ), // Dark teal background
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.delivery_dining,
                                    size: 10,
                                    color:
                                        Theme.of(context).secondaryHeaderColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    store.deliveryTime!.contains('min')
                                        ? store.deliveryTime!.replaceAll(
                                          'min',
                                          'min'.tr,
                                        )
                                        : '${store.deliveryTime!} ${'min'.tr}',
                                    style: robotoBold.copyWith(
                                      fontSize: 10.5,
                                      color:
                                          Theme.of(
                                            context,
                                          ).secondaryHeaderColor, // Neon green text
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6), // Spacing before offers
                          ],
                          // Expand offers into the remaining space
                          if (hasDiscount || hasFreeDelivery)
                            Expanded(
                              // Prevent wrap overflow by expanding remaining space horizontally
                              child: SingleChildScrollView(
                                // Allow scrolling if offers are too long
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    if (hasDiscount) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF2D1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFFD56B),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.local_offer_rounded,
                                              size: 10,
                                              color: Color(0xFFD68A00),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              store.discount!.discountType ==
                                                      'percent'
                                                  ? '${store.discount!.discount!.toInt()}% ${'off'.tr}'
                                                  : '${PriceConverter.convertPrice(store.discount!.discount!)} ${'off'.tr}',
                                              style: robotoBold.copyWith(
                                                fontSize: 10,
                                                color: const Color(0xFFD68A00),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (hasDiscount && hasFreeDelivery)
                                      const SizedBox(width: 6),
                                    if (hasFreeDelivery) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F6F0),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFA1DBC3),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.celebration_rounded,
                                              size: 10,
                                              color: Color(0xFF008955),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'free_delivery'.tr,
                                              style: robotoBold.copyWith(
                                                fontSize: 10,
                                                color: const Color(0xFF008955),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
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

  Widget _buildStoreListShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Column(
        children: List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Shimmer(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 140,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 100,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 180,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
// ORDER AGAIN ITEM DATA MODEL
// ═══════════════════════════════════════════
class _OrderAgainItemData {
  final Store store;
  final Items item;

  const _OrderAgainItemData({required this.store, required this.item});
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
