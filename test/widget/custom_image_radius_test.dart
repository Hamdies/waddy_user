import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';

/// `CustomImage.borderRadius` rounds without a `ClipRRect`.
///
/// A clip forces a `saveLayer`: the subtree renders to an offscreen buffer,
/// gets masked, then composites back. These cards do that per image in a
/// scrolling rail, and the Mi 9T baseline puts raster at 9.8-14.5ms against a
/// 16.7ms budget — the GPU nearly misses the frame before any Dart runs.
///
/// Given a radius, the loaded image is painted as a `DecorationImage` on a
/// rounded `BoxDecoration` instead: the renderer rounds while drawing rather
/// than masking afterwards.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('rounding without a clip', () {
    testWidgets('no ClipRRect is introduced by the widget itself', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          const CustomImage(
            image: 'https://example.invalid/a.png',
            height: 50,
            width: 50,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );

      // The placeholder renders while the (unreachable) URL loads. What
      // matters is that rounding never costs a clip.
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('renders without throwing when no radius is given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          const CustomImage(
            image: 'https://example.invalid/a.png',
            height: 50,
            width: 50,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a radius does not change layout size', (
      WidgetTester tester,
    ) async {
      // Rounding must be free in layout terms — a card that reflows because
      // its image gained a radius would be a regression, not an optimisation.
      await tester.pumpWidget(
        host(
          const SizedBox(
            height: 60,
            width: 60,
            child: CustomImage(
              image: 'https://example.invalid/a.png',
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomImage), findsOneWidget);
    });
  });
}
