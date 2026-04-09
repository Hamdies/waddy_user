import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class OrderDetailsBottomSheet {
  static void show({
    required BuildContext context,
    required OrderController orderController,
    required OrderModel order,
  }) {
    double itemsPrice = 0;
    double addOns = 0;
    if (orderController.orderDetails != null) {
      for (final d in orderController.orderDetails!) {
        for (final a in d.addOns!) {
          addOns += (a.price ?? 0) * (a.quantity ?? 0);
        }
        itemsPrice += (d.price ?? 0) * (d.quantity ?? 0);
      }
    }
    final double subTotal = itemsPrice + addOns;
    final double discount =
        (order.storeDiscountAmount ?? 0) +
        (order.flashAdminDiscountAmount ?? 0) +
        (order.flashStoreDiscountAmount ?? 0);
    final double tax = order.totalTaxAmount ?? 0;
    final double deliveryCharge = order.deliveryCharge ?? 0;
    final double coupon = order.couponDiscountAmount ?? 0;
    final double dmTips = order.dmTips ?? 0;
    final bool taxIncluded = order.taxStatus ?? false;
    final double total =
        subTotal -
        discount +
        (taxIncluded ? 0 : tax) +
        deliveryCharge -
        coupon +
        dmTips;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title bar
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeLarge,
                      0,
                      Dimensions.paddingSizeLarge,
                      Dimensions.paddingSizeSmall,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'order_details'.tr,
                          style: robotoBold.copyWith(
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(
                            Icons.close,
                            size: 22,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: EdgeInsets.fromLTRB(
                        Dimensions.paddingSizeDefault,
                        0,
                        Dimensions.paddingSizeDefault,
                        Dimensions.paddingSizeLarge,
                      ),
                      children: [
                        // Store + Status
                        _dialogCard(
                          context: context,
                          child: Row(
                            children: [
                              if (order.store?.logoFullUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CustomImage(
                                    image: order.store!.logoFullUrl!,
                                    height: 48,
                                    width: 48,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.store?.name ?? 'order'.tr,
                                      style: robotoBold.copyWith(
                                        fontSize: Dimensions.fontSizeDefault,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(height: Dimensions.paddingSizeExtraSmall),
                                    Text(
                                      '${'order_id'.tr}: #${order.id}',
                                      style: robotoRegular.copyWith(
                                        fontSize: Dimensions.fontSizeSmall,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (order.orderStatus ?? '').tr,
                                  style: robotoMedium.copyWith(
                                    fontSize: Dimensions.fontSizeExtraSmall,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Order Items
                        if (orderController.orderDetails != null &&
                            orderController.orderDetails!.isNotEmpty)
                          _dialogCard(
                            context: context,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'item_info'.tr,
                                  style: robotoBold.copyWith(
                                    fontSize: Dimensions.fontSizeDefault,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...orderController.orderDetails!.map((d) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: Dimensions.paddingSizeSmall,
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: CustomImage(
                                            image: '${d.imageFullUrl}',
                                            height: 56,
                                            width: 56,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                d.itemDetails?.name ?? '',
                                                style: robotoMedium.copyWith(
                                                  fontSize: Dimensions.fontSizeSmall,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: Dimensions.paddingSizeExtraSmall),
                                              Text(
                                                PriceConverter.convertPrice(d.price),
                                                style: robotoMedium.copyWith(
                                                  fontSize: Dimensions.fontSizeSmall,
                                                  color: Theme.of(context).primaryColor,
                                                ),
                                                textDirection: TextDirection.ltr,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'x${d.quantity}',
                                            style: robotoMedium.copyWith(
                                              fontSize: Dimensions.fontSizeSmall,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Bill Summary
                        _dialogCard(
                          context: context,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'bill_details'.tr,
                                style: robotoBold.copyWith(
                                  fontSize: Dimensions.fontSizeDefault,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _billRow('subtotal'.tr, subTotal),
                              if (discount > 0)
                                _billRow(
                                  'discount'.tr,
                                  -discount,
                                  color: const Color(0xFF1BA672),
                                ),
                              if (!taxIncluded && tax > 0)
                                _billRow('tax'.tr, tax),
                              _billRow('delivery_fee'.tr, deliveryCharge),
                              if (coupon > 0)
                                _billRow(
                                  'coupon_discount'.tr,
                                  -coupon,
                                  color: const Color(0xFF1BA672),
                                ),
                              if (dmTips > 0)
                                _billRow('delivery_man_tips'.tr, dmTips),
                              const SizedBox(height: 8),
                              Divider(color: Colors.grey.shade200, height: 1),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'total'.tr,
                                    style: robotoBold.copyWith(
                                      fontSize: Dimensions.fontSizeDefault,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    PriceConverter.convertPrice(total),
                                    style: robotoBold.copyWith(
                                      fontSize: Dimensions.fontSizeDefault,
                                      color: Colors.black,
                                    ),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Delivery Details Card
                        if (order.deliveryAddress != null)
                          _dialogCard(
                            context: context,
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFDE7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFFFEE58),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'all_your_delivery_details_in_one_place'.tr,
                                        style: robotoMedium.copyWith(
                                          fontSize: Dimensions.fontSizeSmall,
                                          color: const Color(0xFF5D4037),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                                      const Text('👇', style: TextStyle(fontSize: 16)),
                                    ],
                                  ),
                                ),
                                SizedBox(height: Dimensions.paddingSizeSmall),

                                if (order.deliveryAddress?.contactPersonName != null)
                                  _deliveryDetailRow(
                                    context: context,
                                    icon: Icons.phone_outlined,
                                    title:
                                        order.deliveryAddress!.contactPersonName! +
                                        (order.deliveryAddress?.contactPersonNumber != null
                                            ? ', ${order.deliveryAddress!.contactPersonNumber!}'
                                            : ''),
                                    subtitle: 'delivery_man_call_hint'.tr,
                                  ),
                                if (order.deliveryAddress?.contactPersonName != null)
                                  Divider(color: Colors.grey.shade100, height: 20),

                                _deliveryDetailRow(
                                  context: context,
                                  icon: Icons.location_on_outlined,
                                  title:
                                      '${'delivery_at'.tr} ${(order.deliveryAddress?.addressType ?? 'home').tr.capitalizeFirst ?? ''}',
                                  subtitle: order.deliveryAddress?.address ?? '',
                                ),

                                if (order.deliveryInstruction != null &&
                                    order.deliveryInstruction!.isNotEmpty) ...[
                                  Divider(color: Colors.grey.shade100, height: 20),
                                  _deliveryDetailRow(
                                    context: context,
                                    icon: Icons.delivery_dining_outlined,
                                    title: 'delivery_instruction'.tr,
                                    subtitle: order.deliveryInstruction!,
                                    subtitleColor: const Color(0xFF1BA672),
                                    showCheck: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Payment Method
                        _dialogCard(
                          context: context,
                          child: Row(
                            children: [
                              Icon(
                                Icons.payment_rounded,
                                size: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'payment_method'.tr,
                                style: robotoMedium.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                order.paymentMethod == 'cash_on_delivery'
                                    ? 'cash_on_delivery'.tr
                                    : order.paymentMethod == 'wallet'
                                    ? 'wallet_payment'.tr
                                    : order.paymentMethod == 'partial_payment'
                                    ? 'partial_payment'.tr
                                    : order.paymentMethod == 'offline_payment'
                                    ? 'offline_payment'.tr
                                    : 'digital_payment'.tr,
                                style: robotoMedium.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _dialogCard({required BuildContext context, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  static Widget _deliveryDetailRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    Color? subtitleColor,
    bool showCheck = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 3),
              if (showCheck)
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Color(0xFF1BA672),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: subtitleColor ?? Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  subtitle,
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: subtitleColor ?? Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _billRow(String label, double amount, {Color? color}) {
    final bool isNegative = amount < 0;
    return Padding(
      padding: EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
      child: Row(
        children: [
          Text(
            label,
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          Text(
            '${isNegative ? '- ' : ''}${PriceConverter.convertPrice(amount.abs())}',
            style: robotoMedium.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: color ?? Colors.black87,
            ),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
