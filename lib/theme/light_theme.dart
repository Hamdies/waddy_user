import 'package:flutter/material.dart';
import 'package:waddy_app/util/app_constants.dart';

// ─── Waddy Color System ────────────────────────────────────────────────────────
// Scheme: Split-complementary
//   Primary   #134E4A  teal 177°   — trust, freshness, brand anchor
//   Secondary #1EF2A0  mint 158°   — energy, success, delight
//   Tertiary  #FF6B6B  coral 0°    — warmth, urgency, fun CTAs (complements teal)
//   Warm pop  #FFBE0B  amber 45°   — highlights, badges, playfulness
//
// Shadows: hue-shifted to teal, never pure black
// Surfaces: warm off-white (#FAFAF8) — avoids clinical pure white

class WaddyColors {
  // Brand core
  static const Color primary        = Color(0xFF134E4A); // deep teal
  static const Color primaryLight   = Color(0xFF1D706A); // teal 400
  static const Color primarySurface = Color(0xFFE6F4F3); // teal 50 — tinted bg

  // Accent mint (success, active states)
  static const Color mint           = Color(0xFF1EF2A0); // electric mint
  static const Color mintDark       = Color(0xFF0DC97D); // mint pressed
  static const Color mintSurface    = Color(0xFFE6FCF3); // mint 50

  // Tertiary coral (CTAs, urgency, fun)
  static const Color coral          = Color(0xFFFF6B6B); // coral — warm pop
  static const Color coralDark      = Color(0xFFE84D4D); // coral pressed
  static const Color coralSurface   = Color(0xFFFFEEEE); // coral 50

  // Amber (badges, highlights, "soon" tags)
  static const Color amber          = Color(0xFFFFBE0B); // amber
  static const Color amberSurface   = Color(0xFFFFF8E1); // amber 50

  // Neutrals — warm-tinted, not cold gray
  static const Color ink            = Color(0xFF1A1F1E); // near-black w/ teal tint
  static const Color inkMid         = Color(0xFF3D4744); // body text
  static const Color inkLight       = Color(0xFF6B7876); // secondary text
  static const Color inkMuted       = Color(0xFF9EAAA8); // placeholder/disabled
  static const Color divider        = Color(0xFFE4ECEA); // warm divider

  // Surfaces
  static const Color canvas         = Color(0xFFFAFAF8); // warm off-white bg
  static const Color surface        = Color(0xFFFFFFFF); // card white
  static const Color surfaceRaised  = Color(0xFFF5F7F6); // slightly raised

  // Semantic
  static const Color error          = Color(0xFFE84D4F); // error red
  static const Color errorSurface   = Color(0xFFFFEEEE);
  static const Color success        = Color(0xFF1EF2A0); // reuse mint
  static const Color warning        = Color(0xFFFFBE0B); // reuse amber

  // Shadows — hue-shifted to teal, not black
  static const Color shadowTeal     = Color(0x1A134E4A); // 10% primary
  static const Color shadowDeep     = Color(0x26134E4A); // 15% primary
}

ThemeData light() => ThemeData(
  fontFamily: AppConstants.fontFamily,
  primaryColor: WaddyColors.primary,
  secondaryHeaderColor: WaddyColors.mint,
  disabledColor: WaddyColors.inkMuted,
  brightness: Brightness.light,
  hintColor: WaddyColors.inkMuted,
  cardColor: WaddyColors.surface,
  shadowColor: WaddyColors.shadowTeal,
  scaffoldBackgroundColor: WaddyColors.canvas,
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: WaddyColors.primary),
  ),
  colorScheme: const ColorScheme.light(
    primary:    WaddyColors.primary,
    secondary:  WaddyColors.mint,
    tertiary:   WaddyColors.coral,
    surface:    WaddyColors.surface,
    error:      WaddyColors.error,
    onPrimary:  Colors.white,
    onSecondary: WaddyColors.primary,   // dark text on mint
    onTertiary:  Colors.white,
    onSurface:   WaddyColors.ink,
    onError:     Colors.white,
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: WaddyColors.surface,
    surfaceTintColor: WaddyColors.surface,
  ),
  dialogTheme: const DialogThemeData(surfaceTintColor: WaddyColors.surface),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: WaddyColors.mint,
    foregroundColor: WaddyColors.primary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
  ),
  bottomAppBarTheme: const BottomAppBarThemeData(
    surfaceTintColor: WaddyColors.surface,
    height: 60,
    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    color: WaddyColors.primary,
  ),
  dividerTheme: const DividerThemeData(
    thickness: 0.5,
    color: WaddyColors.divider,
  ),
  tabBarTheme: const TabBarThemeData(
    indicatorColor: WaddyColors.mint,
    labelColor: WaddyColors.mint,
    unselectedLabelColor: WaddyColors.inkLight,
    dividerColor: Colors.transparent,
  ),
);
