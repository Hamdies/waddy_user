import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/util/parse.dart';

/// `Parse` replaces raw `int.parse` / `double.parse` on server and URL values.
///
/// The split is the point. A single never-throws helper would default a
/// missing price to `0`, which is a plausible wrong number that flows into an
/// order and a payment — worse than the crash it replaced. So money,
/// quantities and identifiers go through the strict tier and come back `null`,
/// forcing the caller to decide.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the backend sends numbers as both numbers and strings', () {
    test('a JSON number parses', () {
      expect(Parse.lenientInt(42), 42);
      expect(Parse.lenientDouble(12.5), 12.5);
    });

    test('a quoted number parses', () {
      // This is why every call site used to write `.toString()` first.
      expect(Parse.lenientInt('42'), 42);
      expect(Parse.lenientDouble('12.5'), 12.5);
    });

    test('an int is readable as a double and vice versa', () {
      expect(Parse.lenientDouble(42), 42.0);
      expect(Parse.lenientInt(42.0), 42);
    });

    test('surrounding whitespace is tolerated', () {
      expect(Parse.lenientInt('  42 '), 42);
      expect(Parse.lenientDouble(' 12.5 '), 12.5);
    });
  });

  group('absent values', () {
    test('null, empty and the literal string "null" are all absent', () {
      // The backend sends the string "null" in several places, and the route
      // table already checks for it by hand.
      for (final Object? v in <Object?>[null, '', '   ', 'null']) {
        expect(Parse.lenientInt(v, fallback: -1), -1, reason: 'int of $v');
        expect(Parse.lenientDouble(v, fallback: -1), -1, reason: 'double of $v');
        expect(Parse.strictInt(v, 'test'), isNull, reason: 'strictInt of $v');
        expect(Parse.coordinate(v), isNull, reason: 'coordinate of $v');
      }
    });

    test('the lenient fallback is configurable', () {
      expect(Parse.lenientInt(null), 0);
      expect(Parse.lenientInt(null, fallback: 99), 99);
    });
  });

  group('malformed values do not throw', () {
    test('junk strings are absent, not exceptions', () {
      for (final String v in <String>['abc', '12,50', '1.2.3', '\$5']) {
        expect(() => Parse.lenientDouble(v), returnsNormally);
        expect(Parse.lenientDouble(v, fallback: -1), -1, reason: v);
      }
    });

    test('a comma decimal separator is NOT silently reinterpreted', () {
      // "12,50" is twelve-and-a-half in Arabic/European formatting. Guessing
      // would be worse than refusing: a mis-guess changes a price.
      expect(Parse.strictDouble('12,50', 'price'), isNull);
    });
  });

  group('strict tier — money, quantities, identifiers', () {
    test('a readable value comes back normally', () {
      expect(Parse.strictDouble('19.99', 'price'), 19.99);
      expect(Parse.strictInt('3', 'quantity'), 3);
    });

    test('an unreadable value is null, never a substituted number', () {
      // The whole reason this tier exists. `0` here would be a silent
      // wrong price.
      expect(Parse.strictDouble('abc', 'price'), isNull);
      expect(Parse.strictInt('abc', 'quantity'), isNull);
    });

    test('reporting an unreadable value does not itself throw', () {
      // It reports through `swallow`, which reaches Crashlytics. There is no
      // Firebase app in a unit test, so this asserts the reporting path is
      // absorbed rather than escaping into the caller's parse.
      expect(() => Parse.strictInt('abc', 'quantity'), returnsNormally);
      expect(() => Parse.strictDouble(null, 'price'), returnsNormally);
    });

    test('a fractional value is not silently truncated to an int', () {
      // A quantity of 2.5 becoming 2 is a wrong order, not a rounding nit.
      expect(Parse.strictInt(2.5, 'quantity'), isNull);
      expect(Parse.strictInt(2.0, 'quantity'), 2);
    });
  });

  group('coordinates', () {
    test('real Maadi coordinates survive', () {
      expect(Parse.coordinate('29.9602'), 29.9602);
      expect(Parse.coordinate('31.2569'), 31.2569);
      expect(Parse.coordinate(30.116), 30.116);
    });

    test('negative coordinates are valid', () {
      expect(Parse.coordinate('-33.9249'), -33.9249);
    });

    test('an unreadable coordinate is null, not zero', () {
      // Zero is a VALID latitude — it is in the Gulf of Guinea. Defaulting a
      // broken coordinate to 0 puts a map pin in the Atlantic and makes a
      // distance calculation nonsense.
      expect(Parse.coordinate('abc'), isNull);
      expect(Parse.coordinate(null), isNull);
      expect(Parse.coordinate(''), isNull);
    });

    test('a genuine zero is still zero', () {
      expect(Parse.coordinate('0'), 0.0);
      expect(Parse.coordinate(0), 0.0);
    });

    test('out-of-range values are rejected', () {
      expect(Parse.coordinate('999'), isNull);
      expect(Parse.coordinate('-999'), isNull);
    });
  });

  group('the real payloads this replaces', () {
    test('order_details quantity — the crash that started this', () {
      // order_details_model.dart:129 was
      //   `quantity = int.parse(json['quantity'].toString())`
      // which threw on null and took down the whole order-details screen.
      final Map<String, dynamic> withNull = <String, dynamic>{'quantity': null};
      expect(() => Parse.strictInt(withNull['quantity'], 'quantity'),
          returnsNormally);
      expect(Parse.strictInt(withNull['quantity'], 'quantity'), isNull);
    });

    test('a seeded delivery time with no unit reads as a number', () {
      expect(Parse.lenientInt('30'), 30);
    });

    test('order_amount from a payload', () {
      expect(Parse.strictDouble('123.45', 'order_amount'), 123.45);
      expect(Parse.strictDouble(123.45, 'order_amount'), 123.45);
    });
  });
}
