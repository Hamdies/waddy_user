import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class XpPreviewWidget extends StatefulWidget {
  final double orderAmount;

  const XpPreviewWidget({
    super.key,
    required this.orderAmount,
  });

  @override
  State<XpPreviewWidget> createState() => _XpPreviewWidgetState();
}

class _XpPreviewWidgetState extends State<XpPreviewWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  int _displayedXp = 0;
  int _targetXp = 0;
  bool _isAnimating = false;
  bool _configFetched = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    // Fetch XP config if not already loaded
    _fetchXpConfig();
  }

  void _fetchXpConfig() {
    if (_configFetched) return;
    _configFetched = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final xpController = Get.find<XpController>();
      await xpController.getXpConfig();
      if (mounted && widget.orderAmount > 0) {
        _animateXpChange();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(XpPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderAmount != widget.orderAmount) {
      _animateXpChange();
    }
  }

  void _animateXpChange() {
    final xpController = Get.find<XpController>();
    final splashController = Get.find<SplashController>();
    final moduleType = splashController.module?.moduleType;
    
    final newXp = xpController.calculateEstimatedXp(
      widget.orderAmount,
      moduleType,
    );

    if (newXp != _targetXp && newXp > 0) {
      _targetXp = newXp;
      _startCountAnimation();
    }
  }

  void _startCountAnimation() {
    if (_isAnimating) return;
    _isAnimating = true;

    final startXp = _displayedXp;
    final endXp = _targetXp;
    final difference = endXp - startXp;

    // Play scale animation
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Animate the count
    const duration = Duration(milliseconds: 400);
    const steps = 20;
    final stepDuration = duration.inMilliseconds ~/ steps;

    for (int i = 1; i <= steps; i++) {
      Future.delayed(Duration(milliseconds: stepDuration * i), () {
        if (mounted) {
          setState(() {
            _displayedXp = startXp + ((difference * i) ~/ steps);
          });
        }
      });
    }

    Future.delayed(duration, () {
      if (mounted) {
        setState(() {
          _displayedXp = endXp;
          _isAnimating = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only show for logged-in users (not guests)
    if (!AuthHelper.isLoggedIn()) {
      return const SizedBox.shrink();
    }

    return GetBuilder<XpController>(
      builder: (xpController) {
        // Show nothing while loading
        if (xpController.isXpConfigLoading) {
          return const SizedBox.shrink();
        }
        
        // If config failed to load or leveling disabled, hide
        if (xpController.xpConfig == null) {
          return const SizedBox.shrink();
        }
        
        if (!xpController.xpConfig!.levelingEnabled) {
          return const SizedBox.shrink();
        }

        // Calculate XP directly from config
        final splashController = Get.find<SplashController>();
        final moduleType = splashController.module?.moduleType;
        final estimatedXp = xpController.calculateEstimatedXp(
          widget.orderAmount,
          moduleType,
        );

        // Don't show if no XP to earn
        if (estimatedXp <= 0) {
          return const SizedBox.shrink();
        }

        // Update target and animate if changed
        if (estimatedXp != _targetXp) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _targetXp = estimatedXp;
              _startCountAnimation();
            }
          });
        }

        // Show the widget with current displayed XP (or estimated if not yet animated)
        final displayXp = _displayedXp > 0 ? _displayedXp : estimatedXp;

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                margin: const EdgeInsets.only(
                  bottom: Dimensions.paddingSizeSmall,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                  vertical: Dimensions.paddingSizeSmall,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF134E4A),
                      const Color(0xFF0D7377),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1EF2A0).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sparkle/Star icon
                    _buildSparkleIcon(),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    // XP text
                    Text(
                      '+$displayXp XP',
                      style: robotoBold.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        color: const Color(0xFF1EF2A0),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    // Info text
                    Text(
                      'earn_with_order'.tr,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSparkleIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1EF2A0).withValues(alpha: 0.2),
          ),
        ),
        // Star icon
        const Icon(
          Icons.auto_awesome,
          color: Color(0xFF1EF2A0),
          size: 20,
        ),
      ],
    );
  }
}
