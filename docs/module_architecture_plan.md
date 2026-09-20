# Module system — audit and fix plan

**Date:** 2026-09-15 · **Scope:** `waddi_user` client only
**Status:** Phases 0-4 landed 2026-09-15. See the end of each phase for what
actually shipped, including two places where implementation corrected the plan.

Read this as: Part 1 is what is actually wrong, with evidence. Part 2 is the shape
to move toward. Part 3 is the order to do it in, each phase shippable on its own.
Findings are `M-01`…`M-11` so they can be referenced from commits the way `CC-*`
is used in `cart_checkout_fix_plan.md`.

---

## Summary

"The module" is the app's most load-bearing piece of state — it decides what the
API returns, which home screen renders, and which catalogue the user is looking
at. It is currently stored in **five** places that can disagree, mutated from
**24 widget tap handlers**, and torn down by **two different handlers that clear
different things**. There is no test covering any of it.

That is the actual cause of the bugs of the last few days, not a coincidence of
them: the grocery band showing Food's categories, the dashboard rails needing
hand-built headers to get the right module, "top restaurants" resolving against
the wrong catalogue. Each was fixed at the call site. The generator is still here.

The single worst item, `M-01`, is a two-line fix with app-wide consequences.

---

## Part 1 — Findings

### M-01 · The module id header is never cleared (critical, user-visible)

`ApiClient.updateHeader` falls back to the **persisted** module when it is passed
none:

```dart
// lib/api/api_client.dart:73
if (moduleID != null || sharedPreferences.getString(AppConstants.cacheModuleId) != null) {
  header.addAll({AppConstants.moduleId: '${moduleID ?? ModuleModel.fromJson(...).id}'});
}
```

`cacheModuleId` is written on every module entry (`splash_controller.dart:302`)
and **never cleared**: `removeCacheModule()` exists at `splash_controller.dart:516`
and has zero callers. `setModule(null)` clears the *other* pref (`moduleId`) and
leaves this one.

So `setModule(null)` — the home hero back button, the dashboard tabs, logout,
and `initSharedData` on every cold start — does not put the client back on "no
module". Every ambient request from the aggregated dashboard still carries
`moduleId: <the last module the user opened>`.

**Consequences observed:** `/categories` on the dashboard returns the last
module's categories (verified live: `moduleId: 2` → `Pasta, Coffee & Tea, Juices`;
`moduleId: 1` → `Fresh Produce, Deli, Milk`). Every dashboard rail has had to
hand-build its headers to escape it — that is what the "same trick as featured
stores" comment in `store_repository.dart` is working around.

**Fix:** clear `cacheModuleId` when the module is cleared, and make the header
stop inventing a module the app does not think it is in. Both in one place.

---

### M-02 · Two "module changed" handlers that disagree, and 24 ways to bypass one

| | `setModule(module)` | `switchModule(index, fromPhone)` |
|---|---|---|
| writes prefs + header | yes | via setModule |
| clears category cache | **no** | yes |
| clears banner cache | **no** | yes |
| clears item lists | **no** | yes |
| clears campaigns | **no** | yes |
| clears flash sale | **no** | yes |
| clears store filters | yes | via setModule |
| refetches cart | yes | yes |
| fetches cashback + favourites | yes | via setModule |
| triggers `loadData` | **no** | yes |

`switchModule` is called from exactly **two** places, both module tiles
(`module_view.dart:266`, `:325`). `setModule` is called directly from **24**
places — store cards, item cards, banners, search rows, cart, the Spots rail,
the grocery shelf, every "see all" surface.

So entering a module by tapping its tile gives a clean module. Entering the
*same* module by tapping a store card on the dashboard gives a module whose
category list, banner list, item lists and campaigns still belong to wherever
the user was before. The screen then renders that until something happens to
refetch.

This is the generator behind the "wrong module's data" bugs. It is not a rail
bug or a category bug; it is that half the app changes modules through a door
that skips the cleanup.

---

### M-03 · Five copies of "the current module"

