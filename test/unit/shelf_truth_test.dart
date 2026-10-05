import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/helpers/item_count_label.dart';
import 'package:waddy_app/features/store/helpers/pack_size.dart';
import 'package:waddy_app/features/store/helpers/shelf_listings.dart';

class _Strings extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {
      'n_items_one': '1 item',
      'n_items_two': '@n items',
      'n_items_few': '@n items',
      'n_items_other': '@n items',
    },
    'ar_EG': {
      'n_items_one': 'منتج واحد',
      'n_items_two': 'منتجان',
      'n_items_few': '@n منتجات',
      'n_items_other': '@n منتج',
    },
  };
}

void main() {
  group('PackSize', () {
    // The screenshot's cards, each of which printed "Kilogram".
    final cases = <String, (String, String?)>{
      'Caesar Dressing 250ml': ('Caesar Dressing', '250 ml'),
      'Heinz Ketchup 125g': ('Heinz Ketchup', '125 g'),
      'Clorox for Colors 950ml': ('Clorox for Colors', '950 ml'),
      'Paper Plates 20pcs': ('Paper Plates', '20 pcs'),
      'Fresh Tomatoes 1kg': ('Fresh Tomatoes', '1 kg'),
      'Facial Tissues 500 Sheets': ('Facial Tissues', '500 sheets'),
      'Juice - 1.5 Ltr': ('Juice', '1.5 L'),
      'Juhayna Milk (1L)': ('Juhayna Milk', '1 L'),
      'Water 6 x 1.5L': ('Water', '6 × 1.5 L'),
      'لبن جهينة 1 لتر': ('لبن جهينة', '1 لتر'),
      // Mid-name size: part of how the product is called, name kept whole.
      '1L Bottle Water': ('1L Bottle Water', '1 L'),
      // Not sizes.
      '7Up Can': ('7Up Can', null),
      'Size 2 large eggs': ('Size 2 large eggs', null),
      'Garnier Micellar Water': ('Garnier Micellar Water', null),
    };
    cases.forEach((input, expected) {
      test(input, () {
        final pack = PackSize.of(input);
        expect(pack.name, expected.$1);
        expect(pack.size, expected.$2);
      });
    });

    test('the name\'s size beats a contradicting unit', () {
      expect(PackSize.secondLine('Heinz Ketchup 125g', 'Kilogram'), '125 g');
    });
    test('the unit stands when the name states no size', () {
      expect(PackSize.secondLine('Bananas', 'Kilogram'), 'Kilogram');
      expect(PackSize.secondLine('Bananas', '  '), isNull);
    });
  });

  group('ShelfListings.dedupe', () {
    Item item(int id, String name, {String? image, int? catalog}) => Item(
      id: id,
      name: name,
      imageFullUrl: image,
      catalogProductId: catalog,
    );

    test('same name twice keeps the copy with a photo, in place', () {
      final out = ShelfListings.dedupe([
        item(1, 'Fresh Tomatoes 1kg'),
        item(2, 'Bananas 1kg', image: 'b.png'),
        item(3, 'fresh  tomatoes 1KG', image: 't.png'),
      ]);
      expect(out.map((i) => i.id), [3, 2]);
    });

    test('a shared catalogue product is one product whatever the name', () {
      final out = ShelfListings.dedupe([
        item(1, 'Juhayna Milk 1L', catalog: 9),
        item(2, 'لبن جهينة 1 لتر', catalog: 9),
      ]);
      expect(out.map((i) => i.id), [1]);
    });

    test('different sizes stay apart', () {
      final out = ShelfListings.dedupe([
        item(1, 'Fresh Tomatoes 1kg'),
        item(2, 'Fresh Tomatoes 2kg'),
      ]);
      expect(out.length, 2);
    });
  });

  group('itemCountLabel', () {
    setUpAll(() {
      Get.addTranslations(_Strings().keys);
    });

    test('English', () {
      Get.locale = const Locale('en', 'US');
      expect(itemCountLabel(1), '1 item');
      expect(itemCountLabel(3), '3 items');
    });

    test('Arabic takes four forms', () {
      Get.locale = const Locale('ar', 'EG');
      expect(itemCountLabel(1), 'منتج واحد');
      expect(itemCountLabel(2), 'منتجان');
      expect(itemCountLabel(3), '3 منتجات');
      expect(itemCountLabel(10), '10 منتجات');
      expect(itemCountLabel(11), '11 منتج');
      expect(itemCountLabel(103), '103 منتجات');
    });
  });
}
