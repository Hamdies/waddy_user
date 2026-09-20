---
target: home screen
total_score: 23
max_score: 40
na_heuristics: 
p0_count: 1
p1_count: 5
timestamp: 2026-08-21T17-15-06Z
slug: lib-features-home-screens-home-screen-dart
---
# Design Critique — Waddy Home Screen

Method: dual-agent (A: design review · B: deterministic evidence sweep), parent-verified.

## CRITICAL CAVEAT
Screenshots reviewed were MOCK DATA. kPreviewRankedChart=true (top_restaurants_view.dart:34)
and kPreviewGroceryShelf=true (grocery_shelf_view.dart:35). Both comments say "Set back to
false before shipping." Zooba/KFC/Krispy Kreme/Gourmet Egypt/Seoudi/Metro are from
_mockChartStores() / _mockGroceryStores() with negative ids. kDebugMode-gated so release
builds are safe — the team is blind, not the users.

## Design Health Score: 23/40

| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 2 | Skeletons excellent; no ETA on fold; failed feed indistinguishable from empty zone |
| 2 | Match System / Real World | 3 | Good vocabulary; "1:1 VOTES" is a stadium metaphor users lack schema for |
| 3 | User Control and Freedom | 3 | Branded pull-to-refresh; contender tap opens vote sheet with no pre-tap warning |
| 4 | Consistency and Standards | 2 | Two rails two edge treatments; _OrderAgainRow uses 18 padding + BouncingScrollPhysics both rejected elsewhere |
| 5 | Error Prevention | 2 | No error state; _safe() swallows to debugPrint; six sections SizedBox.shrink() |
| 6 | Recognition Rather Than Recall | 3 | Logos/photos/ranks good; unlabelled perk fallback chain forces recall |
| 7 | Flexibility and Efficiency | 3 | _OrderAgainRow correct and correctly placed; invisible to guests/new users |
| 8 | Aesthetic and Minimalist Design | 2 | Four competing loud objects on fold; hero+greeting+search+3 tiles+battle before one orderable thing |
| 9 | Error Recovery | 1 | No error UI at all. Not a toast, not a retry. Lowest score, earned. |
| 10 | Help and Documentation | 2 | Spot Battle is a novel mechanic with zero explanation |

## Design Specificity Verdict
Authored, not assembled — genuinely top-decile Flutter delivery UI. Cover the logo and you
still know which app this is. Mint hero + deep-teal ink, rank numeral hung half-off the tile
with a mint stroke crossing two backgrounds, grocery shelf plank metaphor, battle contender
axis chosen to survive deuteranopia. Design rationale is baked into source comments at a
level most teams never reach. Weak point: bottom nav is untouched boilerplate — the one
permanently-visible element that could belong to any app.

Deterministic scan: UNAVAILABLE. detect.mjs exit 0 / [] is a NON-SIGNAL — SCANNABLE_EXTENSIONS
(detector/node/file-system.mjs:26-30) has no .dart, so all 130 files were filtered before any
rule ran. Browser overlay N/A (native app).

## What's Working
1. The gap system is a real design system, enforced. _Gap.bind 12 / section 24 / major 36
   (module_view.dart:47-68) with the invariant "a section owns none of its outer spacing"
   actually held across widgets. Widening separators while holding bind constant is the
   correct move — the problem was seam contrast, not absolute space.
2. The chart numeral (top_restaurants_view.dart:1249-1296) hangs half off the tile corner,
   stroked in mint because the glyph crosses two backgrounds and no single fill is legible on
   both. Stroke direction was inverted when the glyph moved. Optical reasoning, not decoration.
3. Honest degradation. kMinRanked=4 drops chart dress entirely when the catalogue is thin
   because chart dress is a claim about depth. Paired with _metaLine part-dropping and the
   perk chain, the card degrades at every level instead of rendering empty slots.

## Priority Issues

P0 — Two kPreview* flags are true; team is reviewing fabricated data.
top_restaurants_view.dart:34, grocery_shelf_view.dart:35. The observed "third line varies with
no rule" is the mock generator's i%3 seeding (top_restaurants_view.dart:139-144), deliberately
forcing every perk branch onto one screen. Fix: set both false, re-screenshot, re-review.

