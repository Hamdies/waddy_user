import 'package:get/get.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/price_converter.dart';

/// Badge text for a store's own offers that the `discount` field can't carry
/// (store app → Offers). The % offer still shows through `discount`.
class StoreOfferLabel {
  StoreOfferLabel._();

  /// "EGP 50 OFF", or null when no amount-off offer is live.
  static String? amountOff(Store store) {
    final offer = store.liveOffer('amount');
    return offer == null ? null : 'offer_amount_off'.trParams({'amount': PriceConverter.convertPrice(offer.value)});
  }

  /// "Free delivery over EGP 150" ("Free delivery" with no minimum), or null.
  static String? freeDelivery(Store store) {
    final offer = store.liveOffer('free_delivery');
    if (offer == null) return null;
    return offer.minOrder > 0 ? 'offer_free_delivery_over'.trParams({'amount': PriceConverter.convertPrice(offer.minOrder)}) : 'free_delivery'.tr;
  }
}
