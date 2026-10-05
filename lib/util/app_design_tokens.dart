import 'package:flutter/material.dart';

/// Centralized design tokens for consistent UI across the app
class AppDesignTokens {
  AppDesignTokens._();

  // ============================================
  // COLORS - Gamification System
  // ============================================

  /// Warm gold for XP and rewards - creates visual distinction from brand actions
  static const Color gamificationGold = Color(0xFFFFB100);

  /// Light gold for XP backgrounds
  static const Color gamificationGoldLight = Color(0xFFFFF3D6);

  /// Success green for confirmations
  static const Color successGreen = Color(0xFF00C48C);

  /// Premium purple for VIP features
  static const Color premiumPurple = Color(0xFF6366F1);

  /// Error/alert red
  static const Color errorRed = Color(0xFFEF4444);

  /// Dark teal primary
  static const Color primaryDark = Color(0xFF134E4A);

  /// Neon green secondary
  static const Color secondaryNeon = Color(0xFF1EF2A0);

  // ============================================
  // CORNER RADIUS
  // ============================================

  /// Cards and containers
  static const double radiusCard = 16.0;

  /// Buttons
  static const double radiusButton = 12.0;

  /// Small elements (badges, chips)
  static const double radiusSmall = 8.0;

  /// Modal sheets and dialogs
  static const double radiusModal = 24.0;

  /// Extra small (progress bars, indicators)
  static const double radiusXSmall = 4.0;

  // ============================================
  // ELEVATION / SHADOWS
  // ============================================

  /// Level 1 - Category cards
  static const double elevation1 = 2.0;

  /// Level 2 - Cart bar (always visible)
  static const double elevation2 = 4.0;

  /// Level 3 - Modal overlays
  static const double elevation3 = 8.0;

  /// Level 4 - Important alerts
  static const double elevation4 = 16.0;

  /// Standard shadow for cards
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: elevation2,
      offset: const Offset(0, 2),
    ),
  ];

  /// Elevated shadow for cart bar
  static List<BoxShadow> get cartBarShadow => [
    BoxShadow(
      color: primaryDark.withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Modal/drawer shadow
  static List<BoxShadow> get modalShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: elevation3,
      offset: const Offset(0, -4),
    ),
  ];

  // ============================================
  // TOUCH TARGETS (Accessibility)
  // ============================================

  /// Minimum touch target size (Apple: 44px, Material: 48px)
  static const double touchTargetMin = 48.0;

  /// Spacing between interactive elements
  static const double touchTargetSpacing = 8.0;

  // ============================================
  // TYPOGRAPHY
  // ============================================

  /// H1 - Page titles
  static const double fontH1 = 24.0;

  /// H2 - Section headers
  static const double fontH2 = 20.0;

  /// H3 - Card titles
  static const double fontH3 = 16.0;

  /// Body text
  static const double fontBody = 14.0;

  /// Small text (use sparingly)
  static const double fontSmall = 12.0;

  /// Button text
  static const double fontButton = 16.0;

  /// XP counter text
  static const double fontXpCounter = 11.0;

  // ============================================
  // ANIMATION DURATIONS
  // ============================================

  /// Fast micro-interaction
  static const Duration animFast = Duration(milliseconds: 150);

  /// Standard animation
  static const Duration animStandard = Duration(milliseconds: 250);

  /// Slow/emphasized animation
  static const Duration animSlow = Duration(milliseconds: 400);

  /// Spring animation for bouncy effects
  static const Duration animSpring = Duration(milliseconds: 600);
}
