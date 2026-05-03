import 'package:flutter/rendering.dart';
import 'package:waddy_app/features/banner/controllers/banner_controller.dart';
import 'package:waddy_app/features/brands/controllers/brands_controller.dart';
import 'package:waddy_app/features/home/controllers/advertisement_controller.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/widgets/all_store_filter_widget.dart';
import 'package:waddy_app/features/home/widgets/cashback_logo_widget.dart';
import 'package:waddy_app/features/home/widgets/cashback_dialog_widget.dart';
import 'package:waddy_app/features/home/widgets/current_order_widget.dart';
import 'package:waddy_app/features/home/widgets/home_app_bar_widget.dart';
import 'package:waddy_app/features/home/widgets/home_search_widget.dart';
import 'package:waddy_app/features/home/widgets/refer_bottom_sheet_widget.dart';
import 'package:waddy_app/features/item/controllers/campaign_controller.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/notification/controllers/notification_controller.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/features/home/screens/modules/food_home_screen.dart';
import 'package:waddy_app/features/home/screens/modules/grocery_home_screen.dart';
import 'package:waddy_app/features/home/screens/modules/pharmacy_home_screen.dart';
import 'package:waddy_app/features/home/screens/modules/shop_home_screen.dart';
import 'package:waddy_app/features/parcel/controllers/parcel_controller.dart';
import 'package:waddy_app/features/places/screens/places_home_screen.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/item_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/common/widgets/paginated_list_view.dart';
import 'package:waddy_app/common/widgets/web_menu_bar.dart';
import 'package:waddy_app/features/home/screens/web_new_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:waddy_app/features/home/widgets/module_view.dart';
import 'package:waddy_app/features/parcel/screens/parcel_category_screen.dart';
import 'package:waddy_app/features/home/widgets/letter_dialog_widget.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_home_decorations_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static Future<void> loadData(bool reload, {bool fromModule = false}) async {
    Get.find<LocationController>().syncZoneData();
    Get.find<FlashSaleController>().setEmptyFlashSale(fromModule: fromModule);

    final splashController = Get.find<SplashController>();
    final moduleType = splashController.module?.moduleType.toString();
    final isPlacesModule = moduleType == AppConstants.places;

    // For Places module, only load essential data and skip unnecessary APIs
    if (isPlacesModule) {
      Get.find<LocationController>().getZone(
        AddressHelper.getUserAddressFromSharedPref()!.latitude,
        AddressHelper.getUserAddressFromSharedPref()!.longitude,
        false,
        updateInAddress: true,
      );
      return;
    }

    if (AuthHelper.isLoggedIn()) {
      Get.find<StoreController>().getVisitAgainStoreList(
        fromModule: fromModule,
      );
    }
    if (Get.find<SplashController>().module != null &&
        !Get.find<SplashController>()
            .configModel!
            .moduleConfig!
            .module!
            .isParcel!) {
      Get.find<BannerController>().getBannerList(reload);
      Get.find<StoreController>().getRecommendedStoreList();
      if (Get.find<SplashController>().module!.moduleType.toString() ==
          AppConstants.grocery) {
        Get.find<FlashSaleController>().getFlashSale(reload, false);
      }
      if (Get.find<SplashController>().module!.moduleType.toString() ==
          AppConstants.ecommerce) {
        Get.find<ItemController>().getFeaturedCategoriesItemList(false, false);
        Get.find<FlashSaleController>().getFlashSale(reload, false);
        Get.find<BrandsController>().getBrandList();
      }
      Get.find<BannerController>().getPromotionalBannerList(reload);
      Get.find<ItemController>().getDiscountedItemList(
        offset: '1',
        firstTimeCategoryLoad: true,
      );
      Get.find<ItemController>().getPopularItemList(
        offset: '1',
        firstTimeCategoryLoad: true,
      );
      Get.find<ItemController>().getReviewedItemList(
        offset: '1',
        firstTimeCategoryLoad: true,
      );
      Get.find<CategoryController>().getCategoryList(reload);
      Get.find<StoreController>().getPopularStoreList(reload, 'all', false);
      Get.find<CampaignController>().getBasicCampaignList(reload);
      Get.find<CampaignController>().getItemCampaignList(reload);
      Get.find<StoreController>().getLatestStoreList(reload, 'all', false);
      Get.find<StoreController>().getTopOfferStoreList(reload, false);
      Get.find<ItemController>().getRecommendedItemList(reload, 'all', false);
      Get.find<StoreController>().getStoreList(1, reload);
      Get.find<AdvertisementController>().getAdvertisementList();
      if (Get.find<HomeController>().showRamadanDecorations) {
        Get.find<ItemController>().getRamadanFeaturedItemList();
      }
    }
    if (AuthHelper.isLoggedIn()) {
      await Get.find<ProfileController>().getUserInfo();
      Get.find<NotificationController>().getNotificationList(reload);
      Get.find<CouponController>().getCouponList();
      Get.find<XpController>().getCurrentLevel(reload: reload);
      Get.find<XpController>().getAllLevels(reload: reload);
      Get.find<OrderController>().getRunningOrders(1);
    }
    Get.find<XpController>().getXpConfig(reload: reload);
    Get.find<SplashController>().getModules();
    if (Get.find<SplashController>().module == null &&
        Get.find<SplashController>().configModel!.module == null) {
      Get.find<BannerController>().getFeaturedBanner();
      await Get.find<StoreController>().getFeaturedStoreList();
      Get.find<StoreController>().getRecommendedStoreList();

      _fetchFeaturedStoresRecommendedItems();

      if (AuthHelper.isLoggedIn()) {
        Get.find<AddressController>().getAddressList();
      }
    }
    if (Get.find<SplashController>().module != null &&
        Get.find<SplashController>()
            .configModel!
            .moduleConfig!
            .module!
            .isParcel!) {
      Get.find<ParcelController>().getParcelCategoryList();
    }
    if (Get.find<SplashController>().module != null &&
        Get.find<SplashController>().module!.moduleType.toString() ==
            AppConstants.pharmacy) {
      Get.find<ItemController>().getBasicMedicine(reload, false);
      Get.find<StoreController>().getFeaturedStoreList();
      await Get.find<ItemController>().getCommonConditions(false);
      if (Get.find<ItemController>().commonConditions!.isNotEmpty) {
        Get.find<ItemController>().getConditionsWiseItem(
          Get.find<ItemController>().commonConditions![0].id!,
          false,
        );
      }
    }
  }

  static void _fetchFeaturedStoresRecommendedItems() {
    final storeController = Get.find<StoreController>();
    final featuredStores = storeController.featuredStoreList;

    if (featuredStores != null && featuredStores.isNotEmpty) {
      for (var store in featuredStores) {
        if (store.id != null) {
          storeController.fetchStoreRecommendedItems(store.id!);
        }
      }
    }
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool searchBgShow = false;
  final GlobalKey _headerKey = GlobalKey();
  ScrollDirection _lastDirection = ScrollDirection.idle;

  @override
  void initState() {
    super.initState();
    HomeScreen.loadData(false).then((value) {
      if (!mounted) return;
      Get.find<SplashController>().getReferBottomSheetStatus();

      final showReferral = (Get.find<ProfileController>()
                  .userInfoModel
                  ?.isValidForDiscount ??
              false) &&
          Get.find<SplashController>().showReferBottomSheet;

      if (showReferral) {
        _showReferBottomSheet();
      } else {
        _checkAndShowWelcomeLetter();
      }
    });

    if (!ResponsiveHelper.isWeb()) {
      Get.find<LocationController>().getZone(
        AddressHelper.getUserAddressFromSharedPref()!.latitude,
        AddressHelper.getUserAddressFromSharedPref()!.longitude,
        false,
        updateInAddress: true,
      );
    }

    _scrollController.addListener(() {
      final direction = _scrollController.position.userScrollDirection;
      if (direction == _lastDirection) return;
      _lastDirection = direction;

      if (direction == ScrollDirection.reverse) {
        Get.find<HomeController>().onScrollDown();
      } else {
        Get.find<HomeController>().onScrollUp();
      }
    });
  }

  Future<void> _checkAndShowWelcomeLetter() async {
    if (!AuthHelper.isLoggedIn() || !mounted) return;

    final splashController = Get.find<SplashController>();
    splashController.getWelcomeLetterShownStatus();

    if (splashController.welcomeLetterShown) return;

    // Wait a bit for the UI to settle
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      splashController.saveWelcomeLetterShownStatus(true);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const LetterDialogWidget(),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

  void _showReferBottomSheet() {
    ResponsiveHelper.isDesktop(context)
        ? Get.dialog(
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
            ),
            insetPadding: const EdgeInsets.all(22),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: const ReferBottomSheetWidget(),
          ),
          useSafeArea: false,
        ).then(
          (value) =>
              Get.find<SplashController>().saveReferBottomSheetStatus(false),
        )
        : showModalBottomSheet(
          isScrollControlled: true,
          useRootNavigator: true,
          context: Get.context!,
          backgroundColor: Theme.of(Get.context!).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(Dimensions.radiusExtraLarge),
              topRight: Radius.circular(Dimensions.radiusExtraLarge),
            ),
          ),
          builder: (context) {
            final screenH = MediaQuery.of(context).size.height;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (screenH * 0.8).clamp(420.0, screenH),
              ),
              child: const ReferBottomSheetWidget(),
            );
          },
        ).then(
          (value) =>
              Get.find<SplashController>().saveReferBottomSheetStatus(false),
        );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      builder: (splashController) {
        if (splashController.moduleList != null &&
            splashController.moduleList!.length == 1) {
          splashController.switchModule(0, true);
        }

        final moduleState = _ModuleState.from(splashController, context);

        return GetBuilder<HomeController>(
          builder: (homeController) {
            return Scaffold(
              appBar:
                  ResponsiveHelper.isDesktop(context)
                      ? const WebMenuBar()
                      : null,
              endDrawer: const MenuDrawer(),
              endDrawerEnableOpenDragGesture: false,
              backgroundColor: Theme.of(context).colorScheme.surface,
              body:
                  moduleState.isParcel
                      ? const ParcelCategoryScreen()
                      : SafeArea(
                        child: RefreshIndicator(
                          onRefresh:
                              () =>
                                  _handleRefresh(splashController, moduleState),
                          child:
                              ResponsiveHelper.isDesktop(context)
                                  ? WebNewHomeScreen(
                                    scrollController: _scrollController,
                                  )
                                  : _buildMobileHomeContent(
                                    context,
                                    splashController,
                                    moduleState,
                                  ),
                        ),
                      ),
              floatingActionButton: _buildFloatingActionButton(homeController),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileHomeContent(
    BuildContext context,
    SplashController splashController,
    _ModuleState moduleState,
  ) {
    // Wrap with Ramadan decorations for the dashboard (module view)
    final content = CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Modern App Bar with Greeting (hide for grocery, food, and places modules)
        if (!moduleState.isGrocery &&
            !moduleState.isFood &&
            !moduleState.isPlaces)
          const SliverToBoxAdapter(child: HomeAppBarWidget()),

        // Current Order Status (show at top when there's an active order)
        if (!moduleState.showMobileModule &&
            !moduleState.isGrocery &&
            !moduleState.isFood &&
            !moduleState.isPlaces)
          const SliverToBoxAdapter(child: CurrentOrderWidget()),

        // Search Bar (hide for grocery, food, and places modules)
        if (!moduleState.showMobileModule &&
            !moduleState.isGrocery &&
            !moduleState.isFood &&
            !moduleState.isPlaces)
          const SliverToBoxAdapter(child: HomeSearchWidget()),

        // Module Content
        SliverToBoxAdapter(
          child: Center(
            child: SizedBox(
              width: Dimensions.webMaxWidth,
              child:
                  !moduleState.showMobileModule
                      ? _buildModuleContent(moduleState)
                      : ModuleView(splashController: splashController),
            ),
          ),
        ),

        // Store Filter (hide for grocery, food, and places modules)
        if (!moduleState.showMobileModule &&
            !moduleState.isGrocery &&
            !moduleState.isFood &&
            !moduleState.isPlaces)
          SliverPersistentHeader(
            key: _headerKey,
            pinned: true,
            delegate: SliverDelegate(
              height:
                  100 *
                  MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3),
              callback: (val) => searchBgShow = val,
              child: const AllStoreFilterWidget(),
            ),
          ),

        // Store List (hide for grocery, food, and places modules)
        if (!moduleState.showMobileModule &&
            !moduleState.isGrocery &&
            !moduleState.isFood &&
            !moduleState.isPlaces)
          SliverToBoxAdapter(child: _buildStoreList(moduleState)),
      ],
    );

    // Only show Ramadan decorations on the main dashboard (module view)
    if (moduleState.showMobileModule) {
      return RamadanHomeDecorationsWidget(
        scrollController: _scrollController,
        child: content,
      );
    }

    return content;
  }

  Widget _buildModuleContent(_ModuleState state) {
    if (state.isGrocery) return const GroceryHomeScreen();
    if (state.isPharmacy) return const PharmacyHomeScreen();
    if (state.isFood) return const FoodHomeScreen();
    if (state.isShop) return const ShopHomeScreen();
    if (state.isPlaces) return const PlacesHomeScreen();
    return const SizedBox();
  }

  Widget _buildStoreList(_ModuleState state) {
    return Center(
      child: GetBuilder<StoreController>(
        builder: (storeController) {
          return Padding(
            padding: EdgeInsets.only(
              bottom:
                  ResponsiveHelper.isDesktop(Get.context!)
                      ? 0
                      : 80 + MediaQuery.of(Get.context!).padding.bottom,
            ),
            child: PaginatedListView(
              scrollController: _scrollController,
              totalSize: storeController.storeModel?.totalSize,
              offset: storeController.storeModel?.offset,
              onPaginate:
                  (int? offset) async =>
                      await storeController.getStoreList(offset!, false),
              itemView: ItemsView(
                isStore: true,
                items: null,
                isFoodOrGrocery: state.isFood || state.isGrocery,
                stores: storeController.storeModel?.stores,
                padding: EdgeInsets.symmetric(
                  horizontal:
                      ResponsiveHelper.isDesktop(Get.context!)
                          ? Dimensions.paddingSizeExtraSmall
                          : Dimensions.paddingSizeSmall,
                  vertical:
                      ResponsiveHelper.isDesktop(Get.context!)
                          ? Dimensions.paddingSizeExtraSmall
                          : Dimensions.paddingSizeDefault,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget? _buildFloatingActionButton(HomeController homeController) {
    if (AuthHelper.isLoggedIn() &&
        homeController.cashBackOfferList != null &&
        homeController.cashBackOfferList!.isNotEmpty &&
        homeController.showFavButton) {
      final ctx = Get.context!;
      final isRtl = Directionality.of(ctx) == TextDirection.rtl;
      final safeBottom = MediaQuery.of(ctx).viewPadding.bottom;
      return Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: safeBottom + 16,
          end: ResponsiveHelper.isDesktop(ctx) ? 50 : (isRtl ? 8 : 0),
        ),
        child: InkWell(
          onTap: () => Get.dialog(const CashBackDialogWidget()),
          child: const CashBackLogoWidget(),
        ),
      );
    }
    return null;
  }

  Future<void> _handleRefresh(
    SplashController splashController,
    _ModuleState state,
  ) async {
    splashController.setRefreshing(true);

    if (Get.find<SplashController>().module != null) {
      await _refreshModuleData(state);
    } else {
      await _refreshHomeData();
    }

    splashController.setRefreshing(false);
  }

  Future<void> _refreshModuleData(_ModuleState state) async {
    await Get.find<LocationController>().syncZoneData();
    await Get.find<BannerController>().getBannerList(true);

    if (state.isGrocery) {
      await Get.find<FlashSaleController>().getFlashSale(true, true);
    }

    await Get.find<BannerController>().getPromotionalBannerList(true);
    await Get.find<ItemController>().getDiscountedItemList(offset: '1');
    await Get.find<CategoryController>().getCategoryList(true);
    await Get.find<StoreController>().getPopularStoreList(true, 'all', false);
    await Get.find<CampaignController>().getItemCampaignList(true);
    Get.find<CampaignController>().getBasicCampaignList(true);
    await Get.find<ItemController>().getPopularItemList(offset: '1');
    await Get.find<StoreController>().getLatestStoreList(true, 'all', false);
    await Get.find<StoreController>().getTopOfferStoreList(true, false);
    await Get.find<ItemController>().getReviewedItemList(offset: '1');
    await Get.find<StoreController>().getStoreList(1, true);
    Get.find<AdvertisementController>().getAdvertisementList();

    if (AuthHelper.isLoggedIn()) {
      await Get.find<ProfileController>().getUserInfo();
      await Get.find<NotificationController>().getNotificationList(true);
      Get.find<CouponController>().getCouponList();
      Get.find<OrderController>().getRunningOrders(1, isUpdate: true);
    }

    if (state.isPharmacy) {
      Get.find<ItemController>().getBasicMedicine(true, true);
      Get.find<ItemController>().getCommonConditions(true);
    }

    if (state.isShop) {
      await Get.find<FlashSaleController>().getFlashSale(true, true);
      Get.find<ItemController>().getFeaturedCategoriesItemList(true, true);
      Get.find<BrandsController>().getBrandList();
    }
  }

  Future<void> _refreshHomeData() async {
    await Get.find<BannerController>().getFeaturedBanner();
    await Get.find<SplashController>().getModules();
    if (AuthHelper.isLoggedIn()) {
      await Get.find<AddressController>().getAddressList();
      Get.find<OrderController>().getRunningOrders(1, isUpdate: true);
    }
    await Get.find<StoreController>().getFeaturedStoreList();
  }
}

/// Helper class to manage module state
class _ModuleState {
  final bool showMobileModule;
  final bool isParcel;
  final bool isPharmacy;
  final bool isFood;
  final bool isShop;
  final bool isGrocery;
  final bool isPlaces;

  const _ModuleState({
    required this.showMobileModule,
    required this.isParcel,
    required this.isPharmacy,
    required this.isFood,
    required this.isShop,
    required this.isGrocery,
    required this.isPlaces,
  });

  factory _ModuleState.from(SplashController controller, BuildContext context) {
    final module = controller.module;
    final moduleType = module?.moduleType.toString();

    return _ModuleState(
      showMobileModule:
          !ResponsiveHelper.isDesktop(context) &&
          module == null &&
          controller.configModel!.module == null,
      isParcel: module != null && moduleType == AppConstants.parcel,
      isPharmacy: module != null && moduleType == AppConstants.pharmacy,
      isFood: module != null && moduleType == AppConstants.food,
      isShop: module != null && moduleType == AppConstants.ecommerce,
      isGrocery: module != null && moduleType == AppConstants.grocery,
      isPlaces: module != null && moduleType == AppConstants.places,
    );
  }
}

class SliverDelegate extends SliverPersistentHeaderDelegate {
  Widget child;
  double height;
  Function(bool isPinned)? callback;
  bool isPinned = false;

  SliverDelegate({required this.child, this.height = 50, this.callback});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    isPinned = shrinkOffset == maxExtent;
    callback!(isPinned);
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(SliverDelegate oldDelegate) {
    return oldDelegate.maxExtent != height ||
        oldDelegate.minExtent != height ||
        child != oldDelegate.child;
  }
}
