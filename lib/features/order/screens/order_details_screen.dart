import 'dart:async';
import 'dart:collection';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/features/chat/domain/models/conversation_model.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/features/order/domain/services/order_tracking_stream_service.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/eta_calculator.dart';
import 'package:waddy_app/helper/marker_animator.dart';
import 'package:waddy_app/helper/marker_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_dialog.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/checkout/widgets/offline_success_dialog.dart';
import 'package:waddy_app/features/order/widgets/order_calcuation_widget.dart';
import 'package:waddy_app/features/order/widgets/order_info_widget.dart';
// order_steps_card, order_map_section, delivery_man_card removed from mobile layout
import 'package:waddy_app/features/order/widgets/order_action_buttons.dart';
import 'package:waddy_app/features/order/widgets/zomato/zomato_order_info_card.dart';
import 'package:waddy_app/features/order/widgets/zomato/zomato_delivery_partner_card.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart' hide Marker;

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
  Timer? _timer;
  double? _maxCodOrderAmount;
  bool? _isCashOnDeliveryActive = false;
  final ScrollController scrollController = ScrollController();
  GoogleMapController? _mapController;
  Set<Marker> _markers = HashSet<Marker>();
  Set<Polyline> _polylines = HashSet<Polyline>();

  // SSE real-time tracking
  OrderTrackingStreamService? _streamService;
  StreamSubscription<TrackingStreamData>? _streamSubscription;
  final MarkerAnimator _markerAnimator = MarkerAnimator();
  bool _useSSE = true;
  ETAResult? _currentETA;

  // SSE retry logic
  int _sseRetryCount = 0;
  static const int _maxSseRetries = 3;
  Timer? _sseRetryTimer;

  // ── Entrance animation ──────────────────────────────────────────────────
  late final AnimationController _entranceController;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

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
    final trackedOrder = Get.find<OrderController>().trackModel;
    if (trackedOrder != null) {
      await _setMapMarkers(trackedOrder);
    }
    Get.find<OrderController>().timerTrackOrder(
      widget.orderId.toString(),
      contactNumber: widget.contactNumber,
    );
    Get.find<OrderController>().getOrderDetails(widget.orderId.toString());

    _startTracking();
  }

  void _startTracking() {
    final status = OrderStatus.fromString(
      Get.find<OrderController>().trackModel?.orderStatus,
    );
    if (status != null && status.isTerminal) return;

    if (_useSSE) {
      _startSSETracking();
    } else {
      _startPolling();
    }
  }

  void _startSSETracking() {
    _streamService?.disconnect();
    _streamService = OrderTrackingStreamService();

    _streamSubscription = _streamService!
        .connect(
          orderId: widget.orderId.toString(),
          token: Get.find<AuthController>().getUserToken(),
          contactNumber: widget.contactNumber,
          guestId: null,
        )
        .listen(
          (data) {
            // Reset retry count on successful data
            _sseRetryCount = 0;
            _handleSSEUpdate(data);
          },
          onError: (error) {
            debugPrint(
              'OrderDetails SSE Error: $error - Attempting retry $_sseRetryCount/$_maxSseRetries',
            );
            _handleSSEFailure();
          },
        );
  }

  /// Handle SSE failure with exponential backoff retry
  void _handleSSEFailure() {
    _streamService?.disconnect();
    _streamSubscription?.cancel();

    if (_sseRetryCount < _maxSseRetries) {
      // Exponential backoff: 5s, 15s, 45s
      final delay = Duration(seconds: 5 * (1 << _sseRetryCount));
      _sseRetryCount++;

      // Start polling immediately as fallback while waiting for retry
      _startPolling();

      _sseRetryTimer?.cancel();
      _sseRetryTimer = Timer(delay, () {
        if (mounted) {
          debugPrint('SSE retry attempt $_sseRetryCount/$_maxSseRetries');
          _timer?.cancel(); // Stop polling before SSE retry
          _useSSE = true;
          _startSSETracking();
        }
      });
    } else {
      debugPrint('SSE max retries reached, staying on polling');
      _useSSE = false;
      _startPolling();
    }
  }

  void _handleSSEUpdate(TrackingStreamData data) {
    final orderController = Get.find<OrderController>();

    if (orderController.trackModel != null) {
      orderController.trackModel!.orderStatus = data.status;
      orderController.trackModel!.subStatus = data.subStatus;

      if (data.estimatedDeliveryAt != null) {
        orderController.trackModel!.estimatedDeliveryAt =
            data.estimatedDeliveryAt;
      }

      if (data.deliveryMan != null &&
          orderController.trackModel!.deliveryMan != null) {
        orderController.trackModel!.deliveryMan!.lat =
            data.deliveryMan!.lat.toString();
        orderController.trackModel!.deliveryMan!.lng =
            data.deliveryMan!.lng.toString();
      }

      orderController.update();
    }

    if (data.deliveryMan != null) {
      final newPosition = LatLng(data.deliveryMan!.lat, data.deliveryMan!.lng);
      _markerAnimator.animateTo(
        target: newPosition,
        onUpdate: (position, rotation) {
          _updateDeliveryManMarkerAnimated(position, rotation);
        },
      );
      _updateETA(data.deliveryMan!.lat, data.deliveryMan!.lng);
    }

    final status = OrderStatus.fromString(data.status);
    if (status != null && status.isTerminal) {
      _streamService?.disconnect();
      _timer?.cancel();
      _sseRetryTimer?.cancel();
    }
  }

  void _updateETA(double driverLat, double driverLng) {
    final destination = Get.find<OrderController>().trackModel?.deliveryAddress;
    if (destination?.latitude == null || destination?.longitude == null) return;

    final distance = ETACalculator.calculateDistanceKm(
      driverLat,
      driverLng,
      double.parse(destination!.latitude!),
      double.parse(destination.longitude!),
    );

    if (mounted) {
      setState(() {
        _currentETA = ETACalculator.calculate(distance);
      });
    }
  }

  void _updateDeliveryManMarkerAnimated(
    LatLng position,
    double rotation,
  ) async {
    final order = Get.find<OrderController>().trackModel;
    final String dmImageUrl = order?.deliveryMan?.imageFullUrl ?? '';
    BitmapDescriptor dmIcon = await MarkerHelper.createPinMarker(
      imageUrl: dmImageUrl,
      logicalSize: 24,
      borderColor: Colors.orange,
      borderWidth: 2,
      fallbackAsset: Images.deliveryManMarker,
      fallbackIcon: Icons.delivery_dining,
      fallbackIconColor: Colors.orange,
    );

    if (mounted) {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'delivery_man');
        _markers.add(
          Marker(
            markerId: const MarkerId('delivery_man'),
            position: position,
            infoWindow: InfoWindow(
              title: 'delivery_man'.tr,
              snippet: _currentETA?.displayText ?? '',
            ),
            rotation: rotation,
            icon: dmIcon,
            anchor: const Offset(0.5, 1.0),
          ),
        );
      });
    }

    _updateRoutePolyline(position);
  }

  void _updateRoutePolyline(LatLng driverPosition) {
    final track = Get.find<OrderController>().trackModel;
    if (track == null) return;

    final List<LatLng> routePoints = [];

    if (track.store?.latitude != null && track.store?.longitude != null) {
      routePoints.add(
        LatLng(
          double.parse(track.store!.latitude!),
          double.parse(track.store!.longitude!),
        ),
      );
    }
    routePoints.add(driverPosition);
    if (track.deliveryAddress?.latitude != null &&
        track.deliveryAddress?.longitude != null) {
      routePoints.add(
        LatLng(
          double.parse(track.deliveryAddress!.latitude!),
          double.parse(track.deliveryAddress!.longitude!),
        ),
      );
    }

    if (routePoints.length < 2) return;

    if (mounted) {
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: routePoints,
            color: Theme.of(context).primaryColor,
            width: 3,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );
      });
    }
  }

  void _startPolling() {
    _timer?.cancel();
    final status = OrderStatus.fromString(
      Get.find<OrderController>().trackModel?.orderStatus,
    );
    if (status != null && status.isTerminal) return;

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final orderController = Get.find<OrderController>();
      await orderController.timerTrackOrder(
        widget.orderId.toString(),
        contactNumber: widget.contactNumber,
      );

      final order = orderController.trackModel;
      if (order != null && mounted) {
        _refreshMapMarkers(order);

        if (order.deliveryMan?.lat != null && order.deliveryMan?.lng != null) {
          final dmLat = double.tryParse(order.deliveryMan!.lat!);
          final dmLng = double.tryParse(order.deliveryMan!.lng!);
          if (dmLat != null && dmLng != null) {
            _updateETA(dmLat, dmLng);
          }
        }

        final orderStatus = OrderStatus.fromString(order.orderStatus);
        if (orderStatus != null && orderStatus.isTerminal) {
          _timer?.cancel();
          _sseRetryTimer?.cancel();
        }
      }
    });
  }

  void _refreshMapMarkers(OrderModel order) async {
    if (order.deliveryMan?.lat != null && order.deliveryMan?.lng != null) {
      final dmLat = double.tryParse(order.deliveryMan!.lat!);
      final dmLng = double.tryParse(order.deliveryMan!.lng!);
      if (dmLat != null && dmLng != null) {
        final String dmImageUrl = order.deliveryMan?.imageFullUrl ?? '';
        BitmapDescriptor dmIcon = await MarkerHelper.createPinMarker(
          imageUrl: dmImageUrl,
          logicalSize: 32,
          borderColor: Colors.orange,
          borderWidth: 2.5,
          fallbackAsset: Images.deliveryManMarker,
          fallbackIcon: Icons.delivery_dining,
          fallbackIconColor: Colors.orange,
        );
        if (mounted) {
          setState(() {
            _markers.removeWhere((m) => m.markerId.value == 'delivery_man');
            _markers.add(
              Marker(
                markerId: const MarkerId('delivery_man'),
                position: LatLng(dmLat, dmLng),
                infoWindow: InfoWindow(title: 'delivery_man'.tr),
                icon: dmIcon,
                anchor: const Offset(0.5, 1.0),
              ),
            );
          });
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData(context, false);

    // Entrance choreography: 700ms total, hero leads then content follows
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Hero: fade + slide up, 0→500ms
    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutQuart),
      ),
    );

    // Content cards: fade + slide up, 250ms→700ms (staggered after hero)
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
      ),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutQuart),
      ),
    );

    // Start after first frame so layout is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTracking();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _sseRetryTimer?.cancel();
      _streamService?.disconnect();
      _streamSubscription?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sseRetryTimer?.cancel();
    _mapController?.dispose();
    _streamSubscription?.cancel();
    _streamService?.disconnect();
    _markerAnimator.cancel();
    _entranceController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int? _getLiveEtaMinutes(OrderModel order) {
    if (_currentETA != null && _currentETA!.minMinutes > 0) {
      return _currentETA!.minMinutes;
    }

    if (order.deliveryMan?.lat != null &&
        order.deliveryMan?.lng != null &&
        order.deliveryAddress?.latitude != null &&
        order.deliveryAddress?.longitude != null) {
      final dmLat = double.tryParse(order.deliveryMan!.lat!);
      final dmLng = double.tryParse(order.deliveryMan!.lng!);
      final destLat = double.tryParse(order.deliveryAddress!.latitude!);
      final destLng = double.tryParse(order.deliveryAddress!.longitude!);
      if (dmLat != null &&
          dmLng != null &&
          destLat != null &&
          destLng != null) {
        final distance = ETACalculator.calculateDistanceKm(
          dmLat,
          dmLng,
          destLat,
          destLng,
        );
        final eta = ETACalculator.calculate(distance);
        if (eta.minMinutes > 0) return eta.minMinutes;
      }
    }

    if (order.estimatedDeliveryAt != null &&
        order.estimatedDeliveryAt!.isNotEmpty) {
      final mins = DateConverter.estimatedDeliveryMinutes(
        estimatedDeliveryAt: order.estimatedDeliveryAt,
      );
      if (mins > 0) return mins;
    }

    return null;
  }

  int? _getPrepMinutes(OrderModel order) {
    if (order.processingTime != null && order.processingTime! > 0) {
      return order.processingTime;
    }
    if (order.store?.deliveryTime != null) {
      try {
        String dt = order.store!.deliveryTime!;
        if (dt.contains('-')) {
          return int.tryParse(dt.split('-')[0].trim());
        }
        return int.tryParse(dt.trim());
      } catch (_) {}
    }
    return null;
  }

  Future<void> _setMapMarkers(OrderModel order) async {
    _markers = HashSet<Marker>();
    _polylines = HashSet<Polyline>();
    final List<LatLng> allPoints = [];
    final Color primaryColor = Theme.of(context).primaryColor;

    if (order.store?.latitude != null && order.store?.longitude != null) {
      final storeLat = double.tryParse(order.store!.latitude!);
      final storeLng = double.tryParse(order.store!.longitude!);
      if (storeLat != null &&
          storeLng != null &&
          storeLat != 0 &&
          storeLng != 0) {
        final String logoUrl = order.store?.logoFullUrl ?? '';
        BitmapDescriptor storeIcon = await MarkerHelper.createPinMarker(
          imageUrl: logoUrl,
          logicalSize: 28,
          borderColor: Theme.of(context).primaryColor,
          borderWidth: 2,
          fallbackAsset: Images.restaurantMarker,
          fallbackIcon: Icons.store,
          fallbackIconColor: Theme.of(context).primaryColor,
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('store'),
            position: LatLng(storeLat, storeLng),
            infoWindow: InfoWindow(title: order.store?.name ?? 'store'.tr),
            icon: storeIcon,
            anchor: const Offset(0.5, 1.0),
          ),
        );
        allPoints.add(LatLng(storeLat, storeLng));
      }
    }

    if (order.deliveryAddress?.latitude != null &&
        order.deliveryAddress?.longitude != null) {
      final destLat = double.tryParse(order.deliveryAddress!.latitude!);
      final destLng = double.tryParse(order.deliveryAddress!.longitude!);
      if (destLat != null && destLng != null && destLat != 0 && destLng != 0) {
        final String userImageUrl =
            Get.find<ProfileController>().userInfoModel?.imageFullUrl ?? '';
        BitmapDescriptor destIcon = await MarkerHelper.createPinMarker(
          imageUrl: userImageUrl,
          logicalSize: 28,
          borderColor: const Color(0xFF1BA672),
          borderWidth: 2,
          fallbackAsset: Images.userMarker,
          fallbackIcon: Icons.home,
          fallbackIconColor: const Color(0xFF1BA672),
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(destLat, destLng),
            infoWindow: InfoWindow(
              title: (order.deliveryAddress?.addressType ?? 'home').tr,
            ),
            icon: destIcon,
            anchor: const Offset(0.5, 1.0),
          ),
        );
        allPoints.add(LatLng(destLat, destLng));
      }
    }

    if (order.deliveryMan?.lat != null && order.deliveryMan?.lng != null) {
      final dmLat = double.tryParse(order.deliveryMan!.lat!);
      final dmLng = double.tryParse(order.deliveryMan!.lng!);
      if (dmLat != null && dmLng != null && dmLat != 0 && dmLng != 0) {
        final String dmImageUrl = order.deliveryMan?.imageFullUrl ?? '';
        BitmapDescriptor dmIcon = await MarkerHelper.createPinMarker(
          imageUrl: dmImageUrl,
          logicalSize: 32,
          borderColor: Colors.orange,
          borderWidth: 2.5,
          fallbackAsset: Images.deliveryManMarker,
          fallbackIcon: Icons.delivery_dining,
          fallbackIconColor: Colors.orange,
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('delivery_man'),
            position: LatLng(dmLat, dmLng),
            infoWindow: InfoWindow(title: 'delivery_man'.tr),
            icon: dmIcon,
            anchor: const Offset(0.5, 1.0),
          ),
        );
        allPoints.add(LatLng(dmLat, dmLng));
        _updateETA(dmLat, dmLng);
      }
    }

    final List<LatLng> routePoints =
        allPoints.where((p) => p.latitude != 0 && p.longitude != 0).toList();
    if (routePoints.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          color: primaryColor,
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    if (mounted) setState(() {});

    if (_mapController != null && allPoints.length >= 2) {
      _fitMapBounds(allPoints);
    }
  }

  void _fitMapBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_mapController != null && mounted) {
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      }
    });
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
        backgroundColor: WaddyColors.canvas,
        body: SafeArea(
          child: GetBuilder<OrderController>(
            builder: (orderController) {
              double deliveryCharge = 0;
              double itemsPrice = 0;
              double discount = 0;
              double couponDiscount = 0;
              double tax = 0;
              double addOns = 0;
              double dmTips = 0;
              double additionalCharge = 0;
              double extraPackagingCharge = 0;
              double referrerBonusAmount = 0;
              OrderModel? order = orderController.trackModel;
              bool parcel = false;
              bool prescriptionOrder = false;
              bool taxIncluded = false;
              bool ongoing = false;
              bool showChatPermission = true;
              if (orderController.orderDetails != null && order != null) {
                parcel = order.orderType == 'parcel';
                prescriptionOrder = order.prescriptionOrder!;
                deliveryCharge = order.deliveryCharge!;
                couponDiscount = order.couponDiscountAmount!;
                discount =
                    order.storeDiscountAmount! +
                    order.flashAdminDiscountAmount! +
                    order.flashStoreDiscountAmount!;
                tax = order.totalTaxAmount!;
                dmTips = order.dmTips!;
                taxIncluded = order.taxStatus!;
                additionalCharge = order.additionalCharge!;
                extraPackagingCharge = order.extraPackagingAmount!;
                referrerBonusAmount = order.referrerBonusAmount!;
                if (prescriptionOrder) {
                  double orderAmount = order.orderAmount ?? 0;
                  itemsPrice =
                      (orderAmount + discount) -
                      ((taxIncluded ? 0 : tax) + deliveryCharge) -
                      dmTips -
                      additionalCharge;
                } else {
                  for (OrderDetailsModel orderDetails
                      in orderController.orderDetails!) {
                    for (AddOn addOn in orderDetails.addOns!) {
                      addOns = addOns + (addOn.price! * addOn.quantity!);
                    }
                    itemsPrice =
                        itemsPrice +
                        (orderDetails.price! * orderDetails.quantity!);
                  }
                }

                if (!parcel && order.store != null) {
                  for (ZoneData zData
                      in AddressHelper.getUserAddressFromSharedPref()!
                          .zoneData!) {
                    if (zData.id == order.store!.zoneId) {
                      _isCashOnDeliveryActive = zData.cashOnDelivery;
                    }
                    for (Modules m in zData.modules!) {
                      if (m.id == order.store!.moduleId) {
                        _maxCodOrderAmount = m.pivot!.maximumCodOrderAmount;
                        break;
                      }
                    }
                  }
                }

                if (order.store != null) {
                  if (order.store!.storeBusinessModel == 'commission') {
                    showChatPermission = true;
                  } else if (order.store!.storeSubscription != null &&
                      order.store!.storeBusinessModel == 'subscription') {
                    showChatPermission =
                        order.store!.storeSubscription!.chat == 1;
                  } else {
                    showChatPermission = false;
                  }
                } else {
                  showChatPermission = AuthHelper.isLoggedIn();
                }

                final status = OrderStatus.fromString(order.orderStatus);
                ongoing = status != null && status.isOngoing;
              }
              double subTotal = itemsPrice + addOns;
              double total =
                  itemsPrice +
                  addOns -
                  discount +
                  (taxIncluded ? 0 : tax) +
                  deliveryCharge -
                  couponDiscount +
                  dmTips +
                  additionalCharge +
                  extraPackagingCharge -
                  referrerBonusAmount;

              if (orderController.orderDetails == null ||
                  order == null ||
                  orderController.trackModel == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final int? liveEtaMinutes = _getLiveEtaMinutes(order);
              final int? prepMinutes = _getPrepMinutes(order);

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      child:
                          ResponsiveHelper.isDesktop(context)
                              ? FooterView(
                                child: SizedBox(
                                  width: Dimensions.webMaxWidth,
                                  child: _desktopLayout(
                                    orderController,
                                    order,
                                    ongoing,
                                    parcel,
                                    prescriptionOrder,
                                    showChatPermission,
                                    deliveryCharge,
                                    itemsPrice,
                                    discount,
                                    couponDiscount,
                                    tax,
                                    addOns,
                                    dmTips,
                                    taxIncluded,
                                    subTotal,
                                    total,
                                    extraPackagingCharge,
                                    referrerBonusAmount,
                                  ),
                                ),
                              )
                              : Column(
                                children: [
                                  // 1. Teal hero — animated entrance
                                  FadeTransition(
                                    opacity: _heroFade,
                                    child: SlideTransition(
                                      position: _heroSlide,
                                      child: _buildGreenHeroWithBanner(
                                        order,
                                        liveEtaMinutes,
                                        prepMinutes,
                                      ),
                                    ),
                                  ),

                                  // ── Zomato-style body ──────────────────
                                  FadeTransition(
                                    opacity: _contentFade,
                                    child: SlideTransition(
                                      position: _contentSlide,
                                      child: Column(
                                        children: [
                                          // 2. Order info card: item fan + steps + OTP + order ID
                                          ZomatoOrderInfoCard(
                                            order: order,
                                            orderController: orderController,
                                            ongoing: ongoing,
                                          ),

                                          const SizedBox(height: 12),

                                          // 4. Delivery partner card
                                          ZomatoDeliveryPartnerCard(
                                            order: order,
                                            showChatPermission: showChatPermission,
                                            onTimerCancel: () => _timer?.cancel(),
                                            onStartTracking: _startTracking,
                                          ),

                                          const SizedBox(height: 32),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────
  Widget _buildGreenHeroWithBanner(
    OrderModel order,
    int? liveEtaMinutes,
    int? prepMinutes,
  ) {
    final int? displayEta = liveEtaMinutes ?? prepMinutes;
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
    final bool isTerminal = status?.isTerminal ?? false;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F7F2), Color(0xFFCCEEE4)],
        ),
      ),
      child: Stack(
        children: [
          // Subtle decorative circles
          Positioned(
            right: -30,
            top: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WaddyColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            top: 50,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WaddyColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    _buildHeroIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: _handleBack,
                    ),
                    Expanded(
                      child: Text(
                        order.store?.name ?? 'order_details'.tr,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyBodyMedium.copyWith(
                          color: WaddyColors.ink,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _buildHeroSupportButton(),
                  ],
                ),
              ),

              // ── ETA + animation row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Context label
                          Text(
                            _heroEtaLabel(status).toUpperCase(),
                            style: waddyMicro.copyWith(
                              fontSize: 11,
                              color: WaddyColors.primary.withValues(alpha: 0.75),
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Big ETA number
                          if (!isTerminal) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 500),
                                  transitionBuilder: (child, anim) => FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.2),
                                        end: Offset.zero,
                                      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutQuart)),
                                      child: child,
                                    ),
                                  ),
                                  child: Text(
                                    displayEta != null ? '$displayEta' : '--',
                                    key: ValueKey(displayEta),
                                    style: waddyDisplay.copyWith(
                                      fontSize: 80,
                                      color: WaddyColors.primary,
                                      height: 0.95,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    'min',
                                    style: waddyTitle.copyWith(
                                      fontSize: 22,
                                      color: WaddyColors.inkLight,
                                      height: 1.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                          // Status pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: WaddyColors.primary,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: WaddyColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              _heroStatusCaption(status),
                              style: waddyLabel.copyWith(
                                color: WaddyColors.mint,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Lottie animation
                    _buildStatusAnimation(status),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: WaddyColors.primary.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: WaddyColors.primary, size: 22),
        ),
      ),
    );
  }

  Widget _buildHeroSupportButton() {
    return Material(
      color: WaddyColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Get.toNamed(RouteHelper.getSupportRoute()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.headset_mic_outlined, color: WaddyColors.primary, size: 18),
              const SizedBox(width: 5),
              Text(
                'support'.tr,
                style: waddyLabel.copyWith(
                  color: WaddyColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LatLng? _getMapFocus(OrderModel order) {
    if (order.store?.latitude != null && order.store?.longitude != null) {
      final storeLat = double.tryParse(order.store!.latitude!);
      final storeLng = double.tryParse(order.store!.longitude!);
      if (storeLat != null && storeLng != null && storeLat != 0 && storeLng != 0) {
        return LatLng(storeLat, storeLng);
      }
    }
    if (order.deliveryAddress?.latitude != null &&
        order.deliveryAddress?.longitude != null) {
      final destLat = double.tryParse(order.deliveryAddress!.latitude!);
      final destLng = double.tryParse(order.deliveryAddress!.longitude!);
      if (destLat != null && destLng != null && destLat != 0 && destLng != 0) {
        return LatLng(destLat, destLng);
      }
    }
    return null;
  }

  Widget _buildMapPreviewCard(OrderModel order) {
    final focus = _getMapFocus(order);

    final VoidCallback? mapTap = order.deliveryAddress != null
        ? () => Get.toNamed(RouteHelper.getMapRoute(
              order.deliveryAddress!,
              'order',
              true,
              storeName: order.store?.name,
            ))
        : null;

    return mapTap != null
        ? _TapScaleButton(
            onTap: mapTap,
            child: _mapCardContent(focus),
          )
        : _mapCardContent(focus);
  }

  Widget _mapCardContent(dynamic focus) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: WaddyColors.shadowDeep,
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // Map thumbnail
              SizedBox(
                width: 80,
                height: 72,
                child: focus != null
                    ? IgnorePointer(
                        child: GoogleMap(
                          liteModeEnabled: true,
                          initialCameraPosition: CameraPosition(
                            target: focus,
                            zoom: 14.0,
                          ),
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          mapToolbarEnabled: false,
                          scrollGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          markers: _markers,
                          polylines: _polylines,
                          onMapCreated: (controller) {
                            _mapController = controller;
                            final trackedOrder =
                                Get.find<OrderController>().trackModel;
                            if (trackedOrder != null) {
                              _setMapMarkers(trackedOrder);
                            }
                          },
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.map_outlined,
                          size: 28,
                          color: Colors.grey.shade400,
                        ),
                      ),
              ),
              // Right-side text
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'track_on_map'.tr,
                        style: waddyBodyMedium.copyWith(
                          color: WaddyColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'see_live_rider'.tr,
                        style: waddyMicro.copyWith(
                          fontSize: 12,
                          color: WaddyColors.inkLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: WaddyColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: WaddyColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildStatusAnimation(OrderStatus? status) {
    final double size = MediaQuery.of(context).size.width < 360 ? 120 : 140;
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        _statusAnimationAsset(status),
        fit: BoxFit.contain,
        repeat: status == null || !status.isTerminal,
      ),
    );
  }

  String _heroEtaLabel(OrderStatus? status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Hang tight, confirming your order...';
      case OrderStatus.accepted:
      case OrderStatus.confirmed:
        return 'Order confirmed! Arriving in';
      case OrderStatus.processing:
        return 'Chef is cooking 🍳 Arriving in';
      case OrderStatus.handover:
      case OrderStatus.pickedUp:
        return 'On the way! Arriving in';
      case OrderStatus.delivered:
        return 'Delivered!';
      case OrderStatus.canceled:
      case OrderStatus.failed:
        return 'Order cancelled';
      default:
        return 'Arriving in';
    }
  }

  String _heroStatusCaption(OrderStatus? status) {
    switch (status) {
      case OrderStatus.pending:
        return '⏳ Waiting for restaurant';
      case OrderStatus.accepted:
      case OrderStatus.confirmed:
        return '✅ Confirmed';
      case OrderStatus.processing:
        return '👨‍🍳 Being prepared';
      case OrderStatus.handover:
      case OrderStatus.pickedUp:
        return '🛵 Out for delivery';
      case OrderStatus.delivered:
        return '🎉 Enjoy your meal!';
      case OrderStatus.canceled:
      case OrderStatus.failed:
        return '❌ Cancelled';
      default:
        return '📦 Processing';
    }
  }

  String _statusAnimationAsset(OrderStatus? status) {
    switch (status) {
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
      case OrderStatus.refunded:
        return 'assets/animation/completed_order.json';
      case OrderStatus.failed:
      case OrderStatus.canceled:
      case OrderStatus.refundRequested:
      case OrderStatus.refundRequestCanceled:
        return 'assets/animation/off.json';
      case null:
        return 'assets/animation/order_placed.json';
    }
  }

  // ─── Desktop Layout ───────────────────────────────────────────────────
  Widget _desktopLayout(
    OrderController orderController,
    OrderModel order,
    bool ongoing,
    bool parcel,
    bool prescriptionOrder,
    bool showChatPermission,
    double deliveryCharge,
    double itemsPrice,
    double discount,
    double couponDiscount,
    double tax,
    double addOns,
    double dmTips,
    bool taxIncluded,
    double subTotal,
    double total,
    double extraPackagingCharge,
    double referrerBonusAmount,
  ) {
    return Column(
      children: [
        Container(
          height: 64,
          color: Theme.of(context).primaryColor.withValues(alpha: 0.10),
          child: Center(child: Text('order_details'.tr, style: robotoMedium)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: OrderInfoWidget(
                order: order,
                ongoing: ongoing,
                parcel: parcel,
                prescriptionOrder: prescriptionOrder,
                timerCancel: () => _timer?.cancel(),
                startApiCall: () => _startTracking(),
                orderController: orderController,
                showChatPermission: showChatPermission,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeLarge),
            Expanded(
              flex: 4,
              child: OrderCalculationWidget(
                orderController: orderController,
                order: order,
                ongoing: ongoing,
                parcel: parcel,
                prescriptionOrder: prescriptionOrder,
                deliveryCharge: deliveryCharge,
                itemsPrice: itemsPrice,
                discount: discount,
                couponDiscount: couponDiscount,
                tax: tax,
                addOns: addOns,
                dmTips: dmTips,
                taxIncluded: taxIncluded,
                subTotal: subTotal,
                total: total,
                bottomView: OrderActionButtons(
                  orderController: orderController,
                  order: order,
                  parcel: parcel,
                  totalPrice: total,
                  contactNumber: widget.contactNumber,
                  isCashOnDeliveryActive: _isCashOnDeliveryActive ?? false,
                  maxCodOrderAmount: _maxCodOrderAmount,
                  onTimerCancel: () => _timer?.cancel(),
                  onStartTracking: _startTracking,
                ),
                extraPackagingAmount: extraPackagingCharge,
                referrerBonusAmount: referrerBonusAmount,
                timerCancel: () => _timer?.cancel(),
                startApiCall: () => _startTracking(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void openDialog(BuildContext context, String imageUrl) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child: PhotoView(
                tightMode: true,
                imageProvider: NetworkImage(imageUrl),
                heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                splashRadius: 5,
                onPressed: () => Get.back(),
                icon: const Icon(Icons.cancel, color: Colors.red),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ─── Tap scale feedback widget ─────────────────────────────────────────────
// Applies a quick 0.92 scale-down on press, restores on release.
// GPU-only (transform + opacity) — 60fps on low-end devices.
class _TapScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapScaleButton({required this.child, required this.onTap});

  @override
  State<_TapScaleButton> createState() => _TapScaleButtonState();
}

class _TapScaleButtonState extends State<_TapScaleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ─── Pulsing opacity badge ─────────────────────────────────────────────────
// Loops between 60%→100% opacity — communicates "waiting" without distraction.
class _PulsingBadge extends StatefulWidget {
  final Widget child;
  const _PulsingBadge({required this.child});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