P1 — Grocery free-delivery pill is invisible: mintSurface on mintSurface.
Band painted WaddyColors.mintSurface (module_view.dart:511); perk bg is WaddyColors.mintSurface
(grocery_shelf_view.dart:896). Contrast 1.0:1. The pill renders and cannot be seen. This is the
real cause of "Seoudi shows Free Delivery as plain text" — a colour collision, NOT a rule
divergence. _kPlateBg (grocery_shelf_view.dart:275) is the same token again.
Fix: white plate + mintInk label, matching the _AisleTile pattern already justified at :437-441.

P1 — No error state anywhere; total failure renders a blank mint page.
_safe() (home_screen.dart:64-70) catches everything into debugPrint. Six sections return
SizedBox.shrink() on null. No retry, no toast, no inline row. On a bad connection the user gets
a mint hero, their name, and nothing — indistinguishable from "no restaurants near you."
Fix: have _safe record failures; when zero sections render AND something failed, show one inline
row + Retry calling loadData(true). ~40 lines for the worst heuristic score. DECISION: approved.

P1 — Global text scaler pinned to 1.0, discarding the OS accessibility setting.
main.dart:205-208 sets textScaler: TextScaler.linear(1) app-wide. Every downstream
textScalerOf() reads 1.0, making the per-widget clamps dead code (home_screen.dart:631,
top_restaurants_view.dart:267, special_offer_view.dart:390+). DECISION: unintentional, to fix.

P1 — Coral 10% OFF pill fails contrast at its real size.
coralDark #E84D4D on coralSurface #FFEEEE = 3.34:1; pill text is fontSizeExtraSmall = 12sp
(dimensions.dart:7), far below the 18.5sp exemption, so the floor is 4.5:1. Highest
commercial-value label, hardest to read. Fix: ~#C62828 (≈5.1:1) or raise to 14sp semibold.

P1 — Zone hardcoded into 16 translation strings.
Live in three paths: most_popular (module_view.dart:461), top_10_maadi_spots
(top_restaurants_view.dart:487), best_store_nearby (grocery_home_screen.dart:401). Spot Battle
composes it too (module_view.dart:906). Known debt — code says backend zone lookup is
unreliable (module_view.dart:903-905). Parameterized infra already ships in BOTH locales:
restaurants_in_zone = "Restaurants in @zone" / "مطاعم في @zone", already used for the thin
variant beside the hardcoded one (module_view.dart:474-475). Also en.json:2167
"fastest_in_maadii": "Fastest in Maadii" is a live typo (currently unreferenced).
AR/EN asymmetry: EN most_popular carries "In Maadi", AR does not.

P2 — Opaque mint status band clips scrolled content.
home_screen.dart:512-545 stacks a permanent ColoredBox over the scroll view. Invisible at
offset 0 only. Explains the clipped "See all 3 spots" in screenshot 2. Fix: cross-fade the band
colour off scroll offset; the controller and listener already exist (home_screen.dart:330-340).

P2 — Sub-48dp tap targets.
See-all arrow 40x40 (top_restaurants_view.dart:572-574); another 36x36 (:820-821). Pressable is
HitTestBehavior.opaque with no min-size expansion (pressable.dart:51), so visual bound = hit
bound. Also current_order_widget.dart:206 (44), cashback_dialog_widget.dart:40,47 (30),
home_hero_banner_widget.dart:838 (16). Arrow does carry semanticLabel + RTL-aware icon.
NOT VERIFIED: Icon(size:<24) candidates — IconButton defaults to 48dp splash; needs runtime.

P3 — Cart badge hardcoded right, breaks RTL.
home_hero_banner_widget.dart:761 Positioned(top:0, right:0). Under RTL the header mirrors but
the badge stays physically right, pointing at the address instead of the corner. Single miss —
the rest of the file uses directional APIs. Fix: PositionedDirectional(top:0, end:0).

