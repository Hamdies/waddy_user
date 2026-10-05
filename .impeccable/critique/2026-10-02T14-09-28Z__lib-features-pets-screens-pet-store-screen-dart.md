---
target: pet store page
total_score: 24
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
timestamp: 2026-10-02T14-09-28Z
slug: lib-features-pets-screens-pet-store-screen-dart
---
# Critique: Pet store page (pet_store_screen.dart), 2026-10-02
Method: dual-agent. Total 24/40 (Acceptable).

Heuristics: 1 status 3 | 2 real world 2 | 3 control 3 | 4 consistency 2 | 5 error prevention 3 | 6 recognition 2 | 7 flexibility 3 | 8 minimalist 2 | 9 error recovery 2 | 10 help 2
Cognitive load: 4 of 8 checks fail (single focus, chunking, hierarchy, choices ≤4).

Specificity verdict: halfway authored. "Shopping for Loky" switcher + gendered Arabic is Waddy's own; below it the page is the generic mart page with Loky's name in the headings. Mint discipline passes PRODUCT.md.
Detector: doesn't support .dart (0 rules ran). Grep scan: clean on .tr keys (en+ar), RTL, Semantics; ~163 raw spacing/font numbers; fixed-height pills with no maxLines in pet_shop_card/pet_usual_card/pet_age_counter; age counter taps 44 < minTapTarget 48.

## Priority issues
1. [P1] Dead gap under "Shop for Loky": GridView.count :341 has no padding, so it inherits the safe-area insets (~59pt top, ~34pt bottom). Fix: padding: EdgeInsets.zero.
2. [P1] Need tiles have uneven sizes and tops: _NeedTile :699-736 has Expanded+AspectRatio, so 2-line labels shrink the square. Fix: reserve the height of 2 label lines (textScaler) like StoreProductCard :148, top-align the tiles.
3. [P1] Sparse, duplicated rails: _rail :507 renders 1-item shelves; Popular (main cat :427) and Treat time (:443) both show Dentastix; _everyPet See All :479 shows even when all items are on screen. Fix: minimum 3 items or fold into the row list; dedupe across rails; gate See All on count.
4. [P2] Tiles: 'walk' → paw (:385) and View All → species.icon (:358), so the dog gets two identical paws; Health/Food glyphs are weak. Fix: View All as a nav affordance; leash glyph; interim packshot per tile; PET-15 art.
5. [P2] No-pet first-timer defaults to Cats (:117), no "Add your pet" chip, _picked not persisted.

## Minor
- Treat panel says "treats and toys" but fetches treats only.
- "Shopping for Loky" + "Shop for Loky" are duplicate headings.
- Shimmer offsets 72/62 don't match the loaded layout.
- Arabic: حلويات for dog treats; رؤية الكل is stiff (شوف الكل).
- PackSize regex lacks sticks/chews/cans/pouches, so it falls back to "Kilogram".
- The Min. order chip and the min-order bar say the same thing.
- ★ glyph is used as a rating icon.
