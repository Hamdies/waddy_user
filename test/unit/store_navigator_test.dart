import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/store/store_navigator.dart';

/// Phase 5 (ST-04, ST-05, ST-06): one rule for which page a store gets, and
/// one way into it. Decided 09-30: restaurants and every non-supermarket store
/// get the menu page; supermarkets get the aisle page.
void main() {
  group('StoreLayout.resolve', () {
    test('a supermarket gets the aisle page', () {
      expect(StoreLayout.resolve(ModuleType.grocery, true), StoreLayout.aisles);
    });

    test('a restaurant gets the menu page', () {
      expect(StoreLayout.resolve(ModuleType.food, false), StoreLayout.menu);
    });

    test('a non-supermarket grocery store gets the specialty page', () {
      // Butchers, dairies, greengrocers — is_supermarket: false inside the
      // grocery module.
      expect(
        StoreLayout.resolve(ModuleType.grocery, false),
        StoreLayout.specialty,
      );
    });

    test('every pets store gets the pets page, whatever the payload says', () {
      for (final bool? flag in <bool?>[true, false, null]) {
        expect(StoreLayout.resolve(ModuleType.pets, flag), StoreLayout.pets);
      }
    });

    test('a store known only by id is undecided, so the shell fetches it', () {
      expect(StoreLayout.resolve(ModuleType.food, null), isNull);
      expect(StoreLayout.resolve(ModuleType.grocery, null), isNull);
      expect(StoreLayout.resolve(null, null), isNull);
    });

    test('an unknown module treats a flagged store by its flag alone', () {
      expect(StoreLayout.resolve(null, true), StoreLayout.aisles);
      expect(StoreLayout.resolve(null, false), StoreLayout.menu);
    });
  });

  group('StoreLayout.resolveFallback', () {
    test('grocery defaults to the aisles', () {
      expect(
        StoreLayout.resolveFallback(ModuleType.grocery),
        StoreLayout.aisles,
      );
    });

    test('pets stays pets', () {
      expect(StoreLayout.resolveFallback(ModuleType.pets), StoreLayout.pets);
    });

    test('with nothing to go on, the fallback is the menu page', () {
      expect(StoreLayout.resolveFallback(null), StoreLayout.menu);
      expect(StoreLayout.resolveFallback(ModuleType.food), StoreLayout.menu);
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
