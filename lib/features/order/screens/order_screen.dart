import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/order/widgets/order_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  OrderScreenState createState() => OrderScreenState();
}

class OrderScreenState extends State<OrderScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool _isLoggedIn = AuthHelper.isLoggedIn();

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, initialIndex: 0, vsync: this);
    _tabController!.addListener(() => setState(() {}));

    initCall();
  }

  void initCall() {
    if (AuthHelper.isLoggedIn()) {
      Get.find<OrderController>().getRunningOrders(1);
      Get.find<OrderController>().getHistoryOrders(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    _isLoggedIn = AuthHelper.isLoggedIn();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: Dimensions.paddingSizeDefault,
            ),
            child: _CoinsPill(
              teal: Theme.of(context).primaryColor,
              textDark: Theme.of(context).textTheme.bodyLarge!.color!,
            ),
          ),
        ],
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          'orders'.tr,
          style: waddyBold.copyWith(
            fontSize: 24,
            color: const Color(0xFF134E4A),
          ),
        ),
        leading:
            Navigator.canPop(context)
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
                if (_isLoggedIn) _buildCustomTabSelector(),
                Expanded(
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [],
                    body: TabBarView(
                      controller: _tabController,
                      children: const [
                        OrderViewWidget(isRunning: true),
                        OrderViewWidget(isRunning: false),
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
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          child: Row(
            children: [
              _buildTab(index: 0, label: 'running'.tr, count: runningCount),
              const SizedBox(width: 10),
              _buildTab(index: 1, label: 'history'.tr, count: historyCount),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab({
    required int index,
    required String label,
    required int count,
  }) {
    final bool selected = _tabController?.index == index;
    const Color primary = Color(0xFF134E4A);
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
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeSmall,
              ),
              child: Text(
                '$label ($count)',
                style:
                    selected
                        ? waddyBold.copyWith(fontSize: 14, color: primary)
                        : waddyRegular.copyWith(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
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
      id: XpController.idLevel,
      builder: (xpController) {
        final xpPoints = xpController.currentLevel?.currentXp ?? 0;
        return GestureDetector(
          onTap: () => RouteHelper.goToTab(RouteHelper.tabRewards),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeMedium,
              vertical: Dimensions.paddingSizeSmall,
            ),
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
                  style: waddyBold.copyWith(fontSize: 15, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
