---
target: supermarket store page (grocery)
total_score: 24
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 2
timestamp: 2026-10-01T21-01-35Z
slug: lib-features-store-screens-store-screen-dart
---
# Critique: supermarket store page (StoreScreen, Mart Store Page v4) — 2026-10-02
DEGRADED: single-context (harness restricts sub-agents to explicit user requests). Detector: 0 findings (no Dart support).

| # | Heuristic | Score | Key issue |
|---|---|---|---|
| 1 | Visibility of status | 3 | Min-order progress clear; grey pill reads disabled though tappable |
| 2 | Match real world | 2 | "Kilogram" under 250ml/125g/950ml/tissues; "1 items"; ar "3 منتج" |
| 3 | User control | 3 | Mini header keeps search + cart one tap away |
| 4 | Consistency | 2 | Group title = selected chip; "2 items" + "See all 2"; See all + View All tile |
| 5 | Error prevention | 2 | Two "Fresh Tomatoes 1kg" at 22 and 25 LE, one with no photo |
| 6 | Recognition | 3 | Photo tiles + item counts |
| 7 | Flexibility | 3 | Persistent search, filter |
| 8 | Minimalist | 2 | Top picks hero says the header twice; sparse rails leave empty thirds |
| 9 | Error recovery | 2 | "Can't find" search is good; placeholder W image |
| 10 | Help | 2 | 80 LE minimum only discoverable via the cart bar |
| Total | | 24/40 | Acceptable |

## Priority issues
1. [P1] Unit line prints "Kilogram" on packaged goods (store_product_card.dart _unitOf). Fix: data in catalogue; client shows pack size parsed from name, hides unit when name carries a size or unit contradicts it.
2. [P1] Duplicate same-store listing (Fresh Tomatoes 1kg, 22 vs 25 LE). Fix: catalogue duplicate check per store (CAT); client dedupe by catalog product in rails.
3. [P2] Sparse groups break layouts: Condiments 2 cards + empty third, Disposables rows at 2/3 width, "See all 3" with all 3 shown. Fix: fit-to-width when items fit; hide See all when shown == count.
4. [P2] Group title duplicates selected tab and changes on tab switch; subtitle count duplicates See all count. Fix: drop title or tabs-as-header.
5. [P2] Unranked Top picks hero (128px) repeats header, packs ~30px. Fix: skip hero when unranked.

## Minor
- Names truncate the size ("Body Splash 2…"); n_items plural en/ar; grey pill looks disabled; header name truncates beside sticker; min order absent from header; dark panel style assigned by index lands on Condiments; "See all" + "+17 View All" duplicate.