1. `SplashController._module` — in memory, the thing UI branches on.
2. `SplashController._cacheModule` — in memory, separate lifecycle.
3. `SharedPreferences[moduleId]` — written by `setModule`, removed on null.
4. `SharedPreferences[cacheModuleId]` — written by `setCacheModule`, never removed (`M-01`).
5. `_configModel.moduleConfig.module` — the module *config*, re-parsed from the
   raw `_data` map on every `setModule` (`splash_controller.dart:296`).

They are allowed to disagree, and the code knows it. This signature is the
system documenting its own confusion:

```dart
// lib/features/store/domain/repositories/store_repository_interface.dart:10
Future<dynamic> getStoreDetails(String storeID, bool fromCart, String slug,
    String languageCode, ModuleModel? module, int? cacheModuleId, int? moduleId);
```

…three module identities passed down so the repository can pick:
`module == null ? cacheModuleId : moduleId` (`store_repository.dart:385`, and
again at `:481`).

`initSharedData` is the same confusion in miniature: it sets `_module = null`
and then calls `setModule(_module)` — i.e. `setModule(null)` — guarded by
`if (_cacheModule != null)`. Reading that line and working out what state the
app ends in takes three files.

---

### M-04 · `setModule` is a side-effect bomb called from tap handlers

`setModule` is named like a setter. It:

- writes two prefs and rewrites the API header,
- re-parses `_data['module_config'][type]` and mutates the global config object,
- calls `CartController.getCartDataOnline()` (network),
- calls `StoreController.clearModuleStoreFilters()`,
- calls `HomeController.getCashBackOfferList()` (network),
- calls `FavouriteController.getFavouriteList()` (network),
- carries three `isPlacesModule` special cases through the middle of all of it.

Tapping a store card on the dashboard therefore fires up to three network
requests as a side effect of *navigation*, on the screen the whole performance
programme is aimed at. It is also `async` and awaited at **1 of 24** call sites.

---

### M-05 · The activation dance is copy-pasted ~11 times

```dart
for (ModuleModel module in Get.find<SplashController>().moduleList!) {
  if (module.id == store.moduleId) {
    Get.find<SplashController>().setModule(module);
    break;
  }
}
Get.toNamed(RouteHelper.getStoreRoute(...));
```

Verbatim (modulo formatting) in `item_widget.dart` ×2, `store_list_card.dart`,
`store_card.dart`, `store_card_widget.dart`, `store_card_with_distance.dart` ×2,
`top_restaurants_view.dart`, `grocery_shelf_view.dart` ×2, `top_grocery_view.dart`,
`top_grocery_stores_view.dart`, `steal_of_the_day_view.dart`, `best_store_nearby_view.dart` ×2,
`search_store_row.dart`, `item_bottom_sheet.dart`, `banner_view.dart` ×2.

Every copy has the same three latent bugs: no teardown (`M-02`), no await
(`M-04`), and a silent no-op when `moduleList` is null (cold start, offline).

---

### M-06 · `featuredHeader()` sends a header literally named `null`

```dart
// lib/helper/header_helper.dart:15
int? moduleID;                                   // never assigned
return {
  ...
  moduleID != null ? AppConstants.moduleId: '$moduleID' : '',
```

That parses as key `(moduleID != null ? 'moduleId' : '$moduleID')`, value `''`.
Verified by running it: `{Content-Type: …, null: , lang: en}`. The module id it
means to send can never be sent — which is exactly why every caller of
`featuredHeader()` spreads it and then appends `AppConstants.moduleId` by hand.
The same dead `int? moduleID;` is copy-pasted into `ApiClient`'s constructor
(`api_client.dart:62`).

---

### M-07 · Module identity is stringly typed

- 185 references to `moduleType`
- 91 comparisons against `AppConstants.food/grocery/pharmacy/ecommerce/parcel/places`
- 26 `moduleType.toString()` calls — on a field already declared `String?`
- 47 files reach for `Get.find<SplashController>().module` directly

