import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The 10-second tracking poll must not repaint on every tick.
///
/// While a tracking screen is open, `timerTrackOrder` fires every 10s and used
/// to call a bare `update()` each time — rebuilding all 15
/// `GetBuilder<OrderController>` trees, the map included, on ticks where the
/// rider had not moved and the status had not changed. On a mid-range device
/// that is a visible stutter every ten seconds, for the length of a delivery.
///
/// Asserted on the source: exercising the poll needs a controller, a service
/// stub and a timer, and the property is structural.
void main() {
  late String controller;
  late String screen;
  late String repository;

  setUpAll(() {
    controller = File(
      'lib/features/order/controllers/order_controller.dart',
    ).readAsStringSync();
    screen = File(
      'lib/features/order/screens/order_tracking_screen.dart',
    ).readAsStringSync();
    repository = File(
      'lib/features/order/domain/repositories/order_repository.dart',
    ).readAsStringSync();
  });

  String methodBody(String src, String signature) {
    final int at = src.indexOf(signature);
    expect(at, isNot(-1), reason: '$signature was renamed or removed');
    int i = src.indexOf('{', src.indexOf(')', at));
    int depth = 0;
    final int start = i;
    while (i < src.length) {
      if (src[i] == '{') depth++;
      if (src[i] == '}') {
        depth--;
        if (depth == 0) return src.substring(start, i + 1);
      }
      i++;
    }
    fail('unbalanced braces');
  }

  group('the poll only rebuilds on a real change', () {
    test('timerTrackOrder compares before updating', () {
      final String body = methodBody(controller, 'timerTrackOrder(');
      expect(
        body,
        contains('if (changed) update()'),
        reason: 'a tick where nothing moved must not rebuild 15 trees',
      );
    });

    test('the comparison covers what a user can see', () {
      final String body = methodBody(controller, 'timerTrackOrder(');
      // Rider position changes most often; status and driver identity change
      // rarely but visibly. Miss one and the screen goes stale.
      expect(body, contains('orderStatus'));
      expect(body, contains('deliveryMan?.lat'));
      expect(body, contains('deliveryMan?.lng'));
    });

    test('a failed poll still updates — the error state must show', () {
      final String body = methodBody(controller, 'timerTrackOrder(');
      final int elseAt = body.indexOf('} else {');
      expect(elseAt, isNot(-1));
      expect(
        body.substring(elseAt).contains('update()'),
        isTrue,
        reason: 'skipping the rebuild on failure would hide the error',
      );
    });
  });

  group('the marker follows the tick that fetched it', () {
    test('the poll awaits the fetch before moving the marker', () {
      // Un-awaited, updateMarker ran against the PREVIOUS tick's data, so
      // every rider position was drawn ten seconds late.
      expect(screen, contains('await Get.find<OrderController>().timerTrackOrder'));
    });

    test('a null track model is handled, not banged through', () {
      // The model is null when a poll fails; a bang took the screen down on a
      // dropped connection mid-delivery.
      expect(
        screen.contains('Get.find<OrderController>().trackModel!.deliveryMan'),
        isFalse,
        reason: 'read the model once, null-check it, then use the local',
      );
    });
  });

  group('the dashboard badge asks for a count, not a list', () {
    test('fromDashboard requests one order', () {
      // It requested 50 — 37.3KB on every home load and refresh — to evaluate
      // `orders!.isNotEmpty` and light a badge.
      expect(
        repository,
        contains('fromDashboard ? 1 : 10'),
        reason: 'one order answers isNotEmpty as well as fifty',
      );
      expect(repository.contains('fromDashboard ? 50'), isFalse);
    });
  });
}
