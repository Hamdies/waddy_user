import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Paper colour of the dashed rules — one step warmer than [WaddyColors.divider]
/// so the dashes read as ink on paper rather than as a UI separator.
const Color _ruleInk = Color(0xFFD5DEDC);

/// Receipt type. Neither Plex Mono nor any bundled mono ships with the app, so
/// this leans on the platform mono (Droid Sans Mono / Menlo). Arabic glyphs
/// fall through to the system Arabic face, which is fine for item names.
const TextStyle _mono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Courier New', 'Courier'],
  fontSize: 12.5,
  height: 1.4,
  letterSpacing: 0.25,
  color: WaddyColors.ink,
);

/// Paper feeding out of a receipt printer: fast at first, easing into the
/// tear-off, with [steps] stepper-motor stutters along the way. Each stutter
/// is a flat spot in the curve (the derivative of `e - sin(2πne)/2πn` is
/// `1 - cos(2πne)`, which touches zero n times), so the paper visibly pauses
/// rather than just wobbling.
class PrinterFeedCurve extends Curve {
  final int steps;
  const PrinterFeedCurve({this.steps = 12});

  @override
  double transformInternal(double t) {
    final double e = 1 - math.pow(1 - t, 1.6).toDouble();
    final double p =
        e - math.sin(2 * math.pi * steps * e) / (2 * math.pi * steps);
    return p.clamp(0.0, 1.0);
  }
}

/// The mint printer mouth the receipt feeds out of. Sits above the scroll
/// area; the receipt slides out from underneath it.
class ReceiptPrinterSlot extends StatelessWidget {
  const ReceiptPrinterSlot({super.key});

