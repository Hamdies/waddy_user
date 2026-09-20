# Food module — audit and fix plan

**Date:** 2026-09-15 · **Scope:** `waddi_user`, the Food module end to end —
home, store, rail, filters, cart bar
**Status:** `F-01`–`F-05` and `F-07` landed 2026-09-15 (`F-01`'s backend half
needs a deploy). `F-06` is a deploy; `F-08` reassessed and deferred; `F-09` open.

Findings are `F-01`…`F-09`, referenceable from commits the way `M-*` is used in
`module_architecture_plan.md` and `CC-*` in `cart_checkout_fix_plan.md`.

The surface: `food_home_screen.dart` (1,525 lines), `food_store_screen.dart`
(2,371), `top_restaurants_view.dart` (1,818), `cuisine/` (controller, model,
repo, service), `food_store_cart_bar.dart` (508).

---

## Summary

Food is the module the app is built around, and it is in better shape than the
module *system* was — `CuisineController` is a model of how a list controller
should look (cache-first, TTL, in-flight dedupe, an explicit `loaded` flag), and
both screens are properly sliver-based.

The problems are of three kinds:

1. **One rail's headline is not true of its data** (`F-01`) — the same defect
   just fixed on the dashboard chart, still live on its sibling, on the screen
   users see most.
2. **State that exists twice and is allowed to drift** (`F-02`) — the same
   shape as `M-03`, with a reproducible user-visible consequence.
3. **Work the module pays for and never shows** (`F-04`, `F-05`), plus one
   render gate that is stricter than it needs to be (`F-03`).

`F-01` and `F-02` are the two worth doing first. Neither is large.

---

## Part 1 — Findings

### F-01 · The ranked rail's headline is not true of its data — **DONE**

> **Resolved by backing the numerals, not dropping them.** A numbered rank is
> one of the strongest attention patterns available and the competition framing
> is worth keeping; the fix was never "lose the numbers", it was "make the
> numbers mean something". Featured stores are already hand-picked, so they are
> now hand-*ordered* at the same time:
>
> - `stores.featured_order` — nullable smallint, migration
>   `2026_09_15_000001`, indexed with `featured`. Null means featured but
>   unranked: still shown, always behind every ranked store.
> - `StoreLogic::get_stores` orders the featured branch by
>   `featured_order IS NULL, featured_order ASC` — NULLs last explicitly,
>   because MySQL sorts them first ascending, and *before* the trailing
>   `orderBy('open')` so position is primary and open-now is the tiebreak
>   between equal ranks.
> - Admin: a number input beside the featured toggle in the store list, shown
>   only once a store is actually featured. Un-featuring clears the rank, so a
>   store cannot silently return at #3 when someone toggles it back on.
> - Client: `Store.featuredOrder` parsed; `_rankFeatured` re-applies the order
>   (the server already sorts, but the same list is served from the drift cache
>   written before the field existed, and a ranking that is only right on a
>   fresh response is not a ranking). Stable: equal ranks keep the server's
>   order.
> - Copy: "Most ordered this week" → **"Our top 10, ranked"** / "أفضل ١٠ عندنا،
>   بالترتيب". The numerals now say exactly what they look like they say.
>
> `test/unit/featured_rank_test.dart` pins it: chosen order, unranked-last,
> duplicate ranks, empty list. **The backend half needs a deploy + `php artisan
> migrate`.** Until then `featured_order` is absent from the payload, every
> store parses as unranked, and the rail keeps the server's order — the old
> behaviour, with honest copy over it.
>
> Still open from this finding: the empty-match fallback can still show
> non-food stores inside Food, and "Maadi" is hardcoded in the headline.

<details><summary>The original finding</summary>

`TopRestaurantsView` renders **"Top 10 Maadi spots / Most ordered this week"**
with rank numerals 1…10 painted on the photos. Its data:

```dart
// top_restaurants_view.dart
List<Store>? allStores = storeController.featuredStoreList;
```

`featuredStoreList` is `GET /stores/featured` — the **admin's `featured` flag**,
returned in whatever order the query produced. Nothing anywhere computes an
order count, and nothing computes "this week". The numerals promise a ranking
the data does not carry.

