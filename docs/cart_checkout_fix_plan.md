# Cart & checkout: correctness and reliability plan

**Target:** `lib/features/cart/`, `lib/features/checkout/`, `lib/features/payment/`, and the order
endpoints in `waddy_back`
**Status:** planned, not implemented, except §2, which has landed.
**Date:** 2026-09-14
**Related:** `docs/cart_screen_restructure_plan.md` (layout work on the same screen; see CC-14),
`docs/snackbar_noise_plan.md` (CC-15 removes a build-time snackbar)

---

## 0. How to read this

Each finding has an ID (`CC-nn`), a severity and a side:

| Severity | Meaning |
|---|---|
| **P0** | The user pays a different amount than shown, a valid order is blocked, or the place-order button stops working |
| **P1** | Money leaks, the server trusts the client, or wrong data reaches the user |
| **P2** | The flow is fragile or misleading, but a user can get past it |
| **P3** | Hygiene, a product decision, or an adjacent risk |

Every item has the same parts: **Symptom → Evidence → Root cause → Fix → Files → Verify**.
File references are `path:line` as of 2026-09-14. Backend paths start with `waddy_back/`.
Everything else is in `waddi_user/`.

**Working constraints (apply to every phase):**

- Never run `flutter build` / `flutter run`. Run `flutter analyze` on the touched files and `flutter test`
  for unit tests, then hand device testing to the user.
- The working tree has 800+ uncommitted changes. No `stash`, `checkout`, `reset` or `clean`.
  Commit only when asked.
- Every new `.tr` key goes into **both** `assets/language/en.json` and `ar.json`. A missing key renders as the
  raw key, with no error.
- The user deploys backend changes. App items that depend on a backend change say so under
  **Depends on**.

---

## 1. Summary

| ID | Problem | Side | Sev | Effort | Phase |
|---|---|---|---|---|---|
| CC-01 | A failed order attempt locks the user out for 30 s. The idempotency key is used up before validation. A crash returns "Forbidden" | Backend | P0 | M | 0 |
| CC-02 | Minimum order is checked after discounts, so a coupon can block a valid order | App | P0 | S | 1 |
| CC-03 | An order can be placed while the delivery distance is recalculating, and the UI shows "Free". Distance responses can land out of order | App | P0 | S | 1 |
| CC-04 | Tapping Pay while quantity writes are still pending means the order can be placed with the old quantity | App | P0 | S | 1 |
| CC-05 | A saved "custom" tip stops Place Order from working. Tip data comes from two sources | App | P0 | S→M | 1 (+3) |
| CC-06 | A slot shown as a time range is sent as ASAP, and the last slot of each day is scheduled after closing, so the server rejects both | App | P0 | S | 1 |
| CC-07 | Delivery fee is priced on a client-sent distance, which the app measures on a walking route | Backend + App | P1 | S (+decision) | 0 / 5 |
| CC-08 | Negative `dm_tips` is accepted and lowers the order total | Backend | P1 | XS | 0 |
| CC-09 | Tax is requested from `build()`, duplicated and raced, and not refreshed after coupon or packaging changes | App | P1 | M | 3 |
| CC-10 | Extra packaging defaults to on. Paths that skip the cart screen charge it without asking | App | P1 | S | 2 |
| CC-11 | The cart list request drops all normal headers (language forced to English, no zone, no image variants, `Bearer null`) | App | P1 | XS | 2 |
| CC-12 | A new idempotency key on every tap, so retries are never deduplicated. The client signature and rate limiter protect nothing | App + Backend | P1 | S | 3 |
| CC-13 | The cart screen never refreshes a non-empty cart, so stale prices and stock surface only at place order | App | P2 | S | 2 |
| CC-14 | The cart's "Pay {subtotal}" button shows a number the next screen contradicts | App | P2 | XS | 2 |
| CC-15 | `CheckoutScreen.build()` does controller work, and the order payload is duplicated in two copies that already differ | App | P2 | L | 3 |
| CC-16 | Offline payment: two separate requests, the spinner can stick, a retry can duplicate the order, cleanup is skipped | App (+Backend opt.) | P2 | M | 4 |
| CC-17 | The success screen can stack two payment-failed dialogs | App | P2 | XS | 4 |
| CC-18 | Digital payment deletes the cart at order placement, before payment | Backend (decision) | P3 | M | 5 |
| CC-19 | Points and the purchase value come from the client total, not the server's `total_ammount` | App | P3 | XS | 4 |
| CC-20 | Distance API is a public, unthrottled proxy to paid Google Routes | Backend | P3 | XS | 0 |
| CC-21 | Checkout hygiene: leaked controllers, stale surge price, double slot computation, unsafe `double.parse` | App | P3 | S | 5 |
| CC-22 | Logout may or may not delete the account's server cart, depending on which logout button was used | App (decision) | P3 | S | 5 |

---

## 2. Already landed (2026-09-14): the quantity stepper

The groundwork CC-04 builds on.

1. **Scoped rebuilds.** Food store menu rows, `CartCountView` and the three cart-count badges now use
   `GetBuilder(filter:)`, keyed by `item.id` where the builder sits in a list. A tap rebuilds one row, not every
   cart-aware widget. The GetX 4.7.3 gotchas (id builders ignore plain `update()`; the filter value isn't
   re-read in `didUpdateWidget`) are recorded in memory `getx-builder-scoping`.
2. **Serialized quantity writes.** `CartController._syncQuantity`
   (`lib/features/cart/controllers/cart_controller.dart:322`) keeps at most one write per cart line in flight.
   Taps made meanwhile only change the number on screen, and the newest number wins. The line re-syncs once it settles.
   `_applyServerCart` keeps local quantities on lines with a write still out or edited after the request left.

---

## 3. Checked and **not** a bug (so nobody "fixes" these)

