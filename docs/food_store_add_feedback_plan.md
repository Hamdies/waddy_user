# Food store — anchored cart bar with Waddy reward strip

**Target:** `lib/features/store/screens/food_store_screen.dart`
**Replaces:** the floating toast fired on "+"
**Status:** planned, not implemented. Revised after design direction.

---

## 1. Direction (confirmed)

- **Structure**, not Swiggy's colours. Waddy palette throughout.
- **No scroll-hide.** The bar is always present when relevant.
- Reward strip is a **progress mechanic**: "add X more for free delivery", not a
  post-hoc "Hooray".
- Voice is **"WADDY!"**, not "Hooray". Playful, brand-first.
- Icon is **`assets/animation/waddi_coins.json`** (Lottie), not a 🎉 emoji tile.
- **The strip shows even when the cart is empty** — if the user already has a
  reward waiting (first-order free delivery, a coupon), tell them up front:
  *"Psst… Waddy got you free delivery"*.

That last point is the important one. It turns the bar from a receipt into a
**hook**: a reason to start a cart, not just a confirmation that you have one.

---

## 2. What exists today

`_buildCartPill` ([food_store_screen.dart:1605](../lib/features/store/screens/food_store_screen.dart#L1605))
is already an anchored bar: count · total · "View Cart", in `WaddyColors.primary`
with a `mint` CTA, hidden when the cart is empty.

So this is not "build a cart bar". It is five gaps:

| Gap | Where |
|---|---|
| Toast still fires on add | `itemDirectlyAddToCart` → `showCartSnackBar()` ([item_controller.dart:1251](../lib/features/item/controllers/item_controller.dart#L1251)) |
| No savings chip | data exists, unused |
| No reward strip | does not exist |
| Bar hides on scroll | `_showLiveCart` → `-80` ([food_store_screen.dart:309](../lib/features/store/screens/food_store_screen.dart#L309)) |
| Bar hidden when cart empty | blocks the "Psst" hook entirely |

---

## 3. The hard part: what "free delivery" actually means here

This is where the feature can quietly go wrong, so it is worth being exact.

`CheckoutCalculationHelper.calculateDeliveryCharge`
([checkout_calculation_helper.dart:450](../lib/features/checkout/helpers/checkout_calculation_helper.dart#L450))
resolves **six independent** paths to a zero delivery charge:

| # | Source | Field | Progress-shaped? |
|---|---|---|---|
| 1 | Takeaway order | `orderType == 'take_away'` | no |
| 2 | Store always-free | `store.freeDelivery == true` | no |
| 3 | Admin free-to-all | `adminFreeDelivery.type == 'free_delivery_to_all_store'` | no |
| 4 | **Admin over-threshold** | `adminFreeDelivery.freeDeliveryOver` | **YES** |
| 5 | Coupon | `CouponController.freeDelivery` | no |
| 6 | XP prize | `selectedCheckoutPrize.isFreeDelivery` | no |

### Two consequences

**(a) Only #4 is a progress bar.** The others are already-true facts. Showing
"add ₹X more" against them would be a lie. The strip must branch on *which*
source applies.

**(b) `store.minimumOrder` is NOT free delivery.** It is the floor below which you
cannot order at all — a different promise. The existing
[`MinimumOrderProgressWidget`](../lib/features/cart/widgets/minimum_order_progress_widget.dart)
already renders that, and `_buildStatsStrip` already surfaces it in the header.

> **Design decision:** the strip should show **minimum-order progress first**
> when the store has a minimum and it is unmet, because that is a *blocker* —
> free delivery is irrelevant if you cannot check out. Free-delivery progress
> takes over once the minimum is cleared. One strip, a priority order, never two
> competing progress bars.

### Priority ladder (single source of truth for the strip)

```
0. orderType == take_away
   → hidden                                        [nothing to promise]
1. Cart non-empty AND store.minimumOrder unmet
   → "Add <X> more to order"                       [blocker, progress]
2. Free delivery unconditional (#2 store, #3 admin-to-all)
   → "Waddy got you FREE DELIVERY"                 [reward, no progress]
3. Admin threshold (#4) exists and unmet
   → "Add <X> more for FREE DELIVERY"              [reward, progress]
4. Admin threshold met
   → "WADDY! Free delivery unlocked"               [reward, celebrate]
5a. Cart empty + isValidForDiscount
   → "Psst… Waddy got you <amount> off your first order"   [hook]
5b. Cart empty + rule 2 applies
   → "Psst… Waddy got you free delivery"           [hook]
6. Nothing applies
   → strip hidden entirely
```

> Rules 2 and 5 changed after checking the backend — coupon (#5) and XP (#6) are
> NOT resolvable before checkout, and the first-order perk is a **discount**, not
> free delivery. See §9 for the evidence and the corrected copy.

Rule 6 matters: an always-visible strip with nothing to say is noise — the exact
failure mode the snackbar work was about.

---

## 4. Plan

### Step 1 — Stop the toast, on this screen only

`showCartSnackBar()` lives in `itemDirectlyAddToCart`, shared by the grocery
`StoreScreen`, item details and the bottom sheet — **none of which get this new
bar**. Deleting it would strip their only feedback.

Add `bool showToast = true` to `itemDirectlyAddToCart`; pass `showToast: false`
from Food's two call sites ([:1558](../lib/features/store/screens/food_store_screen.dart#L1558)
`_addButton`, [:1301](../lib/features/store/screens/food_store_screen.dart#L1301)
`_buildOrderAgainCard`). Same opt-in pattern as `showError` and `silent`.

### Step 2 — New widget: `FoodStoreCartBar`

Extract from `_buildCartPill` into its own file rather than growing an already
1800-line screen. Owns both tiers and all the reward logic.

```
lib/features/store/widgets/food_store_cart_bar.dart
  ├─ _RewardStrip   (tier 1, white, conditional, Lottie + text + progress)
  └─ _CartPill      (tier 2, teal, count | total | saved-chip | View Cart)
```

Inputs: `Store store`, `CartController cart`. Reads config/coupon/XP internally
via `Get.find`, mirroring how `calculateDeliveryCharge` already does it.

**Reward resolution must not be duplicated.** Add a small pure resolver —
`CartRewardState.resolve(...)` returning `(kind, message, progress?)` — so the
ladder in §3 lives in one testable place and cannot drift from checkout's six
conditions.

### Step 3 — Tier 1: the reward strip

- **Lottie** `assets/animation/waddi_coins.json` at **36×36**, matching the
  existing inline precedent in
  [order_successful_screen.dart:1025](../lib/features/checkout/screens/order_successful_screen.dart#L1025).
  (The refer-and-earn usage is 200×200 — full-screen, wrong scale here.)
- **Play policy:** loop only on the *celebrate* state; a single play on entry
  otherwise. A 228KB Lottie looping forever behind a static message is wasted
  battery on a screen users sit on.
- **Progress bar** beneath the text for the two progress states. Reuse the
  arithmetic shape of `MinimumOrderProgressWidget`, not its visual.
- **Entry:** `AnimatedSize` + fade. Crossing a threshold should feel earned.
- Sits **above** the pill, white ground, rounded top corners so the two read as
  one stacked unit.

### Step 4 — Tier 2: enrich the pill

- Label → `N Items | <total>` + **savings chip** when `cart.itemDiscountPrice > 0`
  ([cart_controller.dart:35](../lib/features/cart/controllers/cart_controller.dart#L35)).
- Chip is mint-tinted inside the teal bar — the reference's `₹21 saved`.
- **Overflow:** at 400px with Arabic this will not fit on one line. `Flexible` +
  ellipsis on the label; the chip drops first, `View Cart` never truncates.

### Step 5 — Always-on behaviour

- **Remove `_showLiveCart`** and its scroll listener branches
  ([:109](../lib/features/store/screens/food_store_screen.dart#L109),
  [:115](../lib/features/store/screens/food_store_screen.dart#L115),
  [:304-320](../lib/features/store/screens/food_store_screen.dart#L304)).
- Render the bar when **cart non-empty OR the strip has something to say**.
- **Bottom padding must track the bar's MEASURED height**, which now varies
  (pill only / pill + strip / strip only). The current fixed
  `bottomNavReserve(context) + 60` ([:284](../lib/features/store/screens/food_store_screen.dart#L284))
  will clip the last menu row once the strip appears.

  Measure it — `GlobalKey` on the bar, report the height up on layout, feed it
  into the tail `SliverToBoxAdapter`. **Do not reserve for the tallest state:**
  the strip is absent in the common case (no minimum, no threshold, empty cart),
  so a fixed worst-case reserve burns scroll space on every load to solve a
  problem that usually is not there.

  Implementation note: measuring during layout and feeding it back into the same
  frame's scroll extent is a classic one-frame-late bug. Report via
  `addPostFrameCallback` and hold the value in state, seeded with a sane default
  so the first frame is not visibly short.

### Step 6 — Tap acknowledgement

With the toast gone the bar must visibly react: a scale pulse (1.0 → 1.04 → 1.0,
~200ms) on count change. Transform-only — no relayout, same reasoning as the
toast animation fix.

---

## 5. Translation keys

New keys, **both `en.json` and `ar.json`** or they render as the raw key silently:

| Key | EN |
|---|---|
| `saved` | saved |
| `waddy_free_delivery_unlocked` | WADDY! Free delivery unlocked |
| `waddy_got_you_free_delivery` | Psst… Waddy got you free delivery |
| `add_more_for_free_delivery` | more for FREE DELIVERY |
| `add_more_to_order` | more to order |

Reusable as-is: `item`, `items`, `free_delivery`, `view_cart`, `add`,
`minimum_order`.

> ⚠️ Pre-existing inconsistency: `item` = `"item"` (lowercase) but `items` =
> `"Items"` (capitalised). The reference reads `1 Item`. Normalise both to
> capitalised, or the bar will read `1 item` / `2 Items`. Check AR too.

---

## 6. Risks

| Risk | Mitigation |
|---|---|
| Strip logic drifts from checkout's six conditions → bar promises free delivery the user does not get | Single `CartRewardState` resolver; unit-test it against all six branches |
| 228KB Lottie on a scroll-heavy screen | 36×36, no loop except on celebrate |
| Bottom padding wrong → last row unreachable | Reserve for tallest state; verify on device |
| Arabic overflow in the pill | Flexible + chip-drops-first |
| Other screens lose feedback | `showToast` defaults `true`; only Food opts out |

---

## 7. Open questions

1. ~~**Coupon/XP free delivery before checkout.**~~ **RESOLVED — see §9.**
2. ~~**Takeaway (#1).**~~ **RESOLVED — strip hidden entirely in takeaway mode.**
   Rule 6 already covers it: nothing to say, so show nothing. No special case
   needed in the resolver beyond returning `hidden` when `orderType` is
   `take_away`.

---

## 8. Out of scope

- "Frequently bought together" carousel — separate feature.
- Grocery `StoreScreen` / `LiveCartWidget` — unchanged.
- Retiring `showCartSnackBar` globally — Phase 5 of
  [snackbar_noise_plan.md](snackbar_noise_plan.md).

---

## 9. Backend findings (verified against `waddy_back`)

Two questions were blocking Step 3. Both now answered from the source.

### (a) Can the backend control the free-delivery threshold? — **Yes**

It is a live admin setting, already plumbed end to end:

- **Admin UI:** `resources/views/admin-views/business-settings/business-index.blade.php`
- **Write:** `BusinessSettingsController.php:612-621` persists three keys —
  `admin_free_delivery_status`, `admin_free_delivery_option`, `free_delivery_over`
- **Served to the app:** `ConfigController.php:87-89` emits them as the
  `admin_free_delivery` object the app already parses into `AdminFreeDelivery`
  ([config_model.dart:895](../lib/common/models/config_model.dart#L895))
- **Enforced at order time:** `PlaceNewOrder.php:408-418`

So `freeDeliveryOver` is admin-tunable at runtime with no app release. **The
progress strip (state #3) is fully backed** — it reads a real, server-controlled
number, and the same number the server will enforce at checkout.

> Note the option is an enum, not a boolean: `free_delivery_to_all_store`
> (no progress — always free) vs `free_delivery_by_order_amount` (progress). The
> resolver must branch on `type`, not just on `status`. Getting this wrong shows
> a progress bar to users who already have free delivery unconditionally.

### (b) Is there a first-order signal? — **Yes, but narrower than assumed**

`UserInfoModel.isValidForDiscount`
([userinfo_model.dart:76](../lib/features/profile/domain/models/userinfo_model.dart#L76))
already exists, is already parsed, and is already used by checkout
([checkout_calculation_helper.dart:531](../lib/features/checkout/helpers/checkout_calculation_helper.dart#L531))
and the cart screen.

Server-side it is computed by `Helpers::getCusromerFirstOrderDiscount`
(`app/CentralLogics/helpers.php:3870`), returned from
`CustomerController.php:199`. The gate is:

```php
if ($order_count > 0 || !$refby) { return $data; }   // is_valid = false
```

**Three constraints that change the design:**

1. **It is a referral mechanic, not a blanket new-user perk.** `!$refby` means a
   user who signed up *without* a referral code never qualifies — no matter how
   new they are. This will be a minority of users, not "most first-time users".
2. **It is a DISCOUNT, not free delivery.** The payload is
   `discount_amount` + `discount_amount_type` (`amount` or `percent`). Calling it
   "free delivery" in the strip would be **factually wrong**.
3. It is time-boxed by `new_customer_discount_amount_validity`, so it can expire
   while the user is still on their first order.

### Consequence for the ladder

The "Psst" hook **can ship**, but it must tell the truth. Revise state #5:

| Was | Becomes |
|---|---|
| `5. Cart empty + free delivery → "Psst… Waddy got you free delivery"` | `5a. Cart empty + isValidForDiscount → "Psst… Waddy got you <amount> off your first order"` |
|  | `5b. Cart empty + unconditional free delivery (#2/#3) → "Psst… Waddy got you free delivery"` |

5b is the honest free-delivery hook, and it fires whenever the store is
always-free or admin free-to-all is on — both real, both server-controlled, and
neither requiring a referral. 5a covers the first-order case with correct copy.

**Coupon (#5) and XP (#6) stay out of the store-screen strip.** Both only resolve
after the user acts on the checkout screen; there is no pre-checkout signal for
either, and inventing one would risk promising a discount the server then
declines.

### Extra translation keys this implies

| Key | EN |
|---|---|
| `waddy_got_you_first_order_off` | Psst… Waddy got you {amount} off your first order |

(`waddy_got_you_free_delivery` from §5 still covers 5b.)

### Still worth confirming with you

`new_customer_discount_*` is **not parsed by the app at all** — the config keys
are served but no Dart model reads them. `isValidForDiscount` carries the
already-computed amount on the *user* object, so the strip does not strictly need
them. Flagging it only because it means the discount's own display rules
(validity window, type) are server-side and invisible to the app beyond the
resolved amount.
