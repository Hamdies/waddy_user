import 'package:waddy_app/features/item/domain/models/item_model.dart';

/// One product, once per shelf.
///
/// A store can hold the same product twice: an unlinked copy left beside the
/// catalogue-linked listing (the catalogue's unique index only stops two
/// LINKED listings of one product, CAT-11). Side by side in a rail that read
/// as "Fresh Tomatoes 1kg 22 LE · Fresh Tomatoes 1kg 25 LE", and the shopper
/// can't tell which one is real. The cure is in the admin (link or switch off
/// the copy); this keeps the page honest until then.
class ShelfListings {
  ShelfListings._();

  /// [items] with repeats of one product dropped, order kept. Two listings
  /// are one product when they share a catalogue product, or carry the same
  /// name (the size is in the name, so "1kg" and "2kg" stay apart). Of a
  /// repeat, the copy with a photo is kept, else the first.
  static List<Item> dedupe(List<Item> items) {
    if (items.length < 2) return items;

    final List<Item> kept = [];
    final Map<String, int> slotOf = {};
    for (final Item item in items) {
      final List<String> keys = _keysOf(item);
      final int? slot = keys.map((k) => slotOf[k]).whereType<int>().firstOrNull;
      if (slot == null) {
        for (final k in keys) {
          slotOf[k] = kept.length;
        }
        kept.add(item);
      } else {
        if (!_hasPhoto(kept[slot]) && _hasPhoto(item)) kept[slot] = item;
        for (final k in keys) {
          slotOf.putIfAbsent(k, () => slot);
        }
      }
    }
    return kept.length == items.length ? items : kept;
  }

  static List<String> _keysOf(Item item) {
    final String name =
        (item.name ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return [
      if (item.catalogProductId != null) 'c:${item.catalogProductId}',
      if (name.isNotEmpty) 'n:$name',
    ];
  }

  static bool _hasPhoto(Item item) =>
      (item.imageFullUrl ?? '').trim().isNotEmpty;
}