| Claim | Why it's fine | Evidence |
|---|---|---|
| The server trusts the cart `price` the app sends | It recomputes every line from the product row | `waddy_back/app/Traits/PlaceNewOrder.php:1117-1129` |
| Backend error messages are lost | `ApiClient.handleResponse` maps `errors[0].message` to `statusText` | `lib/api/api_client.dart:346-350` |
| `setAddressIndex(1)` after "add new address" picks the wrong one | The address list is `latest()`, so the new address is first and lands at index 1 in the zone-filtered list | `waddy_back/app/Http/Controllers/Api/V1/CustomerController.php:40`, `lib/features/address/controllers/address_controller.dart:72` |
| Overnight store hours produce no slots | Overnight hours can't exist: the vendor panel requires `end_time` after `start_time`, and the server's open check can't represent them either | `waddy_back/app/Http/Controllers/Vendor/BusinessSettingsController.php:229`, `PlaceNewOrder.php:806` |
| A second coupon can stack over a free-delivery coupon | `coupon_section` shows **Remove** while `freeDelivery` is true | `lib/features/checkout/widgets/coupon_section.dart:97` |
| Place order times out after 12 s | Multipart uses `uploadTimeoutInSeconds = 60` | `lib/api/api_client.dart:45, 255` |
| `calculationCart` double-counts variation prices | Non-food assigns the price per line. Food accumulates and reads the total only after the loop | `lib/features/cart/domain/services/cart_service.dart:176-236` |

### Corrections to the first-pass audit

- **Tax does not depend on address or tip.** `getCalculatedTax` builds tax from the server cart, coupon and
  packaging only (`PlaceNewOrder.php:1669-1760`). CC-09's refresh triggers are narrowed to match.
- **The admin's per-module packaging switch is already respected.** The store payload folds it into
  `extra_packaging_status` (`waddy_back/app/CentralLogics/helpers.php:939, 960`). CC-10 is now only about the
  default-on flag.
- **Found during verification, not in the first pass:** CC-01 (cooldown lockout) and CC-06 (slot scheduling).

---

## 4. Findings and fixes

### P0: wrong total, blocked orders, dead buttons

---

#### CC-01: a failed order attempt locks the user out for 30 seconds (backend)

**Symptom.** A user hits any business error: expired coupon, store closed, under the minimum, out of stock.
They fix it and tap Place Order again, and get *"Please wait before placing another order"* for 30 seconds.
If the server throws, the app shows **"Forbidden"**.

**Evidence.**
- `waddy_back/app/Traits/PlaceNewOrder.php:74-82`: `checkIdempotency` and `checkOrderCooldown` run
  **before** the transaction and before every business check.
- `waddy_back/app/Services/OrderSecurityService.php:36`: `Cache::add` claims the key permanently for 1 h.
- `OrderSecurityService.php:67`: `Cache::put(cooldown, 30s)` is written at check time, not on success.
- `PlaceNewOrder.php:641-645`: `catch` returns `response()->json([$exception], 403)`. The body is `[{}]`,
  which doesn't match the `errors` shape, so the app falls back to the HTTP reason phrase. It also serializes
  the exception.

**Root cause.** The "has this happened?" guards are recorded when an attempt *starts*, not when it *succeeds*.

**Fix.**
1. Make idempotency a three-state record, scoped to the user or guest:

   ```php
   // OrderSecurityService (sketch)
   private function idemKey(Request $r): ?string {
       $key = $r->input('idempotency_key');
       if (!$key) return null;
       $owner = $r->user?->id ? 'u'.$r->user->id : 'g'.$r->input('guest_id');
       return "order_idempotency:{$owner}:{$key}";
   }

   public function claimIdempotency(Request $r): ?JsonResponse {
       $k = $this->idemKey($r);
       if (!$k) return null;
       if (Cache::add($k, ['state' => 'pending'], 120)) return null;      // claimed
       $entry = Cache::get($k);
       if (data_get($entry, 'state') === 'done') {
           return response()->json($entry['response'], 200);             // replay: retry after a lost response
       }
       return response()->json(['errors' => [[
           'code' => 'order_in_progress',
           'message' => translate('messages.order_in_progress'),
       ]]], 409);
   }

   public function completeIdempotency(Request $r, array $response): void {
       if ($k = $this->idemKey($r)) Cache::put($k, ['state' => 'done', 'response' => $response], 3600);
   }

   public function releaseIdempotency(Request $r): void {
       if ($k = $this->idemKey($r)) Cache::forget($k);
   }
   ```

2. **Cooldown only on success.** Keep `Cache::has` at the start, but move the `Cache::put` to after
   `DB::commit()`.
3. **Wrap, don't edit, the 560-line body.** Rename the transaction section (lines 86-651) to
   `runPlaceOrder()`. `new_place_order()` then becomes: validate → claim → `runPlaceOrder()` → on a `200`, call
   `completeIdempotency` and start the cooldown, otherwise `releaseIdempotency`. That covers every early `return` in the body
   without touching each one.
4. **The exception path** returns the normal error shape and keeps the exception in the log only:

   ```php
   } catch (\Exception $exception) {
       info([$exception->getFile(), $exception->getLine(), $exception->getMessage()]);
       DB::rollBack();
       return response()->json(['errors' => [[
           'code' => 'order_failed',
           'message' => translate('messages.failed_to_place_order'),
       ]]], 500);
   }
   ```

5. The replay must return **before** `SendMetaPurchaseEvent` and notifications run, so a retry never sends
   a second purchase event or push. The sketch already does this, because replay happens in `claim`.

**Files.** `waddy_back/app/Services/OrderSecurityService.php`, `waddy_back/app/Traits/PlaceNewOrder.php`,
backend lang files for `order_in_progress`.

**Verify.** New feature test `tests/Feature/PlaceOrderGuardsTest.php`:
- An under-minimum attempt followed by a valid attempt with the **same** key returns 403, then 200 (no 429).
- The same key sent twice after success returns 200 twice, with the same `order_id` and one `orders` row.
- A thrown exception returns 500 with `errors[0].code == order_failed`.
- Two valid orders with **different** keys inside 30 s: the second gets 429.

