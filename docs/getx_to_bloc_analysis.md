# GetX → Bloc: feasibility analysis

**Question:** should Waddi replace GetX with Bloc before going up against Talabat /
HungerStation?
**Date:** 2026-09-19
**Answer:** Possible, yes. Worth it, no — but not for the reason usually given, and there
is a third option that gets you most of the benefit.

---

## 1. Executive summary

| | |
|---|---|
| **Is it technically possible?** | Yes. No blocker is fundamental. |
| **Measured cost** | ~5,750 call sites · 524 of 850 files · 613 events to model · 222 widgets to rewrite |
| **Realistic duration** | 4–7 months for 1–2 engineers, feature freeze on touched areas |
| **Would it fix the perf problem?** | **No.** The perf problem is unscoped rebuilds, which Phase 4 fixes in ~3 weeks. |
| **Would it fix the testability problem?** | Partly — but §5 shows a cheaper route to the same place |
| **Recommendation** | **Don't migrate.** Do Phase 4 + the §6 hardening. Revisit only if §7 triggers fire. |

The headline number that decides it:

> **GetX is not your state management library. It is your framework.**
> Only ~2,100 of ~5,750 GetX call sites are state management. The other ~3,650 are
> translation (2,802 `.tr`), navigation (591), and dialogs/context (118).
> **Bloc replaces none of those.**

---

## 2. What is actually coupled — measured, not estimated

524 of 850 files (**62%**) import `package:get/get.dart`.

| GetX API | Call sites | Does Bloc replace it? |
|---|---|---|
| `.tr` (translations) | **2,802** | ❌ No — needs a separate i18n migration |
| `Get.find<>` | **1,741** | ⚠️ Partly — ~1,300 are controllers, ~440 are services |
| `GetBuilder<>` | 347 | ✅ Yes → `BlocBuilder` |
| `Get.toNamed` | 284 | ❌ No — needs `go_router` or Navigator 2.0 |
| `Get.back` | 215 | ❌ No |
| `Get.parameters` | 174 | ❌ No |
| `Get.off*` | 81 | ❌ No |
| `Get.dialog` | 60 | ❌ No |
| `Get.context` | 42 | ❌ No |
| `GetxService` | 40 | ❌ No — DI, not state |
| `GetxController` | 39 | ✅ Yes → `Bloc`/`Cubit` |
| `GetPlatform` | 28 | ❌ No |
| `Get.bottomSheet` | 16 | ❌ No |
| `Get.currentRoute` | 15 | ❌ No |
| `Get.locale` | 14 | ❌ No |
| `Get.arguments` | 14 | ❌ No |
| `Get.isRegistered` | 11 | ❌ No |
| **Total** | **~5,750** | **~2,100 replaced (37%)** |

**Read that last row carefully.** A "Bloc migration" leaves ~63% of your GetX coupling
untouched. You would either ship an app depending on *both* GetX and Bloc — strictly worse
than today — or you are not doing one migration, you are doing four:

1. State management: GetX → Bloc (~2,100 sites)
2. Navigation: `Get.toNamed`/`back`/`off` → `go_router` (~591 sites, 75 routes)
3. i18n: `.tr` → `flutter_localizations`/`slang` (~2,802 sites)
4. DI: `Get.lazyPut`/`find` for services → `get_it`/`injectable` (~440 sites)

Each has its own regression surface. Together they touch essentially every file that
renders anything.

---

## 3. The three genuine blockers

### 3.1 Circular controller dependencies — the real problem

Bloc's architecture assumes a **directed acyclic** dependency graph. Yours has cycles:

```
cart_controller.dart:230      →  Get.find<CheckoutController>().store
checkout_controller.dart:599  →  Get.find<CartController>().getCartDataOnline()
checkout_controller.dart:714  →  Get.find<CartController>().clearCartList()

cart_controller    →  ItemController   (8 references)
item_controller    →  CartController   (14 references)
```

**`cart ↔ checkout` and `cart ↔ item` are both true cycles.**

GetX tolerates this because `Get.find` is a lazy global service-locator lookup — the cycle
resolves at call time. Bloc does not: `BlocProvider` builds a tree, and two blocs that
need each other at construction deadlock. You must either:

- introduce a mediator/coordinator bloc that owns both (large refactor of the most
  business-critical code you have), or
- push shared state into a third bloc both depend on (re-architecting cart/checkout/item
  ownership), or
- keep a service locator for the cyclic pairs — which means keeping GetX, or bolting on
  `get_it`, and admitting the cycle still exists.

This is not a mechanical translation. It is a redesign of the revenue path.

