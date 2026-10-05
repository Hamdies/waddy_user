import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/cart/widgets/pill_cart_bar.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// Whose minimum order the cart bar enforces (device, 10-01): a 150 LE Seoudi
/// cart read "Add 50 LE to start your order", greyed out, on Al Dahan's page,
/// because the bar applied Al Dahan's 200 LE minimum to Seoudi's basket.
void main() {
  final Store seoudi = Store(id: 40, name: 'Seoudi', minimumOrder: 100);
  final Store alDahan = Store(id: 52, name: 'Al Dahan', minimumOrder: 200);

  CartModel lineFrom(int storeId) => CartModel(
    1,
    50,
    50,
    <Variation>[],
    <List<bool?>>[],
    0,
    3,
    const <AddOn>[],
    const <AddOns>[],
    false,
    10,
    Item(id: 1, storeId: storeId, price: 50),
    10,
  );

  test('an empty cart is judged by the store on screen', () {
    expect(
      PillCartBar.rulesStoreFor(
        page: alDahan,
        cartList: const <CartModel>[],
        cartStore: null,
      ),
      same(alDahan),
    );
  });

  test('a cart from another store is judged by its own store', () {
    expect(
      PillCartBar.rulesStoreFor(
        page: alDahan,
        cartList: <CartModel>[lineFrom(40)],
        cartStore: seoudi,
      ),
      same(seoudi),
    );
  });

  test('on its own store\'s page, the page\'s copy is used', () {
    expect(
      PillCartBar.rulesStoreFor(
        page: seoudi,
        cartList: <CartModel>[lineFrom(40)],
        cartStore: null,
      ),
      same(seoudi),
    );
  });

  test('while the cart\'s store loads, no store-specific minimum applies', () {
    // Admin-wide rules for a moment beat the wrong store's minimum.
    expect(
      PillCartBar.rulesStoreFor(
        page: alDahan,
        cartList: <CartModel>[lineFrom(40)],
        cartStore: null,
      ),
      isNull,
    );
  });

  test('surfaces outside a store keep the admin-wide rules', () {
    expect(
      PillCartBar.rulesStoreFor(
        page: null,
        cartList: <CartModel>[lineFrom(40)],
        cartStore: seoudi,
      ),
      isNull,
    );
  });
}
