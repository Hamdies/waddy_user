# Cart screen — restructure and re-layout plan

**Target:** `lib/features/cart/`
**Status:** planned, not implemented.
**Date:** 2026-09-14 · **Revised** 2026-09-14 with `/critique` + `/impeccable` findings (§7–§10)

---

## 1. What the audit actually found

`dart analyze lib/features/cart` reports **0 errors, 0 warnings** beyond two dead
methods. So the problems are structural, not compile-time — which is why they
show up as visual bugs rather than crashes.

| Finding | Evidence |
|---|---|
| **760 lines of fully dead code** | `ExpandedCartDrawer` has **zero** references outside its own file |
| **Two dead methods** | `_buildDeliveryAddressPreview` (238), `_buildOrderSummary` (327) — ~180 lines |
| **Design system bypassed entirely** | `cart_screen.dart`: **19** hardcoded `Color(0xFF…)`, **25** `Theme.of(context)` lookups, **0** uses of `WaddyColors` |
| **One 1585-line screen** | 9 build methods, the largest ~340 lines |
| **Duplicated reward logic** | `MinimumOrderProgressWidget` re-derives minimum-order progress that `CartRewardState` already owns, with a different visual |
| **Three parallel arrays** | `cartList` / `addOnsList` / `availableList` indexed in lockstep |

### What is NOT a bug (checked, so the plan does not "fix" it)

- **`cartList[0].item!.storeId` is safe.** The cart is enforced single-store by
  `existAnotherStoreItem` + the conflict dialog, so indexing element 0 for store
  context is sound. Multi-store grouping is **out of scope**.
- **The parallel arrays stay in sync.** Every mutation path
  (`removeFromCartOptimistic`, `addToCartOnline`, `restoreCartItem`) calls
  `calculationCart()`, which rebuilds all three together. Worth collapsing for
  clarity, but it is not currently a crash.
- **No cart-bar duplication on this screen.** The cart screen renders neither
  `HomeCartBar` nor `FoodStoreCartBar`.

---

## 2. The two visual bugs in the screenshots

**Screenshot A — reward strip and cart bar disagree.** The strip says
*"Psst… Waddy got you free delivery"* while the bar shows 6 items / 296 LE. The
"Psst" copy is the **empty-cart hook** (states 5a/5b); with a full cart it should
read as the in-cart confirmation (state 2, `freeDeliveryGuaranteed`). Both map to
the same string today:

```dart
case CartRewardKind.freeDeliveryGuaranteed:
case CartRewardKind.hookFreeDelivery:
  return Text('waddy_got_you_free_delivery'.tr, …);
```

**Fix:** split the copy. "Psst…" is a *hook* — it only makes sense before you
have a basket. With items in the cart it should simply confirm: *"Free delivery
on this order"*.

**Screenshot B — progress bar reads as complete at 8 LE remaining.** "Add 8 LE
more to order" with a bar that looks ~100% full. At 91% the last 9% is invisible,
so the bar contradicts its own label.

**Fix:** floor the rendered value (`progress.clamp(0.06, 0.94)`) so "not done"
always reads as not done, and give the track a visible unfilled remainder.

---

## 3. Plan

Five phases. 1–2 are pure deletion and land immediately; 3–5 are the restructure.

### Phase 1 — Delete dead code (~940 lines, zero risk)

- `lib/features/cart/widgets/expanded_cart_drawer.dart` — 760 lines, no callers.
- `_buildDeliveryAddressPreview`, `_buildOrderSummary` — flagged by the analyzer.
- Any imports orphaned by the above.

Verify with `dart analyze` before and after; the warning count should drop to 0.

> The drawer also holds the only *other* undo implementation (an inline banner).
> Deleting it makes the removal path single — consistent with the snackbar
> removal already shipped.

### Phase 2 — Fix the two visual bugs

Both are small and independently shippable, so they should not wait on the
restructure.

