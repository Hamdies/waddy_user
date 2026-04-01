import 'dart:async';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lottie/lottie.dart';
import 'package:sixam_mart/features/auth/widgets/auth_dialog_widget.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_details_model.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/features/xp/domain/models/challenge_model.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_button.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/common/widgets/footer_view.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/common/widgets/web_menu_bar.dart';
import 'package:sixam_mart/features/checkout/widgets/payment_failed_dialog.dart';
import 'package:sixam_mart/services/live_activity_service.dart';
import 'package:sixam_mart/helper/live_activity_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OrderSuccessfulScreen extends StatefulWidget {
  final String? orderID;
  final String? contactPersonNumber;
  final bool? createAccount;
  final String guestId;
  const OrderSuccessfulScreen({
    super.key,
    required this.orderID,
    this.contactPersonNumber,
    this.createAccount = false,
    required this.guestId,
  });

  @override
  State<OrderSuccessfulScreen> createState() => _OrderSuccessfulScreenState();
}

class _OrderSuccessfulScreenState extends State<OrderSuccessfulScreen>
    with TickerProviderStateMixin {
  bool? _isCashOnDeliveryActive = false;
  String? orderId;
  bool _animationsStarted = false;
  Timer? _liveActivityTimer;
  String? _lastLiveActivityStatus;

  late AnimationController _heroAnim;
  late AnimationController _cardAnim;
  late AnimationController _xpAnim;
  late AnimationController _buttonAnim;

  @override
  void initState() {
    super.initState();

    orderId = widget.orderID!;
    if (widget.orderID!.contains('?')) {
      orderId = widget.orderID!.split('?')[0].trim();
    }

    Get.find<OrderController>()
        .trackOrder(
          orderId.toString(),
          null,
          false,
          contactNumber: widget.contactPersonNumber,
        )
        .then((_) {
          Get.find<OrderController>().getOrderDetails(orderId.toString());
          _startLiveActivity();
          _startLiveActivityPolling();
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<XpController>().getXpConfig();
      if (AuthHelper.isLoggedIn()) {
        Get.find<XpController>().getChallenges(reload: true);
      }
    });

    _heroAnim = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _cardAnim = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _xpAnim = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _buttonAnim = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  void _startAnimations() {
    if (_animationsStarted) return;
    _animationsStarted = true;
    _heroAnim.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _cardAnim.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _xpAnim.forward();
    });
    Future.delayed(const Duration(milliseconds: 780), () {
      if (mounted) _buttonAnim.forward();
    });
  }

  void _startLiveActivity() {
    final orderController = Get.find<OrderController>();
    final trackModel = orderController.trackModel;
    if (trackModel == null) return;

    LiveActivityService.startActivity(
      orderId: trackModel.id ?? 0,
      status: trackModel.orderStatus ?? 'pending',
      subStatus: trackModel.subStatus,
      eta: trackModel.estimatedDelivery,
      storeName: trackModel.store?.name,
      storeLogoUrl: trackModel.store?.logoFullUrl,
      deliveryManName: trackModel.deliveryMan != null
          ? '${trackModel.deliveryMan!.fName ?? ''} ${trackModel.deliveryMan!.lName ?? ''}'.trim()
          : null,
      orderType: trackModel.orderType ?? 'delivery',
    );
  }

  void _startLiveActivityPolling() {
    _liveActivityTimer?.cancel();
    _liveActivityTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      final orderController = Get.find<OrderController>();
      await orderController.trackOrder(
        orderId.toString(),
        null,
        false,
        contactNumber: widget.contactPersonNumber,
      );
      final trackModel = orderController.trackModel;
      if (trackModel == null) return;
      final status = trackModel.orderStatus ?? 'pending';
      if (status == _lastLiveActivityStatus) return;
      _lastLiveActivityStatus = status;
      if (LiveActivityHelper.isTerminalStatus(status)) {
        LiveActivityService.endActivity(trackModel.id ?? 0);
        _liveActivityTimer?.cancel();
      } else {
        LiveActivityService.updateActivity(
          orderId: trackModel.id ?? 0,
          status: status,
          subStatus: trackModel.subStatus,
          eta: trackModel.estimatedDelivery,
          storeName: trackModel.store?.name,
          deliveryManName: trackModel.deliveryMan != null
              ? '${trackModel.deliveryMan!.fName ?? ''} ${trackModel.deliveryMan!.lName ?? ''}'.trim()
              : null,
          orderType: trackModel.orderType ?? 'delivery',
        );
      }
    });
  }

  @override
  void dispose() {
    _liveActivityTimer?.cancel();
    _heroAnim.dispose();
    _cardAnim.dispose();
    _xpAnim.dispose();
    _buttonAnim.dispose();
    super.dispose();
  }

  // ── Animation helpers ─────────────────────────────────────────────────────

  Animation<Offset> _slide(AnimationController c, Offset begin) =>
      Tween<Offset>(
        begin: begin,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));

  Animation<double> _fade(AnimationController c) => Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));

  Animation<double> _scaleElastic(AnimationController c) => Tween<double>(
    begin: 0.6,
    end: 1.0,
  ).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut));

  // ── Date formatters ───────────────────────────────────────────────────────

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      DateTime dt;
      try {
        dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateStr);
      } catch (_) {
        dt = DateTime.parse(dateStr);
      }
      return DateFormat('EEE, dd MMM yyyy  ·  h:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _paymentMethodLabel(String? method) {
    switch (method) {
      case 'cash_on_delivery':
        return 'Cash on delivery';
      case 'digital_payment':
        return 'Online payment';
      case 'partial_payment':
        return 'Partial payment';
      case 'wallet':
        return 'Wallet';
      default:
        return method?.replaceAll('_', ' ').capitalize ?? '';
    }
  }

  String _orderStatusMessage(dynamic order) {
    final status = order.orderStatus ?? 'pending';
    final storeName = order.store?.name ?? '';
    switch (status) {
      case 'pending':
        return storeName.isNotEmpty
            ? '$storeName ${'is_reviewing_your_order'.tr}'
            : 'your_order_is_being_reviewed'.tr;
      case 'confirmed':
      case 'accepted':
        return storeName.isNotEmpty
            ? '$storeName ${'is_preparing_your_order'.tr}'
            : 'preparing_your_order'.tr;
      case 'processing':
        return storeName.isNotEmpty
            ? '$storeName ${'is_preparing_your_order'.tr}'
            : 'preparing_your_order'.tr;
      default:
        return storeName.isNotEmpty
            ? '$storeName ${'is_preparing_your_order'.tr}'
            : 'preparing_your_order'.tr;
    }
  }

  /// ETA chip: shows backend ETA range when available (after confirmed),
  /// falls back to store's static delivery time, or nothing if neither exists.
  Widget _buildEtaChip(dynamic order, Color primary) {
    // 1. Backend estimated_delivery_at (set after store confirms)
    if (order.estimatedDelivery != null &&
        order.estimatedDelivery!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 15, color: primary),
            const SizedBox(width: 6),
            Text(
              '${'estimated_delivery'.tr}: ${order.estimatedDelivery}',
              style: robotoMedium.copyWith(fontSize: 12, color: primary),
            ),
          ],
        ),
      );
    }
    // 2. Fallback: store's static delivery time (rough estimate while pending)
    final storeTime = order.store?.deliveryTime;
    if (storeTime != null && storeTime.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 15, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              '${'estimated_delivery'.tr}: $storeTime ',
              style: robotoMedium.copyWith(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).primaryColor;
    final Color accent = Theme.of(context).secondaryHeaderColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult:
          (_, __) async => Get.offAllNamed(RouteHelper.getInitialRoute()),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F8F5),
        appBar: ResponsiveHelper.isDesktop(context) ? const WebMenuBar() : null,
        endDrawer: const MenuDrawer(),
        endDrawerEnableOpenDragGesture: false,
        body: SafeArea(
          child: GetBuilder<OrderController>(
            builder: (oc) {
              double loyaltyPts = 0;
              bool success = true, parcel = false;
              double? maxCod;

              if (oc.trackModel != null) {
                loyaltyPts =
                    ((oc.trackModel!.orderAmount! / 100) *
                        Get.find<SplashController>()
                            .configModel!
                            .loyaltyPointItemPurchasePoint!);
                success =
                    oc.trackModel!.paymentStatus == 'paid' ||
                    oc.trackModel!.paymentMethod == 'cash_on_delivery' ||
                    oc.trackModel!.paymentMethod == 'partial_payment';
                parcel = oc.trackModel!.paymentMethod == 'parcel';

                for (ZoneData z
                    in AddressHelper.getUserAddressFromSharedPref()!
                        .zoneData!) {
                  for (Modules m in z.modules!) {
                    if (m.id == Get.find<SplashController>().module!.id) {
                      maxCod = m.pivot!.maximumCodOrderAmount;
                      break;
                    }
                  }
                  if (z.id ==
                      AddressHelper.getUserAddressFromSharedPref()!.zoneId) {
                    _isCashOnDeliveryActive = z.cashOnDelivery;
                  }
                }

                if (!success &&
                    !Get.isDialogOpen! &&
                    oc.trackModel!.orderStatus != 'canceled' &&
                    Get.currentRoute.startsWith(RouteHelper.orderSuccess)) {
                  Future.delayed(const Duration(seconds: 1), () {
                    Get.dialog(
                      PaymentFailedDialog(
                        orderID: orderId,
                        isCashOnDelivery: _isCashOnDeliveryActive,
                        orderAmount: loyaltyPts,
                        maxCodOrderAmount: maxCod,
                        orderType: parcel ? 'parcel' : 'delivery',
                        guestId: widget.guestId,
                      ),
                      barrierDismissible: false,
                    );
                  });
                }

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _startAnimations(),
                );
              }

              if (oc.trackModel == null) {
                return Center(child: CircularProgressIndicator(color: primary));
              }
              if (!success) return _failureView(primary, loyaltyPts);
              return _successView(context, oc, loyaltyPts, primary, accent);
            },
          ),
        ),
      ),
    );
  }

  // ── Failure view ──────────────────────────────────────────────────────────

  Widget _failureView(Color primary, double total) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(Images.warning, width: 100, height: 100),
          const SizedBox(height: 24),
          Text(
            'your_order_is_failed_to_place'.tr,
            style: robotoBold.copyWith(fontSize: 18, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'your_order_is_failed_to_place_because'.tr,
            style: robotoRegular.copyWith(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          CustomButton(
            buttonText: 'back_to_home'.tr,
            textColor: Colors.white,
            onPressed: () {
              if (AuthHelper.isLoggedIn())
                Get.find<AuthController>().saveEarningPoint(
                  total.toStringAsFixed(0),
                );
              Get.offAllNamed(RouteHelper.getInitialRoute());
            },
          ),
        ],
      ),
    ),
  );

  // ── Success view ──────────────────────────────────────────────────────────

  Widget _successView(
    BuildContext ctx,
    OrderController oc,
    double loyaltyPts,
    Color primary,
    Color accent,
  ) {
    final order = oc.trackModel!;
    final details = oc.orderDetails;

    final double total = order.orderAmount ?? 0;
    final double tax = order.totalTaxAmount ?? 0;
    final double tips = order.dmTips ?? 0;
    final double delivery = order.deliveryCharge ?? 0;
    final double subtotal = total - tax - tips - delivery;

    final bool showRewards =
        Get.find<SplashController>().configModel!.loyaltyPointStatus == 1 &&
        loyaltyPts.floor() > 0 &&
        AuthHelper.isLoggedIn();

    final xpCtrl = Get.find<XpController>();
    final int xp =
        AuthHelper.isLoggedIn()
            ? xpCtrl.calculateEstimatedXp(
              total,
              Get.find<SplashController>().module?.moduleType,
            )
            : 0;

    final challenges = xpCtrl.challengeModel;
    final List<Challenge> orderChallenges = [];
    if (challenges != null) {
      for (final c in [
        ...challenges.dailyChallenges,
        ...challenges.weeklyChallenges,
      ]) {
        if (c.actionType == 'order' || c.actionType == 'spend') {
          orderChallenges.add(c);
        }
      }
    }

    final String orderNumber = '#${order.id ?? orderId}';
    final String dateFormatted = _formatDate(order.createdAt);
    final String paymentMethod = _paymentMethodLabel(order.paymentMethod);
    final String? storeLogo = order.store?.logoFullUrl;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child:
                ResponsiveHelper.isDesktop(ctx)
                    ? FooterView(
                      child: SizedBox(
                        width: Dimensions.webMaxWidth,
                        child: _body(
                          ctx,
                          order,
                          details,
                          storeLogo,
                          orderNumber,
                          dateFormatted,
                          paymentMethod,
                          subtotal,
                          tax,
                          tips,
                          delivery,
                          total,
                          showRewards,
                          loyaltyPts,
                          xp,
                          orderChallenges,
                          primary,
                          accent,
                        ),
                      ),
                    )
                    : _body(
                      ctx,
                      order,
                      details,
                      storeLogo,
                      orderNumber,
                      dateFormatted,
                      paymentMethod,
                      subtotal,
                      tax,
                      tips,
                      delivery,
                      total,
                      showRewards,
                      loyaltyPts,
                      xp,
                      orderChallenges,
                      primary,
                      accent,
                    ),
          ),
        ),

        // ── Bottom buttons ──
        SlideTransition(
          position: _slide(_buttonAnim, const Offset(0, 1)),
          child: FadeTransition(
            opacity: _fade(_buttonAnim),
            child: Container(
              color: const Color(0xFFF2F8F5),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomButton(
                        buttonText: 'track_order'.tr,
                        textColor: Colors.white,
                        onPressed: () {
                          if (AuthHelper.isLoggedIn())
                            Get.find<AuthController>().saveEarningPoint(
                              loyaltyPts.toStringAsFixed(0),
                            );
                          Get.offAllNamed(
                            RouteHelper.getOrderDetailsRoute(
                              int.tryParse(orderId ?? ''),
                              contactNumber: widget.contactPersonNumber,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      CustomButton(
                        buttonText: 'back_to_home'.tr,
                        transparent: true,
                        onPressed: () {
                          if (AuthHelper.isLoggedIn())
                            Get.find<AuthController>().saveEarningPoint(
                              loyaltyPts.toStringAsFixed(0),
                            );
                          Get.offAllNamed(RouteHelper.getInitialRoute());
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _body(
    BuildContext ctx,
    dynamic order,
    List<OrderDetailsModel>? details,
    String? storeLogo,
    String orderNumber,
    String dateFormatted,
    String paymentMethod,
    double subtotal,
    double tax,
    double tips,
    double delivery,
    double total,
    bool showRewards,
    double loyaltyPts,
    int xp,
    List<Challenge> orderChallenges,
    Color primary,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),

          // ── Hero: Lottie + confirmation text ──
          SlideTransition(
            position: _slide(_heroAnim, const Offset(0, -0.2)),
            child: FadeTransition(
              opacity: _fade(_heroAnim),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Checkmark + title inline ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'order_confirmed'.tr,
                        style: robotoBold.copyWith(
                          fontSize: 22,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'your_order_is_confirmed'.tr,
                    style: robotoRegular.copyWith(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.black45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // ── Status message ──
                  Text(
                    _orderStatusMessage(order),
                    style: robotoRegular.copyWith(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // ── Estimated delivery chip with icon ──
                  // Shows ETA range when backend provides it (after store confirms),
                  // otherwise shows store's static delivery time as rough estimate.
                  _buildEtaChip(order, primary),
                  const SizedBox(height: 12),
                  Text(
                    orderNumber,
                    style: robotoBold.copyWith(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Order card ──
          SlideTransition(
            position: _slide(_cardAnim, const Offset(0, 0.15)),
            child: FadeTransition(
              opacity: _fade(_cardAnim),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Card header: store + date + payment ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Row(
                        children: [
                          if (storeLogo != null && storeLogo.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CustomImage(
                                image: storeLogo,
                                height: 48,
                                width: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dateFormatted.isNotEmpty)
                                  Text(
                                    dateFormatted,
                                    style: robotoRegular.copyWith(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: Colors.black45,
                                    ),
                                  ),
                                if (paymentMethod.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    paymentMethod,
                                    style: robotoMedium.copyWith(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Divider ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Container(
                        height: 1,
                        color: const Color(0xFFEEEEEE),
                      ),
                    ),

                    // ── Items ──
                    if (details != null && details.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            ...details.asMap().entries.map(
                              (e) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: e.key < details.length - 1 ? 16 : 0,
                                ),
                                child: _itemRow(e.value),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Container(
                          height: 1,
                          color: const Color(0xFFEEEEEE),
                        ),
                      ),
                    ],

                    // ── Price breakdown ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _priceRow(
                            'subtotal'.tr,
                            PriceConverter.convertPrice(
                              subtotal > 0 ? subtotal : total - tax,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _priceRow('tax'.tr, PriceConverter.convertPrice(tax)),
                          if (tips > 0) ...[
                            const SizedBox(height: 12),
                            _priceRow(
                              'staff_tip'.tr,
                              PriceConverter.convertPrice(tips),
                            ),
                          ],
                          if (delivery > 0) ...[
                            const SizedBox(height: 12),
                            _priceRow(
                              'delivery'.tr,
                              PriceConverter.convertPrice(delivery),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Total ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Container(
                        height: 1,
                        color: const Color(0xFFEEEEEE),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'total'.tr,
                            style: robotoBold.copyWith(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            PriceConverter.convertPrice(total),
                            style: robotoBold.copyWith(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),

                    // ── Rewards section ──
                    if (showRewards || orderChallenges.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: Text(
                          'rewards'.tr.toUpperCase(),
                          style: robotoMedium.copyWith(
                            fontSize: 11,
                            letterSpacing: 2,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (showRewards)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Text(
                                '+${loyaltyPts.floor()} ${'points'.tr}',
                                style: robotoBold.copyWith(
                                  color: accent,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'loyalty_reward'.tr,
                                  style: robotoRegular.copyWith(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ...orderChallenges.map(
                        (c) => Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                          child: Row(
                            children: [
                              Text(
                                '+1 ${'stamp'.tr}',
                                style: robotoBold.copyWith(
                                  color: accent,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  c.title,
                                  style: robotoRegular.copyWith(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // ── XP pill ──
          if (xp > 0)
            FadeTransition(
              opacity: _fade(_xpAnim),
              child: ScaleTransition(
                scale: _scaleElastic(_xpAnim),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _xpPill(xp, primary, accent),
                ),
              ),
            ),

          // ── Thank you ──
          FadeTransition(
            opacity: _fade(_xpAnim),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'thank_you'.tr,
                style: robotoRegular.copyWith(
                  fontSize: 13,
                  color: Colors.black38,
                ),
              ),
            ),
          ),

          // Account creation
          if (widget.createAccount!) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('and_create_account_successfully'.tr, style: robotoMedium),
                InkWell(
                  onTap:
                      () =>
                          ResponsiveHelper.isDesktop(ctx)
                              ? Get.dialog(
                                const Center(
                                  child: AuthDialogWidget(
                                    exitFromApp: false,
                                    backFromThis: false,
                                  ),
                                ),
                              )
                              : Get.toNamed(
                                RouteHelper.getSignInRoute(RouteHelper.splash),
                              ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Text(
                      'sign_in'.tr,
                      style: robotoMedium.copyWith(
                        color: Theme.of(ctx).primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Guest order ID (guest mode disabled)


          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── XP pill ───────────────────────────────────────────────────────────────

  Widget _xpPill(int xp, Color primary, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.15),
            accent.withValues(alpha: 0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Lottie.asset(
            'assets/animation/waddi_coins.json',
            width: 36,
            height: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'xp_earned'.tr,
                      style: robotoBold.copyWith(fontSize: 14, color: primary),
                    ),
                    Row(
                      children: [
                        Text(
                          '+$xp XP ',
                          style: robotoBold.copyWith(
                            fontSize: 18,
                            color: primary,
                          ),
                        ),
                        Image.asset(
                          'assets/image/waddy_coin.png',
                          width: 18,
                          height: 18,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'closer_to_next_level'.tr,
                  style: robotoRegular.copyWith(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Item row ──────────────────────────────────────────────────────────────

  Widget _itemRow(OrderDetailsModel d) {
    final String name = d.itemDetails?.name ?? '';
    final int qty = d.quantity ?? 1;
    final double price = (d.price ?? 0) * qty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F8F5),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            '$qty',
            style: robotoMedium.copyWith(fontSize: 13, color: Colors.black54),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: robotoMedium.copyWith(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (d.addOns != null && d.addOns!.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...d.addOns!.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '+ ${a.name ?? ''}',
                            style: robotoRegular.copyWith(
                              fontSize: 12,
                              height: 1.4,
                              color: Colors.black38,
                            ),
                          ),
                        ),
                        Text(
                          PriceConverter.convertPrice(
                            (a.price ?? 0) * (a.quantity ?? 1),
                          ),
                          style: robotoRegular.copyWith(
                            fontSize: 12,
                            color: Colors.black38,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 14),
        Text(
          PriceConverter.convertPrice(price),
          style: robotoMedium.copyWith(fontSize: 15, color: Colors.black87),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }

  // ── Price row ─────────────────────────────────────────────────────────────

  Widget _priceRow(
    String label,
    String value, {
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  }) {
    final ts = robotoRegular.copyWith(fontSize: 14, height: 1.5, color: Colors.black54);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle ?? ts),
        Text(value, style: valueStyle ?? ts, textDirection: TextDirection.ltr),
      ],
    );
  }
}
