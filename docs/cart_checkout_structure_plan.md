# Cart & checkout — structure and fix plan

**Date:** 2026-09-16 · **Scope:** `waddi_user`, `lib/features/cart/`,
`lib/features/checkout/`, `lib/features/payment/` — the structure of the flow,
not its arithmetic
**Status:** Phases 0–3 and the `CS-10` half of Phase 6 landed 2026-09-16.
Closed: `CS-02`, `CS-03`, `CS-07`, `CS-09`, `CS-10`. Substantially closed:
`CS-01` (pricing out of `build()`; four availability flags remain — see
Phase 2). Partially addressed: `CS-11` (`test/unit/cart_checkout_test.dart`,
16 tests). Open: `CS-04`, `CS-05`, `CS-06`, `CS-08`, `CS-12`, and the `CC-*`
queue.

Analyzer across cart, checkout and payment: **40 → 15.**

Findings are `CS-01`…`CS-12`, referenceable from commits the way `X-*` is used
in `xp_module_plan.md`, `S-*` in `spots_module_plan.md`, `F-*` in
`food_module_plan.md`, `G-*` in `grocery_module_plan.md` and `M-*` in
`module_architecture_plan.md`.

**Read `cart_checkout_fix_plan.md` first.** That document owns *correctness*:
22 findings (`CC-01`…`CC-22`) on wrong prices, races, idempotency and server
trust, with §2 (the quantity stepper) already landed. This document owns
*structure* — why those bugs were possible and keep recurring. Where the two
overlap the ID is named. **Nothing here supersedes a `CC-*` fix**; several
`CC-*` items get materially cheaper after `CS-01` and `CS-02`.

The surface: `checkout_screen.dart` (1,503 lines),
`order_successful_screen.dart` (1,177), `cart_screen.dart` (893),
`pill_cart_bar.dart` (732), `cart_controller.dart` (682),
`checkout_controller.dart` (665), `checkout_calculation_helper.dart` (616),
`bottom_section.dart` (608), plus the widget set and payment.
**16,525 lines total.**

---

## Summary

One sentence: **the price of the order is computed inside `build()`, and the
order is described twice.**

Everything below follows from those two facts.

