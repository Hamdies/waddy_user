import 'dart:async';
import 'dart:collection';

import 'package:geolocator/geolocator.dart';
import 'package:sixam_mart/common/controllers/theme_controller.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/footer_view.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/location/widgets/permission_dialog_widget.dart';
import 'package:sixam_mart/features/order/widgets/delivery_instruction_tracking_widget.dart';
import 'package:sixam_mart/features/order/widgets/modern_tracking_card_widget.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/chat/domain/models/conversation_model.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/order/domain/services/order_tracking_stream_service.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/store/domain/models/store_model.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/eta_calculator.dart';
import 'package:sixam_mart/helper/marker_animator.dart';
import 'package:sixam_mart/helper/marker_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/common/widgets/custom_app_bar.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/features/order/widgets/track_details_view_widget.dart';
import 'package:sixam_mart/features/order/widgets/tracking_stepper_widget.dart';
import 'package:sixam_mart/helper/live_activity_helper.dart';
import 'package:sixam_mart/services/live_activity_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String? orderID;
  final String? contactNumber;
  const OrderTrackingScreen({
    super.key,
    required this.orderID,
    this.contactNumber,
  });

  @override
  OrderTrackingScreenState createState() => OrderTrackingScreenState();
}

class OrderTrackingScreenState extends State<OrderTrackingScreen>
    with WidgetsBindingObserver {
  GoogleMapController? _controller;
  bool _isLoading = true;
  Set<Marker> _markers = HashSet<Marker>();
  Set<Polyline> _polylines = HashSet<Polyline>();
  Timer? _timer;
  bool showChatPermission = true;
  bool isHovered = false;

  // SSE and animation support
  OrderTrackingStreamService? _streamService;
  StreamSubscription<TrackingStreamData>? _streamSubscription;
  final MarkerAnimator _markerAnimator = MarkerAnimator();
  bool _useSSE = true; // Start with SSE, fallback to polling if fails
  ETAResult? _currentETA;

  void _loadData() async {
    await Get.find<LocationController>().getCurrentLocation(
      true,
      notify: false,
      defaultLatLng: LatLng(
        double.parse(AddressHelper.getUserAddressFromSharedPref()!.latitude!),
        double.parse(AddressHelper.getUserAddressFromSharedPref()!.longitude!),
      ),
    );
    await Get.find<OrderController>().trackOrder(
      widget.orderID,
      null,
      true,
      contactNumber: widget.contactNumber,
    );

    // Try SSE first, fallback to polling if fails
    if (_useSSE) {
      _startSSETracking();
    } else {
      _timerTrackOrder();
    }
  }

  /// Start SSE-based real-time tracking
  void _startSSETracking() {
    final status = Get.find<OrderController>().trackModel?.orderStatus;
    if (status == 'delivered' || status == 'failed' || status == 'canceled') {
      return;
    }

    _streamService?.disconnect();
    _streamService = OrderTrackingStreamService();

    _streamSubscription = _streamService!
        .connect(
          orderId: widget.orderID!,
          token: Get.find<AuthController>().getUserToken(),
          contactNumber: widget.contactNumber,
          guestId: null,
        )
        .listen(
          (data) => _handleSSEUpdate(data),
          onError: (error) {
            debugPrint('SSE Error: $error - Falling back to polling');
            _fallbackToPolling();
          },
        );
  }

  /// Handle incoming SSE update
  void _handleSSEUpdate(TrackingStreamData data) {
    final orderController = Get.find<OrderController>();

    // Update order status in controller
    if (orderController.trackModel != null) {
      orderController.trackModel!.orderStatus = data.status;
      orderController.trackModel!.subStatus = data.subStatus;

      // Update estimated delivery time if recalculated by backend
      if (data.estimatedDeliveryAt != null) {
        orderController.trackModel!.estimatedDeliveryAt = data.estimatedDeliveryAt;
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

    // Animate marker to new position
    if (data.deliveryMan != null) {
      final newPosition = LatLng(data.deliveryMan!.lat, data.deliveryMan!.lng);

      _markerAnimator.animateTo(
        target: newPosition,
        onUpdate: (position, rotation) {
          _updateDeliveryManMarker(position, rotation);
        },
      );

      // Calculate ETA
      _updateETA(data.deliveryMan!.lat, data.deliveryMan!.lng);
    }

    // Update Live Activity
    final trackModel = orderController.trackModel;
    if (trackModel != null) {
      final orderId = trackModel.id ?? int.tryParse(widget.orderID ?? '') ?? 0;
      if (LiveActivityHelper.isTerminalStatus(data.status)) {
        LiveActivityService.endActivity(orderId);
      } else {
        LiveActivityService.updateActivity(
          orderId: orderId,
          status: data.status,
          subStatus: data.subStatus,
          eta: trackModel.estimatedDelivery,
          deliveryManName: trackModel.deliveryMan != null
              ? '${trackModel.deliveryMan!.fName ?? ''} ${trackModel.deliveryMan!.lName ?? ''}'.trim()
              : null,
          storeName: trackModel.store?.name,
          orderType: trackModel.orderType ?? 'delivery',
        );
      }
    }

    // Check if order completed
    if (data.status == 'delivered' ||
        data.status == 'failed' ||
        data.status == 'canceled') {
      _streamService?.disconnect();
    }
  }

  /// Update ETA based on delivery man position
  void _updateETA(double driverLat, double driverLng) {
    final destination = Get.find<OrderController>().trackModel?.deliveryAddress;
    if (destination?.latitude == null || destination?.longitude == null) return;

    final distance = ETACalculator.calculateDistanceKm(
      driverLat,
      driverLng,
      double.parse(destination!.latitude!),
      double.parse(destination.longitude!),
    );

    setState(() {
      _currentETA = ETACalculator.calculate(distance);
    });
  }

  /// Update delivery man marker position with animation
  void _updateDeliveryManMarker(LatLng position, double rotation) async {
    final track = Get.find<OrderController>().trackModel;
    if (track == null) return;

    BitmapDescriptor deliveryManIcon =
        await MarkerHelper.convertAssetToBitmapDescriptor(
          width: 30,
          imagePath: Images.deliveryManMarker,
        );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'delivery_boy');
      _markers.add(
        Marker(
          markerId: const MarkerId('delivery_boy'),
          position: position,
          infoWindow: InfoWindow(
            title: 'delivery_man'.tr,
            snippet: _currentETA?.displayText ?? '',
          ),
          rotation: rotation,
          icon: deliveryManIcon,
        ),
      );
    });

    // Update route polyline with new driver position
    _updateRoutePolyline(position);
  }

  /// Update the route polyline from store through driver to destination
  void _updateRoutePolyline(LatLng driverPosition) {
    final track = Get.find<OrderController>().trackModel;
    if (track == null) return;

    final List<LatLng> routePoints = [];

    // Add store position
    if (track.store?.latitude != null && track.store?.longitude != null) {
      routePoints.add(
        LatLng(
          double.parse(track.store!.latitude!),
          double.parse(track.store!.longitude!),
        ),
      );
    }

    // Add driver position
    routePoints.add(driverPosition);

    // Add destination position
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

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          points: routePoints,
          color: Theme.of(context).primaryColor,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    });
  }

  /// Initialize route polyline during marker setup
  void _initRoutePolyline(
    Store? store,
    DeliveryMan? deliveryMan,
    AddressModel? addressModel,
  ) {
    final List<LatLng> routePoints = [];

    // Add store position
    if (store?.latitude != null && store?.longitude != null) {
      routePoints.add(
        LatLng(double.parse(store!.latitude!), double.parse(store.longitude!)),
      );
    }

    // Add driver position if assigned
    if (deliveryMan?.lat != null && deliveryMan?.lng != null) {
      routePoints.add(
        LatLng(double.parse(deliveryMan!.lat!), double.parse(deliveryMan.lng!)),
      );
    }

    // Add destination position
    if (addressModel?.latitude != null && addressModel?.longitude != null) {
      routePoints.add(
        LatLng(
          double.parse(addressModel!.latitude!),
          double.parse(addressModel.longitude!),
        ),
      );
    }

    if (routePoints.length < 2) return;

    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('delivery_route'),
        points: routePoints,
        color: Theme.of(context).primaryColor,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );
  }

  /// Fallback to polling-based tracking
  void _fallbackToPolling() {
    _useSSE = false;
    _streamService?.disconnect();
    _streamSubscription?.cancel();
    _timerTrackOrder();
  }

  _timerTrackOrder() {
    if (Get.find<OrderController>().trackModel?.orderStatus != 'delivered' &&
        Get.find<OrderController>().trackModel?.orderStatus != 'failed' &&
        Get.find<OrderController>().trackModel?.orderStatus != 'canceled') {
      Get.find<OrderController>().timerTrackOrder(
        widget.orderID.toString(),
        contactNumber: widget.contactNumber,
      );
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (Get.currentRoute.contains(RouteHelper.orderDetails) ||
            Get.currentRoute.contains(RouteHelper.orderTracking)) {
          Get.find<OrderController>().timerTrackOrder(
            widget.orderID.toString(),
            contactNumber: widget.contactNumber,
          );

          updateMarker(
            Get.find<OrderController>().trackModel?.store,
            Get.find<OrderController>().trackModel!.deliveryMan,
            Get.find<OrderController>().trackModel?.orderType == 'take_away'
                ? Get.find<LocationController>().position.latitude == 0
                    ? Get.find<OrderController>().trackModel?.deliveryAddress
                    : AddressModel(
                      latitude:
                          Get.find<LocationController>().position.latitude
                              .toString(),
                      longitude:
                          Get.find<LocationController>().position.longitude
                              .toString(),
                      address: Get.find<LocationController>().address,
                    )
                : Get.find<OrderController>().trackModel?.deliveryAddress,
            Get.find<OrderController>().trackModel?.orderType == 'take_away',
            Get.find<OrderController>().trackModel?.orderType == 'parcel',
            Get.find<OrderController>().trackModel?.moduleType == 'food',
          );
        } else {
          _timer?.cancel();
        }
      });
    } else {
      Get.find<OrderController>().timerTrackOrder(
        widget.orderID.toString(),
        contactNumber: widget.contactNumber,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadData();
  }

  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _timerTrackOrder();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _controller?.dispose();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _controller?.dispose();
    _timer?.cancel();
    _streamSubscription?.cancel();
    _streamService?.disconnect();
    _markerAnimator.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  void onEntered(bool isHovered) {
    setState(() {
      this.isHovered = isHovered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'order_tracking'.tr),
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body: GetBuilder<OrderController>(
        builder: (orderController) {
          OrderModel? track;
          if (orderController.trackModel != null) {
            track = orderController.trackModel;

            if (track!.orderType != 'parcel') {
              if (track.store!.storeBusinessModel == 'commission') {
                showChatPermission = true;
              } else if (track.store!.storeSubscription != null &&
                  track.store!.storeBusinessModel == 'subscription') {
                showChatPermission = track.store!.storeSubscription!.chat == 1;
              } else {
                showChatPermission = false;
              }
            } else {
              showChatPermission = AuthHelper.isLoggedIn();
            }
          }

          return track != null
              ? SingleChildScrollView(
                physics:
                    isHovered || !ResponsiveHelper.isDesktop(context)
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                child: FooterView(
                  child: Center(
                    child: SizedBox(
                      width: Dimensions.webMaxWidth,
                      height:
                          ResponsiveHelper.isDesktop(context)
                              ? 700
                              : MediaQuery.of(context).size.height * 0.85,
                      child: Stack(
                        children: [
                          MouseRegion(
                            onEnter: (event) => onEntered(true),
                            onExit: (event) => onEntered(false),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  double.parse(
                                    track.deliveryAddress!.latitude!,
                                  ),
                                  double.parse(
                                    track.deliveryAddress!.longitude!,
                                  ),
                                ),
                                zoom: 16,
                              ),
                              minMaxZoomPreference: const MinMaxZoomPreference(
                                0,
                                16,
                              ),
                              zoomControlsEnabled: false,
                              markers: _markers,
                              polylines: _polylines,
                              onMapCreated: (GoogleMapController controller) {
                                _controller = controller;
                                _isLoading = false;
                                setMarker(
                                  track!.orderType == 'parcel'
                                      ? Store(
                                        latitude:
                                            track.receiverDetails!.latitude,
                                        longitude:
                                            track.receiverDetails!.longitude,
                                        address: track.receiverDetails!.address,
                                        name:
                                            track
                                                .receiverDetails!
                                                .contactPersonName,
                                      )
                                      : track.store,
                                  track.deliveryMan,
                                  track.orderType == 'take_away'
                                      ? Get.find<LocationController>()
                                                  .position
                                                  .latitude ==
                                              0
                                          ? track.deliveryAddress
                                          : AddressModel(
                                            latitude:
                                                Get.find<LocationController>()
                                                    .position
                                                    .latitude
                                                    .toString(),
                                            longitude:
                                                Get.find<LocationController>()
                                                    .position
                                                    .longitude
                                                    .toString(),
                                            address:
                                                Get.find<LocationController>()
                                                    .address,
                                          )
                                      : track.deliveryAddress,
                                  track.orderType == 'take_away',
                                  track.orderType == 'parcel',
                                  track.moduleType == 'food',
                                );
                              },
                              style:
                                  Get.isDarkMode
                                      ? Get.find<ThemeController>().darkMap
                                      : Get.find<ThemeController>().lightMap,
                            ),
                          ),

                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : const SizedBox(),

                          Positioned(
                            top: Dimensions.paddingSizeSmall,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                ModernTrackingCardWidget(
                                  orderStatus: track.orderStatus,
                                  subStatus: track.subStatus,
                                  takeAway: track.orderType == 'take_away',
                                  eta: _currentETA?.displayText ?? track.estimatedDelivery,
                                  deliveryManName: track.deliveryMan?.fName,
                                ),

                                if (_shouldShowDeliveryInstructions(track))
                                  DeliveryInstructionTrackingWidget(order: track),
                              ],
                            ),
                          ),

                          Positioned(
                            right: 15,
                            bottom:
                                track.orderType != 'take_away' &&
                                        track.deliveryMan == null
                                    ? 150
                                    : 220,
                            child: InkWell(
                              onTap:
                                  () => _checkPermission(() async {
                                    AddressModel address =
                                        await Get.find<LocationController>()
                                            .getCurrentLocation(
                                              false,
                                              mapController: _controller,
                                            );
                                    setMarker(
                                      track!.orderType == 'parcel'
                                          ? Store(
                                            latitude:
                                                track.receiverDetails!.latitude,
                                            longitude:
                                                track
                                                    .receiverDetails!
                                                    .longitude,
                                            address:
                                                track.receiverDetails!.address,
                                            name:
                                                track
                                                    .receiverDetails!
                                                    .contactPersonName,
                                          )
                                          : track.store,
                                      track.deliveryMan,
                                      track.orderType == 'take_away'
                                          ? Get.find<LocationController>()
                                                      .position
                                                      .latitude ==
                                                  0
                                              ? track.deliveryAddress
                                              : AddressModel(
                                                latitude:
                                                    Get.find<
                                                          LocationController
                                                        >()
                                                        .position
                                                        .latitude
                                                        .toString(),
                                                longitude:
                                                    Get.find<
                                                          LocationController
                                                        >()
                                                        .position
                                                        .longitude
                                                        .toString(),
                                                address:
                                                    Get.find<
                                                          LocationController
                                                        >()
                                                        .address,
                                              )
                                          : track.deliveryAddress,
                                      track.orderType == 'take_away',
                                      track.orderType == 'parcel',
                                      track.moduleType == 'food',
                                      currentAddress: address,
                                      fromCurrentLocation: true,
                                    );
                                  }),
                              child: Container(
                                padding: const EdgeInsets.all(
                                  Dimensions.paddingSizeSmall,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  color: Colors.white,
                                ),
                                child: Icon(
                                  Icons.my_location_outlined,
                                  color: Theme.of(context).primaryColor,
                                  size: 25,
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            bottom: Dimensions.paddingSizeSmall,
                            left: Dimensions.paddingSizeSmall,
                            right: Dimensions.paddingSizeSmall,
                            child: TrackDetailsViewWidget(
                              status: track.orderStatus,
                              track: track,
                              showChatPermission: showChatPermission,
                              callback: () async {
                                _timer?.cancel();
                                await Get.toNamed(
                                  RouteHelper.getChatRoute(
                                    notificationBody: NotificationBodyModel(
                                      deliverymanId: track!.deliveryMan!.id,
                                      orderId: int.parse(widget.orderID!),
                                    ),
                                    user: User(
                                      id: track.deliveryMan!.id,
                                      fName: track.deliveryMan!.fName,
                                      lName: track.deliveryMan!.lName,
                                      imageFullUrl:
                                          track.deliveryMan!.imageFullUrl,
                                    ),
                                  ),
                                );
                                _timerTrackOrder();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              : const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  bool _shouldShowDeliveryInstructions(OrderModel track) {
    final status = track.orderStatus;
    final hasInstructions = (track.deliveryInstruction != null && track.deliveryInstruction!.isNotEmpty) ||
        (track.voiceInstructionFullUrl != null && track.voiceInstructionFullUrl!.isNotEmpty);
    final isActiveOrder = status == 'pending' || status == 'accepted' ||
        status == 'confirmed' || status == 'processing' ||
        status == 'handover' || status == 'picked_up';
    return hasInstructions && isActiveOrder && track.orderType != 'take_away';
  }

  void setMarker(
    Store? store,
    DeliveryMan? deliveryMan,
    AddressModel? addressModel,
    bool takeAway,
    bool parcel,
    bool isRestaurant, {
    AddressModel? currentAddress,
    bool fromCurrentLocation = false,
  }) async {
    try {
      BitmapDescriptor restaurantImageData =
          await MarkerHelper.convertAssetToBitmapDescriptor(
            width:
                (isRestaurant || parcel)
                    ? 30
                    : isRestaurant
                    ? 30
                    : 50,
            imagePath:
                parcel
                    ? Images.userMarker
                    : isRestaurant
                    ? Images.restaurantMarker
                    : Images.markerStore,
          );

      BitmapDescriptor deliveryBoyImageData =
          await MarkerHelper.convertAssetToBitmapDescriptor(
            width: 30,
            imagePath: Images.deliveryManMarker,
          );
      BitmapDescriptor destinationImageData =
          await MarkerHelper.convertAssetToBitmapDescriptor(
            width: 30,
            imagePath: takeAway ? Images.myLocationMarker : Images.userMarker,
          );

      /// Animate to coordinate
      LatLngBounds? bounds;
      double rotation = 0;
      if (_controller != null) {
        if (double.parse(addressModel!.latitude!) <
            double.parse(store!.latitude!)) {
          bounds = LatLngBounds(
            southwest: LatLng(
              double.parse(addressModel.latitude!),
              double.parse(addressModel.longitude!),
            ),
            northeast: LatLng(
              double.parse(store.latitude!),
              double.parse(store.longitude!),
            ),
          );
          rotation = 0;
        } else {
          bounds = LatLngBounds(
            southwest: LatLng(
              double.parse(store.latitude!),
              double.parse(store.longitude!),
            ),
            northeast: LatLng(
              double.parse(addressModel.latitude!),
              double.parse(addressModel.longitude!),
            ),
          );
          rotation = 180;
        }
      }
      LatLng centerBounds = LatLng(
        (bounds!.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );

      if (fromCurrentLocation && currentAddress != null) {
        LatLng currentLocation = LatLng(
          double.parse(currentAddress.latitude!),
          double.parse(currentAddress.longitude!),
        );
        _controller!.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: currentLocation,
              zoom: GetPlatform.isWeb ? 7 : 15,
            ),
          ),
        );
      }

      if (!fromCurrentLocation) {
        _controller!.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: centerBounds,
              zoom: GetPlatform.isWeb ? 10 : 17,
            ),
          ),
        );
        if (!ResponsiveHelper.isWeb()) {
          zoomToFit(
            _controller,
            bounds,
            centerBounds,
            padding: GetPlatform.isWeb ? 15 : 3,
          );
        }
      }

      /// user for normal order , but sender for parcel order
      _markers = HashSet<Marker>();

      ///current location marker set
      if (currentAddress != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            visible: true,
            draggable: false,
            zIndex: 2,
            flat: true,
            anchor: const Offset(0.5, 0.5),
            position: LatLng(
              double.parse(currentAddress.latitude!),
              double.parse(currentAddress.longitude!),
            ),
            icon: destinationImageData,
          ),
        );
        setState(() {});
      }

      if (currentAddress == null) {
        addressModel != null
            ? _markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: LatLng(
                  double.parse(addressModel.latitude!),
                  double.parse(addressModel.longitude!),
                ),
                infoWindow: InfoWindow(
                  title: parcel ? 'sender'.tr : 'Destination'.tr,
                  snippet: addressModel.address,
                ),
                icon: destinationImageData,
              ),
            )
            : const SizedBox();
      }

      ///store for normal order , but receiver for parcel order
      store != null
          ? _markers.add(
            Marker(
              markerId: const MarkerId('store'),
              position: LatLng(
                double.parse(store.latitude!),
                double.parse(store.longitude!),
              ),
              infoWindow: InfoWindow(
                title:
                    parcel
                        ? 'receiver'.tr
                        : Get.find<SplashController>()
                            .configModel!
                            .moduleConfig!
                            .module!
                            .showRestaurantText!
                        ? 'store'.tr
                        : 'store'.tr,
                snippet: store.address,
              ),
              icon: restaurantImageData,
            ),
          )
          : const SizedBox();

      deliveryMan != null
          ? _markers.add(
            Marker(
              markerId: const MarkerId('delivery_boy'),
              position: LatLng(
                double.parse(deliveryMan.lat ?? '0'),
                double.parse(deliveryMan.lng ?? '0'),
              ),
              infoWindow: InfoWindow(
                title: 'delivery_man'.tr,
                snippet: deliveryMan.location,
              ),
              rotation: rotation,
              icon: deliveryBoyImageData,
            ),
          )
          : const SizedBox();

      // Initialize route polyline (Store → Driver → Destination)
      _initRoutePolyline(store, deliveryMan, addressModel);
    } catch (_) {}
    setState(() {});
  }

  void updateMarker(
    Store? store,
    DeliveryMan? deliveryMan,
    AddressModel? addressModel,
    bool takeAway,
    bool parcel,
    bool isRestaurant, {
    AddressModel? currentAddress,
    bool fromCurrentLocation = false,
  }) async {
    try {
      BitmapDescriptor restaurantImageData =
          await MarkerHelper.convertAssetToBitmapDescriptor(
            width:
                (isRestaurant || parcel)
                    ? 30
                    : isRestaurant
                    ? 30
                    : 50,
            imagePath:
                parcel
                    ? Images.userMarker
                    : isRestaurant
                    ? Images.restaurantMarker
                    : Images.markerStore,
          );

      BitmapDescriptor deliveryBoyImageData =
          await MarkerHelper.convertAssetToBitmapDescriptor(
            width: 30,
            imagePath: Images.deliveryManMarker,
          );
      BitmapDescriptor destinationImageData =
          await MarkerHelper.convertAssetToBitmapDescriptor(
            width: 30,
            imagePath: takeAway ? Images.myLocationMarker : Images.userMarker,
          );

      LatLngBounds? bounds;
      debugPrint(bounds.toString());
      double rotation = 0;
      if (_controller != null) {
        if (double.parse(addressModel!.latitude!) <
            double.parse(store!.latitude!)) {
          bounds = LatLngBounds(
            southwest: LatLng(
              double.parse(addressModel.latitude!),
              double.parse(addressModel.longitude!),
            ),
            northeast: LatLng(
              double.parse(store.latitude!),
              double.parse(store.longitude!),
            ),
          );
          rotation = 0;
        } else {
          bounds = LatLngBounds(
            southwest: LatLng(
              double.parse(store.latitude!),
              double.parse(store.longitude!),
            ),
            northeast: LatLng(
              double.parse(addressModel.latitude!),
              double.parse(addressModel.longitude!),
            ),
          );
          rotation = 180;
        }
      }

      /// user for normal order , but sender for parcel order
      _markers = HashSet<Marker>();

      ///current location marker set
      if (currentAddress != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            visible: true,
            draggable: false,
            zIndex: 2,
            flat: true,
            anchor: const Offset(0.5, 0.5),
            position: LatLng(
              double.parse(currentAddress.latitude!),
              double.parse(currentAddress.longitude!),
            ),
            icon: destinationImageData,
          ),
        );
        setState(() {});
      }

      if (currentAddress == null) {
        addressModel != null
            ? _markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: LatLng(
                  double.parse(addressModel.latitude!),
                  double.parse(addressModel.longitude!),
                ),
                infoWindow: InfoWindow(
                  title: parcel ? 'sender'.tr : 'Destination'.tr,
                  snippet: addressModel.address,
                ),
                icon: destinationImageData,
              ),
            )
            : const SizedBox();
      }

      ///store for normal order , but receiver for parcel order
      store != null
          ? _markers.add(
            Marker(
              markerId: const MarkerId('store'),
              position: LatLng(
                double.parse(store.latitude!),
                double.parse(store.longitude!),
              ),
              infoWindow: InfoWindow(
                title:
                    parcel
                        ? 'receiver'.tr
                        : Get.find<SplashController>()
                            .configModel!
                            .moduleConfig!
                            .module!
                            .showRestaurantText!
                        ? 'store'.tr
                        : 'store'.tr,
                snippet: store.address,
              ),
              icon: restaurantImageData,
            ),
          )
          : const SizedBox();

      deliveryMan != null
          ? _markers.add(
            Marker(
              markerId: const MarkerId('delivery_boy'),
              position: LatLng(
                double.parse(deliveryMan.lat ?? '0'),
                double.parse(deliveryMan.lng ?? '0'),
              ),
              infoWindow: InfoWindow(
                title: 'delivery_man'.tr,
                snippet: deliveryMan.location,
              ),
              rotation: rotation,
              icon: deliveryBoyImageData,
            ),
          )
          : const SizedBox();
    } catch (_) {}
    setState(() {});
  }

  Future<void> zoomToFit(
    GoogleMapController? controller,
    LatLngBounds? bounds,
    LatLng centerBounds, {
    double padding = 0.5,
  }) async {
    bool keepZoomingOut = true;

    while (keepZoomingOut) {
      final LatLngBounds screenBounds = await controller!.getVisibleRegion();
      if (fits(bounds!, screenBounds)) {
        keepZoomingOut = false;
        final double zoomLevel = await controller.getZoomLevel() - padding;
        controller.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: centerBounds, zoom: zoomLevel),
          ),
        );
        break;
      } else {
        // Zooming out by 0.1 zoom level per iteration
        final double zoomLevel = await controller.getZoomLevel() - 0.1;
        controller.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: centerBounds, zoom: zoomLevel),
          ),
        );
      }
    }
  }

  bool fits(LatLngBounds fitBounds, LatLngBounds screenBounds) {
    final bool northEastLatitudeCheck =
        screenBounds.northeast.latitude >= fitBounds.northeast.latitude;
    final bool northEastLongitudeCheck =
        screenBounds.northeast.longitude >= fitBounds.northeast.longitude;

    final bool southWestLatitudeCheck =
        screenBounds.southwest.latitude <= fitBounds.southwest.latitude;
    final bool southWestLongitudeCheck =
        screenBounds.southwest.longitude <= fitBounds.southwest.longitude;

    return northEastLatitudeCheck &&
        northEastLongitudeCheck &&
        southWestLatitudeCheck &&
        southWestLongitudeCheck;
  }

  void _checkPermission(Function onTap) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      showCustomSnackBar('you_have_to_allow'.tr);
    } else if (permission == LocationPermission.deniedForever) {
      Get.dialog(const PermissionDialogWidget());
    } else {
      onTap();
    }
  }
}