**Depends on.** Nothing. **Blocks** CC-12.

---

#### CC-02: minimum order is checked after discounts

**Symptom.** Store minimum 100 EGP, basket 110 EGP, 20 EGP coupon: checkout says *"Minimum order amount is 100"*
and refuses. The server would accept the order. Store discounts and the referral discount cause the same thing
without a coupon. The cart bar has a milder form: *"Add 8 LE more"* while the server already accepts.

**Evidence.**
- App: `lib/features/checkout/screens/checkout_screen.dart:1076`, `orderAmount < store.minimumOrder`.
  `orderAmount` is `price + variations − discount + addOns − coupon − referral` (`checkout_calculation_helper.dart:322-346`).
- Cart bar: `lib/features/store/domain/models/cart_reward_state.dart:163-168` compares `subTotal`, which is after
  item discounts (`cart_controller.dart:199-201`).
- Server: `waddy_back/app/Traits/PlaceNewOrder.php:399`,
  `store->minimum_order > product_price + total_addon_price`. `product_price` is the **undiscounted** unit
  price × quantity (`PlaceNewOrder.php:1187`).

**Root cause.** The app has no number shaped like the server's minimum-order basis. It reuses the nearest total.

**Fix.**
1. `CheckoutCalculationHelper.minimumOrderBasis({price, addOns, variations, cartList})` returns the server
   formula: undiscounted item price (including variation price) plus add-ons. For food that equals the
   existing `subTotal`. For other modules it's `price + addOns`.
2. `checkout_screen.dart:1076`: compare `minimumOrderBasis`, not `orderAmount`. The snackbar text stays the same.
3. `CartController`: add `double get minimumOrderBasis` next to `subTotal`, computed inside `calculationCart()`
   from the same pre-discount parts.
4. `CartRewardState.resolveFromContext`: add a `minimumOrderBasis` parameter and use it **only** for rule 1
   (the minimum). Free-delivery thresholds keep using `subTotal`, because the server's `free_delivery_over` is post-discount
   (`PlaceNewOrder.php:416`). Update the three call sites (`pill_cart_bar.dart`, `food_store_cart_bar.dart`,
   `home_cart_bar.dart`).

**Files.** `checkout_calculation_helper.dart`, `checkout_screen.dart`, `cart_controller.dart`,
`cart_reward_state.dart`, and the three cart bars.

**Verify.**
- Unit: extend `test/cart_reward_state_test.dart` with a case where the discounted subtotal is under the
  minimum and the basis is over it, so the result must not be `minimumOrder`.
- Unit: `minimumOrderBasis` fixtures: a plain item, a discounted item, and a food item with a variation and an add-on.
- Device: a store with a minimum, a basket just over it, and a coupon that brings the total under. The order places.

---

#### CC-03: an order can be placed while the delivery distance is recalculating

**Symptom.** Switch the delivery address and tap Place Order within about a second. The screen shows **"Free"**
delivery, but the server charges its minimum fee, computed for `distance: -1`. Switching address twice quickly
can leave the fee for the first address on screen, because the last response to arrive wins.

**Evidence.**
- `lib/features/checkout/controllers/checkout_controller.dart:355-373`: `_distance = -1` before the request,
  then two awaits, with no check for a newer request.
- `lib/features/checkout/widgets/delivery_section.dart:70-74`: `getDistanceInKM(...)`, then `setAddressIndex` →
  `update()`, so the screen rebuilds with distance `-1`.
- `checkout_calculation_helper.dart:397-427`: with distance `-1` the per-km branches are skipped, but the
  `store != null && distance != null` block still runs and returns `0` (or the stale `extraCharge`), never `-1`.
- `checkout_screen.dart:1137-1140`: the guard is `distance == -1 && deliveryCharge == -1`, and the second half is
  never true.
- `checkout_screen.dart:612-624`: `deliveryCharge == 0` renders `'free'.tr`.

**Fix.**
1. **Guard.** For non-take-away orders, block when `distance == null || distance! < 0 || deliveryCharge < 0`,
   and keep the message `delivery_fee_not_set_yet`.
2. **Sentinel.** `calculateOriginalDeliveryCharge` returns `-1` immediately when `distance == null || distance < 0`,
   for every branch including `fixed`. The "calculating" label then renders correctly.
3. **Request token.**

   ```dart
   int _distanceRequest = 0;

   Future<double?> getDistanceInKM(LatLng origin, LatLng destination) async {
     final int request = ++_distanceRequest;
     _distance = -1;
     _extraCharge = null;
     update();
     final double km = await _measureKm(origin, destination); // existing API + straight-line fallback
     final double extra = await checkoutServiceInterface.getExtraCharge(km);
     // Callers (parcel, store) still use the return value, so only the
     // shared state is guarded.
     if (request == _distanceRequest) {
       _distance = km;
       _extraCharge = extra;
       update();
     }
     return km;
   }
   ```

4. While distance is `-1`, the place-order button shows `isLoading` rather than just refusing on tap.

**Files.** `checkout_controller.dart`, `checkout_calculation_helper.dart`, `checkout_screen.dart`.

**Verify.**
- Unit: `calculateOriginalDeliveryCharge(distance: -1)` returns `-1` for self-delivery, distance and fixed zones.
- Device, on a throttled network: switch address and tap Place Order at once. The button is busy or refuses,
  and the fee reads "calculating". Switch A → B → A fast: the fee matches A.

---

#### CC-04: Pay tapped while quantity writes are pending

**Symptom.** Tap + three times, then Pay straight away. Checkout shows the new quantity, but the server builds
the order from its `carts` table, which may still hold the old one. The user is charged for a different basket
than they saw.

**Evidence.**
- `waddy_back/app/Traits/PlaceNewOrder.php:314-322`: the order is built from `Cart::where(user_id…)`, not from the
  payload.
- `lib/features/cart/screens/cart_screen.dart:366-389` and `:1161-1197`: Pay navigates immediately.
- `lib/features/cart/controllers/cart_controller.dart:322`: `_syncQuantity` can still have a write out.

