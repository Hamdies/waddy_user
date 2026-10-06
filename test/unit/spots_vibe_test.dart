import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/domain/spots_vibe.dart';
import 'package:waddy_app/features/xp/widgets/xp_motion.dart';

Place _p(int id) => Place(id: id, title: 'Spot $id');

void main() {
  test('only the gem and the flash are used, and a card keeps its icon', () {
    final seen = {for (var i = 0; i < 40; i++) SpotsVibe.forPlace(_p(i))};
    expect(seen, {XpIcon.diamond, XpIcon.flash});
    expect(SpotsVibe.forPlace(_p(7)), SpotsVibe.forPlace(_p(7)));
  });

  test('neighbouring ids alternate', () {
    expect(SpotsVibe.forPlace(_p(1)), isNot(SpotsVibe.forPlace(_p(2))));
  });
}
