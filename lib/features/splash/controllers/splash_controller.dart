import 'package:flutter/foundation.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/helper/cache_ttl_helper.dart';
import 'package:waddy_app/features/splash/domain/repositories/splash_repository.dart';
import 'package:waddy_app/common/models/response_model.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/banner/controllers/banner_controller.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/item/controllers/campaign_controller.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/splash/domain/models/landing_model.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/helper/splash_route_helper.dart';

class SplashController extends GetxController implements GetxService {
  final SplashServiceInterface splashServiceInterface;
  SplashController({required this.splashServiceInterface});

  ConfigModel? _configModel;

  /// The app configuration, which is **non-null on every screen**.
  ///
  /// ## Why this can be non-null
  ///
  /// Navigation past the splash is gated on `_configLoaded`, and that flag is
  /// only ever set inside the `statusCode == 200` branch of
  /// [_handleConfigResponse]. A config failure shows `NoInternetScreen` and the
  /// app never routes onward. Nothing assigns `_configModel` back to null.
  /// Notification cold starts route through the splash; deep links stash and
  /// replay from the dashboard's first frame; every other `offAllNamed` is an
  /// in-app return to home. So by the time any screen builds, config is loaded.
  ///
  /// ## Why it throws rather than defaulting
  ///
  /// There are ~358 `configModel!` dereferences. Converting them to
  /// `?? someDefault` would add ~358 fallbacks that can never fire, and each
  /// would *hide* a broken gate: a wrong-but-plausible default for a payment
  /// flag or a tax rate is far worse than a crash. The safety comes from the
  /// load gate, not from defaults.
  ///
  /// This getter keeps that guarantee honest. If the gate is ever broken, the
  /// crash names the bug instead of surfacing as a generic null-check failure
  /// three call-frames away.
  ///
  /// Code that legitimately runs *before* the gate — the splash screen itself,
  /// and anything that must degrade rather than fail — reads [configModelOrNull]
  /// instead.
  ConfigModel get configModel =>
      _configModel ??
      (throw StateError(
        'configModel read before the config load completed. Navigation past '
        'the splash is gated on _configLoaded, so this means either the gate '
        'was bypassed or this code runs pre-splash — use configModelOrNull.',
      ));

  /// The configuration, or null before it has loaded.
  ///
  /// For the splash path and for callers that genuinely handle absence. Prefer
  /// [configModel] everywhere else: a null check that can never be true reads
  /// as though config is optional, which it is not.
  ConfigModel? get configModelOrNull => _configModel;

  bool _firstTimeConnectionCheck = true;
  bool get firstTimeConnectionCheck => _firstTimeConnectionCheck;

  bool _hasConnection = true;
  bool get hasConnection => _hasConnection;

  ModuleModel? _module;
  ModuleModel? get module => _module;

  ModuleModel? _cacheModule;
  ModuleModel? get cacheModule => _cacheModule;

  List<ModuleModel>? _moduleList;
  List<ModuleModel>? get moduleList => _moduleList;

  int _moduleIndex = 0;
  int get moduleIndex => _moduleIndex;

  Map<String, dynamic>? _data = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _selectedModuleIndex = 0;
  int get selectedModuleIndex => _selectedModuleIndex;

  LandingModel? _landingModel;
  LandingModel? get landingModel => _landingModel;

  bool _webSuggestedLocation = false;
  bool get webSuggestedLocation => _webSuggestedLocation;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  bool _showReferBottomSheet = false;
  bool get showReferBottomSheet => _showReferBottomSheet;

  bool _welcomeLetterShown = false;
  bool get welcomeLetterShown => _welcomeLetterShown;

  bool _animationComplete = false;
  bool _configLoaded = false;
  bool get configLoaded => _configLoaded;
  bool _hasNavigated = false;
  NotificationBodyModel? _pendingNotificationBody;

  DateTime get currentTime => DateTime.now();

  void resetSplashState() {
    _animationComplete = false;
    _configLoaded = false;
    _hasNavigated = false;
    _pendingNotificationBody = null;
  }