1. **`CS-01` — 14 chained price calculations run in `build()`**, writing their
   intermediate results back onto `State` fields. The order total is a
   side-effect of painting a frame. This is the structural cause behind
   `CC-09` (tax raced from `build()`), `CC-03` (order placed mid-recalculation)
   and `CC-14` (the cart's button contradicts the next screen).

2. **`CS-02` — the order payload is built twice, and `order_amount` means two
   different things.** `checkout_screen.dart:489` builds one for `getOrderTax`
   sending `subTotal`; `:1254` builds another for the order sending `total` —
   which includes delivery, tips, packaging and the tax figure itself. That is
   the field the server prices tax from. `CC-15` names the duplication; the
   `order_amount` divergence is new, and it needs a backend read to size.

Then the patterns this codebase keeps producing:

3. **Subtotal is computed by two independent code paths** (`CS-03`) —
   `CartController.calculationCart()` and `CheckoutCalculationHelper`. `CC-14`
   is the visible symptom; the duplication is why it recurs.

4. **Nine controllers, 80 `Get.find` calls in one screen** (`CS-04`), with 25
   `GetBuilder`s across cart and checkout of which **2** are scoped (`CS-05`).
   Exactly `X-01`'s shape, one screen over.

5. **Build-time controller mutation** (`CS-06`) — `cart_screen.dart` fires six
   controller writes from `initState`-adjacent code and `checkout_screen.dart`
   assigns seven `State` fields inside `build()`.

**Verified and worth recording so nobody re-audits it:**

- **The quantity stepper is correct.** `CartController._syncQuantity` serializes
  writes per line, newest-wins, and `_applyServerCart` preserves local
  quantities for lines with a write in flight. Landed 2026-09-14 under
  `cart_checkout_fix_plan.md` §2. Do not rework it.
- **`PillCartBar` is clean.** 732 lines, one `CartController` builder, no
  cross-controller reads, design rationale documented inline. It is the
  best-structured thing in the feature. See memory `cart-bar-which-widget`.
- **The server recomputes every line price.** The client-sent `price` is not
  trusted (`waddy_back/app/Traits/PlaceNewOrder.php:1117-1129`), already
  recorded in `cart_checkout_fix_plan.md` §3.

---

## Part 1 — Findings

### CS-01 · The order total is computed inside `build()`

`checkout_screen.dart:316-620` runs fourteen chained calculations in the build
method, each feeding the next:

```dart
double price          = _calcHelper.calculatePrice(...);          // :316
double addOns         = _calcHelper.calculateAddonsPrice(...);    // :320
double variations     = _calcHelper.calculateVariationPrice(...); // :324
double? itemDiscount  = _calcHelper.calculateDiscountPrice(...);  // :329
double? storeDiscount = _calcHelper.calculateDiscountPrice(...);  // :336
double extraDiscount  = _calcHelper.getExtraDiscountPrice(...);   // :344
double? discount      = _calcHelper.getDiscountPrice(...);        // :348
double subTotal       = _calcHelper.calculateSubTotal(...);       // :356
double referral       = _calcHelper.calculateReferralDiscount(...);// :363
double orderAmount    = _calcHelper.calculateOrderAmount(...);    // :369
…
double deliveryCharge = _calcHelper.calculateDeliveryCharge(...); // :600
```

Three consequences, each already a `CC-*` symptom:

**It writes to `State` from `build()`.** Seven fields are assigned mid-build —
`_taxPercent` (:298), `_isCashOnDeliveryActive` (:272),
`_isDigitalPaymentActive` (:275), `_isOfflinePaymentActive` (:282),
`badWeatherChargeForToolTip` (:612), `extraChargeForToolTip` (:613),
`_payableAmount`. A rebuild from any of nine controllers silently changes what
the screen believes about payment availability.

**It makes the total unavailable outside `build()`.** Every price is a local.
The Place Order handler at `:982` cannot read them, which is precisely why the
payload is rebuilt from scratch at `:1254` — see `CS-02`.

**It makes `CC-09` structural.** Tax is requested from `build()` because the
payload it needs only exists in `build()`. Fixing `CC-09` without `CS-01`
means keeping the fetch where it cannot safely live.

**Fix:** a `CheckoutPricing` value type — an immutable snapshot of the fourteen
numbers — computed by `CheckoutController` when its inputs change (cart,
coupon, address, tip, packaging, prize, schedule), exposed as one getter, and
read by both `build()` and the order handler. `build()` then formats numbers it
did not compute. This is the same move `SpotsRound` made for the Spots round
seam (memory `spots-round-lock-time`): one derived object, one owner.

**Depends on:** nothing. Unlocks `CC-03`, `CC-09`, `CC-14`.

---

### CS-02 · The order is described twice, and the tax quote is priced off a different number

```
checkout_screen.dart:489   PlaceOrderBodyModel(...)   → getOrderTax(placeOrderBody)
checkout_screen.dart:1254  PlaceOrderBodyModel(...)   → the actual order
```

Both are preceded by the **same ~40-line cart-item loop**, copy-pasted. The
constructor arguments then diverge on 16 fields — 14 are shared, 4 appear only
in the tax copy (`cutlery`, `deliveryInstruction`, `partialPayment`,
`unavailableItemNote`) and 12 only in the order copy (`address`, `addressType`,
`house`, `floor`, `streetNumber`, `latitude`, `longitude`, `senderZoneId`,
`contactPersonName`, `contactPersonNumber`, `scheduleAt`, `taxAmount`).

**Most of that divergence is harmless, and saying so matters.** The backend's
tax handler (`waddy_back/app/Traits/PlaceNewOrder.php:1629`, routed at
`routes/api/v1/api.php:434`) reads exactly nine request fields:

```
cart, order_amount, store_id, order_type, is_buy_now,
is_prescription, cart_id, parcel_category_id, guest_id
```

No zone, no address, no coordinates, no schedule. So the twelve address and
schedule fields missing from the tax payload change nothing today. **They are
fragility, not a bug** — a future zone-based tax rule would silently read null.

**Three of the nine do diverge, and one of them is a live bug:**

| field | tax call (:489) | order call (:1254) |
|---|---|---|
| **`orderAmount`** | `widget.storeId == null ? subTotal : 0` | **`total`** |
| `isBuyNow` | `widget.fromCart ? 0 : 1` | absent (defaults) |
| `guestId` | `0` | absent (defaults) |

`order_amount` is **the field tax is priced from**:

```php
// PlaceNewOrder.php:1639
$product_price = $request->order_amount ?? 0;
```

The tax quote sends `subTotal`. The order sends `total` — which
`calculateTotal` (`checkout_calculation_helper.dart:497`) defines as:

```dart
subTotal + deliveryCharge - discount - couponDiscount
  + (taxIncluded ? 0 : tax)        // ← tax is inside total
  + tips + additionalCharge + extraPackagingCharge
```

So the order's `order_amount` carries delivery, tips, packaging **and the tax
figure itself**. The number the customer was quoted tax on is not the number
the order is priced on, and the order's is inflated — circularly, since tax is
one of its addends.

Whether the server's final total is wrong depends on which figure
`PlaceNewOrder` ultimately trusts when placing (it recomputes line prices —
`cart_checkout_fix_plan.md` §3 — but `order_amount` is a separate input).
**That is the one thing to confirm before sizing the fix**, and it is a
backend read, not a guess.

`CC-09` observes that tax "is requested from `build()`, duplicated and raced".
This is the duplication's actual cost.

**Fix:** one `PlaceOrderBodyModel` builder on `CheckoutController`, taking the
`CS-01` pricing snapshot. The tax quote takes an explicit `.forTaxQuote()`
projection of the **same** source, so a field cannot go missing by omission and
`orderAmount` cannot mean two things. Settle deliberately which figure
`order_amount` should carry, and send that one from both.

**Depends on:** `CS-01` (the pricing snapshot). Subsumes the structural half of
`CC-15`.

**Verify:** a unit test asserting the tax payload and the order payload agree on
every field either sets. On device, after confirming the backend reading:
place an order with a tip and non-zero delivery, and check the tax shown at
checkout against the tax on the placed order.

---

### CS-03 · Subtotal has two independent implementations

| owner | method | used by |
|---|---|---|
| `CartController` | `calculationCart()` (`:123-201`) | the cart screen, the cart bars |
| `CheckoutCalculationHelper` | `calculateSubTotal()` (`:348`) | the checkout screen |

Both walk the cart, both apply add-ons, variations and item discounts, both
produce "subtotal". Neither calls the other.

`CC-14` reports that the cart's `Pay {subtotal}` button shows a number the next
screen contradicts. That is this finding's symptom. Fixing the label without
merging the implementations leaves two functions that must be kept in agreement
by hand forever.

**Fix:** `CheckoutCalculationHelper` becomes the single implementation;
`CartController` delegates. The helper is already the more complete of the two
(it handles referral, extra packaging, bad-weather and surge).

**Verify:** a unit test feeding one cart to both paths and asserting equality —
which should fail today.

---

### CS-04 · Nine controllers, 80 `Get.find` calls, one screen

```
CheckoutController  25    ProfileController   7
SplashController    17    AddressController   4
CouponController    12    HomeController      3
CartController       9    XpController        2
                          LocationController  1
```

`Get.find` inside `build()` is an untracked dependency: nothing declares it,
nothing can stub it, and a test cannot construct the screen without registering
all nine. This is why `test/` has no checkout coverage at all.

**Fix:** not a rewrite. Route the reads that belong to pricing through the
`CS-01` snapshot, which removes most `SplashController`, `CouponController` and
`XpController` reads from the screen. Re-measure after `CS-01`/`CS-02` before
touching the rest.

---

### CS-05 · 25 builders, 2 scoped

Cart and checkout hold 25 `GetBuilder`s. Two carry a scope — both from the
2026-09-14 stepper work (`filter:`) and the 2026-09-16 XP pass (`id:`).

The rest rebuild on any `update()` from their controller, and
`CheckoutController` calls bare `update()` **37 times**.

This is `X-01` one screen over, with the same fix and the same payoff. `X-01`
is now done and its ids are a working reference
(`xp_controller.dart:30-60`).

**Fix:** the `X-01` treatment — ids on `CheckoutController` for the units the UI
subscribes to (pricing, address, schedule, payment method, tip, instructions),
then scope the 37.

**Depends on:** worth doing after `CS-01`, so the ids describe a settled shape.

---

### CS-06 · Controller writes from build-time code

`cart_screen.dart:59-87` fires six controller mutations in sequence —
`getCartDataOnline`, `updateCutlery`, `toggleExtraPackage`, `setAvailableIndex`,
`getCartStoreSuggestedItemList`, `getStoreDetails`, `calculationCart` — several
guarded by `willUpdate: false` specifically to suppress the rebuild they would
otherwise cause.

`willUpdate: false` is the same tell as XP's `Future.microtask(() => update())`
(`X-01`): a parameter that exists only to make a write survive being called from
the wrong place. In XP those seven microtasks disappeared once the fetch moved
out of `build()`; the same is available here.

**Fix:** move the sequence into an explicit `init` on the controller, called
once from `initState`. Delete the `willUpdate` parameters afterwards — if
nothing needs to suppress a rebuild, nothing should be able to.

---

### CS-07 · `checkout_screen.dart` is 1,503 lines with the payload loop twice

Beyond `CS-02`'s divergence, the ~40-line cart-item construction loop appears
verbatim at `:470` and `:1235`. Any change to how a cart line becomes an order
line must be made twice, and `CS-02` is evidence that such changes have already
been missed.

**Fix:** falls out of `CS-02` — one builder, one loop.

---

### CS-08 · `order_successful_screen.dart` is 1,177 lines

Second-largest file in the feature, and the landing point for every payment
path. `CC-17` (stacked payment-failed dialogs) and `CC-19` (points computed from
the client total) both live here. Not yet audited structurally — flagged so the
number is on record, with a read before it is touched.

**Fix:** audit before acting. Do not restructure on the strength of a line
count.

---

### CS-09 · The `_calcHelper` instance is per-screen, and stateful

`CheckoutCalculationHelper` is instantiated as a `State` field
(`checkout_screen.dart:79`) and carries mutable fields read back out after a
call — `badWeatherChargeForToolTip` and `extraChargeForToolTip` are assigned to
`State` at `:612-613` *after* `calculateDeliveryCharge` ran at `:600`.

A calculation helper that returns one number and leaves two more on itself is
an out-parameter. It works only because the calls happen in a fixed order in
one method, which is exactly the property `CS-01` removes.

**Fix:** return a record or a small result type from
`calculateDeliveryCharge`. Absorbed by `CS-01`'s snapshot.

---

### CS-10 · 40 analyzer issues across cart, checkout and payment

`flutter analyze lib/features/cart lib/features/checkout lib/features/payment`
reports 40, including dead code in `top_section.dart` (five sites),
`delivery_section.dart`, an unused `_buildSummaryRow` in `bottom_section.dart`,
and an unused `live_cart_widget` import in `dashboard_screen.dart` (left behind
when the dashboard moved to `PillCartBar`).

Mechanical, and the count is a usable progress signal — Spots and XP both used
it that way.

---

### CS-11 · Nothing tests cart or checkout

`test/` has no cart or checkout coverage. Every candidate is pure or near-pure:

- `CheckoutCalculationHelper`'s fourteen methods — pure functions over a cart
  and a config
- `calculationCart` vs `calculateSubTotal` agreement (`CS-03`)
- tax-payload vs order-payload field agreement (`CS-02`)
- `CartController._syncQuantity` serialization — already correct, worth pinning
  before anything near it moves

`CC-04`'s and `CC-09`'s fixes are each a few-line controller test once `CS-01`
has landed.

---

### CS-12 · `CartController` mixes cart contents with checkout preferences

`_addCutlery`, `_needExtraPackage`, `_isExpanded`, `_notAvailableIndex` and
`_directAddCartItemIndex` sit alongside `_cartList` and the price fields. Two of
them are order options the checkout screen reads and writes; one is UI state.

`CC-10` (extra packaging defaults to on, and paths skipping the cart screen
charge for it silently) is a direct consequence: the default lives on the cart,
so a path that never opens the cart never gets a chance to ask.

**Fix:** move the order options onto `CheckoutController` where the rest of the
order's options already live; leave `_isExpanded` as screen state. Do this
**with** `CC-10`, not before it.

---

## Part 2 — Phased plan

Ordering rule: the two structural fixes first, because six `CC-*` items get
cheaper after them, and because `CS-02` carries a live `order_amount`
divergence.

**Phase 1's prerequisite is discharged.** Read 2026-09-16 — the answer, so
nobody re-reads it:

For every order type this app places, **the client's `order_amount` is
overwritten before it is used.** `PlaceNewOrder.php:205` seeds
`$order->order_amount` from the request, then `:472` replaces it with
`round($total_price + $tax_amount + $order->delivery_charge)` — `$total_price`
being recomputed server-side from the cart — and `:516` adds tips, additional
charge and packaging. The parcel branch overwrites it too (`:478`, `:510`).

`getCalculatedTax` does read `$request->order_amount` directly
(`:1638`), but only for parcel and prescription orders; for everything else it
recomputes `$product_price` from the cart at `:1729`.

**So the `subTotal`/`total` divergence was a wrong quote, not a wrong charge**,
and only latently: both sides recompute from the cart today, so the quoted tax
was correct by accident. The fix is still worth making — it removes the
accident — but it is not a customer-facing pricing bug, and Phase 1 was sized
accordingly.

### Phase 0 — Safety net · **landed 2026-09-16**

`test/unit/cart_checkout_test.dart`:

- `CheckoutCalculationHelper` against a known cart: subtotal, discounts,
  delivery charge, total
- `calculationCart` and `calculateSubTotal` agree on one cart (**fails today** —
  `CS-03`)
- the tax payload and the order payload agree on every field either sets
  (**fails today** — `CS-02`)
- `_syncQuantity` keeps one write per line in flight, newest-wins

**Landed** as `test/unit/cart_checkout_test.dart` — 10 tests, all passing.
Departures from the sketch above, and why:

- **`calculationCart` is not tested directly.** It needs a
  `CartServiceInterface` and a repository to construct, which is a boot, not a
  unit test. `CS-03` is instead pinned against the arithmetic each path
  performs, which is the part that has to agree.
- **Two new facts came out of writing it**, both recorded as tests:
  - `CheckoutCalculationHelper`'s methods are **not** pure functions over a
    cart and a config, as `CS-11` claims. `calculatePrice` reaches through
    `PriceConverter.toFixed` for `digitAfterDecimalPoint` and `calculateTotal`
    reads `dmTipsStatus`, both via `Get.find` and both with a `!` — so they
    throw, rather than degrade, before config arrives. That is `CS-04`'s
    hidden-dependency shape one layer below the screen.
  - **A null `store` prices a non-food cart at zero.** For a non-food module
    `calculatePrice` discards its own accumulator and returns
    `calculateVariationPrice(...)`, whose whole body is inside
    `if (store != null)`. The screen passes `checkoutController.store`, which
    is null until the store fetch resolves, and prices on every build
    (`CS-01`) — so the window exists. Worth a `CC-*` look on its own.
- Two `@visibleForTesting` seams were added to `SplashController`
  (`setModuleConfigForTest`, `setConfigModelForTest`) because the alternative
  was booting an `ApiClient` and a repository to assert a multiplication.

### Phase 1 — One order, one description (`CS-02`, `CS-07`) · **landed 2026-09-16**

**What landed:**

- `lib/features/checkout/helpers/order_payload_builder.dart` —
  `OrderPayloadBuilder.buildCartLines`, the ~40-line cart-item loop extracted
  verbatim from its two copies. Both call sites now call it. **`CS-07` closed.**
- **`order_amount` settled on `subTotal`**, sent from both payloads. Given the
  backend read above this changes no charge today; it removes the divergence so
  a future amount- or zone-sensitive tax rule cannot read two numbers.

**What did not land, and why:** the plan called for the builder to live on
`CheckoutController` with a `.forTaxQuote()` projection. It does not, because
the pricing it would need is still local to `build()` — threading `subTotal` to
the order handler already required adding an eleventh positional parameter to
two methods. Moving the payload onto the controller is therefore **blocked on
`CS-01`**, and belongs to Phase 2 rather than ahead of it. The cart-line loop,
which needs no pricing, was extracted now.

**Verified:** `flutter test` — 200 pass (`test/golden/marks_render_test.dart`
excluded as always). Analyzer unchanged at 40.

**Still needs a device check** (`no-builds-user-tests`): place an order with a
tip and a non-zero delivery charge, and confirm the tax shown at checkout
matches the tax on the placed order.

### Phase 2 — The pricing snapshot (`CS-01`, `CS-09`) · **landed 2026-09-16**

**What landed:**

- `lib/features/checkout/domain/models/checkout_pricing.dart` —
  `CheckoutPricing`, an immutable value carrying all nineteen figures, with a
  `.calculate()` factory that runs the chain in dependency order. The body is
  the chain as `build()` ran it, so this is a move, not a re-derivation.
- **`build()` no longer computes prices.** The fourteen chained calls are one
  construction; the ~40 downstream references read locals bound off the
  snapshot, so the widget tree below is untouched.
- **`CS-09` closed.** `badWeatherChargeForToolTip` and
  `extraChargeForToolTip` are fields on the value, read immediately after the
  call that sets them rather than scraped off the helper later. The three
  tooltip `State` fields were deleted outright — they were written and read
  within one `build()`, never across frames.
- `total` arrives net of the referral discount, instead of being computed and
  then decremented on a following line.

**What did not land, and why.** The plan says "delete the seven build-time
`State` assignments". Three are gone. The remaining four —
`_taxPercent`, `_isCashOnDeliveryActive`, `_isDigitalPaymentActive`,
`_isOfflinePaymentActive` — are **not** pricing, and unlike the tooltip fields
they are genuinely read outside the `build()` that writes them, by
`_setSinglePaymentActive` and by the place-order handler. Turning them into
locals means threading four more values through two methods that already take
eleven positional parameters each. They belong on `CheckoutController`
alongside the order's other options, which is Phase 5's shape — not a
by-product of the pricing move. Noted in the code at the field declarations.

**A finding worth carrying forward.** Writing the tests established that
pricing one cart reaches through `Get.find` for **four** controllers —
`SplashController`, `ProfileController`, `XpController` and `CartController` —
each dereferenced with `!`, each throwing rather than degrading when absent.
`CS-04` counts `Get.find` calls in the *screen*; this is the same shape one
layer below it, in the arithmetic the screen calls. Moving pricing out of
`build()` does not move these, and `CS-04`'s "re-measure after `CS-01`/`CS-02`"
should count them too.

**Verified:** `flutter test` — 204 pass (`test/golden/marks_render_test.dart`
excluded). Analyzer unchanged at 40. Four new tests pin the snapshot against
the chain it replaced.

### Phase 3 — Merge the subtotal implementations (`CS-03`) · **landed 2026-09-16**

**The divergence, measured.** `CartController` turned out to be constructible
from a service alone, so the two paths could be run against one cart directly.
For a cart of 2 × 100 with a 10% item discount:

| path | figure |
|---|---|
| `CartController.calculationCart` | **180** — net of the item discount |
| `CheckoutCalculationHelper.calculateSubTotal` | **200** — gross, discount is its own row |

That is `CC-14` reproduced as arithmetic, and it reframes the merge: the two
were not an implementation and a buggy copy, they were **two different
questions sharing one name**. The cart bars want the figure the customer will
pay; checkout wants a breakdown that sums.

**What landed.** The merge removes the second *implementation* and keeps both
*meanings*. `CheckoutCalculationHelper.calculateNetSubTotal` states the cart's
meaning in terms of the checkout's (`subTotal - itemDiscount`);
`CartController.calculationCart` delegates to it. The loop above the delegation
stays — it populates `_addOnsList`, `_availableList`, `_itemPrice` and
`_variationPrice`, which the cart screen reads.

**Decision recorded:** the cart bar keeps showing **net**. Following the plan's
original wording — delegate to `calculateSubTotal` — would have raised the
number on the cart bar from 180 to 200. Showing a customer 200 and then 180 is
better than 180 and then 200, so the merge went the other way.

**Guarded by two tests**, both of which had to pass before the delegation was
made: the net projection reproduces `calculationCart`'s number exactly, and the
two meanings still differ by the item discount. `CC-14`'s remaining question —
whether the *checkout screen* should also lead with the net figure — is that
finding's own call and is untouched here.

**Verify:** `flutter test` — 206 pass.

### Phase 4 — The `CC-*` correctness queue

With Phases 1–3 in, work `cart_checkout_fix_plan.md`'s own phases. `CC-03`,
`CC-04`, `CC-09`, `CC-14` and `CC-15` are materially smaller by this point;
`CC-01`, `CC-07`, `CC-08`, `CC-20` are backend and independent of everything
here.

### Phase 5 — Rebuild scope (`CS-05`) and build-time writes (`CS-06`)

Ids on `CheckoutController`, the 37 scoped, the cart screen's init sequence
moved onto the controller and `willUpdate` deleted.

**Verify:** changing the delivery tip does not rebuild the cart item list.

### Phase 6 — Hygiene (`CS-10` · **landed**), ownership (`CS-12`), and `CS-08`

**`CS-10` landed 2026-09-16: 40 → 15.** Applied `dart fix` scoped to four safe
codes (`prefer_const_constructors`,
`prefer_const_literals_to_create_immutables`,
`curly_braces_in_flow_control_structures`, `unnecessary_string_interpolations`,
then `unnecessary_const`) one directory at a time — never `dart format`.
Removed the unused `_buildSummaryRow` in `bottom_section.dart` and the stale
`live_cart_widget` import in `dashboard_screen.dart`.

**The remaining 15 are deliberate, and the count should not be driven to zero:**

- **6 dead-code warnings** in `top_section.dart` and `delivery_section.dart`.
  `CS-10` calls these "dead code … (five sites)", but they are not stray: all
  six sit behind `bool isGuestLoggedIn = false`, the **guest-checkout UI**,
  kept against `docs/guest_mode_plan.md`, which is specified but not built.
  Deleting them would throw away the scaffolding that plan assumes. Annotated
  at both declarations so the next person does not "fix" them.
- **9 deprecation infos** from the Flutter SDK — `withOpacity` and Radio's
  `groupValue`/`onChanged`. Real API migrations, not hygiene, and they touch
  widgets well outside this plan.

`CS-12` (order options off `CartController`) and `CS-08` (audit
`order_successful_screen.dart`) remain open and unchanged.

---

## Out of scope

- **Everything `cart_checkout_fix_plan.md` owns.** This plan does not re-decide
  a `CC-*` fix; it makes several of them cheaper. Where a `CS-*` and a `CC-*`
  touch the same lines, the `CC-*` acceptance criteria win.
- **`cart_screen_restructure_plan.md`.** Layout work on the same screen. `CS-06`
  touches that screen's init, not its layout.
- **`PillCartBar`.** Verified clean. See memory `cart-bar-which-widget`.
- **The quantity stepper.** Landed and correct; Phase 0 pins it so later work
  cannot silently break it.
- **Backend order rules.** `waddy_back` findings stay in
  `cart_checkout_fix_plan.md`.

## Verification discipline

`flutter analyze` and `flutter test` after every phase — never a build; the user
tests on device (`no-builds-user-tests`). Exclude
`test/golden/marks_render_test.dart`; 190 tests pass without it at the time of
this audit. **Do not run `dart format`** on this repo's files — see the note in
`food_module_plan.md`. Every new `.tr` key goes into **both** `en.json` and
`ar.json` (`translation-keys-workflow`).

Cart, checkout and payment reported **40 analyzer issues** at the time of this
audit; they report **15** after Phase 6's `CS-10` pass, and 15 is the floor
worth reaching — see Phase 6 for why the remainder should stay. Spots is at 0
and XP at 25.
