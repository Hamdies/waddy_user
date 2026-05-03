import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ZomatoOrderInfoCard
//
// Two layout modes driven by order status:
//
//  PRE-PICKUP  (pending → processing)
//    Header:  item thumbnail + name + item count
//    Body:    3-step vertical timeline with animated dots
//    OTP:     dark teal block with copy affordance (shown when ongoing + otp present)
//    Footer:  order ID + payment badge
//
//  EN-ROUTE   (handover / pickedUp)
//    This card collapses to a compact summary strip.
//    The map hero in order_details_screen.dart takes the visual lead.
//    OTP is promoted above the strip.
// ─────────────────────────────────────────────────────────────────────────────

class ZomatoOrderInfoCard extends StatefulWidget {
  final OrderModel order;
  final OrderController orderController;
  final VoidCallback? onViewDetails;
  final bool ongoing;
  /// When non-null, overrides internal OTP visibility logic.
  /// Allows parent to control when OTP appears (e.g. only when rider is en-route).
  final bool? showOtpOverride;

  const ZomatoOrderInfoCard({
    super.key,
    required this.order,
    required this.orderController,
    this.onViewDetails,
    this.ongoing = false,
    this.showOtpOverride,
  });

  @override
  State<ZomatoOrderInfoCard> createState() => _ZomatoOrderInfoCardState();
}

class _ZomatoOrderInfoCardState extends State<ZomatoOrderInfoCard> {

  @override
  Widget build(BuildContext context) {
    final items = widget.orderController.orderDetails ?? [];
    final OrderStatus? status = OrderStatus.fromString(
      widget.order.orderStatus,
    );
    final bool enRoute =
        status == OrderStatus.handover || status == OrderStatus.pickedUp;
    final bool showOtp = widget.showOtpOverride ??
        (widget.ongoing &&
        widget.order.otp != null &&
        widget.order.otp!.isNotEmpty);

    if (enRoute) {
      return _CompactOrderStrip(
        order: widget.order,
        items: items,
        showOtp: showOtp,
        onViewDetails: widget.onViewDetails,
      );
    }

    // ── Pre-pickup full card ─────────────────────────────────────────────────
    final bool orderReceived =
        (status != null && status != OrderStatus.pending) ||
        widget.order.paymentStatus == 'paid';
    final bool kitchenInProgress =
        status == OrderStatus.processing ||
        status == OrderStatus.handover ||
        status == OrderStatus.pickedUp ||
        status == OrderStatus.delivered;
    final bool riderAssigned =
        widget.order.deliveryMan != null &&
        (status?.isDeliveryAssigned ?? false);
    return Column(
      children: [
        // OTP above the card when visible — it's the most urgent info
        if (showOtp) ...[
          _OtpBlock(otp: widget.order.otp!),
          const SizedBox(height: 10),
        ],

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Item header ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: _ItemHeader(
                  items: items,
                  onViewDetails: widget.onViewDetails,
                ),
              ),

              // ── Progress bar — gamified step indicator ───────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _StepProgressBar(
                  steps: 3,
                  completed: (orderReceived ? 1 : 0) +
                      (kitchenInProgress ? 1 : 0) +
                      (riderAssigned ? 1 : 0),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _OrderTimeline(
                  orderReceived: orderReceived,
                  kitchenInProgress: kitchenInProgress,
                  riderAssigned: riderAssigned,
                  status: status,
                ),
              ),

              const SizedBox(height: 16),

              // ── Footer ────────────────────────────────────────────────────
              _CardFooter(order: widget.order),
            ],
          ),
        ),
      ],
    );
  }

}

// ─── Compact strip shown during en-route ──────────────────────────────────────
class _CompactOrderStrip extends StatelessWidget {
  final OrderModel order;
  final List<OrderDetailsModel> items;
  final bool showOtp;
  final VoidCallback? onViewDetails;