  void markAnimationComplete() {
    _animationComplete = true;
    _tryNavigate();
  }

  // The splash screen registers its exit animation here; the route helper
  // awaits it right before pushing the next screen, so the splash keeps
  // animating until navigation is actually happening — never a dead frame.
  Future<void> Function()? _splashExit;

  void registerSplashExit(Future<void> Function() exit) {
    _splashExit = exit;
  }

  Future<void> playSplashExit() async {
    final exit = _splashExit;
    _splashExit = null;
    if (exit != null) {
      try {
        await exit();
      } catch (e, s) {
        swallow('splash exit animation', e, s);
      }
    }
  }

  void _tryNavigate() {
    if (_animationComplete && _configLoaded && !_hasNavigated) {
      _hasNavigated = true;
      route(body: _pendingNotificationBody);
    }
  }

  void selectModuleIndex(int index) {
    _selectedModuleIndex = index;
    update();
  }

  Future<void> getConfigData({
    NotificationBodyModel? notificationBody,
    bool loadModuleData = false,
    bool loadLandingData = false,
    DataSourceEnum source = DataSourceEnum.local,
    bool fromMainFunction = false,
    bool fromDemoReset = false,
  }) async {
    _hasConnection = true;
    _moduleIndex = 0;
    Response response;
    if (source == DataSourceEnum.local && !fromDemoReset) {
      response = await splashServiceInterface.getConfigData(
        source: DataSourceEnum.local,
      );
      _handleConfigResponse(
        response,
        loadModuleData,
        loadLandingData,
        fromMainFunction,
        fromDemoReset,
        notificationBody,
      );
      getConfigData(
        loadModuleData: loadModuleData,
        loadLandingData: loadLandingData,
        source: DataSourceEnum.client,
      );
    } else {
      response = await splashServiceInterface.getConfigData(
        source: DataSourceEnum.client,
      );
      _handleConfigResponse(
        response,
        loadModuleData,
        loadLandingData,
        fromMainFunction,
        fromDemoReset,
        notificationBody,
      );
    }
  }

  Future<void> _handleConfigResponse(
    Response response,
    bool loadModuleData,
    bool loadLandingData,
    bool fromMainFunction,
    bool fromDemoReset,
    NotificationBodyModel? notificationBody,
  ) async {
    if (response.statusCode == 200) {
      _data = response.body;
      // New payload, so every parsed module config is stale.
      _moduleConfigCache.clear();
      _configModel = ConfigModel.fromJson(response.body);
      _configModel!.guestCheckoutStatus = false;
      Get.find<HomeController>().initRamadanMode(
        _configModel!.ramadanMode == true,
      );
      // Single-module deployments: the config names the one module, so the
      // app is inside it from the first frame and never sees a picker. It is
      // still a module change, so the user's cart/cashback/favourites for it
      // have to be fetched — the same call the tile path makes.
      if (_configModel!.module != null) {
        _setModule(_configModel!.module);
        _refreshModuleScopedUserData(_configModel!.module!);
      } else if ((loadModuleData && _module != null)) {
        _setModule(_module);
        _refreshModuleScopedUserData(_module!);
      }
      if (loadLandingData) {
        await getLandingPageData();
      }
      if (fromMainFunction) {
        _mainConfigRouting();
      } else if (fromDemoReset) {
        Get.offAllNamed(RouteHelper.getInitialRoute(fromSplash: true));
      } else {
        _pendingNotificationBody = notificationBody;
        _configLoaded = true;
        _tryNavigate();
      }
    } else {
      if (response.statusText == ApiClient.noInternetMessage) {
        _hasConnection = false;
      }
    }
    update();
  }

  _mainConfigRouting() async {
    if (Get.find<AuthController>().isLoggedIn()) {
      Get.find<AuthController>().updateToken();
      if (Get.find<SplashController>().module != null) {
        await Get.find<FavouriteController>().getFavouriteList();
      }
    }
  }