1. Split `freeDeliveryGuaranteed` from `hookFreeDelivery` in
   `RewardStrip._message`, with a new `free_delivery_on_this_order` key in **both**
   `en.json` and `ar.json`.
2. Clamp the progress fill and add a visible track remainder.

### Phase 3 — Adopt the design system

`cart_screen.dart` is the only major screen still on hardcoded hex. Replace:

| Current | Token |
|---|---|
| `Color(0xFFF2F0EB)` (page ground, ×4) | `WaddyColors.surfaceRaised` or a named cart ground |
| `Color(0xFF1A1A1A)` | `WaddyColors.ink` |
| `Color(0xFF888888)` | `WaddyColors.inkMuted` |
| `Colors.white` (card fills) | `WaddyColors.surface` |
| `Theme.of(context).primaryColor` (×25) | `WaddyColors.primary` |

**Do this as its own commit.** Mixed with a layout change it becomes impossible
to tell a token swap from a regression in review.

### Phase 4 — Split the screen

1585 lines → a screen that composes widgets, one file each:

```
lib/features/cart/widgets/
  cart_header.dart          "Your basket" + count + "add more items"
  cart_item_list.dart       the ListView
  cart_suggestions.dart     "Did you forget?" (currently ~340 lines inline)
  cart_summary_sheet.dart   totals + discount breakdown
  cart_checkout_bar.dart    bottom bar (address row + CTA)
```

Target: `cart_screen.dart` under ~250 lines, doing composition and nothing else.

Extract **one widget per commit**, running the app between each. A single
mega-refactor of a 1585-line screen is how regressions get in.

### Phase 5 — Collapse the parallel arrays

Replace `cartList` + `addOnsList` + `availableList` with one list of a small
view-model:

```dart
class CartLine {
  final CartModel cart;
  final List<AddOns> addOns;
  final bool isAvailable;
}
```

Built once in `calculationCart()`. Removes three index-parallel lookups per row
and makes an out-of-range read structurally impossible.

**Lowest priority** — it is a robustness improvement, not a live bug, and it
touches the controller that every cart surface depends on. Do it last, alone.

---

## 4. Sequencing

| Phase | Risk | Ships |
|---|---|---|
| 1 — delete dead code | none | immediately |
| 2 — two visual bugs | low | immediately |
| 3 — design tokens | low, high review value | own commit |
| 4 — split the screen | medium | one widget per commit |
| 5 — collapse arrays | medium | last, alone |

Phases 1–2 are worth doing today regardless of whether 3–5 proceed.

---

## 5. Explicitly out of scope

- **Multi-store carts.** The cart is single-store by design; adding grouping
  would be a feature, not a fix.
- **Checkout screen.** Separate surface, separate audit.
- **`showCartSnackBar`.** Already unreferenced; retiring the file belongs to
  Phase 5 of `snackbar_noise_plan.md`.

---

## 6. Open question

The cart screen currently renders its own minimum-order UI
(`MinimumOrderProgressWidget`) while the store and home screens render
`RewardStrip` for the same information, in a different visual language.

**Should the cart adopt `RewardStrip` too?** It would unify the three surfaces
and delete the duplicated logic. The argument against is that the cart is where
totals get their own detailed treatment, so a compact strip may under-serve it.

My recommendation: **yes, adopt it** — one component, one source of truth.

> **RESOLVED 2026-09-14 — adopt it.** Confirmed by the app owner. See §9 Phase 3b
> for the merge, and §10 for what gets deleted.

---

# Part II — design critique findings

Added 2026-09-14 after running `/critique` and `/impeccable` against the three
cart surfaces (`FoodStoreCartBar`, `HomeCartBar`, `RewardStrip`) plus
`cart_screen.dart`.

