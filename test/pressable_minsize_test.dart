import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/common/widgets/pressable.dart';

void main() {
  testWidgets('minSize expands hit box, not the visual', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Pressable(
              onTap: () => taps++,
              minSize: 48,
              haptic: false,
              child: Container(width: 40, height: 40, color: Colors.red),
            ),
          ),
        ),
      ),
    );

    // The visual child is still 40.
    expect(tester.getSize(find.byType(Container)), const Size(40, 40));

    // The gesture detector's box is 48.
    final gd = tester.getSize(find.byType(GestureDetector).first);
    expect(gd.width, greaterThanOrEqualTo(48.0));
    expect(gd.height, greaterThanOrEqualTo(48.0));

    // A tap 22pt from centre lands outside the 40pt visual but inside 48.
    final c = tester.getCenter(find.byType(GestureDetector).first);
    await tester.tapAt(Offset(c.dx + 22, c.dy));
    await tester.pump();
    expect(taps, 1, reason: 'tap in the expanded margin must register');
  });

  testWidgets('without minSize the box stays at the child size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Pressable(
              onTap: () {},
              haptic: false,
              child: Container(width: 40, height: 40, color: Colors.red),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(GestureDetector).first),
      const Size(40, 40),
    );
  });
}