  const _CompactOrderStrip({
    required this.order,
    required this.items,
    required this.showOtp,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // OTP block first — highest priority when rider is at the door
        if (showOtp) ...[
          _OtpBlock(otp: order.otp!),
          const SizedBox(height: 10),
        ],

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Item thumbnail
              _ItemThumb(items: items, size: 52),
              const SizedBox(width: 12),
              // Summary
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items.isEmpty
                          ? 'Your order'
                          : items.length == 1
                          ? '1 ${'item'.tr}'
                          : '${items.length} ${'items'.tr}',
                      style: waddyBodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: WaddyColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _summary(items),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: waddyMicro.copyWith(
                        color: WaddyColors.inkLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Order ID chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: WaddyColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: WaddyColors.divider),
                ),
                child: Text(
                  '#${order.id}',
                  style: waddyMicro.copyWith(
                    color: WaddyColors.inkMid,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _summary(List<OrderDetailsModel> items) {
    if (items.isEmpty) return 'Order items';
    final names =
        items
            .take(2)
            .map((i) => i.itemDetails?.name)
            .whereType<String>()
            .where((n) => n.trim().isNotEmpty)
            .toList();
    if (names.isEmpty) return 'Order items';
    if (names.length == 1) return names.first;
    return '${names.first} · ${names[1]}${items.length > 2 ? ' +${items.length - 2}' : ''}';
  }
}

// ─── Item Header ──────────────────────────────────────────────────────────────
class _ItemHeader extends StatelessWidget {
  final List<OrderDetailsModel> items;
  final VoidCallback? onViewDetails;

  const _ItemHeader({required this.items, this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ItemThumb(items: items, size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Large numeral count — the headline of the card
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${items.isEmpty ? 1 : items.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 30,
                      color: WaddyColors.ink,
                      height: 1.0,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    items.length == 1 ? 'item'.tr : 'items'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: WaddyColors.inkMid,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _summary(items),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: waddyBody.copyWith(
                  color: WaddyColors.inkLight,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        if (onViewDetails != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onViewDetails,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: WaddyColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'View',
                style: waddyLabel.copyWith(
                  color: WaddyColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _summary(List<OrderDetailsModel> items) {
    if (items.isEmpty) {
      return 'Item list will appear once confirmed.';
    }
    final names =
        items
            .take(2)
            .map((i) => i.itemDetails?.name)
            .whereType<String>()
            .where((n) => n.trim().isNotEmpty)
            .toList();
    if (names.isEmpty) return 'Getting your order details\u2026';
    if (names.length == 1) return names.first;
    return '${names.first} · ${names[1]}${items.length > 2 ? ' +${items.length - 2} more' : ''}';
  }
}

// ─── Item Thumbnail ────────────────────────────────────────────────────────────
class _ItemThumb extends StatelessWidget {
  final List<OrderDetailsModel> items;
  final double size;

  const _ItemThumb({required this.items, required this.size});

  @override
  Widget build(BuildContext context) {
    final String? image = items.isNotEmpty ? items.first.imageFullUrl : null;
    final int more = items.length > 1 ? items.length - 1 : 0;
    final double badgeSize = size * 0.4;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: WaddyColors.primarySurface,
              borderRadius: BorderRadius.circular(size * 0.26),
              border: Border.all(color: WaddyColors.divider),
            ),
            child:
                image != null && image.isNotEmpty
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(size * 0.26),
                      child: CustomImage(
                        image: image,
                        fit: BoxFit.cover,
                        height: size,
                        width: size,
                      ),
                    )
                    : Center(
                      child: Icon(
                        Icons.fastfood_rounded,
                        color: WaddyColors.primary,
                        size: size * 0.44,
                      ),
                    ),
          ),
          if (more > 0)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: WaddyColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: WaddyColors.surface, width: 1.5),
                ),
                child: Text(
                  '+$more',
                  style: waddyMicro.copyWith(
                    color: WaddyColors.mint,
                    fontWeight: FontWeight.w800,
                    fontSize: badgeSize * 0.45,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Order Timeline ────────────────────────────────────────────────────────────
class _OrderTimeline extends StatelessWidget {
  final bool orderReceived;
  final bool kitchenInProgress;
  final bool riderAssigned;
  final OrderStatus? status;

  const _OrderTimeline({
    required this.orderReceived,
    required this.kitchenInProgress,
    required this.riderAssigned,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left rail: dots + connectors
          SizedBox(
            width: 32,
            child: Column(
              children: [
                _Dot(active: orderReceived, icon: Icons.storefront_rounded),
                _Rail(active: kitchenInProgress),
                _Dot(
                  active: kitchenInProgress,
                  icon: Icons.soup_kitchen_rounded,
                ),
                _Rail(active: riderAssigned),
                _Dot(
                  active: riderAssigned,
                  icon: Icons.two_wheeler_rounded,
                  pulse: !riderAssigned,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepLabel(
                  title: 'Order received',
                  subtitle:
                      orderReceived
                          ? 'The restaurant has your order!'
                          : 'Sent! Waiting for confirmation\u2026',
                  active: orderReceived,
                  minHeight: 52,
                ),
                const SizedBox(height: 8),
                _StepLabel(
                  title: 'Preparing your meal',
                  subtitle:
                      kitchenInProgress
                          ? 'Your meal is being freshly prepared.'
                          : 'The kitchen gets started once confirmed.',
                  active: kitchenInProgress,
                  minHeight: 52,
                ),
                const SizedBox(height: 8),
                _StepLabel(
                  title: riderAssigned ? 'Rider on the way!' : 'Finding a rider',
                  subtitle:
                      riderAssigned
                          ? _riderLabel(status)
                          : 'Matching you with the nearest rider\u2026',
                  active: riderAssigned,
                  minHeight: 44,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _riderLabel(OrderStatus? s) {
    switch (s) {
      case OrderStatus.handover:
      case OrderStatus.pickedUp:
        return 'Rider picked up your order — sit tight!';
      case OrderStatus.delivered:
        return 'Delivered! Enjoy every bite.';
      default:
        return 'Rider is heading to the restaurant.';
    }
  }
}

// ─── Timeline Dot ─────────────────────────────────────────────────────────────
class _Dot extends StatefulWidget {
  final bool active;
  final IconData icon;
  final bool pulse;

  const _Dot({required this.active, required this.icon, this.pulse = false});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.pulse && !widget.active) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    if (widget.active) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    } else if (widget.pulse) {
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
    return ScaleTransition(
      scale: _scale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              widget.active ? WaddyColors.primary : WaddyColors.surfaceRaised,
          border: Border.all(
            color: widget.active ? WaddyColors.primary : WaddyColors.divider,
            width: widget.active ? 0 : 1.5,
          ),
          boxShadow:
              widget.active
                  ? [
                    BoxShadow(
                      color: WaddyColors.primary.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : null,
        ),
        child: Center(
          child: Icon(
            widget.active ? Icons.check_rounded : widget.icon,
            size: 15,
            color: widget.active ? WaddyColors.mint : WaddyColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

// ─── Timeline Rail ─────────────────────────────────────────────────────────────
class _Rail extends StatelessWidget {
  final bool active;
  const _Rail({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          width: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color:
                active
                    ? WaddyColors.primary.withValues(alpha: 0.40)
                    : WaddyColors.divider,
          ),
        ),
      ),
    );
  }
}

// ─── Step Label ────────────────────────────────────────────────────────────────
class _StepLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final double minHeight;

  const _StepLabel({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: active
          ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: active ? WaddyColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 350),
              style: waddyBodyMedium.copyWith(
                fontSize: 13.5,
                color: active ? WaddyColors.ink : WaddyColors.inkMuted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(title),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: waddyMicro.copyWith(
                fontSize: 12,
                color: active ? WaddyColors.inkLight : WaddyColors.inkMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── OTP Block ────────────────────────────────────────────────────────────────
class _OtpBlock extends StatefulWidget {
  final String otp;
  const _OtpBlock({required this.otp});

  @override
  State<_OtpBlock> createState() => _OtpBlockState();
}

class _OtpBlockState extends State<_OtpBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glow = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.otp));
    HapticFeedback.lightImpact();
    if (!mounted) return;

    setState(() => _copied = true);
    Future.delayed(
      const Duration(seconds: 2),
      () => mounted ? setState(() => _copied = false) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder:
          (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D3B38), Color(0xFF134E4A)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: WaddyColors.primary.withValues(
                    alpha: 0.20 + _glow.value * 0.18,
                  ),
                  blurRadius: 18 + _glow.value * 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: WaddyColors.mint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: WaddyColors.mint.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: WaddyColors.mint,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR DELIVERY PIN',
                              style: waddyMicro.copyWith(
                                color: WaddyColors.mint,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Show this to your rider when they arrive.',
                              style: waddyMicro.copyWith(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Copy button
                      Semantics(
                        button: true,
                        label:
                            _copied
                                ? 'Delivery PIN copied'
                                : 'Copy delivery PIN',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _copy,
                            borderRadius: BorderRadius.circular(999),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _copied
                                        ? WaddyColors.mint.withValues(
                                          alpha: 0.12,
                                        )
                                        : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color:
                                      _copied
                                          ? WaddyColors.mint.withValues(
                                            alpha: 0.35,
                                          )
                                          : Colors.white.withValues(
                                            alpha: 0.14,
                                          ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child:
                                        _copied
                                            ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: WaddyColors.mint,
                                              size: 16,
                                              key: ValueKey('ok'),
                                            )
                                            : Icon(
                                              Icons.copy_rounded,
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                              size: 16,
                                              key: const ValueKey('cp'),
                                            ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _copied ? 'Copied' : 'Copy',
                                    style: waddyLabel.copyWith(
                                      color:
                                          _copied
                                              ? WaddyColors.mint
                                              : Colors.white.withValues(
                                                alpha: 0.84,
                                              ),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Digit tiles
                  Row(
                    children:
                        widget.otp.split('').map((digit) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Container(
                                height: 58,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: WaddyColors.mint.withValues(
                                      alpha: 0.30,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  digit,
                                  style: waddyDisplay.copyWith(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

// ─── Card Footer ──────────────────────────────────────────────────────────────
class _CardFooter extends StatelessWidget {
  final OrderModel order;
  const _CardFooter({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: WaddyColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ORDER ID',
                style: waddyMicro.copyWith(
                  color: WaddyColors.inkMuted,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '#${order.id}',
                style: waddyTitle.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  color: WaddyColors.primary,
                  letterSpacing: -0.4,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const Spacer(),
          _PaymentChip(method: order.paymentMethod),
        ],
      ),
    );
  }
}

// ─── Payment Chip ──────────────────────────────────────────────────────────────
class _PaymentChip extends StatelessWidget {
  final String? method;
  const _PaymentChip({this.method});

  @override
  Widget build(BuildContext context) {
    final label = _label();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: WaddyColors.primarySurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: WaddyColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.payments_outlined,
            size: 13,
            color: WaddyColors.primary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: waddyLabel.copyWith(
              color: WaddyColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  String _label() {
    switch (method) {
      case 'cash_on_delivery':
        return 'Cash on delivery';
      case 'wallet':
        return 'Wallet';
      case 'partial_payment':
        return 'Partial payment';
      case 'offline_payment':
        return 'Offline payment';
      default:
        return 'Digital payment';
    }
  }
}

// ─── Step Progress Bar (gamified) ──────────────────────────────────────────────
// Shows filled dots + animated bar for 3-step order progress.
class _StepProgressBar extends StatelessWidget {
  final int steps;
  final int completed;

  const _StepProgressBar({required this.steps, required this.completed});

  String _stepLabel() {
    // Show where in the flow the user is, not a generic count
    switch (completed) {
      case 0:
        return 'Waiting for restaurant';
      case 1:
        return 'Restaurant confirmed';
      case 2:
        return 'Kitchen preparing';
      case 3:
        return 'Rider assigned';
      default:
        return completed >= steps ? 'Ready for pickup' : 'Step $completed of $steps';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double fraction = steps > 0 ? (completed / steps).clamp(0.0, 1.0) : 0;

    return Column(
      children: [
        // Track + fill
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                // Track
                Container(
                  decoration: BoxDecoration(
                    color: WaddyColors.progressTrack,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Fill
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  widthFactor: fraction,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [WaddyColors.primary, WaddyColors.mintDark],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Step dots + label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: List.generate(steps, (i) {
                final bool done = i < completed;
                return Padding(
                  padding: EdgeInsets.only(right: i < steps - 1 ? 4.0 : 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? WaddyColors.mintDark : WaddyColors.progressTrack,
                      border: Border.all(
                        color: done
                            ? WaddyColors.mintDark
                            : WaddyColors.inkMuted.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                );
              }),
            ),
            Text(
              _stepLabel(),
              style: waddyMicro.copyWith(
                color: completed == steps
                    ? WaddyColors.mintDark
                    : WaddyColors.inkLight,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Animated Fractionally Sized Box ───────────────────────────────────────────
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final AlignmentGeometry alignment;
  final Widget? child;

  const AnimatedFractionallySizedBox({
    super.key,
    required this.widthFactor,
    this.alignment = Alignment.center,
    this.child,
    required super.duration,
    super.curve,
  });

  @override
  AnimatedFractionallySizedBoxState createState() =>
      AnimatedFractionallySizedBoxState();
}

class AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
      (v) => Tween<double>(begin: v as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: _widthFactor?.evaluate(animation) ?? widget.widthFactor,
      alignment: widget.alignment,
      child: widget.child,
    );
  }
}
