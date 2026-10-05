import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/common/widgets/mccoin_mood.dart';

void main() {
  /// Guards the mood-artboard names against a re-export of `waddy_mascot.riv` that
  /// renames or drops a board: [McCoinMoodAnimation] falls back to an EMPTY box
  /// when a name misses, so a rename would silently blank the out-of-zone sheet
  /// rather than throw.
  test('every McCoinMood artboard name exists in waddy_mascot.riv', () {
    final bytes = File('assets/animation/waddy_mascot.riv').readAsBytesSync();
    for (final mood in McCoinMood.values) {
      final name = mood.artboard;
      final needle = [name.length, ...name.codeUnits];
      var found = false;
      for (var i = 0; i + needle.length <= bytes.length; i++) {
        var hit = true;
        for (var j = 0; j < needle.length; j++) {
          if (bytes[i + j] != needle[j]) {
            hit = false;
            break;
          }
        }
        if (hit) {
          found = true;
          break;
        }
      }
      expect(found, isTrue, reason: 'artboard "$name" missing from waddy_mascot.riv');
    }
  });

  /// The crop constants in [McCoinMoodAnimation] are measured pixel offsets,
  /// not layout values — nothing in the type system ties them to the art. This
  /// pins the geometry they produce so a careless edit to one of them shows up
  /// as a failure rather than as a caption creeping back into the sheet.
  test('crop keeps the character framed and the caption out', () {
    const inkTop = 0.223, inkBottom = 0.775, pad = 0.06;
    const captionTop = 0.871;

    const span = (inkBottom - inkTop) / (1 - 2 * pad);
    const size = 160.0;
    const box = size / span;
    const shiftY = -(inkTop - pad * span) * box;

    // Where each landmark lands inside the visible slot, 0..1 from its top.
    double slotPos(double artboardFraction) =>
        (artboardFraction * box + shiftY) / size;

    expect(
      slotPos(inkTop),
      closeTo(pad, 0.001),
      reason: 'character should start at the top margin',
    );
    expect(
      slotPos(inkBottom),
      closeTo(1 - pad, 0.001),
      reason: 'character should end at the bottom margin',
    );
    expect(
      slotPos(captionTop),
      greaterThan(1.0),
      reason: 'caption must fall outside the clip entirely',
    );
  });
}
