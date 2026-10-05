import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/category/controllers/category_page_controller.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/category/domain/services/category_service_interface.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// ST-16: each category page owns its state, like the store pages (ST-01).
void main() {
  late _FakeCategoryService service;

  setUp(() {
    Get.reset();
    service = _FakeCategoryService();
    Get.put<CategoryServiceInterface>(service);
  });
  tearDown(Get.reset);

  test('a new category page starts clean', () {
    final CategoryPageController a = CategoryPageController.open();
    a.setRestaurant(true);
    a.getCategoryItemList('7', 1, 'veg', false);
    a.setRating(4);

    final CategoryPageController b = CategoryPageController.open();
    expect(b.isStore, isFalse, reason: 'the tab flag used to leak');
    expect(b.type, 'all', reason: 'the item type used to leak');
    expect(b.rating, -1, reason: 'filter selections used to leak');
    expect(b.isSearching, isFalse);
    expect(a.tag, isNot(b.tag));
  });

  test('close unregisters the page', () {
    final CategoryPageController page = CategoryPageController.open();
    page.close();
    expect(Get.isRegistered<CategoryPageController>(tag: page.tag), isFalse);
  });

  test('an older sub-category\'s items do not overwrite a newer one', () async {
    final Completer<ItemModel?> slow = Completer<ItemModel?>();
    final Completer<ItemModel?> fast = Completer<ItemModel?>();
    final List<Completer<ItemModel?>> queue = <Completer<ItemModel?>>[
      slow,
      fast,
    ];
    service.onItems = () => queue.removeAt(0).future;
    final CategoryPageController page = CategoryPageController.open();

    page.getCategoryItemList('7', 1, 'all', false);
    page.getCategoryItemList('8', 1, 'all', false);
    fast.complete(ItemModel(items: <Item>[Item(id: 2)], totalSize: 1));
    await Future<void>.delayed(Duration.zero);
    slow.complete(ItemModel(items: <Item>[Item(id: 1)], totalSize: 1));
    await Future<void>.delayed(Duration.zero);

    expect(page.categoryItemList?.map((Item i) => i.id), <int?>[2]);
  });

  test('items landing after the page closed are dropped', () async {
    final Completer<ItemModel?> gate = Completer<ItemModel?>();
    service.onItems = () => gate.future;
    final CategoryPageController page = CategoryPageController.open();
    page.getCategoryItemList('7', 1, 'all', false);

    page.close();
    gate.complete(ItemModel(items: <Item>[Item(id: 1)], totalSize: 1));
    await Future<void>.delayed(Duration.zero);

    expect(page.categoryItemList, isNull);
  });
}

class _FakeCategoryService implements CategoryServiceInterface {
  Future<ItemModel?> Function()? onItems;

  @override
  Future<ItemModel?> getCategoryItemList(
    String? categoryID,
    int offset,
    String type,
  ) =>
      onItems?.call() ??
      Future<ItemModel?>.value(ItemModel(items: <Item>[], totalSize: 0));

  @override
  Future<StoreModel?> getCategoryStoreList(
    String? categoryID,
    int offset,
    String type,
  ) async => StoreModel(stores: <Store>[], totalSize: 0);

  @override
  Future<List<CategoryModel>?> getSubCategoryList(String? parentID) async =>
      <CategoryModel>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