**Fix.**
1. `CartController`:

   ```dart
   final List<Completer<void>> _settleWaiters = [];

   /// Completes once no quantity write is on the wire. The server builds the
   /// order from its cart table, so anything that reads it must wait.
   Future<void> settleQuantityWrites() {
     if (_quantityWritesInFlight.isEmpty) return Future.value();
     final Completer<void> waiter = Completer<void>();
     _settleWaiters.add(waiter);
     return waiter.future;
   }
   ```

   In `_syncQuantity`'s `finally`, after `_quantityWritesInFlight.remove(cartId)`: if the set is now empty, complete and
   clear every waiter. Don't wait for the follow-up re-sync. The server cart is already correct once the
   write returns.
2. **Both** Pay buttons in `cart_screen.dart`: show a loading state, then
   `await cart.settleQuantityWrites().timeout(const Duration(seconds: 8))`. On timeout show `try_again`
   (the key already exists in both language files) and don't navigate.
3. `CheckoutController.placeOrder`: add the same `await` before sending, for any route that reaches checkout
   without the cart screen.
4. `CheckoutScreen.initCall` copies `cartList` **after** that await, which the cart screen now guarantees.

**Files.** `cart_controller.dart`, `cart_screen.dart`, `checkout_controller.dart`.

**Verify.**
- Unit, with a fake `CartServiceInterface` whose `updateCartQuantityOnline` completes on demand:
  `settleQuantityWrites()` stays pending until the last write completes, and completes right away when idle.
- Device, on a throttled network: tap + ×3, then Pay. The button spins briefly, and the order detail shows the
  final quantity.

---

#### CC-05: a saved "custom" tip stops Place Order from working

**Symptom.**
1. Tick "save for later" on a tip chip, switch to **custom**, enter an amount and place the order.
2. On the next checkout, Place Order does nothing: no snackbar, no request.

Separately, an invalid custom entry can leave the **shown** tip at 0 while a non-zero tip is **sent**.

**Evidence.**
- `lib/util/app_constants.dart:326`: `tips = ['0', '15', '10', '20', '40', 'custom']`.
- `checkout_controller.dart:564-566`: saves `selectedTips` (5) when `isDmTipSave`. That flag is never reset
  (a permanent controller), and its checkbox is hidden while custom is selected
  (`deliveryman_tips_section.dart:105`).
- `checkout_screen.dart:173-176`: the next checkout sets `tipController.text = AppConstants.tips[5]`, which is `'custom'`.
- `checkout_screen.dart:1082-1091`: `double.parse('custom')` throws inside `onPressed`.
- Two sources: the total uses `checkoutController.tips` (`checkout_screen.dart:642`), while the payload sends
  `tipController.text` (`:1312-1318`). `deliveryman_tips_section.dart:151-155` sets `tips` to 0 but only trims
  one character from the text.

**Fix.**
- **Phase 1 (small):**
  1. `initCall`: if the saved index is the custom index, call `updateTips(0)` and set the text to `''`, never `'custom'`.
  2. Validation: replace the `double.parse` of the text with `checkoutController.tips < 0`.
  3. Payload (both copies until CC-15): `dmTips: tips > 0 ? tips.toString() : ''`.
- **Phase 3 (with CC-15):** `CheckoutController.tips` is the only source. The text field writes to it through
  `addTips` and nothing reads the text back. Save the tip **amount** rather than the chip index, so a custom
  amount is remembered correctly. `isDmTipSave` resets in `initAdditionData`.

**Files.** `checkout_screen.dart`, `checkout_controller.dart`, `deliveryman_tips_section.dart`.

**Verify.**
- Device: reproduce the steps above. Place Order works, and the order detail's tip matches the screen.
- Device: type `5a` in the custom field. The shown total and the order detail agree.

---

#### CC-06: a time slot the user sees is not the time the server receives

**Symptom A.** The store opens at 17:00 and it's 10:00. Checkout shows the first slot as **"5:00 PM – 5:30 PM"**, the user
places the order, and the server replies *"store is closed at order time"*. With CC-01 unfixed, that attempt also
locks them out for 30 s.
**Symptom B.** Picking the **last** slot of any day always fails with the same error.

**Evidence.**
- `lib/features/checkout/widgets/time_slot_bottom_sheet.dart:97-101`: slot 0 is labelled "instance" **only if the store is open now**.
- `checkout_screen.dart:1253-1261`: the payload sends `scheduleAt: null` (ASAP) whenever date slot 0 and time slot 0 are
  selected, **whether or not the store is open**.
- `time_slot_section.dart:78`: before the sheet is opened, the default label is always `'instance'.tr`.
- `checkout_screen.dart:1005-1011`: the schedule is set to the slot **end + 1 minute**. For the last slot the end equals
  closing time.
- `waddy_back/app/Traits/PlaceNewOrder.php:806`: the open check is `opening_time < t AND closing_time > t`
  (strict), so closing time + 1 minute is always closed.

**Fix.**
1. `CheckoutController.isInstantSlot` is the only definition, used by the label, the sheet and the payload:

   ```dart
   bool get isInstantSlot =>
       _selectedDateSlot == 0 && _selectedTimeSlot == 0 &&
       _store != null && isStoreOpenNow(_store!.active!, _store!.schedules) &&
       (!(Get.find<SplashController>().configModel!.moduleConfig!.module!.orderPlaceToScheduleInterval!) ||
        (_store!.orderPlaceToScheduleInterval ?? 0) == 0);
   ```

2. `scheduledAt` getter: `null` when `isInstantSlot`, otherwise **slot start + 1 minute** on the selected day.
   +1 minute passes the strict `opening_time <` check for the first slot and stays inside hours for the last one.
3. Use the same instant for surge lookup (`time_slot_bottom_sheet.dart:145-154`) and for item availability
   (`checkout_screen.dart:1012-1034`).
