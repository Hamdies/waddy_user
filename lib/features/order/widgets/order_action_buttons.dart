import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/confirmation_dialog.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/features/order/widgets/cancellation_dialogue_widget.dart';
import 'package:waddy_app/features/review/screens/rate_review_screen.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';

class OrderActionButtons extends StatelessWidget {
  final OrderController orderController;
  final OrderModel order;
  final bool parcel;
  final double totalPrice;
  final String? contactNumber;
  final bool isCashOnDeliveryActive;
  final double? maxCodOrderAmount;
  final VoidCallback onTimerCancel;
  final VoidCallback onStartTracking;

  const OrderActionButtons({
    super.key,
    required this.orderController,
    required this.order,
    required this.parcel,
    required this.totalPrice,
    required this.contactNumber,
    required this.isCashOnDeliveryActive,
    required this.maxCodOrderAmount,
    required this.onTimerCancel,
    required this.onStartTracking,
  });

  @override
  Widget build(BuildContext context) {
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          !orderController.showCancelled
              ? Center(
                  child: SizedBox(
                    width: Dimensions.webMaxWidth,
                    child: Column(
                      children: [
                        // Track Order button
                        if (status != null && status.isTrackable)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              Dimensions.paddingSizeDefault,
                              Dimensions.paddingSizeSmall,
                              Dimensions.paddingSizeDefault,
                              Dimensions.paddingSizeExtraSmall,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () async {
                                  onTimerCancel();
                                  await Get.toNamed(
                                    RouteHelper.getOrderTrackingRoute(
                                      order.id,
                                      contactNumber,
                                    ),
                                  )?.whenComplete(() {
                                    onStartTracking();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  parcel ? 'track_delivery'.tr : 'track_order'.tr,
                                  style: robotoMedium.copyWith(
                                    fontSize: Dimensions.fontSizeDefault,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Switch to COD (pending + unpaid + digital)
                        if (status == OrderStatus.pending &&
                            order.paymentStatus == 'unpaid' &&
                            order.paymentMethod == 'digital_payment' &&
                            isCashOnDeliveryActive)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              Dimensions.paddingSizeDefault,
                              Dimensions.paddingSizeExtraSmall,
                              Dimensions.paddingSizeDefault,
                              Dimensions.paddingSizeExtraSmall,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () {
                                  Get.dialog(
                                    ConfirmationDialog(
                                      icon: Images.warning,
                                      description: 'are_you_sure_to_switch'.tr,
                                      onYesPressed: () {
                                        if ((((maxCodOrderAmount != null &&
                                                        totalPrice < maxCodOrderAmount!) ||
                                                    maxCodOrderAmount == null ||
                                                    maxCodOrderAmount == 0) &&
                                                !parcel) ||
                                            parcel) {
                                          orderController.switchToCOD(
                                            order.id.toString(),
                                          );
                                        } else {
                                          if (Get.isDialogOpen!) {
                                            Get.back();
                                          }
                                          showCustomSnackBar(
                                            '${'you_cant_order_more_then'.tr} ${PriceConverter.convertPrice(maxCodOrderAmount)} ${'in_cash_on_delivery'.tr}',
                                          );
                                        }
                                      },
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'switch_to_cod'.tr,
                                  style: robotoMedium.copyWith(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Cancel Order
                        if (status == OrderStatus.pending &&
                            (Get.find<AuthController>().isLoggedIn()
                                ? true
                                : (orderController.orderDetails != null &&
                                        orderController.orderDetails!.isNotEmpty &&
                                        orderController.orderDetails?[0].isGuest == 1
                                    ? true
                                    : false)))
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              Dimensions.paddingSizeDefault,
                              Dimensions.paddingSizeExtraSmall,
                              Dimensions.paddingSizeDefault,
                              Dimensions.paddingSizeExtraSmall,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () {
                                  orderController.setOrderCancelReason('');
                                  Get.dialog(
                                    CancellationDialogueWidget(
                                      orderId: order.id,
                                      contactNumber: contactNumber,
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey.shade400),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  parcel ? 'cancel_delivery'.tr : 'cancel_order'.tr,
                                  style: robotoMedium.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Container(
                    width: Dimensions.webMaxWidth,
                    height: 50,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(width: 2, color: Colors.red.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'order_cancelled'.tr,
                      style: robotoMedium.copyWith(color: Colors.red.shade400),
                    ),
                  ),
                ),

          // Review button
          if (status == OrderStatus.delivered &&
              (parcel
                  ? order.deliveryMan != null
                  : (orderController.orderDetails!.isNotEmpty &&
                      orderController.orderDetails![0].itemCampaignId == null)))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    List<OrderDetailsModel> orderDetailsList = [];
                    List<int?> orderDetailsIdList = [];
                    for (var orderDetail in orderController.orderDetails!) {
                      if (!orderDetailsIdList.contains(
                        orderDetail.itemDetails!.id,
                      )) {
                        orderDetailsList.add(orderDetail);
                        orderDetailsIdList.add(orderDetail.itemDetails!.id);
                      }
                    }
                    Get.toNamed(
                      RouteHelper.getReviewRoute(),
                      arguments: RateReviewScreen(
                        orderDetailsList: orderDetailsList,
                        deliveryMan: order.deliveryMan,
                        orderID: order.id,
                      ),
                    );
                  },
                  icon: const Icon(Icons.star_outline, size: 20),
                  label: Text('review'.tr, style: robotoMedium),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

          // Reorder button
          if (AuthHelper.isLoggedIn() &&
              !parcel &&
              (status == OrderStatus.delivered ||
                  status == OrderStatus.canceled ||
                  status == OrderStatus.failed))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed:
                      orderController.isReordering
                          ? null
                          : () async {
                              final result = await orderController.reorder(
                                order.id!,
                              );
                              if (result != null) {
                                final int addedCount =
                                    result['added_count'] ?? 0;
                                final int unavailableCount =
                                    result['unavailable_count'] ?? 0;
                                String message = result['message'] ?? '';
                                if (unavailableCount > 0) {
                                  final unavailable =
                                      result['unavailable'] as List? ?? [];
                                  final names = unavailable
                                      .map((u) => u['item_name'] ?? '')
                                      .where((n) => n.isNotEmpty)
                                      .join(', ');
                                  if (names.isNotEmpty) {
                                    message += '\n${'unavailable'.tr}: $names';
                                  }
                                }
                                showCustomSnackBar(
                                  message,
                                  isError: addedCount == 0,
                                );
                                if (addedCount > 0) {
                                  Get.find<CartController>().getCartDataOnline();
                                }
                              } else {
                                showCustomSnackBar('failed_to_reorder'.tr);
                              }
                            },
                  icon:
                      orderController.isReordering
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.replay_rounded, size: 20),
                  label: Text('reorder'.tr, style: robotoMedium),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

          // Switch to COD on failed
          if (status == OrderStatus.failed &&
              Get.find<SplashController>().configModel!.cashOnDelivery!)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Get.dialog(
                      ConfirmationDialog(
                        icon: Images.warning,
                        description: 'are_you_sure_to_switch'.tr,
                        onYesPressed: () {
                          orderController
                              .switchToCOD(order.id.toString())
                              .then((isSuccess) {
                                Get.back();
                                if (isSuccess) {
                                  Get.back();
                                }
                              });
                        },
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'switch_to_cash_on_delivery'.tr,
                    style: robotoMedium.copyWith(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
