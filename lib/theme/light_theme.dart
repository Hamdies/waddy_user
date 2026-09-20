import 'package:flutter/material.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';

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
  static const Color primary = Color(0xFF134E4A); // deep teal
  static const Color primaryLight = Color(0xFF1D706A); // teal 400
  static const Color primarySurface = Color(0xFFE6F4F3); // teal 50 — tinted bg
  static const Color onPrimaryMuted = Color(
    0xFF7ECAC3,
  ); // muted teal for text on primary bg

  // ── Accent mint — reserved for CONTROLS ───────────────────────────────────
  // Mint means "press this". Nothing else. It used to be the brand wash, the
  // success colour, the progress fill, the vote tally and the CTA all at once,
  // which is why the eye could not use colour to triage this screen and fell
  // back to "whichever rectangle is biggest".
  static const Color mint = Color(0xFF1EF2A0); // electric mint — CTA only
  static const Color mintDark = Color(0xFF0DC97D); // mint pressed
  static const Color mintSurface = Color(
    0xFFE6FCF3,
  ); // mint 50 — tint, not a control

  /// Mint 100 — one step deeper than [mintSurface], still a tint and still
  /// not a control. It exists so a tinted tile can carry a gradient that
  /// actually reads (mintSurface→white is barely a gradient at all); the
  /// cuisine tiles wash from this at the top down to near-white.
  static const Color mintSurfaceDeep = Color(0xFFD3F6E8);

  /// Mint that is legible as TEXT on a light surface. #1EF2A0 on white is
  /// 1.47:1 — invisible. This is 5.4:1. Use this whenever mint is a glyph on
  /// paper; use [mint] only when it is a filled surface you can press.
  static const Color mintInk = Color(0xFF0A7A50);

  /// [inkLight] that is legible as TEXT on [mintSurface]. inkLight on
  /// mintSurface is 4.28:1 — under the 4.5:1 floor for normal-weight body
  /// text. This is 4.87:1. Use wherever secondary/meta text sits directly on
  /// the mint tint (e.g. the groceries shelf band); [inkLight] stays correct
  /// everywhere else (4.59:1 on plain white).
  static const Color inkLightOnMint = Color(0xFF636F6D);

  // Tertiary coral (CTAs, urgency, fun)
  static const Color coral = Color(0xFFFF6B6B); // coral — warm pop
  static const Color coralDark = Color(0xFFE84D4D); // coral pressed
  static const Color coralSurface = Color(0xFFFFEEEE); // coral 50

  /// Coral that is legible as TEXT on [coralSurface]. [coralDark] is the
  /// *pressed surface* state, and using it for a glyph gives 3.34:1 — under
  /// the 4.5:1 floor at the 12sp these labels actually render (see
  /// Dimensions.fontSizeExtraSmall). This is 5.01:1.
  ///
  /// Same split as [mint]/[mintInk]: the darker step is a surface you press,
  /// this one is ink you read. Do not repoint [coralDark] to fix contrast —
  /// that would darken every pressed coral control in the app.
  static const Color coralInk = Color(0xFFC62828);

  // Amber (badges, highlights, "soon" tags)
  static const Color amber = Color(0xFFFFBE0B); // amber
  static const Color amberSurface = Color(0xFFFFF8E1); // amber 50

  /// Amber that is legible as TEXT on [amberSurface]. The same split as
  /// [mint]/[mintInk] and [coral]/[coralInk]: [amber] itself is a surface you
  /// look at, this is ink you read (5.58:1 on amberSurface, in line with the
  /// ~5:1 the other two inks hold). Do not set label text in [amber] — at
  /// 1.6:1 on its own tint it is unreadable.
  static const Color amberInk = Color(0xFF8A5A00);

  // Neutrals — warm-tinted, not cold gray
  static const Color ink = Color(0xFF1A1F1E); // near-black w/ teal tint
  static const Color inkMid = Color(0xFF3D4744); // body text
  static const Color inkLight = Color(0xFF6B7876); // secondary text
  static const Color inkMuted = Color(0xFF9EAAA8); // placeholder/disabled
  static const Color divider = Color(0xFFE4ECEA); // warm divider

  // Surfaces
  static const Color canvas = Color(0xFFFAFAF8); // warm off-white bg
  static const Color surface = Color(0xFFFFFFFF); // card white
  static const Color surfaceRaised = Color(0xFFF5F7F6); // slightly raised

  /// Warm cream page ground, used by the cart and checkout flows.
  ///
  /// Deliberately WARMER than [surfaceRaised], which is teal-tinted and cool.
  /// The cart is the one place the app wants to feel like paper rather than
  /// screen, so it gets its own ground rather than borrowing the cool one.
  /// Promoted from a hardcoded literal, not invented — this is the value those
  /// screens already shipped.
  static const Color surfaceWarm = Color(0xFFF2F0EB); // warm cream ground
  static const Color surfaceWarmAlt = Color(0xFFF5F2EC); // warm cream, raised

  // Semantic
  static const Color error = Color(0xFFE84D4F); // error red
  static const Color errorSurface = Color(0xFFFFEEEE);

  /// Own green, no longer an alias of [mint]. When success and the CTA were the
  /// same constant, a success toast looked like a button.
  static const Color success = Color(0xFF16A34A); // green 600
  static const Color successSurface = Color(0xFFE9F9EF);
  static const Color warning = Color(0xFFFFBE0B); // reuse amber

  // Energetic hero gradients — playful & warm
  static const Color heroMint = Color(0xFFE2FFF3); // fresh mint bg
  static const Color heroWarm = Color(0xFFFFF3E6); // subtle peach warmth
  static const Color heroLavender = Color(0xFFF3EEFF); // soft lavender accent

  // Progress / gamification
  static const Color progressTrack = Color(0xFFE4ECEA); // neutral track
  /// Deeper than [mint] on purpose: a progress bar is a readout, not a control,
  /// so it must not wear the press colour.
  static const Color progressFill = Color(0xFF0DC97D); // mint 600

  // ── Head-to-head contenders (Spot Battle) ─────────────────────────────────
  // Two hues on the warm/cool axis, which is the one axis that survives red-
  // green colour blindness — the previous bar was mint against a darker mint,
  // indistinguishable under deuteranopia and nearly so for everyone else.
  // Neither is [mint], so the split bar can never be confused with the button
  // underneath it.
  static const Color contenderWarm = Color(0xFFFFBE0B); // amber — side A
  static const Color contenderCool = Color(0xFF38BDF8); // sky   — side B

  // Shadows — hue-shifted to teal, not black
  static const Color shadowTeal = Color(0x1A134E4A); // 10% primary
  static const Color shadowDeep = Color(0x26134E4A); // 15% primary
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
    primary: WaddyColors.primary,
    secondary: WaddyColors.mint,
    tertiary: WaddyColors.coral,
    surface: WaddyColors.surface,
    error: WaddyColors.error,
    onPrimary: Colors.white,
    onSecondary: WaddyColors.primary, // dark text on mint
    onTertiary: Colors.white,
    onSurface: WaddyColors.ink,
    onError: Colors.white,
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
    padding: EdgeInsets.symmetric(
      vertical: 6,
      horizontal: Dimensions.paddingSizeSmall,
    ),
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
