# Store architecture plan — `ST-*`

Audit written 2026-09-30. It started from a bug report: open a restaurant after
browsing a grocery store and the menu says "no items". The fix for that one is
in (`ST-01`, Phase 0). Tracing it showed that the bug came from the design, not
from a single slip:

> One `StoreController` (1,632 lines, a permanent GetX singleton) holds four
> different kinds of state. Everything that needs any of them reads the same
> object: the store page on screen, the cart, checkout, the home rails and the
> dashboard.

This plan splits it by who owns the state, not by module. A separate food
controller and grocery controller would not help: two supermarkets leak state
into each other exactly the way grocery leaked into food.

Evidence is from source and the device log of 2026-09-30. Nothing was profiled
beyond that log.

---

## Master status

| ID | Finding | Sev | Status | Phase |
|---|---|---|---|---|
| `ST-01` | The previous store's browsing state (selected category, sub-category chip, sub-category cache) leaks into the next store → "no items" | P0 | **structural fix landed 09-30** (Phase 4: per-page controller; the Phase 0 reset is deleted) | 0 → 4 |
| `ST-02` | `StoreController.store` means two things: "the store page on screen" and "the store the cart/checkout is about". The cart screen overwrites it. **Confirmed on device 09-30: the page shows the cart store's header over its own menu** | ~~P1~~ **P0** | **landed 09-30** (device re-check pending) | 3 |
| `ST-03` | The cart bars price the cart against whichever store is at hand: the last checkout's, else the last page's. Neither is the cart's store | ~~P1 (verify)~~ **P3**: re-read 09-30, a wrong store cannot change the figure (see §2) | **landed 09-30** (structural) | 3 |
| `ST-04` | 29 places open a store and use 4 different rules to pick the layout. Restaurants opened from Order Again, search, store cards, banners, XP or deep links get the **supermarket aisle** page | P1 | **landed 09-30** (`StoreNavigator` + `StoreLayout`) | 5 |
| `ST-05` | The module is activated at some store-open sites and not others (visit-again card, popular card, highlights, XP, item title, deep link) | P2 | **landed 09-30** (the navigator always switches; the route shell does it for id-only opens) | 5 |
| `ST-06` | `StoreScreen` embeds `FoodStoreScreen` for specialty grocery: two `initState`s, store details fetched twice, and a `_menuStyle` latch to survive the blank in between | P2 | **landed 09-30** (embed and latch deleted; the shell picks the page first) | 5 |
| `ST-07` | Rebuild radius: 44 `GetBuilder<StoreController>` in 26 files, 54 `update()` calls, 1 scoped. Every store-page change rebuilds the home underneath, including a scroll-direction toggle | P1 perf | **landed 09-30** (Phase 1 dead toggles; Phase 4: page updates leave home alone; Phase 6: every list update scoped by id) | 1, 4, 6 |
| `ST-08` | `_type` is shared by the home store lists (`getPopularStoreList` writes it) and the store menu's item type | P2 | **landed 09-30** (the page owns its item type) | 4 |
| `ST-09` | `getRestaurantRecommendedItemList(reload: true)` nulls `_storeModel` (the home store list), not the recommendations | P3 (latent, no caller passes true) | **landed 09-30** | 1 |
| `ST-10` | No shared store-details cache: the page, the cart screen, checkout and the item sheet each fetch or hand-seed the same store | P2 | **landed 09-30** | 2 |
| `ST-11` | `getStoreDetails(fromModule: true)` calls `HomeScreen.loadData(true)`. Every store opened from the dashboard fires a **full home reload (13–20 requests, ~200 KB)** that competes with the store page | P1 perf | **landed 09-30** (home now loads on return, see correction in §2) | 1 |
| `ST-12` | Dead members: prescriptions, similar stores, top-offer filter/sort setters, `setLowerValue`/`setUpperValue`, `shareStore`/`filteringUrl`, `currentState` (whose 3-second delayed `update()` still rebuilds everything) | P3 | **landed 09-30** (controller members; the service/repo similar-store and link-url methods remain) | 1 |
| `ST-13` | The two store screens open differently: menu requested before details (food) vs after (grocery). That difference is why `ST-01` hit only one direction | P2 | **defused 09-30**: with per-page state the order can no longer leak anything; one shared open sequence folds into Phase 5 | 4 → 5 |
| `ST-14` | Pure store rules (`isStoreOpenNow`, `isStoreClosed`, `isOpenNow`, `getDiscount`, `getRestaurantDistance`) live on the controller, so checkout and cards `Get.find` 1,600 lines to call a function of a `Store` | P3 | **landed 09-30** | 2 |
| `ST-15` | `LocationController` line 1436 reads `Get.find<StoreController>().store!.moduleId`. `getStoreDetails` nulls `_store` during every fetch, so a zone change in that window throws | P2 | **landed 09-30** | 1 |
| `ST-17` | Dashboard "Order again" empty on every cold start: the backend filtered `visit-again` by the moduleId header, which the dashboard never sends; the dashboard and module homes shared one list (so it only filled after opening a module, then showed that module's stores); the dashboard's empty reply was cached under the last module's key; and the zone filter force-unwrapped `module.pivot` | P1 | **fixed 09-30** (found on device); **backend deploy needed** | 6 |
| `ST-18` | The cart bar judged a non-empty cart by the PAGE's store: a 150 LE Seoudi cart showed "Add 50 LE to start your order" (greyed out) on Al Dahan's page, against Al Dahan's 200 LE minimum. The cart bar's twin of ST-02 | P1 | **fixed 10-01** (found on device): `PillCartBar.rulesStoreFor`, empty cart → page's store, else the cart's own store (`CartController.cartStore`) | 3 |
| `ST-16` | Same shape outside the store feature: `CategoryController` holds the category items page's state (`_subCategoryIndex`, `_categoryItemList`, `_isSearching`) as a singleton. **Audited 09-30: it leaks** the item type, search mode, filters and the items/stores tab flag (the body compares the visible tab with that flag), and has no stale-response guard | P2 | **landed 09-30** (`CategoryPageController`) | 7 |

Severity: **P0** wrong result users hit, **P1** wrong result or heavy cost on
a main path, **P2** latent or narrower, **P3** cleanup.

## Verify on device

Tick these as phases land. "(verify)" findings are first checked here, before
any code for them is written.

- [x] **ST-01**: supermarket → "View all" on an aisle → pick a sub-chip → back to home → open a restaurant. The menu loads first time, and the first request says `category_id=0` (device 09-30: store 29 aisle 80, chip 172, then restaurant 33 sent `category_id=0`; the same run showed no home load on the `page=module` open and one `stores/details` per store)
- [ ] **ST-01**: open supermarket A aisle 97, then supermarket B aisle 97. B's chips are B's
- [ ] **Phase 4**: repeat the original bug (supermarket → "View all" → a sub-chip → home → restaurant). The menu loads, `category_id=0`
- [ ] **Phase 4**: on a supermarket, the aisle page's chips, filter sheet (Apply refreshes the aisle page's rails too) and pagination all work
- [ ] **Phase 4**: in-store search from a restaurant page and from an aisle page: results appear, and the cart bar shows
- [ ] **Phase 4**: a specialty grocery store (Al Dahan) still opens as a menu page with its own tabs
- [ ] **Phase 4**: open store A, then store B on top of it (e.g. from an item sheet's store link), go back. A is exactly as you left it (tab, scroll, menu)
- [x] **ST-02** reproduced 09-30. Cart from Butcher's Burger (33), opened Zooba (34), cart → back: Zooba's page showed Butcher's Burger's name, logo, cover, cuisines, address, delivery time, fee and discount banner over Zooba's menu (Taameya, Foul)
- [ ] **ST-02** after Phase 3: the same steps, and Zooba's header stays Zooba's
- [x] **Phase 3**: cart → checkout still opens at once (device 09-30: `checkout open: requests 0, wall 624ms`); **a real order placed on the new path (#100060)**
- [ ] **Phase 3**: the cart header shows the cart store's name
- [ ] **Phase 3**: at checkout, apply a coupon (it is now checked against checkout's own store), and open the time-slot sheet ("now" for an open store)
- [x] **Phase 3**: opening a store page no longer sends `config/distance-api` or `vehicle/extra_charge`; checkout still sends them once (device 09-30: store 34 opened with 4 requests; distance + extra charge once, from checkout)
- [x] ~~**ST-03** (reproduce first)~~: not needed. The source shows the figure cannot change (see §2)
- [ ] **ST-04/Phase 5**: open a restaurant from search, dashboard "Order again", a store card and a deep link. Always the menu page
- [ ] **Phase 5**: a supermarket from any of those still gets the aisle page; a butcher/dairy gets the menu page straight away (no aisle shimmer first)
- [ ] **Phase 5b**: a butcher/dairy (Al Dahan) opens with the restaurant-style cover header, then tabs over a 2-column product grid with + / stepper on each tile
- [ ] **Phase 5b**: a restaurant (Butcher's Burger) looks exactly as before: cover photo, big name, list rows
- [ ] **Phase 5b**: the supermarket aisle page's "View all" grid still looks and adds the same (it now uses the shared tile)
- [ ] **Phase 5**: from an item sheet's store link and the XP screen's "order from X": the right page, after a brief shimmer (these know only the store id)
- [ ] **ST-05/Phase 5**: from the dashboard, open a store from a visit-again card and the XP screen. Its categories and banners are that module's, and going back shows that module's home
- [x] **ST-11**: open a store from the dashboard. The log shows **no** `── API home load` block while the store loads (device 09-30, store 33 `page=module`)
- [x] **ST-11**: then press back. The module home fills in (device 09-30). **Open:** that load came in as `loadData(true)` "(refresh)", which is not the `didPopNext` hook's call. The tracer (below) will name the caller on the next dashboard → store → back
- [x] **ST-11**: open a store from *inside* a module home and go back. No home load (device 09-30: `home loadData(reload: false) ← didPopNext`, returned inside the quiet window)
- [x] **ST-10**: cart → checkout opens with no network wait (device 09-30: `checkout open: requests 0, wall 597ms, janky 0`); the cart screen sent no `stores/details`
- [ ] **ST-10**: open a specialty grocery store through `StoreScreen` (search, a store card). One `stores/details`, not two. (09-30 run opened Al Dahan straight into the menu page, which does not exercise this)
- [ ] **ST-14**: store cards still show the open/closed badge and the discount tag; checkout's time-slot sheet still offers "now" for an open store
- [ ] **ST-07**: store pages still open and scroll normally, and the food store's collapsing header still appears past the hero
- [ ] **Phase 6**: cold-open the app and each module home. Every section fills in (popular, latest, featured, top offers, visit again, recommended, dashboard rails, the cuisine/store-type strip with its logos, the paginated store list). A section that never appears means its builder's id is not notified
- [ ] **Phase 6**: on the food and grocery homes, tap filter chips and a cuisine tile. The list, the headline count and the chip/tile selection all update
- [ ] **Phase 6**: compare `── FRAMES home load` with the 09-30 baseline (build avg 2.1–8.8ms, worst 41–302ms). Build time should drop
- [ ] **ST-17** (after the backend deploy): cold-open the app. The dashboard's "Order again" shows stores from every module straight away. Open Food and go back: the dashboard row is unchanged (it is not replaced by food-only stores)
- [ ] **ST-18**: cart from Seoudi, open Al Dahan: the bar shows Seoudi's state (XP / free delivery), not "Add 50 LE…", and View Cart is active. With an EMPTY cart, Al Dahan's page still shows its own minimum
- [ ] **ST-07**: scroll a store page up and down. No `home load`-style FRAMES block for home builders (DevTools rebuild counts on home widgets stay flat)

---

## 1. What `StoreController` holds today

Every public member was mapped to the files that read it (grep over the 39
files that reference the controller; generic names like `.type` / `.rating`
were checked by hand). There are four kinds of state:

| Kind | Members | Real owner | Readers outside `features/store` |
|---|---|---|---|
| **A. The store page on screen** (per visit) | `categoryList`, `categoryIndex`, sub-categories + chip, `storeItemModel` + pagination, aisle rails, filter sheet (`rating`, prices, available/discounted, `sortIndex`, `filter`), `type` (veg/non-veg), in-store search (`isSearching`, `searchText`, `storeSearchItemModel`), `recommendedItemModel`, `storeBanners`, `storeBundleList`, `showFavButton`/`currentState` | One store page, and the pages pushed from it (aisle page, search, filter sheet) | none (the home hero reads `showFavButton`, which should not exist) |
| **B. The store the cart and checkout are about** | `store` (as read by cart/checkout), plus `getStoreDetails`' side effects: time slots, order type, distance, `clearPrevData` | The cart | `cart_screen` ×3, `cart_controller` ×2, `checkout_controller`, `coupon_section`, `extra_packaging_widget`, `location_controller`, `time_slot_bottom_sheet` |
| **C. Discovery lists** | `storeModel` + `moduleFilters`/`filterType`/`storeType`, popular / latest / topOffer / featured / visitAgain / recommended, `mostOrderedFoodStores`, `quickGroceryStores`, `storeRecommendedItems`, `cartSuggestItemModel` | Home / dashboard / "all stores" | 20+ home widgets |
| **D. Pure rules** | `isStoreOpenNow`, `isStoreClosed`, `isOpenNow`, `getDiscount`, `getDiscountType`, `getRestaurantDistance` | Nobody: they are functions of a `Store` | checkout, 3 card widgets, `best_store_nearby_view` |

Kind A is the only state that belongs to a page, and it is held in a singleton.
Kinds A and B share one field, `_store`. Kinds A and C share one `update()`.

## 2. Evidence per finding

### ST-01 — browsing state outlived the store (P0, interim fix landed)

The log: grocery store 31, then the category page for 97, then back, then
restaurant 33. The first request is
`items/latest?store_id=33&category_id=97`. Store 34 and then back to 33 sends
`category_id=0`.

`FoodStoreScreen._initDataCall` requests the menu *before* store details (to
paint faster). `getStoreItemList` built `category_id` from `_categoryIndex`,
which still pointed at the grocery aisle, because only `getStoreDetails` reset
it and that ran second. `_itemsCategoryOverride` (the sub-chip) was cleared by
nothing except the aisle page itself. `_subCategories` was keyed by category
id alone, across stores.

**Interim fix (09-30):** `StoreController.resetStoreBrowsing()` is called first
in both screens' `_initDataCall`. `getStoreItemList` now drops responses
superseded by a newer first-page request (`_itemListGeneration`). Phase 4
removes the need for both: a new page starts with nothing to reset.

### ST-02 — one `store` field, two meanings (P1)

`cart_screen.dart:156` calls `getStoreDetails(Store(id: cartStoreId, name: null), fromCart: true)`.
With `name == null` that takes the fetch path. It sets `_store = null`, awaits,
then sets `_store` to the cart's store. If a store page is under the cart
(cart opened from that page's cart bar), that page's `GetBuilder` rebuilds
twice: first on no store (shimmer), then as **the cart's store**. That store is
a different one whenever the user opened B while holding A's cart.
`categoryIndex` is reset too.

Checkout hides the problem: `checkout_controller.dart:224` seeds from
`StoreController.store` only if `cached.id == storeId`. That guards against
the wrong store but still depends on whichever screen wrote last.

**Device evidence (09-30).** Worse than the analysis above predicted: no
shimmer, and not a whole-page swap. The page header (name, logo, cover,
cuisines, address, delivery time and fee, discount banner) reads
`StoreController.store`, and the menu reads `storeItemModel`. Only the first
was overwritten, so the page showed store A's identity over store B's items.
Phase 2's cache made the overwrite instant (no request), but it did not cause
it: the write happens with or without a fetch.

### ST-03 — cart bars priced against an arbitrary store (P1, verify)

`cart_controller.dart:241-250` picks the store for `calculateNetSubTotal` in
this order: `CheckoutController.store` if live, else `StoreController.store`.
`CheckoutController` becomes live the first time any store is opened
(`getStoreDetails` calls `initializeTimeSlot` on it). So in practice the store
used is **the last store that went through checkout**, or null.
`calculatePrice` and friends take module type and discount rules from that
store. Memory note `checkout-pricing-hidden-deps`: a null store prices non-food
at 0, which is why the fallback exists. The fix is structural (the cart has
exactly one store and should hold it). Reproduce before sizing.

**Correction (09-30, re-read before testing):** the wrong store cannot change
the number. On the cart-bar path (`calculateNetSubTotal`) the helper uses the
store only as a null check (`if (store != null ...)`). The one branch that
reads store fields, the store-wide discount in `calculateDiscountPrice`, runs
only with `calStoreDiscount: true`, and the net subtotal passes `false`. Any
non-null store gives the same figure. Downgraded to P3: it stays in Phase 3 as
structure (the cart should hold its own store), not as a pricing bug.

### ST-04 / ST-05 / ST-06 — opening a store is decided 29 times (P1/P2)

`RouteHelper.getStoreRoute` has 29 call sites. The screen passed in
`arguments` follows four different rules:

| Rule | Where |
|---|---|
| Always `FoodStoreScreen` | `food_home_screen` ×3 |
| `isSupermarket == false` → Food, else Store | `grocery_home_screen` (+ the module sections it passes a builder to) |
| Module type food (or unknown) → Food, else Store | `top_restaurants_view` |
| Always `StoreScreen`, which switches to Food only for specialty grocery | dashboard Order again (`module_view:455`), `search_store_row`, `visit_again_card`, `store_card`, `store_card_widget`, `store_card_with_distance` ×2, `store_list_card`, `popular_store_card_widget`, `banner_view`, `highlight_widget` ×2, `best_store_nearby_view` ×2, `item_widget`, `item_title_view_widget`, `item_bottom_sheet` ×2, `grocery_shelf_view`, and the route's own fallback (deep links, `xp_levels_screen`) |

`StoreScreen` never switches to the menu layout for a **food** store, so a
restaurant opened by any site in the last row gets the supermarket aisle page.
(verify: this is from the code path, not seen on device.)

Module activation is just as scattered. `activateModuleFor` runs at 16 store-open sites.
`visit_again_card`, `popular_store_card_widget`, `highlight_widget`,
`xp_levels_screen`, `item_title_view_widget` and the deep-link route open a
store without it. Where they are reachable from the module-less dashboard, the
store renders under the previous module's caches and header.

`ST-06`: the specialty-grocery path builds `StoreScreen`, lets it fetch
details, then returns `FoodStoreScreen` from `build`. The embedded screen runs
its own `_initDataCall` and fetches the store again. That fetch nulls `_store`,
which is why `_menuStyle` has to be latched (store_screen.dart:55-61).

### ST-07 — rebuild radius (P1 perf)

- 44 `GetBuilder<StoreController>` in 26 files: food home 6, grocery home 5, `module_view` 4, `all_store_filter_widget` 3, `store_screen` 3, cart 2, and one each in 16 other files.
- 54 `update()` calls in the controller, one of them scoped (`storeRailId`).
- The home stays mounted under a pushed store route, so each item page, rail landing, filter tap or bundle response on the store page rebuilds every home builder too.
- `changeFavVisibility()` runs on each scroll-direction change and calls a bare `update()`.
- `showButtonAnimation()` schedules another bare `update()` 3 s after every store open, for a `currentState` flag nothing reads.

The 09-30 log's home frames are BUILD-bound (worst build 41–75 ms against an
8.3 ms budget).

### ST-11 — a home reload on every dashboard store open (P1 perf)

`getStoreDetails` has `if (fromModule) HomeScreen.loadData(true);`.
`fromModule` is true for every `page=module` route. In the 09-30 log each
`GOING TO ROUTE /store?id=33&page=module` is followed by a
`── API home load (refresh)` block: 20, 13 and 14 requests, 192–327 KB,
running alongside the store's own 4–6 requests. `running-orders` (93.9 KB)
alone took 664–1204 ms.

~~`SplashController._changeModule` already solves this.~~ **Correction
(found while landing Phase 1):** it does not. `_changeModule` only invalidates
the home throttle, and its own comment notes that home is *not remounted* on
the way back, so its `initState` never runs. Nothing else called `loadData` on
return. That home reload was the only thing filling the module home the user
lands on after backing out of a dashboard-opened store: removing it alone
would have left that home blank.

**What landed:** the reload is gone from `getStoreDetails`, and `HomeScreen`
is now `RouteAware` on the existing `dashboardRouteObserver`. `didPopNext`
calls `HomeScreen.loadData(false)`. After a module switch the quiet window is
already open, so this loads on arrival, cache-first rather than the old
`reload: true`. Every other pop (sheets, dialogs, same-module stores) lands
inside the 2-minute window and returns without a request. One side effect: a
pop after the window has expired now runs the normal cache-first load, the
same thing a remount would do. `fromModule` is still read by
`getStoreDetails`' `clearPrevData` branch until Phase 3.

**Still open (device, 09-30):** after a store opened from the *dashboard*, the
load on return arrives as `loadData(true)` "(refresh)", not the hook's
`loadData(false)`. No known caller runs on a store pop. A debug-only tracer at
the top of `HomeScreen.loadData` prints every call with its flags and three
caller frames (`── home loadData(...) ← …`), and the next dashboard → store →
back run names it.

### ST-08, ST-09, ST-12, ST-14, ST-15 — smaller items

- `ST-08`: `getPopularStoreList` / `getLatestStoreList` set `_type = type`. `all_store_screen`, `filter_widget`, `food_store_screen` pagination and `store_category_items_screen` all read `type` back as the menu's item type.
- `ST-09`: store_controller.dart:236-238. Latent.
- `ST-12`: zero readers found for `pickPrescriptionImage`, `removePrescriptionImage`, `pickedPrescriptions`, `getSimilarStoreList`, `similarStoreList`, `setTopOfferFilter`, `setTopOfferSort`, `topOfferFilter`, `topOfferSort`, `setLowerValue`, `setUpperValue`, `shareStore`, `filteringUrl`, `currentState`. Re-grep each before deleting; the member map was built with a name heuristic.
- `ST-14`: move to `extension StoreRules on Store` (or a `StoreRules` class where it needs the clock). Readers stop needing the controller.
- `ST-15`: location_controller.dart:1436. It needs the module of the store being viewed, and should get it as a parameter.

---

## 3. Target shape

```
StoreNavigator.open(store, {source})          ← the only way into a store (Phase 5)
   ├─ SplashController.activateModuleFor(store.moduleId)
   ├─ StoreLayout.of(store, module)  →  menu | aisles
   └─ Get.toNamed(store route, arguments: StorePageArgs)

StorePageController  (tag: 'store-page-<id>-<n>', one per pushed page)   (Phase 4)
   kind A state: categories, chips, items + generation, rails, filters,
   item type, in-store search, banners, bundles, recommendations, fav button
   ↳ aisle page / search page / filter sheet get the tag, not Get.find()

CartController.cartStore  (or a small CartStoreController)               (Phase 3)
   kind B: the cart's one store, resolved from cart's storeId via the cache;
   checkout owns its own side effects (time slots, order type, distance)

StoreDetailsCache  (in StoreService: id → Store, TTL, in-flight join)   (Phase 2)
   used by the page, the cart, checkout and the item sheet

StoreListController  (what's left of StoreController, renamed)          (Phase 6)
   kind C: discovery lists, every update() scoped by rail id

extension StoreRules on Store                                             (Phase 2)
   kind D
```

Why each piece:

- **Per page, not per module.** It makes `ST-01` impossible rather than guarded. Stacked store pages (store → similar store → back) keep their own state for free. `update()` reaches only that page's builders, which is most of `ST-07`.
- **Cart store separate from page store.** A store page and the cart can be about different stores at the same moment, and today they cannot say so. After this, checkout never depends on which screen happened to write last.
- **One navigator.** Layout, module activation and the deep-link fallback are one decision, made once, before the push. That removes the `ST-06` embed and its latch.
- **Cache below all of it.** The page, the cart and checkout ask for the same store. The seeding trick in checkout (`cached.id == storeId`) goes away.

## 4. Phases

Order matters: Phase 3 has to land before Phase 4. Once page state moves out
of the singleton, the cart and checkout must already have their own store, or
checkout loses its seed.

**Phase 0 — landed 2026-09-30.** `ST-01` interim: `resetStoreBrowsing()` +
`_itemListGeneration`.

**Phase 1 — landed 2026-09-30.** (`ST-11`, `ST-09`, `ST-12`, `ST-15`, `ST-07` partial)
`flutter analyze`: no errors. Tests: 550 pass. The 2 failures are in
`spots_draw_demo_test.dart`, which imports only places code this phase did
not touch.
1. Deleted `HomeScreen.loadData(true)` from `getStoreDetails`, and added `HomeScreen.didPopNext` so home loads when the user returns (see the `ST-11` correction). `clearPrevData` kept on the non-module path. The contract test now pins both halves.
2. `ST-09`: null `_recommendedItemModel`, not `_storeModel`.
3. `ST-15`: `setStoreAddressToUserAddress(latLng, moduleId:)`; the caller passes `_store?.moduleId` before its awaits.
4. `ST-12` members deleted after a per-name re-grep. The prescription methods are live, but on `CheckoutController`; the `StoreController` copies were dead.
5. ~~Scope the fav button with its own update id.~~ The re-grep showed **no widget reads `StoreController.showFavButton`** (home reads `HomeController`'s). The toggle, both scroll-listener branches and `hideAnimation`/`showButtonAnimation` were deleted instead.

**Phase 2 — landed 2026-09-30.** (`ST-10`, `ST-14`) 568 tests pass (+18 new). The same 2 unrelated Spots failures remain.
1. `StoreDetailsCache` (`store/domain/services/store_details_cache.dart`), owned by `StoreService`: in-memory, 5-minute TTL, joins a fetch already in flight, never caches a failure. Callers pass `maxAge`, not `refresh`. The key is **id + language + saved lat/lng**, because the backend computes `open` and distance from the address headers, so a language or address change can't serve a stale store and needs no invalidation hook. Service API: `getCachedStoreDetails`, `peekStoreDetails`, `clearStoreDetailsCache`.
   - `getStoreDetails` fetches through it whenever there is an id (slug links bypass). The store page accepts ≤30 s (open/closed must be near-live); `fromCart` accepts the full TTL.
   - Checkout's seed is `peekStoreDetails(storeId)`, no longer `StoreController.store` behind an id check.
   - The item sheet's logo (`ItemController._fetchStoreLogo`) uses it and no longer touches `StoreController`.
   - Side benefit: `ST-06`'s second details fetch (the embedded `FoodStoreScreen`) now joins the cache, so there is one request. The embed itself still goes in Phase 5.
2. `extension StoreRules on Store` + `StoreSchedule` (`store/domain/store_rules.dart`): `isOpenNow`, `discountValue`, `discountTypeOrPercent`, `isClosedOn`, `isOpenBySchedule`, `distanceFromUserKm`. All six controller methods deleted, and 6 files migrated. Behaviour change: null `schedules` now reads as closed, where `schedules!` used to throw. `CheckoutController.isStoreClosed/isStoreOpenNow` stay as thin wrappers, because `checkout_screen` calls them with raw fields.
3. Tests: `store_details_cache_test.dart` (TTL, maxAge, in-flight join, failures not cached, key separation) and `store_rules_test.dart` (Sunday = 0, no-schedule store, hours, discount defaults).

**Phase 3 — landed 2026-09-30.** (`ST-02`, `ST-03`) 572 tests pass (+5 new behaviour, contract test rewritten). The same 2 unrelated Spots failures remain; no analyzer errors.
1. `CartController.cartStore`: the store of the cart's own lines. It is resolved inside `calculationCart()`, which runs after every cart change: first from what it holds, then from a cache peek, else it starts one cached fetch and re-prices when that lands. It never waits, and a late store for a previous cart is dropped. `loadCartStore()` awaits it, for the cart screen. It only touches *live* services (the splash prefetches the cart early).
2. Readers moved off `StoreController.store`: the cart screen (header name, free-delivery fee gate; its outer `GetBuilder<StoreController>` is gone), the cart subtotal (no more Checkout-then-Store chain), `ExtraPackagingWidget`, `CouponSection` (checkout's own store), `TimeSlotBottomSheet` (checkout's own store). The one remaining outside reader is the no-delivery sheet on a blocked add-to-cart, which *should* name the page's store; it is commented and pinned by a test.
3. Checkout owns its setup. `initCheckoutData` gets its store from the cache (peek, else a cached fetch) and runs `_applyStore`: time slots, order type and distance. `CheckoutController` no longer imports `StoreController`. Time slots now run exactly once per checkout. Before, the cart screen's fetch did it and checkout's store came through the short-circuit, which skipped it.
4. `getStoreDetails(store, {slug})` is a plain fetch for the store page. It lost `fromCart`, `fromModule`, the short-circuit branch, `_applyOrderType`, `_computeDeliveryDistance`, `clearPrevData` and `_notifyAfterFrame`, and `StoreController` no longer imports `CheckoutController`. **Every store open is 2 requests lighter** (`distance-api` + `extra_charge`): only checkout read that distance, after `clearPrevData` had reset it anyway (checkout_screen.dart:147 already calls it).
5. Found dead along the way: `DeliveryOptionButtonWidget` (no users). Not deleted in this phase.
6. Tests: `cart_store_test.dart` (the cart's store is its lines' store, fetched once, dropped when the cart moves, late responses ignored) and a rewritten `store_details_contract_test.dart` (no checkout effects in the fetch, only the two screens call it, the schedule loop runs once, and the ST-02 guard: no reader of `StoreController.store` outside the store feature except the one pinned exception).

**Phase 4 — landed 2026-09-30.** (`ST-01` structural, `ST-07`, `ST-08`, `ST-13` defused) 577 tests pass (+4 new, contract test updated). The same 2 unrelated Spots failures remain; no analyzer errors or new warnings.
1. `StorePageController` (`store/controllers/store_page_controller.dart`) holds all kind-A state: the store, categories, menu + pagination, in-store search, the filter sheet, sub-category chips, aisle rails, banners, bundles and recommendations. Members kept their `StoreController` names, so the logic moved rather than being rewritten. `StorePageController.open()` registers one under a unique tag (`store_page_N`); `close()` deletes it. Every async landing checks `isClosed`.
2. Both store screens `open()` in `initState` and `close()` in `dispose`; their builders are `GetBuilder<StorePageController>(tag: _page.tag)`. **The aisle page and the filter sheet are handed the parent page's controller** (`page:` parameter): they are views of the same visit, and a filter applied on the aisle page must reach its parent's rails. In-store search, opened by named route, takes `StorePageController.top` (the page that pushed it) and opens its own only for a direct link.
3. `StorePageController.top` is a stack of open pages, for the one outside reader that means "the store page on screen": the no-delivery sheet on a blocked add-to-cart (`cart_controller`). Pinned by the contract test as the only use outside the store feature.
4. Deleted from `StoreController`: every kind-A member, `resetStoreBrowsing` (the Phase 0 stopgap) and its `_itemListGeneration`. The page keeps its own generation counter for rapid tab taps. `StoreController.type` stays, meaning only the home store lists' type (`ST-08`). The aisle page's pull-to-refresh resets only its rails again, as before Phase 0.
5. **Not done here, deliberately:** a shared `StorePageLifecycle.open()`. The two screens still request in different orders, but with per-page state that can no longer leak, so it folds into Phase 5, where the layouts meet. Reviews still live on the global `ReviewController` (refetched per store open; out of scope).
6. Tests: `store_page_controller_test.dart` covers two pages not sharing a category pick (the 09-30 bug, replayed), a tag per page with `top` following the stack, a response landing after close being dropped, and an older category's page not overwriting a newer one. The contract test now also fails if page state returns to `StoreController`.

**Phase 5 — landed 2026-09-30.** (`ST-04`, `ST-05`, `ST-06`) 583 tests pass (+6 new). The same 2 unrelated Spots failures remain; no analyzer errors, and the issue count is unchanged (348).
1. `lib/features/store/store_navigator.dart`:
   - `StoreLayout.of(store)`: `is_supermarket` true → aisles, false → menu, missing → null (undecided). The backend's store formatter sets the flag on every store list; only id-only stores lack it. `StoreLayout.fallback` is for a store that still does not say: grocery module → aisles, else menu.
   - `StoreNavigator.open(store, {page, replace})` switches to the store's module, then pushes the store route with a `StoreRouteShell`. `page` is only the URL label.
   - `StoreRouteShell` builds the page at once when the layout is known. Otherwise it fetches the store through the cache with the page's own 30 s tolerance (so the page's fetch is then a hit), switches to its module, and picks the page. A slug link fetches by slug, then the page repeats it, since that fetch also moves the saved address: one extra request on a rare path.
2. **All 29 store-open sites** now call `StoreNavigator.open`, including the item sheet's store link, which used to `toNamed` and then `offNamed` the same route. The bare `/store` route (deep links, XP) builds the shell. `_storeScreenArguments` / `storeScreenBuilder` / `_openStore*` layout logic is gone from the homes and the three module sections.
3. `StoreScreen` is the aisle page and nothing else: the specialty-grocery embed, `_menuStyle` latch and `_isSpecialtyGrocery` are deleted. `fromModule` is gone from both screens (its last effect went in Phase 1).
4. `ST-13` (one shared open sequence): the two screens still request in their own order. With the layout decided up front and per-page state, that is now a style difference, not a bug. It stays open as cleanup for Phase 7's screen split.
5. Tests: `store_navigator_test.dart` covers the layout table and the fallback, and two source guards: only the navigator builds `StoreScreen`/`FoodStoreScreen`, and only the navigator (plus the deep-link URL builder) calls `getStoreRoute`.

**Phase 5b — shop variant of the menu page (D3). Landed 2026-09-30.** No analyzer errors (issue count unchanged at 348); 583 tests pass.
1. `FoodStoreScreen._isShop`: the store's module is known and is not food. It replaces `_isGroceryShop` (grocery only), so every non-restaurant store the page serves gets the variant; an unknown module keeps the restaurant look.
2. ~~**Hero:** the aisle page's mint `StoreHeroBannerWidget` for shops.~~ **Reverted the same day at the user's call:** shops keep the restaurant cover hero, the 26pt name and the logo-overhang padding. `_buildShopHero` and the 96pt reveal offset were removed.
3. **Header:** unchanged from the restaurant page. For a shop the cuisines line is its store type (grocery store types are cuisines server-side).
4. **Items:** `_buildShopGrid`, a 2-column `SliverGrid` of `ShopProductTile` (decode width 280) with a matching placeholder grid while the first page loads, and the page's empty state.
5. **`ShopProductTile`** (`store/widgets/shop_product_tile.dart`): the aisle grid's card, add "+" / stepper and tag, moved out of `store_category_items_screen.dart` and shared. The aisle grid uses it at 3 columns, the shop variant at 2, so a price or stepper fix lands in both. `ShopProductTilePlaceholder` replaced the aisle shimmer's inline blocks.
6. **Wording:** "All products" / "Categories" now for every shop (were grocery-only), and the self-delivery fallback says "store", not "restaurant". No new translation keys: all existed in en.json and ar.json.
7. Unchanged: the sticky tabs, "Order again" rail, pagination, search, cart bar and page controller.

**Phase 6 — landed 2026-09-30.** (`ST-07` done) 586 tests pass (+3 new); no analyzer errors, issue count unchanged (348).
1. **Scoped rebuilds.** All 20 `update()` calls in the list controller now name ids, and all 32 `GetBuilder`s on it listen on exactly one. Lists: `storeList` (paginated list + filters), `popular`, `latest`, `featured`, `topOffer`, `visitAgain`, `recommended`, `dashboardRails`, `storeRecommendedItems`, `cartSuggest`. A builder draws what it listens on; a builder that draws two lists gets a combined id that both lists' updates name: `popularLatest` (best-nearby, top brands), `popularFeatured` (best-store-nearby), `cuisineStrip` (the strip's selection is filter state and its tile logos come from popular/latest, read via `Get.find` inside a child) and `allStores` (the "All stores" screen). Before, a bare `update()` rebuilt about 30 home builders for each of the ~15 fetches in a home load.
2. **Rename:** `StoreController` → `StoreListController` (file `store_list_controller.dart`), in 30 files. Code lines only: comments that describe the old singleton's history still say `StoreController`.
3. Found dead: `ModuleCategoryCircles` (no users). Not deleted here.
4. Tests: `store_list_scoping_test.dart` pins no bare `update()`, an id on every builder, and every listened-on id being notified by some update, which is the "section silently never refreshes" trap.

**ST-17 — found on device after Phase 6, fixed 09-30.** Not a Phase 6 regression: the 09-30 log showed `/customer/visit-again` returning 2 bytes (`[]`) on the dashboard and 76 KB inside Food.
1. Backend (`OrderController::order_again`): the module filter now applies only when a `moduleId` header is sent. The dashboard gets recent stores across all modules. **Needs deploying.** Until then the dashboard row stays empty; it used to fill only by accident, from a module home's list.
2. Client: `StoreListController.dashboardVisitAgainStoreList` is the dashboard's own list (`module_view` reads it); `visitAgainStoreList` stays the module homes'. Which list a load fills is fixed when it starts.
3. Client: the repository cache and the TTL stamp are keyed on `ModuleHelper.getModule()?.id` (the module the request carries, `none` on the dashboard), not `currentModuleId()`, whose last-module fallback cached the dashboard's reply as food's.
4. Client: `_inServedZones` is the tolerant zone filter (no pivot evidence → keep; empty result → stale evidence, keep all), shared by featured and "Order again". It replaces a `module.pivot!` that threw inside a swallowed home section.

**Phase 7 — follow-ups.**
1. **`ST-16` — landed 2026-09-30.** `CategoryPageController` (`category/controllers/category_page_controller.dart`), per page and tagged like the store pages, holds the page's sub-categories, items/stores and their pagination, the items/stores tab, search, item type and filters. It adds a generation guard per list and `isClosed` checks. `CategoryItemScreen` opens and closes it; `SubcategoryListWidget` and `CategoryFilterWidget` are handed it. `CategoryController` keeps only the app-wide state (module category list, dashboard grocery aisles, interest picker). Tests: `category_page_controller_test.dart` (a new page starts clean, close unregisters, older sub-category results dropped, results after close dropped).
2. **Dead code — landed 09-30.** Deleted `DeliveryOptionButtonWidget` (file) and `ModuleCategoryCircles`. (`ModuleCategoryCirclesShimmer` was deleted by mistake too: it is live, used by `ModuleCuisineCircles`. The analyzer caught it, and it was restored byte-identical from HEAD, which an earlier session's transcript confirmed matched the uncommitted copy.)
3. **Screen split — landed 09-30.** Dart `part` files with the builders moved into `extension`s on the screen's State (a part shares its library, so private members resolve unchanged). Verified as a pure move by comparing line multisets against a pre-split copy: the only differences are the part/extension scaffolding and, on the menu page, the tab strip's two `setState(() => _selectedTabIndex = i)` becoming the State's `_selectTab(i)` (`setState` is protected, so it cannot be called from an extension).
   - `food_store_screen.dart` 2,552 → 543 lines, plus `food_store/`: `food_store_hero.dart` (cover hero, scrolled header), `food_store_header.dart` (name, rating, stats, offers), `food_store_tabs.dart` (tab strip, categories sheet, sticky delegate), `food_store_menu.dart` (menu rows, add controls, order-again rail, shop grid, shimmers).
   - `store_screen.dart` 1,816 → 543 lines, plus `store_aisles/`: `store_aisles_sections.dart` (category tiles, rails, product cards, discount banner, reviews, bundles) and `store_aisles_info.dart` (info dialog, hours sheet). `_buildAisles` stays in the main file (it calls `setState`).
4. **Debug `loadData` tracer — removed 09-30.** Every `(refresh)` home load in the 09-30 logs came from `switchModule` (tapping a module tile) or checkout's post-order refresh, both expected. The `didPopNext` load is pinned by `store_details_contract_test`.

**The plan is complete.** All findings `ST-01`..`ST-17` are landed. What remains is outside the code: the `ST-17` backend deploy, and the on-device checklist at the top.

## 5. Decisions

- **D1 — pharmacy / shop layout. Decided 09-30: out of scope.** They are not being designed for now. `StoreLayout` sends every store that is neither food nor specialty grocery to the aisle page (today's behaviour) with no special case, and nothing in Phases 5–6 is built around them.
- **D2 — restaurants from search / Order again / deep links. Decided 09-30: menu page, everywhere.** Every restaurant opens on `FoodStoreScreen` whatever it was opened from. That makes `ST-04` a real fix, not a no-op.
- **D3 — the layout rule and the shop look. Decided 09-30.** Food → menu page; supermarkets → aisle page; **every other store → the menu page, in a shop variant** (chosen over "light touch" and "mockup first"): the same structure and category tabs, but product-first. Items are image tiles in a 2-column grid under each tab (price + add, like grocery cards), with shop wording. ~~The grocery mint hero instead of the restaurant cover-photo header.~~ **Revised after seeing it (09-30): keep the restaurant header (cover, logo tile, big name) for shops; only the items change.** This supersedes D1's "aisle page by default" for pharmacy/shop: they are "other stores", so they get the menu page too, with no special design.

## 6. Risks

- **Phase 3 touches the checkout money path.** The subtotal store changes (`ST-03`) and so can the figure on the bars. Land it with the `CC-*` / `CS-*` tests green and a before/after on a discounted cart.
- **Phase 4 touches every store-page read.** Mostly mechanical (`storeController.` becomes `page.`), but `FilterWidget` is also used by the aisle page and must get the right tag. The analyzer can't catch a wrong tag, so each entry point gets a widget test.
- **GetX tags leak if `dispose` is skipped** (e.g. `Get.offAll` over a store page). `Get.delete` in `dispose` covers normal pops. Add a debug assertion counting live `StorePageController`s.
