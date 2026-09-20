import 'package:flutter/material.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';

/// The claw cabinet's materials, expressed in WADDI Spots terms.
///
/// ## What this file is now
///
/// It used to be a parallel design system: its own mint, its own teal, its own
/// page colour, its own radius scale running to 30 where [Spots] caps at 16.
/// Four of those values were near-misses of tokens that already existed —
/// `#0C3A2D` beside [Spots.panel] `#0E3532`, `#22EFA1` beside [Spots.mint]
/// `#1EF2A0` — which is the expensive kind of duplication: close enough that
/// nobody notices the drift, far enough that the screen never quite looks like
/// the rest of Spots.
///
/// So the colours are now **aliases onto [Spots]**. Nothing here invents a
/// hue. What remains genuinely local is *geometry*, and only for the cabinet.
///
/// ## The one exception, and its limit
///
/// The cabinet is a moulded plastic object, not a printed card. So the
/// *shell, glass and chute* keep their own radii rather than the [Spots]
/// scale. The shell used to stand on a wide blurred shadow too; that drop is
/// now removed, on request, so the cabinet sits flat on the page.
///
/// That exception stops at the cabinet's edge. Everything around it — the
/// page, the masthead, the ticker, the CTA, the consolation card, the empty
/// state — is ordinary Spots: [Spots.canvas] paper, drawn teal borders, radii
/// from the [Spots] scale. The machine is allowed to be the one exotic object
/// on a page that is otherwise unmistakably Spots.
class ClawTokens {
  const ClawTokens._();

  // ── Radii ──
  //
  // Only the cabinet's own shell escapes the Spots cap of 16. Everything that
  // is not moulded plastic uses the [Spots] scale directly.
  static const double rSm = Spots.radiusSm; // pips, small chips
  static const double rMd = Spots.radiusMd; // buttons, inner panels
  static const double rLg = Spots.radiusLg; // the header strip's top corners
  static const double rShell = 26; // the chassis — the moulded exception
  static const double rGlass = 6; // the glass — the one hard-edged element

  // ── Border widths ──
  //
  // The cabinet's fine work — ball rings, pips, the glass' inset ring — is
  // finer than the drawn borders on a Spots card, because it is moulding
  // detail rather than ink. The card-level weights come from [Spots].
  static const double bw1 = 2; // ball rings, bulbs, chips
  static const double bw2 = 2.5; // the target ring
  static const double bw3 = 3; // the glass' inset ring, held balls

  /// The shell's drop. Removed on request — the cabinet now sits flat on the
  /// page with no blurred shadow beneath it.
  static const List<BoxShadow> shell = [];

  /// A hard offset shadow, for the elements that live on the *page* rather
  /// than on the cabinet. Delegates to [Spots.shadow] so the claw screen's
  /// drop and a Spots card's drop are one decision.
  static List<BoxShadow> hard(double offset, {Color color = Spots.border}) =>
      Spots.shadow(dx: offset, dy: offset, color: color, opacity: 1);

  // ── Palette — aliases, not inventions ──

  /// The shell. [Spots.panel] is the system's dark-teal panel and this is a
  /// dark-teal panel; they were two hex values apart for no reason.
  static const Color shellFill = Spots.panel;

  /// The darkest teal in the machine: the chute, the glass' rail strip, the
  /// claw's bodywork.
  ///
  /// ## Why this one is not an alias
  ///
  /// It was [Spots.teal900] for one revision, which was a mistake worth
  /// recording: `teal900` #0C3532 and [Spots.panel] #0E3532 are
  /// *luminance-identical* — a contrast ratio of 1.00. Since the shell is
  /// `panel` and the chute is this, aliasing made the prize chute vanish into
  /// the chassis, and the PICK slots ended up floating on one undifferentiated
  /// dark field.
  ///
  /// The Spots palette has no step below `panel`: `teal900` is a *pressed*
  /// state for teal elements, not a darker surface, and `ink` is only 1.05
  /// against panel. A machine with a recessed chute needs one, so this value
  /// stays local — it is the cabinet's own material, exactly like [rShell] and
  /// [glass]. It sits ~1.23 against the shell, enough to read as a hole cut
  /// into it rather than a panel painted on it.
  static const Color deep = Color(0xFF06241B);

  /// The neon. The cabinet used a half-step-brighter mint on the grounds that
  /// the app's value went flat on the dark shell — but [Spots.mint] is already
  /// tuned for exactly that, being the accent on every [Spots.panel] surface
  /// in the app.
  static const Color mint = Spots.mint;

  /// The mint brow's lower stop — [mint] stepped down, not a second hue, so
  /// the gradient stays one colour catching light.
  static const Color mintDeep = Color(0xFF15C47F);

  /// The glass interior, top to bottom.
  ///
  /// Was a near-neutral pale-green wash, then [Spots.mint100]→[mint200] — but
  /// `mint100` is tuned to read as an off-white wash, not a colour, so the
  /// glass still looked white against the shell. This is a flat fill of
  /// [Spots.mint200] — the system's actual mint fill tint, not a wash of it —
  /// so the window reads as mint at a glance.
  static const List<Color> glass = [
    Spots.mint200,
    Spots.mint200,
    Spots.mint200,
  ];

  /// The page behind the cabinet — the Spots dot-grid canvas, which is what
  /// every other Spots screen stands on.
  static const Color page = Spots.canvas;

  /// A filled winner row on the page.
  static const Color wonRow = Spots.mint100;

  /// The winner row's two square elements — the PICK plate and the face.
  /// One value squares both, sits on the 4pt grid, and clears the iOS hit
  /// target so the plate stays tappable if the row ever gains an action.
  static const double rowElement = 44;

  /// The cabinet's design-space chrome heights, kept beside the geometry they
  /// belong to.
  static const double glassTopChrome = 40; // the lit header inside the glass
  static const double glassFooter = 16; // the branded base plate
}
