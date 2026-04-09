import 'package:flutter/material.dart';
import 'package:waddy_app/util/styles.dart';

/// Lerp two colors by [t] (0 = a, 1 = b).
Color mixColor(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

// ─── Banner title used at the top of each game slide ─────────────────────
class LuckySpinBanner extends StatelessWidget {
  final String label;
  final Color primaryColor;
  final Color accentColor;

  const LuckySpinBanner({
    super.key,
    required this.label,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: mixColor(primaryColor, Colors.black, 0.08)
            .withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: robotoBold.copyWith(
          fontSize: 13,
          color: accentColor,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─── Circular icon badge for prize display ───────────────────────────────
class GiftPrizeBadge extends StatelessWidget {
  final Color primaryColor;
  final Color accentColor;
  final IconData icon;

  const GiftPrizeBadge({
    super.key,
    required this.primaryColor,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, mixColor(accentColor, Colors.white, 0.55)],
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 32, color: primaryColor),
    );
  }
}

// ─── CTA button with shadow ──────────────────────────────────────────────
class ShowcaseCta extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const ShowcaseCta({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.padding,
    this.borderColor,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.62 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border:
                  borderColor == null ? null : Border.all(color: borderColor!),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: foregroundColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: robotoBold.copyWith(
                    fontSize: 14,
                    color: foregroundColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Page indicator dots (2 pages) ───────────────────────────────────────
class SlideDots extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDotTap;
  final Color activeColor;
  final Color inactiveColor;

  const SlideDots({
    super.key,
    required this.currentIndex,
    required this.onDotTap,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(2, (int index) {
        final bool isActive = currentIndex == index;
        return GestureDetector(
          onTap: () => onDotTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: EdgeInsets.only(right: index == 1 ? 0 : 8),
            width: isActive ? 16 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: (isActive ? activeColor : inactiveColor).withValues(
                alpha: isActive ? 1 : 0.42,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        );
      }),
    );
  }
}
