import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/store/widgets/store_page_shimmer.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/domain/services/store_service_interface.dart';
import 'package:waddy_app/features/pets/screens/pet_store_screen.dart';
import 'package:waddy_app/features/store/screens/food_store_screen.dart';
import 'package:waddy_app/features/store/screens/specialty_store_screen.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';
import 'package:waddy_app/features/store/widgets/store_details_screen_shimmer_widget.dart';
import 'package:waddy_app/helper/module_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';

/// Which store page a store gets (ST-04, D1/D2 decided 09-30).
///
/// - **menu**: `FoodStoreScreen` — restaurants, and the stores of every other
///   non-grocery module.
/// - **specialty**: `SpecialtyStoreScreen` — grocery stores that are not
///   supermarkets (butcher, greengrocer, dairy, bakery…).
/// - **aisles**: `StoreScreen` — supermarkets only.
/// - **pets**: `PetStoreScreen` — every store of the Pets module, which is
///   a grocery-typed module the app tells apart by its variant (PET-01).
enum StoreLayout {
  menu,
  specialty,
  aisles,
  pets;

  /// [store]'s module type: its own module when the payload names it, else
  /// the module the app is in (`StoreNavigator.open` switches to the store's
  /// module before the page is built).
  static ModuleType? _typeOf(Store store) {
    final SplashController splash = Get.find<SplashController>();
    return splash.moduleById(store.moduleId)?.type ?? splash.module?.type;
  }

  /// The layout [store]'s own payload settles, or null when it cannot:
  /// `is_supermarket` is set by the backend's store formatter on every store
  /// list, but a store known only by id (an item's store link, XP, a deep
  /// link, an ad) does not carry it.
  static StoreLayout? of(Store store) {
    final ModuleType? type = _typeOf(store);
    // Decided by the module, not the payload: a pet shop's `is_supermarket`
    // is false like any specialty shop's.
    if (type == ModuleType.pets) return pets;
    final bool? supermarket = store.isSupermarket;
    if (supermarket == null) return null;
    if (supermarket) return aisles;
    return type == ModuleType.grocery ? specialty : menu;
  }

  /// For a store whose payload still does not say — an older backend, or a
  /// details fetch that failed: supermarkets are the grocery module's default
  /// shape, anything else reads as a menu.
  static StoreLayout fallback(Store store) {
    final ModuleType? type = _typeOf(store);
    if (type == ModuleType.pets) return pets;
    return type == ModuleType.grocery ? aisles : menu;
  }
}

/// The only way into a store page (ST-04, ST-05).
///
/// Twenty-nine call sites used to decide this each on their own, with four
/// different rules: a restaurant opened from search, "Order again", a store
/// card, a banner, XP or a deep link got the supermarket aisle page, and six
/// of them opened the store without switching to its module.
class StoreNavigator {
  StoreNavigator._();

  /// Switches to [store]'s module, then opens its page. [page] is only the
  /// route's `page=` label (where the tap came from); it changes nothing.
  /// [replace] swaps the current route instead of pushing on top of it.
  static Future<dynamic>? open(
    Store store, {
    String page = 'store',
    bool replace = false,
  }) {
    if (store.moduleId != null) {
      Get.find<SplashController>().activateModuleFor(store.moduleId);
    }
    final String route = RouteHelper.getStoreRoute(id: store.id, page: page);
    final StoreRouteShell shell = StoreRouteShell(store: store);
    return replace
        ? Get.offNamed(route, arguments: shell)
        : Get.toNamed(route, arguments: shell);
  }
}

/// What the store route renders: the right page for the store, deciding it
/// before either page is built.
///
/// When the store in hand settles the layout ([StoreLayout.of]) the page is
/// built immediately. Otherwise the store is fetched first — through the
/// shared cache, with the same freshness the page itself asks for, so the page
/// then gets it without a second request — and its module is switched to.
///
/// This replaces `StoreScreen` building itself, fetching, and then returning a
/// `FoodStoreScreen` from `build` for specialty grocery stores (ST-06): two
/// set-ups for one page, and a latch to survive the blank in between.
class StoreRouteShell extends StatefulWidget {
  final Store store;
  final String slug;
  const StoreRouteShell({super.key, required this.store, this.slug = ''});

  @override
  State<StoreRouteShell> createState() => _StoreRouteShellState();
}

class _StoreRouteShellState extends State<StoreRouteShell> {
  StoreLayout? _layout;

  /// Matches the store page's own tolerance, so its fetch is a cache hit.
  static const Duration _maxAge = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _layout = widget.slug.isEmpty ? StoreLayout.of(widget.store) : null;
    if (_layout == null) _resolve();
  }

  Future<void> _resolve() async {
    final StoreServiceInterface storeServiceInterface =
        Get.find<StoreServiceInterface>();
    final String languageCode =
        Get.find<LocalizationController>().locale.languageCode;
    Store? fetched;
    if (widget.slug.isNotEmpty) {
      // A shared link names the store by slug, which the cache is not keyed
      // on. The page repeats this fetch — it is also what moves the user's
      // saved address to the store's — so a slug open costs one extra
      // request, on a rare path.
      fetched = await storeServiceInterface.getStoreDetails(
        '',
        false,
        widget.slug,
        languageCode,
        ModuleHelper.currentModuleId(),
      );
    } else if (widget.store.id != null) {
      fetched = await storeServiceInterface.getCachedStoreDetails(
        widget.store.id!,
        languageCode: languageCode,
        moduleId: widget.store.moduleId ?? ModuleHelper.currentModuleId(),
        maxAge: _maxAge,
      );
    }
    if (!mounted) return;
    final Store store = fetched ?? widget.store;
    // Reached without StoreNavigator (a deep link, a bare named route): the
    // module was never switched. A no-op when it already is.
    if (store.moduleId != null) {
      Get.find<SplashController>().activateModuleFor(store.moduleId);
    }
    setState(() {
      _layout = StoreLayout.of(store) ?? StoreLayout.fallback(store);
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_layout) {
      case null:
        // The page is still being decided; draw the one the list's payload
        // points to, so the shimmer is the right shape in most cases.
        return Scaffold(
          body: switch (StoreLayout.of(widget.store) ??
              StoreLayout.fallback(widget.store)) {
            StoreLayout.aisles => StorePageShimmer(store: widget.store),
            StoreLayout.specialty || StoreLayout.pets => StorePageShimmer(
              layout: StorePageShimmerLayout.specialty,
              store: widget.store,
            ),
            StoreLayout.menu => const StoreDetailsScreenShimmerWidget(),
          },
        );
      case StoreLayout.menu:
        return FoodStoreScreen(store: widget.store, slug: widget.slug);
      case StoreLayout.specialty:
        return SpecialtyStoreScreen(store: widget.store, slug: widget.slug);
      case StoreLayout.aisles:
        return StoreScreen(store: widget.store, slug: widget.slug);
      case StoreLayout.pets:
        return PetStoreScreen(store: widget.store, slug: widget.slug);
    }
  }
}