  static const double height = 26;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 5),
      alignment: Alignment.bottomCenter,
      decoration: const BoxDecoration(
        color: WaddyColors.mint,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(13),
          bottom: Radius.circular(Dimensions.radiusSmall),
        ),
        boxShadow: [
          BoxShadow(
            color: WaddyColors.shadowDeep,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: WaddyColors.primary,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// The printed order receipt: store, order number and time, payment, who and
/// where, line items, the money breakdown and what the customer saved.
class OrderReceiptWidget extends StatelessWidget {
  final OrderModel order;
  final List<OrderDetailsModel>? details;
  const OrderReceiptWidget({
    super.key,
    required this.order,
    required this.details,
  });

  static const double _zigzagHeight = 8;

  @override
  Widget build(BuildContext context) {
    final double tax = order.totalTaxAmount ?? 0;
    final double tips = order.dmTips ?? 0;
    final double delivery = order.deliveryCharge ?? 0;
    final double service = order.additionalCharge ?? 0;
    final double packaging = order.extraPackagingAmount ?? 0;
    final double coupon = order.couponDiscountAmount ?? 0;
    final double storeDiscount = order.storeDiscountAmount ?? 0;
    final double flashDiscount =
        (order.flashAdminDiscountAmount ?? 0) +
        (order.flashStoreDiscountAmount ?? 0);
    final double referral = order.referrerBonusAmount ?? 0;
    final double total = order.orderAmount ?? 0;
    final bool partial = order.paymentMethod == 'partial_payment';
    final double balance = partial ? (order.partiallyPaidAmount ?? 0) : 0;

    // Items are priced from the lines themselves. Before the details land,
    // back the subtotal out of the total so the receipt still adds up.
    final double subtotal =
        (details != null && details!.isNotEmpty)
            ? details!.fold(0.0, (sum, d) => sum + _lineTotal(d))
            : total -
                tax -
                tips -
                delivery -
                service -
                packaging +
                coupon +
                storeDiscount +
                flashDiscount +
                referral;
    final double saved = coupon + storeDiscount + flashDiscount + referral;

    final String? code = order.couponCode;
    final String? arrivingWindow = _arrivingWindow();
    final bool takeAway = order.orderType == 'take_away';
    final String? customer = order.deliveryAddress?.contactPersonName;
    final String? deliverTo = takeAway ? null : _addressLine();

    return PhysicalShape(
      clipper: const _ReceiptClipper(zigzag: _zigzagHeight),
      color: WaddyColors.surface,
      elevation: 6,
      shadowColor: WaddyColors.shadowTeal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Dimensions.paddingSizeExtraLarge,
          Dimensions.paddingSizeExtraOverLarge,
          Dimensions.paddingSizeExtraLarge,
          Dimensions.paddingSizeExtraLarge + _zigzagHeight,
        ),
        child: DefaultTextStyle(
          style: _mono,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.only(
                  bottom: Dimensions.paddingSizeLarge,
                ),
                child: Column(
                  children: [
                    Text(
                      displayCaps(order.store?.name ?? ''),
                      textAlign: TextAlign.center,
                      style: waddyDisplayFace(
                        26,
                        weight: FontWeight.w900,
                        tracking: -0.01,
                        color: WaddyColors.primary,
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                    Text(
                      'Nº ${order.id ?? ''}',
                      style: const TextStyle(color: WaddyColors.inkLight),
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                    if (_placedAt() != null)
                      Text(
                        '- ${_placedAt()} -',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        textDirection: TextDirection.ltr,
                      ),
                  ],
                ),
              ),

              // ── Payment ──
              _Section(children: [_Line('payment'.tr, _paymentLabel())]),

              // ── Who / where / when ──
              if (customer != null && customer.isNotEmpty ||
                  deliverTo != null ||
                  arrivingWindow != null)
                _Section(
                  children: [
                    if (customer != null && customer.isNotEmpty)
                      _Line('customer'.tr, customer),
                    if (deliverTo != null) _Line('deliver_to'.tr, deliverTo),
                    if (arrivingWindow != null)
                      _Line('arriving'.tr, arrivingWindow, ltrValue: true),
                  ],
                ),

              // ── Items ──
              if (details != null && details!.isNotEmpty)
                _Section(
                  children: [
                    for (final d in details!)
                      _Line(
                        '${d.quantity ?? 1}x ${d.itemDetails?.name ?? ''}',
                        PriceConverter.convertPrice(_lineTotal(d)),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                        valueStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                        ltrValue: true,
                      ),
                  ],
                ),

              // ── Breakdown ──
              _Section(
                gap: 7,
                muted: true,
                children: [
                  _money('subtotal'.tr, subtotal),
                  if (delivery > 0) _money('delivery_fee'.tr, delivery),
                  if (service > 0) _money('service_fee'.tr, service),
                  if (packaging > 0) _money('extra_packaging'.tr, packaging),
                  if (tax > 0) _money('tax'.tr, tax),
                  if (tips > 0) _money('rider_tip'.tr, tips),
                  if (storeDiscount + flashDiscount > 0)
                    _money(
                      'discount'.tr,
                      storeDiscount + flashDiscount,
                      credit: true,
                    ),
                  if (coupon > 0)
                    _money(
                      code != null && code.isNotEmpty
                          ? 'promo_with_code'.trParams({
                            'code': code.toUpperCase(),
                          })
                          : 'coupon_discount'.tr,
                      coupon,
                      credit: true,
                    ),
                  if (referral > 0)
                    _money('referral_discount'.tr, referral, credit: true),
                  if (balance > 0)
                    _money('balance_used'.tr, balance, credit: true),
                ],
              ),

              // ── Total ──
              _Rule(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: Dimensions.paddingSizeLarge,
                    bottom: Dimensions.paddingSizeLarge,
                  ),
                  child: _Line(
                    'total'.tr,
                    PriceConverter.convertPrice(total - balance),
                    labelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    valueStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    ltrValue: true,
                  ),
                ),
              ),

              // ── Saved ──
              if (saved > 0)
                _Rule(
                  bottom: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: Dimensions.paddingSizeMedium,
                    ),
                    // "Waddy!" is the Egyptian-slang pun (واضي), on purpose.
                    child: Text(
                      displayCaps(
                        '${'waddy_you_saved'.tr} ${PriceConverter.convertPrice(saved)}',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: WaddyColors.mintInk,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _lineTotal(OrderDetailsModel d) {
    final int qty = d.quantity ?? 1;
    final double addOns = (d.addOns ?? const []).fold(
      0.0,
      (sum, a) => sum + (a.price ?? 0) * (a.quantity ?? 1),
    );
    return (d.price ?? 0) * qty + addOns;
  }

  Widget _money(String label, double value, {bool credit = false}) => _Line(
    label,
    '${credit ? '−' : ''}${PriceConverter.convertPrice(value)}',
    labelStyle: credit ? const TextStyle(color: WaddyColors.mintInk) : null,
    valueStyle: credit ? const TextStyle(color: WaddyColors.mintInk) : null,
    ltrValue: true,
  );

  DateTime? _parse(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s) ?? DateTime.tryParse(s.replaceFirst(' ', 'T'));
  }

  /// "THU 25 SEP 2026 | 9:53 PM"
  String? _placedAt() {
    final DateTime? dt = _parse(order.createdAt);
    if (dt == null) return null;
    return DateFormat('EEE dd MMM yyyy | h:mm a').format(dt).toUpperCase();
  }

  /// Clock window around the backend ETA ("10:20 - 10:30 PM"), matching the
  /// ±5 min range [OrderModel.estimatedDelivery] shows as a duration. Null
  /// until the store confirms and the backend sets the ETA.
  String? _arrivingWindow() {
    final DateTime? eta = _parse(order.estimatedDeliveryAt);
    if (eta == null || eta.isBefore(DateTime.now())) return null;
    final DateTime lo = eta.subtract(const Duration(minutes: 5));
    final DateTime hi = eta.add(const Duration(minutes: 5));
    final bool samePeriod =
        DateFormat('a').format(lo) == DateFormat('a').format(hi);
    final String from = DateFormat(samePeriod ? 'h:mm' : 'h:mm a').format(lo);
    return '$from - ${DateFormat('h:mm a').format(hi)}';
  }

  String? _addressLine() {
    final a = order.deliveryAddress;
    if (a == null) return null;
    final List<String> parts = [
      if ((a.address ?? '').isNotEmpty) a.address!,
      if ((a.streetNumber ?? '').isNotEmpty) a.streetNumber!,
      if ((a.floor ?? '').isNotEmpty) '${'floor'.tr} ${a.floor}',
      if ((a.house ?? '').isNotEmpty) '${'house'.tr} ${a.house}',
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  String _paymentLabel() {
    final String? method = order.paymentMethod;
    switch (method) {
      case 'cash_on_delivery':
      case 'digital_payment':
      case 'partial_payment':
      case 'wallet':
        return method!.tr;
      default:
        return method?.replaceAll('_', ' ').capitalizeFirst ?? '';
    }
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

/// A block of lines under a dashed rule.
class _Section extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final bool muted;
  const _Section({required this.children, this.gap = 9, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
    return _Rule(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child:
            muted
                ? DefaultTextStyle.merge(
                  style: const TextStyle(color: WaddyColors.inkLight),
                  child: column,
                )
                : column,
      ),
    );
  }
}

/// Label on the start edge, value on the end edge. Labels that are field names
/// (Payment, Customer…) are muted; item lines pass their own style.
class _Line extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool ltrValue;
  const _Line(
    this.label,
    this.value, {
    this.labelStyle,
    this.valueStyle,
    this.ltrValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            label,
            style: labelStyle ?? const TextStyle(color: WaddyColors.inkLight),
          ),
        ),
        const SizedBox(width: Dimensions.paddingSizeMedium),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: valueStyle,
            textDirection: ltrValue ? TextDirection.ltr : null,
          ),
        ),
      ],
    );
  }
}

/// Wraps [child] with a dashed rule on top (and optionally the bottom).
class _Rule extends StatelessWidget {
  final Widget child;
  final bool bottom;
  const _Rule({required this.child, this.bottom = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const _Dashes(), child, if (bottom) const _Dashes()],
    );
  }
}

class _Dashes extends StatelessWidget {
  const _Dashes();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 1.5,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter()),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = _ruleInk
          ..strokeWidth = size.height;
    const double dash = 4.5, gap = 3;
    final double y = size.height / 2;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Rectangle with a torn sawtooth bottom edge, 16pt teeth.
class _ReceiptClipper extends CustomClipper<Path> {
  final double zigzag;
  const _ReceiptClipper({required this.zigzag});

  @override
  Path getClip(Size size) {
    const double tooth = 16;
    final double base = size.height - zigzag;
    final Path path =
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, base);
    // Walk back right-to-left so the path closes cleanly at the origin.
    double x = size.width;
    while (x > 0) {
      final double mid = math.max(x - tooth / 2, 0);
      final double next = math.max(x - tooth, 0);
      path
        ..lineTo(mid, size.height)
        ..lineTo(next, base);
      x = next;
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _ReceiptClipper oldClipper) =>
      oldClipper.zigzag != zigzag;
}
