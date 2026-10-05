/// The pack size a product's own name states ("Heinz Ketchup 125g"), split
/// off so a card can show the name and the size on separate lines.
///
/// The name is the one source on a supermarket listing that says what is in
/// the pack. The listing's unit (`unit_type`) is a separate admin field, and
/// live data has it wrong wherever it was left on a default: "Kilogram" under
/// a 250ml dressing, 950ml of bleach and a box of tissues. So a size in the
/// name wins, and the unit is shown only when the name states none.
class PackSize {
  /// The name with a trailing size taken off ("Heinz Ketchup"); the full
  /// name when the size sits mid-name or there is none.
  final String name;

  /// The size, tidied ("125 g", "6 × 200 ml"), or null when the name has none.
  final String? size;

  const PackSize._(this.name, this.size);

  /// A number (Latin or Arabic-Indic digits, optional decimal), an optional
  /// multipack prefix ("6 x"), then a unit that does not run on into a word —
  /// so "2 large" is not "2 l" and "7Up" is not a size.
  static final RegExp _size = RegExp(
    r'(?:([0-9٠-٩]+)\s*[x×]\s*)?'
    r'([0-9٠-٩]+(?:[.,٫][0-9٠-٩]+)?)\s*'
    r'(kgs?|kilos?|kilograms?|grams?|gms?|gr|g|mg|litres?|liters?|ltrs?|lt|l|ml|cl'
    r'|pcs|pc|pieces?|packs?|sheets?|rolls?|bags?|tabs?|capsules?'
    r'|sticks?|chews?|cans?|pouch(?:es)?|pads?|treats?'
    r'|كجم|كيلو(?:جرام)?|جم|جرام|مل|لتر|قطعة|قطع|كيس|أكياس)'
    r'(?![A-Za-z؀-ۿ])',
    caseSensitive: false,
  );

  /// Separators a trailing size leaves behind ("Juice - 1L", "Tissues (500)").
  static final RegExp _trailingJunk = RegExp(r'[\s\-–—,·(/]+$');

  static const Map<String, String> _short = {
    'kg': 'kg',
    'kgs': 'kg',
    'kilo': 'kg',
    'kilos': 'kg',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'gram': 'g',
    'grams': 'g',
    'gm': 'g',
    'gms': 'g',
    'gr': 'g',
    'g': 'g',
    'mg': 'mg',
    'litre': 'L',
    'litres': 'L',
    'liter': 'L',
    'liters': 'L',
    'ltr': 'L',
    'ltrs': 'L',
    'lt': 'L',
    'l': 'L',
    'ml': 'ml',
    'cl': 'cl',
    'pcs': 'pcs',
    'pc': 'pcs',
    'piece': 'pcs',
    'pieces': 'pcs',
    'pack': 'pack',
    'packs': 'packs',
    'sheet': 'sheets',
    'sheets': 'sheets',
    'roll': 'rolls',
    'rolls': 'rolls',
    'bag': 'bags',
    'bags': 'bags',
    'tab': 'tabs',
    'tabs': 'tabs',
    'capsule': 'capsules',
    'capsules': 'capsules',
    // Pet packs count what is inside ("Dentastix, 7 sticks").
    'stick': 'sticks',
    'sticks': 'sticks',
    'chew': 'chews',
    'chews': 'chews',
    'can': 'cans',
    'cans': 'cans',
    'pouch': 'pouches',
    'pouches': 'pouches',
    'pad': 'pads',
    'pads': 'pads',
    'treat': 'treats',
    'treats': 'treats',
  };

  factory PackSize.of(String? rawName) {
    final String name = (rawName ?? '').trim();
    if (name.isEmpty) return const PackSize._('', null);

    final List<RegExpMatch> matches = _size.allMatches(name).toList();
    if (matches.isEmpty) return PackSize._(name, null);

    // The last size is the pack's ("Pampers Size 4 - 52 pcs" → 52 pcs).
    final RegExpMatch m = matches.last;
    final String? multi = m.group(1);
    final String amount = m.group(2)!;
    final String unitRaw = m.group(3)!;
    final String unit = _short[unitRaw.toLowerCase()] ?? unitRaw;
    final String size =
        multi != null ? '$multi × $amount $unit' : '$amount $unit';

    // Only a size at the END comes off the name: one mid-name ("1L Bottle
    // Water") is part of how the product is called.
    final String after = name
        .substring(m.end)
        .replaceAll(RegExp(r'[\s)\]]'), '');
    if (after.isNotEmpty) return PackSize._(name, size);

    final String stripped =
        name.substring(0, m.start).replaceAll(_trailingJunk, '').trim();
    return PackSize._(stripped.isEmpty ? name : stripped, size);
  }

  /// What a pack of [size] ("110 ml", "6 × 200 ml", "1.5 kg") costs per
  /// common measure, so two sizes of one product can be compared: per 100 g /
  /// 100 ml for a small pack, per kg / L once the pack holds a kilo or more.
  /// Null for sizes that are not a weight or a volume, for a pack that already
  /// IS the measure (100 ml), and for a price that is not a number.
  static ({double price, String per})? unitPrice(String? size, double price) {
    if (size == null || price <= 0) return null;
    final RegExpMatch? m = RegExp(
      r'^(?:([0-9]+)\s*×\s*)?([0-9]+(?:[.,][0-9]+)?)\s*(kg|g|L|ml|cl)$',
    ).firstMatch(size.trim());
    if (m == null) return null;
    final double count = double.tryParse(m.group(1) ?? '1') ?? 1;
    final double amount =
        double.tryParse(m.group(2)!.replaceAll(',', '.')) ?? 0;
    if (amount <= 0 || count <= 0) return null;
    // Everything in grams or millilitres.
    final double base = switch (m.group(3)) {
      'kg' || 'L' => 1000,
      'cl' => 10,
      _ => 1,
    };
    final bool weight = m.group(3) == 'kg' || m.group(3) == 'g';
    final double total = count * amount * base;
    if (total <= 0) return null;
    final bool big = total >= 1000;
    final double measure = big ? 1000 : 100;
    // The pack IS the measure: its per-unit price would only repeat the price.
    if ((total - measure).abs() < 0.001) return null;
    return (
      price: price / total * measure,
      per: big ? (weight ? 'kg' : 'L') : (weight ? '100 g' : '100 ml'),
    );
  }

  /// The second line a card prints under the name: the size the name states,
  /// else the listing's unit, else nothing.
  static String? secondLine(String? name, String? unitType) {
    final String? size = PackSize.of(name).size;
    if (size != null) return size;
    final String? unit = unitType?.trim();
    return unit == null || unit.isEmpty ? null : unit;
  }
}
