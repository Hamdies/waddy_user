import 'package:get/get.dart';

/// "1 item", "3 items" — and in Arabic the four forms a count of products
/// takes: منتج واحد، منتجان، ٣ منتجات، ١١ منتج.
///
/// GetX has no ICU plurals, and one "@n منتج" read wrong for every count from
/// 2 to 10, which is most aisles. Keys: `n_items_one`, `_two`, `_few`
/// (3–10), `_other`; English fills `_two` and `_few` with its plural.
String itemCountLabel(int n) {
  final int rest = n % 100;
  final String form =
      n == 1
          ? 'one'
          : n == 2
          ? 'two'
          : rest >= 3 && rest <= 10
          ? 'few'
          : 'other';
  return 'n_items_$form'.trParams({'n': '$n'});
}