P3 — Grocery rail not viewport-solved.
_kUnitWidth=150, _kUnitGap=14 (grocery_shelf_view.dart:243-244) vs the ranked rail solving from
viewport for a 0.34 peek (top_restaurants_view.dart:232-249). Math: on 393pt Mi 9T the third
card lands 33% visible — coincidentally near the intended 34%, so it LOOKS right here. Defect
is fragility: drifts on a 430pt phone while the restaurant rail stays locked. _kUnitGap=14 is
off the 4pt grid. Grocery rail also lacks _TrailingFade, so it hard-cuts mid-word ("Metro M...")
where the restaurant rail fades — fix already written one file over (:417-423).

## Persona Red Flags
Repeat orderer (6pm, one hand, 2s glance): CurrentOrderWidget renders nothing without a live
order (current_order_widget.dart:21-28) — no ETA on the ordinary re-open. _OrderAgainRow sits
BELOW the Spot Battle (module_view.dart:152). Three module tiles are a permanent tax on the
most common path.
First-timer: Spot Battle explains nothing — no what/why/what-is-won. Voting is a hidden gesture
(module_view.dart:1139) with nothing marking logos as pressable; the only button-shaped element
goes elsewhere. "Most Popular In Maadi" assumes they know they're in Maadi.
Arabic/RTL: cart badge wrong side; AR loses the geographic qualifier EN gets; grocery shelf has
NO text-scale clamp while the restaurant rail does (:1207-1209) — Alexandria's taller metrics
will clip descenders in fixed _kNameBlock=20. Credit: displayCaps/displayTracking collapse caps
and tracking under Arabic, headers flip the see-all arrow, _TrailingFade flips its gradient.
Low-vision: measured hero failures — "DELIVER TO" 3.03:1, chevron 2.72:1, search placeholder
2.09:1, magnifier 2.33:1, search border 1.16:1 (on the control the code calls the primary
action). Battle panel: VOTES 3.94:1, ":" 2.98:1, ghost-button border 2.2:1 (below the 3:1
non-text floor). Passes: greeting 6.44:1, store name 16.68:1, free-delivery pill 8.84:1.

## Minor Observations
- _OrderAgainRow breaks two of its own file's conventions: 18 padding (off-grid, off the 16
  everyone else uses) and BouncingScrollPhysics, which StoreRailView explicitly removed
  (top_restaurants_view.dart:373-377). Lesson learned in one widget, not propagated next door.
- _ModuleTile label fontSize: 18 hardcoded (module_view.dart:407); fontSizeLarge is 18.
- _kSpotTile = 32 but its own comment says 36 is the recognisability floor (module_view.dart:727-733).
- _voteText (1,284) and _scoreText (1.3k) coexist in one card for the same magnitude.
- Five duplicate widget filenames; direction is INCONSISTENT (banner_view: root live, views/ dead;
  other three: reverse). Riskiest: cash_back_dialog_widget.dart and cashback_dialog_widget.dart
  both declare class CashBackDialogWidget — an import-path edit silently swaps implementations
  with no compile error.
- dark_theme.dart has ZERO importers; ThemeController still exposes darkTheme and four home files
  branch on it. App ships light-only; 470 hardcoded neutrals are latent, not live, breakage.
- 0 cacheWidth/cacheHeight across 96 image sites (CustomImage internals unverified).
- 124 non-directional EdgeInsets.only(left/right) vs 16 directional — bimodal by file generation.
- Only 3 untranslated strings ('CLOSED', 'CRAZY', 'SALE'). Translation discipline otherwise good.
- SpotsRound SUN 9PM vs Mon 00:00 discrepancy from earlier sessions is RESOLVED
  (spots_round.dart:10 documents it as fixed history). No action.

## Questions to Consider
- Why does a voting game outrank dinner on the fold? What's the measured tap-through vs the
  scroll-depth cost to the chart?
- light_theme.dart:32-38 says mint is "reserved for CONTROLS. Mint means press this. Nothing
  else" — but the confirmed identity is mint-dominant fields, and the hero, tiles, pill, numeral
  stroke, FAB and CTA are all mint. Which document is authoritative? Until settled, mint carries
  no information, which is the exact failure that comment was written to prevent.
- What process catches a "set back to false before shipping" comment, and why didn't it fire?