**Prerequisite created:** `.impeccable.md` at the repo root. The design skills
refuse to run without a declared Design Context and explicitly forbid inferring
it from code. It records the audience, tone (*fresh, energetic, slightly
playful — NOT premium; bias bolder*), palette roles, and the constraints
(4pt grid, 48pt taps, EN+AR parity). Update it when the brand direction moves.

---

## 7. Design health score

| # | Heuristic | Score | Key issue |
|---|---|---|---|
| 1 | Visibility of system status | **2** | Progress track invisible — bar reads 100% at 91% |
| 2 | Match system / real world | **3** | "Extra charges may apply" is honest; "Psst…" misfires with a full cart |
| 3 | User control and freedom | **3** | Whole bar is the tap target; no undo after removal (accepted) |
| 4 | Consistency and standards | **2** | One string serves two states; cart uses a third visual for the same info |
| 5 | Error prevention | **4** | Module/store conflict dialogs genuinely guard basket wipes |
| 6 | Recognition rather than recall | **3** | Savings chip visible; the minimum *target* is never stated |
| 7 | Flexibility and efficiency | **3** | Optimistic add + fast path already landed |
| 8 | Aesthetic and minimalist design | **2** | Three layers of chrome for one bar |
| 9 | Error recovery | **2** | Removal is silent and irreversible |
| 10 | Help and documentation | **3** | n/a for this surface |
| **Total** | | **27/40** | **Fair** — solid foundation, specific defects |

### Anti-patterns verdict: **PASS**

Not AI slop. No gradient text, no glassmorphism, no dark-mode-with-glow, no
identical card grid, no hero-metric template. The mint-on-teal is distinctive and
the rationing rule (mint = pressable only) is a real system held consistently
across the bar, the CTA and the savings chip.

---

## 8. Priority issues

### [P0] The progress track is invisible — measured, not estimated

`RewardStrip` sets `backgroundColor: WaddyColors.surfaceRaised` on a
`LinearProgressIndicator` that sits inside a container whose fill is *also*
`surfaceRaised` in the blocker state:

| State | Container | Track | Contrast |
|---|---|---|---|
| `minimumOrder` (blocker) | `surfaceRaised #F5F7F6` | `surfaceRaised #F5F7F6` | **1.00** |
| free-delivery progress | `mintSurface #E6FCF3` | `surfaceRaised #F5F7F6` | **1.00** |

A ratio of 1.00 means the unfilled remainder is *mathematically indistinguishable*
from its background. The bar therefore always looks full, whatever the value.

Screenshot arithmetic confirms which cases break:

| Screenshot | Subtotal | Remaining | Minimum | Fill | Reads as |
|---|---|---|---|---|---|
| "Add 49 LE more" | 41 LE | 49 LE | 90 LE | 45.6% | correct |
| "Add 8 LE more" | 83 LE | 8 LE | 91 LE | **91.2%** | **complete** |

So this is not "the bar is slightly off" — below ~70% the fill carries the
meaning on its own and looks fine; above it, the label and the bar actively
contradict each other.

**Fix (two parts, both required):**
1. Give the track a real contrasting colour — `WaddyColors.divider #E4ECEA`
   against the mint ground, a mint-tinted track against the raised ground.
2. Clamp the *rendered* value to `progress.clamp(0.04, 0.92)` so "not finished"
   always reads as not finished. Keep the true value for the label.

### [P0] One string serves two opposite states

Already noted in §2; the critique confirms the severity. "Psst…" is a **hook** —
it presumes no basket. Firing it above "6 Items | 296 LE" is a tonal error, not
just a copy nit: the brand voice is playful, and playfulness misapplied reads as
the app not knowing what state it is in.

### [P1] Three layers of chrome for one bar — **CONFIRMED: merge**

White ground + top divider + tinted strip card + teal pill card = four surfaces
stacked to say two things. Brand direction is *bias bolder*, and bolder means
more committed, not more layered.

**Decision (confirmed by the owner):** merge the strip and the pill into **one
surface** with an internal divider.

