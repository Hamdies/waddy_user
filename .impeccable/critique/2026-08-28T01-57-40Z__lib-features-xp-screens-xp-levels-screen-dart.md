---
target: Rewards / XP screen
total_score: 17
max_score: 40
na_heuristics: 
p0_count: 2
p1_count: 2
timestamp: 2026-08-28T01-57-40Z
slug: lib-features-xp-screens-xp-levels-screen-dart
---
Method: dual-agent (A: design review · B: detector + mechanical Dart evidence)

# Design Critique — Rewards tab (`xp_levels_screen.dart`)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Skeleton mirrors real layout, toast honestly gated to 600s. But progress over-reported: same fact twice, 40pt apart. |
| 2 | Match System / Real World | 1 | Screen speaks XP/tier/rarity; zero food vocabulary in 1979 lines. `free delivery` is LEGENDARY in one place, EPIC in another. |
| 3 | User Control and Freedom | 2 | Every tap one-way `Get.toNamed`. All 8 trophies share one GestureDetector (:1417). |
| 4 | Consistency and Standards | 1 | Private `_Xp` scale (:244-252) `rSm=5, sMd=14, sXl=36` off the 4pt grid. 33 tokens : 198 raw literals. |
| 5 | Error Prevention | 2 | `xpTarget` falls back to `totalXp + 100` (:347) — fictional finish line with real authority. |
| 6 | Recognition Rather Than Recall | 2 | 7 of 8 trophies hit the same `emoji_events_outlined` default (:1233). Two tiles both read "LV.5". |
| 7 | Flexibility and Efficiency | 1 | No path from "+50 XP for ordering" to ordering. Claim action absent. |
| 8 | Aesthetic and Minimalist Design | 1 | Six competing visual systems first viewport; two progress-bar languages in two greens. |
| 9 | Error Recovery | 3 | Error vs no-session correctly split, sign-in offered, all 6 strings translated. Docked: `pull_to_retry` above a tap-to-retry button. |
| 10 | Help and Documentation | 1 | Nothing explains tier/rarity/rank/streak reset. Single help string truncates mid-sentence. |
| **Total** | | **17/40** | **Poor — major UX overhaul required** |

## Design Specificity Verdict

**Generic. Stock gamification chrome wearing Waddy's paint.**

Masthead → avatar hero → twin stat split → segmented meter → "what's next" → "ways to earn" → locked trophy grid = the Duolingo/Strava/bank-points skeleton. File header admits a "faithful native port of Home.dc.html" — ported shape-first. Delivery vocabulary in 1979 lines: **one** line (`free_delivery` → truck glyph).

Damning: **all seven navigation targets go to other XP screens or auth. None leads to ordering food.**

Places/Spots already solves this with the same visual language, correctly localized. This screen copy-pasted its palette: `_Xp` (:214-240) is byte-identical to `spots_theme.dart:14-30` for mint/teal/panel/green/border.

**Deterministic scan:** detector exit 0 on all three targets — but that means **zero files scanned**, not clean. Allowlist (`detector/node/file-system.mjs:26-30`) has no `.dart`. `flutter analyze` ran instead: 7.4s, 28 issues (7 warnings, 21 infos).

**Visual overlays:** none. Native Flutter, no web build, no dev server, standing no-builds rule. Real coverage gap, not a silent omission.

## Overall Impression

Engineering underneath is better than the design on top. Data discipline is genuinely unusual — refuses to fake XP, gates celebration honestly, distinguishes error/no-session/first-load. But that honest data is poured into a borrowed skeleton that doesn't know what product it's in, and its emotional argument to a new user is "you are 87.5% locked."

Biggest opportunity: the screen observes behavior when it should drive it.

## What's Working

1. **Honest data discipline.** `_XpSourcesSection._realSources` (:1281-1320) reads live config, returns empty rather than inventing; section self-removes. Zero `kPreview*` flags in this feature — nothing mocked.
2. **State machine properly factored — all four states exist.** Error, logged-out, loading, empty all handled; skeleton mirrors real silhouette. Both assessments flagged this as where a screenshot-only review would false-positive.
3. **Reduced-motion respected in three independent animation systems** — toast, shimmer, Rive badge.

## Priority Issues

### [P0] Screen is untranslatable — Arabic structurally broken
Only 6 `.tr` keys in 1979 lines, all in error states. Weekday names hardcoded (:1075-1081). `KEEP THE MOMENTUM`, `What's next`, `XP sources`, `Per order`, `STARTER BADGE` absent from BOTH language files; `TOTAL XP`, `Trophy case`, `SEE ALL`, `Write a review` in en.json but NOT ar.json.

App already ships the fix and this file ignores it: `styles.dart:52-54` defines `displayCaps()`/`displayTracking()` because Arabic has no uppercase and breaks when letter-spaced. 20 Places files use them; this file uses them 0 times while calling `.toUpperCase()` 8× and `letterSpacing` 12×. `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start` across all 15 files = 0. `'SEE ALL →'` (:1403) points wrong way in RTL.

