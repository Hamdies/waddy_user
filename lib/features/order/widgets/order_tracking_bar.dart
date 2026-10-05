import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/overhang_badge.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_stamp.dart';
import 'package:waddy_app/features/order/screens/order_details_screen.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/styles.dart';

/// The order-tracking twin of `PillCartBar`: a fixed bottom sheet that tells
/// the user where their running order is, replacing the "Track" card that used
/// to scroll away with the home feed.
///
/// Same ground and Lottie badge as the cart bar so the two read as one family,
/// but it answers the two questions someone with an order running actually has
/// — *where is it* and *when does it arrive* — and nothing else until asked:
///
/// ```
///        ╭────╮
///   ╭────┼────┼───────────────────╮
///   │    ╰────╯  Being Prepared [Track] │  ← Track: order details
///   │             Arrives [10:48 – 10:58 PM]
///   │  ▬▬▬▬▬▬▬ ▬▬▬▬▬▬▬ ▬▬▬▬▬▬▬ ▬▬▬▬▬▬▬ │  ← one segment per stage
///   ╰─────────────────────────────╯
/// ```
///
/// Tapping the status text expands it: the order's summary (items, total), any
/// other running orders, View all, and a call button once a courier is
/// assigned.
///
/// The arrival window is the server's ETA ±5 minutes, the same convention as
/// `OrderModel.estimatedDelivery`: a range sets a realistic expectation, a
/// single minute does not.
class OrderTrackingBar extends StatefulWidget {
  /// Opens the full list of running orders. A callback, not a route push, so
  /// the dashboard can switch its own tab instead of stacking a second one.
  final VoidCallback onViewAll;

  /// True when another bar (the nav, or the cart bar) sits directly beneath
  /// this one. That bar already carries the system bottom inset inside its
  /// ground, so this one must not add it a second time.
  final bool hasBarBelow;

  /// Extra white under the bar's content, so the badge that `PillCartBar`
  /// overhangs upward lands on this bar's ground instead of on its content.
  final double belowClearance;

  const OrderTrackingBar({
    super.key,
    required this.onViewAll,
    this.hasBarBelow = true,
    this.belowClearance = 0,
  });

  /// Height a scrolling page must leave for this bar, INCLUDING the badge's
  /// overhang (painted above the box, still on top of content). Zero when the
  /// bar is not showing. Always the COLLAPSED height: the expanded panel is a
  /// transient overlay the user dismisses, and pushing the page's content
  /// around under their thumb while they read it would be worse than covering
  /// the last row for a moment. Pages that reserve for the nav or the cart bar
  /// add this on top — see `OrderTrackingReserve`.
  static final ValueNotifier<double> reserve = ValueNotifier<double>(0);

  /// The orders the bar speaks for: running and not yet delivered.
  ///
  /// This is only the orders that are LOADED. The dashboard asks the server for
  /// one (a count, not a list — see `_getRunningOrderList`), and the home reload
  /// joins that same request, so a user with three orders running has one here.
  /// Use [activeTotal] for how many there really are.
  static List<OrderModel> activeOrders(OrderController ctrl) =>
      ctrl.runningOrderModel?.orders
          ?.where((o) => o.orderStatus != AppConstants.delivered)
          .toList() ??
      const [];

  /// How many orders are running, per the server's `total_size`, never fewer
  /// than the [loaded] ones.
  static int activeTotal(OrderController ctrl, List<OrderModel> loaded) {
    final int reported = ctrl.runningOrderModel?.totalSize ?? 0;
    return reported > loaded.length ? reported : loaded.length;
  }

  @override
  State<OrderTrackingBar> createState() => _OrderTrackingBarState();
}

