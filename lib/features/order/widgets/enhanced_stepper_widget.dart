import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:flutter/material.dart';

/// Enhanced stepper widget that displays sub-statuses
class EnhancedStepperWidget extends StatelessWidget {
  final bool isActive;
  final bool isCompleted;
  final bool haveLeftBar;
  final bool haveRightBar;
  final String title;
  final String? subStatusText;
  final bool rightActive;
  final bool showPulse;

  const EnhancedStepperWidget({
    super.key,
    required this.title,
    required this.isActive,
    this.isCompleted = false,
    required this.haveLeftBar,
    required this.haveRightBar,
    required this.rightActive,
    this.subStatusText,
    this.showPulse = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color =
        isActive
            ? Theme.of(context).primaryColor
            : Theme.of(context).disabledColor;
    Color right =
        rightActive
            ? Theme.of(context).primaryColor
            : Theme.of(context).disabledColor;

    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child:
                    haveLeftBar
                        ? Divider(color: color, thickness: 2)
                        : const SizedBox(),
              ),
              _buildIcon(context, color),
              Expanded(
                child:
                    haveRightBar
                        ? Divider(color: right, thickness: 2)
                        : const SizedBox(),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: robotoMedium.copyWith(
              color: color,
              fontSize: Dimensions.fontSizeExtraSmall,
            ),
          ),

          // Sub-status text
          if (subStatusText != null && subStatusText!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subStatusText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: robotoRegular.copyWith(
                color: Theme.of(context).primaryColor,
                fontSize: Dimensions.fontSizeOverSmall,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else
            const SizedBox(height: 12), // Maintain consistent height
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context, Color color) {
    if (showPulse && isActive && !isCompleted) {
      // Pulsing animation for active step
      return _PulsingIcon(color: color);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isActive ? 0 : 5),
      child: Icon(
        isActive ? Icons.check_circle : Icons.blur_circular,
        color: color,
        size: isActive ? 25 : 15,
      ),
    );
  }
}

/// Pulsing icon animation for active step
class _PulsingIcon extends StatefulWidget {
  final Color color;
  const _PulsingIcon({required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(
            Icons.radio_button_checked,
            color: widget.color,
            size: 22,
          ),
        );
      },
    );
  }
}