```
┌─────────────────────────────────┐
│ 🪙  Add 49 LE to reach 90 LE    │   ← reward row (tinted)
│     ▓▓▓▓▓▓░░░░░░░░░░░░          │
├─────────────────────────────────┤   ← internal divider
│ 1 Item | 41 LE   [14 LE saved]  │   ← cart row (teal)
│ Extra charges…      View Cart › │
└─────────────────────────────────┘
```

One container, one radius, one shadow. The reward row keeps its tint so the two
rows stay legible as different kinds of information.

### [P2] The minimum target is never stated

"Add 49 LE more to order" gives the delta but not the goal; the user must
compute 41 + 49 = 90. Recognition over recall (heuristic 6).

**Fix:** `Add 49 LE to reach the 90 LE minimum`. Needs a new key with two
substitutions in **both** `en.json` and `ar.json`.

### [P2] Removal is silent and irreversible

Accepted by the owner when the snackbar was removed, so this is a recorded
consequence rather than an unflagged defect — but it is why heuristic 9 scores 2.
If mis-taps show up in the wild, the escape hatch is an **inline undo row** in
the cart list, not a returning snackbar.

---

## 9. Revised phase plan

Part I's phases stand. These amend and extend them.

### Phase 2 (amended) — now three fixes, not two

1. Split `freeDeliveryGuaranteed` from `hookFreeDelivery`
   (`free_delivery_on_this_order`, EN + AR).
2. **Track contrast** — a real colour, not `surfaceRaised` on `surfaceRaised`.
3. **Clamp the fill** to `[0.04, 0.92]`.

Items 2 and 3 are separate defects. Clamping alone would still leave an invisible
remainder; recolouring alone would still show a ~92% bar as visually complete.

### Phase 2b (new) — merge the two bar surfaces

Restructure `FoodStoreCartBar` and `HomeCartBar` to render one container with an
internal divider (§8 P1). Touches only those two widgets and `RewardStrip`'s
outer decoration; the resolver is untouched.

### Phase 3b (new) — cart adopts `RewardStrip`

The §6 open question is **resolved: adopt it.**

- `cart_screen.dart` renders `RewardStrip` via `CartRewardState.resolveFromContext`
  instead of `MinimumOrderProgressWidget`.
- **Delete** `lib/features/cart/widgets/minimum_order_progress_widget.dart`
  (112 lines) once nothing references it.
- All three surfaces then share one component and one resolver.

Sequence it **after** Phase 3 (design tokens): adopting a tokenised component
into a screen still on hardcoded hex would mean touching the same lines twice.

### Phase 6 (new, optional) — copy pass

P2 copy work: state the minimum target. Small, isolated, needs new EN + AR keys.

---

## 10. Revised sequencing

| Phase | Risk | Ships |
|---|---|---|
| 1 — delete dead code (~940 lines) | none | immediately |
| 2 — three visual bugs (copy, contrast, clamp) | low | immediately |
| 2b — merge bar surfaces | low | after 2 |
| 3 — design tokens in `cart_screen` | low | own commit |
| 3b — cart adopts `RewardStrip`, delete `MinimumOrderProgressWidget` | medium | after 3 |
| 4 — split the 1585-line screen | medium | one widget per commit |
| 5 — collapse parallel arrays | medium | last, alone |
| 6 — copy pass (state the target) | low | any time after 2 |

**Total deletion across the plan:** ~1,050 lines
(`ExpandedCartDrawer` 760 + two dead methods ~180 + `MinimumOrderProgressWidget` 112).

---

## 11. Persona red flags

**Layla — first-time orderer, 3G, one-handed.** Sees a full progress bar beside
"Add 8 LE more to order", concludes the app is broken or the minimum is already
met, taps *View Cart*, and hits a blocked checkout. ⚠️ Trust lost at the
highest-stakes moment in the funnel.