**The full graph:** 75 controller→controller edges. `splash_controller` alone reaches 13
other controllers; `location_controller` and `checkout_controller` reach 8 each.

### 3.2 The state shape is not Bloc-shaped

Bloc requires immutable state objects with value equality. Your controllers are mutable
bags:

| Controller | private fields | public getters | public mutable |
|---|---|---|---|
| `item_controller` | 249 | 49 | 69 |
| `checkout_controller` | 120 | 39 | 48 |
| `cart_controller` | 92 | 17 | 34 |

`item_controller` holds **249 private fields**. Converting that to a single immutable state
class means a 249-field `copyWith`, or decomposing it into 5–10 smaller blocs — which is
the right answer, and is also a from-scratch redesign of the item feature.

You also have **613 public controller methods** that become Bloc events. Each needs an
event class, a handler, and a test. At a genuinely optimistic 1 hour each including review,
that alone is ~15 engineer-weeks — before any widget is touched.

Neither `equatable` nor `freezed` is currently a dependency.

### 3.3 The domain layer is not as clean as it looks

88 files under `lib/features/*/domain/` import `package:get`, and GetX's `Response` type
(from `get_connect`) appears 213 times, leaking into repository signatures.

Your repository/service interface split is real and valuable — but it is **not** currently
framework-independent. A Bloc migration has to fix this first, or blocs end up depending on
GetX types, which defeats the purpose.

---

## 4. The argument that actually kills it

**Bloc would not fix your performance problem.**

The perf problem is precisely diagnosed: 527 bare `update()` calls against 347
`GetBuilder`s, so every state change repaints every listener. That is not a GetX
limitation — GetX has scoped updates, and **`places_controller` already uses them**
(18 bare / 30 scoped).

The fix is mechanical: enumerate update ids, scope the calls, add `id:` to builders.
**~3 weeks** for the five worst controllers, per Phase 4 of the hardening plan.

A Bloc migration would also fix it — in **4–7 months**, while introducing regression risk
across the entire app, during a period when you need to be shipping features to compete.

> Same outcome. 6–10× the cost. Vastly more risk.

If someone argues "Bloc prevents the problem recurring," note that a 20-line CI guard
prevents it too:

```yaml
n=$(grep -rho "update();" lib --include='*.dart' | wc -l)
[ "$n" -le 50 ] || exit 1
```

---

## 5. What Bloc would genuinely buy you

Being fair to the proposal — these are real, and I am not dismissing them:

1. **Testability without a container.** Blocs test as plain objects. Today
   `CheckoutCalculationHelper` reaches into 5 controllers via `Get.find` and cannot be
   tested without booting GetX.
2. **Explicit state transitions.** 613 methods mutating 249 fields is hard to reason about;
   `Event → State` is not.
3. **Compile-time safety.** `Get.find<T>()` fails at *runtime* if unregistered. Bloc's
   `context.read<T>()` fails at compile time.
4. **Time-travel debugging** via `BlocObserver` — genuinely useful at scale.
5. **Hiring.** Bloc is the more common enterprise Flutter idiom.

**But every one of items 1–4 is achievable without leaving GetX:**

| Bloc benefit | Cheaper equivalent | Cost |
|---|---|---|
| Testable pricing | Pure-function refactor with `PricingInputs` (Phase 3.2) | 1 week |
| Explicit transitions | Scoped update ids as enums (Phase 4) | 3 weeks |
| Compile-time DI safety | `di_graph_test.dart` — **you already have this** | done |
| Observability | `GetObserver` / a logging wrapper on `update()` | 2 days |
| No unscoped rebuilds | CI budget guard | 1 day |

Item 5 (hiring) is the only one that genuinely requires Bloc. It is not worth 4–7 months.

---

## 6. Recommendation: constrain GetX, buy the option

Do not migrate. Instead, make the codebase **migration-ready** so the decision stays open
and cheap. Every item below has standalone value today — none is wasted if you never migrate.

### 6.1 Evict GetX from the domain layer (Phase 3, +3 days)
Replace `get_connect`'s `Response` in repository signatures with your own
`ApiResult<T>`. Removes GetX from all 88 domain files. **Value today:** domain becomes
unit-testable without a container. **Value if you migrate:** this step is already done.

### 6.2 Break the controller cycles (Phase 3, +1 week)
Fix `cart ↔ checkout` and `cart ↔ item`. **Value today:** removes the hardest-to-debug
class of bug in the codebase — the one behind `checkout-pricing-hidden-deps`.
**Value if you migrate:** removes blocker 3.1 entirely.

