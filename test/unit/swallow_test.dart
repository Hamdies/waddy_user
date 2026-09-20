import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/util/swallow.dart';

/// `swallow` replaced 39 bare `catch (_) {}` blocks.
///
/// The point is not that it does something clever — it is that ignoring a
/// failure now requires writing down *why*, so a reader can tell a considered
/// decision from an oversight. `catch (_) {}` made those two look identical,
/// and `location_controller.dart` still carries a comment about the time that
/// cost: *"a bare empty catch here hid a hanging zone lookup for a long time"*.
///
/// What must hold: it never throws. A handler that can itself fail is worse
/// than the silence it replaced, because the exception escapes from inside the
/// `catch` that was supposed to contain it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('swallow never escapes', () {
    test('a plain call does not throw', () {
      expect(
        () => swallow('unit test', Exception('boom')),
        returnsNormally,
      );
    });

    test('a call with a stack trace does not throw', () {
      expect(
        () => swallow('unit test', Exception('boom'), StackTrace.current),
        returnsNormally,
      );
    });

    test('report: true does not throw even with no Firebase app', () {
      // This is the assertion that matters. There is no initialised Firebase
      // in a unit test, so `recordError` fails — and `swallow` has to absorb
      // that too, or every reporting call site becomes a crash.
      expect(
        () => swallow('unit test', Exception('boom'), StackTrace.current, true),
        returnsNormally,
      );
    });

    test('an Error, not just an Exception, is handled', () {
      expect(
        () => swallow('unit test', StateError('bad state')),
        returnsNormally,
      );
    });

    test('a null stack trace is accepted', () {
      expect(
        () => swallow('unit test', Exception('boom'), null, true),
        returnsNormally,
      );
    });
  });

  group('it works inside a real catch', () {
    test('the enclosing function continues after a swallowed failure', () {
      // The shape every call site uses: the failure is absorbed and the caller
      // carries on with a fallback.
      String attempt() {
        try {
          throw Exception('inner');
        } catch (e, s) {
          swallow('unit test fallback', e, s);
          return 'fallback';
        }
      }

      expect(attempt(), 'fallback');
    });

    test('a reported failure still lets the caller continue', () {
      int attempt() {
        try {
          throw StateError('inner');
        } catch (e, s) {
          swallow('unit test reported', e, s, true);
          return -1;
        }
      }

      expect(attempt(), -1);
    });
  });
}
