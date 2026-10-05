import 'package:flutter/material.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Checkout's sticky footer: where the order is going, how it is being paid,
/// and the button.
///
/// With no payment method chosen the button is "Select payment method" and
/// scrolls to the list rather than placing anything — the one decision still
/// missing is the one the button asks for.
class CheckoutBottomBar extends StatelessWidget {
  final CheckoutController checkoutController;
  final List<AddressModel> address;
  final int? storeId;

  /// Null while the order cannot be placed (terms not accepted).
  final VoidCallback? onPlaceOrder;

  /// Brings the "Pay with" list into view.
  final VoidCallback onChoosePayment;

  const CheckoutBottomBar({
    super.key,
    required this.checkoutController,
    required this.address,
    required this.storeId,
    required this.onPlaceOrder,
    required this.onChoosePayment,
  });

  @override
  Widget build(BuildContext context) {
    final bool noPayment =
        storeId == null && checkoutController.paymentMethodIndex == -1;

    return Container(
      decoration: const BoxDecoration(
        color: WaddyColors.surface,
        border: Border(top: BorderSide(color: WaddyColors.divider)),
        boxShadow: [
          BoxShadow(
            color: WaddyColors.shadowTeal,
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _destinationRow(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeDefault,
                Dimensions.paddingSizeMedium,
                Dimensions.paddingSizeDefault,
                Dimensions.paddingSizeMedium,
              ),
              child:
                  noPayment
                      ? CustomButton(
                        buttonText: 'select_payment_method'.tr,
                        onPressed: onChoosePayment,
                        radius: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'select_payment_method'.tr,
                              style: waddyBold.copyWith(
                                fontSize: Dimensions.fontSizeDefault,
                                color: WaddyColors.primary,
                              ),
                            ),
                            const SizedBox(
                              width: Dimensions.paddingSizeExtraSmall,
                            ),
                            CheckoutIcon(
                              icon: _forwardChevron(context),
                              size: 14,
                              color: WaddyColors.primary,
                            ),
                          ],
                        ),
                      )
                      : Row(
                        children: [
                          Expanded(flex: 4, child: _payUsing()),
                          const SizedBox(width: Dimensions.paddingSizeMedium),
                          Expanded(flex: 7, child: _placeOrderPill(context)),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _destinationRow(BuildContext context) {
    final bool takeAway = checkoutController.orderType == 'take_away';
    final AddressModel? selected =
        address.isNotEmpty &&
                (checkoutController.addressIndex ?? 0) < address.length
            ? address[checkoutController.addressIndex ?? 0]
            : null;

    // Home and Office read as places ("Delivering to Home"); "others" does
    // not ("Delivering to Others"), so that one gets a plain heading.
    final String? type = selected?.addressType;
    final bool namedPlace = type == 'home' || type == 'office';
    final String title =
        takeAway
            ? 'picking_up_from'.tr
            : namedPlace
            ? '${'delivering_to'.tr} '
            : '';
    final String emphasis =
        takeAway
            ? ' ${checkoutController.store?.name ?? ''}'
            : namedPlace
            ? type!.tr
            : 'delivery_address'.tr;
    final String line =
        takeAway
            ? (checkoutController.store?.address ?? '')
            : (selected?.address ?? 'tap_to_set_address'.tr);

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeSmall,
        Dimensions.paddingSizeExtraSmall,
        Dimensions.paddingSizeSmall,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WaddyColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: WaddyColors.mintSurface,
            ),
            child: CheckoutIcon(
              icon:
                  takeAway
                      ? HugeIcons.strokeRoundedStore01
                      : HugeIcons.strokeRoundedHome01,
              size: 20,
              color: WaddyColors.mintInk,
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: title,
                    style: waddyMedium,
                    children: [TextSpan(text: emphasis, style: waddyBold)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Dimensions.fontSizeSmall,
                    color: WaddyColors.ink,
                  ),
                ),
                if (line.isNotEmpty)
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: WaddyColors.inkLight,
                    ),
                  ),
              ],
            ),
          ),
          if (!takeAway)
            TextButton(
              onPressed: () => _openAddressSheet(context),
              style: TextButton.styleFrom(
                foregroundColor: WaddyColors.mintInk,
                minimumSize: const Size(
                  Dimensions.minTapTarget,
                  Dimensions.minTapTarget,
                ),
              ),
              child: Text(
                'change'.tr,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: WaddyColors.mintInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _payUsing() {
    final (List<List<dynamic>> icon, String name) = _selectedMethod();
    return InkWell(
      onTap: storeId == null ? onChoosePayment : null,
      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeExtraSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CheckoutIcon(icon: icon, size: 14, color: WaddyColors.inkLight),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                Flexible(
                  child: Text(
                    'pay_using'.tr.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyBold.copyWith(
                      fontSize: Dimensions.fontSizeOverSmall,
                      color: WaddyColors.inkLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (storeId == null)
                  const CheckoutIcon(
                    icon: HugeIcons.strokeRoundedArrowUp01,
                    size: 16,
                    color: WaddyColors.inkLight,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: WaddyColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (List<List<dynamic>>, String) _selectedMethod() {
    final c = checkoutController;
    final String wallet = c.isPartialPay ? ' + ${'wallet'.tr}' : '';
    if (storeId != null) {
      return (HugeIcons.strokeRoundedMoney03, 'cash_on_delivery'.tr);
    }
    switch (c.paymentMethodIndex) {
      case 0:
        return (
          HugeIcons.strokeRoundedMoney03,
          '${'cash_on_delivery'.tr}$wallet',
        );
      case 1:
        return (HugeIcons.strokeRoundedWallet01, 'wallet'.tr);
      case 2:
        final methods =
            Get.find<SplashController>().configModel.activePaymentMethodList ??
            [];
        final match = methods.where((m) => m.getWay == c.digitalPaymentName);
        final String title =
            match.isNotEmpty
                ? (match.first.getWayTitle ?? match.first.getWay ?? '')
                : 'digital_payment'.tr;
        return (HugeIcons.strokeRoundedCreditCard, '$title$wallet');
      case 3:
        return (HugeIcons.strokeRoundedBank, 'offline_payment'.tr);
      default:
        return (HugeIcons.strokeRoundedMoney03, 'select_payment_method'.tr);
    }
  }

  Widget _placeOrderPill(BuildContext context) {
    final bool loading = checkoutController.isLoading;
    // The app's own button, with a split total/label row as its content.
    // `isLoading` makes it swallow taps while placing; the spinner is ours
    // because `child` replaces the button's default loading row.
    return CustomButton(
      buttonText: 'place_order'.tr,
      onPressed: onPlaceOrder,
      isLoading: loading,
      radius: 100,
      height: 54,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Dimensions.paddingSizeLarge,
          0,
          Dimensions.paddingSizeDefault,
          0,
        ),
        child:
            loading
                ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: WaddyColors.primary,
                    ),
                  ),
                )
                : Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          PriceConverter.convertPrice(
                            checkoutController.viewTotalPrice,
                          ),
                          textDirection: TextDirection.ltr,
                          style: waddyBold.copyWith(
                            fontSize: Dimensions.fontSizeLarge,
                            color: WaddyColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    const Spacer(),
                    Text(
                      'place_order'.tr,
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: WaddyColors.primary,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                    CheckoutIcon(
                      icon: _forwardChevron(context),
                      size: 14,
                      color: WaddyColors.primary,
                    ),
                  ],
                ),
      ),
    );
  }

  void _openAddressSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
            ),
            decoration: const BoxDecoration(
              color: WaddyColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(Dimensions.radiusExtraLarge),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(
                        top: Dimensions.paddingSizeMedium,
                      ),
                      decoration: BoxDecoration(
                        color: WaddyColors.divider,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusExtraSmall,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(
                      Dimensions.paddingSizeDefault,
                    ),
                    child: Text(
                      'choose_address'.tr,
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        color: WaddyColors.ink,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (int i = 0; i < address.length; i++)
                          _AddressOption(
                            address: address[i],
                            selected: checkoutController.addressIndex == i,
                            onTap: () {
                              _selectAddress(i);
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                        InkWell(
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _addNewAddress();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(
                              Dimensions.paddingSizeDefault,
                            ),
                            child: Row(
                              children: [
                                const CheckoutIcon(
                                  icon: HugeIcons.strokeRoundedAdd01,
                                  size: 20,
                                  color: WaddyColors.mintInk,
                                ),
                                const SizedBox(
                                  width: Dimensions.paddingSizeMedium,
                                ),
                                Text(
                                  'add_new_address'.tr,
                                  style: waddyBold.copyWith(
                                    fontSize: Dimensions.fontSizeSmall,
                                    color: WaddyColors.mintInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// DeliverySection's address-picker `onSelected`: re-price the delivery for
  /// the new address and carry its street/house/floor into the order.
  void _selectAddress(int index) {
    final c = checkoutController;
    c.getDistanceInKM(
      LatLng(
        double.parse(address[index].latitude!),
        double.parse(address[index].longitude!),
      ),
      LatLng(
        double.parse(c.store!.latitude!),
        double.parse(c.store!.longitude!),
      ),
    );
    c.setAddressIndex(index);
    c.streetNumberController.text = address[index].streetNumber ?? '';
    c.houseController.text = address[index].house ?? '';
    c.floorController.text = address[index].floor ?? '';
  }

  /// DeliverySection's "Add new" flow, unchanged.
  Future<void> _addNewAddress() async {
    final c = checkoutController;
    var newAddress = await Get.toNamed(
      RouteHelper.getAddAddressRoute(true, false, c.store!.zoneId),
    );
    if (newAddress != null) {
      c.getDistanceInKM(
        LatLng(
          double.parse(newAddress.latitude),
          double.parse(newAddress.longitude),
        ),
        LatLng(
          double.parse(c.store!.latitude!),
          double.parse(c.store!.longitude!),
        ),
      );
      c.streetNumberController.text = newAddress.streetNumber ?? '';
      c.houseController.text = newAddress.house ?? '';
      c.floorController.text = newAddress.floor ?? '';
    }
  }
}

class _AddressOption extends StatelessWidget {
  final AddressModel address;
  final bool selected;
  final VoidCallback onTap;
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: Dimensions.paddingSizeMedium,
          ),
          child: Row(
            children: [
              const CheckoutIcon(
                icon: HugeIcons.strokeRoundedLocation01,
                size: 20,
                color: WaddyColors.ink,
              ),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (address.addressType == 'home' ||
                                  address.addressType == 'office'
                              ? address.addressType!
                              : 'address_label_other')
                          .tr,
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: WaddyColors.ink,
                      ),
                    ),
                    Text(
                      address.address ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: waddyRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall,
                        color: WaddyColors.inkLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              CheckoutRadio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Next" chevron that points the reading direction's way.
List<List<dynamic>> _forwardChevron(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
        ? HugeIcons.strokeRoundedArrowLeft01
        : HugeIcons.strokeRoundedArrowRight01;