  Future<void> getLandingPageData({
    DataSourceEnum source = DataSourceEnum.local,
  }) async {
    LandingModel? landingModel;
    if (source == DataSourceEnum.local) {
      landingModel = await splashServiceInterface.getLandingPageData(
        source: DataSourceEnum.local,
      );
      _prepareLandingModel(landingModel);
      getLandingPageData(source: DataSourceEnum.client);
    } else {
      landingModel = await splashServiceInterface.getLandingPageData(
        source: DataSourceEnum.client,
      );
      _prepareLandingModel(landingModel);
    }
  }

  _prepareLandingModel(LandingModel? landingModel) {
    if (landingModel != null) {
      _landingModel = landingModel;
      hoverStates = List<bool>.generate(
        _landingModel!.availableZoneList!.length,
        (index) => false,
      );
    }
    update();
  }

  /// Cold start: no module is active, whatever the user was in last time.
  ///
  /// The app opens on the module picker by design, so the session begins with
  /// `_module == null` and a header that names no module. `_cacheModule` is
  /// restored because it is the "last module in play" that dashboard-opened
  /// screens read — it is not a module the user is in.
  ///
  /// This used to read as `_module = null; ... if (_cacheModule != null)
  /// _setModule(_module)` — i.e. "set the module to the null I just assigned",
  /// guarded by a different variable. It took three files to work out that it
  /// meant "clear the header".
  Future<void> initSharedData() async {
    _module = null;
    splashServiceInterface.initSharedData();
    _cacheModule = splashServiceInterface.getCacheModule();
    splashServiceInterface.updateModuleHeader(null);
  }

  void setCacheConfigModule(ModuleModel? cacheModule) {
    _configModel!.moduleConfig!.module = Module.fromJson(
      _data!['module_config'][cacheModule!.moduleType],
    );
  }

  bool? showIntro() {
    return splashServiceInterface.showIntro();
  }

  void disableIntro() {
    splashServiceInterface.disableIntro();
  }

  void setFirstTimeConnectionCheck(bool isChecked) {
    _firstTimeConnectionCheck = isChecked;
  }

  /// Writes module state: the two prefs, the API header, the module config,
  /// and the per-module refreshes that hang off them.
  ///
  /// Private on purpose. Twenty-four widget tap handlers used to call this
  /// directly and it is only half of what changing module means — it does not
  /// clear a single one of the caches that belong to the module being left, so
  /// the new module's screens rendered the old module's catalogue. The ways in
  /// are [enterModule] and [activateModuleFor]; the way out is [leaveModule].
  Future<void> _setModule(ModuleModel? module, {bool notify = true}) async {
    // Remember what they are leaving. Backing out of a module home clears
    // `_module` so the module picker can render, which used to make every
    // return look like a brand-new switch — see [switchModule].
    if (module == null && _module != null) {
      _lastActiveModuleId = _module!.id;
    }
    _module = module;

    // Synchronous, and first: callers change module and navigate on the very
    // next line without awaiting, so the header has to be right before this
    // method yields.
    splashServiceInterface.updateModuleHeader(module);

    if (module != null) {
      if (_configModel != null) {
        _configModel!.moduleConfig!.module = getModuleConfig(module.moduleType);
      }
      // The one persisted copy of "which module", and the only one left. It
      // deliberately outlives leaving a module: ~20 screens opened from the
      // module-less dashboard read it as "the module of the thing I am
      // showing" — the cart's module id, the item sheet's config,
      // getStoreDetails. `_module` answers "where is the user", this answers
      // "which module was last in play"; they are different questions and the
      // app asks both.
      _cacheModule = await splashServiceInterface.setCacheModule(module);
    }

    if (notify) {
      update();
    }
  }

