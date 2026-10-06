import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/helpers/store_delivery_fee.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';

/// Delivery time · delivered by · fee.
///
/// The one strip every store page wears — restaurants, supermarkets,
/// specialty shops and pet stores — so the same three promises read the same
/// way wherever the user lands.
///
/// These render identically in and out of zone. An out-of-zone visitor is
/// browsing, not buying: a half-empty strip told them something was wrong
/// without telling them what, and the answer ("we don't deliver here yet")
/// is one they only need at the moment they act. That moment is add-to-cart,
/// where [CartController.addToCartOnline] raises the NO DELIVERY sheet — so
/// the honesty is enforced at the gate rather than by hollowing out the page
/// ahead of it. The numbers themselves stay true: they describe the store,
/// not a promise to this address.
class StoreStatsStrip extends StatelessWidget {
  final Store store;

  /// Names the courier "store" rather than "restaurant" when a self-delivering
  /// store has no name to show.
  final bool isShop;

  /// Set when the strip sits in the store hero's mint, directly under the
  /// search bar. It then turns to frosted glass — the translucent white the
  /// hero's own chips used — so the mint shows through it and it fades out
  /// with the hero's gradient instead of sitting on it as a second solid box.
  /// The search bar above stays opaque, which keeps it the primary control.
  /// On the white canvas (the menu page) there is nothing to blend with, so it
  /// stays the plain bordered card.
  final bool onHero;