4. `time_slot_section.dart:78`: the default label uses `isInstantSlot`, otherwise the slot range.
5. *Optional backend:* make the open check inclusive (`<=` / `>=`), so the +1 minute trick isn't needed.

**Files.** `checkout_controller.dart`, `checkout_screen.dart`, `time_slot_bottom_sheet.dart`, `time_slot_section.dart`.

**Verify.**
- Unit: `scheduledAt` for the first slot, a middle slot, the last slot, and slot 0 with the store closed now.
- Device: a scheduled-order store before its opening time, placing an order on the first slot, succeeds and is
  scheduled. The last slot of the day succeeds.

---

### P1: money leaks, client trust, wrong data

---

#### CC-07: delivery fee is priced on a client-sent distance

**Symptom.** The fee is `request.distance × per_km`, clamped to min/max. The app measures distance on a
**walking** route, which ignores one-way streets and is shorter than a motorbike's. When the API fails it falls back to
straight-line, which is shorter still. A modified request can send `distance=0` for a minimum-fee delivery anywhere in the zone.

**Evidence.**
- `waddy_back/app/Traits/PlaceNewOrder.php:942, 978-994`: uses `$request->distance` directly. `:264`
  stores it on the order.
- `lib/features/checkout/domain/repositories/checkout_repository.dart:51`: `&mode=WALK`.
- `waddy_back/app/Http/Controllers/Api/V1/ConfigController.php:407, 424`: accepts `DRIVE|WALK` and defaults to `WALK`.
- `checkout_controller.dart:363-366`: straight-line fallback.

**Fix.**
- **Phase 0, backend: floor, no pricing change.** Compute the great-circle distance between the store and
  `latitude/longitude`, then use `max(request.distance, straightLine)` for pricing and for `$order->distance`. This stops
  under-reporting below straight-line without changing any honest price, because a real route is never shorter than a straight
  line. Add `Helpers::haversineKm()` if nothing equivalent exists. Apply to non-parcel orders, before
  `getDeliveryCharge`, via `$request->merge(['distance' => $floored])`.
- **Phase 5, app: needs a pricing decision.** Switch `mode=WALK` to `DRIVE`. **This raises fees for every user**,
  and the per-km rates may have been tuned against walking distances. See open question Q1.

**Files.** `PlaceNewOrder.php`, `app/CentralLogics/helpers.php`; later `checkout_repository.dart`.

**Verify.** Backend test: `distance=0` for an address 3 km away is priced at about 3 km. An honest route distance
is priced unchanged.

---

#### CC-08: negative tips reduce the order total (backend)

**Evidence.**
- `waddy_back/app/Traits/PlaceNewOrder.php:54`: `'dm_tips' => 'nullable|numeric'`.
- `:292`: `dm_tips` is stored as-is.
- `:516`: `order_amount += dm_tips`.
- The app blocks negatives (`checkout_screen.dart:1082-1091`), but the API doesn't.

**Fix.** `'dm_tips' => 'nullable|numeric|min:0|max:<sane cap, e.g. 1000>'` on `place_order` and
`get-order-tax`.

**Verify.** Backend test: `dm_tips=-50` returns 403 with a validation error.

---

#### CC-09: tax is fetched from `build()`, raced, and not refreshed

**Symptom.**
- Opening checkout fires the tax request several times.
- Responses land in any order, and the last one wins.
- Removing a coupon, applying a second one, or toggling packaging leaves the old tax on screen, so the shown total differs from the charged total.

**Evidence.**
- `checkout_screen.dart:373-573`: `Future.delayed(50 ms, getOrderTax)` is scheduled on **every** rebuild while
  `isFirstTime` is true. `getDmTipMostTapped`, `getOfflineMethodList`, `getSurgePrice`, `getDistanceInKM`
  and the coupon and XP controllers all call `update()` in that window.
- `_calledOrderTax` goes true on the first coupon and never back, so removal and a second coupon are ignored.
- `checkout_controller.dart:643-656`: no sequencing on responses.
- Tax inputs on the server are the cart, coupon and packaging only (`PlaceNewOrder.php:1669-1760`).

**Fix.**
- **Interim, Phase 1 (optional):** a `_taxRequested` flag, set when the call is scheduled rather than when it
  returns. That stops the duplicates. It doesn't fix staleness.
- **Real fix, Phase 3 (with CC-15):**
  1. `CheckoutController.refreshTax()` is debounced by 300 ms and uses a request token like CC-03. Stale responses are ignored.
  2. It's called explicitly on: first load once the store is ready, coupon applied, coupon **removed**, packaging toggled.
  3. It is **not** called on address, tip, order type or prize changes, which the endpoint ignores.
  4. While a refresh is in flight, the tax row shows `calculating` and Place Order is busy.
  5. The payload comes from the shared builder (CC-15), so the tax quote and the order use the same inputs.

**Files.** `checkout_controller.dart`, `checkout_screen.dart`, `coupon_section.dart`, the packaging toggle.

**Verify.** Device, with the network inspector: opening checkout sends **one** `get-order-tax`. Apply, remove, then
re-apply a coupon: three more requests, and the total matches the order detail each time.

---

#### CC-10: extra packaging defaults to on

**Symptom.** A user who reaches checkout without opening the cart screen (the campaign "buy now" path)
pays the store's packaging fee without ever being asked.

**Evidence.**
- `lib/features/cart/controllers/cart_controller.dart:72`: `_needExtraPackage = true`.
- Only `cart_screen.dart:74-76` flips it to false.
- `checkout_screen.dart:1336-1341` sends it, and the server charges it when the store enables it (`PlaceNewOrder.php:305`).
- *Not an issue:* the admin module switch is already applied server-side (§3).

**Fix.**
1. Default `_needExtraPackage = false`, and delete the reset in `cart_screen.dart:74-76`.
2. Checkout shows the packaging line with its toggle, reusing `ExtraPackagingWidget`, whenever
   `store.extraPackagingStatus` is true. The choice is visible on every path.
3. Reset to false after a successful order (in `callback`).

