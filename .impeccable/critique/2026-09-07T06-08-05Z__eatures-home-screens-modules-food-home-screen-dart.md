---
target: lib/features/home/screens/modules/food_home_screen.dart
total_score: 23
max_score: 40
na_heuristics: 
p0_count: 2
p1_count: 2
timestamp: 2026-09-07T06-08-05Z
slug: eatures-home-screens-modules-food-home-screen-dart
---
Method: dual-agent (A: design review · B: detector + deterministic evidence)

Surface mode: Operate. Score 23/40 (Needs work).

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Shimmer matches real card geometry. Chip toggle fires server call with no spinner. |
| 2 | Match System / Real World | 3 | "Sort by" is UI-speak in a row of content-speak. |
| 3 | User Control and Freedom | 3 | Clear chip w/ live count good; docked for forced auto-scroll. |
| 4 | Consistency and Standards | 1 | 4 controls / 2 interaction models; rail and list publish different fact sets; two star colors; two rating floors (rail fabricates 4.5). |
| 5 | Error Prevention | 3 | kMaxPlausibleDeliveryKm, _MetaLine free-delivery guard, 44pt negative-margin hit box. |
| 6 | Recognition Rather Than Recall | 1 | Pinned strip never names active cuisine; strip + headline both scroll away. |
| 7 | Flexibility and Efficiency | 2 | Order Again buried third; no reorder shortcut. |
| 8 | Aesthetic and Minimalist Design | 2 | Four horizontal scroll surfaces before the vertical list; same stores twice in one viewport. |
| 9 | Error Recovery | 3 | No network-error state: storeModel == null shimmers forever. |
| 10 | Help and Documentation | 2 | Active Sort chip never says what it sorted by. |
| **Total** | | **23/40** | **Needs work** |

## Design Specificity Verdict
4/10. Three authored moments (mint header band, ranked numeral cross-background treatment, cuisine tile gradient); everything else stock delivery feed. Body paints #FFFFFF while token file defines canvas #FAFAF8 "avoids clinical pure white" — home_screen.dart:485 sets colorScheme.surface. Mint field below header ~6% of viewport against "large mint fields ARE the identity."

Detector: NULL RESULT not a pass — .dart absent from SCANNABLE_EXTENSIONS (detector/node/file-system.mjs:26-30); zero rules evaluated, exit 0, []. Browser viz skipped (native Flutter). flutter analyze modules/: clean.

Hand-derived deterministic findings:
- RTL: 4 real mirror bugs, target file only (542 card gutter, 584-586 discount badge, 846 clear-chip gap, 1022-1024 inter-chip gutter). Other 4 collaborator files all use directional variants correctly.
- Tap targets: _kChipHeight=36 with no minSize passed through PressableScale -> visual bounds ARE hit bounds (pressable.dart:117-126). 5 controls fail HIG 44 / Material 48. Comment at 38-40 claims the 44 row is the target; it is not.
- Contrast: inkMuted on white 2.39:1 (FAIL 3:1) and it is the resting chip's only affordance marker. Clear-chip border composites 1.76:1. inkLight 4.59:1 on white but 4.39:1 on canvas (FAIL).
- Text scaling: _FilterChipsHeader._height const 68, no textScaler. Count badge 17pt circle / 11pt glyph clips ~1.2x. 110pt rail clips ~1.3x.
- i18n: all 19 keys present in both en.json and ar.json. Clean.
- Type: 15 distinct font sizes across 5 files; clusters at 10/10.5/11/11.5 and 16/16.5. Two section headlines differ in size AND weight (20/w800 vs 18/w700).

CORRECTION: kPreviewRankedChart and kPreviewGroceryShelf both false; no preview flag in store-row path. Screenshots are REAL DATA — uniform NEW/15 LE/10-30 min is a live defect.

## What's Working
1. Ranked numeral cross-background solution (_kRankOverhang/_kRankDrop/_kRankLeadPad).
2. _activeFilterCount including _selectedCuisineId, folded into Object.hash signature.
3. Sliver conversion — SliverMainAxisGroup + real SliverPaginatedList without lifting state.

## Priority Issues

