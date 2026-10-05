import 'dart:async';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waddy_app/features/scratch_card/widgets/scratch_card_badge.dart';
import 'package:waddy_app/features/chat/domain/models/conversation_model.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_stamp.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/features/order/widgets/order_details/order_details_sections.dart';
import 'package:waddy_app/features/order/widgets/order_details/order_live_map.dart';
import 'package:waddy_app/features/review/screens/rate_review_screen.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/eta_calculator.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/rider_camera.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/common/widgets/custom_dialog.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/checkout/widgets/offline_success_dialog.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel? orderModel;
  final int? orderId;
  final bool fromNotification;
  final bool fromOfflinePayment;
  final String? contactNumber;
  const OrderDetailsScreen({
    super.key,
    required this.orderModel,
    required this.orderId,
    this.fromNotification = false,
    this.fromOfflinePayment = false,
    this.contactNumber,
  });

  @override
  OrderDetailsScreenState createState() => OrderDetailsScreenState();
}

class OrderDetailsScreenState extends State<OrderDetailsScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Reloads the whole order every 30 s while it is live (LT-06).
  Timer? _timer;

  /// Moves the rider every 10 s, only while the near-state map is showing.
  Timer? _locationTimer;
  bool _locationInFlight = false;

  /// The rider is close enough for the map (LT-01). Has hysteresis: on below
  /// [_nearOnMeters], off again only above [_nearOffMeters].
  bool _near = false;
  double? _riderMeters;
  bool _foreground = true;

  static const double _nearOnMeters = 1500;
  static const double _nearOffMeters = 2000;

  /// Under this the title says the rider is arriving.
  static const double _arrivingMeters = 150;

  final ScrollController scrollController = ScrollController();

  /// The arrival time the header has committed to — see [_committedArrival].
  DateTime? _etaAnchor;
  bool _etaSlipped = false;

  bool _refreshing = false;
  bool _reordering = false;

  // ── Entrance animation ──────────────────────────────────────────────────
  late final AnimationController _entranceController;
  late final Animation<double> _screenFade;
  late final Animation<Offset> _screenSlide;

  void _loadData(BuildContext context, bool reload) async {
    await Get.find<OrderController>()
        .trackOrder(
          widget.orderId.toString(),
          reload ? null : widget.orderModel,
          false,
          contactNumber: widget.contactNumber,
        )
        .then((value) {
          if (widget.fromOfflinePayment) {
            Future.delayed(
              const Duration(seconds: 2),
              () => showAnimatedDialog(
                Get.context!,
                OfflineSuccessDialog(orderId: widget.orderId),
              ),
            );
          }
        });
    Get.find<OrderController>().timerTrackOrder(
      widget.orderId.toString(),
      contactNumber: widget.contactNumber,
    );
    Get.find<OrderController>().getOrderDetails(widget.orderId.toString());

    _startPolling();
  }

  /// The header's refresh button: one immediate poll instead of waiting for
  /// the next 30-second tick.
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final orderController = Get.find<OrderController>();
    await orderController.timerTrackOrder(
      widget.orderId.toString(),
      contactNumber: widget.contactNumber,
    );
    if (mounted) setState(() => _refreshing = false);
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    final status = OrderStatus.fromString(
      Get.find<OrderController>().trackModel?.orderStatus,
    );
    if (status != null && status.isTerminal) return;

    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final orderController = Get.find<OrderController>();
      await orderController.timerTrackOrder(
        widget.orderId.toString(),
        contactNumber: widget.contactNumber,
      );

      final order = orderController.trackModel;
      if (order != null && mounted) {
        final orderStatus = OrderStatus.fromString(order.orderStatus);
        if (orderStatus != null && orderStatus.isTerminal) {
          _timer?.cancel();
        }
        // A rider whose fix went stale without moving changes nothing the
        // controller compares; re-run the distance gate anyway.
        setState(() {});
      }
    });
  }

  /// Starts or stops the 10 s rider poll to match [_near]. The rider app
  /// reports every 10 s, so polling faster would read the same fix twice.
  void _syncLocationPolling() {
    final bool want = _near && _foreground;
    if (want == (_locationTimer != null)) return;
    _locationTimer?.cancel();
    _locationTimer = null;
    if (!want) return;
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_locationInFlight) return;
      _locationInFlight = true;
      final orderController = Get.find<OrderController>();
      final bool sameStatus = await orderController.pollRiderLocation(
        widget.orderId.toString(),
        contactNumber: widget.contactNumber,
      );
      if (!sameStatus) {
        await orderController.timerTrackOrder(
          widget.orderId.toString(),
          contactNumber: widget.contactNumber,
        );
      }
      _locationInFlight = false;
    });
  }

  /// The rider's position, if it is worth drawing.
  LatLng? _liveRider(OrderModel order) {
    final DeliveryMan? rider = order.deliveryMan;
    if (rider == null || rider.locationStale) return null;
    return _point(rider.lat, rider.lng);
  }

  /// The distance gate (LT-01). Runs on every build, like the ETA anchor.
  void _updateGate(OrderModel order, OrderStage stage) {
    final LatLng? rider = _liveRider(order);
    final LatLng? home = _homePoint(order);
    final bool wasNear = _near;
    if (stage != OrderStage.onWay || rider == null || home == null) {
      _near = false;
      _riderMeters = null;
    } else {
      final double d = RiderCamera.meters(rider, home);
      _riderMeters = d;
      _near = _near ? d <= _nearOffMeters : d < _nearOnMeters;
    }
    if (wasNear != _near) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncLocationPolling();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData(context, false);

    // Entrance: single fade+slide, 550ms
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _screenFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _screenSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutQuart),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _startPolling();
      _syncLocationPolling();
    } else if (state == AppLifecycleState.paused) {
      _foreground = false;
      _timer?.cancel();
      _syncLocationPolling();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationTimer?.cancel();
    _entranceController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ─── Arrival estimate ────────────────────────────────────────────────────
  // One committed arrival time instead of a different source per stage. It
  // may move earlier freely; it moves later only on a real slip, and the chip
  // then says so rather than silently growing.

  static const Duration _slipThreshold = Duration(minutes: 5);

  /// Straight-line legs beyond this are bad coordinates, not a trip — the
  /// same gate `StoreDeliveryFee` applies before quoting a fee.
  static const double _maxPlausibleKm = 60;

  /// A rider further than this from home with the food on board is a bad fix
  /// (or a test rider), not a ride: quote the promised time instead of
  /// flagging the order late (LT-08).
  static const double _maxRideKm = 15;

  LatLng? _point(String? lat, String? lng) {
    final double? la = double.tryParse(lat ?? '');
    final double? ln = double.tryParse(lng ?? '');
    if (la == null || ln == null || la == 0 || ln == 0) return null;
    return LatLng(la, ln);
  }

  Duration? _leg(LatLng from, LatLng to, {double maxKm = _maxPlausibleKm}) {
    final double km = ETACalculator.calculateDistanceKm(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    if (km > maxKm) return null;
    return Duration(minutes: ETACalculator.calculate(km).maxMinutes);
  }

  /// What the order promised: the server's estimate, else the store's quoted
  /// window counted from when the order was placed.
  DateTime? _promisedArrival(OrderModel order) {
    final DateTime? server = DateTime.tryParse(order.estimatedDeliveryAt ?? '');
    if (server != null) return server.toLocal();
    final DateTime? placed = DateTime.tryParse(order.createdAt ?? '');
    final int? window = _storeWindowMax(order);
    if (placed == null || window == null) return null;
    return placed.toLocal().add(Duration(minutes: window));
  }

  /// Upper bound of the store's "25-35 min" style delivery time.
  int? _storeWindowMax(OrderModel order) {
    final String raw = (order.store?.deliveryTime ?? '').trim();
    if (raw.isEmpty) return null;
    final String upper = raw.contains('-') ? raw.split('-').last : raw;
    return int.tryParse(upper.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  DateTime? _estimateArrival(OrderModel order, OrderStage stage) {
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
    // Nothing is promised until the store accepts.
    if (status == OrderStatus.pending) return null;
    final DateTime now = DateTime.now();
    final LatLng? rider = _liveRider(order);
    final LatLng? store = _point(order.store?.latitude, order.store?.longitude);
    final LatLng? home = _point(
      order.deliveryAddress?.latitude,
      order.deliveryAddress?.longitude,
    );
    if (stage == OrderStage.onWay && rider != null && home != null) {
      final Duration? toYou = _leg(rider, home, maxKm: _maxRideKm);
      if (toYou != null) return now.add(toYou);
    }
    // Food is ready and a rider is heading for it: count both legs.
    if (status == OrderStatus.handover &&
        rider != null &&
        store != null &&
        home != null) {
      final Duration? toStore = _leg(rider, store);
      final Duration? toYou = _leg(store, home);
      if (toStore != null && toYou != null) return now.add(toStore + toYou);
    }
    return _promisedArrival(order);
  }

  DateTime? _committedArrival(OrderModel order, OrderStage stage) {
    final DateTime? estimate =
        stage.isLive ? _estimateArrival(order, stage) : null;
    if (estimate == null) {
      _etaAnchor = null;
      _etaSlipped = false;
      return null;
    }
    final DateTime? anchor = _etaAnchor;
    if (anchor == null || estimate.isBefore(anchor)) {
      _etaAnchor = estimate;
    } else if (estimate.difference(anchor) > _slipThreshold) {
      _etaAnchor = estimate;
      _etaSlipped = true;
    }
    return _etaAnchor;
  }

  OrderEta _eta(OrderModel order, OrderStage stage) {
    final DateTime? arrival = _committedArrival(order, stage);
    // Close in, the map is the truth: minutes straight from the distance, no
    // anchor and no "running late" (LT-08).
    final double? meters = _riderMeters;
    if (_near && meters != null) {
      if (meters < _arrivingMeters) {
        return OrderEta(label: 'od_arriving_soon'.tr);
      }
      final int minutes = math.max(
        1,
        ETACalculator.calculate(meters / 1000).maxMinutes,
      );
      return OrderEta(
        label: 'od_arriving_in'.trParams({'min': '$minutes'}),
        minutes: minutes,
      );
    }
    if (arrival == null) {
      return OrderEta(
        label:
            OrderStatus.fromString(order.orderStatus) == OrderStatus.pending
                ? 'od_eta_after_confirm'.tr
                : 'od_estimating_arrival'.tr,
      );
    }
    final int minutes =
        (arrival.difference(DateTime.now()).inSeconds / 60).ceil();
    if (minutes <= 0) {
      return OrderEta(
        label:
            stage == OrderStage.onWay
                ? 'od_arriving_soon'.tr
                : 'od_eta_late'.tr,
      );
    }
    final DateTime? promised = _promisedArrival(order);
    final String? note =
        _etaSlipped
            ? 'od_eta_delayed'.tr
            : promised != null && !arrival.isAfter(promised.add(_slipThreshold))
            ? 'od_on_time'.tr
            : null;
    return OrderEta(
      label: 'od_arriving_in'.trParams({'min': '$minutes'}),
      note: note,
      minutes: minutes,
      delayed: _etaSlipped,
    );
  }

  void _handleBack() {
    if (widget.fromNotification || widget.fromOfflinePayment) {
      Get.offAllNamed(RouteHelper.getInitialRoute());
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) async {
        if (widget.fromNotification || widget.fromOfflinePayment) {
          Get.offAllNamed(RouteHelper.getInitialRoute());
        } else {
          return;
        }
      },
      child: Scaffold(
        endDrawer: const MenuDrawer(),
        endDrawerEnableOpenDragGesture: false,
        backgroundColor: WaddyColors.surfaceRaised,
        body: GetBuilder<OrderController>(
          builder: (orderController) {
            final OrderModel? order = orderController.trackModel;
            if (orderController.orderDetails == null || order == null) {
              return const _OrderDetailsSkeleton();
            }

            final bool parcel = order.orderType == 'parcel';
            final bool prescriptionOrder = order.prescriptionOrder ?? false;
            final double deliveryCharge = order.deliveryCharge ?? 0;
            final double couponDiscount = order.couponDiscountAmount ?? 0;
            final double discount =
                (order.storeDiscountAmount ?? 0) +
                (order.flashAdminDiscountAmount ?? 0) +
                (order.flashStoreDiscountAmount ?? 0);
            final double tax = order.totalTaxAmount ?? 0;
            final double dmTips = order.dmTips ?? 0;
            final bool taxIncluded = order.taxStatus ?? false;
            final double additionalCharge = order.additionalCharge ?? 0;
            final double extraPackagingCharge = order.extraPackagingAmount ?? 0;
            final double referrerBonusAmount = order.referrerBonusAmount ?? 0;
            double itemsPrice = 0;
            double addOns = 0;
            if (prescriptionOrder) {
              final double orderAmount = order.orderAmount ?? 0;
              itemsPrice =
                  (orderAmount + discount) -
                  ((taxIncluded ? 0 : tax) + deliveryCharge) -
                  dmTips -
                  additionalCharge;
            } else {
              for (OrderDetailsModel orderDetails
                  in orderController.orderDetails!) {
                for (AddOn addOn in orderDetails.addOns ?? []) {
                  addOns += (addOn.price ?? 0) * (addOn.quantity ?? 0);
                }
                itemsPrice +=
                    (orderDetails.price ?? 0) * (orderDetails.quantity ?? 0);
              }
            }
            final bill = OrderBill(
              itemsPrice: itemsPrice,
              addOns: addOns,
              discount: discount,
              couponDiscount: couponDiscount,
              referrerBonus: referrerBonusAmount,
              tax: tax,
              taxIncluded: taxIncluded,
              deliveryCharge: deliveryCharge,
              dmTips: dmTips,
              additionalCharge: additionalCharge,
              extraPackaging: extraPackagingCharge,
              total:
                  itemsPrice +
                  addOns -
                  discount +
                  (taxIncluded ? 0 : tax) +
                  deliveryCharge -
                  couponDiscount +
                  dmTips +
                  additionalCharge +
                  extraPackagingCharge -
                  referrerBonusAmount,
            );

            bool showChatPermission;
            if (order.store != null) {
              if (order.store!.storeBusinessModel == 'commission') {
                showChatPermission = true;
              } else if (order.store!.storeSubscription != null &&
                  order.store!.storeBusinessModel == 'subscription') {
                showChatPermission = order.store!.storeSubscription!.chat == 1;
              } else {
                showChatPermission = false;
              }
            } else {
              showChatPermission = AuthHelper.isLoggedIn() && !parcel;
            }

            final OrderStage stage = orderStageOf(order);
            _updateGate(order, stage);
            final List<Widget> cards = _cards(
              context,
              order,
              orderController,
              stage,
              bill,
              showChatPermission,
            );

            return FadeTransition(
              opacity: _screenFade,
              child: SlideTransition(
                position: _screenSlide,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child:
                      _near
                          ? KeyedSubtree(
                            key: const ValueKey('near'),
                            child: _buildNear(context, order, stage, cards),
                          )
                          : Column(
                            key: const ValueKey('far'),
                            children: [
                              OrderDetailsHeader(
                                storeName:
                                    order.store?.name ?? 'order_details'.tr,
                                stage: stage,
                                tone: _headerTone(order, stage),
                                statusTitle: _statusTitle(order, stage),
                                endedSubtitle: _endedSubtitle(order, stage),
                                eta: _eta(order, stage),
                                refreshing: _refreshing,
                                onBack: _handleBack,
                                onRefresh: _refresh,
                              ),
                              Expanded(
                                child: Stack(
                                  children: [
                                    // Pulling past the top would otherwise open a grey
                                    // gap between the pinned header and the band.
                                    if (_stageAnimation(order) != null)
                                      _OverscrollFill(
                                        controller: scrollController,
                                        color:
                                            _headerTone(order, stage).colors.$1,
                                      ),
                                    SingleChildScrollView(
                                      controller: scrollController,
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.only(
                                        bottom:
                                            MediaQuery.paddingOf(
                                              context,
                                            ).bottom,
                                      ),
                                      child: _buildBody(order, stage, cards),
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
    );
  }

  /// Follows the order status itself — the same thing the stage animation
  /// follows — so title and animation always move together. Stage alone
  /// can't: it waits for a rider, and a store can hand over before one exists.
  String _statusTitle(OrderModel order, OrderStage stage) {
    switch (stage) {
      case OrderStage.preparing:
      case OrderStage.collecting:
      case OrderStage.onWay:
        switch (OrderStatus.fromString(order.orderStatus)) {
          case OrderStatus.pending:
            return 'od_title_waiting'.tr;
          case OrderStatus.accepted:
          case OrderStatus.confirmed:
            return 'od_title_confirmed'.tr;
          case OrderStatus.handover:
            return order.deliveryMan != null
                ? 'od_title_collecting'.tr
                : 'od_title_ready'.tr;
          case OrderStatus.pickedUp:
            return 'od_title_on_the_way'.tr;
          default:
            return 'od_title_preparing'.tr;
        }
      case OrderStage.delivered:
        return 'od_head_delivered'.tr;
      case OrderStage.closed:
        switch (OrderStatus.fromString(order.orderStatus)) {
          case OrderStatus.failed:
            return 'od_head_failed'.tr;
          case OrderStatus.refundRequested:
            return 'od_head_refund_requested'.tr;
          case OrderStatus.refunded:
            return 'od_head_refunded'.tr;
          default:
            return 'od_head_cancelled'.tr;
        }
    }
  }

  LatLng? _homePoint(OrderModel order) =>
      _point(order.deliveryAddress?.latitude, order.deliveryAddress?.longitude);

  /// Same status → Lottie mapping as the home screen's current-order card.
  String? _stageAnimation(OrderModel order) {
    switch (OrderStatus.fromString(order.orderStatus)) {
      case OrderStatus.pending:
        return 'assets/animation/order_placed.json';
      case OrderStatus.accepted:
      case OrderStatus.confirmed:
        return 'assets/animation/order_confirmed.json';
      case OrderStatus.processing:
        return 'assets/animation/preparing_order.json';
      case OrderStatus.handover:
      case OrderStatus.pickedUp:
        return 'assets/animation/delivery_order.json';
      case OrderStatus.delivered:
      case OrderStatus.refundRequestCanceled:
        return 'assets/animation/completed_order.json';
      default:
        return null;
    }
  }

  OrderHeaderTone _headerTone(OrderModel order, OrderStage stage) {
    if (stage != OrderStage.closed) return OrderHeaderTone.mint;
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
    return status == OrderStatus.refundRequested ||
            status == OrderStatus.refunded
        ? OrderHeaderTone.amber
        : OrderHeaderTone.red;
  }

  /// "Cancelled at 9:58 PM" and friends, from the status's own timestamp.
  /// Null (no pill) when the backend never stamped it.
  String? _endedSubtitle(OrderModel order, OrderStage stage) {
    if (stage.isLive) return null;
    final (String key, String? raw) = switch (stage) {
      OrderStage.delivered => ('od_head_delivered_at', order.delivered),
      _ => switch (OrderStatus.fromString(order.orderStatus)) {
        OrderStatus.failed => ('od_head_failed_at', order.failed),
        OrderStatus.refundRequested => (
          'od_head_refund_requested_at',
          order.refundRequested,
        ),
        OrderStatus.refunded => ('od_head_refunded_at', order.refunded),
        _ => ('od_head_cancelled_at', order.canceled),
      },
    };
    final String? time = _formatTime(order, raw);
    return time == null ? null : key.trParams({'time': time});
  }

  // ─── Body ──────────────────────────────────────────────────────────────
  /// The card stack, the same in the scrolling page and in the near-state
  /// sheet.
  List<Widget> _cards(
    BuildContext context,
    OrderModel order,
    OrderController orderController,
    OrderStage stage,
    OrderBill bill,
    bool showChatPermission,
  ) {
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
    final List<OrderDetailsModel> items = orderController.orderDetails ?? [];
    final DeliveryMan? rider = order.deliveryMan;
    final bool live = stage.isLive;

    final bool showOtp =
        (status == OrderStatus.handover || status == OrderStatus.pickedUp) &&
        (order.otp ?? '').isNotEmpty;

    final String? tipLine =
        bill.dmTips > 0
            ? (stage == OrderStage.delivered ? 'od_tipped' : 'od_tip_thanks')
                .trParams({'amount': PriceConverter.convertPrice(bill.dmTips)})
            : null;

    final List<OrderDetailsModel> reviewable = _reviewableItems(items);
    final void Function(int stars)? onRate =
        stage == OrderStage.delivered &&
                AuthHelper.isLoggedIn() &&
                (reviewable.isNotEmpty || rider != null)
            ? (stars) => Get.toNamed(
              RouteHelper.getReviewRoute(),
              arguments: RateReviewScreen(
                orderDetailsList: reviewable,
                deliveryMan: rider,
                orderID: order.id,
                initialRating: stars,
              ),
            )
            : null;

    final bool canReorder =
        AuthHelper.isLoggedIn() &&
        order.id != null &&
        order.orderType != 'parcel' &&
        !(order.prescriptionOrder ?? false) &&
        items.isNotEmpty;
    final VoidCallback? onReorder = canReorder ? () => _reorder(order) : null;

    // The printed scratch card, in its own slot in the card list: "coming with
    // this order" while live, "won? use your code" for a week after delivery.
    // Parcels carry no bag.
    final bool cardInBag =
        order.orderType != 'parcel' && ScratchCardBadge.inBags;

    final String orderLabel = 'od_order_number'.trParams({
      'id': '${order.id ?? ''}',
    });

    // Fixed slot order across every stage, so a glance lands in the same
    // place: what needs doing now → who is bringing it → where → what → help.
    final cards = <Widget>[
      if (showOtp) OrderPinCard(otp: order.otp!),
      if (stage == OrderStage.delivered)
        OrderEndingCard(
          headline: 'od_ending_title'.tr,
          subtitle: _deliveredBy(rider),
          tipLine: tipLine,
          onRate: onRate,
          onReorder: onReorder,
          reordering: _reordering,
        ),
      if (stage == OrderStage.delivered &&
          cardInBag &&
          _deliveredWithinDays(order, 7))
        const ScratchCardBar(moment: ScratchTeaserMoment.delivered),
      if (stage == OrderStage.closed) _outcomeCard(order, status, onReorder),
      if (stage == OrderStage.preparing)
        OrderAssigningCard(
          text:
              status == OrderStatus.pending
                  ? 'od_assigning_after_confirm'.tr
                  : 'od_assigning_partner'.tr,
          tipLine: tipLine,
        ),
      if (rider != null && live && stage != OrderStage.preparing)
        OrderRiderCard(
          rider: rider,
          onChat:
              showChatPermission ? () => _openRiderChat(order, rider) : null,
          onCall:
              (rider.phone ?? '').isNotEmpty ? () => _dial(rider.phone!) : null,
          tipLine: tipLine,
        ),
      if (live && cardInBag)
        const ScratchCardBar(moment: ScratchTeaserMoment.onTheWay),
      OrderDeliveryDetailsCard(
        contactLine: _contactLine(order),
        addressTitle: _addressTitle(order, stage),
        addressLine: _addressLine(order),
        instructions: _instructions(order),
      ),
      OrderStoreCard(
        store: order.store,
        onCallStore:
            live && (order.store?.phone ?? '').isNotEmpty
                ? () => _dial(order.store!.phone!)
                : null,
        orderLabel: orderLabel,
        itemsSummary: _itemsSummary(items),
        paymentIcon:
            _isCash(order)
                ? Icons.payments_outlined
                : Icons.credit_card_outlined,
        paymentLabel: _paymentLabel(order, stage),
        amount: PriceConverter.convertPrice(order.orderAmount ?? bill.total),
        cashNote:
            live && order.paymentMethod == 'cash_on_delivery'
                ? 'od_cash_ready'.trParams({
                  'amount': PriceConverter.convertPrice(
                    order.orderAmount ?? bill.total,
                  ),
                })
                : null,
        onOpenBill:
            () => OrderBillSheet.show(
              context,
              orderLabel: orderLabel,
              items: items,
              bill: bill,
              paymentMethod: order.paymentMethod,
            ),
      ),
      OrderHelpCard(
        onHelp: () => Get.toNamed(RouteHelper.getSupportRoute()),
        onCancel:
            status == OrderStatus.pending
                ? () => OrderCancelSheet.show(
                  context,
                  onConfirm: (reason) => _cancelOrder(order, reason),
                )
                : null,
      ),
    ];

    return cards;
  }

  /// Far from home (or no live fix): the scrolling page, with the stage
  /// animation on the band's continuation scrolling away with the body.
  Widget _buildBody(OrderModel order, OrderStage stage, List<Widget> cards) {
    final String? animation = _stageAnimation(order);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (animation != null)
          OrderStageBand(
            asset: animation,
            tone: _headerTone(order, stage),
            loop: stage.isLive,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeMedium,
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeExtraOverLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced(cards),
          ),
        ),
      ],
    );
  }

  List<Widget> _spaced(List<Widget> cards) => [
    for (int i = 0; i < cards.length; i++) ...[
      if (i > 0) const SizedBox(height: Dimensions.paddingSizeMedium),
      cards[i],
    ],
  ];

  /// The rider is close (LT-02): the map fills the screen behind the status
  /// bar and the cards ride on a sheet over it.
  Widget _buildNear(
    BuildContext context,
    OrderModel order,
    OrderStage stage,
    List<Widget> cards,
  ) {
    const double sheet = 0.42;
    final double screen = MediaQuery.sizeOf(context).height;
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double meters = _riderMeters ?? _nearOnMeters;
    final bool arriving = meters < _arrivingMeters;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Stack(
        children: [
          Positioned.fill(
            child: OrderLiveMap(
              rider: _liveRider(order)!,
              home: _homePoint(order)!,
              insets: EdgeInsets.only(
                top: safe.top + Dimensions.minTapTarget,
                bottom: screen * sheet - Dimensions.radiusExtraLarge,
              ),
            ),
          ),
          PositionedDirectional(
            top: safe.top + Dimensions.paddingSizeSmall,
            start: Dimensions.paddingSizeDefault,
            child: OrderMapButton(
              icon: Icons.arrow_back_rounded,
              semanticLabel:
                  MaterialLocalizations.of(context).backButtonTooltip,
              onTap: _handleBack,
            ),
          ),
          PositionedDirectional(
            top: safe.top + Dimensions.paddingSizeSmall,
            end: Dimensions.paddingSizeDefault,
            child: OrderMapButton(
              label: 'help'.tr,
              onTap: () => Get.toNamed(RouteHelper.getSupportRoute()),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: sheet,
            minChildSize: sheet,
            maxChildSize: 0.92,
            snap: true,
            builder:
                (context, controller) => OrderNearSheet(
                  controller: controller,
                  bottomInset: safe.bottom,
                  summary: OrderNearSummary(
                    eta: _eta(order, stage),
                    title:
                        arriving
                            ? 'od_rider_arriving'.tr
                            : _statusTitle(order, stage),
                    // Placed and prepared are done; the last leg fills as
                    // the rider closes in from the edge of the map's range.
                    rideProgress: (1 - meters / _nearOnMeters).clamp(0.08, 1),
                  ),
                  children: _spaced(cards),
                ),
          ),
        ],
      ),
    );
  }

  /// Delivered no more than [days] ago. The stamp is a naive server-time
  /// string; day precision is all this needs, so it is read as-is.
  bool _deliveredWithinDays(OrderModel order, int days) {
    final DateTime? at = DateTime.tryParse(order.delivered ?? '');
    return at != null && DateTime.now().difference(at).inDays < days;
  }

  /// Cancelled, failed and refund states. The header already says what
  /// happened and when; this card says why (when someone wrote a reason) and
  /// what the customer can do next.
  Widget _outcomeCard(
    OrderModel order,
    OrderStatus? status,
    VoidCallback? onReorder,
  ) {
    final String? refundReason = _nonEmpty(order.refund?.customerReason);
    switch (status) {
      case OrderStatus.refundRequested:
        return OrderOutcomeCard(
          positive: true,
          icon: Icons.schedule_rounded,
          title: 'od_title_refund_requested'.tr,
          subtitle: 'od_refund_requested_subtitle'.tr,
          reason: refundReason,
        );
      case OrderStatus.refunded:
        return OrderOutcomeCard(
          positive: true,
          icon: Icons.replay_rounded,
          title: 'od_title_refunded'.tr,
          subtitle: 'od_refunded_subtitle'.tr,
          reason: refundReason,
        );
      case OrderStatus.failed:
        return OrderOutcomeCard(
          positive: false,
          icon: Icons.warning_amber_rounded,
          title: 'od_title_failed'.tr,
          subtitle: 'od_failed_subtitle'.tr,
          reason: _nonEmpty(order.cancellationReason),
          onReorder: onReorder,
          reordering: _reordering,
        );
      default:
        return OrderOutcomeCard(
          positive: false,
          icon: Icons.close_rounded,
          title: 'od_title_cancelled'.tr,
          subtitle:
              onReorder != null
                  ? 'od_cancelled_reorder_hint'.tr
                  : 'od_cancelled_subtitle'.tr,
          reason: _nonEmpty(order.cancellationReason),
          onReorder: onReorder,
          reordering: _reordering,
        );
    }
  }

  String _deliveredBy(DeliveryMan? rider) {
    final String name = '${rider?.fName ?? ''} ${rider?.lName ?? ''}'.trim();
    return name.isNotEmpty
        ? 'od_delivered_by'.trParams({'name': name})
        : 'od_delivered_enjoy'.tr;
  }

  /// "Delivering to Home" only for the two types that are real places to a
  /// person; anything else ("others", custom labels) is just the address.
  String _addressTitle(OrderModel order, OrderStage stage) {
    final String type =
        (order.deliveryAddress?.addressType ?? '').trim().toLowerCase();
    if (type == 'home' || type == 'office') {
      return (stage == OrderStage.delivered
              ? 'od_delivered_to_place'
              : 'od_delivering_to_place')
          .trParams({'place': type.tr});
    }
    return 'od_delivery_address'.tr;
  }

  Future<void> _reorder(OrderModel order) async {
    if (_reordering || order.id == null) return;
    setState(() => _reordering = true);
    final result = await Get.find<OrderController>().reorder(order.id!);
    if (!mounted) return;
    setState(() => _reordering = false);
    if (result != null) Get.toNamed(RouteHelper.getCartRoute());
  }

  /// Free text from the backend, or null when there is nothing a person
  /// wrote — some clients store the literal string "null".
  String? _nonEmpty(String? value) {
    final String trimmed = (value ?? '').trim();
    const Set<String> blanks = {'', 'null', 'undefined', 'none', 'n/a'};
    return blanks.contains(trimmed.toLowerCase()) ? null : trimmed;
  }

  bool _isCash(OrderModel order) =>
      order.paymentMethod == 'cash_on_delivery' ||
      order.paymentMethod == 'partial_payment';

  String _paymentLabel(OrderModel order, OrderStage stage) {
    switch (order.paymentMethod) {
      case 'cash_on_delivery':
        return stage == OrderStage.delivered
            ? 'od_pay_cash_paid'.tr
            : 'od_pay_cash'.tr;
      case 'wallet':
        return 'od_pay_wallet'.tr;
      case 'partial_payment':
        return 'od_pay_partial'.tr;
      case 'offline_payment':
        return 'od_pay_offline'.tr;
      default:
        return 'od_pay_online'.tr;
    }
  }

  String? _formatTime(OrderModel order, String? raw) {
    final DateTime? local = order.stampToLocal(raw);
    return local == null ? null : DateConverter.dateToTimeOnly(local);
  }

  String? _contactLine(OrderModel order) {
    final String name = (order.deliveryAddress?.contactPersonName ?? '').trim();
    final String phone =
        (order.deliveryAddress?.contactPersonNumber ?? '').trim();
    if (name.isEmpty && phone.isEmpty) return null;
    if (name.isEmpty) return phone;
    if (phone.isEmpty) return name;
    return '$name${listSeparator()}$phone';
  }

  /// Street details, floor and apartment first — they are what the rider
  /// needs at the door — then the geocoded area line.
  String? _addressLine(OrderModel order) {
    final a = order.deliveryAddress;
    if (a == null) return null;
    final parts = <String>[
      if ((a.streetNumber ?? '').trim().isNotEmpty) a.streetNumber!.trim(),
      if ((a.floor ?? '').trim().isNotEmpty)
        'od_floor'.trParams({'value': a.floor!.trim()}),
      if ((a.house ?? '').trim().isNotEmpty)
        'od_apartment'.trParams({'value': a.house!.trim()}),
      if ((a.address ?? '').trim().isNotEmpty) a.address!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(listSeparator());
  }

  String? _instructions(OrderModel order) {
    // Checkout stores the picked chips as a comma-joined list of keys
    // ("avoid_calling,leave_at_the_door"); translate each one.
    final String fromOrder = (order.deliveryInstruction ?? '').trim();
    if (fromOrder.isNotEmpty) {
      return fromOrder
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .map((part) => part.tr)
          .join(listSeparator());
    }
    final String fromAddress =
        (order.deliveryAddress?.deliveryInstructions ?? '').trim();
    return fromAddress.isNotEmpty ? fromAddress : null;
  }

  String _itemsSummary(List<OrderDetailsModel> items) {
    final named =
        items.where((i) => (i.itemDetails?.name ?? '').isNotEmpty).toList();
    if (named.isEmpty) return 'od_view_order_summary'.tr;
    final shown = named
        .take(2)
        .map((i) => '${i.quantity ?? 1} × ${i.itemDetails!.name}')
        .join(listSeparator());
    final int more = named.length - 2;
    return more > 0
        ? '$shown ${'od_more_items'.trParams({'count': '$more'})}'
        : shown;
  }

  /// One entry per distinct item — the review screen rates items, not lines.
  List<OrderDetailsModel> _reviewableItems(List<OrderDetailsModel> items) {
    final List<OrderDetailsModel> out = [];
    final Set<int> seen = {};
    for (final detail in items) {
      final int? id = detail.itemDetails?.id;
      if (id != null && seen.add(id)) out.add(detail);
    }
    return out;
  }

  void _dial(String phone) {
    launchUrlString('tel:$phone', mode: LaunchMode.externalApplication);
  }

  Future<void> _openRiderChat(OrderModel order, DeliveryMan rider) async {
    _timer?.cancel();
    await Get.toNamed(
      RouteHelper.getChatRoute(
        notificationBody: NotificationBodyModel(
          deliverymanId: rider.id,
          orderId: order.id,
        ),
        user: User(
          id: rider.id,
          fName: rider.fName,
          lName: rider.lName,
          imageFullUrl: rider.imageFullUrl,
        ),
      ),
    );
    _startPolling();
  }

  Future<void> _cancelOrder(OrderModel order, String reason) async {
    final bool success = await Get.find<OrderController>().cancelOrder(
      order.id,
      reason,
      guestId: AuthHelper.isLoggedIn() ? null : AuthHelper.getGuestId(),
    );
    if (success && mounted) await _refresh();
  }
}

/// Paints the band colour into the space a top overscroll opens up.
class _OverscrollFill extends StatelessWidget {
  final ScrollController controller;
  final Color color;
  const _OverscrollFill({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final double pull =
            controller.hasClients && controller.offset < 0
                ? -controller.offset
                : 0;
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: pull + 1,
          child: ColoredBox(color: color),
        );
      },
    );
  }
}

// ─── Order Details Skeleton ───────────────────────────────────────────────────
// Mirrors the live layout — mint header, then stacked cards — so nothing jumps
// when data lands.
class _OrderDetailsSkeleton extends StatefulWidget {
  const _OrderDetailsSkeleton();

  @override
  State<_OrderDetailsSkeleton> createState() => _OrderDetailsSkeletonState();
}

class _OrderDetailsSkeletonState extends State<_OrderDetailsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _opacity = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _ctrl.stop();
      _ctrl.value = 0.8;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _block({
    double height = 16,
    double? width,
    double radius = Dimensions.radiusSmall,
    Color color = WaddyColors.divider,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _card({required double height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: WaddyColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _block(height: 48, width: 48, radius: 24),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _block(height: 15, width: 140),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                _block(height: 12, width: 200),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color onMint = WaddyColors.primary.withValues(alpha: 0.12);
    return FadeTransition(
      opacity: _opacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: WaddyColors.mint,
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 64,
              bottom: Dimensions.paddingSizeLarge,
            ),
            child: Column(
              children: [
                _block(height: 26, width: 220, color: onMint),
                const SizedBox(height: Dimensions.paddingSizeMedium),
                _block(
                  height: 36,
                  width: 200,
                  radius: Dimensions.radiusDefault,
                  color: onMint,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Column(
              children: [
                _card(height: 88),
                const SizedBox(height: Dimensions.paddingSizeMedium),
                _card(height: 150),
                const SizedBox(height: Dimensions.paddingSizeMedium),
                _card(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