**Files.** `cart_controller.dart`, `cart_screen.dart`, `checkout_screen.dart` or `bottom_section.dart`.

**Verify.** Device, via the campaign buy-now path: no packaging fee unless toggled. Via the cart: unchanged.

---

#### CC-11: the cart list request drops all normal headers

**Symptom.**
- Arabic users see **English** item names in the cart and cart bars.
- Cart images come back full size (no variants).
- No zone or lat/lng headers are sent.
- Guests send `Authorization: Bearer null`.

**Evidence.** `lib/features/cart/domain/repositories/cart_repository.dart:106-130`: builds a fresh header map with
`AppConstants.languages[0].languageCode` (`en`, `app_constants.dart:374`) and passes it as `headers:`, which
**replaces** `_mainHeaders` (`api_client.dart:137`).

**Fix.**

```dart
final Map<String, String> headers = {
  ...apiClient.getHeader(),
  if (ModuleHelper.getModule()?.id != null)
    AppConstants.moduleId: '${ModuleHelper.getModule()!.id}',
};
```

**Files.** `cart_repository.dart`.

**Verify.** Device in Arabic: cart item names are Arabic. Network inspector: `cart/list` carries
`X-localization: ar`, `zoneId` and `X-Image-Variants: 1`.

---

#### CC-12: idempotency never deduplicates, and the client "security" protects nothing

**Evidence.**
- `checkout_controller.dart:480`: a new UUID on every `placeOrder` call, so a retry after a lost response is a new order.
- `lib/helper/order_security_helper.dart:18`: the HMAC secret is shipped in the binary, and it's the backend's
  default too (`waddy_back/config/services.php:44`). The server only logs a mismatch (`OrderSecurityService.php:76-125`).
- `order_security_helper.dart:67-86`: the "fingerprint" is `sha256(os_version + localHostname)`. On iOS the host name is often the
  device name. It's low-entropy and not stable across OS updates.
- `order_security_helper.dart:90-107`: hard-coded English errors, and a 30 s client limiter that duplicates the server cooldown.

**Fix.**
1. **Key per checkout session.** Generate it in `CheckoutScreen.initCall`, store it on `CheckoutController`, and reuse it for
   every attempt on that screen. Rotate it only after a `200`. With CC-01, a retry after a timeout replays the original
   success, and a retry after a business error runs normally because the key was released.
2. Remove `generateOrderSignature` and its secret from the app. Server: stop logging signature failures and
   drop the `ORDER_HMAC_SECRET` default. Keep the columns nullable for old builds.
3. Replace `validateOrderIntegrity`'s cooldown with a plain in-flight guard (`if (_isLoading) return '';`) and let the
   server's translated 429 speak. That removes the untranslated strings.
4. Fingerprint: see Q4. Until decided, stop sending it.

**Files.** `order_security_helper.dart`, `checkout_controller.dart`, `checkout_screen.dart`,
`waddy_back/app/Services/OrderSecurityService.php`, `waddy_back/config/services.php`.

**Depends on.** **CC-01 deployed.** Shipping stable keys before it turns a retry after any business error into a 409.

**Verify.** Device: turn on airplane mode just after tapping Place Order (the request leaves, the response is lost), then retry.
You land on success with the **same** order id, and one order exists.

---

### P2: fragile or misleading

---

#### CC-13: the cart screen shows a stale cart

**Evidence.** `cart_screen.dart:61-63` only fetches when the list is empty. Prices, stock and removed items change
only after a mutation or an app restart, and the user learns about them from a 403 at place order.

**Fix.** Always call `getCartDataOnline()` in `initCall`. Render the cached list immediately, and let the response
replace it (`_applyServerCart` already protects in-flight quantity edits). Coalescing in `getCartDataOnline`
(300 ms) prevents a double fetch when the cart screen opens right after boot.

**Verify.** Device: change an item price in admin, then open the cart. The new price shows within one round trip.

---

#### CC-14: the Pay button shows the wrong number

**Evidence.** `cart_screen.dart:399` reads `'pay'.tr + subTotal`. Checkout then adds delivery, service fee, packaging and
tax, so the next screen contradicts it.

**Fix.** The label becomes `'checkout'.tr` (existing key) with no amount, or with `subTotal` shown under a clear `subtotal` label.
No money verb on a button that doesn't charge. **Coordinate** with `docs/cart_screen_restructure_plan.md`
Phase 4 (splitting the screen): if that hasn't landed, make the change inside the extracted bottom bar.

**Verify.** Visual check on device, in EN and AR.

---

#### CC-15: `CheckoutScreen.build()` does controller work

**Evidence.**
- Side effects scheduled or run from `build()`:
  - tax requests (`checkout_screen.dart:373-573`)
  - cashback lookup and snackbar on every total change (`:667-673`, `:1485-1496`)
  - payment auto-select after 600 ms (`:191-214`, `:675`)
  - controller writes `setPaymentMethod(0)` (`:652-657`) and `setTotalAmount` (`:658-665`)
  - address list recomputed and force-unwrapped (`:262-265`, `:1458`)
- The payload is built twice in two ~180-line copies (`:381-570` for tax, `:1161-1348` for the order). They already differ:
  - the tax copy has `isPrescriptionOrder`, and the order copy doesn't
  - the order copy has address, contact and schedule, and the tax copy doesn't
  - their `orderAmount` values differ

**Root cause.** The quote (every money number) and the order body have no owner, so the screen computes them
wherever it happens to need them.

**Fix: three extractions, no visual change.**
1. **`CheckoutQuote`**: an immutable value with `subTotal`, `itemDiscount`, `storeDiscount`, `coupon`, `referral`,
   `deliveryCharge` (−1 = calculating), `tax`, `taxIncluded`, `tips`, `serviceFee`, `packaging`, `total`,
   `minimumOrderBasis`. It's produced by a pure `CheckoutCalculationHelper.quote(...)` and exposed as a getter on the controller.
   `build()` only reads it.
