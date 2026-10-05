import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/review/controllers/review_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/review/widgets/deliver_man_review_widget.dart';
import 'package:waddy_app/features/review/widgets/item_review_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RateReviewScreen extends StatefulWidget {
  final List<OrderDetailsModel> orderDetailsList;
  final DeliveryMan? deliveryMan;
  final int? orderID;

  /// Stars already tapped on the order screen; pre-fills every rating so the
  /// tap isn't lost. 0 leaves them empty.
  final int initialRating;
  const RateReviewScreen({
    super.key,
    required this.orderDetailsList,
    required this.deliveryMan,
    required this.orderID,
    this.initialRating = 0,
  });

  @override
  RateReviewScreenState createState() => RateReviewScreenState();
}

class RateReviewScreenState extends State<RateReviewScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length:
          (widget.deliveryMan == null || widget.orderDetailsList.isEmpty)
              ? 1
              : 2,
      initialIndex: 0,
      vsync: this,
    );
    Get.find<ReviewController>().initRatingData(
      widget.orderDetailsList,
      initialRating: widget.initialRating,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: CustomAppBar(title: 'rate_review'.tr),
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body: Column(
        children: [
          Center(
            child: Container(
              width: Dimensions.maxContentWidth,
              color: Theme.of(context).cardColor,
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).textTheme.bodyLarge!.color,
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 3,
                unselectedLabelStyle: waddyRegular.copyWith(
                  color: Theme.of(context).disabledColor,
                  fontSize: Dimensions.fontSizeSmall,
                ),
                labelStyle: waddyMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                ),
                tabs:
                    widget.orderDetailsList.isNotEmpty
                        ? widget.deliveryMan != null
                            ? [
                              Tab(
                                text:
                                    widget.orderDetailsList.length > 1
                                        ? 'items'.tr
                                        : 'item'.tr,
                              ),
                              Tab(text: 'delivery_man'.tr),
                            ]
                            : [
                              Tab(
                                text:
                                    widget.orderDetailsList.length > 1
                                        ? 'items'.tr
                                        : 'item'.tr,
                              ),
                            ]
                        : [Tab(text: 'delivery_man'.tr)],
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children:
                  widget.orderDetailsList.isNotEmpty
                      ? widget.deliveryMan != null
                          ? [
                            ItemReviewWidget(
                              orderDetailsList: widget.orderDetailsList,
                            ),
                            DeliveryManReviewWidget(
                              deliveryMan: widget.deliveryMan,
                              orderID: widget.orderID.toString(),
                            ),
                          ]
                          : [
                            ItemReviewWidget(
                              orderDetailsList: widget.orderDetailsList,
                            ),
                          ]
                      : [
                        DeliveryManReviewWidget(
                          deliveryMan: widget.deliveryMan,
                          orderID: widget.orderID.toString(),
                        ),
                      ],
            ),
          ),
        ],
      ),
    );
  }
}