  /// The per-module data that belongs to the *user* rather than to the
  /// catalogue: their cart, their cashback offers, their favourites, and the
  /// store filters they had applied.
  ///
  /// Called by the module-change path, not by [_setModule]. It used to live
  /// inside the setter, which meant a tap handler asking "what module am I in"
  /// fired three network requests as a side effect — on the dashboard, the
  /// screen the whole performance effort is aimed at. Places has no cart, no
  /// cashback and no favourites, so it skips the lot.
  void _refreshModuleScopedUserData(ModuleModel module) {
    if (module.type == ModuleType.places) return;
    if (AuthHelper.isLoggedIn() || AuthHelper.isGuestLoggedIn()) {
      // Guests have a server-side cart too, keyed by guest_id.
      Get.find<CartController>().getCartDataOnline();
      Get.find<StoreController>().clearModuleStoreFilters();
    }
    if (AuthHelper.isLoggedIn()) {
      Get.find<HomeController>().getCashBackOfferList();
      Get.find<FavouriteController>().getFavouriteList();
    }
  }

  /// Per-module feature flags: add-ons, stock, veg/non-veg, attachments…
  ///
  /// Memoised, because this is read 43 times and most of those are inside
  /// `build` — the order widgets call it once per row. It used to run a full
  /// `Module.fromJson` on every one of them, so a 20-row order list parsed the
  /// same map 20 times per frame to produce 20 identical objects.
  ///
  /// The cache is cleared whenever the config payload is replaced (see
  /// [_moduleConfigCache]); nothing mutates the returned object, so one
  /// instance per module type is safe to share.
  final Map<String, Module> _moduleConfigCache = <String, Module>{};

  Module getModuleConfig(String? moduleType) {
    final String key = moduleType ?? '';
    final Module? cached = _moduleConfigCache[key];
    if (cached != null) return cached;

    final Module config = _parseModuleConfig(moduleType);
    // Not cached when the payload has not arrived: the miss is what makes the
    // real config get parsed once config data lands, instead of this default
    // being pinned for the session.
    if (_data?['module_config']?[moduleType] != null) {
      _moduleConfigCache[key] = config;
    }
    return config;
  }

  /// The flags `Module.fromJson` expects the payload to carry.
  ///
  /// `new_variation` is deliberately absent: the client decides that one (food
  /// only), so the backend omitting it is not a gap.
  static const List<String> _expectedConfigFlags = <String>[
    'add_on',
    'stock',
    'veg_non_veg',
    'unit',
    'order_attachment',
    'show_restaurant_text',
    'is_parcel',
    'order_place_to_schedule_interval',
  ];

  @visibleForTesting
  static List<String> get expectedConfigFlagsForTest => _expectedConfigFlags;

  /// Seeds the module config payload the way a 200 from `/config` would.
  ///
  /// Pricing is decided by one flag — `newVariation`, which [_parseModuleConfig]
  /// derives from the module *type* rather than the payload — but every path
  /// that reads it goes through [getModuleConfig], which answers "everything
  /// off" until `module_config` exists. Tests of the checkout arithmetic need
  /// that entry present and nothing else from the config payload, and the
  /// alternative is booting an ApiClient and a repository to assert a
  /// multiplication. Clears the parse cache for the same reason the real
  /// response handler does.
  @visibleForTesting
  void setModuleConfigForTest(Map<String, dynamic> moduleConfig) {
    _data = <String, dynamic>{...?_data, 'module_config': moduleConfig};
    _moduleConfigCache.clear();
  }

  /// Seeds [configModel] without a network round trip.
  ///
  /// `CheckoutCalculationHelper`'s methods are described as pure functions over
  /// a cart, but several of them reach for this through `Get.find` —
  /// `PriceConverter.toFixed` needs `digitAfterDecimalPoint` and
  /// `calculateTotal` needs `dmTipsStatus` — and throw on a null check when it
  /// is absent. Testing the arithmetic therefore requires it to exist.
  @visibleForTesting
  void setConfigModelForTest(ConfigModel config) {
    _configModel = config;
  }

  /// Sets the current module without `_setModule`'s side effects.
  ///
  /// `_setModule` fetches the cart, cashback and favourites for the module it
  /// switches to, which a pricing test neither needs nor can serve. Delivery
  /// charges are looked up by `module!.id` against the address's zone data, so
  /// the field has to be set somehow; this sets only the field.
  @visibleForTesting
  void setModuleForTest(ModuleModel? module) {
    _module = module;
  }

