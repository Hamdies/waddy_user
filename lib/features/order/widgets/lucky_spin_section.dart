import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/widgets/games/lucky_day_game_slide.dart';
import 'package:waddy_app/features/order/widgets/games/vote_place_game_slide.dart';
import 'package:waddy_app/features/order/widgets/verification_code_widget.dart';
import 'package:waddy_app/features/order/widgets/order_eta_badge.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

const double _luckyShowcaseHeight = 500;

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
    final bool isMobile = ResponsiveHelper.isMobile(context);
    const double spinBackgroundHeight = _luckyShowcaseHeight;
    final double etaBadgeTop = isMobile ? 355 : 335;
    final double etaBadgeBottom =
        etaBadgeTop +
        OrderEtaBadge.badgeSizeFor(isMobile) +
        OrderEtaBadge.bottomPillOverlapFor(isMobile);
    final double contentTopPadding =
        math.max(0, etaBadgeBottom - spinBackgroundHeight) +
        (isMobile ? 22 : 26);

    return Container(
      color:  Theme.of(context).primaryColor,
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
                    top: 0,
                    left: 0,
                    right: 0,
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
                  contentTopPadding,
                  Dimensions.paddingSizeLarge,
                  Dimensions.paddingSizeLarge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'order_placed'.tr,
                      style: robotoBold.copyWith(
                        fontSize: isMobile ? 24 : 28,
                        color: const Color(0xFF112E2C),
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                    Text(
                      'your_order_is_being_processed'.tr,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: const Color(0xFF6A7C79),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                      height: isMobile ? 18 : Dimensions.paddingSizeLarge,
                    ),
                    _buildCombinedOrderCard(context),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: etaBadgeTop,
            child: Center(child: OrderEtaBadge(minutes: displayEta)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Theme(
      data: Theme.of(
        context,
      ).copyWith(iconTheme: const IconThemeData(color: Colors.white)),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          color: Colors.white,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        actions: [
          IconButton(
            color: Colors.white,
            onPressed: onHelp,
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'help'.tr,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSpinWheelBackground(BuildContext context) {
    return const SizedBox(
      height: _luckyShowcaseHeight,
      width: double.infinity,
      child: _LuckyGamesSlider(),
    );
  }

  Widget _buildCombinedOrderCard(BuildContext context) {
    final List<OrderDetailsModel> orderDetails =
        orderController.orderDetails ?? const [];
    final bool hasItemImages = orderDetails.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        Dimensions.paddingSizeDefault + Dimensions.paddingSizeLarge,
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
          const SizedBox(height: Dimensions.paddingSizeDefault),
          const Divider(color: Color(0xFFE8EFED), height: 1),
          const SizedBox(height: Dimensions.paddingSizeDefault),
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
              const SizedBox(width: Dimensions.paddingSizeSmall),
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
          const SizedBox(height: Dimensions.paddingSizeSmall),
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
          const SizedBox(height: Dimensions.paddingSizeSmall),
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
          const SizedBox(height: Dimensions.paddingSizeDefault),
          const Divider(color: Color(0xFFE8EFED), height: 1),
          const SizedBox(height: 12),
          // OTP verification card
          if (order.otp != null && order.otp!.isNotEmpty)
            VerificationCodeWidget(
              otp: order.otp!,
              variant: VerificationCodeVariant.compact,
            ),
          if (order.otp != null && order.otp!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFE8EFED), height: 1),
            const SizedBox(height: 10),
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
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
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
                    errorBuilder:
                        (_, __, ___) => const Icon(Icons.image, size: 20),
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

class _LuckyGamesSlider extends StatefulWidget {
  const _LuckyGamesSlider();

  @override
  State<_LuckyGamesSlider> createState() => _LuckyGamesSliderState();
}

class _LuckyGamesSliderState extends State<_LuckyGamesSlider> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateToPage(int index) {
    if (!_pageController.hasClients || index == _currentIndex) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (int index) {
        if (!mounted) {
          return;
        }
        setState(() => _currentIndex = index);
      },
      children: [
        LuckyDayGameSlide(
          currentIndex: _currentIndex,
          onDotTap: _animateToPage,
        ),
        VotePlaceGameSlide(
          currentIndex: _currentIndex,
          onDotTap: _animateToPage,
        ),
      ],
    );
  }
}

