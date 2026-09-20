import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/widgets/order_shimmer_widget.dart';
import 'package:waddy_app/features/review/screens/rate_review_screen.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/no_data_screen.dart';
import 'package:waddy_app/common/widgets/paginated_list_view.dart';
import 'package:waddy_app/features/order/screens/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderViewWidget extends StatefulWidget {
  final bool isRunning;
  const OrderViewWidget({super.key, required this.isRunning});

  @override
  State<OrderViewWidget> createState() => _OrderViewWidgetState();
}

enum _DateFilter { all, today, week, month }

enum _PriceSort { none, lowToHigh, highToLow }

class _OrderViewWidgetState extends State<OrderViewWidget> {
  // Track expanded state for each order
  final Map<int, bool> _expandedOrders = {};

  // Filter state only (no search)
  _DateFilter _dateFilter = _DateFilter.all;
  _PriceSort _priceSort = _PriceSort.none;

  List<OrderModel> _applyFilters(
    List<OrderModel> orders,
    OrderController orderController,
  ) {
    List<OrderModel> result = List.from(orders);

    // Date filter
    if (_dateFilter != _DateFilter.all) {
      final now = DateTime.now();
      result =
          result.where((order) {
            if (order.createdAt == null) return false;
            try {
              final date = DateTime.parse(order.createdAt!).toLocal();
              switch (_dateFilter) {
                case _DateFilter.today:
                  return date.year == now.year &&
                      date.month == now.month &&
                      date.day == now.day;
                case _DateFilter.week:
                  return now.difference(date).inDays < 7;
                case _DateFilter.month:
                  return date.year == now.year && date.month == now.month;
                default:
                  return true;
              }
            } catch (_) {
              return true;
            }
          }).toList();
    }

    // Price sort
    if (_priceSort == _PriceSort.lowToHigh) {
      result.sort((a, b) => (a.orderAmount ?? 0).compareTo(b.orderAmount ?? 0));
    } else if (_priceSort == _PriceSort.highToLow) {
      result.sort((a, b) => (b.orderAmount ?? 0).compareTo(a.orderAmount ?? 0));
    }

    return result;
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFCC7722); // Orange - In Progress
      case 'accepted':
      case 'confirmed':
        return const Color(0xFF2A8F5D); // Green - Done
      case 'processing':
      case 'handover':
        return const Color(0xFFCC7722); // Orange - In Progress
      case 'picked_up':
        return const Color(0xFF0097A7); // Cyan - Archived
      case 'delivered':
        return const Color(0xFF2A8F5D); // Green - Done
      case 'canceled':
      case 'failed':
        return const Color(0xFFC41D1D); // Red - Blocked
      case 'refund_requested':
      case 'refunded':
        return const Color(0xFF2A8F5D); // Green - Done
      default:
        return const Color(0xFF1565C0); // Blue - Not Started
    }
  }

  Color _getStatusBackgroundColor(String? status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFF3E0); // Light Orange - In Progress
      case 'accepted':
      case 'confirmed':
        return const Color(0xFFE8F5E9); // Light Green - Done
      case 'processing':
      case 'handover':
        return const Color(0xFFFFF3E0); // Light Orange - In Progress
      case 'picked_up':
        return const Color(0xFFE0F2F1); // Light Cyan - Archived
      case 'delivered':
        return const Color(0xFFE8F5E9); // Light Green - Done
      case 'canceled':
      case 'failed':
        return const Color(0xFFFFEBEE); // Light Red - Blocked
      case 'refund_requested':
      case 'refunded':
        return const Color(0xFFE8F5E9); // Light Green - Done
      default:
        return const Color(0xFFE3F2FD); // Light Blue - Not Started
    }
  }

  Color _getStatusTextColor(String? status) {
    switch (status) {
      case 'pending':
      case 'processing':
      case 'handover':
        return const Color(0xFFCC7722); // Orange text
      case 'accepted':
      case 'confirmed':
      case 'delivered':
      case 'refund_requested':
      case 'refunded':
        return const Color(0xFF2A8F5D); // Green text
      case 'picked_up':
        return const Color(0xFF0097A7); // Cyan text
      case 'canceled':
      case 'failed':
        return const Color(0xFFC41D1D); // Red text
      default:
        return const Color(0xFF1565C0); // Blue text
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

  String _formatOrderDate(String? createdAt) {
    if (createdAt == null) return '';
    try {
      DateTime date;
      try {
        date = DateTime.parse(createdAt).toLocal();
      } catch (_) {
        date = DateTime.parse(createdAt);
      }
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final hour =
          date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'pm' : 'am';
      final minute = date.minute.toString().padLeft(2, '0');
      return '${months[date.month - 1]} ${date.day} · $hour:$minute$amPm';
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: GetBuilder<OrderController>(
        builder: (orderController) {
          PaginatedOrderModel? paginatedOrderModel;
          if (widget.isRunning) {
            paginatedOrderModel = orderController.runningOrderModel;
          } else {
            paginatedOrderModel = orderController.historyOrderModel;
          }

          if (paginatedOrderModel != null &&
              paginatedOrderModel.orders != null) {
            for (final order in paginatedOrderModel.orders!) {
              if (order.id != null &&
                  order.orderType != 'parcel' &&
                  !(order.prescriptionOrder ?? false)) {
                orderController.fetchOrderDetailsForList(order.id!);
              }
            }
          }

          if (paginatedOrderModel == null) {
            return OrderShimmerWidget(orderController: orderController);
          }

          final allOrders = paginatedOrderModel.orders ?? [];
          final bool showSearchBar = allOrders.length > 10;
          final List<OrderModel> filteredOrders =
              showSearchBar
                  ? _applyFilters(allOrders, orderController)
                  : allOrders;

          if (allOrders.isEmpty) {
            return NoDataScreen(text: 'no_order_found'.tr, showFooter: true);
          }

          return Column(
            children: [
              // ── Search + filter bar (only when >10 orders) ──
              if (showSearchBar) _buildSearchAndFilter(primary),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    if (widget.isRunning) {
                      await orderController.getRunningOrders(1, isUpdate: true);
                    } else {
                      await orderController.getHistoryOrders(1, isUpdate: true);
                    }
                  },
                  child:
                      filteredOrders.isEmpty
                          ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.25,
                              ),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.search_off_rounded,
                                      size: 48,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'no_order_found'.tr,
                                      style: waddyRegular.copyWith(
                                        color: Colors.grey.shade400,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                          : SingleChildScrollView(
                            controller: scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: FooterView(
                              child: SizedBox(
                                width: Dimensions.maxContentWidth,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: 100,
                                    left: Dimensions.paddingSizeDefault,
                                    right: Dimensions.paddingSizeDefault,
                                    top: Dimensions.paddingSizeDefault,
                                  ),
                                  child:
                                      showSearchBar
                                          // When filtering, render flat list (no pagination needed for client-side filter)
                                          ? ListView.builder(
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            shrinkWrap: true,
                                            padding: EdgeInsets.zero,
                                            itemCount: filteredOrders.length,
                                            itemBuilder: (context, index) {
                                              final order =
                                                  filteredOrders[index];
                                              return widget.isRunning
                                                  ? _buildRunningCard(
                                                    context,
                                                    order,
                                                    orderController,
                                                    primary,
                                                  )
                                                  : _buildTalabatStyleHistoryCard(
                                                    context,
                                                    order,
                                                    orderController,
                                                    primary,
                                                  );
                                            },
                                          )
                                          : PaginatedListView(
                                            scrollController: scrollController,
                                            onPaginate: (int? offset) async {
                                              if (widget.isRunning) {
                                                await orderController
                                                    .getRunningOrders(
                                                      offset!,
                                                      isUpdate: true,
                                                    );
                                              } else {
                                                await orderController
                                                    .getHistoryOrders(
                                                      offset!,
                                                      isUpdate: true,
                                                    );
                                              }
                                            },
                                            totalSize:
                                                widget.isRunning
                                                    ? orderController
                                                        .runningOrderModel
                                                        ?.totalSize
                                                    : orderController
                                                        .historyOrderModel
                                                        ?.totalSize,
                                            offset:
                                                widget.isRunning
                                                    ? orderController
                                                        .runningOrderModel
                                                        ?.offset
                                                    : orderController
                                                        .historyOrderModel
                                                        ?.offset,
                                            itemView: ListView.builder(
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              shrinkWrap: true,
                                              padding: EdgeInsets.zero,
                                              itemCount: allOrders.length,
                                              itemBuilder: (context, index) {
                                                final order = allOrders[index];
                                                return widget.isRunning
                                                    ? _buildRunningCard(
                                                      context,
                                                      order,
                                                      orderController,
                                                      primary,
                                                    )
                                                    : _buildTalabatStyleHistoryCard(
                                                      context,
                                                      order,
                                                      orderController,
                                                      primary,
                                                    );
                                              },
                                            ),
                                          ),
                                ),
                              ),
                            ),
                          ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilter(Color primary) {
    final bool hasActiveFilter =
        _dateFilter != _DateFilter.all || _priceSort != _PriceSort.none;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Date filters
                ...[
                  (_DateFilter.all, 'all'.tr),
                  (_DateFilter.today, 'today'.tr),
                  (_DateFilter.week, 'this_week'.tr),
                  (_DateFilter.month, 'this_month'.tr),
                ].map((entry) {
                  final (filter, label) = entry;
                  final bool selected = _dateFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(
                      right: Dimensions.paddingSizeSmall,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _dateFilter = filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeMedium,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? primary : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusExtraLarge,
                          ),
                        ),
                        child: Text(
                          label,
                          style: waddyMedium.copyWith(
                            fontSize: 12,
                            color:
                                selected ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Divider
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.grey.shade200,
                  margin: const EdgeInsets.only(
                    right: Dimensions.paddingSizeSmall,
                  ),
                ),

                // Price sort toggle
                GestureDetector(
                  onTap:
                      () => setState(() {
                        if (_priceSort == _PriceSort.none) {
                          _priceSort = _PriceSort.lowToHigh;
                        } else if (_priceSort == _PriceSort.lowToHigh) {
                          _priceSort = _PriceSort.highToLow;
                        } else {
                          _priceSort = _PriceSort.none;
                        }
                      }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeMedium,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _priceSort != _PriceSort.none
                              ? primary
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusExtraLarge,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _priceSort == _PriceSort.highToLow
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size: 12,
                          color:
                              _priceSort != _PriceSort.none
                                  ? Colors.white
                                  : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _priceSort == _PriceSort.highToLow
                              ? 'price_high_low'.tr
                              : 'price_low_high'.tr,
                          style: waddyMedium.copyWith(
                            fontSize: 12,
                            color:
                                _priceSort != _PriceSort.none
                                    ? Colors.white
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Clear all filters
                if (hasActiveFilter) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap:
                        () => setState(() {
                          _dateFilter = _DateFilter.all;
                          _priceSort = _PriceSort.none;
                        }),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HIGH-CONVERSION REORDER-FIRST CARD
  //  Goal: ⚡ Decide in <2s | 💰 Maximize reorders | 🧠 Memory trigger
  // ══════════════════════════════════════════════════════════════
  Widget _buildTalabatStyleHistoryCard(
    BuildContext context,
    OrderModel order,
    OrderController orderController,
    Color primary,
  ) {
    bool isParcel = order.orderType == 'parcel';
    final bool isDelivered = order.orderStatus == 'delivered';
    final bool isCanceled =
        order.orderStatus == 'canceled' || order.orderStatus == 'failed';

    final List<OrderDetailsModel> cachedDetails =
        order.id != null
            ? (orderController.orderDetailsCache[order.id!] ?? [])
            : [];

    final storeName =
        isParcel ? 'parcel'.tr : (order.store?.name ?? 'store'.tr);
    final storeLogoUrl = order.store?.logoFullUrl ?? '';
    final priceStr = PriceConverter.convertPrice(order.orderAmount ?? 0);
    final dateStr = _formatOrderDate(order.createdAt);
    final itemCount = order.detailsCount ?? cachedDetails.length;

    // Check if this order is expanded
    final bool isExpanded = _expandedOrders[order.id] ?? false;

    // Get first item for memory trigger
    String? firstItemImage;
    if (cachedDetails.isNotEmpty) {
      firstItemImage =
          cachedDetails.first.itemDetails?.imageFullUrl ??
          cachedDetails.first.imageFullUrl;
    }

    // Build memory trigger text (e.g., "Chicken meal + fries")
    String memoryTriggerText = '';
    if (cachedDetails.isNotEmpty) {
      final firstName = cachedDetails.first.itemDetails?.name ?? '';
      if (cachedDetails.length == 1) {
        memoryTriggerText = firstName;
      } else if (cachedDetails.length == 2) {
        final secondName = cachedDetails[1].itemDetails?.name ?? '';
        memoryTriggerText = '$firstName + $secondName';
      } else {
        memoryTriggerText = '$firstName + ${cachedDetails.length - 1} more';
      }
    }

    // Calculate XP earned for this order
    int xpEarned = 0;
    final xpController = Get.find<XpController>();
    final xpConfig = xpController.xpConfig;
    if (xpConfig != null && xpConfig.levelingEnabled && isDelivered) {
      xpEarned = xpConfig.calculateEstimatedXp(
        order.orderAmount ?? 0,
        order.moduleType,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeMedium),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Status badge + Date ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                children: [
                  // Status badge — pill, ALL CAPS
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeSmall,
                      vertical: Dimensions.paddingSizeExtraSmall,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusBackgroundColor(order.orderStatus),
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusExtraLarge,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(order.orderStatus),
                          size: 14,
                          color: _getStatusColor(order.orderStatus),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          (order.orderStatus?.tr ?? '').toUpperCase(),
                          style: waddyBold.copyWith(
                            fontSize: 11,
                            color: _getStatusTextColor(order.orderStatus),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: waddyRegular.copyWith(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            // ── Row 2: Food image + info ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Food image — larger, square
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    child: Container(
                      width: 74,
                      height: 74,
                      color: Colors.grey.shade100,
                      child:
                          _isValidUrl(firstItemImage)
                              ? CustomImage(
                                image: firstItemImage!,
                                height: 74,
                                width: 74,
                                fit: BoxFit.cover,
                              )
                              : _isValidUrl(storeLogoUrl)
                              ? CustomImage(
                                image: storeLogoUrl,
                                height: 74,
                                width: 74,
                                fit: BoxFit.cover,
                              )
                              : Center(
                                child: Icon(
                                  isParcel
                                      ? Icons.inventory_2_rounded
                                      : Icons.fastfood_rounded,
                                  color: Colors.grey.shade400,
                                  size: 32,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Text info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memoryTriggerText.isNotEmpty
                              ? memoryTriggerText
                              : storeName,
                          style: waddyBold.copyWith(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$storeName • $itemCount ${itemCount == 1 ? 'item'.tr : 'items'.tr}',
                          style: waddyRegular.copyWith(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          priceStr,
                          style: waddyBold.copyWith(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Row 3: Reorder button ──
            if (isDelivered || isCanceled)
              _OrderAgainButton(
                orderId: order.id!,
                orderController: orderController,
                xpEarned: xpEarned,
              ),

            // ── Row 4: Rate to earn + View Details ──
            if (isDelivered || isCanceled)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: Row(
                  children: [
                    if (isDelivered)
                      GestureDetector(
                        onTap: () {
                          final List<OrderDetailsModel> orderDetailsList = [];
                          final List<int?> orderDetailsIdList = [];
                          for (var detail in cachedDetails) {
                            if (detail.itemDetails?.id != null &&
                                !orderDetailsIdList.contains(
                                  detail.itemDetails!.id,
                                )) {
                              orderDetailsList.add(detail);
                              orderDetailsIdList.add(detail.itemDetails!.id);
                            }
                          }
                          if (orderDetailsList.isNotEmpty) {
                            Get.toNamed(
                              RouteHelper.getReviewRoute(),
                              arguments: RateReviewScreen(
                                orderDetailsList: orderDetailsList,
                                deliveryMan: order.deliveryMan,
                                orderID: order.id,
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_border_rounded,
                              color: Colors.grey.shade400,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              xpEarned > 0
                                  ? '${'rate_to_earn'.tr} +$xpEarned'
                                  : 'rate_to_earn'.tr,
                              style: waddyRegular.copyWith(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    GestureDetector(
                      onTap:
                          () => Get.toNamed(
                            RouteHelper.getOrderDetailsRoute(order.id),
                            arguments: OrderDetailsScreen(
                              orderId: order.id,
                              orderModel: order,
                            ),
                          ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'view_details'.tr,
                            style: waddyRegular.copyWith(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (!isDelivered && !isCanceled)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap:
                          () => Get.toNamed(
                            RouteHelper.getOrderDetailsRoute(order.id),
                            arguments: OrderDetailsScreen(
                              orderId: order.id,
                              orderModel: order,
                            ),
                          ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'view_details'.tr,
                            style: waddyRegular.copyWith(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════
  //  RUNNING CARD — Redesigned with smart UX actions & progress bar
  // ══════════════════════════════════════════════════════════════
  Widget _buildRunningCard(
    BuildContext context,
    OrderModel order,
    OrderController orderController,
    Color primary,
  ) {
    bool isParcel = order.orderType == 'parcel';
    final storeName =
        isParcel ? 'parcel'.tr : (order.store?.name ?? 'store'.tr);
    final itemCount = order.detailsCount ?? 0;
    final status = order.orderStatus?.toLowerCase() ?? '';

    // Get first item image and names
    final List<OrderDetailsModel> cachedDetails =
        order.id != null
            ? (orderController.orderDetailsCache[order.id!] ?? [])
            : [];

    String? firstItemImage;
    String memoryTriggerText = '';
    final List<String> itemNames = [];

    for (final detail in cachedDetails) {
      if (firstItemImage == null) {
        final img = '${detail.imageFullUrl}';
        if (_isValidUrl(img)) {
          firstItemImage = img;
        } else {
          final itemImg = '${detail.itemDetails?.imageFullUrl}';
          if (_isValidUrl(itemImg)) {
            firstItemImage = itemImg;
          }
        }
      }
      if (detail.itemDetails?.name != null) {
        itemNames.add(detail.itemDetails!.name!);
      }
    }

    if (itemNames.isNotEmpty) {
      final firstName = itemNames.first;
      if (itemNames.length == 1) {
        memoryTriggerText = firstName;
      } else if (itemNames.length == 2) {
        memoryTriggerText = '$firstName + 1';
      } else {
        memoryTriggerText = '$firstName + ${itemNames.length - 1} more';
      }
    }

    // ETA display: use computed estimatedDelivery, fallback to store.deliveryTime
    String etaText = '';
    if (order.estimatedDelivery != null &&
        order.estimatedDelivery!.isNotEmpty) {
      etaText = order.estimatedDelivery!;
    } else if (order.store?.deliveryTime != null &&
        order.store!.deliveryTime!.isNotEmpty) {
      etaText = order.store!.deliveryTime!;
    }

    // Journey step: 0=placed 1=preparing 2=on-the-way 3=delivered
    int journeyStep = 0;
    if (status.contains('confirmed') || status.contains('processing')) {
      journeyStep = 1;
    } else if (status.contains('handover') ||
        status.contains('picked_up') ||
        status.contains('out_for_delivery')) {
      journeyStep = 2;
    } else if (status.contains('delivered')) {
      journeyStep = 3;
    }

    // Determine track button text and icon
    String trackButtonText;
    IconData trackButtonIcon;
    if (status.contains('pending')) {
      trackButtonText = 'view_status'.tr;
      trackButtonIcon = Icons.visibility_rounded;
    } else if (status.contains('processing') || status.contains('confirmed')) {
      trackButtonText = 'track_live'.tr;
      trackButtonIcon = Icons.radar_rounded;
    } else if (status.contains('out_for_delivery') ||
        status.contains('handover')) {
      trackButtonText = 'track_rider'.tr;
      trackButtonIcon = Icons.delivery_dining_rounded;
    } else {
      trackButtonText = isParcel ? 'track_delivery'.tr : 'track_order'.tr;
      trackButtonIcon = Icons.my_location_rounded;
    }

    final bool isLive = journeyStep == 2;

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeMedium),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER: Status badge (left) · ETA timer (right) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status badge with green dot
                  _buildStatusBadge(status, primary),
                  // ETA section: "ARRIVING IN" + bold time
                  if (etaText.isNotEmpty) _buildEtaSection(etaText, primary),
                ],
              ),
            ),

            // ── CONTENT: 74×74 image + item name + store + price ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food image 74×74 rounded
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primary.withValues(alpha: 0.1),
                            primary.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                      child:
                          _isValidUrl(firstItemImage)
                              ? CustomImage(
                                image: firstItemImage!,
                                height: 74,
                                width: 74,
                                fit: BoxFit.cover,
                              )
                              : Center(
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    Colors.grey.shade400,
                                    BlendMode.srcIn,
                                  ),
                                  child: Image.asset(
                                    'assets/image/waddy.png',
                                    height: 48,
                                    width: 48,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text: Item name (16px bold), Store + count (14px grey), Price (16px bold)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memoryTriggerText.isNotEmpty
                              ? memoryTriggerText
                              : storeName,
                          style: waddyBold.copyWith(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$storeName • $itemCount ${itemCount == 1 ? 'item'.tr : 'items'.tr}',
                          style: waddyRegular.copyWith(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          PriceConverter.convertPrice(order.orderAmount ?? 0),
                          style: waddyBold.copyWith(
                            fontSize: 16,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── TRACK BUTTON: Simple button with just "Track Order" ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: CustomButton(
                buttonText: trackButtonText,
                onPressed:
                    () => Get.toNamed(
                      RouteHelper.getOrderDetailsRoute(order.id),
                      arguments: OrderDetailsScreen(
                        orderId: order.id,
                        orderModel: order,
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HELPER: Status badge with green dot
  // ══════════════════════════════════════════════════════════════
  Widget _buildStatusBadge(String status, Color primary) {
    final Color statusColor = _getStatusColor(
      status.isNotEmpty ? status.replaceAll('_', ' ') : null,
    );

    // Green dot for in-transit/active statuses
    bool showGreenDot =
        status.contains('confirmed') ||
        status.contains('processing') ||
        status.contains('handover') ||
        status.contains('picked_up') ||
        status.contains('out_for_delivery');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (status.isEmpty ? 'pending' : status)
                .replaceAll('_', ' ')
                .toUpperCase(),
            style: waddyMedium.copyWith(
              fontSize: 11,
              color: statusColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HELPER: ETA display ("ARRIVING IN" label + bold time)
  // ══════════════════════════════════════════════════════════════
  Widget _buildEtaSection(String etaText, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'arriving_in'.tr.toUpperCase(),
          style: waddyRegular.copyWith(
            fontSize: 10,
            color: Colors.grey.shade500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          etaText,
          style: waddyBold.copyWith(
            fontSize: 18,
            color: Theme.of(context).primaryColor, // Neon green
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HELPER: Inline action text (no button styling)
  // ══════════════════════════════════════════════════════════════
  Widget _buildInlineActionText(String status, Color primary) {
    String actionLabel = '';
    VoidCallback? onTap;

    if (status.contains('pending') || status.isEmpty) {
      actionLabel = 'contact_support'.tr;
      onTap = () => _openSupportScreen();
    } else if (status.contains('accepted') || status.contains('confirmed')) {
      actionLabel = 'live_chat'.tr;
      onTap = () => _openChatWithStore('');
    } else if (status.contains('processing')) {
      actionLabel = 'live_chat'.tr;
      onTap = () => _openChatWithStore('');
    } else if (status.contains('handover') ||
        status.contains('picked_up') ||
        status.contains('out_for_delivery')) {
      actionLabel = 'chat_with_courier'.tr;
      onTap = () => _openChatWithDriver();
    } else {
      actionLabel = 'get_help'.tr;
      onTap = () => _openSupportScreen();
    }

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_rounded, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            actionLabel,
            style: waddyRegular.copyWith(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ACTION HANDLERS
  // ══════════════════════════════════════════════════════════════

  void _openSupportScreen() {
    // TODO: Navigate to support screen or create support ticket
    showCustomSnackBar(
      'support_feature_coming_soon'.tr,
      isError: false,
      showDuration: 2,
    );
  }

  void _openChatWithStore(String storeName) {
    Get.toNamed(RouteHelper.getChatRoute(notificationBody: null));
  }

  void _openChatWithDriver() {
    Get.toNamed(RouteHelper.getChatRoute(notificationBody: null));
  }

  Future<void> _callCourier(String phone) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else if (mounted) {
        showCustomSnackBar('dialer_error'.tr, showDuration: 2);
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar('call_failed'.tr, showDuration: 2);
      }
    }
  }
}

// Button state enum for micro-interactions
enum _ButtonState { idle, loading, success }

// Order Again Button with micro-interactions
class _OrderAgainButton extends StatefulWidget {
  final int orderId;
  final OrderController orderController;
  final int xpEarned;

  const _OrderAgainButton({
    required this.orderId,
    required this.orderController,
    required this.xpEarned,
  });

  @override
  State<_OrderAgainButton> createState() => _OrderAgainButtonState();
}

class _OrderAgainButtonState extends State<_OrderAgainButton>
    with SingleTickerProviderStateMixin {
  _ButtonState _state = _ButtonState.idle;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
    );
    _scaleController.value = 1.0;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _handleReorder() async {
    if (_state != _ButtonState.idle) return;

    // Scale down animation
    setState(() => _state = _ButtonState.loading);
    await _scaleController.animateTo(
      0.92,
      duration: const Duration(milliseconds: 120),
    );
    await _scaleController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 150),
    );

    // Perform reorder
    final result = await widget.orderController.reorder(widget.orderId);

    if (result != null) {
      // Success state with longer display
      setState(() => _state = _ButtonState.success);

      // Show XP toast if applicable
      if (widget.xpEarned > 0) {
        _showXpToast();
      }

      // Let success state show longer for satisfaction
      await Future.delayed(const Duration(milliseconds: 1200));
      Get.toNamed(RouteHelper.getCartRoute());
    } else {
      // Reset on failure
      setState(() => _state = _ButtonState.idle);
    }
  }

  void _showXpToast() {
    Get.showSnackbar(
      GetSnackBar(
        messageText: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF134E4A),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF134E4A).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/image/waddy_coin.png', width: 18, height: 18),
              const SizedBox(width: 6),
              Text(
                '+${widget.xpEarned} coins earned!',
                style: waddyBold.copyWith(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.only(bottom: 80),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color brandNeon = Theme.of(context).secondaryHeaderColor;
    Color brandDark = Color(0xFF134E4A);
    Color successGreen = Color(0xFF00C853);

    final bgColor = _state == _ButtonState.success ? successGreen : brandNeon;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: GestureDetector(
        onTap: _handleReorder,
        child: AnimatedBuilder(
          animation: _scaleController,
          builder:
              (context, child) =>
                  Transform.scale(scale: _scaleController.value, child: child),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: Dimensions.paddingSizeMedium,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildButtonContent(brandDark, successGreen),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonContent(Color textColor, Color successGreen) {
    switch (_state) {
      case _ButtonState.loading:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          key: const ValueKey('loading'),
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'adding'.tr.toUpperCase(),
              style: waddyBold.copyWith(
                fontSize: 13,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      case _ButtonState.success:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          key: const ValueKey('success'),
          children: [
            Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'added_to_cart'.tr,
              style: waddyBold.copyWith(
                fontSize: 12,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        );
      case _ButtonState.idle:
        return Row(
          key: const ValueKey('idle'),
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'reorder'.tr,
              style: waddyBold.copyWith(fontSize: 14, color: textColor),
            ),
            if (widget.xpEarned > 0) ...[
              const SizedBox(width: 8),
              Image.asset('assets/image/waddy_coin.png', width: 18, height: 18),
              const SizedBox(width: 4),
              Text(
                '+${widget.xpEarned}',
                style: waddyBold.copyWith(fontSize: 14, color: textColor),
              ),
            ],
          ],
        );
    }
  }
}

// ──────────────────────────────────────────────────────────────
//  ORDER JOURNEY STEPPER
//  4 steps: Placed → Preparing → On the way → Delivered
// ──────────────────────────────────────────────────────────────
// ──────────────────────────────────────────────────────────────
//  TRACK ORDER BUTTON — same neon pill style as reorder button
//  Pulses when order is in transit (isLive = true)
// ──────────────────────────────────────────────────────────────
class _TrackOrderButton extends StatefulWidget {
  final bool isLive;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TrackOrderButton({
    required this.isLive,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_TrackOrderButton> createState() => _TrackOrderButtonState();
}

class _TrackOrderButtonState extends State<_TrackOrderButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isLive) _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color brandNeon = Theme.of(context).secondaryHeaderColor;
    const Color brandDark = Color(0xFF134E4A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder:
              (context, child) => Transform.scale(
                scale: widget.isLive ? _pulseAnim.value : 1.0,
                child: child,
              ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: Dimensions.paddingSizeMedium,
              horizontal: Dimensions.paddingSizeMedium,
            ),
            decoration: BoxDecoration(
              color: brandNeon,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              boxShadow: [
                BoxShadow(
                  color: brandNeon.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLive) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: brandDark,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(widget.icon, size: 16, color: brandDark),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: waddyMedium.copyWith(
                    fontSize: 14,
                    color: brandDark,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