  /// Module types already reported this session, so a gap is one event rather
  /// than one per `build`. `getModuleConfig` is read 43 times and the absent
  /// case is deliberately not memoised, so without this an order list would
  /// report the same gap once per row per frame.
  final Set<String> _reportedConfigGaps = <String>{};

  /// Says out loud that a module's feature flags are missing.
  ///
  /// Defaulting the flags to false (see `Module.fromJson`) traded a loud
  /// failure for a quiet one: a partial config used to throw inside `build`
  /// the first time anyone opened the screen, which is a stack trace in
  /// Crashlytics on day one. Now it renders the feature as *off*, which is
  /// indistinguishable from a module that genuinely has it off — so a backend
  /// that forgets `is_parcel` on a new module doesn't crash, it quietly serves
  /// the wrong home body until a customer writes in.
  ///
  /// The defaults stay: crashing a delivery app inside `build` over a missing
  /// boolean is the worse end of that trade. This is the part that was missing
  /// — the gap is still an event, it is just no longer an outage.
  void _reportConfigGap(String moduleType, String reason, String detail) {
    if (!_reportedConfigGaps.add('$moduleType/$reason')) return;
    debugPrint('module config gap [$reason] for "$moduleType": $detail');
    AnalyticsHelper.log('module_config_gap', <String, Object>{
      'module_type': moduleType,
      'reason': reason,
      'detail': detail,
    });
  }

  Module _parseModuleConfig(String? moduleType) {
    final String typeKey = moduleType ?? 'none';
    final dynamic raw = _data?['module_config']?[moduleType];

    if (raw == null) {
      // Already the behaviour before the flags gained defaults — an absent
      // config has always answered "everything off" rather than throwing. It
      // was silent then too; now at least it says so.
      //
      // Not reported before the config payload has arrived at all: that is
      // startup, not a gap.
      if (_data != null && _data!['module_config'] != null) {
        _reportConfigGap(typeKey, 'absent', 'no module_config entry');
      }
      // Every flag off. Not null, and not a throw: 43 call sites dereference
      // these with `!` from inside build().
      return Module(
        addOn: false,
        stock: false,
        vegNonVeg: false,
        unit: false,
        orderAttachment: false,
        showRestaurantText: false,
        isParcel: false,
        newVariation: false,
        orderPlaceToScheduleInterval: false,
      );
    }

    if (raw is Map) {
      final List<String> missing = <String>[
        for (final String flag in _expectedConfigFlags)
          if (raw[flag] == null) flag,
      ];
      if (missing.isNotEmpty) {
        _reportConfigGap(typeKey, 'partial', missing.join(','));
      }
    }

    final Module module = Module.fromJson(_data!['module_config'][moduleType]);
    // Food is the only module on the new variation UI, and the backend does
    // not say so — the client decides. Kept as an override of the parsed value
    // rather than a special case at the call sites.
    module.newVariation = ModuleType.of(moduleType) == ModuleType.food;
    return module;
  }

  /// The module tiles — the grid at the top of the dashboard.
  ///
  /// This is the largest payload on home (~10 KB, measured at 741 ms on a Mi
  /// 9T) and it used to be fetched unconditionally on every single load: the
  /// local branch painted the cached list and then fired the network call
  /// anyway, ignoring how old the cache actually was. Home's initState runs on
  /// every remount — tab hops, module resume, the PageView rebuilding — so
  /// leaving and re-entering the dashboard three times re-downloaded the same
  /// ten kilobytes three times, rebuilt the grid three times, and re-created
  /// every module tile's image widget with it.
  ///
  /// Staleness is the trigger now, exactly as it already is for the store and
  /// category lists. The cached row is keyed by zone (see [moduleCacheId]), so
  /// a customer who changes address reads a different key, finds it stale, and
  /// goes to the network — the one case where the old unconditional re-fetch
  /// was doing something necessary.
  /// Coalesces concurrent module fetches.
  ///
  /// Home fires `getModules()` twice on a cold load: once unconditionally, and
  /// once from the quick-delivery rail behind a `moduleList == null` guard.
  /// Both run inside the same `Future.wait`, so the guard loses the race — the
  /// second call starts before the first has assigned anything, and
  /// `/api/v1/module` goes out twice for 20.8 KB.
  ///
  /// Same shape as `CartController.getCartDataOnline`: a second caller arriving
  /// while a fetch is in flight joins it rather than starting another.
  Future<void>? _modulesFetchInFlight;

