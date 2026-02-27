import 'package:sixam_mart/common/widgets/custom_ink_well.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_details_model.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/order/widgets/order_shimmer_widget.dart';
import 'package:sixam_mart/helper/date_converter.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/common/widgets/footer_view.dart';
import 'package:sixam_mart/common/widgets/no_data_screen.dart';
import 'package:sixam_mart/common/widgets/paginated_list_view.dart';
import 'package:sixam_mart/features/order/screens/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OrderViewWidget extends StatelessWidget {
  final bool isRunning;
  const OrderViewWidget({super.key, required this.isRunning});

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFE8A317);
      case 'accepted':
      case 'confirmed':
        return const Color(0xFF3B82F6);
      case 'processing':
      case 'handover':
        return const Color(0xFF8B5CF6);
      case 'picked_up':
        return const Color(0xFF6366F1);
      case 'delivered':
        return const Color(0xFF10B981);
      case 'canceled':
      case 'failed':
        return const Color(0xFFEF4444);
      case 'refund_requested':
      case 'refunded':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'accepted':
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'processing':
      case 'handover':
        return Icons.restaurant_rounded;
      case 'picked_up':
        return Icons.delivery_dining_rounded;
      case 'delivered':
        return Icons.task_alt_rounded;
      case 'canceled':
      case 'failed':
        return Icons.cancel_outlined;
      case 'refund_requested':
      case 'refunded':
        return Icons.replay_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    try {
      DateTime date;
      try {
        date = DateTime.parse(createdAt).toLocal();
      } catch (_) {
        date = DateTime.parse(createdAt);
      }
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'just_now'.tr;
      if (diff.inMinutes < 60) return '${diff.inMinutes} ${'min_ago'.tr}';
      if (diff.inHours < 24) return '${diff.inHours} ${'hours_ago'.tr}';
      if (diff.inDays < 7) return '${diff.inDays} ${'days_ago'.tr}';
      return DateConverter.dateTimeStringToDateTime(createdAt);
    } catch (_) {
      return DateConverter.dateTimeStringToDateTime(createdAt);
    }
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty || url == 'null') return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: GetBuilder<OrderController>(builder: (orderController) {
        PaginatedOrderModel? paginatedOrderModel;
        if(isRunning) {
          paginatedOrderModel = orderController.runningOrderModel;
        }else {
          paginatedOrderModel = orderController.historyOrderModel;
        }

        if (paginatedOrderModel != null && paginatedOrderModel.orders != null) {
          for (final order in paginatedOrderModel.orders!) {
            if (order.id != null && order.orderType != 'parcel' && !(order.prescriptionOrder ?? false)) {
              orderController.fetchOrderDetailsForList(order.id!);
            }
          }
        }

        return paginatedOrderModel != null ? paginatedOrderModel.orders!.isNotEmpty ? RefreshIndicator(
          onRefresh: () async {
            if(isRunning) {
              await orderController.getRunningOrders(1, isUpdate: true);
            }else {
              await orderController.getHistoryOrders(1, isUpdate: true);
            }
          },
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: FooterView(
              child: SizedBox(
                width: Dimensions.webMaxWidth,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: ResponsiveHelper.isDesktop(context) ? 0 : 100,
                    left: 16,
                    right: 16,
                    top: 8,
                  ),
                  child: PaginatedListView(
                    scrollController: scrollController,
                    onPaginate: (int? offset) async {
                      if(isRunning) {
                        await orderController.getRunningOrders(offset!, isUpdate: true);
                      }else {
                        await orderController.getHistoryOrders(offset!, isUpdate: true);
                      }
                    },
                    totalSize: isRunning ? orderController.runningOrderModel?.totalSize : orderController.historyOrderModel?.totalSize,
                    offset: isRunning ? orderController.runningOrderModel?.offset : orderController.historyOrderModel?.offset,
                    itemView: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: paginatedOrderModel.orders!.length,
                      itemBuilder: (context, index) {
                        final order = paginatedOrderModel!.orders![index];
                        bool isParcel = order.orderType == 'parcel';
                        bool isPrescription = order.prescriptionOrder ?? false;
                        final statusColor = _getStatusColor(order.orderStatus);
                        final statusIcon = _getStatusIcon(order.orderStatus);
                        final storeName = isParcel
                            ? 'parcel'.tr
                            : (order.store?.name ?? 'store'.tr);
                        final itemCount = order.detailsCount ?? 0;
                        final timeAgo = _timeAgo(order.createdAt);

                        final List<OrderDetailsModel> cachedDetails =
                            order.id != null ? (orderController.orderDetailsCache[order.id!] ?? []) : [];

                        final List<String> itemImages = [];
                        final List<String> itemNames = [];
                        for (final detail in cachedDetails) {
                          final img = '${detail.imageFullUrl}';
                          if (_isValidUrl(img)) {
                            itemImages.add(img);
                          } else {
                            final itemImg = '${detail.itemDetails?.imageFullUrl}';
                            if (_isValidUrl(itemImg)) {
                              itemImages.add(itemImg);
                            }
                          }
                          if (detail.itemDetails?.name != null) {
                            itemNames.add(detail.itemDetails!.name!);
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: CustomInkWell(
                            onTap: () {
                              Get.toNamed(
                                RouteHelper.getOrderDetailsRoute(order.id),
                                arguments: OrderDetailsScreen(
                                  orderId: order.id,
                                  orderModel: order,
                                ),
                              );
                            },
                            radius: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.06),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // ── Colored status accent bar at top ──
                                  Container(
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 32),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [statusColor.withValues(alpha: 0.7), statusColor.withValues(alpha: 0.15)],
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // ── Top: Status pill + Order ID + Time ──
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [statusColor.withValues(alpha: 0.15), statusColor.withValues(alpha: 0.05)],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(statusIcon, size: 13, color: statusColor),
                                              const SizedBox(width: 5),
                                              Text(
                                                order.orderStatus?.tr ?? '',
                                                style: robotoBold.copyWith(
                                                  fontSize: Dimensions.fontSizeOverSmall,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          '#${order.id}',
                                          style: robotoMedium.copyWith(
                                            fontSize: Dimensions.fontSizeExtraSmall,
                                            color: Theme.of(context).disabledColor.withValues(alpha: 0.5),
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.access_time_rounded, size: 13, color: Theme.of(context).disabledColor.withValues(alpha: 0.4)),
                                        const SizedBox(width: 4),
                                        Text(
                                          timeAgo,
                                          style: robotoRegular.copyWith(
                                            fontSize: Dimensions.fontSizeOverSmall,
                                            color: Theme.of(context).disabledColor.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // ── Middle: Item images + info ──
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                    child: Row(
                                      children: [

                                        // Item image thumbnails (rounded squares, stacked)
                                        if (itemImages.isNotEmpty) ...[
                                          SizedBox(
                                            height: 52,
                                            width: _getStackWidth(itemImages.length, itemCount),
                                            child: Stack(
                                              children: [
                                                for (int i = 0; i < itemImages.length.clamp(0, 3); i++)
                                                  Positioned(
                                                    left: i * 36.0,
                                                    child: Container(
                                                      height: 52,
                                                      width: 52,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(14),
                                                        border: Border.all(color: Theme.of(context).cardColor, width: 3),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withValues(alpha: 0.08),
                                                            blurRadius: 6,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(11),
                                                        child: CustomImage(
                                                          image: itemImages[i],
                                                          height: 52,
                                                          width: 52,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (itemCount > 3)
                                                  Positioned(
                                                    left: (itemImages.length.clamp(0, 3)) * 36.0,
                                                    child: Container(
                                                      height: 52,
                                                      width: 52,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(14),
                                                        gradient: LinearGradient(
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                          colors: [primary.withValues(alpha: 0.12), primary.withValues(alpha: 0.05)],
                                                        ),
                                                        border: Border.all(color: Theme.of(context).cardColor, width: 3),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '+${itemCount - 3}',
                                                          style: robotoBold.copyWith(
                                                            fontSize: Dimensions.fontSizeSmall,
                                                            color: primary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                        ] else if (isParcel || isPrescription) ...[
                                          Container(
                                            height: 52,
                                            width: 52,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(14),
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [primary.withValues(alpha: 0.12), primary.withValues(alpha: 0.04)],
                                              ),
                                            ),
                                            child: Icon(
                                              isParcel ? Icons.inventory_2_rounded : Icons.medical_services_rounded,
                                              color: primary,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                        ] else ...[
                                          Container(
                                            height: 52,
                                            width: 52,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(14),
                                              color: Theme.of(context).disabledColor.withValues(alpha: 0.06),
                                            ),
                                            child: Icon(
                                              Icons.shopping_bag_outlined,
                                              color: Theme.of(context).disabledColor.withValues(alpha: 0.35),
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                        ],

                                        // Item names + store name
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                itemNames.isNotEmpty
                                                    ? (itemNames.length <= 2
                                                        ? itemNames.join(', ')
                                                        : '${itemNames.take(2).join(', ')} +${itemNames.length - 2}')
                                                    : (isParcel ? 'parcel'.tr : isPrescription ? 'prescription'.tr : '$itemCount ${itemCount > 1 ? 'items'.tr : 'item'.tr}'),
                                                style: robotoBold.copyWith(
                                                  fontSize: Dimensions.fontSizeDefault,
                                                  height: 1.3,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(3),
                                                    decoration: BoxDecoration(
                                                      color: primary.withValues(alpha: 0.08),
                                                      borderRadius: BorderRadius.circular(5),
                                                    ),
                                                    child: Icon(Icons.storefront_rounded, size: 12, color: primary.withValues(alpha: 0.7)),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      storeName,
                                                      style: robotoRegular.copyWith(
                                                        fontSize: Dimensions.fontSizeExtraSmall,
                                                        color: Theme.of(context).disabledColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // ── Bottom: Total + Action button ──
                                  Container(
                                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'total'.tr,
                                              style: robotoRegular.copyWith(
                                                fontSize: Dimensions.fontSizeOverSmall,
                                                color: Theme.of(context).disabledColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              PriceConverter.convertPrice(order.orderAmount ?? 0),
                                              style: robotoBold.copyWith(
                                                fontSize: Dimensions.fontSizeLarge,
                                                color: Theme.of(context).textTheme.bodyLarge!.color,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const Spacer(),

                                        if (isRunning)
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => Get.toNamed(RouteHelper.getOrderTrackingRoute(order.id, null)),
                                              borderRadius: BorderRadius.circular(14),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [primary, primary.withValues(alpha: 0.85)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(14),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: primary.withValues(alpha: 0.3),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Image.asset(Images.tracking, height: 15, width: 15, color: Colors.white),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      isParcel ? 'track_delivery'.tr : 'track_order'.tr,
                                                      style: robotoBold.copyWith(
                                                        fontSize: Dimensions.fontSizeExtraSmall,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                        if (!isRunning)
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                Get.toNamed(
                                                  RouteHelper.getOrderDetailsRoute(order.id),
                                                  arguments: OrderDetailsScreen(
                                                    orderId: order.id,
                                                    orderModel: order,
                                                  ),
                                                );
                                              },
                                              borderRadius: BorderRadius.circular(14),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: primary.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(color: primary.withValues(alpha: 0.15)),
                                                ),
                                                child: Text(
                                                  'view_details'.tr,
                                                  style: robotoBold.copyWith(
                                                    fontSize: Dimensions.fontSizeExtraSmall,
                                                    color: primary,
                                                  ),
                                                ),
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
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ) : NoDataScreen(text: 'no_order_found'.tr, showFooter: true) : OrderShimmerWidget(orderController: orderController);
      }),
    );
  }

  double _getStackWidth(int imageCount, int totalItems) {
    int visibleCount = imageCount.clamp(0, 3);
    bool hasOverflow = totalItems > 3;
    int totalCircles = visibleCount + (hasOverflow ? 1 : 0);
    if (totalCircles == 0) return 52;
    return 52.0 + (totalCircles - 1) * 36.0;
  }
}
