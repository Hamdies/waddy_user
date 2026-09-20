import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/auth/domain/services/auth_service_interface.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/category/domain/services/category_service_interface.dart';
import 'package:waddy_app/features/banner/controllers/banner_controller.dart';
import 'package:waddy_app/features/banner/domain/services/banner_service_interface.dart';
import 'package:waddy_app/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:waddy_app/features/flash_sale/domain/services/flash_sale_service_interface.dart';
import 'package:waddy_app/features/item/controllers/campaign_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/services/campaign_service_interface.dart';
import 'package:waddy_app/features/item/domain/services/item_service_interface.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/splash/domain/repositories/splash_repository.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service.dart';
import 'package:waddy_app/util/app_constants.dart';

/// The module is the app's most load-bearing piece of state: it decides what
/// the API returns, which home screen renders, and which catalogue the user is
/// looking at. Nothing asserted anything about it until this file — which is
/// precisely why M-01 survived for as long as it did.
///
/// See `docs/module_architecture_plan.md`. These pin the two halves of the
/// contract that the rest of the app assumes and that nothing enforced:
///
///   * the client asks the server for the module it thinks it is in, and for
///     NO module when it is on the aggregated dashboard;
///   * changing module leaves none of the previous module's catalogue behind.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ModuleModel moduleOf(int id, String type) =>
      ModuleModel(id: id, moduleName: type, moduleType: type);

  late ApiClient apiClient;
  late SplashRepository repository;
  late SplashController controller;

  Future<void> boot({
    Map<String, Object> prefs = const <String, Object>{},
  }) async {
    Get.reset();
    SharedPreferences.setMockInitialValues(prefs);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    Get.put<SharedPreferences>(preferences);
    apiClient = ApiClient(
      appBaseUrl: AppConstants.baseUrl,
      sharedPreferences: preferences,
    );
    Get.put<ApiClient>(apiClient);
    // Signed out, so setModule's cart/cashback/favourite side effects stay out
    // of these tests — they are module *state* tests, and that those side
    // effects live in a setter at all is M-04.
    Get.put<AuthController>(
      AuthController(authServiceInterface: _LoggedOutAuthService()),
    );
    repository = SplashRepository(
      apiClient: apiClient,
      sharedPreferences: preferences,
    );
    controller = SplashController(
      splashServiceInterface: _CannedModuleList(
        SplashService(splashRepositoryInterface: repository),
        <ModuleModel>[
          moduleOf(1, AppConstants.grocery),
          moduleOf(2, AppConstants.food),
        ],
      ),
    );
    Get.put<SplashController>(controller);

    // The five controllers whose lists belong to the module being left. The
    // module-change path clears all of them, so all of them have to exist.
    Get.put<CategoryController>(
      CategoryController(categoryServiceInterface: _FakeCategoryService()),
    );
    Get.put<ItemController>(
      ItemController(itemServiceInterface: _StubItemService()),
    );
    Get.put<BannerController>(
      BannerController(bannerServiceInterface: _StubBannerService()),
    );
    Get.put<CampaignController>(
      CampaignController(campaignServiceInterface: _StubCampaignService()),
    );
    Get.put<FlashSaleController>(
      FlashSaleController(flashSaleServiceInterface: _StubFlashSaleService()),
    );

    // `activateModuleFor` resolves an id against this list, the way a store
    // card does; without it every activation is a silent no-op.
    await controller.getModules();
  }

  tearDown(Get.reset);

  group('the module id the client sends', () {
    test('entering a module names it in the header', () async {
      await boot();

      await controller.activateModuleFor(2);

      expect(apiClient.getHeader()[AppConstants.moduleId], '2');
    });

    test('switching modules replaces it rather than keeping both', () async {
      await boot();

      await controller.activateModuleFor(2);
      await controller.activateModuleFor(1);

      expect(apiClient.getHeader()[AppConstants.moduleId], '1');
    });

    // M-01. The dashboard is module-less by definition — it shows every
    // module's stores at once — so a request made from it must not claim to be
    // inside the module the user last opened. Today `cacheModuleId` is written
    // on entry and never cleared, and ApiClient.updateHeader resurrects it
    // whenever the caller passes no module, so leaving a module changes
    // nothing about what the client asks for.
    test('leaving a module stops sending one', () async {
      await boot();

      await controller.activateModuleFor(2);
      controller.leaveModule();

      expect(
        apiClient.getHeader().containsKey(AppConstants.moduleId),
        isFalse,
        reason: 'the dashboard must not ask the server for a module',
      );
    });

    // The same thing one launch later: a returning customer lands on the
    // dashboard (`_module` is null until they pick a tile), so the header they
    // start the session with must be module-less too.
    test('a cold start on the dashboard sends no module', () async {
      await boot(
        prefs: <String, Object>{
          AppConstants.cacheModuleId: jsonEncode(
            moduleOf(2, AppConstants.food).toJson(),
          ),
        },
      );

      await controller.initSharedData();

      expect(
        apiClient.getHeader().containsKey(AppConstants.moduleId),
        isFalse,
        reason: 'nothing has selected a module yet this session',
      );
    });
  });

  group('what is persisted', () {
    // M-03. There used to be two prefs for one fact. `moduleId` was written on
    // every module change and read by nobody — both loaders threw the value
    // away — so it was pure drift surface: a second copy that could disagree
    // with the first and that no code path could correct.
    test('only one copy of the module is persisted', () async {
      await boot();

      await controller.activateModuleFor(2);

      final SharedPreferences prefs = Get.find<SharedPreferences>();
      expect(prefs.containsKey(AppConstants.cacheModuleId), isTrue);
      expect(
        prefs.containsKey(AppConstants.moduleId),
        isFalse,
        reason: 'the active module lives in memory, not in a second pref',
      );
    });

    // The deliberate asymmetry, and the correction to this plan's first draft:
    // `cacheModule` is NOT the active module. It is "the last module in play",
    // and ~20 screens opened from the module-less dashboard read it as the
    // module of the thing they are showing — the cart's id, the item sheet's
    // config, store details. Clearing it on leave would break all of them.
    test(
      'the last module outlives leaving it, but the active one does not',
      () async {
        await boot();
        await controller.activateModuleFor(2);

        controller.leaveModule();

        expect(
          controller.module,
          isNull,
          reason: 'the user is on the dashboard',
        );
        expect(
          controller.cacheModule?.id,
          2,
          reason: 'but food is still the module their cart belongs to',
        );
      },
    );
  });

  group('what a module change clears', () {
    // Both doors (tiles and tap handlers) share `_changeModule`; these drive it
    // through `activateModuleFor` because the other one also kicks off a home
    // load, and a unit test has no home screen for that to land on. What is
    // asserted here — that a module change invalidates the previous module's
    // catalogue — is the shared half.
    Future<void> loadFoodCategories() async {
      await Get.find<CategoryController>().getCategoryList(true);
      expect(
        Get.find<CategoryController>().categoryList,
        isNotEmpty,
        reason: 'precondition: a catalogue is loaded for the module we leave',
      );
    }

    // M-02, the door the module tiles use.
    test('changing module drops the previous module\'s categories', () async {
      await boot();
      await controller.activateModuleFor(2);
      await loadFoodCategories();

      await controller.activateModuleFor(1);

      expect(
        Get.find<CategoryController>().categoryList,
        anyOf(isNull, isEmpty),
        reason: 'grocery must not render food categories',
      );
    });

    // M-02, the door the 24 tap handlers use — the one that cleared nothing.
    // Tapping a grocery store from the dashboard is a module change even
    // though the destination is a store screen, and the grocery home reached
    // afterwards must not still be holding food's catalogue.
    test(
      'opening a store in another module drops that module\'s categories',
      () async {
        await boot();
        await controller.activateModuleFor(2);
        await loadFoodCategories();

        await controller.activateModuleFor(1);

        expect(controller.module?.id, 1);
        expect(
          Get.find<CategoryController>().categoryList,
          anyOf(isNull, isEmpty),
          reason: 'the store tap changed module, so the catalogue is stale',
        );
      },
    );

    // The other half of the contract, and the reason this cannot simply clear
    // on every tap: browsing inside one module must not keep throwing that
    // module's own catalogue away.
    test(
      'opening a store in the module already active clears nothing',
      () async {
        await boot();
        await controller.activateModuleFor(2);
        await loadFoodCategories();

        await controller.activateModuleFor(2);

        expect(
          Get.find<CategoryController>().categoryList,
          isNotEmpty,
          reason: 'same module — nothing went stale',
        );
      },
    );

    test('an unknown module id changes nothing', () async {
      await boot();
      await controller.activateModuleFor(2);

      await controller.activateModuleFor(99);

      expect(controller.module?.id, 2);
    });
  });

  group('module type', () {
    // M-07. 41 hand-written string comparisons, 26 of them calling
    // `.toString()` on a field already declared `String?`. Parsing once at the
    // model boundary is only safe if it is total: an unknown or missing type
    // must land somewhere that matches no branch, rather than defaulting into
    // one and silently rendering the wrong module's screen.
    test('parses the wire strings, whatever their casing', () {
      expect(ModuleType.of('food'), ModuleType.food);
      expect(ModuleType.of('Grocery'), ModuleType.grocery);
      expect(ModuleType.of(' pharmacy '), ModuleType.pharmacy);
      expect(ModuleType.of('ecommerce'), ModuleType.ecommerce);
      expect(ModuleType.of('parcel'), ModuleType.parcel);
      expect(ModuleType.of('places'), ModuleType.places);
    });

    test('an unknown or missing type matches no module', () {
      for (final String? value in <String?>[null, '', 'rental', 'taxi']) {
        expect(
          ModuleType.of(value),
          ModuleType.unknown,
          reason: '"$value" must not resolve to a real module',
        );
      }
    });

    test('every module type round-trips through its wire string', () {
      for (final ModuleType type in ModuleType.values) {
        if (type == ModuleType.unknown) continue;
        expect(ModuleType.of(type.wire), type);
      }
    });
  });

  group('module config', () {
    // 43 call sites read this, most of them inside build(), and every one of
    // them dereferences the result with `!`. A module the backend has not
    // configured must therefore come back as a complete object, not null and
    // not a throw.
    test(
      'an unconfigured module returns defaults instead of throwing',
      () async {
        await boot();

        expect(
          () => controller.getModuleConfig(AppConstants.food),
          returnsNormally,
        );
        expect(controller.getModuleConfig(AppConstants.food).addOn, isFalse);
        expect(controller.getModuleConfig('not_a_module').isParcel, isFalse);
      },
    );

    // The flags default to false so a partial payload cannot throw inside
    // build(). That turns a loud failure into a quiet one, so every field the
    // payload is supposed to carry has to be listed here — a flag added to
    // Module.fromJson without being added to _expectedConfigFlags is a gap
    // that would go unreported.
    test('every parsed flag is one the gap check knows to look for', () {
      const List<String> parsed = <String>[
        'add_on',
        'stock',
        'veg_non_veg',
        'unit',
        'order_attachment',
        'show_restaurant_text',
        'is_parcel',
        'order_place_to_schedule_interval',
      ];
      expect(
        SplashController.expectedConfigFlagsForTest,
        parsed,
        reason: 'new_variation is excluded on purpose: the client sets it',
      );
    });
  });
}