  Future<void> getModules({
    Map<String, String>? headers,
    DataSourceEnum dataSource = DataSourceEnum.local,
  }) {
    final Future<void>? inFlight = _modulesFetchInFlight;
    if (inFlight != null) return inFlight;

    late final Future<void> fetch;
    fetch = _getModules(headers: headers, dataSource: dataSource)
        .whenComplete(() {
      if (identical(_modulesFetchInFlight, fetch)) {
        _modulesFetchInFlight = null;
      }
    });
    _modulesFetchInFlight = fetch;
    return fetch;
  }

  Future<void> _getModules({
    Map<String, String>? headers,
    DataSourceEnum dataSource = DataSourceEnum.local,
  }) async {
    _moduleIndex = 0;
    final String ttlKey = moduleCacheId();
    if (dataSource == DataSourceEnum.local && CacheTtlHelper.isStale(ttlKey)) {
      dataSource = DataSourceEnum.client;
    }
    List<ModuleModel>? moduleList;
    if (dataSource == DataSourceEnum.local) {
      moduleList = await splashServiceInterface.getModules(
        headers: headers,
        source: DataSourceEnum.local,
      );
      // A fresh stamp is not proof the row is there — the cache write is fire
      // and forget and the store can be cleared under us. An empty local read
      // has to fall through to the network or the module grid shimmers
      // forever with a stamp saying everything is fine.
      if (moduleList == null) {
        return getModules(headers: headers, dataSource: DataSourceEnum.client);
      }
      _prepareModuleList(moduleList);
    } else {
      moduleList = await splashServiceInterface.getModules(
        headers: headers,
        source: DataSourceEnum.client,
      );
      _prepareModuleList(moduleList);
      if (moduleList != null) {
        CacheTtlHelper.markFresh(ttlKey);
      }
    }
  }

  _prepareModuleList(List<ModuleModel>? moduleList) {
    if (moduleList != null) {
      _moduleList = [];
      for (var module in moduleList) {
        if (module.moduleType != 'rental') {
          _moduleList!.add(module);
        }
      }
      // Single-module config: auto-select it here — on every getModules()
      // (initial load, zone change, drawer) — instead of as a side effect of
      // HomeScreen.build. switchModule no-ops when it is already active.
      if (_moduleList!.length == 1) {
        switchModule(0);
      }
    }
    update();
  }

  Future<void> _showInterestPage() async {
    final userInfoModel = Get.find<ProfileController>().userInfoModel;
    final module = Get.find<SplashController>().module;

    if (userInfoModel == null ||
        module == null ||
        userInfoModel.selectedModuleForInterest == null) {
      return;
    }

    if (!userInfoModel.selectedModuleForInterest!.contains(module.id)) {
      await Get.find<CategoryController>()
          .getCategoryList(true, allCategory: false)
          .then((_) async {
            if (Get.find<CategoryController>().categoryList != null &&
                Get.find<CategoryController>().categoryList!.isNotEmpty) {
              await Get.toNamed(RouteHelper.getInterestRoute());
            } else {
              Get.offAllNamed(RouteHelper.getInitialRoute());
            }
          });
    }
  }

  /// The module the user was in before the last `_setModule(null)`.
  ///
  /// Only meaningful while `_module` is null; [switchModule] uses it to tell a
  /// genuine module change from a return to the one just left.
  int? _lastActiveModuleId;

  /// Enter a module because the user is going to its home screen now — the
  /// module tiles on the dashboard.
  void switchModule(int index) async {
    await enterModule(_moduleList![index]);
  }

