import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/language/domain/models/language_model.dart';
import 'package:waddy_app/features/language/domain/service/language_service_interface.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';
import 'package:waddy_app/features/store/controllers/store_page_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/domain/services/store_service_interface.dart';

/// Phase 4 (ST-01, ST-07): each store page owns its state.
///
/// The original bug, on device 09-30: an aisle picked on grocery store 31
/// (category 97) was sent as `category_id=97` for restaurant 33's menu, which
/// came back empty. With one controller per page there is nothing to carry.
void main() {
  late _FakeStoreService stores;

  setUp(() {
    Get.reset();
    // Fetching a store reads the current module (for the request header).
    Get.put<SplashController>(
      SplashController(splashServiceInterface: _StubSplashService()),
    );
    Get.put<LocalizationController>(
      LocalizationController(languageServiceInterface: _StubLanguageService()),
    );
    stores = _FakeStoreService();
    Get.put<StoreServiceInterface>(stores);
  });
  tearDown(() {
    // Pages left open by a failing test must not leak into the next one.
    while (StorePageController.top != null) {
      StorePageController.top!.close();
    }
    Get.reset();
  });

  test('two store pages do not share a category pick', () async {
    final StorePageController grocery = StorePageController.open();
    await grocery.getStoreDetails(Store(id: 31));
    grocery.selectSubCategory(172, 80);
    expect(stores.categoriesRequested.last, 172);

    final StorePageController restaurant = StorePageController.open();
    await restaurant.getStoreDetails(Store(id: 33));
    await restaurant.getStoreItemList(33, 1, 'all', false);

    expect(
      stores.categoriesRequested.last,
      0,
      reason: 'the restaurant\'s first menu request carries no category',
    );
  });

  test(
    'each page is registered under its own tag, and top follows the stack',
    () {
      final StorePageController a = StorePageController.open();
      final StorePageController b = StorePageController.open();

      expect(a.tag, isNot(b.tag));
      expect(Get.find<StorePageController>(tag: a.tag), same(a));
      expect(StorePageController.top, same(b));

      b.close();
      expect(Get.isRegistered<StorePageController>(tag: b.tag), isFalse);
      expect(StorePageController.top, same(a));

      a.close();
      expect(StorePageController.top, isNull);
    },
  );

  test('a menu page landing after its page closed is dropped', () async {
    final Completer<ItemModel?> gate = Completer<ItemModel?>();
    stores.onItems = (_) => gate.future;
    final StorePageController page = StorePageController.open();
    final Future<void> fetch = page.getStoreItemList(33, 1, 'all', false);

    page.close();
    gate.complete(ItemModel(items: <Item>[], totalSize: 0, offset: 1));

    await expectLater(fetch, completes, reason: 'no update() on a dead page');
  });

  test('an older category\'s page does not overwrite a newer one', () async {
    final Completer<ItemModel?> slow = Completer<ItemModel?>();
    final Completer<ItemModel?> fast = Completer<ItemModel?>();
    final List<Completer<ItemModel?>> queue = <Completer<ItemModel?>>[
      slow,
      fast,
    ];
    stores.onItems = (_) => queue.removeAt(0).future;
    final StorePageController page = StorePageController.open();

    final Future<void> first = page.getStoreItemList(33, 1, 'all', false);
    final Future<void> second = page.getStoreItemList(33, 1, 'all', false);
    fast.complete(ItemModel(items: <Item>[Item(id: 2)], totalSize: 1));
    await second;
    slow.complete(ItemModel(items: <Item>[Item(id: 1)], totalSize: 1));
    await first;

    expect(page.storeItemModel?.items?.single.id, 2);
  });
}

class _FakeStoreService implements StoreServiceInterface {
  final List<int?> categoriesRequested = <int?>[];
  Future<ItemModel?> Function(int? categoryId)? onItems;

  @override
  Future<Store?> getCachedStoreDetails(
    int storeId, {
    required String languageCode,
    int? moduleId,
    bool fromCart = false,
    Duration? maxAge,
  }) async => Store(id: storeId, name: 'store $storeId', categoryIds: <int>[]);

  @override
  Future<ItemModel?> getStoreItemList({
    int? storeID,
    required int offset,
    int? categoryID,
    String? type,
    List<String>? filter,
    int? rating,
    double? lowerValue,
    double? upperValue,
  }) {
    categoriesRequested.add(categoryID);
    return onItems?.call(categoryID) ??
        Future<ItemModel?>.value(ItemModel(items: <Item>[], totalSize: 0));
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
