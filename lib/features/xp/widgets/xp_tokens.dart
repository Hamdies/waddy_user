import 'package:flutter/material.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// XP THEME TOKENS — shared by every XP screen
// ─────────────────────────────────────────────────────────────────────────────
// Moved out of `xp_levels_screen.dart` so the challenges and prizes screens
// stop carrying their own copies of the brand colours (X-27, X-28).
/// The XP surface's slice of the shared Spots system.
///
/// This class used to redeclare `mint`, `teal`, `panel`, `border` and `green`
/// with the same hex values as `Spots`, plus its own radius and spacing scales —
/// two sources of truth for one brand, and the spacing was off the project's 4pt
/// grid (14 and 36). Everything that `Spots` already owns now forwards to it, so
/// a brand change lands in one file.
///
/// What remains are the tokens the dark XP surface genuinely needs and `Spots`
/// (light-mode only) does not define: the darker `foil` hero, the mint and gold
/// washes, the gold achievement accent, and the coral urgency accent.
class XpTokens {
  XpTokens._();

  // ── FORWARDED FROM THE SHARED SYSTEM ──────────────────────────────────
  static const Color mint = Spots.mint;
  static const Color teal = Spots.teal;
  static const Color panel = Spots.panel;
  static const Color green = Spots.green;
  static const Color border = Spots.border;

  // ── XP-ONLY TOKENS ────────────────────────────────────────────────────
  static const Color foil = Color(0xFF0B2A27); // darker foil hero card
  static const Color mint100 = Color(0xFFD6FCEC); // mint wash (toast)

  // ── SEMANTIC ACCENTS ──────────────────────────────────────────────────
  // Each color owns one meaning so the eye can decode state without reading:
  //   mint  → forward progress / XP earned  (dominant)
  //   gold  → achievement — the "crown" win state  (secondary)
  //   coral → urgency — streak at risk, resets soon  (accent)
  static const Color gold = Color(0xFFFFC93C); // won/achieved — crown accent
  static const Color goldInk = Color(0xFF4A3410); // ink on gold surfaces
  static const Color coral = Color(0xFFFF6B4A); // urgency / streak-at-risk

  // Neutrals tinted toward the teal hue rather than flat white — subtle
  // cohesion so overlays read as "part of the canvas", not stickers on it.
  static const Color _tint = Color(0xFFCFF5E9); // pale teal-mint for overlays
  static Color overlay(double a) => _tint.withValues(alpha: a);

  // Text on dark. `onDarkFaint` sat at 0.5, which computes to 4.5:1 on `panel` —
  // a rounding-boundary pass used at 9–9.5sp. Raised to clear AA outright.
  static Color get onDark => Colors.white;
  static Color get onDarkMed => Colors.white.withValues(alpha: 0.62);
  static Color get onDarkFaint => Colors.white.withValues(alpha: 0.58);

  // Radii — the shared scale. `rSm` was 5, one off `Spots.radiusSm`.
  static const double rSm = Spots.radiusSm; // 4
  static const double rMd = Spots.radiusMd; // 8
  static const double rLg = Spots.radiusLg; // 10

  // Spacing — snapped onto the 4pt grid `Spots` keeps (was 8 / 14 / 36).
  static const double sSm = Spots.s8; // within a group
  static const double sMd = Spots.s12; // header → content
  static const double sXl = Spots.s32; // section-to-section breathing room

  static List<BoxShadow> shadow({
    double dx = 4,
    double dy = 4,
    Color color = border,
  }) => Spots.shadow(dx: dx, dy: dy, color: color);
}