  const StoreStatsStrip({
    super.key,
    required this.store,
    this.isShop = false,
    this.onHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool freeDelivery = store.freeDelivery ?? false;
    final String? time =
        (store.deliveryTime ?? '').trim().isEmpty
            ? null
            : store.deliveryTime!.trim();

    final double minimum = store.minimumOrder ?? 0;

    // Who actually carries the order.
    //
    // `selfDeliverySystem == 1` is the store running its own fleet on its own
    // per-km rates — the checkout calculator branches on exactly this flag to
    // decide whose shipping charges to apply, so it is a real operational
    // difference and not a cosmetic one. The cell used to answer "Waddy" for
    // every store, which made it decoration; naming the restaurant when the
    // restaurant is the courier is what makes it worth its third of the row.
    //
    // It also sets expectations the two couriers genuinely differ on — live
    // tracking and support reach Waddy's riders, not a restaurant's.
    final bool selfDelivery = store.selfDeliverySystem == 1;
    final String courier =
        selfDelivery
            ? (store.name ?? (isShop ? 'store'.tr : 'restaurant'.tr))
            : AppConstants.appName;

    // What the fee cell can honestly claim.
    //
    // `StoreDeliveryFee` runs the same ladder checkout runs, so the number
    // quoted here is the number charged later — and it returns null instead of
    // guessing when the rates or the distance cannot be trusted. Where it
    // returns null the minimum order takes the slot, exactly as before.
    final double? fee = StoreDeliveryFee.estimate(
      store: store,
      address: AddressHelper.getUserAddressFromSharedPref(),
    );

    final List<Widget> cells = [
      if (time != null)
        _statCell(
          label: 'delivery_time'.tr,
          value: time,
          valueColor: WaddyColors.primary,
        ),
      _statCell(
        label: 'delivered_by'.tr,
        value: courier,
        valueColor: WaddyColors.ink,
        valueMaxLines: 2,
        // Waddy's own riders wear Waddy's mark; a restaurant's fleet does not.
        leading:
            selfDelivery
                ? null
                : Image.asset(Images.waddyLogo, width: 18, fit: BoxFit.contain),
      ),
      // Free delivery strikes the fee it replaced rather than just saying
      // "Free": the struck number is what makes free read as a SAVING instead
      // of as this store's ordinary price. With no computable fee there is
      // nothing to strike, and an invented "was" price would manufacture a
      // discount that does not exist — so that case shows the word alone.
      if (freeDelivery || fee != null)
        _feeCell(freeDelivery: freeDelivery, fee: fee),
      // The minimum is its own cell rather than the fee's fallback. Both facts
      // can be true at once — a store CAN deliver free above a minimum — and
      // the old either/or hid the minimum from exactly those stores, which are
      // the ones where knowing it matters most. It only renders when the fee
      // cell did not already fill the row, so the strip stays at three.
      if (!freeDelivery && fee == null && minimum > 0)
        _statCell(
          label: 'minimum_order'.tr,
          value: PriceConverter.convertPrice(minimum),
          valueColor: WaddyColors.ink,
        ),
    ];

    final Color divider =
        onHero
            ? WaddyColors.surface.withValues(alpha: 0.75)
            : WaddyColors.divider;

    return Container(
      decoration: BoxDecoration(
        color:
            onHero
                ? WaddyColors.surface.withValues(alpha: 0.55)
                : WaddyColors.surface,
        border: Border.all(
          color:
              onHero
                  ? WaddyColors.surface.withValues(alpha: 0.8)
                  : WaddyColors.divider,
        ),
        borderRadius: BorderRadius.circular(onHero ? 14 : 15),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < cells.length; i++) ...[
              if (i > 0)
                VerticalDivider(width: 1, thickness: 1, color: divider),
              Expanded(child: cells[i]),
            ],
          ],
        ),
      ),
    );
  }

  /// The delivery-fee cell, which is the only one that shows two values.
  ///
  /// Free delivery is a SAVING, and a saving needs the thing it saved you from
  /// — so the fee this store would otherwise have charged is struck through
  /// beside a green "Free". The same grammar the menu rows use for a
  /// discounted price, which is why it reads instantly here.
  ///
  /// Three shapes:
  ///   • free, fee known    → `35 LE  Free`   (struck grey, then green)
  ///   • free, fee unknown  → `Free`          (nothing to strike)
  ///   • not free           → `35 LE`         (plain ink)
  static Widget _feeCell({required bool freeDelivery, required double? fee}) {
    final String? feeLabel =
        fee == null ? null : PriceConverter.convertPrice(fee);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'delivery_fee'.tr,
            textAlign: TextAlign.center,
            style: waddyMedium.copyWith(
              fontSize: 11.5,
              color: WaddyColors.inkLight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Wrap, not Row: at the system's larger text sizes "35 LE Free" does
          // not fit a third of the screen on one line, and a struck price that
          // ellipsizes away leaves a bare "Free" that has lost its point.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            children: [
              if (feeLabel != null)
                Text(
                  feeLabel,
                  style: waddyBold.copyWith(
                    fontSize: 14,
                    // Struck only when something replaced it. Without free
                    // delivery this IS the price, and striking it would say
                    // the opposite of what is true.
                    color:
                        freeDelivery ? WaddyColors.inkMuted : WaddyColors.ink,
                    decoration:
                        freeDelivery ? TextDecoration.lineThrough : null,
                    decorationColor: WaddyColors.inkMuted,
                  ),
                  maxLines: 1,
                ),
              if (freeDelivery)
                Text(
                  'free'.tr,
                  style: waddyBold.copyWith(
                    fontSize: 14,
                    color: WaddyColors.mintInk,
                  ),
                  maxLines: 1,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// One cell of the stats strip.
  ///
  /// [valueMaxLines] exists for the courier cell. Every other value here is a
  /// short token ("20-35", "Free", "120 LE") that cannot overflow a third of
  /// the screen, but the courier's value is a STORE NAME — and a name clipped
  /// to "Vinny's Piz…" fails at the one job this cell has, which is saying who
  /// is carrying the order. It gets a second line; the rest stay at one so a
  /// long translation cannot silently make the strip taller.
  static Widget _statCell({
    required String label,
    required String value,
    required Color valueColor,
    int valueMaxLines = 1,
    Widget? leading,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Two lines, not one. At the system's larger text sizes a
          // single-line "Delivery Time" truncated to "Delivery T…" — the cell
          // stopped naming its own number, which is the one thing a label has
          // to do. Wrapping costs a few points of height the strip can absorb;
          // ellipsis cost the meaning.
          Text(
            label,
            textAlign: TextAlign.center,
            style: waddyMedium.copyWith(
              fontSize: 11.5,
              color: WaddyColors.inkLight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (leading == null)
            Text(
              value,
              textAlign: TextAlign.center,
              style: waddyBold.copyWith(fontSize: 14, color: valueColor),
              maxLines: valueMaxLines,
              overflow: TextOverflow.ellipsis,
            )
          else
            // [leading] is a mark, not text, so it sits beside the value
            // instead of inside it and the value keeps its own ellipsis.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading,
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: waddyBold.copyWith(fontSize: 14, color: valueColor),
                    maxLines: valueMaxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