class _OrderTrackingBarState extends State<OrderTrackingBar>
    with WidgetsBindingObserver {
  static const Duration _kExpand = Duration(milliseconds: 240);

  /// The order-details screen polls every 10 seconds; the bar is the same
  /// information on another surface and must not lag it.
  static const Duration _kPoll = Duration(seconds: 10);

  final GlobalKey _barKey = GlobalKey();
  bool _expanded = false;

  /// True from a toggle until the size animation has finished. A measurement
  /// taken mid-animation reads a height that is neither state's, and would be
  /// published as the reserve.
  bool _settling = false;
  Timer? _settleTimer;

  /// Live updates. The running-orders list is only reloaded by a foreground
  /// push or a home reload, so a status that changes while the user sits on
  /// this bar (a store accepting, a courier picking up) never reached it — it
  /// took an app restart. The bar polls instead, but only while there is an
  /// order to watch and the app is in the foreground.
  Timer? _pollTimer;
  bool _wantPolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _settleTimer?.cancel();
    _publishReserve(0);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Whatever happened while the app was away is stale now; ask at once
      // rather than waiting out a tick.
      if (_wantPolling) {
        _refresh();
        _startPolling();
      }
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _refresh() {
    Get.find<OrderController>().refreshRunningOrdersQuietly();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_kPoll, (_) => _refresh());
  }

  /// Idempotent; called after every build with whether there is an order to
  /// watch, so polling starts with the first one and stops with the last.
  void _syncPolling(bool want) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _wantPolling = want;
      if (!want) {
        _pollTimer?.cancel();
        _pollTimer = null;
      } else if (_pollTimer == null) {
        _startPolling();
      }
    });
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = !_expanded;
      _settling = true;
    });
    _settleTimer?.cancel();
    _settleTimer = Timer(_kExpand + const Duration(milliseconds: 60), () {
      if (!mounted) return;
      _settling = false;
      _measureReserve();
    });
  }

  /// Published after the frame: listeners are pages that rebuild a spacer, and
  /// notifying them mid-build (or mid-unmount) is a framework error.
  void _publishReserve(double value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (OrderTrackingBar.reserve.value != value) {
        OrderTrackingBar.reserve.value = value;
      }
    });
  }

  void _measureReserve() {
    if (_expanded || _settling) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _expanded || _settling) return;
      final RenderBox? box =
          _barKey.currentContext?.findRenderObject() as RenderBox?;
      final double h =
          box == null ? 0 : box.size.height + OverhangBadge.overhang;
      if ((OrderTrackingBar.reserve.value - h).abs() > 0.5) {
        OrderTrackingBar.reserve.value = h;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthHelper.isLoggedIn()) {
      _publishReserve(0);
      _syncPolling(false);
      return const SizedBox.shrink();
    }

    return GetBuilder<OrderController>(
      builder: (ctrl) {
        final List<OrderModel> orders = OrderTrackingBar.activeOrders(ctrl);
        if (orders.isEmpty) {
          _publishReserve(0);
          _syncPolling(false);
          return const SizedBox.shrink();
        }
        _syncPolling(true);
        _measureReserve();

        final OrderModel order = orders.first;
        final _Stage stage = _Stage.of(order.orderStatus ?? '');

        return Container(
          key: _barKey,
          decoration: const BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: WaddyColors.shadowTeal,
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 10,
            bottom:
                widget.hasBarBelow
                    ? 8 + widget.belowClearance
                    : MediaQuery.paddingOf(context).bottom + 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                order: order,
                stage: stage,
                expanded: _expanded,
                onToggle: _toggle,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _StageStrip(stage: stage),
              ),
              AnimatedSize(
                duration: _kExpand,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child:
                    _expanded
                        ? _Details(
                          orders: orders,
                          total: OrderTrackingBar.activeTotal(ctrl, orders),
                          onViewAll: widget.onViewAll,
                        )
                        : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Opens one order's details screen — what the Track button and the other-order
/// rows both mean.
void _openOrder(OrderModel order) {
  HapticFeedback.lightImpact();
  Get.toNamed(
    RouteHelper.getOrderDetailsRoute(order.id),
    arguments: OrderDetailsScreen(orderId: order.id, orderModel: order),
  );
}

// ═══════════════════════════════════════════
// Stage model
// ═══════════════════════════════════════════

/// What the bar says and shows for one order status.
class _Stage {
  final String labelKey;
  final String asset;

  /// Which of the strip's segments is current (0-based), or null when the
  /// status is not one the bar can place — no strip is filled rather than a
  /// wrong one.
  final int? index;

  /// How far through the current segment the order is, 0..1.
  final double within;

  /// The store has not accepted yet: the title names the store the customer is
  /// waiting on instead of the bare status.
  final bool awaitingStore;

  const _Stage(
    this.labelKey,
    this.asset,
    this.index,
    this.within, {
    this.awaitingStore = false,
  });

  /// Placed → confirmed → preparing → on the way.
  static const int segments = 4;

  static _Stage of(String status) {
    switch (status) {
      case AppConstants.pending:
        return const _Stage(
          'order_placed',
          'assets/animation/order_placed.json',
          0,
          0.5,
          awaitingStore: true,
        );
      case AppConstants.accepted:
      case AppConstants.confirmed:
        return const _Stage(
          'order_confirmed',
          'assets/animation/order_confirmed.json',
          1,
          0.5,
        );
      case AppConstants.processing:
        return const _Stage(
          'being_prepared',
          'assets/animation/preparing_order.json',
          2,
          0.5,
        );
      case AppConstants.handover:
        return const _Stage(
          'ready_for_pickup',
          'assets/animation/delivery_order.json',
          3,
          0.3,
        );
      case AppConstants.pickedUp:
        return const _Stage(
          'order_arriving',
          'assets/animation/delivery_order.json',
          3,
          0.7,
        );
      default:
        return const _Stage(
          'in_progress',
          'assets/animation/completed_order.json',
          null,
          0,
        );
    }
  }
}

// ═══════════════════════════════════════════
// Arrival
// ═══════════════════════════════════════════

/// When an order arrives, in the two shapes the bar can say it.
class _Arrival {
  /// "10:48 PM – 10:58 PM", or null when there is no usable ETA.
  final String? window;

  /// "10–30 mins" from the store's own range, used only when [window] is null.
  final String? range;

  /// The ETA has passed.
  final bool due;

  const _Arrival({this.window, this.range, this.due = false});

  static _Arrival of(OrderModel order) {
    // `stampToLocal`, not a bare DateTime.parse: the ETA is a naive wall-clock
    // string in the SERVER's timezone, so reading it as device-local would
    // print a clock time that is off by the zone difference.
    final DateTime? eta = order.stampToLocal(order.estimatedDeliveryAt);
    if (eta != null) {
      final DateTime now = DateTime.now();
      if (!eta.isAfter(now)) return const _Arrival(due: true);
      DateTime lo = eta.subtract(const Duration(minutes: 5));
      if (lo.isBefore(now)) lo = now;
      final DateTime hi = eta.add(const Duration(minutes: 5));
      return _Arrival(window: _window(lo, hi));
    }
    return _Arrival(range: _storeRange(order.store?.deliveryTime));
  }

  /// "10:48 – 10:58 PM": the meridiem is said once when both ends share it.
  /// The Track button beside the text leaves little width, and "PM" twice is
  /// the part that costs it.
  static String _window(DateTime lo, DateTime hi) {
    String a = DateConverter.dateToTimeOnly(lo);
    final String b = DateConverter.dateToTimeOnly(hi);
    final List<String> pa = a.split(' ');
    final List<String> pb = b.split(' ');
    if (pa.length == 2 && pb.length == 2 && pa[1] == pb[1]) a = pa[0];
    return '$a \u2013 $b';
  }

  static String? _storeRange(String? dt) {
    if (dt == null || dt.isEmpty) return null;
    final List<String> parts = dt.split('-');
    if (parts.length == 2) {
      final int? lo = int.tryParse(parts[0].trim());
      final int? hi = int.tryParse(parts[1].trim());
      if (lo != null && hi != null) return '$lo–$hi ${'mins'.tr}';
    }
    final int? single = int.tryParse(dt.trim());
    if (single != null) return '$single ${'mins'.tr}';
    return dt;
  }
}

// ═══════════════════════════════════════════
// Header + strip
// ═══════════════════════════════════════════

/// Badge, stage title, arrival chip and the expand chevron. The whole row
/// toggles the panel.
class _Header extends StatelessWidget {
  final OrderModel order;
  final _Stage stage;
  final bool expanded;
  final VoidCallback onToggle;

  const _Header({
    required this.order,
    required this.stage,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final String? storeName = order.store?.name;
    final bool waiting =
        stage.awaitingStore && storeName != null && storeName.isNotEmpty;
    // "Waiting for Pet Mart to confirm" — until the store accepts there is no
    // arrival to promise, so this state carries the store in the title and no
    // arrival line.
    final String label =
        waiting
            ? 'waiting_for_store_to_confirm'.trParams({'store': storeName})
            : stage.labelKey.tr;
    final _Arrival arrival = _Arrival.of(order);
    final bool enRoute = order.orderStatus == AppConstants.pickedUp;

    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // The stage changes the animation; cross-fade so the swap is a
                // hand-off rather than a cut. The default layout clips, which
                // would shear off the badge's overhang, hence the custom one.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  layoutBuilder:
                      (current, previous) => Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [...previous, if (current != null) current],
                      ),
                  child: OverhangBadge(
                    key: ValueKey(stage.asset),
                    asset: stage.asset,
                    fill: WaddyColors.mintSurface,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: waddyBold.copyWith(
                          fontSize: 14,
                          color: WaddyColors.ink,
                          height: 1.25,
                        ),
                        maxLines: waiting ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!waiting) ...[
                        const SizedBox(height: 1),
                        _arrivalLine(arrival, enRoute),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // The bar's one primary action. Primary fill, white ink: it is
                // the control a user with an order running reaches for, and it
                // must read as a button, not as part of the status text.
                CustomButton(
                  buttonText: 'track'.tr,
                  width: 64,
                  height: 40,
                  radius: 12,
                  fontSize: 14,
                  color: WaddyColors.primary,
                  textColor: Colors.white,
                  onPressed: () => _openOrder(order),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _arrivalLine(_Arrival arrival, bool enRoute) {
    final TextStyle base = waddyRegular.copyWith(
      fontSize: 12,
      color: WaddyColors.inkMid,
      height: 1.25,
    );

    // A passed ETA only means "arriving" once the courier is on the road. On a
    // pending order it would contradict "Order Placed", so say nothing about
    // time and name the store instead.
    if (arrival.due) {
      return Text(
        enRoute ? 'arriving_now'.tr : (order.store?.name ?? 'your_order'.tr),
        style: base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final String? chip = arrival.window ?? arrival.range;
    if (chip == null) {
      return Text(
        order.store?.name ?? 'your_order'.tr,
        style: base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Wrap, not Row: at 1.12x text scale the window chip is ~150px, and the
    // label beside it must drop to its own line rather than overflow.
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          arrival.window != null ? 'arrives'.tr : 'arrives_in'.tr,
          style: base,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: WaddyColors.mintSurface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            chip,
            style: waddyBold.copyWith(
              fontSize: 12,
              color: WaddyColors.primary,
              height: 1.25,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}

/// One segment per stage: earlier stages full, the current one part-filled,
/// later ones empty — the design's three-segment strip, with the extra stage
/// the app actually has.
class _StageStrip extends StatelessWidget {
  final _Stage stage;

  const _StageStrip({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _Stage.segments; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _Segment(fill: _fillFor(i))),
        ],
      ],
    );
  }

  double _fillFor(int i) {
    final int? current = stage.index;
    if (current == null) return 0;
    if (i < current) return 1;
    if (i == current) return stage.within;
    return 0;
  }
}

class _Segment extends StatelessWidget {
  final double fill;

  const _Segment({required this.fill});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fill),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder:
            (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: WaddyColors.divider,
              valueColor: const AlwaysStoppedAnimation(WaddyColors.primary),
            ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Expanded panel
// ═══════════════════════════════════════════

/// What the panel adds: the headline order's summary, the other running
/// orders, and the actions.
class _Details extends StatelessWidget {
  /// The orders that are loaded; [total] is how many are running.
  final List<OrderModel> orders;
  final int total;
  final VoidCallback onViewAll;

  /// Orders listed beneath the headline one before the "+n" line takes over.
  static const int _maxOthers = 2;

  const _Details({
    required this.orders,
    required this.total,
    required this.onViewAll,
  });

  String _summary(OrderModel order) {
    final int items = order.detailsCount ?? 0;
    final List<String> bits = [
      order.store?.name ?? 'your_order'.tr,
      if (items > 0) '$items ${items == 1 ? 'item'.tr : 'items'.tr}',
      if ((order.orderAmount ?? 0) > 0)
        PriceConverter.convertPrice(order.orderAmount),
    ];
    return bits.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final OrderModel head = orders.first;
    final List<OrderModel> others = orders.skip(1).take(_maxOthers).toList();
    final int hidden = total - 1 - others.length;
    final String? phone = head.deliveryMan?.phone;
    final bool canCall =
        phone != null &&
        phone.isNotEmpty &&
        (head.orderStatus == AppConstants.handover ||
            head.orderStatus == AppConstants.pickedUp);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: WaddyColors.divider),
          const SizedBox(height: 12),
          Text(
            _summary(head),
            style: waddyMedium.copyWith(
              fontSize: 13.5,
              color: WaddyColors.ink,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          for (final OrderModel o in others) _OtherOrder(order: o),
          // Orders running that this panel has no row for — whether the list
          // was capped at _maxOthers or the server only sent one. Opens the
          // list that does have them.
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '+$hidden ${'active_orders'.tr}',
                      style: waddyBold.copyWith(
                        fontSize: 13,
                        color: WaddyColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  buttonText: 'view_all'.tr,
                  height: 44,
                  radius: 12,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onViewAll();
                  },
                ),
              ),
              if (canCall) ...[
                const SizedBox(width: 10),
                _CallButton(phone: phone),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A secondary running order: store and stage, tap for its details.
class _OtherOrder extends StatelessWidget {
  final OrderModel order;

  const _OtherOrder({required this.order});

  @override
  Widget build(BuildContext context) {
    final _Stage stage = _Stage.of(order.orderStatus ?? '');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _openOrder(order),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${order.store?.name ?? 'your_order'.tr} · ${stage.labelKey.tr}',
                  style: waddyRegular.copyWith(
                    fontSize: 13,
                    color: WaddyColors.inkMid,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: WaddyColors.inkMid,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calls the courier. Square 44, like the buttons beside it.
class _CallButton extends StatelessWidget {
  final String phone;

  const _CallButton({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'call'.tr,
      child: Material(
        color: WaddyColors.mintSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            launchUrlString('tel:$phone');
          },
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.call_rounded,
              size: 20,
              color: WaddyColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A spacer for scrolling pages: the room [OrderTrackingBar] currently takes,
/// zero when it is not showing. Place it after the page's own nav/cart-bar
/// reserve.
class OrderTrackingReserve extends StatelessWidget {
  const OrderTrackingReserve({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: OrderTrackingBar.reserve,
      builder: (context, h, _) => SizedBox(height: h),
    );
  }
}
