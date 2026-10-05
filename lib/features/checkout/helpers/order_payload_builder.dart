import 'package:get/get.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/checkout/domain/models/place_order_body_model.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';

/// Turns cart lines into the `OnlineCart` list an order is sent as.
///
/// `CS-07`: this ~40-line loop existed verbatim twice in
/// `checkout_screen.dart` — once at `:470` for the tax quote and once at
/// `:1235` for the order itself. Two copies meant any change to how a cart
/// line becomes an order line had to be made twice, and `CS-02` is the
/// evidence that such a change was already missed once.
///
/// Extracted rather than rewritten: the body below is the loop as it stood,
/// so this is a deduplication and not a behaviour change.
class OrderPayloadBuilder {
  const OrderPayloadBuilder._();

  /// The `cart` field of both the tax quote and the order.
  ///
  /// [isCampaign] mirrors the screen's `!widget.fromCart` — a campaign item
  /// carries a different `item_type`, which is the only thing the two call
  /// sites ever varied.
  static List<OnlineCart> buildCartLines({
    required List<CartModel?>? cartList,
    required bool isCampaign,
  }) {
    final List<OnlineCart> carts = <OnlineCart>[];
    if (cartList == null) return carts;

    for (final CartModel? entry in cartList) {
      if (entry == null) continue;
      final CartModel cart = entry;

      final List<int?> addOnIdList = <int?>[];
      final List<int?> addOnQtyList = <int?>[];
      for (final AddOn addOn in cart.addOnIds!) {
        addOnIdList.add(addOn.id);
        addOnQtyList.add(addOn.quantity);
      }

      // Read once per line instead of the four `Get.find` calls per line the
      // duplicated loops made — same answer, and `getModuleConfig` is cached.
      final bool newVariation =
          Get.find<SplashController>()
              .getModuleConfig(cart.item!.moduleType)
              .newVariation!;

      final List<OrderVariation> variations = <OrderVariation>[];
      if (newVariation) {
        for (int i = 0; i < cart.item!.foodVariations!.length; i++) {
          if (!cart.foodVariations![i].contains(true)) continue;

          final OrderVariation variation = OrderVariation(
            name: cart.item!.foodVariations![i].name,
            values: OrderVariationValue(label: <String?>[]),
          );
          variations.add(variation);

          for (
            int j = 0;
            j < cart.item!.foodVariations![i].variationValues!.length;
            j++
          ) {
            if (cart.foodVariations![i][j]!) {
              variation.values!.label!.add(
                cart.item!.foodVariations![i].variationValues![j].level,
              );
            }
          }
        }
      }

      carts.add(
        OnlineCart(
          cart.id,
          cart.item!.id,
          cart.isCampaign! ? cart.item!.id : null,
          cart.discountedPrice.toString(),
          '',
          newVariation ? null : cart.variation,
          newVariation ? variations : null,
          cart.quantity,
          addOnIdList,
          cart.addOns,
          addOnQtyList,
          'Item',
          itemType: isCampaign ? 'AppModelsItemCampaign' : null,
          preference: cart.preference,
        ),
      );
    }

    return carts;
  }
}
