import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/common/widgets/spots/spots_marks.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';

/// Every Spots mark and the two sticker styles lay out and paint without a
/// framework exception (overflow, bad paint, unbounded constraints).
///
/// This used to be a golden-file test. A pixel comparison rendered on a Mac
/// and checked on a Linux CI runner differs in anti-aliasing and font
/// metrics, so it would fail for reasons unrelated to the marks. What it was
/// protecting is that they render at all, which needs no screenshot.
void main() {
  testWidgets('marks and stickers render without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Spots.canvas,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final SpotsMark mark in SpotsMark.values) ...[
                      SpotsGlyph(mark, size: 40),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                const SpotsSticker(
                  label: 'LIVE LEADER',
                  mark: SpotsMark.flame,
                  live: true,
                ),
                const SizedBox(height: 20),
                const SpotsSticker(
                  label: 'CURRENT CHAMPION',
                  mark: SpotsMark.trophy,
                  fill: Spots.teal,
                  fg: Spots.mint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // The live sticker animates forever, so step the clock instead of settling.
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    // The stickers draw their own glyphs too, so the row's seven are a floor.
    expect(
      tester.widgetList(find.byType(SpotsGlyph)).length,
      greaterThanOrEqualTo(SpotsMark.values.length),
    );
    expect(find.byType(SpotsSticker), findsNWidgets(2));
  });
}