`ModuleModel.moduleType` is a raw `String?` off the wire, compared by hand in 91
places. A typo is a silent behaviour change, and adding a module means finding
all 91.

---

### M-08 · `getModuleConfig` re-parses JSON on every call, mostly inside `build`

```dart
Module module = Module.fromJson(_data!['module_config'][moduleType]);
moduleType == 'food' ? module.newVariation = true : module.newVariation = false;
```

43 call sites, the majority in `build` methods of order widgets that appear once
per row. An order list with 20 rows parses that map 20+ times per frame, then
dereferences the result with `!` (`.addOn!`, `.newVariation!`) — which is also a
crash surface for any module whose config the backend has not sent.

---

### M-09 · `home_screen` branches on six booleans

`_ModuleState` carries `showMobileModule, isParcel, isPharmacy, isFood, isShop,
isGrocery, isPlaces`, and the body repeats

```dart
if (!moduleState.showMobileModule && !moduleState.isGrocery &&
    !moduleState.isFood && !moduleState.isPlaces)
```

**four times** for four different slivers, plus a fifth variant for the hero.
Adding a seventh module means editing five conditions correctly. This is the
readable end of the problem, and the cheapest to fix once `M-07` exists.

---

### M-10 · Dead and misleading code in the module path

- `removeCacheModule()` — no callers (and its absence is `M-01`).
- `setCacheConfigModule()` — one caller, does what `setModule` already does.
- `initSharedData`'s `setModule(_module)` where `_module` was just set to null.
- `_ModuleState.showMobileModule` is `module == null && configModel?.module == null`
  — the second half is always true on a mobile-only build.

---

### M-11 · Zero test coverage

No test in `test/` mentions `setModule` or `switchModule`. Every change to this
system has been verified by opening the app and looking at it. That is why
`M-01` survived: nothing asserts what header the client sends after leaving a
module.

---

## Part 2 — The shape to fix it into

Not a rewrite. Four small pieces, each replacing something that already exists:

**1. One owner of module state.** A `ModuleSession` (or keep it on
`SplashController`, the name matters less than the rule) with exactly two
mutators:

```dart
Future<void> enter(ModuleModel module);   // was setModule + switchModule
Future<void> leave();                     // was setModule(null) + removeModule
```

`enter` is idempotent (re-entering the active module is a no-op, which is what
`_lastActiveModuleId` is approximating today), writes **one** persisted copy,
refreshes the header from it, and runs the teardown **once** — the union of what
`switchModule` clears today. `leave` does the inverse, including the pref that
`M-01` leaves behind. Nothing else writes module state.

**2. `ModuleType` as an enum,** parsed at the model boundary
(`ModuleModel.fromJson`), with the wire string kept for the header. Replaces 91
string comparisons with exhaustive `switch`, and makes "which home screen"
(`M-09`) a single `switch` returning a widget.

**3. One `openInModule(...)` helper** — the loop from `M-05`, written once,
awaited, with the null-`moduleList` case handled. 11 call sites collapse to one
line each.

**4. Side effects out of the setter.** `enter`/`leave` change state and fire one
`update()`. Cart, cashback and favourites refresh from the screens that need
them, not from a tap handler on a store card.

---

## Part 3 — Phased plan

Each phase is independently shippable and independently verifiable. Phase 0
first, always — it is what makes the rest safe without device builds.

### Phase 0 — Safety net (no behaviour change) — **DONE**

