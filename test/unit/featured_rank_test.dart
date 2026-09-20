import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/home/widgets/views/top_restaurants_view.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// The food home paints 1..10 over the featured stores — the strongest
/// attention pattern on the screen. Those numerals used to sit on whatever
/// order the query returned, so they looked like a judgement and were an
/// accident. They are now backed by `featured_order`, set by hand in admin,
/// which makes the order a claim worth testing rather than a side effect.
void main() {
  Store store(String name, {int? rank}) =>
      Store(id: name.hashCode, name: name, featured: 1, featuredOrder: rank);

  List<String> names(List<Store> stores) =>
      stores.map((Store s) => s.name ?? '').toList();

  test('ranked stores come back in the order someone chose', () {
    final List<Store> ranked = rankFeaturedForTest(<Store>[
      store('Zooba', rank: 3),
      store('Ama Sushi', rank: 1),
      store('Butcher\'s Burger', rank: 2),
    ]);

    expect(names(ranked), <String>['Ama Sushi', 'Butcher\'s Burger', 'Zooba']);
  });

  // The trap MySQL sets with NULLs in an ascending sort, and the same one in
  // Dart's comparator: an unranked store must never outrank a ranked one.
  test('featured but unranked sorts last, never first', () {
    final List<Store> ranked = rankFeaturedForTest(<Store>[
      store('Unranked'),
      store('Vinny\'s Pizza', rank: 2),
      store('Auntie Anne\'s', rank: 1),
    ]);

    expect(names(ranked), <String>[
      'Auntie Anne\'s',
      'Vinny\'s Pizza',
      'Unranked',
    ]);
  });

  test('unranked stores keep the order the server sent', () {
    final List<Store> ranked = rankFeaturedForTest(<Store>[
      store('First'),
      store('Second'),
      store('Third'),
    ]);

    expect(names(ranked), <String>['First', 'Second', 'Third']);
  });

  // Two stores given the same position is an admin slip, not a crash. The
  // server's order decides, so the chart stays stable between loads instead of
  // shuffling those two around.
  test('a duplicated rank falls back to the order the server sent', () {
    final List<Store> ranked = rankFeaturedForTest(<Store>[
      store('Second at 1', rank: 1),
      store('First at 1', rank: 1),
      store('Third', rank: 2),
    ]);

    expect(names(ranked), <String>['Second at 1', 'First at 1', 'Third']);
  });

  test('an empty list is not an error', () {
    expect(rankFeaturedForTest(<Store>[]), isEmpty);
  });
}
