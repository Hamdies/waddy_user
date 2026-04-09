import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_asset_image_widget.dart';
import 'package:waddy_app/features/order/widgets/support_reason_bottom_sheet.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/order/widgets/order_item_widget.dart';
import 'package:waddy_app/features/parcel/widgets/details_widget.dart';

class OrderCalculationWidget extends StatelessWidget {
  final OrderController orderController;
  final OrderModel order;
  final bool ongoing;
  final bool parcel;
  final bool prescriptionOrder;
  final double deliveryCharge;
  final double itemsPrice;
  final double discount;
  final double couponDiscount;
  final double tax;
  final double addOns;
  final double dmTips;
  final bool taxIncluded;
  final double subTotal;
  final double total;
  final Widget bottomView;
  final double extraPackagingAmount;
  final double referrerBonusAmount;
  final Function timerCancel;
  final Function startApiCall;
  const OrderCalculationWidget({
    super.key, required this.orderController, required this.order, required this.ongoing,
    required this.parcel, required this.prescriptionOrder, required this.deliveryCharge,
    required this.itemsPrice, required this.discount, required this.couponDiscount, required this.tax,
    required this.addOns, required this.dmTips, required this.taxIncluded, required this.subTotal,
    required this.total, required this.bottomView, required this.extraPackagingAmount, required this.referrerBonusAmount, required this.timerCancel, required this.startApiCall,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color labelColor = Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.6);
    final Color valueColor = Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.85);
    final TextStyle labelStyle = robotoRegular.copyWith(fontSize: 13, color: labelColor);
    final TextStyle valueStyle = robotoMedium.copyWith(fontSize: 13, color: valueColor);

