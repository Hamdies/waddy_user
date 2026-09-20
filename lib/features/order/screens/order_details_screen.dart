import 'dart:async';
import 'package:waddy_app/util/swallow.dart';
import 'dart:collection';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/eta_calculator.dart';
import 'package:waddy_app/helper/marker_animator.dart';
import 'package:waddy_app/helper/marker_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_dialog.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/checkout/widgets/offline_success_dialog.dart';
// order_steps_card, order_map_section, delivery_man_card removed from mobile layout
import 'package:waddy_app/features/order/widgets/zomato/zomato_order_info_card.dart';
import 'package:waddy_app/features/order/widgets/zomato/zomato_delivery_partner_card.dart';
import 'package:waddy_app/theme/light_theme.dart';
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Timer? _timer;
  double? _maxCodOrderAmount;
  bool? _isCashOnDeliveryActive = false;
  final ScrollController scrollController = ScrollController();
  GoogleMapController? _mapController;
  Set<Marker> _markers = HashSet<Marker>();
  Set<Polyline> _polylines = HashSet<Polyline>();

  final MarkerAnimator _markerAnimator = MarkerAnimator();
  ETAResult? _currentETA;

  // Tracking freshness
  DateTime? _lastUpdateTime;
  bool _isLive = false;

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
    final trackedOrder = Get.find<OrderController>().trackModel;
    if (trackedOrder != null) {
      await _setMapMarkers(trackedOrder);
    }
    Get.find<OrderController>().timerTrackOrder(
      widget.orderId.toString(),
      contactNumber: widget.contactNumber,
    );
    Get.find<OrderController>().getOrderDetails(widget.orderId.toString());

    _startPolling();
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
      borderColor: WaddyColors.amber,
      borderWidth: 2,
      fallbackAsset: Images.deliveryManMarker,
      fallbackIcon: Icons.delivery_dining,
      fallbackIconColor: WaddyColors.amber,
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

        setState(() => _lastUpdateTime = DateTime.now());

        final orderStatus = OrderStatus.fromString(order.orderStatus);
        if (orderStatus != null && orderStatus.isTerminal) {
          _timer?.cancel();
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
          borderColor: WaddyColors.amber,
          borderWidth: 2.5,
          fallbackAsset: Images.deliveryManMarker,
          fallbackIcon: Icons.delivery_dining,
          fallbackIconColor: WaddyColors.amber,
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
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
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
      } catch (e, s) {
        swallow('parse store delivery time', e, s);
      }
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
          borderColor: WaddyColors.mintDark,
          borderWidth: 2,
          fallbackAsset: Images.userMarker,
          fallbackIcon: Icons.home,
          fallbackIconColor: WaddyColors.mintDark,
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
          borderColor: WaddyColors.amber,
          borderWidth: 2.5,
          fallbackAsset: Images.deliveryManMarker,
          fallbackIcon: Icons.delivery_dining,
          fallbackIconColor: WaddyColors.amber,
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
        backgroundColor: const Color(0xFFF2F4F3),
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
                return const _OrderDetailsSkeleton();
              }

              final int? liveEtaMinutes = _getLiveEtaMinutes(order);
              final int? prepMinutes = _getPrepMinutes(order);

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: _buildMobileLayout(
                        context,
                        order,
                        orderController,
                        ongoing,
                        showChatPermission,
                        liveEtaMinutes,
                        prepMinutes,
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

  // ─── Mobile Layout (two-mode) ──────────────────────────────────────────
  //
  // Mode 1  pending → processing  : teal hero band + clock-time window
  // Mode 2  handover / pickedUp   : full-height map replaces the hero
  // Mode 3  delivered / terminal  : celebration / cancelled state
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(
    BuildContext context,
    OrderModel order,
    OrderController orderController,
    bool ongoing,
    bool showChatPermission,
    int? liveEtaMinutes,
    int? prepMinutes,
  ) {
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
    final bool enRoute =
        status == OrderStatus.handover || status == OrderStatus.pickedUp;

    // OTP: only show when rider is assigned and en-route (not during pending/processing)
    final bool showOtp =
        enRoute && ongoing && order.otp != null && order.otp!.isNotEmpty;

    return FadeTransition(
      opacity: _screenFade,
      child: SlideTransition(
        position: _screenSlide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App bar ─────────────────────────────────────────────────
            _AppBar(
              title: order.store?.name ?? 'order_details'.tr,
              onBack: _handleBack,
              orderId: widget.orderId,
            ),

            // ── Hero: map (en-route) OR gradient band (pre-pickup) ─────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder:
                  (child, anim) => FadeTransition(opacity: anim, child: child),
              child:
                  enRoute
                      ? _MapHero(
                        key: const ValueKey('map_hero'),
                        markers: _markers,
                        polylines: _polylines,
                        eta: _currentETA,
                        onMapCreated: (ctrl) {
                          _mapController = ctrl;
                          final t = Get.find<OrderController>().trackModel;
                          if (t != null) _setMapMarkers(t);
                        },
                        initialFocus: _getMapFocus(order),
                      )
                      : _PrePickupHero(
                        key: const ValueKey('pre_hero'),
                        status: status,
                        liveEtaMinutes: liveEtaMinutes,
                        prepMinutes: prepMinutes,
                        estimatedDeliveryAt: order.estimatedDeliveryAt,
                        storeName: order.store?.name,
                        lastUpdateTime: _lastUpdateTime,
                        isLive: _isLive,
                      ),
            ),

            // ── Card sheet — warm gray surface rolls over the dark hero ──
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F4F3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (enRoute) ...[
                    ZomatoDeliveryPartnerCard(
                      order: order,
                      showChatPermission: showChatPermission,
                      onTimerCancel: () => _timer?.cancel(),
                      onStartTracking: _startPolling,
                    ),
                    const SizedBox(height: 12),
                    ZomatoOrderInfoCard(
                      order: order,
                      orderController: orderController,
                      ongoing: ongoing,
                      showOtpOverride: showOtp,
                    ),
                  ] else ...[
                    ZomatoOrderInfoCard(
                      order: order,
                      orderController: orderController,
                      ongoing: ongoing,
                      showOtpOverride: false,
                    ),
                    const SizedBox(height: 12),
                    ZomatoDeliveryPartnerCard(
                      order: order,
                      showChatPermission: showChatPermission,
                      onTimerCancel: () => _timer?.cancel(),
                      onStartTracking: _startPolling,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LatLng? _getMapFocus(OrderModel order) {
    if (order.deliveryMan?.lat != null && order.deliveryMan?.lng != null) {
      final lat = double.tryParse(order.deliveryMan!.lat!);
      final lng = double.tryParse(order.deliveryMan!.lng!);
      if (lat != null && lng != null && lat != 0 && lng != 0) {
        return LatLng(lat, lng);
      }
    }
    if (order.store?.latitude != null && order.store?.longitude != null) {
      final lat = double.tryParse(order.store!.latitude!);
      final lng = double.tryParse(order.store!.longitude!);
      if (lat != null && lng != null && lat != 0 && lng != 0) {
        return LatLng(lat, lng);
      }
    }
    return null;
  }

  // ─── Desktop Layout ───────────────────────────────────────────────────

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

// ─── App Bar ──────────────────────────────────────────────────────────────────
// Teal background flows seamlessly into the pre-pickup hero below.
// Back button: white icon in a translucent rounded container.
// Two-line title: store name + "Order #XXXX" for context.
class _AppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final int? orderId;

  const _AppBar({required this.title, required this.onBack, this.orderId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WaddyColors.primary,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(
        children: [
          // ── Back button ─────────────────────────────────────────────
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            child: InkWell(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              splashColor: Colors.white.withValues(alpha: 0.14),
              highlightColor: Colors.white.withValues(alpha: 0.08),
              onTap: onBack,
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── Title group ──────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: Colors.white,
                    letterSpacing: -0.2,
                    height: 1.2,
                  ),
                ),
                if (orderId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Order #$orderId',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pre-Pickup Hero ──────────────────────────────────────────────────────────
// Deep teal command slab. Status is communicated ONCE here — not repeated in
// the order card below. ETA is the lead element. Liveness badge confirms the
// data is live or shows when it was last refreshed.
class _PrePickupHero extends StatelessWidget {
  final OrderStatus? status;
  final int? liveEtaMinutes;
  final int? prepMinutes;
  final String? estimatedDeliveryAt;
  final String? storeName;
  final DateTime? lastUpdateTime;
  final bool isLive;

  const _PrePickupHero({
    super.key,
    required this.status,
    required this.liveEtaMinutes,
    required this.prepMinutes,
    required this.estimatedDeliveryAt,
    this.storeName,
    this.lastUpdateTime,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTerminal = status?.isTerminal ?? false;
    final bool isCancelled =
        status == OrderStatus.canceled || status == OrderStatus.failed;
    final bool isDelivered = status == OrderStatus.delivered;
    final String? clockWindow = _clockWindow();
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;

    // Hero background: teal for active, deep green for delivered, charcoal for cancelled
    final Color heroBg =
        isCancelled
            ? const Color(0xFF2A1C1C)
            : isDelivered
            ? const Color(0xFF0A4A30)
            : WaddyColors.primary;

    return Container(
      width: double.infinity,
      color: heroBg,
      child: Stack(
        children: [
          // ── Decorative ring — clips to hero bounds, top-right corner
          Positioned(
            right: -44,
            top: -44,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 32,
                ),
              ),
            ),
          ),
          // ── Content ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: context label + liveness ─────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_statusIcon(), size: 13, color: _statusIconColor()),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _contextLabel(),
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (!isTerminal) ...[
                      const SizedBox(width: 12),
                      _LivenessBadge(
                        lastUpdateTime: lastUpdateTime,
                        isLive: isLive,
                      ),
                    ],
                  ],
                ),
                // ── ETA / clock window ─────────────────────────────
                if (!isTerminal) ...[
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: reduceMotion ? 0 : 400),
                    transitionBuilder: (child, anim) {
                      if (reduceMotion) return child;
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.06),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutQuart,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child:
                        clockWindow != null
                            ? _ClockWindowDisplay(
                              key: ValueKey(clockWindow),
                              window: clockWindow,
                              color: Colors.white,
                            )
                            : _EtaShimmerDark(key: const ValueKey('shimmer')),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estimated arrival window',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.48),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                ] else
                  const SizedBox(height: 18),
                // ── Status pill ────────────────────────────────────
                _StatusPill(status: status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon() {
    switch (status) {
      case OrderStatus.pending:
        return Icons.hourglass_top_rounded;
      case OrderStatus.accepted:
      case OrderStatus.confirmed:
        return Icons.check_circle_rounded;
      case OrderStatus.processing:
        return Icons.restaurant_rounded;
      case OrderStatus.delivered:
        return Icons.celebration_rounded;
      case OrderStatus.canceled:
      case OrderStatus.failed:
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _statusIconColor() {
    switch (status) {
      case OrderStatus.pending:
        return WaddyColors.amber;
      case OrderStatus.accepted:
      case OrderStatus.confirmed:
        return WaddyColors.mint;
      case OrderStatus.processing:
        return WaddyColors.coral;
      case OrderStatus.delivered:
        return WaddyColors.mint;
      case OrderStatus.canceled:
      case OrderStatus.failed:
        return const Color(0xFFFF8A8A);
      default:
        return Colors.white70;
    }
  }

  String? _clockWindow() {
    if (estimatedDeliveryAt != null && estimatedDeliveryAt!.isNotEmpty) {
      try {
        DateTime? eta = DateTime.tryParse(estimatedDeliveryAt!);
        if (eta == null) {
          final parts = estimatedDeliveryAt!.split(' ');
          if (parts.length >= 2) {
            eta = DateTime.tryParse('${parts[0]}T${parts[1]}');
          }
        }
        if (eta != null) {
          final lo = eta.subtract(const Duration(minutes: 5));
          final hi = eta.add(const Duration(minutes: 5));
          return '${ETAResult.fmtTime(lo)} \u2013 ${ETAResult.fmtTime(hi)}';
        }
      } catch (e, s) {
        swallow('format ETA window', e, s);
      }
    }

    final minutes = liveEtaMinutes ?? prepMinutes;
    if (minutes == null || minutes <= 0) return null;

    final result = ETAResult(
      minMinutes: minutes,
      maxMinutes: minutes + (minutes * 0.2).round().clamp(2, 10),
      speedUsed: 0,
    );
    return result.clockWindow;
  }

  String _contextLabel() {
    final name = storeName ?? 'the restaurant';
    switch (status) {
      case OrderStatus.pending:
        return 'Sent to $name \u2014 waiting for confirmation';
      case OrderStatus.accepted:
      case OrderStatus.confirmed:
        return '$name confirmed your order!';
      case OrderStatus.processing:
        return '$name is preparing your meal';
      case OrderStatus.delivered:
        return 'Delivered \u2014 enjoy every bite!';
      case OrderStatus.canceled:
      case OrderStatus.failed:
        return 'Order cancelled';
      default:
        return 'Estimated arrival';
    }
  }
}

// ─── Clock Window Display ──────────────────────────────────────────────────────
class _ClockWindowDisplay extends StatelessWidget {
  final String window;
  final Color? color;
  const _ClockWindowDisplay({super.key, required this.window, this.color});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        window,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 44,
          color: color ?? WaddyColors.primary,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
          height: 1.0,
        ),
      ),
    );
  }
}

// ─── Status Pill ──────────────────────────────────────────────────────────────
// Minimal translucent badge on the dark hero. No shadow, no fill — keeps the
// hero clean and lets the ETA be the dominant element.
class _StatusPill extends StatelessWidget {
  final OrderStatus? status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool isError =
        status == OrderStatus.canceled || status == OrderStatus.failed;
    final bool isSuccess = status == OrderStatus.delivered;
    final bool isActive = !isError && !isSuccess;

    final Color borderColor =
        isError
            ? const Color(0xFFFF8A8A).withValues(alpha: 0.5)
            : isSuccess
            ? WaddyColors.mint.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.22);

    final Color textColor =
        isError
            ? const Color(0xFFFF8A8A)
            : isSuccess
            ? WaddyColors.mint
            : Colors.white.withValues(alpha: 0.9);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeMedium,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation(
                    Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          Text(
            _caption(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  String _caption() {
    switch (status) {
      case OrderStatus.pending:
        return 'Waiting for restaurant';
      case OrderStatus.accepted:
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Being prepared';
      case OrderStatus.handover:
      case OrderStatus.pickedUp:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered!';
      case OrderStatus.canceled:
      case OrderStatus.failed:
        return 'Cancelled';
      default:
        return 'Processing';
    }
  }
}

// ─── Map Hero ─────────────────────────────────────────────────────────────────
// Full-height embedded map shown when rider is en-route (handover / pickedUp).
// Floats the estimated arrival time as a chip over the map.
class _MapHero extends StatelessWidget {
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final ETAResult? eta;
  final void Function(GoogleMapController) onMapCreated;
  final LatLng? initialFocus;

  const _MapHero({
    super.key,
    required this.markers,
    required this.polylines,
    required this.eta,
    required this.onMapCreated,
    required this.initialFocus,
  });

  @override
  Widget build(BuildContext context) {
    final LatLng focus = initialFocus ?? const LatLng(0, 0);
    final String? arrivalText =
        eta != null && !eta!.isArriving
            ? 'Arrives ~${ETAResult.fmtTime(DateTime.now().add(Duration(minutes: eta!.minMinutes)))}'
            : eta?.isArriving == true
            ? 'Arriving now!'
            : null;

    // Responsive map height: taller on tall devices
    final screenH = MediaQuery.of(context).size.height;
    final mapHeight = (screenH * 0.32).clamp(220.0, 340.0);

    return Stack(
      children: [
        // Map
        SizedBox(
          height: mapHeight,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: focus, zoom: 15.0),
            markers: markers,
            polylines: polylines,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: onMapCreated,
          ),
        ),

        // Arrival time badge — energetic coral gradient
        if (arrivalText != null)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeMedium,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [WaddyColors.primary, Color(0xFF1D706A)],
                ),
                borderRadius: BorderRadius.circular(
                  Dimensions.radiusExtraLarge,
                ),
                boxShadow: [
                  BoxShadow(
                    color: WaddyColors.primary.withValues(alpha: 0.40),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.two_wheeler_rounded,
                    color: WaddyColors.mint,
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    arrivalText,
                    style: waddyLabel.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Clock-window badge — floated bottom-right
        if (eta != null && !eta!.isArriving)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeMedium,
                vertical: Dimensions.paddingSizeSmall,
              ),
              decoration: BoxDecoration(
                color: WaddyColors.surface,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                border: Border.all(color: WaddyColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: WaddyColors.shadowTeal.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                eta!.clockWindow,
                style: waddyLabel.copyWith(
                  color: WaddyColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Liveness Badge ───────────────────────────────────────────────────────────
// Shows "● Live" when SSE is active, "Updated X ago" when on polling fallback.
// Displayed in the hero footer so the user always knows data freshness.
class _LivenessBadge extends StatefulWidget {
  final DateTime? lastUpdateTime;
  final bool isLive;

  const _LivenessBadge({this.lastUpdateTime, this.isLive = false});

  @override
  State<_LivenessBadge> createState() => _LivenessBadgeState();
}

class _LivenessBadgeState extends State<_LivenessBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotCtrl;
  late final Animation<double> _dotScale;
  Timer? _refreshTimer;
  String _label = '';

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _dotScale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut));
    _updateLabel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _updateLabel());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion && widget.isLive && !_dotCtrl.isAnimating) {
      _dotCtrl.repeat(reverse: true);
    } else if (reduceMotion || !widget.isLive) {
      _dotCtrl.stop();
      _dotCtrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_LivenessBadge old) {
    super.didUpdateWidget(old);
    _updateLabel();
    if (widget.isLive && !_dotCtrl.isAnimating) {
      _dotCtrl.repeat(reverse: true);
    } else if (!widget.isLive) {
      _dotCtrl.stop();
      _dotCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _updateLabel() {
    if (widget.isLive) {
      _label = 'Live';
      return;
    }
    final t = widget.lastUpdateTime;
    if (t == null) {
      _label = 'Updating…';
      return;
    }
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) {
      _label = 'Just updated';
    } else if (diff.inMinutes < 60) {
      _label = 'Updated ${diff.inMinutes}m ago';
    } else {
      _label = 'Updated ${diff.inHours}h ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color dotColor = widget.isLive ? WaddyColors.mint : WaddyColors.amber;
    final Color textColor =
        widget.isLive
            ? WaddyColors.mint.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.55);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _dotScale,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          _label,
          style: TextStyle(
            fontSize: 11.5,
            color: textColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ─── ETA Shimmer (dark variant) ───────────────────────────────────────────────
// Light shimmer bars on the dark teal hero while ETA resolves.
class _EtaShimmerDark extends StatefulWidget {
  const _EtaShimmerDark({super.key});

  @override
  State<_EtaShimmerDark> createState() => _EtaShimmerDarkState();
}

class _EtaShimmerDarkState extends State<_EtaShimmerDark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = Tween<double>(
      begin: 0.15,
      end: 0.35,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _ctrl.stop();
      _ctrl.value = 0.5;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 36,
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Order Details Skeleton ───────────────────────────────────────────────────
// Shown instead of CircularProgressIndicator while data loads.
// Mirrors the real screen structure (hero + two cards) for a stable layout.
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

  Widget _block({double height = 16, double? width, double radius = 8}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: WaddyColors.divider,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App bar skeleton — matches the redesigned teal header
          Container(
            color: WaddyColors.primary,
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 15,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 11,
                      width: 78,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusExtraSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Hero skeleton — full teal to match real hero
          Container(
            height: 140,
            color: WaddyColors.primary,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 44,
                  width: 232,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  ),
                ),
                const Spacer(),
                Container(
                  height: 28,
                  width: 130,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  ),
                ),
              ],
            ),
          ),
          // Card sheet skeleton — gray container with top rounding
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F4F3),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            child: Column(
              children: [
                // Order card skeleton
                Container(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  decoration: BoxDecoration(
                    color: WaddyColors.surface,
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusExtraLarge,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: WaddyColors.divider,
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusLarge,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _block(height: 15, width: 100),
                              const SizedBox(height: 6),
                              _block(height: 12, width: 160),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _block(height: 8, width: double.infinity),
                      const SizedBox(height: 10),
                      _block(height: 8, width: 200),
                      const SizedBox(height: 10),
                      _block(height: 8, width: 240),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Rider card skeleton
                Container(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  decoration: BoxDecoration(
                    color: WaddyColors.surface,
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusExtraLarge,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: WaddyColors.divider,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _block(height: 15, width: 120),
                          const SizedBox(height: 6),
                          _block(height: 12, width: 180),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
        builder:
            (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ─── ETA Shimmer placeholder ───────────────────────────────────────────────
// Shows animated loading bars while ETA resolves instead of bare "--"
// Respects reduced-motion accessibility preference.
class _EtaShimmer extends StatefulWidget {
  const _EtaShimmer({super.key});

  @override
  State<_EtaShimmer> createState() => _EtaShimmerState();
}

class _EtaShimmerState extends State<_EtaShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _ctrl.stop();
      _ctrl.value = 0.5;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 80,
        height: 68,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 16,
              decoration: BoxDecoration(
                color: WaddyColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 12,
              decoration: BoxDecoration(
                color: WaddyColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
            ),
          ],
        ),
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
    );

    _opacity = Tween<double>(
      begin: 0.55,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
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