  /// Enter [module] and show its home.
  ///
  /// One of exactly two doors into a module (see [activateModuleFor] for the
  /// other), and the only place that decides what a module change costs.
  Future<void> enterModule(ModuleModel module) =>
      _changeModule(module, openingModuleHome: true);

  /// Enter the module that owns something the user just tapped — a store card,
  /// an item, a banner — when the destination is that thing, not the module's
  /// home.
  ///
  /// This is the door 24 widget tap handlers used to reach by calling
  /// `setModule` directly, which changed the module without clearing anything:
  /// the new module's screens then rendered the previous module's categories,
  /// banners, items and campaigns until something happened to refetch them.
  /// Silently does nothing when the module list has not arrived yet (cold
  /// start, offline) — same as the loops it replaces, but in one place where
  /// it can be fixed once.
  Future<void> activateModuleFor(int? moduleId) async {
    final ModuleModel? module = moduleById(moduleId);
    if (module == null) return;
    await _changeModule(module, openingModuleHome: false);
  }

  /// The module with this id, or null when the list has not arrived yet (cold
  /// start, offline) or the id belongs to a module this zone is not served.
  ModuleModel? moduleById(int? moduleId) {
    if (moduleId == null || _moduleList == null) return null;
    for (final ModuleModel module in _moduleList!) {
      if (module.id == moduleId) return module;
    }
    return null;
  }

  /// Leave the module and return to the aggregated dashboard.
  ///
  /// [refreshDashboard] refetches what the dashboard shows. Off by default
  /// because the common way out — the home hero's back button, the Home tab —
  /// swaps the module body for `ModuleView` inside the *same* HomeScreen,
  /// whose controllers are still holding everything that view renders; firing
  /// a burst of requests on every back press would be pure cost. On by choice
  /// for the ways out that leave a screen the dashboard was never behind
  /// (the parcel flow), where there is nothing warm to fall back on.
  void leaveModule({bool refreshDashboard = false}) {
    _setModule(null);
    if (!refreshDashboard) return;
    Get.find<BannerController>().getFeaturedBanner();
    getModules();
    Get.find<HomeController>().forcefullyNullCashBackOffers();
    if (AuthHelper.isLoggedIn()) {
      Get.find<AddressController>().getAddressList();
    }
    Get.find<StoreController>().getFeaturedStoreList();
    Get.find<CampaignController>().itemAndBasicCampaignNull();
  }

  /// The single definition of "the module changed".
  ///
  /// [openingModuleHome] is the difference between the two doors, and it is
  /// only about *when* home reloads, never about whether the caches are
  /// cleared — clearing them is unconditional, because a module's screens must
  /// never be able to render another module's catalogue.
  ///
  /// Teardown and reload have to stay coupled: home's `loadData` throttles
  /// itself for two minutes, so clearing the caches without also arranging a
  /// real load leaves the module home rendering nothing at all. When the user
  /// is heading for the module home we load now; when they are heading into a
  /// store we only invalidate the throttle, so the load happens if and when
  /// they actually arrive rather than racing the screen they asked for.
  Future<void> _changeModule(
    ModuleModel module, {
    required bool openingModuleHome,
  }) async {
    // Already in it — a store tap inside the module the user is already
    // browsing must not tear down that module's caches, and must not re-run
    // the setter either: that writes both prefs and re-requests the cart, the
    // cashback list and the favourites, which is three network calls to arrive
    // at the state the app is already in.
    if (_module != null && _module!.id == module.id) return;

    // Returning to the module they just backed out of.
    //
    // The home hero's back button calls _setModule(null) so the picker can
    // render, which meant `_module == null` on the way back in and every
    // return took the full-switch path below: tear down the item, banner,
    // category and campaign caches, then reload ~20 endpoints with
    // reload: true — which also forces every controller to DataSourceEnum
    // .client and bypasses home's 2-minute quiet window via fromModule: true.
    // Leaving food and stepping straight back in re-fetched the entire screen
    // the user had been looking at a second earlier.
    //
    // Nothing about that data went stale in the meantime, and the controllers
    // still hold it, so restore the module and let loadData's own throttle
    // decide whether anything actually needs refreshing.
    final bool isResume = _module == null && _lastActiveModuleId == module.id;

    // Before the first await, deliberately.
    //
    // Callers do not await this — they change module and navigate on the next
    // line — so everything that decides what the destination screen reads has
    // to happen in the same synchronous turn as the call. The module id and
    // the API header already did (`_setModule` updates the header before its
    // own first await); dropping the outgoing module's catalogue here puts the
    // caches on the same footing. Anything left until after the await is a
    // frame in which the new module's screen can build against the old
    // module's lists, which is the whole bug this path exists to close.
    if (!isResume) _clearModuleScopedCaches();

    await _setModule(module);
    _refreshModuleScopedUserData(module);

    if (isResume) {
      // Home is not remounted on this path — the same HomeScreen simply swaps
      // ModuleView back out for the module body — so its initState will not
      // fire. Call loadData explicitly and let the quiet window throttle it.
      if (openingModuleHome) HomeScreen.loadData(false);
      return;
    }

    // No getCartDataOnline() here: _setModule already refreshed the cart for
    // this module, and calling it again made every switch request the cart
    // twice. Same reasoning as the cashback list.
    if (AuthHelper.isLoggedIn()) {
      await _showInterestPage();
    }

    if (openingModuleHome) {
      HomeScreen.loadData(true, fromModule: true);
    } else {
      HomeScreen.invalidateLoadThrottle();
    }
  }