    return Padding(
      padding: EdgeInsets.only(
        top: ResponsiveHelper.isDesktop(context) ? Dimensions.paddingSizeExtraLarge : Dimensions.paddingSizeSmall,
        left: ResponsiveHelper.isDesktop(context) ? 0 : 16,
        right: ResponsiveHelper.isDesktop(context) ? 0 : 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Desktop order items (unchanged logic) ──
          if (ResponsiveHelper.isDesktop(context) && orderController.orderDetails!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: parcel ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DetailsWidget(title: 'sender_details'.tr, address: order.deliveryAddress),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                DetailsWidget(title: 'receiver_details'.tr, address: order.receiverDetails),
              ]) : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orderController.orderDetails!.length,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemBuilder: (context, index) {
                  return OrderItemWidget(order: order, orderDetails: orderController.orderDetails![index]);
                },
              ),
            ),

          // ── Bill Summary Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long_outlined, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text('bill_summary'.tr, style: robotoBold.copyWith(fontSize: 16)),
            ]),
          ),

          // ── Divider ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.12)),
          ),

          // ── Line Items ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [

              // --- PARCEL ---
              if (parcel) ...[
                _billRow('delivery_fee'.tr, PriceConverter.convertPrice(deliveryCharge), labelStyle, valueStyle),
                const SizedBox(height: 12),
                _billRow('delivery_man_tips'.tr, PriceConverter.convertPrice(order.dmTips ?? 0), labelStyle, valueStyle),
                if ((tax != 0) && !taxIncluded) ...[
                  const SizedBox(height: 12),
                  _billRow('vat_tax'.tr, PriceConverter.convertPrice(tax), labelStyle, valueStyle),
                ],
                if (order.additionalCharge != null && order.additionalCharge! > 0) ...[
                  const SizedBox(height: 12),
                  _billRow(
                    Get.find<SplashController>().configModel!.additionalChargeName!,
                    PriceConverter.convertPrice(order.additionalCharge),
                    labelStyle, valueStyle,
                  ),
                ],
              ],

              // --- NON-PARCEL ---
              if (!parcel) ...[
                _billRow('item_price'.tr, PriceConverter.convertPrice(itemsPrice), labelStyle, valueStyle),

                if (Get.find<SplashController>().getModuleConfig(order.moduleType).addOn!) ...[
                  const SizedBox(height: 12),
                  _billRow('addons'.tr, PriceConverter.convertPrice(addOns), labelStyle, valueStyle),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
                  ),
                  _billRow('subtotal'.tr, PriceConverter.convertPrice(subTotal), labelStyle, valueStyle),
                ],

                if (discount > 0) ...[
                  const SizedBox(height: 12),
                  _billRow('discount'.tr, '- ${PriceConverter.convertPrice(discount)}', labelStyle, valueStyle.copyWith(color: Colors.green)),
                ],

                if (couponDiscount > 0) ...[
                  const SizedBox(height: 12),
                  _billRow('coupon_discount'.tr, '- ${PriceConverter.convertPrice(couponDiscount)}', labelStyle, valueStyle.copyWith(color: Colors.green)),
                ],

                if (referrerBonusAmount > 0) ...[
                  const SizedBox(height: 12),
                  _billRow('referral_discount'.tr, '- ${PriceConverter.convertPrice(referrerBonusAmount)}', labelStyle, valueStyle.copyWith(color: Colors.green)),
                ],

                if (order.additionalCharge != null && order.additionalCharge! > 0) ...[
                  const SizedBox(height: 12),
                  _billRow(
                    Get.find<SplashController>().configModel!.additionalChargeName!,
                    PriceConverter.convertPrice(order.additionalCharge),
                    labelStyle, valueStyle,
                  ),
                ],

                if ((tax != 0) && !taxIncluded) ...[
                  const SizedBox(height: 12),
                  _billRow('vat_tax'.tr, PriceConverter.convertPrice(tax), labelStyle, valueStyle),
                ],

                if (dmTips > 0) ...[
                  const SizedBox(height: 12),
                  _billRow('delivery_man_tips'.tr, PriceConverter.convertPrice(dmTips), labelStyle, valueStyle),
                ],

                if (extraPackagingAmount > 0) ...[
                  const SizedBox(height: 12),
                  _billRow('extra_packaging'.tr, PriceConverter.convertPrice(extraPackagingAmount), labelStyle, valueStyle),
                ],

                const SizedBox(height: 12),
                _billRow(
                  'delivery_fee'.tr,
                  deliveryCharge > 0 ? PriceConverter.convertPrice(deliveryCharge) : 'free'.tr,
                  labelStyle,
                  deliveryCharge > 0 ? valueStyle : valueStyle.copyWith(color: primaryColor),
                ),
              ],

            ]),
          ),

          // ── Total / Paid Row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.12)),
          ),

          if (order.paymentMethod == 'partial_payment') ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Column(children: [
                _billRow(
                  'total_amount'.tr,
                  PriceConverter.convertPrice(total),
                  robotoBold.copyWith(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium!.color),
                  robotoBold.copyWith(fontSize: 14, color: primaryColor),
                ),
                const SizedBox(height: 10),
                _billRow(
                  'paid_by_wallet'.tr,
                  PriceConverter.convertPrice(order.payments?[0].amount ?? 0),
                  labelStyle, valueStyle,
                ),
                const SizedBox(height: 10),
                _billRow(
                  '${order.payments?[1].paymentStatus == 'paid' ? 'paid_by'.tr : 'due_amount'.tr} (${order.payments?[1].paymentMethod?.tr})',
                  PriceConverter.convertPrice(order.payments?[1].amount ?? 0),
                  labelStyle, valueStyle,
                ),
              ]),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(children: [
                Text(
                  'paid'.tr,
                  style: robotoBold.copyWith(fontSize: 15, color: Theme.of(context).textTheme.bodyMedium!.color),
                ),
                if (taxIncluded)
                  Text(
                    ' (${'vat_tax_inc'.tr})',
                    style: robotoRegular.copyWith(fontSize: 10, color: labelColor),
                  ),
                const Spacer(),
                Text(
                  PriceConverter.convertPrice(total),
                  style: robotoBold.copyWith(fontSize: 15, color: primaryColor),
                  textDirection: TextDirection.ltr,
                ),
              ]),
            ),
          ],

          // ── Desktop bottom view ──
          if (ResponsiveHelper.isDesktop(context))
            Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: bottomView,
            ),

          // ── Support Link ──
          if (AuthHelper.isLoggedIn())
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Center(
                child: TextButton(
                  onPressed: () async {
                    if (ResponsiveHelper.isDesktop(context)) {
                      await Get.dialog(Dialog(child: SupportReasonBottomSheet(orderId: order.id!, timerCancel: timerCancel, startApiCall: startApiCall)));
                    } else {
                      await Get.bottomSheet(SupportReasonBottomSheet(orderId: order.id!, timerCancel: timerCancel, startApiCall: startApiCall), backgroundColor: Colors.transparent, isScrollControlled: true);
                    }
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const CustomAssetImageWidget(Images.chatSupport, height: 18, width: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: '${'message_to'.tr} ',
                            style: robotoMedium.copyWith(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color),
                          ),
                          TextSpan(
                            text: Get.find<SplashController>().configModel!.businessName,
                            style: robotoMedium.copyWith(fontSize: 12, color: primaryColor, decoration: TextDecoration.underline),
                          ),
                        ]),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              ),
            ),

          const SizedBox(height: 14),
        ]),
      ),
    );
  }

  Widget _billRow(String label, String value, TextStyle labelStyle, TextStyle valueStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 12),
        Text(value, style: valueStyle, textDirection: TextDirection.ltr),
      ],
    );
  }
}
