import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/order/domain/models/order_details_model.dart';
import 'package:sixam_mart/features/order/widgets/verification_code_widget.dart';
import 'package:sixam_mart/features/order/widgets/order_eta_badge.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class LuckySpinSection extends StatelessWidget {
  final OrderModel order;
  final OrderController orderController;
  final int itemCount;
  final int? liveEtaMinutes;
  final int? prepMinutes;
  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onViewDetails;

  const LuckySpinSection({
    super.key,
    required this.order,
    required this.orderController,
    required this.itemCount,
    required this.liveEtaMinutes,
    required this.prepMinutes,
    required this.onBack,
    required this.onHelp,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final int? displayEta = liveEtaMinutes ?? prepMinutes;

    return Container(
      color: const Color(0xFF051F24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  _buildSpinWheelBackground(context),
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      bottom: false,
                      child: _buildTopBar(context),
                    ),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeLarge,
                  ResponsiveHelper.isMobile(context) ? 260 : 200,
                  Dimensions.paddingSizeLarge,
                  Dimensions.paddingSizeLarge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'order_placed'.tr,
                      style: robotoBold.copyWith(
                        fontSize: ResponsiveHelper.isMobile(context) ? 24 : 28,
                        color: const Color(0xFF112E2C),
                      ),
                    ),
                    SizedBox(height: Dimensions.paddingSizeExtraSmall),
                    Text(
                      'your_order_is_being_processed'.tr,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: const Color(0xFF6A7C79),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: Dimensions.paddingSizeLarge),
                    _buildCombinedOrderCard(context),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: ResponsiveHelper.isMobile(context) ? 280 : 260,
            child: Center(child: OrderEtaBadge(minutes: displayEta)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Material(
          color: const Color(0xFF193A39).withValues(alpha: 0.94),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: ResponsiveHelper.isMobile(context) ? 16 : 18,
              ),
            ),
          ),
        ),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onHelp,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeExtraSmall,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF193A39).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              'help'.tr,
              style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpinWheelBackground(BuildContext context) {
    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF062C30),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0B3840),
                    Color(0xFF082C30),
                    Color(0xFF051F24),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: SpinBackgroundPainter()),
          ),
          Positioned(
            top: 88,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2E32),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFD4A84B),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '✨ ${'lucky_spin'.tr.toUpperCase()} ✨',
                    style: robotoBold.copyWith(
                      fontSize: 12,
                      color: const Color(0xFFFFD770),
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                SizedBox(height: Dimensions.paddingSizeLarge),
                SizedBox(
                  width: 230,
                  height: 230,
                  child: CustomPaint(painter: LuckySpinWheelPainter()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedOrderCard(BuildContext context) {
    final List<OrderDetailsModel> orderDetails =
        orderController.orderDetails ?? const [];
    final bool hasItemImages = orderDetails.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        Dimensions.paddingSizeDefault + Dimensions.paddingSizeExtraSmall,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE6ECEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (hasItemImages)
                _buildItemImagesFan(orderDetails)
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4F2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF184541),
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$itemCount ${'items'.tr}',
                      style: robotoBold.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: const Color(0xFF112E2C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'to_be_packed'.tr,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: const Color(0xFF7B8C89),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onViewDetails,
                child: Text(
                  'view_details'.tr,
                  style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: const Color(0xFF184541),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Dimensions.paddingSizeDefault),
          const Divider(color: Color(0xFFE8EFED), height: 1),
          SizedBox(height: Dimensions.paddingSizeDefault),
          // Step 1: Order received
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1BA672).withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 20,
                  color: Color(0xFF1BA672),
                ),
              ),
              SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: Colors.black87,
                    ),
                    children: [
                      TextSpan(text: '${'yay'.tr}! ${'we_have'.tr} '),
                      TextSpan(
                        text: 'received'.tr,
                        style: robotoBold.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Colors.black87,
                        ),
                      ),
                      TextSpan(text: ' ${'your_order'.tr}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Dimensions.paddingSizeSmall),
          // Dashed divider
          Padding(
            padding: EdgeInsets.only(
              left: ResponsiveHelper.isMobile(context) ? 50 : 54,
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: DashedLinePainter(),
            ),
          ),
          SizedBox(height: Dimensions.paddingSizeSmall),
          // Step 2: Delivery partner
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      order.deliveryMan != null
                          ? const Color(0xFF1BA672).withValues(alpha: 0.12)
                          : Colors.grey.shade100,
                ),
                child: Icon(
                  Icons.delivery_dining_rounded,
                  size: 20,
                  color:
                      order.deliveryMan != null
                          ? const Color(0xFF1BA672)
                          : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  order.deliveryMan != null
                      ? '${'your_delivery_partner_is'.tr} ${order.deliveryMan!.fName ?? ''}'
                      : 'we_will_assign_a_delivery_partner_soon'.tr,
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: Dimensions.paddingSizeLarge + Dimensions.paddingSizeSmall,
          ),
          const Divider(color: Color(0xFFE8EFED), height: 1),
          SizedBox(height: Dimensions.paddingSizeLarge),
          // OTP verification card
          if (order.otp != null && order.otp!.isNotEmpty)
            VerificationCodeWidget(otp: order.otp!, variant: VerificationCodeVariant.compact),
          if (order.otp != null && order.otp!.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Divider(color: Color(0xFFE8EFED), height: 1),
            const SizedBox(height: 6),
          ],
          // Order ID + Payment method row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'order_id'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: const Color(0xFF7B8C89),
                    ),
                  ),
                  SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Text(
                    '#${order.id}',
                    style: robotoBold.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: const Color(0xFF184541),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (order.paymentMethod != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECF3F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD8E4E0)),
                  ),
                  child: Text(
                    order.paymentMethod!.replaceAll('_', ' ').tr,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: const Color(0xFF184541),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemImagesFan(List<OrderDetailsModel> items) {
    final List<OrderDetailsModel> display = items.take(3).toList();
    final double fanWidth = 46 + 18.0 * (display.length - 1).clamp(0, 2);
    final List<double> angles = [-0.22, 0.0, 0.22];

    return SizedBox(
      width: fanWidth,
      height: 52,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: List.generate(display.length, (i) {
          return Positioned(
            left: i * 18.0,
            top: 3,
            child: Transform.rotate(
              angle: angles[i],
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    '${display[i].imageFullUrl}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Custom Painters ─────────────────────────────────────────────────────────

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = const Color(0xFFDDDDDD)
          ..strokeWidth = 1;
    const double dashWidth = 6;
    const double dashSpace = 4;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SpinBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint stripePaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.01),
            ],
          ).createShader(rect);

    for (double x = -40; x < size.width + 40; x += 34) {
      final Path stripe =
          Path()
            ..moveTo(x, 0)
            ..lineTo(x + 12, 0)
            ..lineTo(x - 8, size.height)
            ..lineTo(x - 20, size.height)
            ..close();
      canvas.drawPath(stripe, stripePaint);
    }

    final Paint dotPaint =
        Paint()..color = const Color(0xFF96B6AF).withValues(alpha: 0.45);
    const double radius = 1.8;
    for (double x = 20; x < size.width - 20; x += 10) {
      canvas.drawCircle(Offset(x, 28), radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LuckySpinWheelPainter extends CustomPainter {
  static const List<Color> _segmentColors = [
    Color(0xFF6B35B8),
    Color(0xFF2DC982),
    Color(0xFF3A5EE8),
    Color(0xFFE8721A),
    Color(0xFFCC3333),
    Color(0xFF7A8C8A),
  ];

  static const List<String> _labels = [
    'Surprise',
    'Free\nDelivery',
    '10%\nOFF',
    '20%\nOFF',
    '5 EGP\nOFF',
    'Better\nLuck',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2;
    final double sweep = (math.pi * 2) / _segmentColors.length;

    final Paint shadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center + const Offset(0, 12), radius * 0.9, shadowPaint);

    final Paint outerPaint = Paint()..color = const Color(0xFFE1FCEF);
    canvas.drawCircle(center, radius, outerPaint);
    canvas.drawCircle(
      center,
      radius - 8,
      Paint()..color = const Color(0xFF08363B),
    );

    final Rect wheelRect = Rect.fromCircle(center: center, radius: radius - 14);

    for (int i = 0; i < _segmentColors.length; i++) {
      final double startAngle = (-math.pi / 2) + (sweep * i);
      final Paint segmentPaint = Paint()..color = _segmentColors[i];
      canvas.drawArc(wheelRect, startAngle, sweep, true, segmentPaint);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + sweep / 2);

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 72);

      textPainter.paint(canvas, Offset(radius * 0.28, -textPainter.height / 2));
      canvas.restore();
    }

    final Paint ringPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.65);
    canvas.drawCircle(center, radius - 14, ringPaint);

    canvas.drawCircle(
      center,
      26,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(center, 18, Paint()..color = Colors.white);

    final Path pointer =
        Path()
          ..moveTo(center.dx, 4)
          ..lineTo(center.dx - 14, 32)
          ..lineTo(center.dx + 14, 32)
          ..close();
    canvas.drawPath(pointer, Paint()..color = const Color(0xFF1EF2A0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
