import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/store_navigator.dart';

/// Phase 5 (ST-04, ST-05, ST-06): one rule for which page a store gets, and
/// one way into it. Decided 09-30: restaurants and every non-supermarket store
/// get the menu page; supermarkets get the aisle page.
void main() {
  group('StoreLayout', () {
    test('a supermarket gets the aisle page', () {
      expect(StoreLayout.of(Store(isSupermarket: true)), StoreLayout.aisles);
    });

    test('everything else gets the menu page', () {
      // Restaurants, butchers, dairies — the backend formats them all with
      // is_supermarket: false.
      expect(StoreLayout.of(Store(isSupermarket: false)), StoreLayout.menu);
    });

    test('a store known only by id is undecided, so the shell fetches it', () {
      expect(StoreLayout.of(Store(id: 33)), isNull);
    });

    test('with nothing to go on, the fallback is the menu page', () {
      Get.reset();
      Get.put<SplashController>(
        SplashController(splashServiceInterface: _StubSplashService()),
      );
      expect(StoreLayout.fallback(Store(id: 33)), StoreLayout.menu);
      Get.reset();
    });
  });

  group('one way into a store', () {
    List<File> dartFiles() =>
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((File f) => f.path.endsWith('.dart'))
            .toList();

    String code(File f) => f
        .readAsStringSync()
        .split('\n')
        .where((String l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('only the navigator builds a store page', () {
      // Twenty-nine call sites used to, with four different rules — which is
      // how restaurants opened from search or "Order again" got the
      // supermarket aisle page.
      final List<String> builders = <String>[
        for (final File f in dartFiles())
          if (RegExp(r'\b(StoreScreen|FoodStoreScreen)\(').hasMatch(
                code(f).replaceAll(
                  RegExp(r'const (StoreScreen|FoodStoreScreen)\('),
                  '',
                ),
              ) &&
              !f.path.endsWith('store_navigator.dart'))
            f.path,
      ];
      expect(builders, isEmpty);
    });

    test(
      'only the navigator (and the deep-link URL builder) route to a store',
      () {
        final List<String> callers = <String>[
          for (final File f in dartFiles())
            if (code(f).contains('getStoreRoute(') &&
                !f.path.endsWith('route_helper.dart'))
              f.path,
        ]..sort();
        expect(callers, <String>[
          'lib/features/store/store_navigator.dart',
          'lib/helper/deep_link_helper.dart',
        ]);
      },
    );
  });
}

class _StubSplashService implements SplashServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