`test/unit/module_session_test.dart`. Ran with the audit's prediction: **3
passed, 3 failed** — two failures were M-01 (leaving a module, and a cold
start, both still sending the last module) and one was M-02 (a module change
leaving the previous module's categories in place). The audit reproduced itself
as red tests before a line of production code changed.

Now 9 tests, all green. They drive the clearing behaviour through
`activateModuleFor` rather than `enterModule`, because the latter also kicks off
a home load and a unit test has no home screen for that to land on; what is
asserted is the half they share.

<details><summary>Original plan for this phase</summary>

Write the tests that pin today's *correct* behaviour before touching anything:

- entering a module sets the `moduleId` header to that module
- **leaving a module removes it** (fails today — this is `M-01`)
- entering module B after A leaves no A-owned cached list behind (fails today via the `setModule` path — `M-02`)
- `getModuleConfig` returns the right config per type and does not throw on an unknown one

`test/unit/module_session_test.dart`. Needs `GetMaterialApp` if any widget is
pumped (see `perf-work-state` note on `Dimensions.fontSize*`).

**Verify:** two of the four tests fail. That failure *is* the audit result,
reproduced.

</details>

### Phase 1 — Header truth (`M-01`, `M-06`, part of `M-10`) — **DONE**

> **Correction found while implementing.** The plan said to clear
> `cacheModuleId` on leave. That would have broken things: `cacheModule` is read
> in ~20 places as "the module of the thing being looked at" for screens opened
> from the module-less dashboard — the cart's module id
> (`cart_repository.dart:50`), the item bottom sheet's config, `getStoreDetails`.
> It is a legitimate fallback, and the pref is not the bug. The bug is that an
> *ambient header* helped itself to it. So `updateHeader` now sends
> `moduleId` only when a caller supplies one, and the pref keeps doing its
> other job untouched. Everything that matters already passes
> `ModuleHelper.getModule()?.id` — i.e. the *active* module — so removing the
> fallback made those call sites correct rather than breaking them.

What landed:

- `ApiClient.updateHeader` no longer resurrects the module from `cacheModuleId`.
- `featuredHeader()`'s `null` key fixed; it takes `moduleId` as a parameter, and
  the two callers that appended the header by hand now just pass it.
- The dead `int? moduleID;` in `ApiClient`'s constructor replaced by an explicit
  `null` and a comment saying why there is no module at boot.

<details><summary>Original plan for this phase</summary>

- `leave()` clears `cacheModuleId` (call the existing `removeCacheModule`, or
  fold it in).
- `updateHeader`: send `moduleId` when a module is genuinely active; stop
  resurrecting it from a pref the caller did not ask for.
- Fix `featuredHeader()`'s `null` key; have it take the module id it needs.
- Delete the dead `int? moduleID;` in `ApiClient`'s constructor.

**Risk:** medium-high blast radius — this changes what every request sends.
Specifically check the paths that *rely* on the stale fallback today: store
details from cart (`fromCart`), notifications opening a store, deep links.
**Verify:** Phase 0 tests go green; `ApiStats` on a dashboard load shows no
`moduleId` header; a module home still sends its own.

**Payoff:** the dashboard rails' hand-built headers become optional rather than
load-bearing, and the whole class of "wrong module's data on the dashboard"
closes at the source.

</details>

### Phase 2 — One activation path (`M-02`, `M-05`) — **DONE**

Three doors now, and `setModule` is private (`_setModule`), so the compiler
enforces that nothing outside the controller writes module state:

| door | used by | clears caches | reloads home |
|---|---|---|---|
| `enterModule(module)` | module tiles, the module dialog, the cart adopting its own module | yes | now |
| `activateModuleFor(id)` | the 24 tap handlers (store cards, items, banners, search, rails) | yes | on arrival |
| `leaveModule({refreshDashboard})` | hero back button, Home tab, sign-out, parcel bar | — | — |

The distinction between the first two is only about *when* home reloads, never
whether the caches are cleared. Teardown and reload have to stay coupled —
home's `loadData` throttles itself for two minutes, so clearing without
arranging a load leaves the module home rendering nothing — so the store-card
door calls the new `HomeScreen.invalidateLoadThrottle()` instead of firing a
whole home load that races the screen the user actually asked for.

Four real bugs fell out of the migration rather than being designed for:

1. **Re-entering the active module re-ran the setter** — two pref writes and
   three network calls (cart, cashback, favourites) to arrive at the state the
   app was already in. `_changeModule` now returns before any of it.
2. **`cart_screen`'s checkout button could throw a range error**: it scanned
   `moduleList` for the cart's module with a bare `for` and then used `i` —
   which is `length` when there is no match — as an index.
3. **`banner_view` set the module twice**, the second time from a `ModuleModel`
   built out of `zoneData` that need not be in `moduleList` at all.
4. **`location_controller` kept scanning after a match**, setting the module
   once per remaining entry.

Also removed: the duplicate `getCartDataOnline()` on the switch path (the setter
already does it), and `switchModule`'s dead `fromPhone` parameter.

<details><summary>Original plan for this phase</summary>

- Add `enter()`/`leave()` with the union teardown; keep `setModule` as a thin
  deprecated forwarder so nothing breaks mid-migration.
- Add `openInModule(store|item)`; migrate the 11 copies to it, deleting the loop.
- Migrate the remaining 13 `setModule` call sites to `enter`/`leave`.
- Delete the forwarder, `switchModule`'s teardown block, and `removeModule`.

**Risk:** touches 24 files but each edit is mechanical and the tests from Phase 0
cover the semantics. Do it in two commits (helper + migration) so a revert is cheap.
**Verify:** `grep -rn "setModule(" lib` returns only the session itself.

</details>

### Phase 3 — Single source of truth (`M-03`, `M-04`) — **DONE**

> **Second correction.** "Collapse `moduleId`/`cacheModuleId` to one pref;
> `_cacheModule` becomes a read of `_module`" was half right. They are not two
> copies of one fact — they answer different questions: `_module` is *where the
> user is* (null on the dashboard), `cacheModule` is *the last module in play*,
> which is what a screen opened from the module-less dashboard needs. Making
> one a read of the other would have emptied the cart's module id on the
> dashboard. What was actually redundant was the **`moduleId` pref**, which
> turned out to be **write-only**: both places that loaded it
> (`initSharedData`, `getModule`) discarded the value, because the app starts on
> the picker by design rather than restoring the last module.

What landed:

- The `moduleId` pref and the whole dead `getModule()` chain (repo → service →
  interface) are gone. **One** persisted copy remains.
- `SplashRepository.setModule` → `updateModuleHeader`, which is all it does now.
- `getStoreDetails` and `getCartStoreSuggestedItemList` took `ModuleModel?`,
  `cacheModuleId` **and** `moduleId` so the repository could pick between them
  with `module == null ? cacheModuleId : moduleId`. Every caller passed the same
  three expressions and the ternary always came out as
  `activeModule?.id ?? cacheModule?.id`. Three identities across four layers to
  express one number — now one `int? moduleId`, and the expression lives once
  as `ModuleHelper.currentModuleId()`.
- The cart/cashback/favourites refresh moved out of the setter into
  `_refreshModuleScopedUserData`, called by the module-change path and by the
  single-module startup path.
- `initSharedData`'s `_module = null; … if (_cacheModule != null) setModule(_module)`
  now says `updateModuleHeader(null)` — which is what it meant.

<details><summary>Original plan for this phase</summary>

- Collapse `moduleId` / `cacheModuleId` to one pref; `_cacheModule` becomes a
  read of `_module`.
- Drop `cacheModuleId`/`moduleId` params from `getStoreDetails` and
  `getCartStoreSuggestedItemList` (interface, service, repo, call sites) — the
  session already knows.
- Move cart/cashback/favourites refresh out of the setter.

**Risk:** the `fromCart` store-details path is the one that genuinely needs "the
module of *that store*, not the active one" — keep that explicit rather than
implicit. **Verify:** open a store from the cart while a different module is
active; the item list must be that store's.

</details>

### Phase 4 — Typing and ergonomics (`M-07`, `M-08`, `M-09`) — **DONE**

**`ModuleType` enum** (`lib/common/models/module_model.dart`) with a `wire`
string and a total `ModuleType.of(String?)`; `ModuleModel.type` parses once.
All 41 comparison sites migrated — including the 26 `.toString()` calls on a
`String?` field, one of which was `splashController.module?.moduleType
.toString()` producing the literal `"null"` for a null module and comparing
unequal to every branch by luck rather than design. Unknown types resolve to
`ModuleType.unknown`, which matches no branch.

**`getModuleConfig` memoised** per module type, cleared when the config payload
is replaced. Nothing mutates the returned object, so one instance per type is
safe to share. Also: `Module.fromJson` now defaults every flag to `false`
instead of null — those nine fields are dereferenced with `!` at 43 call sites,
most inside `build`, so a module the backend has not configured used to crash
the widget rather than render the feature as off.

> **That default trades a loud failure for a quiet one, and the trade is only
> half right on its own.** A *wholly* absent module config already answered
> "everything off" long before this change, silently. What is new is the
> partial case: a config that is present but missing a key used to throw inside
> `build` the first time anyone opened the screen — a stack trace in
> Crashlytics on day one — and now renders that feature as off, which is
> indistinguishable from a module that genuinely has it off. A backend that
> forgets `is_parcel` on a new module no longer crashes; it quietly serves the
> wrong home body until a customer writes in.
>
> The defaults stay — crashing a delivery app inside `build` over a missing
> boolean is the worse end of the trade — but the gap is now an **event**
> rather than an outage: `_reportConfigGap` fires a `module_config_gap`
> analytics event (and a debugPrint) with `reason: absent | partial` and the
> list of missing keys, deduped to one per module type per session because
> `getModuleConfig` is read 43 times and the absent case is deliberately not
> memoised. `new_variation` is excluded from the expected list on purpose: the
> client sets it, so the backend omitting it is not a gap. A test pins the
> expected-flag list against `Module.fromJson`, so a flag added to one without
> the other is a red test rather than a gap that reports nothing.

**`_ModuleState`** is one nullable `ModuleType` instead of seven booleans, and
the four-part condition spelled out at four call sites is now named once:
`hasOwnScaffold` (grocery/food/places render their own complete screen) and
`usesGenericBody`. Adding a module is one enum case, not five conditions.

Tests: 14 in `module_session_test.dart` (parsing, casing, round-trip,
unknown-type totality), 118 in the suite.

<details><summary>Original plan for this phase</summary>

- `ModuleType` enum + `ModuleModel.type`; migrate the 91 comparisons.
- Memoise `getModuleConfig` per type (`Map<String, Module>` built once from
  `_data`), and give `Module`'s flags non-null defaults so 43 `!` dereferences
  stop being crash surface.
- Replace `_ModuleState`'s six booleans with one `ModuleType?`; the four
  repeated conditions become `switch` arms; `_buildModuleContent` becomes a
  `switch` returning the home screen.

**Risk:** low, high volume. Purely mechanical once the enum exists.
**Verify:** `flutter analyze` clean; the enum's exhaustive switches mean a new
module type is a compile error, not a silent fallthrough.

</details>

---

## What is left

The findings are closed, but two of the shapes in Part 2 were deliberately not
taken all the way:

- **`getModuleConfig(String?)` still takes the wire string**, because its 43
  callers pass `order.moduleType` — a string off an order payload, not a module
  the app is in. That is the right currency at that boundary; the enum is the
  currency for branching.
- **`ModuleSession` was not extracted.** The rules now hold on
  `SplashController` (`_setModule` is private, three public doors), which was
  the point; moving them to their own class is a rename, and renames are worth
  doing when they buy something other than tidiness.
- **Places (Spots) special-casing** remains as scoped out.

---

## Out of scope

- The backend `/api/v2/m/{module}/z/{zone}/home` aggregate (tracked in the perf
  programme; it would collapse the fan-out but does not touch module *identity*).
- The per-module home screens' internals — food/grocery/pharmacy/shop bodies
  stay as they are; only how they are *selected* changes.
- Places (`Spots`) special-casing. It is a genuinely different module shape;
  fold it in only after Phase 4 makes the seams visible.

## Verification discipline

`flutter analyze` and `flutter test` after every phase — never a build; the user
tests on device (`no-builds-user-tests`). Exclude
`test/golden/marks_render_test.dart` (30 pre-existing errors against a deleted
Spots API); 107 tests pass without it.
