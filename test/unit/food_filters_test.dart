import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';

/// The food home's filter state lives on `StoreController` and only there.
///
/// It used to live in five `setState` fields on the screen *as well*, pushed
/// into the controller and never read back — so the chips rendered from one
/// copy and the store list from the other. `DashboardScreen` builds its pages
/// with a `PageView.builder` that keeps nothing alive, so a hop to the Orders
/// tab disposed the screen's State: the chips came back empty while the
/// controller was still filtering the list.
///
/// These pin the model the screen now reads through. See `F-02` in
/// `docs/food_module_plan.md`.
void main() {
  const ModuleStoreFilters none = ModuleStoreFilters();

  group('one filter changes, the rest survive', () {
    test('toggling a flag keeps the cuisine and the sort', () {
      const ModuleStoreFilters active = ModuleStoreFilters(
        cuisineId: 7,
        sort: 'rating',
        freeDelivery: true,
      );

      final ModuleStoreFilters next = active.copyWith(offers: true);

      expect(next.offers, isTrue);
      expect(next.cuisineId, 7);
      expect(next.sort, 'rating');
      expect(next.freeDelivery, isTrue);
    });

    // The reason copyWith takes sentinels rather than plain nullables: a
    // nullable parameter cannot tell "leave this alone" from "clear this", and
    // every one of these fields is cleared by tapping its own control again.
    test('null clears a field rather than being ignored', () {
      const ModuleStoreFilters active = ModuleStoreFilters(
        cuisineId: 7,
        sort: 'distance',
        maxDeliveryTime: 30,
      );

      expect(active.copyWith(cuisineId: null).cuisineId, isNull);
      expect(active.copyWith(sort: null).sort, isNull);
      expect(active.copyWith(maxDeliveryTime: null).maxDeliveryTime, isNull);
      // …and clearing one leaves the others alone.
      expect(active.copyWith(sort: null).cuisineId, 7);
    });

    test('the filters sheet resets only what it owns', () {
      const ModuleStoreFilters active = ModuleStoreFilters(
        cuisineId: 7,
        sort: 'rating',
        maxDeliveryTime: 30,
        freeDelivery: true,
        offers: true,
      );

      final ModuleStoreFilters reset = active.copyWith(
        maxDeliveryTime: null,
        freeDelivery: false,
        offers: false,
      );

      expect(reset.maxDeliveryTime, isNull);
      expect(reset.freeDelivery, isFalse);
      expect(reset.offers, isFalse);
      expect(
        reset.cuisineId,
        7,
        reason: 'the cuisine strip is not in the sheet',
      );
      expect(reset.sort, 'rating', reason: 'nor is the sort');
    });
  });

  group('the query the chips produce', () {
    test('no filters means no query at all, not an empty clause', () {
      expect(none.isActive, isFalse);
      expect(none.toQueryString(), isEmpty);
    });

    // Matches the contract in `get-stores-filter-contract`: the backend reads
    // filter/sort/category_id/max_delivery_time/cuisine_id off get-stores.
    test('every filter lands in the query under its contracted name', () {
      const ModuleStoreFilters all = ModuleStoreFilters(
        offers: true,
        freeDelivery: true,
        maxDeliveryTime: 30,
        sort: 'rating',
        cuisineId: 7,
      );

      final String query = all.toQueryString();

      expect(query, startsWith('&'));
      expect(query, contains('filter=[discounted,free_delivery]'));
      expect(query, contains('max_delivery_time=30'));
      expect(query, contains('sort=rating'));
      expect(query, contains('cuisine_id=7'));
    });

    test('a cleared filter leaves no trace in the query', () {
      const ModuleStoreFilters active = ModuleStoreFilters(
        cuisineId: 7,
        offers: true,
      );

      final String query = active.copyWith(cuisineId: null).toQueryString();

      expect(query, contains('filter=[discounted]'));
      expect(query, isNot(contains('cuisine_id')));
    });
  });
}
