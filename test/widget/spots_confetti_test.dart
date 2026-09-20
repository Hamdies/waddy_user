import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/spots/spots_confetti.dart';

/// The burst had never once rendered.
///
/// `showSpotsConfetti` looked its context up through `Get.context`, which is
/// the `GetMaterialApp`'s context and sits *above* the `Navigator` — so the
/// `Overlay` it then searched for was not in scope, `Overlay.maybeOf` returned
/// null, and the function returned on its own guard clause. Silently, every
/// time, on every win and every vote.
///
/// Nothing caught it because the failure mode is "nothing happens", which is
/// indistinguishable from not having called it — so these tests assert the
/// burst actually mounts rather than that the call does not throw.
bool _hasConfetti() => find.byType(CustomPaint).evaluate().any(
  (e) =>
      (e.widget as CustomPaint).painter.runtimeType.toString().contains(
        'Confetti',
      ),
);

Widget _host({required void Function(BuildContext) onReady}) {
  return GetMaterialApp(
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onReady(context),
              child: const Text('go'),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  testWidgets('a burst fired from a widget context actually mounts', (t) async {
    await t.pumpWidget(_host(onReady: (c) => showSpotsConfetti(from: c)));
    await t.pump();

    expect(_hasConfetti(), isFalse);
    await t.tap(find.text('go'));
    await t.pump();

    expect(_hasConfetti(), isTrue);

    // And it cleans itself up rather than leaving an overlay entry behind.
    await t.pumpAndSettle();
    expect(_hasConfetti(), isFalse);
    expect(t.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion suppresses it', (t) async {
    await t.pumpWidget(
      GetMaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder:
                (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => showSpotsConfetti(from: context),
                    child: const Text('go'),
                  ),
                ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.tap(find.text('go'));
    await t.pump();

    expect(_hasConfetti(), isFalse);
  });

  testWidgets('the no-context fallback still renders', (t) async {
    // `place_vote_action` is a top-level function reached from six call
    // sites and has no `BuildContext` to hand, so the fallback has to work
    // rather than merely not throw — the vote burst is the whole reason this
    // helper was written.
    await t.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: Text('home'))),
    );
    await t.pump();

    // A pushed route, which is where a vote actually happens.
    Get.to(() => const Scaffold(body: Text('details')));
    await t.pumpAndSettle();

    showSpotsConfetti();
    await t.pump();

    expect(_hasConfetti(), isTrue);
    expect(t.takeException(), isNull);
    await t.pumpAndSettle();
  });
}
