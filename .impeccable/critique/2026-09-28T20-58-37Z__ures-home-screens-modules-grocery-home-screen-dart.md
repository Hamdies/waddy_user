---
target: grocery module home
total_score: 24
max_score: 36
na_heuristics: 10
p0_count: 0
p1_count: 2
timestamp: 2026-09-28T20-58-37Z
slug: ures-home-screens-modules-grocery-home-screen-dart
---
⚠️ DEGRADED: single-context (session policy: no sub-agents unless user asks explicitly)
Target: grocery module home (grocery_home_screen.dart + module_top_brands_grid / module_category_circles / module_store_row_card), from 2 device screenshots at large text scale.

Scores: H1 3, H2 3, H3 3, H4 2, H5 3, H6 2, H7 3, H8 2, H9 3, H10 n/a — 24/36 (67%, Acceptable)
Detector: 0 findings (Dart not scannable by detect.mjs).

Priority issues
1. [P1] Category labels break mid-word at large text ("Supermar/kets") — module_category_circles.dart:321; _needsTwoLines only checks line count, not a single word wider than the 76pt tile. Fix: detect per-word overflow and shrink the strip's label size uniformly (or widen the label box past the tile).
2. [P1] Free-delivery chip floats to mid-row (Natural Garden) — module_store_row_card.dart:545 _MetaLine outer Row is MainAxisSize.max inside a Flexible, so it takes half the row. Fix: mainAxisSize: MainAxisSize.min.
3. [P2] Brand logos cropped by BoxFit.cover (Farmland wordmark cut, HajArafa tiny) — module_top_brands_grid.dart:197. Fix: contain on white plate with inset.
4. [P2] Perk slot under tiles mixes ETA and FREE DELIVERY; free-delivery stores lose their ETA; caps "FREE DELIVERY" vs chip "Free delivery". Fix: slot always ETA; perk as tile-corner tab; one casing.
5. [P2] Grid and list show the same stores 1.5 screens apart (zone has ~9 stores). Fix: hide/shrink grid when catalogue is small, or exclude grid stores from list top.

Minor: stale "3×2"/"six cells"/"three columns" comments; cover-less stores show logo as cover + same logo badge; Natural Garden reuses Farmland art (data); mint below the banner is thin on the All Stores screen.
