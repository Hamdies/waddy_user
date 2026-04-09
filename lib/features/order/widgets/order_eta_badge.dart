import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class OrderEtaBadge extends StatefulWidget {
  final int? minutes;

  const OrderEtaBadge({super.key, required this.minutes});

  static double badgeSizeFor(bool isMobile) => isMobile ? 138 : 182;
  static double bottomPillOverlapFor(bool isMobile) => isMobile ? 14 : 14;

  @override
  State<OrderEtaBadge> createState() => _OrderEtaBadgeState();
}

class _OrderEtaBadgeState extends State<OrderEtaBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseShadow;

  @override
  void initState() {
    super.initState();

    // Breathing pulse — slow, calming (2.4s cycle)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseShadow = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int minEta = widget.minutes ?? 0;
    final int maxEta = minEta > 0 ? minEta + 10 : 0;
    final bool isWaiting = minEta <= 0;

    final bool isMobile = ResponsiveHelper.isMobile(context);
    final double badgeSize = OrderEtaBadge.badgeSizeFor(isMobile);
    final double badgeFontSize = isMobile ? 10 : 12;
    final double badgeEtaFontSize = isMobile ? 30 : 40;
    final double statusHorizontalPadding = isMobile ? 22 : 28;
    final double bottomPillOverlap = OrderEtaBadge.bottomPillOverlapFor(isMobile);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Breathing outer glow ring (only when waiting)
        if (isWaiting)
          AnimatedBuilder(
            animation: _pulseShadow,
            builder: (_, __) => Container(
              width: badgeSize + 16,
              height: badgeSize + 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WaddyColors.mint.withValues(alpha: _pulseShadow.value * 0.18),
              ),
            ),
          ),

        // Main badge with breathing scale
        AnimatedBuilder(
          animation: _pulseScale,
          builder: (_, child) => Transform.scale(
            scale: isWaiting ? _pulseScale.value : 1.0,
            child: child,
          ),
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [WaddyColors.primaryLight, WaddyColors.primary],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: const [
                BoxShadow(
                  color: WaddyColors.shadowDeep,
                  blurRadius: 36,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'arrival_in'.tr,
                  style: waddyMicro.copyWith(
                    fontSize: badgeFontSize,
                    color: Colors.white.withValues(alpha: 0.92),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                // ETA number — animate changes
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: anim,
                        curve: Curves.easeOutQuart,
                      )),
                      child: child,
                    ),
                  ),
                  child: Text(
                    minEta > 0 ? '$minEta-$maxEta' : '--',
                    key: ValueKey(minEta),
                    style: waddyDisplay.copyWith(
                      fontSize: badgeEtaFontSize,
                      color: WaddyColors.mint,
                      height: 0.95,
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  'mins'.tr,
                  style: waddyMicro.copyWith(
                    fontSize: isMobile ? 10 : 12,
                    color: Colors.white.withValues(alpha: 0.92),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Status pill — animates content changes
        Positioned(
          bottom: -bottomPillOverlap,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: Container(
              key: ValueKey(minEta > 0),
              padding: EdgeInsets.symmetric(
                horizontal: statusHorizontalPadding,
                vertical: isMobile ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: WaddyColors.mint.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: WaddyColors.mint.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                minEta > 0
                    ? 'on_time'.tr
                    : '⏳ ${'hang_tight'.tr.isNotEmpty ? 'hang_tight'.tr : 'Hang tight'}',
                style: waddyLabel.copyWith(
                  fontSize: isMobile
                      ? Dimensions.fontSizeExtraSmall
                      : Dimensions.fontSizeSmall,
                  fontWeight: FontWeight.w700,
                  color: WaddyColors.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
