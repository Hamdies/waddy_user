import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/sliver_paginated_list.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_list.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// The point of the sliver conversion is that off-screen cards are never built.
/// The analyzer cannot check either half of that claim — a box widget placed in
/// a `slivers:` list fails at layout, not at compile time, and eagerness is a
/// runtime property — so both are asserted here against a real viewport.
void main() {
  StoreModel model(int count) => StoreModel(
    totalSize: count,
    offset: 1,
    stores: List<Store>.generate(
      count,
      (int i) => Store(id: i, name: 'Store $i'),
    ),
  );

  // GetMaterialApp, not MaterialApp: `Dimensions.fontSize*` reads `Get.context!`
  // at static-initialiser time, so any widget that touches a text style throws
  // a null check error without a Get-owned context in the tree.
  Widget host(Widget sliver) => GetMaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 600,
        child: CustomScrollView(slivers: <Widget>[sliver]),
      ),
    ),
  );

  group('SliverPaginatedList', () {
    testWidgets('lays out as a sliver inside a CustomScrollView', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SliverPaginatedList(
            scrollController: ScrollController(),
            onPaginate: (_) async {},
            totalSize: 3,
            offset: 1,
            itemCount: 3,
            itemBuilder:
                (context, index) =>
                    SizedBox(height: 100, child: Text('row $index')),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('row 0'), findsOneWidget);
      expect(find.text('row 2'), findsOneWidget);
    });

    testWidgets('builds only what the viewport needs, not the whole list', (
      tester,
    ) async {
      final Set<int> built = <int>{};

      await tester.pumpWidget(
        host(
          SliverPaginatedList(
            scrollController: ScrollController(),
            onPaginate: (_) async {},
            totalSize: 200,
            offset: 1,
            itemCount: 200,
            itemBuilder: (context, index) {
              built.add(index);
              return SizedBox(height: 100, child: Text('row $index'));
            },
          ),
        ),
      );

      // 600pt viewport / 100pt rows = 6 visible, plus Flutter's cache extent.
      // The precise number is an implementation detail; that it is nowhere near
      // 200 is the whole point. The old Column built all 200.
      expect(built.length, lessThan(30));
      expect(built.length, greaterThanOrEqualTo(6));
      expect(
        built.contains(199),
        isFalse,
        reason: 'the last row is far off-screen and must not be built',
      );
    });

    testWidgets('reserves bottom space for the nav overlay', (tester) async {
      await tester.pumpWidget(
        host(
          SliverPaginatedList(
            scrollController: ScrollController(),
            onPaginate: (_) async {},
            totalSize: 1,
            offset: 1,
            itemCount: 1,
            bottomReserve: 80,
            itemBuilder: (context, index) => const SizedBox(height: 100),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('ModuleStoreListSliver', () {
    testWidgets('null store model shows the shimmer, still as a sliver', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ModuleStoreListSliver(
            scrollController: ScrollController(),
            storeModel: null,
            cardBuilder: (store) => const SizedBox(height: 80),
            shimmer: const SizedBox(height: 200, child: Text('loading')),
            emptyIcon: const Icon(Icons.restaurant_outlined),
            emptyTitle: 'none',
            emptySubtitle: 'try again',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('loading'), findsOneWidget);
    });

    testWidgets('empty list shows the empty state', (tester) async {
      await tester.pumpWidget(
        host(
          ModuleStoreListSliver(
            scrollController: ScrollController(),
            storeModel: StoreModel(totalSize: 0, offset: 1, stores: <Store>[]),
            cardBuilder: (store) => const SizedBox(height: 80),
            shimmer: const SizedBox(height: 200, child: Text('loading')),
            emptyIcon: const Icon(Icons.restaurant_outlined),
            emptyTitle: 'No restaurants',
            emptySubtitle: 'try a different category',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('No restaurants'), findsOneWidget);
      expect(find.text('loading'), findsNothing);
    });

    testWidgets(
      'stays lazy inside the DecoratedSliver band grocery wraps it in',
      (tester) async {
        // GroceryHomeScreen groups its browse area in a tinted, bordered band.
        // As a Container round a Column that band was what forced the whole
        // catalogue to build; DecoratedSliver keeps the treatment without the
        // eagerness. This asserts the composition actually lays out AND that the
        // decoration does not quietly force its child to a full extent.
        final Set<int?> built = <int?>{};

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: CustomScrollView(
                  slivers: <Widget>[
                    DecoratedSliver(
                      decoration: const BoxDecoration(
                        color: Color(0x11000000),
                        border: Border(
                          top: BorderSide(color: Color(0x22000000)),
                          bottom: BorderSide(color: Color(0x22000000)),
                        ),
                      ),
                      sliver: SliverMainAxisGroup(
                        slivers: <Widget>[
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          ModuleStoreListSliver(
                            scrollController: ScrollController(),
                            storeModel: model(120),
                            cardBuilder: (store) {
                              built.add(store.id);
                              return SizedBox(
                                height: 120,
                                child: Text('card ${store.id}'),
                              );
                            },
                            shimmer: const SizedBox(height: 200),
                            emptyIcon: const Icon(Icons.storefront_outlined),
                            emptyTitle: 'none',
                            emptySubtitle: 'try again',
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('card 0'), findsOneWidget);
        expect(
          built.length,
          lessThan(30),
          reason: 'the decorated band must not force an eager full build',
        );
      },
    );

    testWidgets('populated list renders cards lazily', (tester) async {
      final Set<int?> built = <int?>{};

      await tester.pumpWidget(
        host(
          ModuleStoreListSliver(
            scrollController: ScrollController(),
            storeModel: model(120),
            cardBuilder: (store) {
              built.add(store.id);
              return SizedBox(height: 120, child: Text('card ${store.id}'));
            },
            shimmer: const SizedBox(height: 200, child: Text('loading')),
            emptyIcon: const Icon(Icons.restaurant_outlined),
            emptyTitle: 'none',
            emptySubtitle: 'try again',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('card 0'), findsOneWidget);
      expect(
        built.length,
        lessThan(30),
        reason: 'a Column would have built all 120',
      );
    });
  });
}