/// Wraps the real splash service so the header/prefs behaviour under test
/// stays real, and only hands back a canned module list — which is otherwise a
/// network call, and which `activateModuleFor` needs in order to resolve an id.
class _CannedModuleList implements SplashServiceInterface {
  _CannedModuleList(this._inner, this._modules);

  final SplashServiceInterface _inner;
  final List<ModuleModel> _modules;

  @override
  Future<List<ModuleModel>?> getModules({
    Map<String, String>? headers,
    required DataSourceEnum source,
  }) async => _modules;

  @override
  Future<void> initSharedData() => _inner.initSharedData();

  @override
  void updateModuleHeader(ModuleModel? module) =>
      _inner.updateModuleHeader(module);

  @override
  Future<ModuleModel?> setCacheModule(ModuleModel? module) =>
      _inner.setCacheModule(module);

  @override
  ModuleModel? getCacheModule() => _inner.getCacheModule();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Stand-ins for the services behind the controllers whose only role in these
/// tests is to be cleared. Nothing calls them; they exist so the controllers
/// can be constructed.
class _StubItemService implements ItemServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubBannerService implements BannerServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubCampaignService implements CampaignServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubFlashSaleService implements FlashSaleServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A signed-out session. Everything else returns null; if a test ever reaches
/// one of those it should say so loudly rather than pretend.
class _LoggedOutAuthService implements AuthServiceInterface {
  @override
  bool isSharedPrefNotificationActive() => false;

  @override
  bool isLoggedIn() => false;

  @override
  bool isGuestLoggedIn() => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Returns one category for any list request and null for everything else —
/// enough to give the controller a catalogue to hold, which is all these tests
/// need it for.
class _FakeCategoryService implements CategoryServiceInterface {
  @override
  Future<List<CategoryModel>?> getCategoryList(
    bool allCategory, {
    dynamic source,
  }) async => <CategoryModel>[CategoryModel(id: 1, name: 'Pasta')];

  @override
  Future<List<CategoryModel>?> getModuleCategoryList(int moduleId) async =>
      <CategoryModel>[CategoryModel(id: 1, name: 'Pasta')];

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.value();
}
