import 'dart:async';
import 'package:waddy_app/features/scratch_card/widgets/scratch_card_badge.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/checkout/widgets/order_receipt_widget.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/checkout/widgets/payment_failed_dialog.dart';
import 'package:waddy_app/services/live_activity_service.dart';
import 'package:waddy_app/helper/live_activity_helper.dart';
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
    with SingleTickerProviderStateMixin {
  bool? _isCashOnDeliveryActive = false;
  String? orderId;
  Timer? _liveActivityTimer;
  String? _lastLiveActivityStatus;

  // ── Receipt print ──
  // The receipt feeds out of the printer slot, then the thank-you and the
  // CTAs arrive and the page scrolls down to them.
  static const Duration _printDuration = Duration(milliseconds: 3200);
  static const Duration _printDelay = Duration(milliseconds: 450);

  /// How long the print waits for the item lines before starting without
  /// them, so a slow details call never holds the whole screen hostage.
  static const Duration _detailsWait = Duration(seconds: 2);

  /// Bottom edge of the printer slot (6pt gap + slot). The scroll area starts
  /// 8pt above it so the paper visibly emerges from under the slot.
  static const double _slotBottom = 6 + ReceiptPrinterSlot.height;
  static const double _slotOverlap = 8;

  late final AnimationController _print;
  late final Animation<double> _feed;
  final ScrollController _scroll = ScrollController();
  Timer? _printTimer;
  Timer? _detailsTimer;
  Timer? _scrollTimer;
  bool _printScheduled = false;
  bool _detailsWaitExpired = false;
  bool _done = false;

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
          _logPurchaseOnce();
          _startLiveActivity();
          _startLiveActivityPolling();
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<XpController>().getXpConfig();
    });

    _print = AnimationController(duration: _printDuration, vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onPrinted();
      });
    _feed = CurvedAnimation(parent: _print, curve: const PrinterFeedCurve());
  }

  /// Order ids already reported as Purchase this session. The screen can be
  /// remounted (web payment callbacks, back-and-forth) and the conversion
  /// Meta optimizes on must never double-count.
  static final Set<String> _loggedPurchases = <String>{};

  void _logPurchaseOnce() {
    final trackModel = Get.find<OrderController>().trackModel;
    if (trackModel == null || orderId == null) return;
    final bool paidOrCod =
        trackModel.paymentStatus == 'paid' ||
        trackModel.paymentMethod == 'cash_on_delivery' ||
        trackModel.paymentMethod == 'partial_payment';
    if (!paidOrCod) return;
    if (!_loggedPurchases.add(orderId!)) return;
    AnalyticsHelper.logPurchase(
      amount: trackModel.orderAmount ?? 0,
      orderId: orderId,
    );
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
      arrivalAt: LiveActivityHelper.parseArrival(
        trackModel.estimatedDeliveryAt,
      ),
      storeName: trackModel.store?.name,
      storeLogoUrl: trackModel.store?.logoFullUrl,
      deliveryManName:
          trackModel.deliveryMan != null
              ? '${trackModel.deliveryMan!.fName ?? ''} ${trackModel.deliveryMan!.lName ?? ''}'
                  .trim()
              : null,
      orderType: trackModel.orderType ?? 'delivery',
      moduleType: trackModel.moduleType,
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
        LiveActivityService.endActivity(trackModel.id ?? 0, status: status);
        _liveActivityTimer?.cancel();
      } else {
        LiveActivityService.updateActivity(
          orderId: trackModel.id ?? 0,
          status: status,
          subStatus: trackModel.subStatus,
          eta: trackModel.estimatedDelivery,
          arrivalAt: LiveActivityHelper.parseArrival(
            trackModel.estimatedDeliveryAt,
          ),
          storeName: trackModel.store?.name,
          deliveryManName:
              trackModel.deliveryMan != null
                  ? '${trackModel.deliveryMan!.fName ?? ''} ${trackModel.deliveryMan!.lName ?? ''}'
                      .trim()
                  : null,
          orderType: trackModel.orderType ?? 'delivery',
        );
      }
    });
  }

  @override
  void dispose() {
    _liveActivityTimer?.cancel();
    _printTimer?.cancel();
    _detailsTimer?.cancel();
    _scrollTimer?.cancel();
    _print.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Print sequencing ──────────────────────────────────────────────────────

  /// The controller outlives this screen, so both models can still hold the
  /// previous order until the fetches for this one land.
  bool _isThisOrder(OrderModel? m) =>
      m != null && m.id != null && m.id.toString() == orderId;

  List<OrderDetailsModel>? _detailsFor(OrderController oc) {
    final details = oc.orderDetails;
    if (details == null || details.isEmpty) return details;
    return details.first.orderId?.toString() == orderId ? details : null;
  }

  /// Starts the print once this order's receipt can be drawn in full, or once
  /// [_detailsWait] runs out — whichever comes first.
  void _maybeStartPrint(OrderController oc) {
    if (_printScheduled || !mounted) return;
    if (!_isThisOrder(oc.trackModel)) return;
    if (_detailsFor(oc) == null && !_detailsWaitExpired) {
      _detailsTimer ??= Timer(_detailsWait, () {
        _detailsWaitExpired = true;
        if (mounted) _maybeStartPrint(Get.find<OrderController>());
      });
      return;
    }
    _printScheduled = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _print.value = 1;
      return;
    }
    _printTimer = Timer(_printDelay, () {
      if (mounted) _print.forward();
    });
  }

  /// Tap anywhere on the paper to tear it off early.
  void _skipPrint() {
    if (!_printScheduled || _done) return;
    _printTimer?.cancel();
    _print.stop();
    _print.value = 1;
  }

  void _onPrinted() {
    if (!mounted || _done) return;
    setState(() => _done = true);
    if (MediaQuery.disableAnimationsOf(context)) return;
    _scrollTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 900),
        curve: WaddyMotion.easeInOut,
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).primaryColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult:
          (_, __) async => Get.offAllNamed(RouteHelper.getInitialRoute()),
      child: Scaffold(
        backgroundColor: WaddyColors.surfaceRaised,
        appBar: null,
        endDrawer: const MenuDrawer(),
        endDrawerEnableOpenDragGesture: false,
        body: SafeArea(
          bottom: false,
          child: GetBuilder<OrderController>(
            builder: (oc) {
              double loyaltyPts = 0;
              bool success = true, parcel = false;
              double? maxCod;

              if (oc.trackModel != null) {
                loyaltyPts =
                    ((oc.trackModel!.orderAmount! / 100) *
                        Get.find<SplashController>()
                            .configModel
                            .loyaltyPointItemPurchasePoint!);
                success =
                    oc.trackModel!.paymentStatus == 'paid' ||
                    oc.trackModel!.paymentMethod == 'cash_on_delivery' ||
                    oc.trackModel!.paymentMethod == 'partial_payment';
                parcel = oc.trackModel!.paymentMethod == 'parcel';

                // This screen stays in the stack after the user goes home,
                // where no module is selected; rebuilds from OrderController
                // then crashed on `module!`. Fall back to the order's module.
                final address = AddressHelper.getUserAddressFromSharedPref();
                final int? moduleId = Get.find<SplashController>().module?.id;
                for (ZoneData z in address?.zoneData ?? const <ZoneData>[]) {
                  for (Modules m in z.modules ?? const <Modules>[]) {
                    final bool isOrderModule =
                        moduleId != null
                            ? m.id == moduleId
                            : m.moduleType == oc.trackModel!.moduleType;
                    if (isOrderModule) {
                      maxCod = m.pivot?.maximumCodOrderAmount;
                      break;
                    }
                  }
                  if (z.id == address?.zoneId) {
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

                if (success) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _maybeStartPrint(oc),
                  );
                }
              }

              if (!success) return _failureView(primary, loyaltyPts);
              // Until this order's track lands, the empty printer slot is the
              // loading state — the receipt feeding out of it is the reveal.
              return _successView(oc, loyaltyPts);
            },
          ),
        ),
      ),
    );
  }

  // ── Failure view ──────────────────────────────────────────────────────────

  Widget _failureView(Color primary, double total) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeExtremeLarge,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(Images.warning, width: 100, height: 100),
          const SizedBox(height: 24),
          Text(
            'your_order_is_failed_to_place'.tr,
            style: waddyBold.copyWith(fontSize: 18, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'your_order_is_failed_to_place_because'.tr,
            style: waddyRegular.copyWith(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          CustomButton(
            buttonText: 'back_to_home'.tr,
            textColor: Colors.white,
            onPressed: () {
              if (AuthHelper.isLoggedIn()) {
                Get.find<AuthController>().saveEarningPoint(
                  total.toStringAsFixed(0),
                );
              }
              Get.offAllNamed(RouteHelper.getInitialRoute());
            },
          ),
        ],
      ),
    ),
  );

  // ── Success view ──────────────────────────────────────────────────────────

  Widget _successView(OrderController oc, double loyaltyPts) {
    final OrderModel? order =
        _isThisOrder(oc.trackModel) ? oc.trackModel : null;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    // The cart's own per-line estimate, handed over at checkout. The
    // fallback (an order not placed from the cart) estimates on the order
    // total, which includes delivery and tax and so reads high (X-23).
    final XpController xpController = Get.find<XpController>();
    final int xp =
        order != null && AuthHelper.isLoggedIn()
            ? (xpController.lastOrderXpEstimate ??
                xpController.calculateEstimatedXp(
                  order.orderAmount ?? 0,
                  Get.find<SplashController>().module?.moduleType,
                ))
            : 0;

    return Stack(
      children: [
        // ── Paper ──
        Positioned.fill(
          top: _slotBottom - _slotOverlap,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _skipPrint,
            child: SingleChildScrollView(
              controller: _scroll,
              physics:
                  _done
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  if (order != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeExtremeLarge,
                      ),
                      child: AnimatedBuilder(
                        animation: _feed,
                        builder:
                            (context, child) => FractionalTranslation(
                              translation: Offset(0, _feed.value - 1),
                              child: child,
                            ),
                        child: OrderReceiptWidget(
                          order: order,
                          details: _detailsFor(oc),
                        ),
                      ),
                    ),
                  if (order != null) _thanks(order, xp, bottomInset),
                ],
              ),
            ),
          ),
        ),

        // ── Slot shade: the paper darkens as it slides under the lip ──
        const Positioned(
          top: _slotBottom - _slotOverlap,
          left: 0,
          right: 0,
          height: 14,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x38134E4A), Color(0x00134E4A)],
                ),
              ),
            ),
          ),
        ),

        // ── Printer ──
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Dimensions.paddingSizeMedium,
              6,
              Dimensions.paddingSizeMedium,
              0,
            ),
            child: ReceiptPrinterSlot(),
          ),
        ),

        // ── CTAs ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !_done,
            child: _reveal(
              slide: 0.12,
              curve: const Interval(0.25, 1, curve: WaddyMotion.easeOut),
              duration: const Duration(milliseconds: 600),
              child: _ctas(loyaltyPts, bottomInset),
            ),
          ),
        ),
      ],
    );
  }

  /// Fades and lifts [child] into place once the receipt has printed.
  Widget _reveal({
    required Widget child,
    required double slide,
    Curve curve = WaddyMotion.easeOut,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return AnimatedOpacity(
      opacity: _done ? 1 : 0,
      duration: duration,
      curve: curve,
      child: AnimatedSlide(
        offset: _done ? Offset.zero : Offset(0, slide),
        duration: duration,
        curve: curve,
        child: child,
      ),
    );
  }

  Widget _thanks(OrderModel order, int xp, double bottomInset) {
    final String? eta = order.estimatedDelivery ?? order.store?.deliveryTime;

    return _reveal(
      slide: 0.06,
      child: Padding(
        // Bottom room so the last line can scroll clear of the CTA stack.
        padding: EdgeInsets.fromLTRB(
          Dimensions.paddingSizeDefault,
          Dimensions.paddingSizeExtraOverLarge,
          Dimensions.paddingSizeDefault,
          190 + bottomInset,
        ),
        child: Column(
          children: [
            Text(
              'thanks_for_your_order'.tr,
              textAlign: TextAlign.center,
              style: waddyDisplayFace(
                44,
                weight: FontWeight.w900,
                height: 0.95,
                color: WaddyColors.primary,
              ),
            ),
            if (eta != null && eta.isNotEmpty) ...[
              const SizedBox(height: Dimensions.paddingSizeMedium),
              Text(
                '${'arriving_in'.tr.capitalizeFirst} $eta',
                textAlign: TextAlign.center,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  fontWeight: FontWeight.w600,
                  color: WaddyColors.inkMid,
                ),
              ),
            ],
            if (xp > 0) ...[
              const SizedBox(height: Dimensions.paddingSizeExtraLarge),
              _xpChip(xp),
            ],
            // The printed card is in the bag: a bar under the XP chip, in its
            // style (docs/scratch_card_plan.md §3a).
            if (order.orderType != 'parcel' && ScratchCardBadge.inBags) ...[
              SizedBox(
                height:
                    xp > 0
                        ? Dimensions.paddingSizeMedium
                        : Dimensions.paddingSizeExtraLarge,
              ),
              const ScratchCardBar(moment: ScratchTeaserMoment.placed),
            ],
            if (widget.createAccount!) ...[
              const SizedBox(height: Dimensions.paddingSizeMedium),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'and_create_account_successfully'.tr,
                    style: waddyMedium,
                  ),
                  InkWell(
                    onTap:
                        () => Get.toNamed(
                          RouteHelper.getSignInRoute(RouteHelper.splash),
                        ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                        Dimensions.paddingSizeExtraSmall,
                      ),
                      child: Text(
                        'sign_in'.tr,
                        style: waddyMedium.copyWith(color: WaddyColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _xpChip(int xp) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeMedium,
        vertical: Dimensions.paddingSizeMedium,
      ),
      decoration: BoxDecoration(
        color: WaddyColors.mintSurface,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(
          color: WaddyColors.mint.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/image/waddy_coin.png', width: 24, height: 24),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Flexible(
            child: Text.rich(
              TextSpan(
                style: waddyMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: WaddyColors.mintInk,
                ),
                children: [
                  TextSpan(
                    text: '${'you_will_earn'.tr} $xp XP',
                    style: waddyBold.copyWith(
                      fontSize: 15,
                      color: WaddyColors.mintInk,
                    ),
                  ),
                  TextSpan(text: ' ${'earn_with_order'.tr}'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctas(double loyaltyPts, double bottomInset) {
    void saveEarning() {
      if (AuthHelper.isLoggedIn()) {
        Get.find<AuthController>().saveEarningPoint(
          loyaltyPts.toStringAsFixed(0),
        );
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            WaddyColors.surfaceRaised.withValues(alpha: 0),
            WaddyColors.surfaceRaised,
          ],
          stops: const [0, 0.3],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Dimensions.paddingSizeDefault,
          Dimensions.paddingSizeExtraLarge,
          Dimensions.paddingSizeDefault,
          Dimensions.paddingSizeDefault + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomButton(
              buttonText: 'track_order'.tr,
              height: 54,
              radius: 999,
              fontSize: Dimensions.fontSizeDefault + 2,
              onPressed: () {
                saveEarning();
                Get.offAllNamed(
                  RouteHelper.getOrderDetailsRoute(
                    int.tryParse(orderId ?? ''),
                    contactNumber: widget.contactPersonNumber,
                  ),
                );
              },
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            CustomButton(
              buttonText: 'back_to_home'.tr,
              transparent: true,
              height: 50,
              radius: 999,
              fontSize: Dimensions.fontSizeDefault + 1,
              onPressed: () {
                saveEarning();
                Get.offAllNamed(RouteHelper.getInitialRoute());
              },
            ),
          ],
        ),
      ),
    );
  }
}
