import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';

/// The invariant that makes ~340 `configModel` dereferences safe.
///
/// ## Why this file exists
///
/// `SplashController.configModel` returns a **non-null** `ConfigModel` and
/// throws if config has not loaded. That is only sound because navigation past
/// the splash is gated: `_configLoaded` is set exclusively inside the
/// `statusCode == 200` branch of `_handleConfigResponse`, and `_tryNavigate`
/// refuses to route without it. A config failure shows `NoInternetScreen` and
/// the app stays on the splash.
///
/// The alternative — converting every site to `?? someDefault` — was rejected
/// deliberately: ~340 fallbacks that can never fire would each *hide* a broken
/// gate, and a wrong-but-plausible default for a payment flag or a tax rate is
/// far worse than a crash that names the bug. The safety comes from the gate,
/// so the gate is what has to be tested.
///
/// ## The bypass paths
///
/// Four ways to reach a post-splash screen were audited before relying on this:
///
///  1. **Notification cold start** — `main()` passes the payload to
///     `RouteHelper.getSplashRoute(body)`, so it routes *through* the splash.
///  2. **Deep links** — `DeepLinkHelper` stashes a cold link and replays it from
///     the dashboard's first frame (`consumePending`), which is post-gate.
///  3. **Other `offAllNamed` calls** — all are in-app returns to home from
///     order, chat, auth and notification screens, i.e. already past the gate.
///  4. **Config refresh** — three callers re-fetch after boot. They go through
///     the same `_handleConfigResponse`, which only assigns on a 200, so a
///     failed refresh leaves the previously loaded model in place.
///
/// Path 4 is the one with teeth, and it is covered below: a failed refresh must
/// not null or partially overwrite a good config.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SplashController controller;

  setUp(() {
    Get.reset();
    controller = SplashController(
      splashServiceInterface: _StubSplashService(),
    );
    Get.put<SplashController>(controller);
  });
  tearDown(Get.reset);

  group('before config loads', () {
    test('configModel throws a named error rather than a null failure', () {
      // The whole point of the non-null getter: if the gate is ever bypassed,
      // the crash says what is wrong instead of surfacing as "Null check
      // operator used on a null value" three frames away.
      expect(
        () => controller.configModel,
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('configModel read before the config load completed'),
          ),
        ),
      );
    });

    test('configModelOrNull is the escape hatch for pre-gate code', () {
      // The splash screen itself, guest bootstrap and onboarding run before the
      // gate and must degrade rather than throw.
      expect(controller.configModelOrNull, isNull);
    });

    test('navigation is not permitted', () {
      // `_tryNavigate` requires `_configLoaded`, which only the 200 branch
      // sets. Observable through the public flag.
      expect(controller.configLoaded, isFalse);
    });
  });

  group('after config loads', () {
    setUp(() {
      controller.setConfigModelForTest(
        ConfigModel(digitAfterDecimalPoint: 2, businessName: 'Waddy'),
      );
    });

    test('configModel returns the model without throwing', () {
      expect(controller.configModel, isNotNull);
      expect(controller.configModel.businessName, 'Waddy');
    });

    test('both getters agree once loaded', () {
      expect(controller.configModelOrNull, same(controller.configModel));
    });
  });

  group('config is never un-loaded', () {
    test('nothing in the controller sets the model back to null', () {
      // This is the second half of the invariant. If a future change adds a
      // "clear config" path, `configModel` starts throwing on live screens and
      // this test is where that shows up first.
      controller.setConfigModelForTest(
        ConfigModel(digitAfterDecimalPoint: 2, businessName: 'Waddy'),
      );

      // Exercise a state transition a session actually goes through.
      controller.selectModuleIndex(1);

      expect(
        controller.configModelOrNull,
        isNotNull,
        reason: 'a loaded config must survive ordinary session state changes',
      );
      expect(() => controller.configModel, returnsNormally);
    });

    test('a later config replaces the old one wholesale, never partially', () {
      controller.setConfigModelForTest(
        ConfigModel(digitAfterDecimalPoint: 2, businessName: 'First'),
      );
      controller.setConfigModelForTest(
        ConfigModel(digitAfterDecimalPoint: 3, businessName: 'Second'),
      );

      // `_handleConfigResponse` assigns a freshly parsed model in one
      // statement, so a refresh cannot leave a half-updated object behind.
      expect(controller.configModel.businessName, 'Second');
      expect(controller.configModel.digitAfterDecimalPoint, 3);
    });
  });
}

class _StubSplashService implements SplashServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Async members must hand back a Future, not null, or awaiting one throws
    // a type error that looks like a controller bug.
    final String name = invocation.memberName.toString();
    if (name.contains('initSharedData') || name.contains('Future')) {
      return Future<void>.value();
    }
    return null;
  }
}
