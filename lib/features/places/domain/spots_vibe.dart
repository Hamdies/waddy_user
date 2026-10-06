import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/xp/widgets/xp_motion.dart';

/// Which animated icon a venue card wears: the flash or the gem.
///
/// Cards used to carry a "NEW" / "FIRST APPEARANCE" chip, which was the same
/// word on every young spot and told you nothing about the place. Two icons
/// from the shared set keep the list lively without a table of moods to
/// maintain; the choice comes from the id, so a card keeps its icon between
/// renders and neighbouring spots usually differ.
class SpotsVibe {
  const SpotsVibe._();

  static const List<XpIcon> _icons = [XpIcon.diamond, XpIcon.flash];

  static XpIcon forPlace(Place place) => _icons[place.id.abs() % _icons.length];
}
