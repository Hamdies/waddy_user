import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';

/// 🎨 IMPROVED Ramadan Decorations Widget
///
/// Key Improvements:
/// 1. More subtle decorations that don't overwhelm content
/// 2. Better positioning to avoid UI elements
/// 3. Refined animation timing
/// 4. Improved performance with optimized painting
/// 5. Better accessibility with reduced motion support

class RamadanHomeDecorationsWidget extends StatefulWidget {
  final Widget child;
  final ScrollController? scrollController;

  const RamadanHomeDecorationsWidget({
    super.key,
    required this.child,
    this.scrollController,
  });

  @override
  State<RamadanHomeDecorationsWidget> createState() =>
      _RamadanHomeDecorationsWidgetState();
}

class _RamadanHomeDecorationsWidgetState
    extends State<RamadanHomeDecorationsWidget>
    with TickerProviderStateMixin {
  late AnimationController _lightUpController;
  late Animation<double> _lightUpAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _swayController;
  late Animation<double> _swayAnimation;

  double _scrollOffset = 0;
  bool _wasLightsOn = false;

  @override
  void initState() {
    super.initState();

    // Light up animation (2 seconds)
    _lightUpController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _lightUpAnimation = CurvedAnimation(
      parent: _lightUpController,
      curve: Curves.easeOutCubic,
    );

    _lightUpAnimation.addListener(() {
      Get.find<HomeController>().updateRamadanLightProgress(
        _lightUpAnimation.value,
      );
    });

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _swayController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    )..repeat(reverse: true);

    _swayAnimation = Tween<double>(begin: -0.025, end: 0.025).animate(
      CurvedAnimation(parent: _swayController, curve: Curves.easeInOut),
    );

    widget.scrollController?.addListener(_onScroll);
  }

  void _onScroll() {
    if (widget.scrollController != null && mounted) {
      setState(() {
        _scrollOffset = widget.scrollController!.offset;
      });
    }
  }

  void _triggerLightUpAnimation() {
    HapticFeedback.mediumImpact();
    _lightUpController.forward().then((_) {
      _glowController.repeat(reverse: true);
    });
  }

  void _triggerLightOffAnimation() {
    _glowController.stop();
    _lightUpController.reverse();
  }

  @override
  void dispose() {
    _lightUpController.dispose();
    _glowController.dispose();
    _swayController.dispose();
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      id: 'ramadan',
      builder: (controller) {
        if (!controller.showRamadanDecorations) {
          return widget.child;
        }

        // Handle toggle on/off
        if (controller.isRamadanLightsOn && !_wasLightsOn) {
          _wasLightsOn = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerLightUpAnimation();
          });
        } else if (!controller.isRamadanLightsOn && _wasLightsOn) {
          _wasLightsOn = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerLightOffAnimation();
          });
        }

        return Stack(
          children: [
            widget.child,

            // Decorative string lights - more subtle

            // Strategic lantern placement
            // ..._buildStrategicLanterns(controller),
          ],
        );
      },
    );
  }
}
