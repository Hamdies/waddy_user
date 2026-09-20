import 'dart:async';
import 'package:waddy_app/util/frame_stats.dart';

import 'package:waddy_app/api/api_stats.dart';

import 'package:flutter/rendering.dart';
import 'package:waddy_app/features/banner/controllers/banner_controller.dart';
import 'package:waddy_app/features/brands/controllers/brands_controller.dart';
import 'package:waddy_app/features/home/controllers/advertisement_controller.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/widgets/all_store_filter_widget.dart';
import 'package:waddy_app/features/home/widgets/cashback_logo_widget.dart';
import 'package:waddy_app/features/home/widgets/cashback_dialog_widget.dart';
import 'package:waddy_app/features/home/widgets/current_order_widget.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/home/widgets/home_search_widget.dart';
import 'package:waddy_app/features/home/widgets/views/grocery_shelf_view.dart';
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
import 'package:waddy_app/helper/guest_gate_helper.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/item_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/common/widgets/paginated_list_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:waddy_app/features/home/widgets/module_view.dart';
import 'package:waddy_app/features/parcel/screens/parcel_category_screen.dart';
import 'package:waddy_app/features/home/widgets/letter_dialog_widget.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_home_decorations_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  // Stamped only on a CLEAN finish (see the end of loadData). It used to be
  // stamped up front, which meant a load that failed outright still burned the
  // whole 2-minute quiet window: home could not self-heal on remount and the
  // user had to discover pull-to-refresh while staring at an empty screen.
  static DateTime? _lastLoadStartedAt;

  /// Forces the next `loadData(false)` to actually load.
  ///
  /// The module-change path clears every module-scoped cache, and those two
  /// facts have to travel together: without this, a module entered by tapping
  /// a store card would clear the caches, and the module home reached a minute
  /// later would hit the quiet window, skip the fetch, and render nothing.
  /// Used instead of forcing a load on the spot, so entering a store does not
  /// race a whole home load the user did not ask for.
  static void invalidateLoadThrottle() {
    _lastLoadStartedAt = null;
  }

  // Dedupe and throttle are two different jobs, and _lastLoadStartedAt was
  // doing both — which is precisely why a failure burned the window. This one
  // stops the concurrent double-fire (navigation calls loadData(true), then
  // initState calls loadData(false) on arrival); the timestamp above throttles
  // repeat loads. Separating them lets a failed load stay retryable.
  static bool _loadInFlight = false;

  // Incremented per load. Each _safe closure captures the value at creation
  // and drops its write if a newer load has started since — otherwise a slow
  // response from a superseded batch can clear an error the current batch is
  // about to report, or stomp a fresh success with a stale failure.
  static int _loadGen = 0;

  // Wraps one endpoint call so a single failure degrades its own section
  // instead of rejecting the whole Future.wait and blanking the screen.
  //
  // [section] is a HomeSection id: the rail this call feeds, so the UI can put
  // an error row in that slot instead of leaving it shimmering forever.
  static Future<void> _safe(
    String section,
    FutureOr<dynamic> Function() call,
  ) async {
    final int gen = _loadGen;
    try {
      await call();
      if (gen != _loadGen) return;
      Get.find<HomeController>().clearError(section);
    } catch (e) {
      debugPrint('HomeScreen.loadData[$section]: $e');
      if (gen != _loadGen) {
        debugPrint('HomeScreen.loadData[$section]: stale, write dropped');
        return;
      }
      Get.find<HomeController>().recordError(section);
    }
  }

  // Single source of truth for home data: initial load, module switch and
  // pull-to-refresh all go through here (refresh passes reload=true and
  // awaits the whole batch). Calls run concurrently.
  static Future<void> loadData(bool reload, {bool fromModule = false}) async {
    // A batch is already running: whatever this caller wanted is in flight.
    // This is the real double-fire guard — it does not care how long ago the
    // last load ran, only whether one is happening now.
    if (_loadInFlight) return;

    // Home's initState fires this on every remount (tab switches, PageView
    // rebuilds), so the quiet-path window has to outlive navigation hops —
    // pull-to-refresh (reload: true) and module switches still bypass it.
    // Only a *successful* load sets the timestamp, so a failed one stays
    // retryable on the next remount.
    if (!reload &&
        !fromModule &&
        _lastLoadStartedAt != null &&
        DateTime.now().difference(_lastLoadStartedAt!) <
            const Duration(minutes: 2)) {
      return;
    }

    _loadInFlight = true;
    final int gen = ++_loadGen;
    // Home is the screen the whole performance effort is aimed at, and its cost
    // is stated in round trips ("~25 today, 1 once the aggregate endpoint
    // lands"). Bracketing the batch turns that from an estimate read out of the
    // source into a number the app reports about itself.
    ApiStats.startWindow('home load${reload ? ' (refresh)' : ''}');
    // Frames alongside requests: the two failure modes look identical to a
    // user ("home is slow") and have opposite fixes. ApiStats blames the
    // network, FrameStats blames the device — and its build/raster split says
    // whether that is rebuild cost (what scoping update() addresses) or paint
    // cost (which scoping will not touch). See docs/performance_baseline.md.
    FrameStats.start('home load${reload ? ' (refresh)' : ''}');
    try {
      await _loadDataInner(reload, fromModule: fromModule);
    } finally {
      // finally, not a trailing statement: an exception escaping the batch
      // would otherwise leave the flag set and block every future load for
      // the rest of the session.
      _loadInFlight = false;
      ApiStats.printReport();
      FrameStats.stopAndPrint();
    }

    // Superseded by a newer load while we were running — that one owns the
    // quiet-path stamp.
    if (gen != _loadGen) return;

    // Clean finish only. A load that left any section failed must not start
    // the 2-minute window, or the retry path is closed off exactly when it is
    // needed most.
    if (!Get.find<HomeController>().hasAnyError) {
      _lastLoadStartedAt = DateTime.now();
    }
  }

  static Future<void> _loadDataInner(
    bool reload, {
    bool fromModule = false,
  }) async {
    final splashController = Get.find<SplashController>();
    // The module's kind, parsed once. `.toString()` on a String? is what this
    // used to say, which reads as "whatever this is, make it a string" — and
    // for a null module produced the literal "null", a value that compares
    // unequal to every branch below by luck rather than by design.
    final ModuleType moduleType =
        splashController.module?.type ?? ModuleType.unknown;
    final configModule = splashController.configModelOrNull?.moduleConfig!.module;
    final bool isParcel = configModule?.isParcel ?? false;

    Get.find<FlashSaleController>().setEmptyFlashSale(fromModule: fromModule);

    // The featured/visit-again store lists filter against the saved address's
    // zoneData (module + zone match, StoreController._prepareFeaturedStore).
    // On a fresh install that zoneData doesn't exist until syncZoneData
    // persists it, and losing that race drops every store — blanking Steal of
    // the Day and friends for the whole session (the quiet-path window below
    // blocks a retry). Block on the sync once instead of racing it.
    final savedAddress = AddressHelper.getUserAddressFromSharedPref();
    final bool zoneDataMissing =
        savedAddress != null && (savedAddress.zoneData?.isEmpty ?? true);
    if (zoneDataMissing) {
      await _safe(
        HomeSection.zone,
        () => Get.find<LocationController>().syncZoneData(),
      );
    }

    final List<Future<void>> futures = [
      if (!zoneDataMissing)
        _safe(
          HomeSection.zone,
          () => Get.find<LocationController>().syncZoneData(),
        ),
      _safe(
        HomeSection.zone,
        () => Get.find<LocationController>().refreshOutOfZoneStatus(),
      ),
      // Restores "you're on the list" state and replays any notify-me request
      // that never reached the server, so a network blip can't silently drop
      // a promise we made to the user.
      _safe(
        HomeSection.zone,
        () => Get.find<LocationController>().initZoneRequestState(),
      ),
    ];

    // For Places module, only load essential data and skip unnecessary APIs
    if (moduleType == ModuleType.places) {
      final address = AddressHelper.getUserAddressFromSharedPref();
      if (address != null) {
        futures.add(
          _safe(
            HomeSection.zone,
            () => Get.find<LocationController>().getZone(
              address.latitude,
              address.longitude,
              false,
              updateInAddress: true,
            ),
          ),
        );
      }
      await Future.wait(futures);
      return;
    }

    if (AuthHelper.isLoggedIn()) {
      futures.addAll([
        _safe(
          HomeSection.orderAgain,
          () => Get.find<StoreController>().getVisitAgainStoreList(
            fromModule: fromModule,
          ),
        ),
        _safe(
          HomeSection.modules,
          () => Get.find<ProfileController>().getUserInfo(),
        ),
        _safe(
          HomeSection.modules,
          () => Get.find<NotificationController>().getNotificationList(reload),
        ),
        _safe(
          HomeSection.modules,
          () => Get.find<CouponController>().getCouponList(),
        ),
        _safe(
          HomeSection.modules,
          () => Get.find<XpController>().getLevelDetails(reload: reload),
        ),
        _safe(
          HomeSection.modules,
          () =>
              Get.find<OrderController>().getRunningOrders(1, isUpdate: reload),
        ),
      ]);
    }

    if (splashController.module != null && !isParcel) {
      // Waddi's food & grocery homes are custom screens. Grocery renders
      // banners, categories, best-nearby, the store list and reorder chips;
      // food renders banners, the ranked rail, cuisines and the store list —
      // no categories, no best-nearby (see the guard on popular/latest below).
      // The generic rails (reviewed items, campaigns, top offers, ads) only
      // exist on other module types' home bodies, and every "see all" screen
      // refetches on open — so skip those here.
      final bool isCustomModuleHome =
          moduleType == ModuleType.food || moduleType == ModuleType.grocery;
      futures.addAll([
        _safe(
          HomeSection.modules,
          () => Get.find<BannerController>().getBannerList(reload),
        ),
        // Keeps the module-select screen's sections warm for when the user
        // returns there: recommended stores, Steal of the Day's item pool,
        // and Food Offers all read these lists.
        _safe(
          HomeSection.recommended,
          () => Get.find<StoreController>().getRecommendedStoreList(),
        ),
        _safe(
          HomeSection.offers,
          () => Get.find<ItemController>().getDiscountedItemList(
            offset: '1',
            firstTimeCategoryLoad: true,
          ),
        ),
        _safe(
          HomeSection.offers,
          () => Get.find<ItemController>().getPopularItemList(
            offset: '1',
            firstTimeCategoryLoad: true,
          ),
        ),
        _safe(
          HomeSection.modules,
          () => Get.find<CategoryController>().getCategoryList(reload),
        ),
        // Popular and latest stores, for the modules that actually render
        // them: grocery (ModuleBestNearbySection, and the "all" tile inside
        // ModuleCategoryCircles), shop (PopularStoreView / NewOnMartView) and
        // pharmacy (NewOnMartView, BestStoreNearbyView).
        //
        // Food renders neither. Its cuisine strip is the same widget as
        // grocery's category strip but is passed `showAllTile: false`, and the
        // "all" tile is the only thing in there that reads these lists — so
        // before this guard, every food home load spent two requests on two
        // lists nothing on the screen could display. The "see all" screens
        // fetch for themselves in their own initState, so nothing downstream
        // depends on the prefetch either.
        if (moduleType != ModuleType.food) ...[
          _safe(
            HomeSection.fastest,
            () => Get.find<StoreController>().getPopularStoreList(
              reload,
              'all',
              false,
            ),
          ),
          _safe(
            HomeSection.fastest,
            () => Get.find<StoreController>().getLatestStoreList(
              reload,
              'all',
              false,
            ),
          ),
        ],
        // Item-details' "you may also like" reads this list app-wide.
        _safe(
          HomeSection.offers,
          () => Get.find<ItemController>().getRecommendedItemList(
            reload,
            'all',
            false,
          ),
        ),
        _safe(
          HomeSection.fastest,
          () => Get.find<StoreController>().getStoreList(1, reload),
        ),
      ]);
      if (!isCustomModuleHome) {
        futures.addAll([
          _safe(
            HomeSection.offers,
            () => Get.find<ItemController>().getReviewedItemList(
              offset: '1',
              firstTimeCategoryLoad: true,
            ),
          ),
          _safe(
            HomeSection.offers,
            () => Get.find<CampaignController>().getBasicCampaignList(reload),
          ),
          _safe(
            HomeSection.offers,
            () => Get.find<CampaignController>().getItemCampaignList(reload),
          ),
          _safe(
            HomeSection.offers,
            () =>
                Get.find<StoreController>().getTopOfferStoreList(reload, false),
          ),
          _safe(
            HomeSection.modules,
            () => Get.find<AdvertisementController>().getAdvertisementList(),
          ),
        ]);
      }
      // Grocery used to fetch flash sales here (`G-04`). `GroceryHomeScreen`
      // never built `FlashSaleViewWidget`, so the request was parsed and held
      // in memory on every grocery home load with nothing to render it. The
      // ecommerce fetch below stays: `shop_home_screen.dart` does build the
      // rail, and it navigates to the details route. If grocery ever wants the
      // rail, adding it back here is one line.
      if (moduleType == ModuleType.ecommerce) {
        futures.addAll([
          _safe(
            HomeSection.offers,
            () => Get.find<ItemController>().getFeaturedCategoriesItemList(
              false,
              false,
            ),
          ),
          _safe(
            HomeSection.offers,
            () => Get.find<FlashSaleController>().getFlashSale(reload, false),
          ),
          _safe(
            HomeSection.modules,
            () => Get.find<BrandsController>().getBrandList(),
          ),
        ]);
      }
      if (Get.find<HomeController>().showRamadanDecorations) {
        futures.add(
          _safe(
            HomeSection.offers,
            () => Get.find<ItemController>().getRamadanFeaturedItemList(),
          ),
        );
      }
    }

    futures.addAll([
      _safe(
        HomeSection.modules,
        () => Get.find<XpController>().getXpConfig(reload: reload),
      ),
      _safe(HomeSection.modules, () => splashController.getModules()),
    ]);

    if (splashController.module == null &&
        splashController.configModelOrNull?.module == null) {
      futures.addAll([
        _safe(
          HomeSection.modules,
          () => Get.find<BannerController>().getFeaturedBanner(),
        ),
        _safe(HomeSection.fastest, () async {
          await Get.find<StoreController>().getFeaturedStoreList();
          _fetchFeaturedStoresRecommendedItems();
        }),
        _safe(
          HomeSection.recommended,
          () => Get.find<StoreController>().getRecommendedStoreList(),
        ),
        // The grocery shelf's aisles, and only when the shelf is actually
        // rendering them — home is the most-loaded screen in the app and a
        // request for a list nothing paints is pure cost. Pinned to the
        // grocery module rather than read off CategoryController's
        // selected-module list, which on this screen is either empty or —
        // after a visit to any module — that module's categories under a
        // grocery headline.
        if (kGroceryShelfAisles)
          _safe(
            HomeSection.grocery,
            () => Get.find<CategoryController>().getGroceryAisles(),
          ),
        // One call fills BOTH quick rails (StoreController populates
        // _mostOrderedFoodStores and _quickGroceryStores together), so its failure
        // has to be reported against both — keying it to one rail only would
        // leave the other shimmering with nothing to explain it.
        _safe(HomeSection.fastest, () async {
          // Quick-delivery rails need module ids to resolve food/grocery.
          if (splashController.moduleList == null) {
            await splashController.getModules();
          }
          final storeController = Get.find<StoreController>();
          try {
            await storeController.getDashboardQuickStoreLists(reload: reload);
            Get.find<HomeController>().clearError(HomeSection.grocery);
          } catch (_) {
            Get.find<HomeController>().recordError(HomeSection.grocery);
            rethrow; // _safe records the `fastest` half
          }
        }),
      ]);
      if (AuthHelper.isLoggedIn()) {
        futures.add(
          _safe(
            HomeSection.modules,
            () => Get.find<AddressController>().getAddressList(),
          ),
        );
      }
    }

    if (splashController.module != null && isParcel) {
      futures.add(
        _safe(
          HomeSection.modules,
          () => Get.find<ParcelController>().getParcelCategoryList(),
        ),
      );
    }

    if (splashController.module != null && moduleType == ModuleType.pharmacy) {
      futures.addAll([
        _safe(
          HomeSection.modules,
          () => Get.find<ItemController>().getBasicMedicine(reload, false),
        ),
        _safe(
          HomeSection.fastest,
          () => Get.find<StoreController>().getFeaturedStoreList(),
        ),
        _safe(HomeSection.modules, () async {
          final itemController = Get.find<ItemController>();
          await itemController.getCommonConditions(false);
          if (itemController.commonConditions?.isNotEmpty ?? false) {
            itemController.getConditionsWiseItem(
              itemController.commonConditions![0].id!,
              false,
            );
          }
        }),
      ]);
    }

    await Future.wait(futures);

    // Out-of-zone escalation (guest AND logged-in). Once the zone status is
    // fresh, an out-of-zone shopping module (food/grocery/pharmacy/shop) shows
    // the "No delivery there" sheet — at most once per out-of-zone episode.
    // The header still renders the OUT OF ZONE badge + coming-soon banner so
    // browsing stays available. Parcel/places run their own location flows.
    final bool isShoppingModule =
        moduleType == ModuleType.food ||
        moduleType == ModuleType.grocery ||
        moduleType == ModuleType.pharmacy ||
        moduleType == ModuleType.ecommerce;
    if (splashController.module != null && isShoppingModule) {
      await GuestGate.maybeAutoShowNoDelivery();
      // In-zone counterpart of the same question: the user's real position is
      // in a DIFFERENT serving zone than their saved address, so ask which one
      // they meant. Mutually exclusive with the out-of-zone sheet above (that
      // one needs empty GPS zoneIds, this one needs non-empty), so the two can
      // never stack on the same load.
      await GuestGate.maybeAutoShowAddressDivergence();
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _headerKey = GlobalKey();
  ScrollDirection _lastDirection = ScrollDirection.idle;

  /// Scroll offset, for the status-bar band alone.
  ///
  /// A ValueNotifier rather than setState: this updates on every scroll frame,
  /// and the only thing that needs to repaint is a 40pt stripe. Calling
  /// setState here would rebuild the whole feed sixty times a second to
  /// animate one colour.
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may grant location permission elsewhere (pick map, settings)
    // and come back — keep the out-of-zone hint current.
    if (state == AppLifecycleState.resumed) {
      Get.find<LocationController>().refreshOutOfZoneStatus();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeScreen.loadData(false).then((value) {
      if (!mounted) return;
      Get.find<SplashController>().getReferBottomSheetStatus();

      final showReferral =
          (Get.find<ProfileController>().userInfoModel?.isValidForDiscount ??
              false) &&
          Get.find<SplashController>().showReferBottomSheet;

      if (showReferral) {
        _showReferBottomSheet();
      } else {
        _checkAndShowWelcomeLetter();
      }
    });

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

    // Separate listener on purpose: the one above returns early whenever the
    // direction is unchanged, which is almost every frame of a scroll — it can
    // never drive a per-pixel value. Feeding the band from there would make it
    // step only when the user reverses.
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      _scrollOffset.value = _scrollController.offset;
    });
  }

  Future<void> _checkAndShowWelcomeLetter() async {
    if (!AuthHelper.isLoggedIn() || !mounted) return;

    final splashController = Get.find<SplashController>();
    splashController.getWelcomeLetterShownStatus();

    if (splashController.welcomeLetterShown) return;

    // Wait a bit for the UI to settle
    await Future.delayed(const Duration(milliseconds: 500));

    // The letter greets the user by name, and it only ever shows once. Right
    // after login getUserInfo() is still in flight among loadData's concurrent
    // futures, so opening now would address a brand-new user as "friend" and
    // then burn the shown-flag forever. Fetch the profile first, and leave the
    // flag unset if it fails so the letter gets another chance next launch.
    final profileController = Get.find<ProfileController>();
    if (profileController.userInfoModel == null) {
      await profileController.getUserInfo();
      if (!mounted) return;
      if (profileController.userInfoModel == null) return;
    }

    if (mounted) {
      splashController.saveWelcomeLetterShownStatus(true);
      showDialog(
        context: context,
        // Never trap a first-run user in marketing: tapping outside dismisses.
        barrierDismissible: true,
        builder: (context) => const LetterDialogWidget(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  void _showReferBottomSheet() {
    showModalBottomSheet(
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
      (value) => Get.find<SplashController>().saveReferBottomSheetStatus(false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      builder: (splashController) {
        final moduleState = _ModuleState.from(splashController);

        // The hero banner paints its own status-bar area, so the body must
        // not consume the top inset when it is shown. Grocery/food now
        // render their own HomeHeroBannerWidget inside the module content,
        // so they cover the status bar too — only parcel/places (which keep
        // their own plain app bars) and desktop need the outer SafeArea.
        final bool heroCoversStatusBar =
            !moduleState.isParcel && !moduleState.isPlaces;

        return GetBuilder<HomeController>(
          builder: (homeController) {
            return Scaffold(
              appBar: null,
              endDrawer: const MenuDrawer(),
              endDrawerEnableOpenDragGesture: false,
              backgroundColor: Theme.of(context).colorScheme.surface,
              body:
                  moduleState.isParcel
                      ? const ParcelCategoryScreen()
                      : SafeArea(
                        top: !heroCoversStatusBar,
                        child: _withStatusBarScrim(
                          context,
                          enabled: heroCoversStatusBar,
                          child: RefreshIndicator(
                            // The one moment the user physically grabs the
                            // screen, and it used to answer in stock Material
                            // blue on grey — the only unbranded surface in the
                            // app, on the most-repeated gesture in it.
                            color: WaddyColors.primary,
                            backgroundColor: WaddyColors.surface,
                            strokeWidth: 2.5,
                            displacement: 32,
                            edgeOffset:
                                heroCoversStatusBar
                                    ? MediaQuery.of(context).padding.top
                                    : 0,
                            onRefresh: () => _handleRefresh(splashController),
                            child: _buildMobileHomeContent(
                              context,
                              splashController,
                              moduleState,
                            ),
                          ),
                        ),
                      ),
              floatingActionButton: _buildFloatingActionButton(
                context,
                homeController,
              ),
            );
          },
        );
      },
    );
  }

  /// Paints an opaque band over the status bar so scrolling content passes
  /// *behind* the clock instead of across it.
  ///
  /// The hero is an ordinary scrolling sliver, deliberately — pinning it spent
  /// ~100pt of the first screen on a search field nobody needs pinned on a
  /// browse-then-order page. But nothing replaced the protection pinning used
  /// to give for free: `statusBarColor` is transparent so the icons can sit on
  /// mint, and the banner's own `SafeArea` pads only the banner's content, not
  /// the feed that scrolls up past it a second later. So the w900 greeting
  /// travelled up and landed on the system clock.
  ///
  /// The band starts as the hero's own first gradient stop, so at rest it is
  /// the same colour as the pixels already behind it and cannot be seen.
  ///
  /// It does not stay that colour. The band's job is to stop the feed
  /// disappearing into the system clock, and it has to keep doing that after
  /// the mint hero has scrolled away — at which point a mint stripe is sitting
  /// on a white page with dark-teal cards sliding under it, and a button
  /// halfway beneath it reads as a rendering fault rather than a scrim. So the
  /// colour follows what is actually behind it: mint over the hero, page
  /// colour once the hero is gone.
  ///
  /// It stays fully opaque throughout. Fading it out instead would be the
  /// wrong fix — the moment it becomes translucent the greeting is legible
  /// through it again, which is the bug the band exists to prevent.
  Widget _withStatusBarScrim(
    BuildContext context, {
    required bool enabled,
    required Widget child,
  }) {
    final double inset = MediaQuery.paddingOf(context).top;
    // Desktop and the plain-app-bar modules keep their outer SafeArea, so
    // nothing scrolls under the bar there and a band would just be a stripe.
    if (!enabled || inset <= 0) return child;

    return Stack(
      // Expand, not the default loose fit: the scroll view was previously the
      // direct child of a SafeArea and took the full box. Under a loose Stack
      // it would be handed `minHeight: 0` and its own sizing rules would decide
      // instead, which is not a thing to leave to chance on the app's main
      // scroll surface just to hang a 40pt band off the top.
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: inset,
          // Ignores pointers: the band sits over the scroll view, and a fling
          // that starts in the top few points of the screen is an ordinary
          // scroll, not a tap on a decoration.
          child: IgnorePointer(
            // Only this stripe rebuilds per scroll frame. The builder is
            // deliberately the innermost thing in the tree: put it any higher
            // and the feed repaints sixty times a second to recolour 40pt.
            child: ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (context, offset, _) {
                // Crossfade over the band's own height. By the time the hero
                // has travelled its own inset, whatever is behind the band is
                // page, not hero.
                final double t =
                    inset <= 0 ? 1.0 : (offset / inset).clamp(0.0, 1.0);
                return ColoredBox(
                  color:
                      Color.lerp(
                        HomeHeroBannerWidget.statusBarTint,
                        WaddyColors.surface,
                        t,
                      )!,
                );
              },
            ),
          ),
        ),
      ],
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
        // New neo-brutalist hero banner (preview — sits above the existing app bar)
        if (!moduleState.hasOwnScaffold) ...[
          // Search lives inside the banner, the way Talabat and Rabbit do it:
          // address line, greeting, search — one coloured block that ends
          // right under the field.
          //
          // It used to be a pinned sliver of its own. That cost a lot for
          // little: the delegate reserved the status-bar inset as top padding
          // at all times, so at rest there was a status-bar-sized hole between
          // the greeting and the field and another gap under it, and the
          // banner had to stop short at the headline to avoid stacking the two
          // paddings. Roughly 100pt of the first screen went to separating a
          // search box from the header it belongs to — and a persistently
          // pinned search bar is not something a browse-then-order screen
          // needs, it just permanently occupies the fold.
          const SliverToBoxAdapter(
            child: HomeHeroBannerWidget(showSearch: true),
          ),
        ],

        // Current Order Status (show at top when there's an active order)
        if (moduleState.usesGenericBody)
          const SliverToBoxAdapter(child: CurrentOrderWidget()),

        // Search Bar (hide for grocery, food, and places modules)
        if (moduleState.usesGenericBody)
          const SliverToBoxAdapter(child: HomeSearchWidget()),

        // Module Content
        // Places manages its own scrolling and needs a bounded height —
        // SliverToBoxAdapter gives unbounded constraints and crashes its
        // root Column/Expanded, so fill the remaining viewport instead.
        if (moduleState.isPlaces)
          SliverFillRemaining(
            hasScrollBody: true,
            child: Center(
              child: SizedBox(
                width: Dimensions.maxContentWidth,
                child: _buildModuleContent(moduleState),
              ),
            ),
          )
        // Food renders itself as a sliver (SliverMainAxisGroup), so it goes
        // straight into this list. Wrapping it in SliverToBoxAdapter — as every
        // module used to be — is exactly what defeated the lazy building: the
        // whole home became one box that laid out every section, on and off
        // screen, in the first frame.
        //
        // The Center/SizedBox(maxContentWidth) the other branch keeps is a
        // no-op on phones (1170pt is wider than any phone), and this app is
        // mobile-only — so nothing is lost by dropping it on the sliver path.
        else if (moduleState.isDashboard)
          // The dashboard landing feed, also a sliver now.
          ModuleView(splashController: splashController)
        else if (moduleState.isFood || moduleState.isGrocery)
          _buildModuleContent(moduleState)
        else
          // Pharmacy and shop still render as boxes.
          SliverToBoxAdapter(
            child: Center(
              child: SizedBox(
                width: Dimensions.maxContentWidth,
                child: _buildModuleContent(moduleState),
              ),
            ),
          ),

        // Store Filter (hide for grocery, food, and places modules)
        if (moduleState.usesGenericBody)
          SliverPersistentHeader(
            key: _headerKey,
            pinned: true,
            delegate: SliverDelegate(
              height:
                  100 *
                  MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3),
              child: const AllStoreFilterWidget(),
            ),
          ),

        // Store List (hide for grocery, food, and places modules)
        if (moduleState.usesGenericBody)
          SliverToBoxAdapter(child: _buildStoreList(context, moduleState)),
      ],
    );

    // Only show Ramadan decorations on the main dashboard (module view)
    if (moduleState.isDashboard) {
      return RamadanHomeDecorationsWidget(
        scrollController: _scrollController,
        child: content,
      );
    }

    return content;
  }

  Widget _buildModuleContent(_ModuleState state) {
    if (state.isGrocery) {
      return GroceryHomeScreen(scrollController: _scrollController);
    }
    if (state.isPharmacy) return const PharmacyHomeScreen();
    if (state.isFood)
      return FoodHomeScreen(scrollController: _scrollController);
    if (state.isShop) return const ShopHomeScreen();
    if (state.isPlaces) return const PlacesHomeScreen();
    return const SizedBox();
  }

  Widget _buildStoreList(BuildContext context, _ModuleState state) {
    return Center(
      child: GetBuilder<StoreController>(
        builder: (storeController) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: Dimensions.bottomNavReserve(context),
            ),
            child: PaginatedListView(
              scrollController: _scrollController,
              itemsPerPage: 12,
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
                  horizontal: Dimensions.paddingSizeSmall,
                  vertical: Dimensions.paddingSizeDefault,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget? _buildFloatingActionButton(
    BuildContext context,
    HomeController homeController,
  ) {
    if (AuthHelper.isLoggedIn() &&
        homeController.cashBackOfferList != null &&
        homeController.cashBackOfferList!.isNotEmpty &&
        homeController.showFavButton) {
      final isRtl = Directionality.of(context) == TextDirection.rtl;
      final safeBottom = MediaQuery.of(context).viewPadding.bottom;
      return Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: safeBottom + 16,
          end: (isRtl ? 8 : 0),
        ),
        child: InkWell(
          onTap: () => Get.dialog(const CashBackDialogWidget()),
          child: const CashBackLogoWidget(),
        ),
      );
    }
    return null;
  }

  Future<void> _handleRefresh(SplashController splashController) async {
    splashController.setRefreshing(true);
    await HomeScreen.loadData(true);
    splashController.setRefreshing(false);
  }
}