This is the identical defect that was just fixed one screen over: the
dashboard's `_QuickStoresSection` now asks for `store_type=popular` and ranks on
`orders_count`, with the subtitle changed to match. The food home's rail — the
more prominent of the two — still makes the older, stronger claim.

Two smaller problems in the same widget:

- The module filter falls back to *unfiltered* when it matches nothing
  (`restaurantList = matched.isEmpty ? allStores : matched`). On the dashboard
  that is the right call (trust the server's scoping). Inside the Food module it
  means a payload whose module ids disagree renders **grocers in a restaurant
  rail** rather than an empty one.
- `top_10_maadi_spots` and `nearest_zone_maadi` hardcode Maadi in both language
  files. Correct today, one zone launch from being wrong in a headline.

**Fix:** feed it the same way the dashboard chart is now fed (module-pinned
`store_type=popular`, ranked by orders, open-first), or — if "featured" is the
intended curation — drop `ranked:` and say "Featured". Either is honest; the
present combination is not.

</details>

---

### F-02 · Filter state exists twice, and the copies drift — **DONE**

> `StoreController.moduleFilters` is now the only copy. The screen's five
> fields became getters that read it, and every handler starts from the current
> filters and changes the one thing it is about, via a new
> `ModuleStoreFilters.copyWith`.
>
> `copyWith` takes **sentinels**, not plain nullables: a nullable parameter
> cannot tell "leave this alone" from "clear this", and every one of these
> fields is cleared by tapping its own control a second time.
>
> Removing `setState` meant finding what actually repaints. Three things read
> filter state and only one was already subscribed:
>
> | surface | before | now |
> |---|---|---|
> | catalogue header, store list | `GetBuilder<StoreController>` | unchanged |
> | chip strip | rebuilt by `setState` | its own `GetBuilder` inside the pinned header |
> | cuisine circles | rebuilt by `setState` | wrapped in a `GetBuilder` |
>
> The strip lives inside a pinned `SliverPersistentHeader` whose delegate is
> built by the screen's `build`, and nothing rebuilds that on a filter change
> once the state moved — so the strip subscribes for itself. That also deleted
> the delegate's `signature`: it existed only to make the header repaint when
> one of the five local fields changed, and `shouldRebuild` is now `false`,
> because a self-updating child and a fixed height leave it nothing to compare.
>
> The filters sheet was a `StatefulBuilder` re-reading the screen's fields; it
> is a `GetBuilder` now, which also makes its footer's result count live rather
> than a number read once when the sheet opened.
>
> `test/unit/food_filters_test.dart` pins the model: one filter changing leaves
> the rest alone, null clears rather than being ignored, the sheet's reset
> clears only what the sheet owns, and every filter lands in the query under
> its contracted name.
>
> **Same defect still live in grocery.** `grocery_home_screen.dart` keeps
> `_selectedCategoryId`, `_filterOffers`, `_filterUnder30`,
> `_filterFreeDelivery` in `setState` and pushes them the same way — identical
> shape, identical tab-hop reproduction. Not fixed here because this plan is
> food-scoped; it is a direct copy of this change when someone picks it up.

<details><summary>The original finding</summary>

The food home holds the filter state in `State`:

```dart
int? _selectedCuisineId;
bool _filterOffers = false;
bool _filterUnder30 = false;
bool _filterFreeDelivery = false;
String _selectedSort = 'default';
```

and pushes it into the controller, which holds the same facts again:

```dart
void _pushFilters() => Get.find<StoreController>().setModuleStoreFilters(
  ModuleStoreFilters(offers: _filterOffers, freeDelivery: _filterFreeDelivery,
    maxDeliveryTime: _filterUnder30 ? 30 : null, sort: …, cuisineId: …));
```

It pushes and never reads back. `initState` does not restore from
`StoreController.moduleFilters`, and the chips render from the local copy while
the *list* renders from the controller's.

They drift on a path users take constantly: `DashboardScreen` uses a
`PageView.builder` with no keep-alive, so switching to Orders/Account and back
**disposes the food home's `State`**. Its filters reset to defaults;
`_moduleFilters` does not (nothing clears it on a tab hop — only a module change
does, via `clearModuleStoreFilters`).

**Reproduction:** food home → "Free delivery" → Orders tab → Home tab. The chip
row shows nothing selected; the list is still free-delivery only, and the
catalogue header still counts the filtered result. The only way back to the full
list is to toggle the chip on and off again.

Same shape as `M-03`: two stores of one fact, no owner.

**Fix:** the controller owns filter state; the screen renders from it. Reading
`moduleFilters` in `initState` is the one-line version; moving the five fields
out of `State` entirely is the real one.

</details>

---

### F-03 · The store screen gates its whole render on a list only its tabs need — **DONE**

> The gate is the store payload alone. The category list is consulted when it
> is there and skipped when it is not, and the tab strip degrades to its
> synthetic "full menu" tab — which is the tab that shows everything anyway.
> The screen is a `GetBuilder` on the category controller, so tabs appear the
> moment their data does.

<details><summary>The original finding</summary>

```dart
// food_store_screen.dart
if (storeController.store != null &&
    storeController.store!.name != null &&
    categoryController.categoryList != null) {   // ← global category list
  store = storeController.store;
  storeController.setCategoryList();
}
if (store == null) return const _FoodStoreScreenShimmer();
```

The global category list is used for exactly one thing: `setCategoryList()`
intersects it with `store.categoryIds` to build the tab strip. But the gate
covers **everything** — hero, name, rating, offers, menu rows, prices, the cart
bar. If `/categories` is slow the whole screen shimmers with the store payload
already in hand; if it fails, it shimmers indefinitely.

Worth stating precisely, because the module work changed the odds here: before
`M-02`, opening a food store from the dashboard left whatever module's category
list was already loaded, so the screen rendered *immediately* and the tab strip
was silently built from the **wrong module's** categories. Now the list is
cleared on module change, so the screen is correct — and blocking. That trade
was an improvement; it is not the end state.

**Fix:** gate on the store payload alone. Render the menu as soon as it is
there, and let the tab strip appear when its categories do (it already has an
"all" tab, so the menu is usable without it).

</details>

---

### F-04 · Two requests per food-home load that nothing on the screen renders — **DONE**

> **The finding held; its prescription did not.** The plan said "move
> popular/latest behind the pharmacy branch". Checking the call sites first —
> the habit this repo has now earned twice — those lists have four consumers,
> not one:
>
> | consumer | screens | needs the lists |
> |---|---|---|
> | `ModuleBestNearbySection` | grocery | yes |
> | `ModuleCategoryCircles` (the "all" tile) | grocery | yes |
> | `PopularStoreView` / `NewOnMartView` | shop, pharmacy | yes |
> | `BestStoreNearbyView` | pharmacy | yes |
> | `ModuleCuisineCircles` | **food** | **no** — food passes `showAllTile: false`, and that tile is the only thing in the widget that reads them |
>
> So the guard is `moduleType != ModuleType.food`, not "pharmacy only" —
> moving them behind pharmacy would have emptied grocery's best-nearby section
> and shop's two rails. `NearbyStoresHeroView` also reads `latestStoreList` and
> is built by nothing at all.
>
> The `all_store_screen` "see all" destinations fetch in their own `initState`,
> so nothing downstream depended on the prefetch. The stale comment that named
> "best-nearby (popular/latest stores)" as part of the food home is corrected
> to describe the two screens as they actually are.

<details><summary>The original finding</summary>

`HomeScreen.loadData` fetches `getPopularStoreList` and `getLatestStoreList` for
every non-parcel module, justified in the comment as:

> Waddi's food & grocery homes are custom screens that render banners,
> categories, best-nearby (popular/latest stores), the store list and reorder
> chips.

The only consumer of those two lists is `BestStoreNearbyView`, and the only
screen using it is `pharmacy_home_screen.dart`. Food home renders no
best-nearby section and no category strip; verified by symbol:

| list | rendered by food home | rendered by food store |
|---|---|---|
| `popularStoreList` | no | no |
| `latestStoreList` | no | no |
| `recommendedStoreList` | no | no |
| `discountedItemList` / `popularItemList` | no | no |

`categoryList` is the honest exception — food home does not use it, but the food
*store* screen does (`F-03`), so fetching it on module entry is legitimate
pre-warming, for a different reason than the comment gives.

**Fix:** move popular/latest behind the pharmacy branch. Two fewer requests on
every food and grocery home load, and a comment that describes the screen that
exists.

</details>

---

### F-05 · `FoodStoreCartBar` is 508 lines of dead code, documented as live — **PARTLY DONE**

> The comments are fixed — `home_cart_bar.dart` now orients the reader around
> the bars that are actually built (`PillCartBar`, `LiveCartWidget`, itself)
> and says plainly that `FoodStoreCartBar` is not one of them;
> `pill_cart_bar.dart` no longer contrasts itself with a widget nothing
> constructs. That was the part doing harm: a comment naming a dead widget is
> the one a newcomer trusts.
>
> **The file itself is left in place, deliberately.** It is untracked
> (`git status` reports `??`), so deleting it is unrecoverable — not a revert
> away. It is also not compiled into the app: nothing imports it. The call is
> yours; `rm lib/features/store/widgets/food_store_cart_bar.dart` is the whole
> of it, and nothing depends on it going.

<details><summary>The original finding</summary>

`grep -rn FoodStoreCartBar lib` returns its own definition and two doc comments
that describe it as one of three live bars:

> `FoodStoreCartBar` — "what is in my cart at THIS restaurant"

The food store screen uses `PillCartBar` (`food_store_screen.dart:412`). The
comment in `home_cart_bar.dart` that orients a reader among "the three bars" is
therefore describing a widget nothing builds — the most expensive kind of stale
comment, because it is the one a newcomer trusts.

---

### F-06 · The "Under 30 min" chip empties the catalogue (backend, pending deploy)

`maxDeliveryTime: _filterUnder30 ? 30 : null` → `max_delivery_time=30` →
`having('min_delivery_time','<=',30)`, where `min_delivery_time` is a computed
SQL alias that returned **9999 for every seeded store** because the CASE only
understood `"30-45 min"`, not the bare `"30-45"` the seeders write.

Fixed in `waddy_back` on 2026-09-15 (`Store::scopeWithOpenWithDeliveryTime`,
`REGEXP "^[0-9]"` branch) — **not yet deployed**. Until it is, that chip returns
zero restaurants for any value. See `get-stores-filter-contract` in memory.

**Action:** deploy, then verify the chip against the live catalogue — with the
Maadi data as it stands, "under 30" is Zooba, Butcher's Burger, Auntie Anne's
and Vinny's; Ama Sushi (35-50) should drop out.

---

### F-07 · Both food screens rebuild wholesale on every `setState` — **DONE**

> `_showScrolledHeader` is a `ValueNotifier<bool>` consumed by a
> `ValueListenableBuilder` that wraps only the header's opacity and pointer
> gate. The bar itself is passed as the builder's `child`, so it is built once
> per screen build and a scroll past the threshold no longer rebuilds the hero,
> store header, rating card, stats strip, tab strip, cart bar and every menu-row
> builder to fade in a widget that was already laid out.
>
> The two measurements stay on `setState`: both are once-per-layout and settle
> before the user can scroll.
>
> That leaves three `setState` triggers on this screen — two layout
> measurements at startup, and a tab tap, where the menu genuinely changes. See
> `F-08` for why that changes the case for the rest of it.

<details><summary>The original finding</summary>

`_FoodStoreScreenState` drives four pieces of state through `setState` on the
whole screen: `_showScrolledHeader` (on scroll), `_scrolledHeaderHeight` (post-
frame measurement), `_cartBarHeight` (measurement), `_selectedTabIndex`. Each
rebuilds `build()` — hero, header, stats strip, tab strip, cart bar and the
sliver list's builders.

The slivers keep the *list* cost bounded, so this is not the `Column`-in-a-
`SliverToBoxAdapter` problem that was already fixed elsewhere; it is the
everything-above-the-list cost, paid on a scroll threshold crossing. The pattern
that solved the same problem on the dashboard is here already:
`HomeScreen._scrollOffset` is a `ValueNotifier` feeding a `ValueListenableBuilder`
around only the strip that repaints.

**Fix:** `_showScrolledHeader` → `ValueNotifier<bool>`, consumed by the header
overlay alone. The two measurements are once-per-layout and can stay.

</details>

---

### F-08 · `_buildX` methods instead of widgets — **DEFERRED, and the reason matters**

> The finding stands as a description: these are still methods, and methods
> cannot be `const` or usefully `RepaintBoundary`-d.
>
> But its *justification* was "every one of them re-runs on every `setState` of
> the host `State` (`F-07`)" — and `F-07` removed the `setState` that was firing
> mid-scroll. What is left is two layout measurements at startup and a tab tap
> that changes the menu anyway. Promoting the methods now buys a bounded
> rebuild on a rebuild that happens three times per visit.
>
> Against that: it is several hundred lines of diff in a 2,300-line file, with
> no behaviour change to show for it. Worth doing when the file is being opened
> for another reason; not worth opening it for.

<details><summary>The original finding</summary>

Both screens are built from `Widget _buildHero(...)`, `_buildStoreHeader(...)`,
`_buildMenuRow(...)` — 20+ between them. Methods cannot have `const`
constructors, cannot be `RepaintBoundary`-d meaningfully, and every one of them
re-runs on every `setState` of the host `State` (`F-07`), whether or not its
inputs changed.

This is the readable end of `F-07` and the cheapest thing to do *after* it:
promoting the three biggest (`_buildHero`, `_buildMenuRow`, `_buildStoreHeader`)
to real widgets with their own `const` constructors bounds the rebuild without
touching behaviour.

</details>

---

### F-09 · No test covers the food module

Nothing in `test/` exercises cuisine filtering, the filter-state round trip, the
store screen's gate, or the rail's data source. `F-02` in particular is exactly
the kind of bug a three-line controller test pins forever.

---

## Part 2 — Phased plan

### Phase 0 — Safety net

`test/unit/food_module_test.dart`:

- filters set on the controller survive a screen rebuild and the chips reflect
  them (**fails today** — `F-02`)
- `ModuleStoreFilters.toQueryString()` emits `cuisine_id` and `max_delivery_time`
  exactly as the backend contract expects (`get-stores-filter-contract`)
- the ranked rail's source list is module-scoped (**pins `F-01`'s fix**)

