import 'package:flutter/rendering.dart';
import 'package:sixam_mart/features/banner/controllers/banner_controller.dart';
import 'package:sixam_mart/features/brands/controllers/brands_controller.dart';
import 'package:sixam_mart/features/home/controllers/advertisement_controller.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/home/widgets/all_store_filter_widget.dart';
import 'package:sixam_mart/features/home/widgets/cashback_logo_widget.dart';
import 'package:sixam_mart/features/home/widgets/cashback_dialog_widget.dart';
import 'package:sixam_mart/features/home/widgets/current_order_widget.dart';
import 'package:sixam_mart/features/home/widgets/home_app_bar_widget.dart';
import 'package:sixam_mart/features/home/widgets/home_search_widget.dart';
import 'package:sixam_mart/features/home/widgets/refer_bottom_sheet_widget.dart';
import 'package:sixam_mart/features/item/controllers/campaign_controller.dart';
import 'package:sixam_mart/features/category/controllers/category_controller.dart';
import 'package:sixam_mart/features/coupon/controllers/coupon_controller.dart';
import 'package:sixam_mart/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/address/controllers/address_controller.dart';
import 'package:sixam_mart/features/home/screens/modules/food_home_screen.dart';
import 'package:sixam_mart/features/home/screens/modules/grocery_home_screen.dart';
import 'package:sixam_mart/features/home/screens/modules/pharmacy_home_screen.dart';
import 'package:sixam_mart/features/home/screens/modules/shop_home_screen.dart';
import 'package:sixam_mart/features/parcel/controllers/parcel_controller.dart';
import 'package:sixam_mart/features/rental_module/home/controllers/taxi_home_controller.dart';
import 'package:sixam_mart/features/rental_module/home/screens/taxi_home_screen.dart';
import 'package:sixam_mart/features/places/screens/places_home_screen.dart';
import 'package:sixam_mart/features/rental_module/rental_cart_screen/controllers/taxi_cart_controller.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/common/widgets/item_view.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/common/widgets/paginated_list_view.dart';
import 'package:sixam_mart/common/widgets/web_menu_bar.dart';
import 'package:sixam_mart/features/home/screens/web_new_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sixam_mart/features/home/widgets/module_view.dart';
import 'package:sixam_mart/features/parcel/screens/parcel_category_screen.dart';
import 'package:sixam_mart/features/home/widgets/letter_dialog_widget.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/features/home/widgets/ramadan/ramadan_home_decorations_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static Future<void> loadData(bool reload, {bool fromModule = false}) async {
    Get.find<LocationController>().syncZoneData();
    Get.find<FlashSaleController>().setEmptyFlashSale(fromModule: fromModule);
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
            .isParcel! &&
        !Get.find<SplashController>()
            .configModel!
            .moduleConfig!
            .module!
            .isTaxi!) {
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
    Get.find<SplashController>().getModules();
    if (Get.find<SplashController>().module == null &&
        Get.find<SplashController>().configModel!.module == null) {
      Get.find<BannerController>().getFeaturedBanner();
      await Get.find<StoreController>().getFeaturedStoreList();
      Get.find<StoreController>().getRecommendedStoreList();
      Get.find<ItemController>().getPopularItemList(
        offset: '1',
        firstTimeCategoryLoad: true,
      );

      // Fetch recommended items for all featured stores
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

  @override
  void initState() {
    super.initState();
    HomeScreen.loadData(false).then((value) {
      Get.find<SplashController>().getReferBottomSheetStatus();

      if ((Get.find<ProfileController>().userInfoModel?.isValidForDiscount ??
              false) &&
          Get.find<SplashController>().showReferBottomSheet) {
        _showReferBottomSheet();
      }

      // Show welcome letter dialog only once
      _checkAndShowWelcomeLetter();
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
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        // Scrolling down - hide bottom nav
        Get.find<HomeController>().onScrollDown();
        if (Get.find<HomeController>().showFavButton) {
          Get.find<HomeController>().changeFavVisibility();
          Future.delayed(
            const Duration(milliseconds: 800),
            () => Get.find<HomeController>().changeFavVisibility(),
          );
        }
      } else {
        // Scrolling up - show bottom nav
        Get.find<HomeController>().onScrollUp();
        if (Get.find<HomeController>().showFavButton) {
          Get.find<HomeController>().changeFavVisibility();
          Future.delayed(
            const Duration(milliseconds: 800),
            () => Get.find<HomeController>().changeFavVisibility(),
          );
        }
      }
    });
  }

  Future<void> _checkAndShowWelcomeLetter() async {
    // Only show the welcome letter dialog if the user is logged in and has 0 XP
    // This ensures only true "founding members" (users who haven't earned any XP yet) see it
    if (!AuthHelper.isLoggedIn() || !mounted) return;

    final xpController = Get.find<XpController>();

    // Wait for XP data to finish loading (with timeout)
    int waitAttempts = 0;
    const maxAttempts = 20; // 20 * 200ms = 4 seconds max wait

    while (xpController.currentLevel == null &&
        waitAttempts < maxAttempts &&
        mounted) {
      await Future.delayed(const Duration(milliseconds: 200));
      waitAttempts++;
    }

    // If data still not loaded after waiting, don't show dialog
    // (better to not show than to show incorrectly)
    if (xpController.currentLevel == null || !mounted) {
      return;
    }

    // Check if user has exactly 0 XP (founding member who hasn't engaged yet)
    final currentXp = xpController.currentLevel!.currentXp;

    // Debug log to verify XP value
    print('_checkAndShowWelcomeLetter: currentXp = $currentXp');

    // Only show the dialog if user has EXACTLY 0 XP
    if (currentXp == 0 && mounted) {
      // Wait a bit for the UI to settle
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const LetterDialogWidget(),
        );
        // Note: No longer marking as "seen" - dialog will show again
        // on app open as long as user has 0 XP (until they engage)
      }
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
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(Dimensions.radiusExtraLarge),
              topRight: Radius.circular(Dimensions.radiusExtraLarge),
            ),
          ),
          builder: (context) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: const ReferBottomSheetWidget(),
            );
          },
        ).then(
          (value) =>
              Get.find<SplashController>().saveReferBottomSheetStatus(false),
        );
  }

  Future<void> loadTaxiApis() async {
    await Get.find<TaxiHomeController>().getTaxiBannerList(true);
    await Get.find<TaxiHomeController>().getTopRatedCarList(1, true);
    if (AuthHelper.isLoggedIn()) {
      await Get.find<AddressController>().getAddressList();
      await Get.find<TaxiHomeController>().getTaxiCouponList(true);
      await Get.find<TaxiCartController>().getCarCartList();
    }
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
                      : Container(
                        decoration: BoxDecoration(
                          // gradient: LinearGradient(
                          //   begin: Alignment.topCenter,
                          //   end: Alignment.bottomCenter,
                          //   colors: [
                          //     Theme.of(context).colorScheme.secondary
                          //         .withOpacity(0.05), // soft neon green
                          //     Theme.of(context).colorScheme.secondary
                          //         .withOpacity(0.08), // soft teal
                          //     Theme.of(context).colorScheme.surface, // white
                          //   ],
                          //   stops: const [0.0, 0.08, 0.15],
                          // ),
                        ),
                        child: SafeArea(
                          child: RefreshIndicator(
                            onRefresh:
                                () => _handleRefresh(
                                  splashController,
                                  moduleState,
                                ),
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
        // Modern App Bar with Greeting (hide for grocery module)
        if (!moduleState.isGrocery && !moduleState.isFood)
          const SliverToBoxAdapter(child: HomeAppBarWidget()),

        // Current Order Status (show at top when there's an active order)
        if (!moduleState.showMobileModule &&
            !moduleState.isGrocery &&
            !moduleState.isFood)
          const SliverToBoxAdapter(child: CurrentOrderWidget()),

        // Search Bar (hide for grocery module)
        if (!moduleState.showMobileModule &&
            !moduleState.isTaxi &&
            !moduleState.isGrocery &&
            !moduleState.isFood)
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

        // Store Filter (hide for grocery — grocery has its own inline filtered list)
        if (!moduleState.showMobileModule &&
            !moduleState.isTaxi &&
            !moduleState.isGrocery &&
            !moduleState.isFood)
          SliverPersistentHeader(
            key: _headerKey,
            pinned: true,
            delegate: SliverDelegate(
              height: 100,
              callback: (val) => searchBgShow = val,
              child: const AllStoreFilterWidget(),
            ),
          ),

        // Store List (hide for grocery — grocery has its own inline filtered list)
        if (!moduleState.showMobileModule &&
            !moduleState.isTaxi &&
            !moduleState.isGrocery &&
            !moduleState.isFood)
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
    if (state.isTaxi) return const TaxiHomeScreen();
    if (state.isPlaces) return const PlacesHomeScreen();
    return const SizedBox();
  }

  Widget _buildStoreList(_ModuleState state) {
    return Center(
      child: GetBuilder<StoreController>(
        builder: (storeController) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: ResponsiveHelper.isDesktop(Get.context!) ? 0 : 100,
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
      return Padding(
        padding: EdgeInsets.only(
          bottom: 50.0,
          right: ResponsiveHelper.isDesktop(Get.context!) ? 50 : 0,
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

    if (Get.find<SplashController>().module != null && !state.isTaxi) {
      await _refreshModuleData(state);
    } else if (state.isTaxi) {
      await loadTaxiApis();
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
  final bool isTaxi;
  final bool isPlaces;

  const _ModuleState({
    required this.showMobileModule,
    required this.isParcel,
    required this.isPharmacy,
    required this.isFood,
    required this.isShop,
    required this.isGrocery,
    required this.isTaxi,
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
      isTaxi: module != null && moduleType == AppConstants.taxi,
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