2. **`PlaceOrderBodyBuilder.build(controller, cartList, {required bool forTax})`**: one function for both uses.
   `forTax` only omits fields the tax endpoint ignores.
3. **Lifecycle moves to `CheckoutController`:**
   - `initCheckout()` does what `initCall` does now, **plus** the single-payment auto-select, the prescription
     COD default and the first `refreshTax()`
   - the cashback check runs once, after the first complete quote, and on a debounced total change (not per rebuild)
   - `viewTotalPrice` becomes a getter derived from the quote and `isPartialPay`
4. The validation chain in `_orderPlaceButton` (`:976-1150`) moves to `CheckoutController.validateBeforePlace()`
   and returns the first failing message key. The widget shows it, and it can be unit-tested.

**Files.** `checkout_screen.dart` (shrinks substantially), `checkout_controller.dart`,
`checkout_calculation_helper.dart`, new `lib/features/checkout/domain/place_order_body_builder.dart`.

**Verify.**
- Unit: `validateBeforePlace` covers each rejection path, including CC-02/03/05/06.
- Unit: `PlaceOrderBodyBuilder` produces the same `toJson()` for both uses except the documented fields.
- Device regression: COD, wallet, partial, digital, offline, take-away, scheduled, coupon, prize.

**Depends on.** CC-02, CC-03, CC-05 and CC-06 landing first, so the extraction moves correct logic.

---

#### CC-16: offline payment is two separate requests, and can stick or duplicate

**Evidence.** `lib/features/payment/screens/offline_payment_screen.dart:198-245`:
- `changeLoadingStatus(true)` is never reset in this handler. `saveOfflineInfo` resets the flag itself, but if
  `placeOrder` fails (`orderId` is empty) nothing does, and the spinner stays.
- The order is placed first, then payment info is saved separately. If the second call fails, the order exists with no payment
  info, and a retry after 30 s places a **second** order.
- `isOfflinePay` success skips `callback`, so the coupon, previous data and tip preference aren't cleaned up (`checkout_controller.dart:503-507`).

**Fix.**
1. Reset loading in a `finally`.
2. Keep the placed `orderId` in screen state. A retry skips `placeOrder` and only calls `saveOfflineInfo` for that id.
   CC-12's session key already covers the placement itself.
3. On success, run the same cleanup as `callback` (extract `onOrderPlaced()` so both paths share it).
4. *Optional backend:* accept offline payment info inside `place_order`, making it one request.

**Verify.** Device: force `saveOfflineInfo` to fail (airplane mode after placement), then retry. One order, with the info attached.

---

#### CC-17: the success screen can stack two payment-failed dialogs

**Evidence.** `lib/features/checkout/screens/order_successful_screen.dart:384-399`: `Get.isDialogOpen` is checked when
the dialog is **scheduled**, not when it's shown 1 s later. `initState` triggers `trackOrder` and `getOrderDetails`,
which means two rebuilds inside that second.

**Fix.** A `bool _failedDialogShown` in state, set when scheduling and checked again inside the delayed callback. Move the
decision out of `build()` into a listener on the order controller result.

**Verify.** Device: digital payment, then cancel on the gateway. Exactly one dialog appears.

---

### P3: decisions, adjacent risks, hygiene

---

#### CC-18: digital payment deletes the cart before payment (decision)

**Evidence.** `waddy_back/app/Traits/PlaceNewOrder.php:581-583` deletes cart rows at placement for every
non-buy-now order. `checkout_controller.dart:557-559` clears the local cart before routing to the gateway.

**Effect.** An abandoned or failed payment leaves an unpaid order and an empty basket. `PaymentFailedDialog` offers switching to
COD, but a user who backs out has to rebuild the basket.

**Options.**
- **(a)** Keep as is: this is the upstream 6amMart behaviour.
- **(b)** For `digital_payment`, delete cart rows on payment success (the payment callback), not at placement. The app
  doesn't clear locally until the success route.

See Q3.

---

#### CC-19: loyalty points and purchase value use the client total

**Evidence.** `checkout_controller.dart:576-579` computes points from the client `amount`. The response already
returns `total_ammount` (`PlaceNewOrder.php:635`).

**Fix.** Pass `response.body['total_ammount']` through `callback` and use it for `saveEarningPoint` and the purchase
analytics value (`order_successful_screen.dart:111-120`). The copy already says "you **will** earn", which is right,
because points are awarded when the order is completed: `create_loyalty_point_transaction` runs inside
`OrderLogic::create_transaction` (`waddy_back/app/CentralLogics/order.php:40, 333`), which is called from the
order status update, not from placement.

---

#### CC-20: the distance API is an open proxy to a paid Google API (backend)

**Evidence.** `waddy_back/routes/api/v1/api.php:325`: `config/distance-api` sits in a group with no auth or
throttle, and forwards to Routes `computeRouteMatrix` on the platform key (`ConfigController.php:400-444`).

**Fix.** Add a `throttle:<n>,1` middleware on the route (CGNAT-aware, like the existing loose throttles at
`api.php:96`). Optionally cache by rounded origin/destination for 10 min.

---

#### CC-21: checkout hygiene

| Item | Evidence | Fix |
|---|---|---|
| `dispose()` calls `super.dispose()` first. Three text controllers, four focus nodes, the scroll controller and three tooltip controllers are never disposed | `checkout_screen.dart:216-222` | Dispose all of them, and call `super.dispose()` last |
| Surge price keeps the previous store's value when a fetch returns null | `checkout_controller.dart:658-664` | Set `_surgePrice = surgePriceModel` unconditionally (null clears it) |
| `initializeTimeSlot` computes the same list twice | `checkout_controller.dart:316-317` | Compute once, copy |
| Two slot validators with different code paths | `checkout_controller.dart:322` vs `:611` | Keep one, backed by the service |
| `double.parse(response.body.toString())` can throw on a malformed body | `checkout_repository.dart:64` | `double.tryParse(...) ?? 0` |
| `callback` is `void async`, fire-and-forget | `checkout_controller.dart:551` | `Future<void>`, awaited by `placeOrder` |

