import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/rental_module/rental_order/controllers/taxi_order_controller.dart';
import 'package:sixam_mart/features/rental_module/rental_order/widgets/trip_order_view_widget.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/taxi_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/features/order/widgets/order_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OrderScreen extends StatefulWidget {
  final int? index;
  const OrderScreen({super.key, this.index = 0});

  @override
  OrderScreenState createState() => OrderScreenState();
}

class OrderScreenState extends State<OrderScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  bool _isLoggedIn = AuthHelper.isLoggedIn();
  List<String> type = ['orders', 'trips'];
  int selectTypeIndex = 0;
  bool haveTaxiModule = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, initialIndex: 0, vsync: this);
    _tabController!.addListener(() => setState(() {}));
    selectTypeIndex = widget.index!;
    haveTaxiModule = TaxiHelper.haveTaxiModule();

    initCall();
  }

  void initCall(){
    if(AuthHelper.isLoggedIn()) {
      if(selectTypeIndex == 0) {
        Get.find<OrderController>().getRunningOrders(1);
        Get.find<OrderController>().getHistoryOrders(1);
      } else {
        Get.find<TaxiOrderController>().getTripList(1, isRunning: true);
        Get.find<TaxiOrderController>().getTripList(1, isRunning: false);
      }
    }
  }

  void _switchOrderType(int newIndex) {
    setState(() {
      selectTypeIndex = newIndex;
      // Reset tab to first tab when switching types
      _tabController?.index = 0;
    });
    initCall();
  }

  @override
  Widget build(BuildContext context) {
    _isLoggedIn = AuthHelper.isLoggedIn();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _CoinsPill(teal: Theme.of(context).primaryColor, textDark: Theme.of(context).textTheme.bodyLarge!.color!),
          ),
        ],
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          'orders'.tr,
          style: robotoBold.copyWith(
            fontSize: 24,
            color: const Color(0xFF134E4A),
          ),
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      endDrawer: const MenuDrawer(), 
      endDrawerEnableOpenDragGesture: false,
      body: SafeArea(
        child: GetBuilder<OrderController>(
          builder: (orderController) {
            if (!_isLoggedIn) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                  child: Text('please_login_to_view_orders'.tr),
                ),
              );
            }
            return Column(
              children: [
                if (haveTaxiModule && !ResponsiveHelper.isDesktop(context))
                  _buildTypeSelector(),
                if (_isLoggedIn) _buildCustomTabSelector(),
                Expanded(
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [],
                    body: TabBarView(
                      controller: _tabController,
                      children: selectTypeIndex == 0
                          ? const [
                              OrderViewWidget(isRunning: true),
                              OrderViewWidget(isRunning: false),
                            ]
                          : const [
                              TripOrderViewWidget(isRunning: true),
                              TripOrderViewWidget(isRunning: false),
                            ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }


  // Type selector (Orders/Trips) — only when taxi module is active
  Widget _buildTypeSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(type.length, (index) {
          bool selected = index == selectTypeIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => _switchOrderType(index),
              child: Container(
                margin: EdgeInsets.only(right: index == 0 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Theme.of(context).primaryColor : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  type[index].tr,
                  style: robotoMedium.copyWith(
                    fontSize: 14,
                    color: selected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  CUSTOM TAB SELECTOR: Running / History with counts + animation
  // ══════════════════════════════════════════════════════════════
  Widget _buildCustomTabSelector() {
    return GetBuilder<OrderController>(
      builder: (orderController) {
        final runningCount =
            orderController.runningOrderModel?.orders?.length ?? 0;
        final historyCount =
            orderController.historyOrderModel?.orders?.length ?? 0;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildTab(
                index: 0,
                label: 'running'.tr,
                count: runningCount,
              ),
              const SizedBox(width: 10),
              _buildTab(
                index: 1,
                label: 'history'.tr,
                count: historyCount,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab({required int index, required String label, required int count}) {
    final bool selected = _tabController?.index == index;
    final Color primary = const Color(0xFF134E4A);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController?.animateTo(
            index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '$label ($count)',
                style: selected
                    ? robotoBold.copyWith(fontSize: 14, color: primary)
                    : robotoRegular.copyWith(fontSize: 14, color: Colors.grey.shade500),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: 2,
              decoration: BoxDecoration(
                color: selected ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// XP pill — dark teal rounded pill with icon + XP points count
class _CoinsPill extends StatelessWidget {
  final Color teal;
  final Color textDark;
  const _CoinsPill({required this.teal, required this.textDark});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      builder: (xpController) {
        final xpPoints = xpController.currentLevel?.currentXp ?? 0;
        return GestureDetector(
          onTap: () => Get.toNamed(RouteHelper.getMainRoute('levels')),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF134E4A),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/image/waddy_coin.png',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '$xpPoints',
                  style: robotoBold.copyWith(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