**Fix:** extract strings; replace toUpperCase→displayCaps, letterSpacing→displayTracking; directional Icon; EdgeInsetsDirectional.
**Command:** `/impeccable harden`

### [P0] Zero semantics; two contrast failures; tap targets under half minimum
`Semantics` count across 15 files: 0. VoiceOver reads hero as orphaned fragments. Locked state = `Opacity(0.32)` (:1512), silent to assistive tech.

Measured failures: locked trophy name `#5B7674` on `#123835` = **2.61:1**; locked tag `#3C5C59` on `#123835` = **1.75:1** (invisible).

`Dimensions.minTapTarget = 48` used 0 times. `LV. 1` pill ~23dp; `SEE ALL →` bare Text, no padding, ~13dp.

**Fix:** Semantics on `_Stat` and trophies with lock state; raise locked opacity ≥0.5; ConstrainedBox minHeight on both targets.
**Command:** `/impeccable audit`

### [P1] Nothing leads to ordering food
Structural reason the design reads generic. Says "Order Launch today · +50 XP", offers no way to order — tapping opens another XP screen. Scoreboard, not rewards system.

**Fix:** route `_ChallengeTile` (:989) to the satisfying store; persistent "Order now · +20 XP" CTA after the meter.
**Command:** `/impeccable shape`

### [P1] Trophy grid overflows at accessible font sizes
`GridView.count(crossAxisCount: 4)` with no `childAspectRatio` forces squares. `main.dart:141,152` shows textScaler clamps deliberately removed app-wide, so scaling applies at full strength — 1.3× yields RenderFlex stripes. Screenshot shows precursor: "2× FREE DELIVERY" wrapping while siblings fit. Also 8 apparently-tappable tiles share one GestureDetector.

**Fix:** `childAspectRatio: 0.78`; clamp textScaler on tile; onTap per cell. Investigate why 7/8 hit the icon default branch — data-contract bug.
**Command:** `/impeccable adapt`

### [P2] Remembered emotion is a quantified failure
Peak-end: scroll ends on "1 OF 8 UNLOCKED" under seven 32%-opacity tiles. Level-1 user meets four deficit meters (2/10, 1/8, 46/200, rank #18) against one win awarded for existing. Next reward shown desirable then padlocked. Nothing celebrates what the user did in the product. Tell: the gold full-width `DEBUG · SIMULATE LEVEL UP` is the loudest control on the page, sitting where a real CTA should be.

**Fix:** lead with earned value in delivery terms; show next 1-2 locked rewards not all 7; reframe as forward motion.
**Command:** `/impeccable clarify`

## Persona Red Flags

**Layla (Arabic-first, `ar` locale)** — every successful-load string is English; only Arabic she sees is the error state. Server-sent Arabic titles hit letterSpacing and disassemble — the exact failure `styles.dart:51` documents. `SEE ALL →` points right in RTL. Name renders `@أحمد`.

**Omar (first-timer, ordered once)** — level 1 of 10, 2 of 10 segments, 1 of 8 trophies, padlock on the reward he wants, rank #18. Did what the product wanted; screen quantifies how far he is from mattering. Wants to earn more; no button lets him.

**Nadia (VoiceOver, text at 130%)** — hears disconnected fragments; cannot hear seven trophies are locked (opacity is silent). Grid overflows at 130% (no clamp app-wide). Key controls 23dp and 13dp against the app's own 48dp standard.

## Minor Observations

- `_Xp.gold #FFC93C` ≠ brand amber `#FFBE0B`; `_Xp.coral #FF6B4A` ≠ brand coral `#FF6B6B`.
- `_Xp.green #22C55E` is a seventh accent for the challenge bar while the meter above uses mint.
- `onDarkFaint` = exactly 4.50:1, rounding-boundary pass, used at 9-9.5px. At-risk.
- Dead code (analyzer-confirmed): `_Ribbon` (:502) never instantiated; `levelName` (:339) unused. Three orphaned widgets ~33KB: streak_badge, next_reward_indicator, brilliant_roadmap — no importer in lib/.
- "Resturant" typo is NOT in code — backend challenge data rendered raw. Title repeats in subtext because `_metaLine` falls through to description when `targetProgress <= 1`.
- `Theme.of(context)` count in this file: 0. Hardcoded dark surface regardless of app theme.
- Rive flame at `right:-10, top:-24` inside `clipBehavior: Clip.antiAlias` parent — clipped by its own container.
- 21 `withOpacity` deprecations in sibling widgets; this file already uses `withValues()`.

## Questions to Consider

1. Delete XP/level/rank/grid, keep "you've saved 340 EGP on delivery, order 2 more for another free one" — would the user be worse off, or finally understand what they're playing for?
2. Why does a screen whose economy is fed by ordering contain zero paths to ordering?
3. At what unlock ratio does a trophy case become a list of rejections?
4. Places/Spots runs the same system, correctly localized. What stops the next ported screen from duplicating `_Xp` a third time?
