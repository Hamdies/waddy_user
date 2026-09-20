import 'package:get/get.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// Builds the screen-reader announcement for a store card.
///
/// Store cards render their facts as separate visual fragments — a name, a
/// star glyph beside a number, a clock beside a duration, a ribbon reading
/// "FREE DELIVERY". Sighted users read that as one object. A screen reader
/// walking the raw tree reads it as a pile of disconnected strings, several
/// of which ("4.7", "20-30") mean nothing on their own.
///
/// So the card gets one composed sentence instead, in the order a user
/// actually decides in: who it is, whether it's even open, how good it is,
/// how long it takes, what it saves.
String moduleStoreSemanticLabel(Store store) {
  final parts = <String>[];

  final name = store.name?.trim();
  if (name != null && name.isNotEmpty) parts.add(name);

  // Closed comes second, right after the name: it changes whether any of the
  // rest is worth hearing, and a screen-reader user should not have to reach
  // the end of the sentence to find out the place isn't taking orders.
  if (store.open != 1) parts.add('closed'.tr);

  final rating = store.avgRating;
  if (rating != null && rating > 0) {
    parts.add('${'rating'.tr} ${rating.toStringAsFixed(1)}');
  }

  final time = store.deliveryTime?.trim();
  if (time != null && time.isNotEmpty) parts.add('$time ${'min'.tr}');

  if (store.freeDelivery == true) parts.add('free_delivery'.tr);

  final discount = store.discount?.discount;
  if (discount != null && discount > 0) {
    parts.add('${discount.toInt()}% ${'off'.tr}');
  }

  return parts.join(', ');
}