**Verify:** the first fails, the others pass. Same discipline as `M-*` Phase 0 —
the audit reproduces itself before anything is changed.

### Phase 1 — Tell the truth on the rail (`F-01`) — **DONE**

Resolved by adding the editorial rank rather than by changing the data source
or dropping the numerals — see the finding above. What remains from it, and is
*not* done: narrowing the empty-match fallback so a food rail cannot fall back
to every module's stores, and the hardcoded "Maadi".

### Phase 2 — One owner for filter state (`F-02`) — **DONE**

See the finding above. Worth re-testing by hand: food home → "Free delivery" →
Orders tab → Home tab. The chip should still be lit and the list still filtered,
because they are now the same fact.

### Phase 3 — Unblock the store screen (`F-03`), drop the dead weight (`F-04`, `F-05`)

- Gate on the store payload; let the tab strip fill in late.
- Move popular/latest store fetches behind the pharmacy branch and correct the
  comment.
- Delete `food_store_cart_bar.dart` and fix the two comments that describe it.

**Risk:** `F-03` is the only one with behaviour to check — confirm the tab strip
still populates on a cold open, and that `setCategoryList()` is called once the
categories land rather than only inside the gate.

### Phase 4 — Rebuild scope (`F-07`, `F-08`) — **`F-07` DONE, `F-08` deferred**

The scroll threshold is off `setState`. The widget promotion is deferred because
`F-07` removed the reason for it — see `F-08` above.

> **Note on the diff.** `dart format` was run on `food_store_screen.dart` while
> making this change and reformatted the whole file: ~700 lines of cosmetic
> churn around a ~30-line edit. It could not be cleanly undone — the git index
> copy of that file predates other unstaged work in it, so restoring would have
> destroyed real changes. The file is correct and analyzes clean; the diff is
> just noisier than the change warrants. Don't run a formatter across files this
> repo has not already formatted.

---

## Out of scope

- The backend `max_delivery_time` fix (`F-06`) — already written, waiting on a
  deploy the user owns.
- `ItemBottomSheet`'s food-variation handling — it is shared with every other
  module and belongs to a cart/item audit, not this one.
- The Maadi-hardcoded copy — flagged in `F-01`, but it is a launch question
  (which zones, what do they call themselves), not a refactor.

## Verification discipline

`flutter analyze` and `flutter test` after every phase — never a build; the user
tests on device (`no-builds-user-tests`). Exclude
`test/golden/marks_render_test.dart`; 122 tests pass without it.