---

#### CC-22: logout and the server cart (decision + race)

**Evidence.** Two logout paths clear the cart differently:
- `lib/features/menu/widgets/menu_button_widget.dart:33-39` doesn't await `clearSharedData()` before `clearCartList()`.
- `lib/common/widgets/menu_drawer.dart:124-131` awaits it.

`clearCartList` deletes the **user's** server cart if the token is still present, or the guest cart if it's already gone.
Which one happens depends on timing and on the button used. *Needs confirmation on device.*

**Fix.** Decide the intended behaviour first (Q5). Then make both paths identical: either `await clearSharedData()` and
clear the local cart only, or explicitly `clearCartOnline()` **before** clearing the token.

---

## 5. Phases and sequencing

```
Phase 0  backend guardrails ── CC-01, CC-08, CC-07 (floor), CC-20
   │        user deploys
   ▼
Phase 1  app P0 fixes ───────── CC-02, CC-03, CC-04, CC-05 (small), CC-06
   │        independent of each other; any order
   ▼
Phase 2  cart data ──────────── CC-11, CC-13, CC-10, CC-14
   │
   ▼
Phase 3  checkout structure ─── CC-15 → CC-09, CC-05 (single source), CC-12 (needs CC-01 live)
   │
   ▼
Phase 4  payment tail ───────── CC-16, CC-17, CC-19
   │
   ▼
Phase 5  decisions/backlog ──── CC-07 (app mode), CC-18, CC-21, CC-22
```

| Phase | Why this position | Exit check |
|---|---|---|
| 0 | Backend fixes protect every client version, including builds already installed. CC-01 unblocks CC-12 | Backend feature tests green; user deploys |
| 1 | Smallest diffs with the largest money and conversion impact, and each stands alone | `flutter analyze` clean on touched files; new unit tests pass; the user device-tests the steps under each item |
| 2 | Cheap data fixes, done before the refactor so it moves correct behaviour | Same |
| 3 | CC-15 is the only large change. Doing it after Phases 1-2 means it moves logic that's already correct | Full payment-method regression on device |
| 4 | Depends on the `onOrderPlaced()` extraction from CC-15 | Offline and digital device runs |
| 5 | Needs owner decisions | Decisions recorded in §6 |

**Suggested commits:** one per ID, except CC-15, which may split into quote, body builder and lifecycle. Each commit message
names the ID.

---

## 6. Open questions (owner decisions)

| # | Question | Blocks | Default if unanswered |
|---|---|---|---|
| Q1 | Price delivery on a **driving** route, a straight line, or keep walking? Switching raises fees; were per-km rates tuned to walking distances? | CC-07 app side | Keep `WALK`; ship only the server floor |
| Q2 | Keep the 30 s cooldown once idempotency replay exists? | CC-01 scope | Keep, success-only |
| Q3 | For digital payment, keep the cart until payment succeeds? | CC-18 | Keep upstream behaviour |
| Q4 | Device fingerprint: drop it, or replace it with a random install ID stored in shared prefs? | CC-12 step 4 | Stop sending until decided |
| Q5 | Should logout delete the account's server cart? | CC-22 | Don't delete; clear local only |

---

## 7. Translation keys

| Key | Where | EN | AR |
|---|---|---|---|
| `order_in_progress` | backend `translate()` | Your order is already being placed | جاري تأكيد طلبك بالفعل |

That's the only new key. Everything else reuses keys that already exist in both `en.json` and `ar.json`:
`try_again` (CC-04), `delivery_fee_not_set_yet`, `calculating`, `checkout`, `store_is_closed`,
`minimum_order_amount_is`. Before adding a key, grep both files for it.

---

## 8. Test inventory

**App (`flutter test`):**

| Test | Covers |
|---|---|
| `test/cart_reward_state_test.dart` (+cases) | CC-02 minimum uses the pre-discount basis; free delivery uses `subTotal` |
| `test/unit/checkout_calculation_test.dart` (new) | CC-02 `minimumOrderBasis`; CC-03 `-1` sentinel for every zone type; CC-15 `quote()` totals |
| `test/unit/cart_quantity_sync_test.dart` (new) | CC-04 `settleQuantityWrites`; §2 serialized writes; rollback on failure |
| `test/unit/checkout_schedule_test.dart` (new) | CC-06 `isInstantSlot` / `scheduledAt` for the first, middle and last slot, and a closed store |
| `test/unit/checkout_validation_test.dart` (new, Phase 3) | CC-15 `validateBeforePlace` rejection paths |

`CheckoutCalculationHelper` reads `Get.find<SplashController>()` and `Get.find<XpController>()`. Tests register
lightweight fakes with `Get.put` in `setUp` and call `Get.reset()` in `tearDown`, or Phase 3 passes config in as
parameters, which is the better end state.

**Backend (`php artisan test --filter=PlaceOrderGuards`):** CC-01, CC-07 floor, CC-08. Order tests need seeded
store, zone, item and user fixtures. Don't rely on existing DB rows; `GetStoresFilterTest` skips on an empty DB, which is
not acceptable for money paths.

**Device script (user):** each item's **Verify** block, in EN and AR, on a throttled connection.

---

## Addendum (2026-09-16): structural plan

`docs/cart_checkout_structure_plan.md` (`CS-01`…`CS-12`) audits the *structure*
behind several findings here — the order total computed inside `build()`, the
order payload built twice, subtotal implemented twice, 2 of 25 builders scoped.

It does not re-decide anything in this document. Where both touch the same
lines, this document's acceptance criteria win. `CC-03`, `CC-04`, `CC-09`,
`CC-14` and `CC-15` get materially cheaper after `CS-01` and `CS-02`.

One finding there is new and money-adjacent: `CS-02` records that the tax quote
sends `subTotal` as `order_amount` while the placed order sends `total` — the
field the server prices tax from. It needs a backend read to size.