**Omar — price-sensitive repeat orderer.** Reads "99 LE saved", then reads
"Extra charges may apply" directly beneath it. Two numbers pulling in opposite
directions, unresolved until checkout. ⚠️ Anxiety spike exactly where the design
wants confidence. (Both strings are individually honest — the issue is that they
sit adjacent with no reconciliation. Worth revisiting in Phase 6.)

---

## 12. What the critique did NOT find

Recorded so a later pass does not "fix" working code:

- **Palette and rationing are sound.** Mint-as-pressable-only is held
  consistently. No change recommended.
- **Error prevention is the strongest dimension** (4/4). The module and store
  conflict dialogs are correct and should survive every refactor below — they are
  the only thing standing between a mis-tap and a wiped basket.
- **Typography hierarchy in the bar works.** Bold count/total over muted caveat
  reads correctly at a glance.
- **The optimistic add and fast path already landed** and measurably fixed the
  responsiveness complaint; no further work needed there.

---

# Part III — execution log

## Phase 1 ✅ LANDED — dead code deleted (1,155 lines, not 940)

| Removed | Lines |
|---|---|
| `expanded_cart_drawer.dart` | 760 |
| `_buildDeliveryAddressPreview` + `_buildOrderSummary` + cascade | 395 |
| **Total** | **1,155** |

**The estimate was low because dead code cascades.** `_buildOrderSummary` was the
only caller of `_showDiscountBreakdown` (76 lines) and `_buildSummaryRow`
(28 lines). The analyzer only reports one layer at a time, so those two did not
appear as dead until the method calling them was gone.

`cart_screen.dart`: **1585 → 1190 lines** — already most of the way to Phase 4's
~250 target before a single widget has been extracted.

> **Note on the drawer.** It carried 61 lines of *uncommitted* work — the 4pt
> token migration and an optimistic-removal implementation — applied to a file
> with no callers. `git rm` refused until forced, which is the correct default.
> All of it was superseded by what shipped in `cart_item_widget.dart`, so
> deleting was right; recording it here because the diff would otherwise look
> like lost work.

## Phase 2 ✅ LANDED — three visual fixes

**1. Copy split.** `freeDeliveryGuaranteed` now renders
`free_delivery_on_this_order` ("Free delivery on this order"); `hookFreeDelivery`
keeps the "Psst…" hook. New key in **both** `en.json` and `ar.json`.

**2. Track contrast.** Measured before and after:

| State | Container | Track | Before | After |
|---|---|---|---|---|
| blocker | `surfaceRaised` | `divider` | **1.00** | **1.12** |
| reward | `mintSurface` | `mintSurfaceDeep` | **1.00** | **1.08** |

**3. Fill clamp.** `value: state.progress.clamp(0.04, 0.92)`. The true value is
untouched for the label — only the paint is clamped.

### One extra fix the measurement surfaced

Recolouring the track exposed a second contrast failure the critique had not
caught: the reward **fill** (`mintDark #0DC97D`) against its new deep-mint track
scored only **1.87:1**, so filled and unfilled would have been hard to tell
apart. Swapped to `mintInk #0A7A50` → **4.63:1**, which separates cleanly while
staying in the mint family rather than borrowing the blocker's teal.

| Fill candidate | vs `mintSurfaceDeep` |
|---|---|
| `mintDark` (original) | 1.87 |
| **`mintInk` (chosen)** | **4.63** |
| `primary` | 8.17 — too strong, reads as the blocker |

### Regression tests

Three added to `test/cart_reward_state_test.dart`, including the exact 83/91
case from the device screenshot. **22/22 passing.**

### State after Phases 1–2

`dart analyze lib` → **0 errors, 0 warnings.**

## Still open

Phases 2b, 3, 3b, 4, 5, 6 per §10.

## Phase 2b ✅ LANDED — bar surfaces merged

`FoodStoreCartBar` and `HomeCartBar` now render **one** rounded container with a
hairline seam, instead of two stacked cards on a white ground.

