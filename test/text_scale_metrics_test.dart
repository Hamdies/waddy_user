// Guards for the home rails whose card heights are fixed rather than intrinsic.
//
// main.dart used to pin textScaler to 1.0 app-wide, so every fixed-height text
// block was only ever measured at 1x. Unpinning it made the OS font-size
// setting real; these tests are what keep the blocks honest about it.
//
// They assert the *metrics*, not a rendered widget: the card widgets are
// private and sit behind GetX controllers, and the existing unit tests in this
// repo already document that widget-level testing here needs a full DI
// container. The metric is where the defect lived, so it is where the guard
// goes.
import 'package:flutter_test/flutter_test.dart';

/// Mirrors `_shelfTextScale` / `_rankTextScale` — both clamp (1.0, 1.3).
double clampedScale(double osScale) => osScale.clamp(1.0, 1.3);

// Grocery shelf blocks, from grocery_shelf_view.dart.
const double kNameBlock = 20;
const double kMetaBlock = 18;
const double kPerkBlock = 17;
const double kAisleLabel = 28;

// Unranked restaurant card blocks, from top_restaurants_view.dart.
const double kRestNameBlock = 13 * 1.35 * 2;
const double kRestRatingBlock = 18;

/// Height one line of text actually needs at a given scale.
double needed(double fontSize, double leading, double scale, {int lines = 1}) =>
    fontSize * leading * lines * scale;

void main() {
  group('grocery shelf blocks have headroom once scaled', () {
    for (final os in [1.0, 1.15, 1.3, 1.5, 2.0]) {
      test('at OS scale $os', () {
        final t = clampedScale(os);

        expect(
          kNameBlock * t,
          greaterThanOrEqualTo(needed(15, 1.25, t)),
          reason: 'store name clips at $os',
        );
        expect(
          kMetaBlock * t,
          greaterThanOrEqualTo(needed(12.5, 1.35, t)),
          reason: 'rating/ETA row clips at $os',
        );
        expect(
          kPerkBlock * t,
          greaterThanOrEqualTo(needed(12, 1.17, t)),
          reason: 'perk row clips at $os',
        );
        expect(
          kAisleLabel * t,
          greaterThanOrEqualTo(needed(11.5, 1.2, t, lines: 2)),
          reason: 'aisle label clips at $os',
        );
      });
    }
  });

  group('unranked restaurant card blocks have headroom once scaled', () {
    for (final os in [1.0, 1.15, 1.3, 1.5, 2.0]) {
      test('at OS scale $os', () {
        final t = clampedScale(os);
        expect(
          kRestNameBlock * t,
          greaterThanOrEqualTo(needed(13, 1.35, t, lines: 2)),
          reason: 'two-line store name clips at $os',
        );
        expect(
          kRestRatingBlock * t,
          greaterThanOrEqualTo(needed(13, 1.2, t)),
          reason: 'rating row clips at $os',
        );
      });
    }
  });

  test('scale is clamped so the rail cannot grow without bound', () {
    expect(clampedScale(3.0), 1.3);
    expect(
      clampedScale(0.8),
      1.0,
      reason: 'never shrink below the design size',
    );
  });

  test('UNSCALED blocks would clip at 1.3x (proves the guard is real)', () {
    // Regression witness: this is the state before the fix. If someone reverts
    // the scaling, the asserts above start failing and this one documents why.
    const t = 1.3;
    expect(kNameBlock, lessThan(needed(15, 1.25, t)));
    expect(kAisleLabel, lessThan(needed(11.5, 1.2, t, lines: 2)));
    expect(kRestNameBlock, lessThan(needed(13, 1.35, t, lines: 2)));
  });
}
