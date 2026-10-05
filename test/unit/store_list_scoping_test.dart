import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ST-07 / Phase 6: every store-list update names the builders it concerns.
///
/// The GetX trap this guards (memory: getx-builder-scoping): a `GetBuilder`
/// with an `id` ignores a bare `update()`, and one without an id ignores
/// `update([ids])`. Mixing the two makes a section silently stop refreshing —
/// nothing fails, the list just never appears. So the rules are all-or-nothing
/// and checked here from source:
///
/// 1. no bare `update()` in the controller,
/// 2. every `GetBuilder` on it carries an `id:`,
/// 3. every id a builder listens on is named by at least one update.
void main() {
  const String controllerPath =
      'lib/features/store/controllers/store_list_controller.dart';
  const String controllerClass = 'StoreListController';

  late String controller;

  setUpAll(() {
    controller = File(controllerPath).readAsStringSync();
  });

  String stripComments(String code) => code
      .split('\n')
      .where((String l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  test('no bare update() in the controller', () {
    expect(
      RegExp(r'\bupdate\(\)').hasMatch(stripComments(controller)),
      isFalse,
      reason: 'a bare update() reaches no builder — every builder has an id',
    );
  });

  /// Every `GetBuilder<StoreController>(` in lib, with the id it passes.
  Map<String, List<String?>> builders() {
    final Map<String, List<String?>> found = <String, List<String?>>{};
    for (final FileSystemEntity f in Directory('lib').listSync(
      recursive: true,
    )) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final String code = stripComments(f.readAsStringSync());
      for (final RegExpMatch m in RegExp(
        'GetBuilder<$controllerClass>\\(',
      ).allMatches(code)) {
        final String head = code.substring(
          m.end,
          (m.end + 160).clamp(0, code.length),
        );
        final RegExpMatch? id = RegExp(
          '^\\s*id:\\s*$controllerClass\\.(\\w+)',
        ).firstMatch(head);
        (found[f.path] ??= <String?>[]).add(id?.group(1));
      }
    }
    return found;
  }

  test('every builder listens on an id', () {
    final Map<String, List<String?>> all = builders();
    expect(all, isNotEmpty);
    final List<String> missing = <String>[
      for (final MapEntry<String, List<String?>> e in all.entries)
        if (e.value.contains(null)) e.key,
    ];
    expect(missing, isEmpty, reason: 'these builders would never rebuild');
  });

  test('every id a builder listens on is notified by some update', () {
    // The id sets the updates use: `static const List<Object> _xIds = [...]`.
    final Set<String> notified = <String>{};
    for (final RegExpMatch m in RegExp(
      r'static const List<Object> _\w+Ids = \[([^\]]*)\]',
    ).allMatches(controller)) {
      notified.addAll(
        RegExp(r'\w+').allMatches(m.group(1)!).map((RegExpMatch w) => w[0]!),
      );
    }
    final Set<String> listened = <String>{
      for (final List<String?> ids in builders().values) ...ids.whereType(),
    };
    expect(listened.difference(notified), isEmpty);
  });
}
