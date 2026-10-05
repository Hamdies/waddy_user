---
target: mart product screen (Garnier Micellar Water)
total_score: 22
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
timestamp: 2026-10-02T21-33-34Z
slug: lib-features-item-screens-mart-product-screen-dart
---
Method: dual-agent (A: design review · B: detector + Flutter code scan)

# Critique: Mart product screen (Garnier Micellar Water) — 22/40, Acceptable

Scores: H1 3, H2 2, H3 2, H4 2, H5 2, H6 3, H7 3, H8 2, H9 2, H10 1.

## Specificity verdict
Generic with one authored accent (mint CTA with teal hard shadow, teal price, Egyptian Arabic strings). Hero is white cutout on white with a 1px rule; rail cards are white+hairline+gray caption; mint ~3% of viewport, no mintSurface tint. Header cites a Claude Design template (mart_product_screen.dart:25).
Detector: detect.mjs exit 0, [] (no Dart rules; not evidence of cleanliness). Browser overlay skipped (native Flutter).

## Priority issues
- [P1] "Goes well with" is a false claim: rail is same-store/category fill (mps:118-160); Arabic string is a food idiom. Fix: honest label ("More from this aisle"). /impeccable clarify
- [P1] No product info, no "sold by"/ETA/unit price; description dropped when equal to name (mps:296-307). Fix: sold-by row, per-unit price, brand chip, fallback copy. /impeccable arrange, clarify
- [P1] Generic hero, mint absent, hard 1px divider (mps:316-319). Fix: mintSurface stage + soft edge; full mint stays CTA-only. /impeccable colorize | bolder
- [P2] Rail cards: gray bands, "+" hit box 120x48 over photo (spc:174-185) causes accidental adds, 11px inkLight size line. /impeccable polish
- [P2] Auto-close 650ms after add (mps:248-249), sold-out dead end (mps:697-704). Fix: stay + "Added ✓ · View cart" or PillCartBar on return; notify-me + alternatives. /impeccable harden

## Code-backed defects (Assessment B)
- Stepper semantic labels dangle "of" (mps:730, :746); quantity_stepper.dart appends the name.
- _Chip/_VariantTile expose no selected state; sold-out tile announced as plain button.
- Fixed heights overflow at OS text scale >= ~1.3: variant tile 98 (:526), rail 252 (:677), sale chip 26 (:390), chip 40 (:996).
- _StepButton 40 wide and _Chip 40 high lack minSize 48.
- Multi-choice chips (:566-570): no sold-out handling, quantity not reset.
- Off-grid literals: 290, 58, 26, 98, 18, 22, 3, 5, 9, 14, +2 offsets.
- Badge counts lines not units (:377); 10px badge digit (:870).

## Personas
Casey: accidental rail add, top-row controls, no rail skeleton, quantity reset. Riley: empty rail blank, long variant ellipsis, enabled CTA for missing combo, badge "1" for qty 5. Egyptian Arabic-first shopper: MSA CTA vs colloquial neighbours, food idiom on cosmetics, bidi LE run, no store/ETA.

## Questions
Waddy-specific hero? Honest or data-driven rail? Auto-close vs basket as destination?
