import 'package:get/get.dart';

/// The one question produce asks before it goes in the cart.
///
/// An admin marks a category `ripeness` (fruit) or `use` (vegetables); the
/// backend resolves it onto every item under it as `prep_option`. The shopper
/// must pick an answer before adding, and it rides on the cart line
/// (`preference`) into the order for whoever picks it. It never changes
/// price or stock. Codes match the backend's `ProducePreference::OPTIONS`.
class ProducePreference {
  ProducePreference._();

  static const Map<String, List<String>> _answers = {
    'ripeness': ['ready_to_eat', 'ripe_later'],
    'use': ['salad', 'cooking'],
  };

  /// The answers [option] offers, as codes; empty for an unknown option.
  static List<String> answersFor(String? option) =>
      _answers[option] ?? const <String>[];

  /// Whether [option] is a question this app knows how to ask.
  static bool asks(String? option) => _answers.containsKey(option);

  /// "Ripeness" / "Use it for".
  static String title(String option) => 'prep_title_$option'.tr;

  /// "Ready to eat", "For salad" — or null for a code this build doesn't know.
  static String? label(String? code) {
    if (code == null) return null;
    for (final answers in _answers.values) {
      if (answers.contains(code)) return 'preference_$code'.tr;
    }
    return null;
  }

  /// One line under the answer, saying what it means.
  static String hint(String code) => 'preference_${code}_hint'.tr;
}