/// What home is currently showing: one module, or the dashboard.
///
/// This used to be seven booleans derived from the same string, and the body
/// then asked the same four-part question — "not the dashboard, and not
/// grocery, food or places" — in four different places, once per sliver, plus
/// a fifth variant for the hero. Adding a module meant getting five conditions
/// right; getting one wrong showed a rail on a screen that has no room for it.
///
/// One nullable [ModuleType] answers all of it, and the questions the body
/// actually asks are named here once.
class _ModuleState {
  /// The active module, or null on the aggregated dashboard.
  final ModuleType? type;

  const _ModuleState(this.type);

  factory _ModuleState.from(SplashController controller) {
    final ModuleModel? module = controller.module;
    // configModel.module is the single-module deployment's pinned module; on a
    // multi-module build it is always null, so `module == null` is the whole
    // question in practice.
    if (module == null && controller.configModelOrNull?.module == null) {
      return const _ModuleState(null);
    }
    return _ModuleState(module?.type ?? ModuleType.unknown);
  }

  /// The dashboard: every module's stores at once, no module selected.
  bool get isDashboard => type == null;

  bool get isParcel => type == ModuleType.parcel;
  bool get isPharmacy => type == ModuleType.pharmacy;
  bool get isFood => type == ModuleType.food;
  bool get isShop => type == ModuleType.ecommerce;
  bool get isGrocery => type == ModuleType.grocery;
  bool get isPlaces => type == ModuleType.places;

  /// Modules that render their own complete screen — hero, search, catalogue
  /// and all — so home must not stack its generic furniture on top of them.
  ///
  /// This is the four-part condition that was spelled out at four call sites.
  /// Naming it is the difference between "why is this rail missing on
  /// grocery?" and reading the name.
  bool get hasOwnScaffold => isGrocery || isFood || isPlaces;

  /// The generic home body: hero, search bar, filter header and the flat store
  /// list. Pharmacy and shop still use it; nothing else does.
  bool get usesGenericBody => !isDashboard && !hasOwnScaffold;
}

class SliverDelegate extends SliverPersistentHeaderDelegate {
  Widget child;
  double height;

  SliverDelegate({required this.child, this.height = 50});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
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