[P0] Rail and list are the same restaurants, adjacent, with different facts. ~250pt for a duplicate; "Most ordered this week" reads admin-curated featuredStoreList. Fix: dedupe rail ids from page 1, or re-claim honestly, or cut. Unify fact set to rating·time·fee both views. -> /impeccable shape

[P0] Pinned strip never names active cuisine. Filter to Pizza, scroll, no on-screen statement. File's own comment at :762 diagnoses it and leaves the header in a scrolling sliver. Fix: selected cuisine as leading chip in pinned strip, tap-to-clear (~15 lines). -> /impeccable layout

[P1] Every row NEW, identical meta line, rating structurally absent. isNew fires ratingCount<20 && avgRating<=0 = whole catalogue; hasShowableRating needs >=20 = nothing. Fix: suppress NEW when >60% of page qualifies; drop floor to 5 with count shown; put distance in the row. -> /impeccable clarify

[P1] Four controls two interaction models + 5 tap targets under minimum. Sort = sheet, others = toggles, identical active state, label never shows the value. Fix: print value not label; move Sort to catalogue header row; pass minSize; darken resting border to 3:1. -> /impeccable audit

[P2] Body abandons the brand. Fix: canvas #FAFAF8 as scroll bg (one line); mintSurface band around headline+cuisine strip+chips — creates second mint field, fixes proximity grouping, makes pinned strip a persistent brand mark, and white chips finally get real figure/ground. -> /impeccable colorize

## Cognitive Load: 5/8 failed (high)
Failed: single focus, grouping, visual hierarchy, one thing at a time, minimal choices (11 tiles / 5 chips / 10 rail cards in one viewport), working memory.
Passed: chunking, progressive disclosure, section rhythm.
The three passes are craft items; the five failures are decision-architecture items.

## Emotional Journey
Two early peaks (mint header, "Top 10" promise), three valleys: #1/#2 cards are flat logos showing no food; same names reappear 200pt below; four identical rows. No end — paginates into the nav reserve. Peak-end: peaks early, ends on the weakest note. Nothing answers the product's stated top question in the 95% case.

## Persona Red Flags
- First-timer 8pm: no food in top slot, chart = decoration, every row NEW, no ratings, 4 horizontal strips. Returns to the app showing 4.6 (1,203).
- Weekly reorderer: Order Again is best-designed thing here but sits third, under 36pt of dead space from unconditional spacers around conditional widgets, above a 250pt rail they never use.
- One-handed commuter: see-all arrow top-right is sole entry; chips pin to top (worst thumb position); auto-scroll fires on a cuisine tap in a different widget and slides the strip under a committed thumb.
- Low-vision 200%: ModuleCuisineCircles handles scaling with real TextPainter; this file's const-68 header and hard-36 chips clip.

## Minor Observations
- _ProductCard._resolve defaults rating to hardcoded 4.5 — fabricated rating as fact.
- _ProductCardState._isFavorite persists nothing; resets on rebuild.
- Color(0xFFE84D4D) byte-identical to coralDark, hardcoded anyway; Color(0xFF7A4F00) hand-mixed amber ink, no amberInk token.
- Stale comment top_restaurants_view.dart:296 (mintSurface documented as #F5F7F6).
- _MetaLine builds a SingleChildScrollView to do a ClipRect's job on every row.
- _buildFilterChips mutates state and schedules post-frame callback inside build().
- BannerView: width*0.38 shimmer when null, SizedBox when empty — catalogue shifts mid-scroll as banners resolve.
- Order Again -> rail seam uses _kSectionGapTight (12) for two unrelated sections; should be 24. Refactor named the values without fixing the assignment.
- Sort sheet has no dismiss control beyond handle and scrim.

## Questions to Consider
1. If you deleted the rail tomorrow, what would a user lose?
2. Is it actually "most ordered this week"? It reads an admin flag.
3. What is a user choosing between when every row says "15 LE · 10-30 min"?
4. Token file says mint is "reserved for CONTROLS"; brand says "large mint fields." Direct conflict, resolved by using almost no mint.
5. Why pin the four filters set once, and let the cuisine — changed most, no on-screen state — scroll away?
