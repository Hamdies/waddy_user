import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/cart/domain/repositories/cart_repository_interface.dart';
import 'package:waddy_app/features/cart/domain/services/cart_service.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/language/domain/models/language_model.dart';
import 'package:waddy_app/features/language/domain/service/language_service_interface.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/profile/domain/services/profile_service_interface.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/domain/services/store_service_interface.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

/// ST-02: the cart holds its own store.
///
/// On device (09-30) the cart screen wrote the cart's store into
/// `StoreController.store`, and the store page under the cart came back with
/// the cart store's header over its own menu. The cart now resolves its store
/// from its own lines, through the shared store cache, and never touches the
/// page's.
void main() {
  late _FakeStoreService stores;
  late CartController cart;

  setUp(() {
    Get.reset();
    final SplashController splash = SplashController(
      splashServiceInterface: _StubSplashService(),
    );
    splash.setModuleConfigForTest(<String, dynamic>{
      AppConstants.food: <String, dynamic>{},
      AppConstants.grocery: <String, dynamic>{},
    });
    splash.setConfigModelForTest(
      ConfigModel(digitAfterDecimalPoint: 2, dmTipsStatus: 1),
    );
    splash.setModuleForTest(
      ModuleModel(id: 7, moduleName: 'food', moduleType: AppConstants.food),
    );
    Get.put<SplashController>(splash);
    Get.put<ProfileController>(
      ProfileController(profileServiceInterface: _StubProfileService()),
    );
    Get.put<XpController>(XpController(xpServiceInterface: _StubXpService()));
    Get.put<LocalizationController>(
      LocalizationController(languageServiceInterface: _StubLanguageService()),
    );
    stores = _FakeStoreService();
    Get.put<StoreServiceInterface>(stores);
    cart = CartController(
      cartServiceInterface: CartService(
        cartRepositoryInterface: _StubCartRepository(),
      ),
    );
  });
  tearDown(Get.reset);

  CartModel lineFrom(int storeId) => CartModel(
    1,
    100,
    100,
    <Variation>[],
    <List<bool?>>[],
    0,
    1,
    const <AddOn>[],
    const <AddOns>[],
    false,
    10,
    Item(
      id: storeId * 100,
      name: 'item',
      price: 100,
      discount: 0,
      discountType: 'percent',
      moduleType: AppConstants.food,
      storeId: storeId,
      variations: <Variation>[],
      foodVariations: <FoodVariation>[],
      addOns: <AddOns>[],
    ),
    10,
  );

  test('the cart store is the store of the cart\'s lines', () {
    stores.cached[33] = Store(id: 33, name: "Butcher's Burger");
    stores.cached[34] = Store(id: 34, name: 'Zooba');
    cart.cartList.add(lineFrom(33));

    cart.calculationCart();

    expect(cart.cartStore?.name, "Butcher's Burger");
    expect(stores.fetches, isEmpty, reason: 'a cached store needs no request');
  });

  test(
    'an uncached store is fetched once, and the bars re-price on arrival',
    () async {
      final Completer<Store?> gate = Completer<Store?>();
      stores.onFetch = (_) => gate.future;
      cart.cartList.add(lineFrom(33));

      // Every quantity tap recalculates; only the first may start a request.
      cart.calculationCart();
      cart.calculationCart();
      cart.calculationCart();
      expect(stores.fetches, <int>[33]);
      expect(cart.cartStore, isNull);

      gate.complete(Store(id: 33, name: "Butcher's Burger"));
      await Future<void>.delayed(Duration.zero);
      expect(cart.cartStore?.id, 33);
    },
  );

  test('a cart that moves to another store stops reporting the old one', () {
    stores.cached[33] = Store(id: 33, name: "Butcher's Burger");
    cart.cartList.add(lineFrom(33));
    cart.calculationCart();
    expect(cart.cartStore?.id, 33);

    // "Replace cart?" → the lines now belong to Zooba.
    cart.cartList
      ..clear()
      ..add(lineFrom(34));
    expect(cart.cartStore, isNull, reason: '33 is no longer this cart\'s');
  });

  test('a late store for the previous cart is dropped', () async {
    final Completer<Store?> gate = Completer<Store?>();
    stores.onFetch = (_) => gate.future;
    cart.cartList.add(lineFrom(33));
    cart.calculationCart();

    cart.cartList
      ..clear()
      ..add(lineFrom(34));
    gate.complete(Store(id: 33, name: "Butcher's Burger"));
    await Future<void>.delayed(Duration.zero);

    expect(cart.cartStore, isNull);
  });

  test('an empty cart has no store', () {
    expect(cart.cartStore, isNull);
    cart.calculationCart();
    expect(stores.fetches, isEmpty);
  });
}

class _FakeStoreService implements StoreServiceInterface {
  final Map<int, Store> cached = <int, Store>{};
  final List<int> fetches = <int>[];
  Future<Store?> Function(int id)? onFetch;

  @override
  Store? peekStoreDetails(int storeId, {required String languageCode}) =>
      cached[storeId];

  @override
  Future<Store?> getCachedStoreDetails(
    int storeId, {
    required String languageCode,
    int? moduleId,
    bool fromCart = false,
    Duration? maxAge,
  }) {
    fetches.add(storeId);
    return onFetch?.call(storeId) ?? Future<Store?>.value(cached[storeId]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubLanguageService implements LanguageServiceInterface {
  @override
  Locale getLocaleFromSharedPref() => const Locale('en', 'US');

  @override
  int setSelectedIndex(List<LanguageModel> languages, Locale locale) => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubSplashService implements SplashServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubProfileService implements ProfileServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubXpService implements XpServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubCartRepository implements CartRepositoryInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
