import 'dart:async';
import 'dart:collection';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_details_model.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/order/domain/models/order_status.dart';
import 'package:sixam_mart/features/order/domain/services/order_tracking_stream_service.dart';
import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/date_converter.dart';
import 'package:sixam_mart/helper/eta_calculator.dart';
import 'package:sixam_mart/helper/marker_animator.dart';
import 'package:sixam_mart/helper/marker_helper.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_dialog.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/common/widgets/footer_view.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/features/checkout/widgets/offline_success_dialog.dart';
import 'package:sixam_mart/features/order/widgets/order_calcuation_widget.dart';
import 'package:sixam_mart/features/order/widgets/order_info_widget.dart';
import 'package:sixam_mart/features/order/widgets/lucky_spin_section.dart';
import 'package:sixam_mart/features/order/widgets/order_steps_card.dart';
import 'package:sixam_mart/features/order/widgets/order_map_section.dart';
import 'package:sixam_mart/features/order/widgets/delivery_man_card.dart';
import 'package:sixam_mart/features/order/widgets/order_action_buttons.dart';
import 'package:sixam_mart/features/order/widgets/order_details_bottom_sheet.dart';
import 'package:flutter/material.dart';
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
    with WidgetsBindingObserver {
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
      if (dmLat != null && dmLng != null && destLat != null && destLng != null) {
        final distance = ETACalculator.calculateDistanceKm(
          dmLat, dmLng, destLat, destLng,
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
      if (storeLat != null && storeLng != null && storeLat != 0 && storeLng != 0) {
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

  void _handleHelp(OrderController orderController) {
    Get.toNamed(RouteHelper.getSupportRoute());
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
        backgroundColor: const Color(0xFFF5F5F5),
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

              final int itemCount =
                  parcel ? 1 : (orderController.orderDetails?.length ?? 0);
              final String storeName =
                  parcel
                      ? (order.parcelCategory?.name ?? 'parcel'.tr)
                      : (order.store?.name ?? '');
              final String timeStr =
                  order.createdAt != null
                      ? DateConverter.dateTimeStringToDateTime(order.createdAt!)
                      : '';
              final int? liveEtaMinutes = _getLiveEtaMinutes(order);
              final int? prepMinutes = _getPrepMinutes(order);
              final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
              final bool showLuckySpinLayout =
                  ongoing &&
                  !parcel &&
                  status != null &&
                  status.isWaitingStatus;

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
                                  if (showLuckySpinLayout)
                                    LuckySpinSection(
                                      order: order,
                                      orderController: orderController,
                                      itemCount: itemCount,
                                      liveEtaMinutes: liveEtaMinutes,
                                      prepMinutes: prepMinutes,
                                      onBack: _handleBack,
                                      onHelp: () => _handleHelp(orderController),
                                      onViewDetails: () =>
                                          OrderDetailsBottomSheet.show(
                                            context: context,
                                            orderController: orderController,
                                            order: order,
                                          ),
                                    )
                                  else ...[
                                    _buildSwiggyAppBar(
                                      storeName,
                                      timeStr,
                                      itemCount,
                                      orderController,
                                    ),
                                    OrderMapSection(
                                      order: order,
                                      ongoing: ongoing,
                                      parcel: parcel,
                                      liveEtaMinutes: liveEtaMinutes,
                                      prepMinutes: prepMinutes,
                                      markers: _markers,
                                      polylines: _polylines,
                                      onMapCreated: (controller) {
                                        _mapController = controller;
                                        _setMapMarkers(order);
                                      },
                                    ),
                                    OrderStepsCard(
                                      order: order,
                                      orderController: orderController,
                                      itemCount: itemCount,
                                      parcel: parcel,
                                      ongoing: ongoing,
                                      onViewDetails: () =>
                                          OrderDetailsBottomSheet.show(
                                            context: context,
                                            orderController: orderController,
                                            order: order,
                                          ),
                                    ),
                                  ],

                                  // Coupon Savings Banner
                                  if (couponDiscount > 0)
                                    _buildCouponSavingsBanner(couponDiscount),

                                  // Delivery Man Details
                                  if (order.deliveryMan != null)
                                    DeliveryManCard(
                                      order: order,
                                      showChatPermission: showChatPermission,
                                      onTimerCancel: () => _timer?.cancel(),
                                      onStartTracking: _startTracking,
                                    ),

                                  // Order Items
                                  if (!showLuckySpinLayout &&
                                      !parcel &&
                                      orderController.orderDetails!.isNotEmpty)
                                    _buildOrderItemsCard(
                                      order,
                                      orderController,
                                    ),

                                  const SizedBox(
                                    height: Dimensions.paddingSizeSmall,
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

  // ─── Swiggy-style App Bar ─────────────────────────────────────────────
  Widget _buildSwiggyAppBar(
    String storeName,
    String timeStr,
    int itemCount,
    OrderController orderController,
  ) {
    final order = orderController.trackModel;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black87, size: 22),
            onPressed: _handleBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${'order'.tr} #${order?.id ?? ''}',
                  style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => OrderDetailsBottomSheet.show(
                        context: context,
                        orderController: orderController,
                        order: order!,
                      ),
                      child: Text(
                        'view_details'.tr,
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    if (timeStr.isNotEmpty)
                      Text(
                        '  |  $timeStr',
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _handleHelp(orderController),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeSmall,
                vertical: Dimensions.paddingSizeExtraSmall,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'help'.tr,
              style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Coupon Savings Banner ────────────────────────────────────────────
  Widget _buildCouponSavingsBanner(double couponDiscount) {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '  ',
              style: robotoRegular.copyWith(
                fontSize: 12,
                color: const Color(0xFF1BA672),
              ),
            ),
            Text(
              '${'yay'.tr}! ${PriceConverter.convertPrice(couponDiscount)} ${'saved_with_coupon'.tr}',
              style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: const Color(0xFF1BA672),
              ),
            ),
            Text(
              '  ',
              style: robotoRegular.copyWith(
                fontSize: 12,
                color: const Color(0xFF1BA672),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Order Items Card ─────────────────────────────────────────────────
  Widget _buildOrderItemsCard(
    OrderModel order,
    OrderController orderController,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeExtraSmall,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'item_info'.tr,
            style: robotoMedium.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              color: Colors.black87,
            ),
          ),
          SizedBox(
            height:
                Dimensions.paddingSizeSmall + Dimensions.paddingSizeExtraSmall,
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orderController.orderDetails!.length,
            separatorBuilder:
                (_, __) => Divider(color: Colors.grey.shade100, height: 16),
            itemBuilder: (context, index) {
              final detail = orderController.orderDetails![index];
              return Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomImage(
                      image: '${detail.imageFullUrl}',
                      height: 48,
                      width: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.itemDetails?.name ?? '',
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          PriceConverter.convertPrice(detail.price),
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Theme.of(context).primaryColor,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'x${detail.quantity}',
                      style: robotoMedium.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
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
