import 'dart:async';
import 'dart:collection';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:sixam_mart/common/controllers/theme_controller.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart/features/chat/domain/models/conversation_model.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/widgets/waiting_game_widget.dart';
import 'package:sixam_mart/features/order/domain/models/order_details_model.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
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
import 'package:sixam_mart/common/widgets/confirmation_dialog.dart';
import 'package:sixam_mart/common/widgets/custom_dialog.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/footer_view.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/features/checkout/widgets/offline_success_dialog.dart';
import 'package:sixam_mart/features/order/widgets/cancellation_dialogue_widget.dart';
import 'package:sixam_mart/features/order/widgets/order_calcuation_widget.dart';
import 'package:sixam_mart/features/order/widgets/order_info_widget.dart';
import 'package:sixam_mart/features/review/screens/rate_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel? orderModel;
  final int? orderId;
  final bool fromNotification;
  final bool fromOfflinePayment;
  final String? contactNumber;
  const OrderDetailsScreen({super.key, required this.orderModel, required this.orderId, this.fromNotification = false, this.fromOfflinePayment = false, this.contactNumber});

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
  bool _mapLoading = true;

  // SSE real-time tracking
  OrderTrackingStreamService? _streamService;
  StreamSubscription<TrackingStreamData>? _streamSubscription;
  final MarkerAnimator _markerAnimator = MarkerAnimator();
  bool _useSSE = true;
  ETAResult? _currentETA;

  void _loadData(BuildContext context, bool reload) async {
    await Get.find<OrderController>().trackOrder(widget.orderId.toString(), reload ? null : widget.orderModel, false, contactNumber: widget.contactNumber).then((value) {
      if(widget.fromOfflinePayment) {
        Future.delayed(const Duration(seconds: 2), () => showAnimatedDialog(Get.context!, OfflineSuccessDialog(orderId: widget.orderId)));
      }
    });
    Get.find<OrderController>().timerTrackOrder(widget.orderId.toString(), contactNumber: widget.contactNumber);
    Get.find<OrderController>().getOrderDetails(widget.orderId.toString());

    // Start real-time tracking for active orders
    _startTracking();
  }

  /// Start SSE tracking, fallback to polling
  void _startTracking() {
    final status = Get.find<OrderController>().trackModel?.orderStatus;
    if (_isTerminalStatus(status)) return;

    if (_useSSE) {
      _startSSETracking();
    } else {
      _startPolling();
    }
  }

  bool _isTerminalStatus(String? status) {
    return status == 'delivered' || status == 'failed' || status == 'canceled'
        || status == 'refund_requested' || status == 'refunded' || status == 'refund_request_canceled';
  }

  /// SSE-based real-time tracking (same as order_tracking_screen)
  void _startSSETracking() {
    _streamService?.disconnect();
    _streamService = OrderTrackingStreamService();

    _streamSubscription = _streamService!
        .connect(
          orderId: widget.orderId.toString(),
          token: Get.find<AuthController>().getUserToken(),
          contactNumber: widget.contactNumber,
          guestId: AuthHelper.isGuestLoggedIn() ? AuthHelper.getGuestId() : null,
        )
        .listen(
          (data) => _handleSSEUpdate(data),
          onError: (error) {
            debugPrint('OrderDetails SSE Error: $error - Falling back to polling');
            _fallbackToPolling();
          },
        );
  }

  /// Handle incoming SSE update
  void _handleSSEUpdate(TrackingStreamData data) {
    final orderController = Get.find<OrderController>();

    if (orderController.trackModel != null) {
      orderController.trackModel!.orderStatus = data.status;
      orderController.trackModel!.subStatus = data.subStatus;

      if (data.deliveryMan != null && orderController.trackModel!.deliveryMan != null) {
        orderController.trackModel!.deliveryMan!.lat = data.deliveryMan!.lat.toString();
        orderController.trackModel!.deliveryMan!.lng = data.deliveryMan!.lng.toString();
      }

      orderController.update();
    }

    // Animate delivery man marker
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

    // Stop tracking if order completed
    if (_isTerminalStatus(data.status)) {
      _streamService?.disconnect();
      _timer?.cancel();
    }
  }

  /// Update ETA based on delivery man's live position
  void _updateETA(double driverLat, double driverLng) {
    final destination = Get.find<OrderController>().trackModel?.deliveryAddress;
    if (destination?.latitude == null || destination?.longitude == null) return;

    final distance = ETACalculator.calculateDistanceKm(
      driverLat, driverLng,
      double.parse(destination!.latitude!),
      double.parse(destination.longitude!),
    );

    if (mounted) {
      setState(() {
        _currentETA = ETACalculator.calculate(distance);
      });
    }
  }

  /// Animate delivery man marker to new position
  void _updateDeliveryManMarkerAnimated(LatLng position, double rotation) async {
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
        _markers.add(Marker(
          markerId: const MarkerId('delivery_man'),
          position: position,
          infoWindow: InfoWindow(title: 'delivery_man'.tr, snippet: _currentETA?.displayText ?? ''),
          rotation: rotation,
          icon: dmIcon,
          anchor: const Offset(0.5, 1.0),
        ));
      });
    }

    _updateRoutePolyline(position);
  }

  /// Update polyline with delivery man's current position
  void _updateRoutePolyline(LatLng driverPosition) {
    final track = Get.find<OrderController>().trackModel;
    if (track == null) return;

    final List<LatLng> routePoints = [];

    if (track.store?.latitude != null && track.store?.longitude != null) {
      routePoints.add(LatLng(double.parse(track.store!.latitude!), double.parse(track.store!.longitude!)));
    }
    routePoints.add(driverPosition);
    if (track.deliveryAddress?.latitude != null && track.deliveryAddress?.longitude != null) {
      routePoints.add(LatLng(double.parse(track.deliveryAddress!.latitude!), double.parse(track.deliveryAddress!.longitude!)));
    }

    if (routePoints.length < 2) return;

    if (mounted) {
      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          color: Theme.of(context).primaryColor,
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ));
      });
    }
  }

  /// Fallback to polling when SSE fails
  void _fallbackToPolling() {
    _useSSE = false;
    _streamService?.disconnect();
    _streamSubscription?.cancel();
    _startPolling();
  }

  /// Polling-based tracking (every 10 seconds)
  void _startPolling() {
    _timer?.cancel();
    final status = Get.find<OrderController>().trackModel?.orderStatus;
    if (_isTerminalStatus(status)) return;

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final orderController = Get.find<OrderController>();
      await orderController.timerTrackOrder(widget.orderId.toString(), contactNumber: widget.contactNumber);

      // Update map markers with new delivery man position
      final order = orderController.trackModel;
      if (order != null && mounted) {
        _refreshMapMarkers(order);

        // Update ETA from delivery man position
        if (order.deliveryMan?.lat != null && order.deliveryMan?.lng != null) {
          final dmLat = double.tryParse(order.deliveryMan!.lat!);
          final dmLng = double.tryParse(order.deliveryMan!.lng!);
          if (dmLat != null && dmLng != null) {
            _updateETA(dmLat, dmLng);
          }
        }

        // Stop polling if order completed
        if (_isTerminalStatus(order.orderStatus)) {
          _timer?.cancel();
        }
      }
    });
  }

  /// Refresh only the delivery man marker (lightweight update during polling)
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
            _markers.add(Marker(
              markerId: const MarkerId('delivery_man'),
              position: LatLng(dmLat, dmLng),
              infoWindow: InfoWindow(title: 'delivery_man'.tr),
              icon: dmIcon,
              anchor: const Offset(0.5, 1.0),
            ));
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
      // Resume tracking when app comes back to foreground
      _startTracking();
    } else if (state == AppLifecycleState.paused) {
      // Pause everything when app goes to background
      _timer?.cancel();
      _streamService?.disconnect();
      _streamSubscription?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    _streamSubscription?.cancel();
    _streamService?.disconnect();
    _markerAnimator.cancel();
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  String _getOrderStatusText(OrderModel order) {
    switch (order.orderStatus) {
      case 'pending':
        return 'order_placed'.tr;
      case 'accepted':
        return 'order_accepted'.tr;
      case 'confirmed':
        return 'order_confirmed'.tr;
      case 'processing':
        return 'order_processing'.tr;
      case 'handover':
        return 'order_handover'.tr;
      case 'picked_up':
        return 'order_picked_up'.tr;
      case 'delivered':
        return 'order_delivered'.tr;
      case 'canceled':
        return 'order_cancelled'.tr;
      case 'failed':
        return 'order_failed'.tr;
      case 'refund_requested':
        return 'refund_requested'.tr;
      case 'refunded':
        return 'refunded'.tr;
      default:
        return order.orderStatus?.tr ?? '';
    }
  }

  /// Returns live ETA in minutes only when a delivery man is assigned and en route.
  /// Returns null for all other states (pending, preparing, etc.) — caller decides what to show.
  int? _getLiveEtaMinutes(OrderModel order) {
    // Live ETA from SSE/polling distance calculation
    if (_currentETA != null && _currentETA!.minMinutes > 0) {
      return _currentETA!.minMinutes;
    }

    // Distance-based ETA when delivery man coordinates are available
    if (order.deliveryMan?.lat != null && order.deliveryMan?.lng != null
        && order.deliveryAddress?.latitude != null && order.deliveryAddress?.longitude != null) {
      final dmLat = double.tryParse(order.deliveryMan!.lat!);
      final dmLng = double.tryParse(order.deliveryMan!.lng!);
      final destLat = double.tryParse(order.deliveryAddress!.latitude!);
      final destLng = double.tryParse(order.deliveryAddress!.longitude!);
      if (dmLat != null && dmLng != null && destLat != null && destLng != null) {
        final distance = ETACalculator.calculateDistanceKm(dmLat, dmLng, destLat, destLng);
        final eta = ETACalculator.calculate(distance);
        if (eta.minMinutes > 0) return eta.minMinutes;
      }
    }

    return null;
  }

  /// Returns the store's prep/processing time in minutes, or null if unavailable.
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

    // Store marker — decorative pin with store logo
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
        _markers.add(Marker(
          markerId: const MarkerId('store'),
          position: LatLng(storeLat, storeLng),
          infoWindow: InfoWindow(title: order.store?.name ?? 'store'.tr),
          icon: storeIcon,
          anchor: const Offset(0.5, 1.0),
        ));
        allPoints.add(LatLng(storeLat, storeLng));
      }
    }

    // Delivery address marker — decorative pin with user profile image
    if (order.deliveryAddress?.latitude != null && order.deliveryAddress?.longitude != null) {
      final destLat = double.tryParse(order.deliveryAddress!.latitude!);
      final destLng = double.tryParse(order.deliveryAddress!.longitude!);
      if (destLat != null && destLng != null && destLat != 0 && destLng != 0) {
        final String userImageUrl = Get.find<ProfileController>().userInfoModel?.imageFullUrl ?? '';
        BitmapDescriptor destIcon = await MarkerHelper.createPinMarker(
          imageUrl: userImageUrl,
          logicalSize: 28,
          borderColor: const Color(0xFF1BA672),
          borderWidth: 2,
          fallbackAsset: Images.userMarker,
          fallbackIcon: Icons.home,
          fallbackIconColor: const Color(0xFF1BA672),
        );
        _markers.add(Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destLat, destLng),
          infoWindow: InfoWindow(title: (order.deliveryAddress?.addressType ?? 'home').tr),
          icon: destIcon,
          anchor: const Offset(0.5, 1.0),
        ));
        allPoints.add(LatLng(destLat, destLng));
      }
    }

    // Delivery man marker — decorative pin with delivery man photo
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
        _markers.add(Marker(
          markerId: const MarkerId('delivery_man'),
          position: LatLng(dmLat, dmLng),
          infoWindow: InfoWindow(title: 'delivery_man'.tr),
          icon: dmIcon,
          anchor: const Offset(0.5, 1.0),
        ));
        allPoints.add(LatLng(dmLat, dmLng));

        // Calculate initial ETA
        _updateETA(dmLat, dmLng);
      }
    }

    // Polyline between store and destination
    final List<LatLng> routePoints = allPoints.where((p) => p.latitude != 0 && p.longitude != 0).toList();
    if (routePoints.length >= 2) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: Theme.of(context).primaryColor,
        width: 3,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    }

    if (mounted) setState(() {});

    // Fit bounds with proper southwest/northeast calculation
    if (_mapController != null && allPoints.length >= 2) {
      _fitMapBounds(allPoints);
    }
  }

  /// Properly calculate and fit map bounds for all points
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

    // Delay to ensure map is fully rendered before animating
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_mapController != null && mounted) {
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) async {
        if(widget.fromNotification || widget.fromOfflinePayment) {
          Get.offAllNamed(RouteHelper.getInitialRoute());
        } else {
          return;
        }
      },
      child: Scaffold(
        endDrawer: const MenuDrawer(),
        endDrawerEnableOpenDragGesture: false,
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(child: GetBuilder<OrderController>(builder: (orderController) {
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
          if(orderController.orderDetails != null  && order != null) {
            parcel = order.orderType == 'parcel';
            prescriptionOrder = order.prescriptionOrder!;
            deliveryCharge = order.deliveryCharge!;
            couponDiscount = order.couponDiscountAmount!;
            discount = order.storeDiscountAmount! + order.flashAdminDiscountAmount! + order.flashStoreDiscountAmount!;
            tax = order.totalTaxAmount!;
            dmTips = order.dmTips!;
            taxIncluded = order.taxStatus!;
            additionalCharge = order.additionalCharge!;
            extraPackagingCharge = order.extraPackagingAmount!;
            referrerBonusAmount = order.referrerBonusAmount!;
            if(prescriptionOrder) {
              double orderAmount = order.orderAmount ?? 0;
              itemsPrice = (orderAmount + discount) - ((taxIncluded ? 0 : tax) + deliveryCharge) - dmTips - additionalCharge;
            } else{
              for(OrderDetailsModel orderDetails in orderController.orderDetails!) {
                for(AddOn addOn in orderDetails.addOns!) {
                  addOns = addOns + (addOn.price! * addOn.quantity!);
                }
                itemsPrice = itemsPrice + (orderDetails.price! * orderDetails.quantity!);
              }
            }

            if(!parcel && order.store != null) {
              for(ZoneData zData in AddressHelper.getUserAddressFromSharedPref()!.zoneData!) {
                if(zData.id == order.store!.zoneId){
                  _isCashOnDeliveryActive = zData.cashOnDelivery;
                }
                for(Modules m in zData.modules!) {
                  if(m.id == order.store!.moduleId) {
                    _maxCodOrderAmount = m.pivot!.maximumCodOrderAmount;
                    break;
                  }
                }
              }
            }

            if (order.store != null) {
              if (order.store!.storeBusinessModel == 'commission') {
                showChatPermission = true;
              } else if (order.store!.storeSubscription != null && order.store!.storeBusinessModel == 'subscription') {
                showChatPermission = order.store!.storeSubscription!.chat == 1;
              } else {
                showChatPermission = false;
              }
            } else {
              showChatPermission = AuthHelper.isLoggedIn();
            }

            ongoing = (order.orderStatus != 'delivered' && order.orderStatus != 'failed' && order.orderStatus != 'canceled' && order.orderStatus != 'refund_requested'
            && order.orderStatus != 'refunded' && order.orderStatus != 'refund_request_canceled');

          }
          double subTotal = itemsPrice + addOns;
          double total = itemsPrice + addOns - discount + (taxIncluded ? 0 : tax) + deliveryCharge - couponDiscount + dmTips + additionalCharge + extraPackagingCharge - referrerBonusAmount;

          if (orderController.orderDetails == null || order == null || orderController.trackModel == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final int itemCount = parcel ? 1 : (orderController.orderDetails?.length ?? 0);
          final String storeName = parcel
              ? (order.parcelCategory?.name ?? 'parcel'.tr)
              : (order.store?.name ?? '');
          final String timeStr = order.createdAt != null
              ? DateConverter.dateTimeStringToDateTime(order.createdAt!)
              : '';
          final int? liveEtaMinutes = _getLiveEtaMinutes(order);
          final int? prepMinutes = _getPrepMinutes(order);

          return Column(children: [
            Expanded(child: SingleChildScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              child: ResponsiveHelper.isDesktop(context)
                ? FooterView(child: SizedBox(width: Dimensions.webMaxWidth, child: _desktopLayout(
                    orderController, order, ongoing, parcel, prescriptionOrder,
                    showChatPermission, deliveryCharge, itemsPrice, discount,
                    couponDiscount, tax, addOns, dmTips, taxIncluded, subTotal,
                    total, extraPackagingCharge, referrerBonusAmount,
                  )))
                : Column(children: [
                    // --- Swiggy-style App Bar ---
                    _buildSwiggyAppBar(storeName, timeStr, itemCount),

                    // --- Map + Status Card (Swiggy-style overlap) ---
                    _buildMapWithOverlappingCard(order, storeName, ongoing, parcel, liveEtaMinutes, prepMinutes),

                    // --- Coupon Savings Banner ---
                    if (couponDiscount > 0)
                      _buildCouponSavingsBanner(couponDiscount),

                    // --- Mini-Game while waiting ---
                    if (ongoing && (order.orderStatus == 'pending' || order.orderStatus == 'accepted'
                        || order.orderStatus == 'confirmed' || order.orderStatus == 'processing'
                        || order.orderStatus == 'handover'))
                      const WaitingGameWidget(),

                    // --- Delivery Man Details ---
                    if (order.deliveryMan != null)
                      _buildDeliveryManCard(order, showChatPermission),

                    // --- Order Items ---
                    if (!parcel && orderController.orderDetails!.isNotEmpty)
                      _buildOrderItemsCard(order, orderController),

                    // --- Order Summary ---
                    OrderCalculationWidget(
                      orderController: orderController, order: order, ongoing: ongoing, parcel: parcel,
                      prescriptionOrder: prescriptionOrder, deliveryCharge: deliveryCharge, itemsPrice: itemsPrice,
                      discount: discount, couponDiscount: couponDiscount, tax: tax, addOns: addOns, dmTips: dmTips,
                      taxIncluded: taxIncluded, subTotal: subTotal, total: total,
                      bottomView: const SizedBox(), extraPackagingAmount: extraPackagingCharge,
                      referrerBonusAmount: referrerBonusAmount,
                      timerCancel: () => _timer?.cancel(), startApiCall: () => _startTracking(),
                    ),

                    const SizedBox(height: Dimensions.paddingSizeSmall),
                  ]),
            )),

            // --- Bottom Action Buttons ---
            if (!ResponsiveHelper.isDesktop(context))
              _bottomView(orderController, order, parcel, total),
          ]);
        })),
      ),
    );
  }

  // ─── Swiggy-style App Bar ─────────────────────────────────────────────
  Widget _buildSwiggyAppBar(String storeName, String timeStr, int itemCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
          onPressed: () {
            if (widget.fromNotification || widget.fromOfflinePayment) {
              Get.offAllNamed(RouteHelper.getInitialRoute());
            } else {
              Get.back();
            }
          },
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              storeName,
              style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: Colors.black87),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$timeStr  |  $itemCount ${'items'.tr}',
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.grey),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz, color: Colors.black54, size: 24),
          onPressed: () {},
        ),
      ]),
    );
  }

  // ─── Map + Status Card (Swiggy-style: card overlaps map from below) ───
  Widget _buildMapWithOverlappingCard(OrderModel order, String storeName, bool ongoing, bool parcel, int? liveEtaMinutes, int? prepMinutes) {
    LatLng initialTarget;
    if (order.deliveryAddress?.latitude != null && order.deliveryAddress?.longitude != null) {
      initialTarget = LatLng(
        double.tryParse(order.deliveryAddress!.latitude!) ?? 0,
        double.tryParse(order.deliveryAddress!.longitude!) ?? 0,
      );
    } else if (order.store?.latitude != null && order.store?.longitude != null) {
      initialTarget = LatLng(
        double.tryParse(order.store!.latitude!) ?? 0,
        double.tryParse(order.store!.longitude!) ?? 0,
      );
    } else {
      initialTarget = const LatLng(0, 0);
    }

    final String statusText = _getOrderStatusText(order);
    final bool isActiveOrder = ongoing;

    return Column(children: [
      // Map with bottom padding so the card can overlap
      SizedBox(
        height: 220,
        width: double.infinity,
        child: Stack(children: [
          // Google Map fills the entire area
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              markers: _markers,
              polylines: _polylines,
              padding: const EdgeInsets.only(bottom: 40),
              style: Get.isDarkMode
                  ? Get.find<ThemeController>().darkMap
                  : Get.find<ThemeController>().lightMap,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _mapLoading = false;
                _setMapMarkers(order);
              },
            ),
          ),
          if (_mapLoading)
            Container(
              color: const Color(0xFFE8E4D8),
              child: const Center(child: CircularProgressIndicator()),
            ),
          // Gradient fade at bottom so map blends into card
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.6),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),

      // Status card — slides up over the map with negative margin
      Transform.translate(
        offset: const Offset(0, -24),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // "ON TIME" label
            if (isActiveOrder)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.check_circle, size: 14, color: Color(0xFF1BA672)),
                  const SizedBox(width: 4),
                  Text(
                    'on_time'.tr.toUpperCase(),
                    style: robotoBold.copyWith(fontSize: 11, color: const Color(0xFF1BA672), letterSpacing: 0.5),
                  ),
                ]),
              ),

            // Status header with ETA badge
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    statusText,
                    style: robotoBold.copyWith(fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getOrderStatusSubtext(order),
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.grey.shade600),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  // Prep time hint — shown inline when no courier assigned yet
                  if (isActiveOrder && !parcel && liveEtaMinutes == null && prepMinutes != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.schedule_rounded, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '${'estimated_prep_time'.tr}: $prepMinutes ${'mins'.tr}',
                        style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ]),
                  ],
                ]),
              ),

              // Live ETA badge — only when courier is assigned and en route
              if (isActiveOrder && !parcel && liveEtaMinutes != null)
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(
                      '$liveEtaMinutes',
                      style: robotoBold.copyWith(fontSize: 22, color: Theme.of(context).secondaryHeaderColor, height: 1.1),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'mins'.tr,
                      style: robotoRegular.copyWith(fontSize: 11, color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.9)),
                    ),
                  ]),
                ),
            ]),

            // Delivery Instructions (compact, like Swiggy)
            if (order.deliveryInstruction != null && order.deliveryInstruction!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 14, color: Colors.black54),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'delivery_instruction'.tr,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.black87),
                  ),
                  Text(
                    order.deliveryInstruction!,
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.grey.shade600),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ])),
              ]),
            ],

            // Delivery Verification Code (OTP)
            if (order.otp != null && order.otp!.isNotEmpty && isActiveOrder) ...[
              const SizedBox(height: 14),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.verified_user_outlined, size: 16, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'delivery_verification_code'.tr,
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.black87),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_outline, size: 13, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 5),
                    Text(
                      order.otp!.split('').join(' '),
                      style: robotoBold.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: Theme.of(context).primaryColor,
                        letterSpacing: 2,
                      ),
                    ),
                  ]),
                ),
              ]),
            ],

            // Delivery address row
            if (order.deliveryAddress != null) ...[
              const SizedBox(height: 14),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${(order.deliveryAddress?.addressType ?? '').tr.isNotEmpty ? '${order.deliveryAddress!.addressType!.tr.capitalizeFirst}' : ''}'
                    '${order.deliveryAddress?.address != null ? " | ${order.deliveryAddress!.address}" : ""}',
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.grey.shade700),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],

            // Cancellation reason
            if (order.orderStatus == 'canceled' && order.cancellationReason != null) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('cancellation_note'.tr, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.red)),
                  const SizedBox(height: 2),
                  Text(
                    order.cancellationReason!,
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.grey.shade600),
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                  ),
                ])),
              ]),
            ],

            // Order ID & Payment
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 10),
            Row(children: [
              Text('${'order_id'.tr}: ', style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.grey)),
              Text('#${order.id}', style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.black87)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.paymentMethod == 'cash_on_delivery' ? 'cash_on_delivery'.tr
                      : order.paymentMethod == 'wallet' ? 'wallet_payment'.tr
                      : order.paymentMethod == 'partial_payment' ? 'partial_payment'.tr
                      : order.paymentMethod == 'offline_payment' ? 'offline_payment'.tr : 'digital_payment'.tr,
                  style: robotoMedium.copyWith(color: Theme.of(context).primaryColor, fontSize: Dimensions.fontSizeOverSmall),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }

  /// Get subtext for order status (like "Partner will be assigned when food is just about ready")
  String _getOrderStatusSubtext(OrderModel order) {
    switch (order.orderStatus) {
      case 'pending': return 'your_order_is_being_processed'.tr;
      case 'accepted': return 'your_order_has_been_accepted'.tr;
      case 'confirmed': return 'your_order_is_confirmed'.tr;
      case 'processing': return 'your_order_is_being_prepared'.tr;
      case 'handover': return 'your_order_is_ready_for_pickup'.tr;
      case 'picked_up': return 'your_order_is_on_the_way'.tr;
      case 'delivered': return 'your_order_has_been_delivered'.tr;
      case 'canceled': return 'your_order_has_been_canceled'.tr;
      case 'failed': return 'your_order_has_failed'.tr;
      default: return order.store?.name ?? '';
    }
  }

  // ─── Coupon Savings Banner ────────────────────────────────────────────
  Widget _buildCouponSavingsBanner(double couponDiscount) {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('  ', style: robotoRegular.copyWith(fontSize: 12, color: const Color(0xFF1BA672))),
          Text(
            '${'yay'.tr}! ${PriceConverter.convertPrice(couponDiscount)} ${'saved_with_coupon'.tr}',
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFF1BA672)),
          ),
          Text('  ', style: robotoRegular.copyWith(fontSize: 12, color: const Color(0xFF1BA672))),
        ]),
      ),
    );
  }

  // ─── Delivery Man Card ────────────────────────────────────────────────
  Widget _buildDeliveryManCard(OrderModel order, bool showChatPermission) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        ClipOval(child: CustomImage(
          image: '${order.deliveryMan!.imageFullUrl}',
          height: 40, width: 40, fit: BoxFit.cover,
        )),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '${order.deliveryMan!.fName} ${order.deliveryMan!.lName}',
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.black87),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'delivery_man'.tr,
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.grey),
          ),
        ])),
        if (order.orderStatus != 'delivered' && order.orderStatus != 'failed' && order.orderStatus != 'canceled' && order.orderStatus != 'refunded') ...[
          if (showChatPermission)
            _buildCircleAction(Icons.chat_bubble_outline, () async {
              _timer?.cancel();
              await Get.toNamed(RouteHelper.getChatRoute(
                notificationBody: NotificationBodyModel(deliverymanId: order.deliveryMan!.id, orderId: int.parse(order.id.toString())),
                user: User(id: order.deliveryMan!.id, fName: order.deliveryMan!.fName, lName: order.deliveryMan!.lName, imageFullUrl: order.deliveryMan!.imageFullUrl),
              ));
              _startTracking();
            }),
          const SizedBox(width: 8),
          _buildCircleAction(Icons.phone_outlined, () async {
            final url = 'tel:${order.deliveryMan!.phone}';
            // Use url_launcher via the same pattern as the original
          }),
        ],
      ]),
    );
  }

  Widget _buildCircleAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        ),
        child: Icon(icon, size: 18, color: Theme.of(context).primaryColor),
      ),
    );
  }

  // ─── Order Items Card ─────────────────────────────────────────────────
  Widget _buildOrderItemsCard(OrderModel order, OrderController orderController) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('item_info'.tr, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: Colors.black87)),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orderController.orderDetails!.length,
          separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 16),
          itemBuilder: (context, index) {
            final detail = orderController.orderDetails![index];
            return Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomImage(
                  image: '${detail.imageFullUrl}',
                  height: 48, width: 48, fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  detail.itemDetails?.name ?? '',
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.black87),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  PriceConverter.convertPrice(detail.price),
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
                  textDirection: TextDirection.ltr,
                ),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'x${detail.quantity}',
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.black54),
                ),
              ),
            ]);
          },
        ),
      ]),
    );
  }

  // ─── Desktop Layout (unchanged logic, wrapped) ────────────────────────
  Widget _desktopLayout(
    OrderController orderController, OrderModel order, bool ongoing, bool parcel,
    bool prescriptionOrder, bool showChatPermission, double deliveryCharge,
    double itemsPrice, double discount, double couponDiscount, double tax,
    double addOns, double dmTips, bool taxIncluded, double subTotal, double total,
    double extraPackagingCharge, double referrerBonusAmount,
  ) {
    return Column(children: [
      Container(
        height: 64,
        color: Theme.of(context).primaryColor.withValues(alpha: 0.10),
        child: Center(child: Text('order_details'.tr, style: robotoMedium)),
      ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 6,
          child: OrderInfoWidget(
            order: order, ongoing: ongoing, parcel: parcel, prescriptionOrder: prescriptionOrder,
            timerCancel: () => _timer?.cancel(), startApiCall: () => _startTracking(),
            orderController: orderController, showChatPermission: showChatPermission,
          ),
        ),
        const SizedBox(width: Dimensions.paddingSizeLarge),
        Expanded(
          flex: 4,
          child: OrderCalculationWidget(
            orderController: orderController, order: order, ongoing: ongoing, parcel: parcel,
            prescriptionOrder: prescriptionOrder, deliveryCharge: deliveryCharge, itemsPrice: itemsPrice,
            discount: discount, couponDiscount: couponDiscount, tax: tax, addOns: addOns, dmTips: dmTips,
            taxIncluded: taxIncluded, subTotal: subTotal, total: total,
            bottomView: _bottomView(orderController, order, parcel, total), extraPackagingAmount: extraPackagingCharge,
            referrerBonusAmount: referrerBonusAmount, timerCancel: () => _timer?.cancel(), startApiCall: () => _startTracking(),
          ),
        ),
      ]),
    ]);
  }

  void openDialog(BuildContext context, String imageUrl) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusLarge)),
        child: Stack(children: [

          ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            child: PhotoView(
              tightMode: true,
              imageProvider: NetworkImage(imageUrl),
              heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
            ),
          ),

          Positioned(top: 0, right: 0, child: IconButton(
            splashRadius: 5,
            onPressed: () => Get.back(),
            icon: const Icon(Icons.cancel, color: Colors.red),
          )),

        ]),
      );
    },
  );

  Widget _bottomView(OrderController orderController, OrderModel order, bool parcel, double totalPrice) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        !orderController.showCancelled ? Center(
          child: SizedBox(
            width: Dimensions.webMaxWidth,
            child: Column(children: [
              ((order.orderStatus == 'pending' && order.paymentMethod != 'digital_payment') || order.orderStatus == 'accepted' || order.orderStatus == 'confirmed'
              || order.orderStatus == 'processing' || order.orderStatus == 'handover'|| order.orderStatus == 'picked_up') ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      _timer?.cancel();
                      await Get.toNamed(RouteHelper.getOrderTrackingRoute(order.id, widget.contactNumber))?.whenComplete(() {
                        _startTracking();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      parcel ? 'track_delivery'.tr : 'track_order'.tr,
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: Colors.white),
                    ),
                  ),
                ),
              ) : const SizedBox(),

              (order.orderStatus == 'pending' && order.paymentStatus == 'unpaid' && order.paymentMethod == 'digital_payment' && _isCashOnDeliveryActive!) ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: SizedBox(
                  width: double.infinity, height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Get.dialog(ConfirmationDialog(
                        icon: Images.warning, description: 'are_you_sure_to_switch'.tr,
                        onYesPressed: () {
                          if((((_maxCodOrderAmount != null && totalPrice < _maxCodOrderAmount!) || _maxCodOrderAmount == null || _maxCodOrderAmount == 0) && !parcel) || parcel){
                            orderController.switchToCOD(order.id.toString());
                          }else{
                            if(Get.isDialogOpen!) {
                              Get.back();
                            }
                            showCustomSnackBar('${'you_cant_order_more_then'.tr} ${PriceConverter.convertPrice(_maxCodOrderAmount)} ${'in_cash_on_delivery'.tr}');
                          }
                        }
                      ));
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('switch_to_cod'.tr, style: robotoMedium.copyWith(color: Theme.of(context).primaryColor)),
                  ),
                ),
              ) : const SizedBox(),

              (order.orderStatus == 'pending' && (Get.find<AuthController>().isLoggedIn() ? true : (orderController.orderDetails != null && orderController.orderDetails!.isNotEmpty  && orderController.orderDetails?[0].isGuest == 1 ? true : false))) ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SizedBox(
                  width: double.infinity, height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      orderController.setOrderCancelReason('');
                      Get.dialog(CancellationDialogueWidget(orderId: order.id, contactNumber: widget.contactNumber));
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      parcel ? 'cancel_delivery'.tr : 'cancel_order'.tr,
                      style: robotoMedium.copyWith(color: Colors.grey.shade600),
                    ),
                  ),
                ),
              ) : const SizedBox(),

            ]),
          ),
        ) : Center(
          child: Container(
            width: Dimensions.webMaxWidth,
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: Colors.red.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('order_cancelled'.tr, style: robotoMedium.copyWith(color: Colors.red.shade400)),
          ),
        ),

        !AuthHelper.isGuestLoggedIn() && (order.orderStatus == 'delivered' && (parcel ? order.deliveryMan != null : (orderController.orderDetails!.isNotEmpty && orderController.orderDetails![0].itemCampaignId == null))) ? Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                List<OrderDetailsModel> orderDetailsList = [];
                List<int?> orderDetailsIdList = [];
                for (var orderDetail in orderController.orderDetails!) {
                  if(!orderDetailsIdList.contains(orderDetail.itemDetails!.id)) {
                    orderDetailsList.add(orderDetail);
                    orderDetailsIdList.add(orderDetail.itemDetails!.id);
                  }
                }
                Get.toNamed(RouteHelper.getReviewRoute(), arguments: RateReviewScreen(
                  orderDetailsList: orderDetailsList, deliveryMan: order.deliveryMan, orderID: order.id,
                ));
              },
              icon: const Icon(Icons.star_outline, size: 20),
              label: Text('review'.tr, style: robotoMedium),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ) : const SizedBox(),

        AuthHelper.isLoggedIn() && !parcel && (order.orderStatus == 'delivered' || order.orderStatus == 'canceled' || order.orderStatus == 'failed') ? Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: orderController.isReordering ? null : () async {
                final result = await orderController.reorder(order.id!);
                if (result != null) {
                  final int addedCount = result['added_count'] ?? 0;
                  final int unavailableCount = result['unavailable_count'] ?? 0;
                  String message = result['message'] ?? '';
                  if (unavailableCount > 0) {
                    final unavailable = result['unavailable'] as List? ?? [];
                    final names = unavailable.map((u) => u['item_name'] ?? '').where((n) => n.isNotEmpty).join(', ');
                    if (names.isNotEmpty) {
                      message += '\n${'unavailable'.tr}: $names';
                    }
                  }
                  showCustomSnackBar(message, isError: addedCount == 0);
                  if (addedCount > 0) {
                    Get.find<CartController>().getCartDataOnline();
                  }
                } else {
                  showCustomSnackBar('failed_to_reorder'.tr);
                }
              },
              icon: orderController.isReordering
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.replay_rounded, size: 20),
              label: Text('reorder'.tr, style: robotoMedium),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ) : const SizedBox(),

        (order.orderStatus == 'failed' && Get.find<SplashController>().configModel!.cashOnDelivery!) ? Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: OutlinedButton(
              onPressed: () {
                Get.dialog(ConfirmationDialog(
                    icon: Images.warning, description: 'are_you_sure_to_switch'.tr,
                    onYesPressed: () {
                      orderController.switchToCOD(order.id.toString()).then((isSuccess) {
                        Get.back();
                        if(isSuccess) {
                          Get.back();
                        }
                      });
                    }
                ));
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).primaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('switch_to_cash_on_delivery'.tr, style: robotoMedium.copyWith(color: Theme.of(context).primaryColor)),
            ),
          ),
        ) : const SizedBox(),

        const SizedBox(height: 4),
      ]),
    );
  }
}