### 6.3 Extract pure logic from controllers (Phase 3.2)
`PricingInputs → CheckoutPricing` as a pure function. **Value today:** the money path
becomes testable. **Value if you migrate:** pure functions port to Bloc unchanged.

### 6.4 Centralise navigation (+1 week)
Wrap all 591 `Get.toNamed`/`back`/`off` sites behind an `AppNavigator` interface.
**Value today:** navigation becomes mockable and analytics-instrumentable in one place.
**Value if you migrate:** swapping to `go_router` becomes a one-file change instead of 591.

### 6.5 Centralise translation access (+3 days)
Wrap `.tr` behind a thin `S.of()`-style accessor, migrating incrementally. **Value today:**
a CI guard can then detect missing keys at compile time rather than rendering raw keys to
Arabic users. **Value if you migrate:** decouples the single largest GetX surface (2,802 sites).

**Total: ~3 weeks, all inside Phases 3–4, all valuable regardless.**

After this, a future Bloc migration drops from 4–7 months to roughly 6–8 weeks, because
the three genuine blockers are gone and only `GetBuilder → BlocBuilder` remains — which
*is* mechanical.

---

## 7. When to revisit

Reopen this decision if any fires:

- **Team exceeds ~8 Flutter engineers.** Convention-based discipline stops scaling; you'll
  want compile-time enforcement.
- **Phase 4 fails to hit the jank budget.** If scoped GetX still can't hold <1% jank on
  mid-range Android, the library genuinely is the ceiling. (Unlikely — `places_controller`
  suggests otherwise.)
- **Hiring becomes the bottleneck** and candidates decline over the stack.
- **A greenfield sibling app** (vendor/courier) needs building — start *that* in Bloc and
  compare honestly before touching the consumer app.

---

## 8. If you decide to migrate anyway

Not recommended, but if the call is made, this is the only sane sequencing. **Do not**
attempt a big-bang rewrite.

**Prerequisites (non-negotiable):** all of §6, plus Phase 1's test net. Migrating without
tests around the money path turns one bug into five.

| Stage | Work | Duration |
|---|---|---|
| 0 | §6 prep + `equatable`/`freezed` + `flutter_bloc` added alongside GetX | 3 weeks |
| 1 | Pilot: **one leaf feature** with no cyclic deps (`favourite` or `coupon` — 9 files, 1 controller, ~192 LOC) | 1 week |
| 2 | Evaluate honestly. Measure: LOC delta, test delta, perf delta, developer friction. **Real go/no-go gate.** | — |
| 3 | Leaf features: banner, brands, cuisine, loyalty, refer_and_earn, review, support | 4 weeks |
| 4 | Mid-tier: search, category, address, wallet, notification, profile | 6 weeks |
| 5 | Navigation → `go_router` (591 sites, 75 routes) | 3 weeks |
| 6 | i18n → `slang` (2,802 sites, mostly codemod-able) | 2 weeks |
| 7 | **Revenue path**: cart, checkout, item, store — cycles first | 8 weeks |
| 8 | home (96 GetBuilders), order (23 files), places, xp | 6 weeks |
| 9 | Remove GetX from pubspec; DI → `get_it`/`injectable` | 2 weeks |

**Total: ~35 weeks ≈ 8 months** at one engineer; ~4–5 months at two with clean splits.

**Stage 2 is the point of the plan.** Migrate `favourite`, measure everything, and let
data decide. If the pilot doesn't clearly win, stop — you've spent 4 weeks, not 8 months.

**Hard rules during migration:**
- Both libraries coexist; never half-migrate a feature.
- Every migrated feature ships with tests written *before* the migration (characterization
  tests against old behaviour).
- Feature freeze per feature while it migrates, never globally.
- A CI guard asserting migrated features never re-import `package:get`.

---

## 9. Bottom line

**Possible?** Yes.

**Advisable?** No — because it solves a problem (unscoped rebuilds) that a 3-week
mechanical fix already solves, at 6–10× the cost, while three genuine blockers
(cycles, 249-field state bags, GetX in the domain layer) make it a redesign rather than
a migration, and because 63% of your GetX coupling isn't state management at all and
survives the migration untouched.

**What to do instead:** Phases 0–4 of the hardening plan, plus the §6 prep work. That
buys you the performance, the testability, and the enforcement — and leaves a future
migration cheap if you ever want it.

The thing that will beat Talabat is not your state management library. It is shipping
correct prices, not crashing on bad payloads, and not dropping frames on a mid-range
Android in Maadi. None of those require Bloc.