Mechanics:

- `RewardStrip` gained a `merged` flag. Merged it drops its bottom margin and
  rounds only its **top** corners; standalone it keeps all four — which is what
  Phase 3b needs when the cart screen renders it alone.
- `_CartPill` gained the mirror flag: squared top, rounded bottom when merged.
- A new `_MergedBar` owns the outer `ClipRRect`, the single radius and the single
  shadow, and inserts a 1px `Divider` **only** when both rows are present.
- `HomeCartBar._basket` lost its own radius and shadow — the parent owns the
  shape now, so a radius there would have shown as a corner inside a corner.

The seam is a hairline divider, not a gap: a gap would put the white ground back
between the rows and undo the merge.

Shadow count across both bars: **1** (was 2 — one per card).

## Phase 3 ✅ LANDED — design tokens adopted

`cart_screen.dart` went from **zero** token usage to fully tokenised:

| | Before | After |
|---|---|---|
| `WaddyColors.*` | 0 | **34** |
| `Color(0xFF…)` | 19 | **0** |
| `Theme.of(context).*` | 25 | **0** |

### Two new tokens, promoted not invented

The plan proposed mapping the cart's page ground to `surfaceRaised`. **Measuring
it showed that would have been wrong:**

| | Value | Temperature |
|---|---|---|
| cart ground | `#F2F0EB` | warm cream (R242 G240 B235) |
| `surfaceRaised` | `#F5F7F6` | cool, teal-tinted |

They are different temperatures. Mapping cream onto the cool grey would have
quietly changed the cart's mood — a visual regression disguised as a token swap,
which is exactly what doing this as its own commit was meant to catch.

So the literal was **promoted to a named token** instead:

```dart
static const Color surfaceWarm    = Color(0xFFF2F0EB); // warm cream ground
static const Color surfaceWarmAlt = Color(0xFFF5F2EC); // warm cream, raised
```

Same shipped value, now named and reusable. The cart is the one surface that
should feel like paper rather than screen; it keeps that.

### The `Theme.of` swaps are provably identical

Verified against `light_theme.dart` rather than assumed:

| Lookup | Line | Resolves to |
|---|---|---|
| `primaryColor` | 126 | `WaddyColors.primary` |
| `disabledColor` | 128 | `WaddyColors.inkMuted` |
| `cardColor` | 131 | `WaddyColors.surface` |

All three are 1:1, so those 15 replacements cannot have changed a pixel.

### State after Phases 1, 2, 2b, 3

`dart analyze lib` → **0 errors, 0 warnings.** Tests **22/22**.

## Still open

Phases 3b, 4, 5, 6 per §10.

## Phase 3b ✅ LANDED — cart adopts `RewardStrip`

All three surfaces now share one component and one resolver.
`minimum_order_progress_widget.dart` (112 lines) **deleted**.

### The swap was not a straight swap — a state was missing

The old widget had a success state the resolver did not: **"Minimum order
reached"** with a full bar. Tracing the ladder showed that clearing the minimum
fell straight through to `hidden`, so a naive swap would have made the strip
**silently vanish** the moment the user crossed the threshold.

On a browsing screen that is correct — "you can check out now" is not news. On
the **cart**, where the minimum is the gate between the user and the button they
came to press, a strip that disappears reads as the app forgetting.

So `CartRewardKind.minimumOrderMet` was added, gated behind a new
`showMinimumMet` flag: **true only on the cart**, false everywhere else.

### A test caught an ordering bug before it shipped

First implementation put the met-branch immediately after the unmet one — which
meant it **shadowed real rewards**. A cart that cleared a 50 LE minimum at a
free-delivery store would have announced "Minimum order reached" instead of
"Free delivery on this order".

The branch moved to **last resort**, immediately before rule 6: it only surfaces
when the ladder would otherwise fall through to hidden. Free delivery is worth
more to a user than "you can check out now", and the ladder now says so.

