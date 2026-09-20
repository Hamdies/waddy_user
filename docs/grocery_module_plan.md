# Grocery module — audit and fix plan

**Date:** 2026-09-15 · **Scope:** `waddi_user`, the Grocery module end to end —
home, store screen, browse/filters, the dashboard band
**Status:** `G-01`–`G-06` and `G-08` landed 2026-09-15. `G-04` was overstated
and is corrected below; what remained of it was one line, and that line is
gone. `G-07` is a product decision, still open — and latent, since the aisle
grid is switched off. `G-09` open: no test covers the grocery module.

Findings are `G-01`…`G-09`, referenceable from commits the way `F-*` is used in
`food_module_plan.md`, `M-*` in `module_architecture_plan.md` and `CC-*` in
`cart_checkout_fix_plan.md`.

The surface: `grocery_home_screen.dart` (1,213 lines), `store_screen.dart`
(1,931 — the generic store screen, which grocery is the main user of),
`module_category_circles.dart` (964), `module_best_nearby_section.dart` (333),
`grocery_shelf_view.dart` (the dashboard band), plus `top_grocery_view.dart`
(412) and `top_grocery_stores_view.dart` (540).

---

## Summary

Grocery is where the app's dead weight has collected. Of the ~5,400 lines listed
above, **roughly 1,800 are built by nothing at all** — two grocery rails and two
cart bars. (The audit first counted an entire dead flash-sale feature here too;
that was a bad grep, corrected under `G-04`. The feature is live in shop, and
only grocery's fetch of it is waste.)

The live code has two defects, and both are already documented twins of things
fixed in Food this week:

- `G-01` is `F-02` — filter state kept in `setState` *and* on the controller.
- `G-02` is `F-03` — the store screen gating its whole render on a category
  list only its tab strip needs.

Both fixes are written; this is mostly a matter of applying them to the other
module. The genuinely new finding is `G-03`: the grocery store screen builds
every category's product rail on every rebuild.

---

## Part 1 — Findings

### G-01 · Filter state exists twice (`F-02`'s twin) — **DONE**

> `StoreController.moduleFilters` is the only copy. The four `setState` fields
> became getters that read it, and every handler starts from the current
> filters and changes the one thing it is about via `copyWith`.
>
> Three surfaces render filter state and none of them was subscribed once
> `setState` went, so each got its own `GetBuilder<StoreController>`: the
> browse header's reset button, the category circles' selected ring, and the
> refine button's active count. The refine sheet was a `StatefulBuilder`
> re-reading the screen's fields; it is a `GetBuilder` now, because it renders
> in its own overlay route and cannot wait for the screen behind it.
>
> One difference from food, deliberate: food's sheet resets only the two
> switches it owns, because the cuisine and sort are set elsewhere on the
> screen. Grocery's sheet owns the category tiles *as well*, so its reset and
> the header's reset clear the same four things.

<details><summary>The original finding</summary>


`_GroceryHomeScreenState` holds four fields and pushes them into the controller
without ever reading back:

```dart
int? _selectedCategoryId;
bool _filterOffers = false;
bool _filterUnder30 = false;
bool _filterFreeDelivery = false;

void _pushFilters() => Get.find<StoreController>().setModuleStoreFilters(
  ModuleStoreFilters(offers: _filterOffers, freeDelivery: _filterFreeDelivery,
    maxDeliveryTime: _filterUnder30 ? 30 : null, categoryId: _selectedCategoryId));
```

Identical to Food before `F-02`, with the identical reproduction:
`DashboardScreen`'s `PageView.builder` keeps no page alive, so a hop to the
Orders tab disposes this State — the chips come back empty while
`StoreController._moduleFilters` is still filtering the list.

The refine sheet has the same `syncSheet(...)` → `setState` + `_pushFilters`
shape that Food's filters sheet had.

**Fix:** the change made for `F-02`, applied here. `ModuleStoreFilters.copyWith`
already exists. The three surfaces that need their own `GetBuilder` once
`setState` goes are the category circles, the refine button's active state, and
the browse header.

</details>

---

### G-02 · The store screen gates its whole render on the category list (`F-03`'s twin) — **DONE**

> The gate is the store payload alone; `setCategoryList()` is called when the
> categories are there and skipped when they are not. The screen is a
> `GetBuilder` on the category controller, so the categories row appears the
> moment its data lands. Identical to the `F-03` change, down to the shape of
> the null check.

<details><summary>The original finding</summary>


```dart
// store_screen.dart:132
if (storeController.store != null && storeController.store!.name != null &&
    categoryController.categoryList != null) {
  store = storeController.store;
  storeController.setCategoryList();
}
if (store == null) return const StoreDetailsScreenShimmerWidget();
```

Same gate, same consequence: a slow or failed `/categories` holds the entire
store — search bar, banners, offers, every product section — behind a shimmer
with the store payload already in hand. And the same aggravating factor as in
Food: since `M-02`, a module change clears the category list, so this is now
*reliably* hit when a grocery store is opened from the dashboard.

**Fix:** as `F-03` — gate on the store payload, call `setCategoryList()` when
the categories are there. The categories row is already behind
`if (storeCategories.isNotEmpty)`, so it degrades on its own.

</details>

---

### G-03 · The grocery store screen builds every category's rail on every build — **DONE**

> `CustomScrollView` + `SliverList.builder`. The fixed sections above and below
> became `SliverToBoxAdapter`s — they were already built eagerly and still are,
> which is correct for a search bar and a banner — and the per-category rails
> became a builder, so one is constructed as it approaches the viewport.
>
> The builder is fed a **pre-filtered** `stockedCategories` rather than the
> full list with an empty check inside `itemBuilder`. Returning
> `SizedBox.shrink()` from a builder still occupies an index, so the viewport
> would have to walk past empty slots to find content; filtering first — a
> cheap list operation that constructs no widgets — keeps the sliver dense.
>
> Pagination is unaffected in kind: the scroll listener reads
> `position.pixels` against `maxScrollExtent`, which works the same on a
> `CustomScrollView`. It is worth knowing that `maxScrollExtent` is now an
> *estimate* extrapolated from the rails laid out so far, so the "within 300px
> of the bottom" trigger fires against a moving target. The rails are uniform
> enough that the estimate is good, and the `!isLoading` + offset guard already
> tolerates the trigger firing more than once.

<details><summary>The original finding</summary>


```dart
// store_screen.dart:155
child: ListView(
  children: [
    …
    ...storeCategories.map((category) {
      final categoryItems = groupedItems[category.id] ?? [];
      if (categoryItems.isEmpty) return const SizedBox.shrink();
      return _buildHorizontalProductSection(…);   // a horizontal ListView of cards
    }),
  ],
)
```

`ListView(children: …)` takes an **already-built** list: every element of that
`map` is constructed on every build of this screen, however far below the fold
it is. A grocery store with 20 stocked categories constructs 20 horizontal
rails and all of their product cards each time the screen rebuilds — and this
screen rebuilds on every `StoreController` update, which includes each page of
paginated items arriving.

Food's store screen was converted to slivers with a builder for exactly this
reason; grocery's was not. This is the same finding as the `Column`-in-a-
`SliverToBoxAdapter` one in the perf programme, one level down.

**Fix:** `CustomScrollView` + `SliverList.builder` for the per-category
sections, so a rail is constructed when it approaches the viewport. The section
widgets themselves need no changes — this is the same move already made on the
food home and the module home screens.

</details>

---

### G-04 · Flash sale is fetched for grocery and shown only in shop — **corrected**

> **The original finding was wrong, and wrong in a way worth recording.** It
> claimed the whole flash-sale feature was dead. It is not:
>
> | link | actual state |
> |---|---|
> | `FlashSaleController.getFlashSale` | called for grocery (`home_screen.dart:290`) and ecommerce (`:296`) |
> | `FlashSaleViewWidget` | **built** by `shop_home_screen.dart:51` |
> | `flashSaleDetailsScreen` route | registered in `route_helper.dart:1215` |
> | `getFlashSaleDetailsScreen(id)` | **called** by `flash_sale_view_widget.dart:101` |
>
> For the shop module the feature is wired end to end: fetch → rail → details.
> The audit searched for `getFlashSaleDetailsRoute`, a name that does not
> exist — the helper is `getFlashSaleDetailsScreen` — found nothing, and read
> the absence as the feature being dead. A grep for a guessed name returning
> nothing is not evidence; it is a failed grep.
>
> What survives is much smaller: **grocery** fetches flash sales and never
> renders them. `GroceryHomeScreen` does not build `FlashSaleViewWidget`, and
> `home_screen.dart:802` shows grocery gets that screen and nothing else. So
> line 290 is one dead request on the grocery home load.
>
> **Resolved: the grocery fetch is gone.** `home_screen.dart`'s
> `ModuleType.grocery` branch is removed; the ecommerce branch below it is
> untouched, as are the controller, the widget and the route. Adding the rail
> to grocery later is one line in each place.

---

### G-05 · Two of the four cart bars are dead — including the one I documented — **DONE**

> Both deleted. `PillCartBar` and `LiveCartWidget` are the two live bars and
> are untouched. The two files were untracked, so this is not a revert away —
> a copy was kept in the session scratchpad, which outlives nothing.

<details><summary>The original finding</summary>


| bar | built by |
|---|---|
| `PillCartBar` | dashboard (global), food store screen |
| `LiveCartWidget` | grocery `StoreScreen` (`:262`) |
| `HomeCartBar` | **nothing** |
| `FoodStoreCartBar` | **nothing** |

`F-05` found `FoodStoreCartBar` dead and corrected the comment in
`home_cart_bar.dart` that described it as live. That comment is inside
`HomeCartBar` — which is *also* dead. The correction was accurate about
`FoodStoreCartBar` and still sits in a file nothing builds.

That is the finding, and it is worth stating plainly rather than quietly fixing:
a dead widget carrying a careful comment about which widget is live is exactly
the artefact that makes the next person trust it.

**Fix:** decide on both files together (see `G-08` — the same decision, on the
same untracked-file footing).

</details>

---

### G-06 · `ModuleBestNearbySection` shimmers forever on failure — **DONE**

> The null branch now asks `HomeController` which case it is in. Both lists are
> fetched under `HomeSection.fastest`, so that is the id the section's
> `GetBuilder` is scoped to: no error recorded means still in flight and the
> shimmer stands; an error means a `SectionErrorView` with a Retry that calls
> `HomeScreen.loadData(true)`. `_safe` clears the flag on a successful retry,
> so the row disappears on its own. Genuinely empty still renders nothing — a
> zone with no open stores is a fact, not something to apologise for.

<details><summary>The original finding</summary>


```dart
final stores = storeController.popularStoreList ?? storeController.latestStoreList;
if (stores == null) return ModuleBestNearbyShimmer(…);
if (stores.isEmpty) return const SizedBox();
```

Null means "not loaded", and a failed fetch leaves it null forever — so the
section shimmers for the rest of the session with no error state and no retry.
The dashboard solved this with `_SectionErrorSlot` + `HomeController.recordError`
(a retry row in the section's own slot) and the store rails distinguish "empty"
from "failed"; this section predates that and never got it.

**Fix:** the `_SectionErrorSlot` pattern, or a `loaded` flag on the controller
lists the way `CuisineController` has one.

</details>

---

### G-07 · The two grocery surfaces disagree about what a category tap means

- **Module home** (`_onCategoryTap`): sets `categoryId` on the store filter →
  `get-stores?category_id=N` → **stores that stock that category**.
- **Dashboard band** (`grocery_shelf_view`'s aisle grid): routes to
  `getCategoryItemRoute` → **items in that category**.

Both are labelled with the same words ("Fresh Produce", "Milk") and drawn as
the same circular tiles. Tapping one gets you a list of shops; tapping the
other gets you a list of products.

The aisle grid is currently switched off (`kGroceryShelfAisles = false`, because
the category art mostly does not exist yet), so this is latent rather than live
— but it is the thing to settle *before* turning that flag back on, not after.

**Fix is a product decision.** Stores-that-stock-it is defensible for a
multi-store module; items-in-it is what a shopper usually means. Pick one, and
make the two surfaces agree.

---

### G-08 · `TopGroceryView` and `TopGroceryStoresView` are built by nothing — **DONE**

> Both deleted. They are tracked, so `git restore` brings back their card and
> shimmer designs if `grocery_shelf_view.dart` ever wants them.


952 lines across two files, zero references outside themselves. Both are
full rail implementations — cards, shimmers, module-activation handlers — from
earlier passes at the dashboard's grocery band, superseded by
`grocery_shelf_view.dart`.

> **Correction:** both files are **tracked** in git, not untracked as first
> written. Deleting them is a revert away, which lowers the stakes considerably
> — the "unrecoverable" framing applies to the two cart bars in `G-05`
> (`home_cart_bar.dart` and `food_store_cart_bar.dart`), which really are
> untracked, and not to these.

---

### G-09 · No test covers the grocery module

As with Food before `F-02`: nothing exercises the category filter round trip,
the store screen's gate, or the browse sheet. `ModuleStoreFilters` is now
covered by `food_filters_test.dart` and that coverage is shared — `categoryId`
is grocery's field and is already asserted there.

---

## Part 2 — Phased plan

### Phase 1 — Apply the two Food fixes (`G-01`, `G-02`) — **DONE**

Both were ports of changes already made and verified this week: the filter-state
move and the store-screen gate, in one pass.

**Verify:** grocery home → a filter → Orders tab → Home tab, chips still lit;
open a grocery store cold, content appears before the category row does.

### Phase 2 — The eager store screen (`G-03`) — **DONE**

`CustomScrollView` + `SliverList.builder` for the per-category sections.

**Verify:** the store screen scrolls to the bottom with all sections present and
in the same order; pagination still appends near the bottom.

### Phase 4 — Section failure states (`G-06`) — **DONE**

Taken before Phase 3, because Phase 3 is blocked on decisions and this was not.
`ModuleBestNearbySection` now tells "in flight" from "failed", which closes the
last "shimmers forever" surface outside the dashboard.

### Phase 3 — Decide on the dead weight (`G-04`, `G-05`, `G-08`) — **DONE**

Three decisions, all taken the same way: remove it.

1. Grocery's flash-sale fetch — **dropped**. Shop's is untouched.
2. `HomeCartBar` / `FoodStoreCartBar` — **deleted**, 839 lines. Untracked, so
   gone for good.
3. `TopGroceryView` / `TopGroceryStoresView` — **deleted**, 952 lines. Tracked,
   so a `git restore` away.

1,791 lines of widget code and one request per grocery home load.

---

## Out of scope

- The generic `StoreScreen`'s use by pharmacy and shop. `G-02` and `G-03` touch
  it, and the fixes are module-agnostic, but the other two modules' own home
  screens are not audited here.
- `ModuleCategoryCircles`' internals. It is shared with Food's cuisine strip and
  behaves correctly in both; only its "all" tile reads the popular/latest lists,
  which `F-04` already accounted for.

## Verification discipline

`flutter analyze` and `flutter test` after every phase — never a build; the user
tests on device (`no-builds-user-tests`). Exclude
`test/golden/marks_render_test.dart`; 133 tests pass without it. **Do not run
`dart format`** on this repo's files — see the note in `food_module_plan.md`.