  /// Everything that belongs to the module being left.
  ///
  /// These lists are all module-scoped and none of them carry their module's
  /// id, so there is no way to tell, later, that they are the wrong module's.
  /// Dropping them is the only thing that makes "which module am I in" a
  /// question with one answer.
  void _clearModuleScopedCaches() {
    Get.find<ItemController>().clearItemLists();
    Get.find<BannerController>().clearBanner();
    Get.find<CategoryController>().clearCategoryList();
    Get.find<CampaignController>().itemAndBasicCampaignNull();
    Get.find<FlashSaleController>().setEmptyFlashSale(fromModule: true);
  }

  int getCacheModule() {
    return splashServiceInterface.getCacheModule()?.id ?? 0;
  }

  void setModuleIndex(int index) {
    _moduleIndex = index;
    update();
  }

  Future<void> removeCacheModule() async {
    _cacheModule = await splashServiceInterface.setCacheModule(null);
  }

  Future<bool> subscribeMail(String email) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await splashServiceInterface.subscribeEmail(
      email,
    );
    if (responseModel.isSuccess) {
      showCustomSnackBar(responseModel.message, isError: false);
    } else {
      showCustomSnackBar(responseModel.message, isError: true);
    }
    _isLoading = false;
    update();
    return responseModel.isSuccess;
  }

  void saveWebSuggestedLocationStatus(bool data) {
    splashServiceInterface.saveSuggestedLocationStatus(data);
    _webSuggestedLocation = true;
    update();
  }

  void getWebSuggestedLocationStatus() {
    _webSuggestedLocation = splashServiceInterface.getSuggestedLocationStatus();
  }

  void setRefreshing(bool status) {
    _isRefreshing = status;
    update();
  }

  void saveReferBottomSheetStatus(bool data) {
    splashServiceInterface.saveReferBottomSheetStatus(data);
    _showReferBottomSheet = data;
    update();
  }

  void getReferBottomSheetStatus() {
    _showReferBottomSheet = splashServiceInterface.getReferBottomSheetStatus();
  }

  void saveWelcomeLetterShownStatus(bool data) {
    splashServiceInterface.saveWelcomeLetterShownStatus(data);
    _welcomeLetterShown = data;
    update();
  }

  void getWelcomeLetterShownStatus() {
    _welcomeLetterShown = splashServiceInterface.getWelcomeLetterShownStatus();
  }

  var hoverStates = <bool>[];

  void setHover(int index, bool state) {
    hoverStates[index] = state;
    update();
  }
}