```
… rules 1–4 (blocker, guaranteed, progress, unlocked)
   ↓ nothing matched
   minimumOrderMet     ← only if showMinimumMet and the cart is non-empty
   ↓
   hidden
```

### Tests

Six added for the new state, including the two that would have caught each bug:

| Test | Guards |
|---|---|
| hidden on browsing surfaces once met | the flag actually gates it |
| shown on the cart | the cart keeps its confirmation |
| never shown for an empty cart | no "minimum reached" on nothing |
| no minimum → still hidden | does not fire for stores without one |
| unmet blocker still outranks it | ordering above |
| **a real reward still outranks it** | **the ordering bug, caught pre-ship** |

**28/28 passing.** `dart analyze lib` → **0 errors, 0 warnings.**

`minimum_order_reached` already existed in both `en.json` and `ar.json`, so no
new keys were needed.

### Running totals

| | Lines |
|---|---|
| Phase 1 | 1,155 |
| Phase 3b (`minimum_order_progress_widget.dart`) | 112 |
| **Deleted so far** | **1,267** |

`cart_screen.dart`: **1585 → 1208 lines.**

## Still open

Phases 4, 5, 6 per §10.

## Phase 2b ❌ REVERTED — the merge was wrong

The §8 P1 decision (merge strip and pill into one seamed surface) was
implemented, seen on device, and **reverted**. Recording it so it is not
re-proposed.

**Why it failed.** A single container split by a hairline read as *one object
awkwardly divided*, not as one component with two rows. The reward and the cart
are different kinds of thing — a nudge and a total — and collapsing them into one
surface removed the only signal saying so. The reference (Swiggy) does the
opposite: a light card, a clear gap, then the coloured bar.

**What replaced it:**

| | Merged (reverted) | Now |
|---|---|---|
| structure | one container, hairline seam | two objects, 10px gap |
| strip ground | mint / raised by state | `surfaceRaised` in all states |
| cart bar | teal, squared top | teal, fully rounded |
| tint carrier | the whole strip surface | icon + emphasis text only |

The strip is a **light card in every state**. Colour is carried by the icon and
the emphasised numbers, not by the slab — a coloured strip directly above the
teal bar is what made the pair look like two mismatched objects competing rather
than a card introducing a bar.

`HomeCartBar._basket` also went **teal** (it was `surfaceRaised`), so the cart
surface is the brand colour on both screens. That forced three contrast fixes
the revert would otherwise have shipped broken:

| Element | Was | Now | Why |
|---|---|---|---|
| basket title | `ink` | `surface` | ink on teal is unreadable |
| "view full menu" / count | `inkMid` | `onPrimaryMuted` | same |
| Checkout button | `primary` fill | `mint` fill, `primary` label | teal-on-teal was invisible |
| Clear button | `coralSurface` | `coral` @ 18% | near-white read as a second bright button |

### Track contrast re-measured after the ground change

The strip ground is now uniform, so the two-branch track collapsed to one:

| | vs ground `#F5F7F6` |
|---|---|
| track `divider #E4ECEA` | **1.12** |

| Fill | vs track | Used for |
|---|---|---|
| `primary` | **7.89** | blocker |
| `mintInk` | **4.47** | reward |

Both fills still separate cleanly, and the two colours keep "blocker" and
"reward" reading as different kinds of news.

`_MergedBar` deleted; the `merged` flags on `RewardStrip` and `_CartPill` are
gone. **28/28 tests passing**, `dart analyze lib` → **0 errors, 0 warnings**.

> **Lesson for §8.** The critique scored "three layers of chrome" as a P1 and
> merging looked like the obvious fix on paper. On device the layering was not
> the problem — the *colour competition* was. Reducing the strip to a light card
> solved what the merge was aiming at, without destroying the separation that
> makes the two elements legible.
