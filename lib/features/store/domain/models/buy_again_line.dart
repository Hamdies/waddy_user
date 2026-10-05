import 'package:waddy_app/features/item/domain/models/item_model.dart';

/// One item in a store's "Buy again", and how it was bought last time — its
/// variation (the weight, e.g. "2kg") and produce answer — so "+" can
/// repeat that exact line.
class BuyAgainLine {
  final Item item;
  final String? variationType;
  final String? preference;

  const BuyAgainLine({required this.item, this.variationType, this.preference});

  factory BuyAgainLine.fromJson(Map<String, dynamic> json) => BuyAgainLine(
    item: Item.fromJson(json),
    variationType:
        json['last_variation'] is String ? json['last_variation'] : null,
    preference:
        json['last_preference'] is String ? json['last_preference'] : null,
  );
}
