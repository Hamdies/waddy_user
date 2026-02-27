import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EgyptianPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Filter out non-digits
    String newText = newValue.text.replaceAll(RegExp(r'\D'), '');

    // 2. Prevent leading 0 (User requirement: "Must start with 1")
    if (newText.startsWith('0')) {
      newText = newText.substring(1);
    }

    // 3. Limit to 10 digits
    if (newText.length > 10) {
      newText = newText.substring(0, 10);
    }

    // 4. Format with spaces: 10 1234 5678 (2-4-4 grouping)
    // Matches the "Mobile starts with: 10, 11, 12, 15" guidance + 8 digits
    StringBuffer buffer = StringBuffer();
    int selectionIndex = newValue.selection.end;

    // Adjust selection index for removed leading zero
    if (newValue.text.startsWith('0') && selectionIndex > 0) {
      selectionIndex--;
    }

    for (int i = 0; i < newText.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write(' ');
      }
      buffer.write(newText[i]);
    }

    String formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ShakeWidget extends StatelessWidget {
  final Widget child;
  final AnimationController controller;
  final double shakeOffset;

  const ShakeWidget({
    super.key,
    required this.child,
    required this.controller,
    this.shakeOffset = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double offset =
            ui.lerpDouble(
              0,
              shakeOffset,
              math.sin(controller.value * 3.14 * 3),
            ) ??
            0; // 3 shakes
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: child,
    );
  }
}

class ScaleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onDisabledTap;
  final Widget child;
  final bool enabled;
  final String? tooltip;
  final String? semanticLabel;

  const ScaleButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.enabled = true,
    this.tooltip,
    this.semanticLabel,
    this.onDisabledTap,
  });

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enabled) {
      _controller.forward();
      HapticFeedback.lightImpact();
    } else {
      // Disabled state interaction
      if (widget.onDisabledTap != null) {
        widget.onDisabledTap!();
      }

      if (widget.tooltip != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.tooltip!),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.grey[800],
          ),
        );
      }
      HapticFeedback.selectionClick();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.enabled) {
      _controller.reverse();
      widget.onPressed?.call();
    }
  }

  void _onTapCancel() {
    if (widget.enabled) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      hint: !widget.enabled ? widget.tooltip : null,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
      ),
    );
  }
}
