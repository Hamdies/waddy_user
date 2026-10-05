# Price, offer badge, add button and stepper: one language app-wide

Prefix `PA-*`. Status: **All phases (PA-01..PA-12) built 2026-10-02 — backend deploy + device check pending. Ramadan stall deferred.**

The ask: every product surface in every module (food, grocery, supermarket,
specialty, pets) draws a discounted price, an "N% OFF" mark, the add button
and the quantity stepper **the same way**. Adding something that is already in
the cart turns into +1 on that line instead of an "already exists" error. The
stepper gets bigger and easier to hit.

## Master status

| ID | What | Where | Status |
|---|---|---|---|
| PA-01 | Backend `add_to_cart` merges a duplicate line instead of a 403, under a per-item lock (shared with `update_cart`), limit checked on the total | `waddy_back` `Api/V1/CartController::add_to_cart` | **built 10-02, deploy pending** |
| PA-02 | Backend duplicate key ignores add-ons, so "same size, other add-ons" is refused; compare as sorted id:qty pairs | same | **built 10-02, deploy pending** |
| PA-03 | Client simple-add path checks the cart first and bumps the line | `ItemController._commitAdd` + slow path | **built 10-02** |
| PA-04 | Food item sheet: "Add" on an identical line adds, never replaces (item details needed nothing) | `item_bottom_sheet.dart`, `ItemController` | **built 10-02** |
| PA-05 | `PriceTag` widget: mint-block price + coral-struck was-price | new `lib/common/widgets/price_tag.dart` | **built 10-02** |
| PA-06 | `OfferCollarBadge.forItem` + solid on-photo variant | `offer_collar_badge.dart` | **built 10-02** |
| PA-07 | `AddToCartButton`: the square `+` with the mint ledge, `+ n` when in cart under options | new, extracted from `StoreAddControl._add` | **built 10-02** |
| PA-08 | `QuantityStepper` grows: new default size, 40pt pill | `quantity_stepper.dart` | **built 10-02** |
| PA-09 | Migrate food surfaces | food menu, food home Order Again | **built 10-02** |
| PA-10 | Migrate mart / specialty / pets surfaces | `store_product_card.dart`, `shop_product_tile.dart`, `pet_usual_card.dart` | **built 10-02** |
| PA-11 | Migrate shared surfaces | search (`ItemWidget`), favourites, item details, item sheet, cart line, view-all, flash sale details | **built 10-02** |
| PA-12 | Retire the old shapes | `DiscountTag`, `_Badge`, `_Tag`, food `_discountRibbon`, `_disc`, `CartCountView` default child | **built 10-02** |

### Verify checklist (device)

- [ ] Same discounted item looks identical (price block, strike, collar) on: food menu, mart card, mart row, specialty row, pet card, search, favourites, item details, cart line.
- [ ] Tap `+` on a simple item that is already in the cart from a surface without a stepper (search, favourites, Order Again) → line goes 1→2, no snackbar, no error.
- [ ] Food item with options: add "Large", reopen sheet, add "Large" ×2 → one line at 3. Add "Large + extra cheese" → second line, not an error.
- [ ] Editing a cart line from the cart screen still **replaces** its quantity.
- [ ] Old build (pre-PA-03) against the deployed backend: double-tap `+` → quantity 2, no "Item already exists".
- [ ] `maximum_cart_quantity` enforced on the merged total (stock stays client-side, see PA-01 notes).
- [ ] Concurrent add: two simultaneous `add_to_cart` calls for the same item (curl ×2 with `&`) → **one** line, quantity 2. Repeat with no existing line, the both-miss-insert case.
- [ ] Add-on pairs: `{1:2, 2:1}` and `{1:1, 2:2}` stay two lines.
- [ ] Food photo stepper: a tap on the photo above the pill still opens the item; in Arabic the pill pins to the left (trailing) corner.
- [ ] Stepper: thumb-tap ten times fast on `+` → count 11, every tap counted; trash at 1 removes.
- [ ] Arabic: collar flips to the right, strike + mint block read correctly RTL, `% OFF` string translated.
- [ ] Text scale 1.3: stepper count does not run under the glyphs; price block wraps, does not clip.

---

## 1. What is on screen today

Collected from the 2026-10-02 screenshots and the code behind them. Same fact,
five drawings:

| Fact | Food menu | Mart card (`StoreProductCard`) | Mart/specialty row | Pets hub | Legacy (`ItemWidget`, `DiscountTag`) |
|---|---|---|---|---|---|
| Discounted price | **mint block**, red strike (the target, screenshot 10) | plain ink, grey strike | plain ink, grey strike | plain ink, grey strike | error-red strike |
| "% OFF" | coral sale-tag ribbon, only when it differs from the store promo | **dark-teal pill** top-start of photo | **mint `_Tag`** under the price | none | solid red rectangle |
| Add | **white circle** on the photo | **36 square, teal rim, mint ledge** (screenshot 12, the target) | same square | own button | 25pt grey-shadow circle |
| Stepper | compact, 82×34 painted (screenshot 13: "too small") | compact | compact | — | compact |

Store-level offers (store cards, top-10 rail) already use
[`OfferCollarBadge`](../lib/common/widgets/offer_collar_badge.dart) in the coral
`sale` tone (screenshot 11). That is the shape the user wants on **items** too.

### Where "already exists in cart" comes from

Not the app: there is no such string in `lib/`. It is the backend.
[`CartController::add_to_cart`](../../waddy_back/app/Http/Controllers/Api/V1/CartController.php)
finds a line with the same item + variation + produce preference and returns
`403 {code: cart_item, message: Item_already_exists}`, which the API client
shows as a snackbar.

The app reaches that branch whenever it calls `addToCartOnline` for an item
that already has a line:

1. **`itemDirectlyAddToCart` → `_addSimpleItemToCart` → `_commitAdd`** never
   checks the cart. Food menu and mart cards hide this because they swap the
   `+` for a stepper once the item is in. Every surface that keeps showing `+`
   (search results via `ItemWidget`, favourites, food home Order Again, view-all,
   flash sale) hits the 403 on the second tap.
2. **The food item sheet / item details** look up an existing identical line
   (`isExistInCartForBottomSheet`) and then call `updateCartOnline` with the
   sheet's quantity — **replacing** the line, so "2 in cart, add 2 more" ends at
   2, not 4.
3. **Backend key ignores add-ons.** Two lines of the same food item in the same
   size with different add-ons collide on `variation` alone and the second is
   refused.

`addLineToCart` (the mart/pets `ProductOptionsSheet`) already does it right:
existing line → `updateCartOnline(quantity + n)`. That is the template.

---

## 2. The design

### PA-05 `PriceTag`

```
  discounted:   ███148 LE███  1̶8̶5̶ ̶L̶E̶      mint block, coral strike
  regular:      148 LE                    plain ink
  per-unit:     ███638 LE███ / kg  7̶5̶0̶     unit sits between the two
```

- **Now price**: `waddyBold`, `WaddyColors.primary` ink. When discounted, on a
  `WaddyColors.mint` block, square corners, 5/2 padding — exactly the food menu
  today. Full mint is the brand's attention colour and the user has kept it on
  the saving chip before (full-mint chip, 2026-09-25); this is the same move.
- **Was price**: `waddyMedium`, `inkMid`, strike line in `WaddyColors.error`.
  Strike colour carries "this was more"; the number itself stays readable grey.
- **Sizes**: `compact` (cards, rows: 14/12), `regular` (food menu, search:
  15/14), `large` (item details, sheet: 20/15). Token-based per the 4pt scale.
- **Inputs**: `PriceTag.forItem(item, {variationPrice})` computes now/was with
  `PriceConverter.convertWithDiscount`, so every caller stops re-deriving it.
  Also a raw `PriceTag(now:, was:, unit:)` for the cart line, which has its own
  totals.
- `Wrap`, not `Row`, so a narrow card puts the strike on the next line instead
  of clipping (the mart card already does this).

### PA-06 Collar on items

- `OfferCollarBadge.forItem(item, {compact})` → coral `sale` tone, label
  `"N% OFF"`. Percent derived from the two real prices (food menu's rule), so a
  flat EGP discount never shows as a fake percentage; flat discounts read
  `"50 LE OFF"`.
- `onPhoto: true` variant: the pill is **solid** `coralSurface` (no fade to
  transparent) plus a 1px white rim. The fade is right on a white card and
  unreadable over a product photo.
- Placement: **top-start of the photo** on cards (replacing the dark-teal pill);
  **under the price** on rows (replacing the mint `_Tag`). One collar per item.
- Rank badge (`#3`) keeps the photo corner when both exist, as today; the collar
  then moves under the price.

### PA-07 `AddToCartButton`

Extracted unchanged in look from `StoreAddControl._add`, then sized up to match
the new stepper so the swap between them does not jump:

```
  resting          options item in cart (×2)
  ┌────┐           ┌────────┐
  │ +  │           │ +  2   │   filled teal, mint ink
  └────┘▁mint      └────────┘▁mint
  40×40            min 40 wide, grows
```

- 40×40 painted (was 36), 1.5 teal rim, `radiusDefault`, mint ledge
  `Offset(0, 2)`; 48×48 hit box always.
- `+ n` filled state for customizable items (the cart holds several option
  lines; the button reopens the sheet and says how many are already in).
- Owns the add/stepper swap: one widget, `AddToCartControl(item)`, which is
  today's `StoreAddControl` promoted to `lib/common/widgets/`. Every surface
  uses it; no surface draws its own `+` again.

### PA-08 Bigger stepper

Current compact: painted 82×34, glyph 18, count 15 — two 48×48 halves. It
meets the minimum hit size, but it *looks* small, and the eye aims at the
glyph, not the invisible box.

New sizes (compact stays only where space forces it):

| Size | Painted pill | Hit box | Glyph | Count | Used on |
|---|---|---|---|---|---|
| `regular` (**new default**) | 112×40 | 120×48, halves 60×48 | 22 | 18 | every card, row, photo corner, cart line |
| `large` | 148×48 | 148×52 | 24 | 20 | item sheet + item details bottom bars |
| `compact` | 82×34 | 96×48 | 18 | 15 | kept for one-off tight slots only; none planned |

- Pill gets the **mint ledge** the add button has, so add and stepper read as
  one control in two states (screenshot 12 → 13).
- Height 40 matches the new add button: tapping `+` grows the same-height
  control sideways, pinned by its trailing edge so the `+` under the thumb does
  not move.
- Count stays clamped at 1.3× text scale.
- Food menu photo is 110 wide; a 112 pill would overhang the photo by a hair.
  Pill pins to the photo's bottom edge and trailing corner, overlapping the
  photo by half its height — the plate stays visible above it. (Decision D1.)

### PA-01..04 Duplicate add → +n

**Backend (PA-01, PA-02)** — the real fix, because it also covers old builds
and double-tap races the client cannot see:

Built as (`CartController.php`):

- `add_to_cart` runs inside `withLineLock($is_guest, $user_id, $item_id)` —
  `Cache::lock("cart:{0|1}:{user}:{item}", 5)->block(3)`. `CACHE_DRIVER=database`,
  `cache_locks` from `2024_11_17_104649_create_cache_table`.
- Line found (same variation + preference + add-on pairs) →
  `$cart->increment('quantity', n)`; the line keeps its creation price.
  Not found → today's insert (`insertLine`). Either way: 200 + full cart, the
  same body as before, so old builds just see the merged line.
- `maximum_cart_quantity` checked on `existing + n`.
- `update_cart` takes the **same lock key** (by the line's `item_id`) and
  `refresh()`es the row inside it, so a stepper write and a `+` cannot
  interleave. `remove_cart_item` is not locked: a delete racing an increment
  can only lose that one increment, and the client re-syncs from the response.
- Lock timeout → `429 {errors:[{code: cart_busy, message: cart_busy_try_again}]}`.
  The API client turns an `errors` body into the snackbar text, so the user sees
  "Busy for a second, please try again", not a generic error; the optimistic row
  rolls back like any failed add. Key added to `en` + `ar` `messages.php`.
- Unknown item → 404 instead of the null-dereference 500 it was.
- **No server stock check.** `update_cart` has none either, and the client
  already ceilings each line on its *own* stock (`decideItemQuantity` reads the
  line's stock, which is the variation's stock for a variation line). A server
  check on `$item->stock` would be the wrong ceiling for variation items and
  would disagree with the client. Stock stays a client + order-placement rule.

Not a unique index: the line identity includes `variation` and add-ons stored
as JSON text, which MySQL cannot index as a whole without a generated hash
column. The lock gets the same guarantee without a migration.

**Add-on key (PA-02).** Compare add-ons as **pairs**: zip `add_on_ids` with
`add_on_qtys` into `id:qty`, sort, compare. Sorting the two arrays separately
would make `[(1,2),(2,1)]` equal `[(1,1),(2,2)]`. Different add-ons → new line.

**Price.** `add_to_cart` stores `$request->price` today, and still will. The
merge does not overwrite it. A full server-side recompute (variation + add-ons +
discount) is out of scope: the order is repriced in `PlaceNewOrder` anyway
(order_amount is overwritten server-side), so a client price on a cart line is a
wrong *quote*, never a wrong *charge*. That belongs to the `CC-*` plan.

**Client (PA-03)** — so the bump is instant, not a round-trip:

- `_commitAdd` (and the slow path's simple branch) first calls
  `isExistInCart(item.id, '', false, null)`. Found → `setQuantity(true, index,
  stock, limit)`, the stepper's own optimistic path. Not found → today's add.
- Cross-module / cross-store dialogs stay first: a line that exists is by
  definition the same store and module, so it never reaches them.
- Rollback is already there: `setQuantity` refuses at a stock or limit ceiling
  locally (`decideItemQuantity`), and `_syncQuantity` restores
  `_acceptedQuantity` if the server rejects the write. No new rollback code.

**As built (PA-03, PA-04), 2026-10-02:**

- `ItemController._bumpExistingLine(item)`: called by `_commitAdd` after the
  out-of-stock check, and by the slow path's simple branch (not campaigns).
  Matches only a **plain** line (no variation, add-ons, preference or food
  option selected) — `isExistInCart` ignores add-ons and food options, so it
  would have grown a "with extra cheese" line from a bare `+`. Then
  `CartController.setQuantity(true, …)`.
- `getItemDetails(accumulate:)` → `_accumulate`. The sheet passes
  `accumulate: !isCampaign`; it only takes effect when `cart == null`. While on,
  `setExistInCart` still finds `_cartIndex` but no longer copies that line's
  quantity and add-ons into the sheet, so the sheet opens at 1 with nothing
  pre-ticked.
- `ItemController.identicalLineIndex(item, addOnIds:, addOnQtys:)`: same food
  selections (or the old-variation `_cartIndex`), same preference, same add-on
  `id:qty` pairs. The sheet's Add: found → `updateCartOnline(onlineCart.copyWith(
  cartId, quantity: line + sheet))`; not found → `addToCartOnline`.
- `OnlineCart.copyWith({cartId, quantity})` added.
- Button label: "Update in cart" only when `widget.cart != null` (editing).
- **Item details unchanged:** once the item is in the cart its bottom bar *is*
  a live stepper on that line (`isInCart` branch), so there is no "Add" that
  could replace a quantity.

**Client (PA-04)** — the sheet:

- Opened from a `+` (`widget.cart == null`): an identical existing line gets
  `existing.quantity + sheetQuantity`. Button label stays "Add to cart".
- Opened to **edit** a cart line (`widget.cart != null`, from the cart screen):
  keeps replace semantics; label "Update cart".
- Checked every caller (2026-10-02): `widget.cart` is set only by
  `cart_item_widget.dart:91` (edit a line). `food_home_screen.dart:244`,
  `cart_screen.dart:1188` (suggestions) and the two `item_controller.dart`
  opens (:1102, :1607) pass no `cart`. So `cart == null` really does mean
  "adding".
- No snackbar for either. The `+ n` badge / stepper and the cart bar already
  change in front of the user (snackbar noise plan).

### As built, Phases 2–3 (2026-10-02)

Primitives (`lib/common/widgets/`):

- `price_tag.dart` — `ItemPrice.of(item, {base})` / `ItemPrice.from(now, was,
  flat)`: now, was, and the off label derived from the two prices ("15% OFF",
  or "50 LE OFF" for a flat discount). `PriceTag(price, unit, size, dimmed,
  oneLine)`; `oneLine` never wraps (the was-price ellipsizes) for fixed-extent
  grids, and `PriceTag.lineHeight(size)` feeds their height maths.
- `offer_collar_badge.dart` — `forItem(item)` / `forPrice(price)`, and
  `onPhoto` (solid pill + white rim, no fade).
- `add_to_cart_control.dart` — `AddToCartControl(item, inset, onOptions,
  expands)` is `StoreAddControl` promoted, square now 40. Fills its box,
  paints at the trailing end; `hitWidth = 120`. In a bounded slot narrower than
  the stepper it overflows toward the start (OverflowBox); in an unbounded row
  slot it takes its own width. **`expands: false`** never becomes the stepper:
  it fills and counts ("+ 2", "+ 4"), each tap adds one — for cards too narrow
  for 112pt beside a name. `AddToCartSquare` is the bare square for a model
  too thin for the control (the food home rail's `Items`).
- `quantity_stepper.dart` — `regular` (default) 120×48 hit, 112×40 pill, glyph
  22, count 18; `large` 148×52 / 48 pill; mint ledge on every size. The `+`
  glyph sits 20pt in from the painted edge on both square and pill, so it does
  not move under the thumb.

Surfaces:

| Surface | Price | Collar | Add |
|---|---|---|---|
| Food menu row | `PriceTag.regular` | compact collar on **every** discounted row (`_kCollarOnlyWhenNews = false` in `food_store_screen.dart` is the D2 switch) | `AddToCartControl` straddling the photo's bottom edge; `_kControlOverhang = 24` reserves the half below (D1) |
| Food store Order Again card | `PriceTag` | — | `AddToCartControl(expands: false)` replaced the "Reorder" pill |
| Food home Order Again card | `PriceTag` | collar on photo | `AddToCartSquare` (opens the sheet), counts cart quantity |
| Mart card | `PriceTag.regular` | collar on photo top-start; under the price when a `#rank` holds the corner | control, 120 box |
| Mart row / compact row | `PriceTag` | collar on the photo's top corner (a line under the price would make the aisle grid ragged) | control |
| Mart menu row | `PriceTag.regular` | collar under the price | control |
| Aisle tile (`ShopProductTile`) | `PriceTag.regular, oneLine` | collar on photo | control (own `_AddControl` deleted) |
| Supermarket special offers (`StoreSpecialOfferView`) | `PriceTag oneLine` | collar on photo | control replaced the full-width "ADD" |
| Pets hub usual card | `PriceTag` | collar under price | unchanged — its actions are labelled "Buy again" CTAs, not a product `+` |
| Specialty / pet store pages | inherit from the mart widgets | | |

Device pass 1 fixes (2026-10-02, from screenshots):

- **`+` sat mid-photo.** `Pressable(minSize:)` wraps its child in a `Center`,
  which overrode the trailing alignment. `AddToCartSquare` now applies the 48pt
  minimum itself and pins the square to the trailing corner. Never use
  `Pressable.minSize` for a control that must sit at an edge.
- **Cards too tall and uneven.** In a 136pt card the price `Wrap` broke onto
  three lines ("638 LE" / "/ Kilogram" / "750 LE").
  - `PriceTag(stacked: true)` on `StoreProductCard`: price and unit on one
    line, was-price on a second line that is reserved even when there is no
    sale, so every card in a rail is the same height.
  - Units shortened everywhere: `PriceTag.shortUnit` ("Kilogram" → "kg").
  - `StoreMenuRow`: collar moved onto the photo, price `oneLine` — a collar line
    under the price made discounted rows taller than the rest.
  - Ranked cards: collar goes top-end when `#rank` holds top-start, never under
    the price.
  - `_blurbOf` drops a description that only repeats the name ("Jumbo Shrimp
    1kg / Jumbo Shrimp 1kg").

Device pass 2 (2026-10-02): the pass-1 "stacked" price and reserved name/second
lines made rail cards tall and mostly empty. Reversed: `StoreProductCard` has no
reserved lines (name natural, second line only when it has text, price + was-price
in a normal wrap); the four rails (pet, specialty, best sellers, aisles) wrap
their `Row` in `IntrinsicHeight` with `crossAxisAlignment.stretch`, and the card's
`Column` is `spaceBetween`, so cards still match in height and the price sits at
the foot. `PriceTag(stacked:)` is still used by the view-all grid and item details.

Device pass 2b: on narrow photo cards (`StoreProductCard`, `ShopProductTile`,
view-all grid) the control is `AddToCartControl(expands: false)` in a 72×48 box —
the square counts ("+ 2") instead of growing a 112pt stepper over a ~124pt photo.
Rows, the food menu and the sheets keep the full stepper. Trade-off: no minus on
those cards; quantity goes down from the cart.

Device pass 2c: `AddToCartControl.expands` now defaults to **false** — every
product list/card/row shows the counting square ("+ 5") and never the − n + pill
(user preference). The food menu slot is 72 wide (was the full photo width, which
would have made the photo's bottom strip a tap-to-add). Steppers remain only where
quantity is edited: cart line, item sheet, item details.

Device pass 2d (reverses 2b/2c): the − n + pill is the control **everywhere**
(`AddToCartControl.expands` default true again, slots back to the full 120 hit
width). Only exception: the food-store Order Again card uses `compact: true`
(82×34) and is 264 wide, since the regular pill left its name no room. The food
*home* Order Again card still uses `AddToCartSquare` ("+ n", opens the sheet) —
its `Items` model cannot tell a simple dish from one with options.

Device pass 3: card is 164 wide; sale collar lives in the card body above the
price (not on the photo). The equal-height stretch from pass 2 is **removed**
(rails are `Row(crossAxisAlignment.start)` again, no `IntrinsicHeight`; the aisle
rail keeps it only when it has a trailing tile): stretching to the one tall sale
card left dead space above every other card's price. Cards differ in height by
the collar line instead.

Device pass 4: `StoreProductCard` rows are now identical on every card — name
(two lines' height), a 24pt meta row (size left, sale collar right), a one-line
`PriceTag(oneLine)`; so all cards in a rail match without blank filler or
stretching. Bare unit words in the size line go through `PriceTag.shortUnit`.

Deferred: `store_ramadan_stall_view.dart` — seasonal (behind
`showRamadanDecorations`, off), themed fixed-height cards where a 48pt control
would overflow. Migrate with its own layout pass before next Ramadan.

Deleted: `StoreAddControl`, `_Price`, `_PriceLine`, `_Tag` (store card),
`_AddControl` (aisle tile), food menu `_discountRibbon`, `_addControl`,
`_addButton`, `_stepperPill`, `_disc`, `_kStepperHeight`. Pre-edit copies in the
session scratchpad.

### As built, Phase 4 (2026-10-02)

| Surface | File | Change |
|---|---|---|
| Search items | `common/widgets/item_widget.dart` | `PriceTag.forItem(oneLine)`; collar on the photo's bottom-start (the heart holds top-start); `AddToCartControl` replaced `CartCountView`; the corner ribbon (`CornerDiscountTag`) no longer drawn for items. Store branch unchanged. |
| Legacy cards via `CartCountView` | `common/widgets/cart_count_view.dart` | With no custom `child`, it now *is* `AddToCartControl`. Callers that pass a child keep their visual. |
| View-all grid | `features/item/screens/item_view_all_screen.dart` | `PriceTag(stacked)` on the starting price; collar on photo; control at the photo's bottom-end. |
| Favourites | `features/favourite/widgets/favourite_item_card.dart` | `PriceTag`; collar on photo; control replaced the teal circle (which only opened the item page). |
| Flash sale details | `features/flash_sale/widgets/flash_product_card_widget.dart` | `PriceTag(oneLine)`; collar on photo. No add button there before; none added. |
| Item details | `features/item/widgets/item_title_view_widget.dart` | `PriceTag(large, stacked)` + collar replaced the tinted chip and the red was-price. |
| Food item sheet | `common/widgets/item_bottom_sheet.dart` | Header: `PriceTag(large)` for a single price (a range keeps its text); collar on the photo replaced `DiscountTag`; running-total strike now red. |
| Options sheet (mart/pets/specialty) | `features/store/widgets/product_options_sheet.dart` | Price left the grey headline text: `PriceTag(regular)` + collar under the name; the description line shows only when it says more than the name. |
| Cart line | `features/cart/widgets/cart_item_widget.dart` | `PriceTag(ItemPrice.from(total, original))` replaced the struck price + `CheckoutSavingChip` pair (same mint block, same order as every card). Stepper is the regular size by default. |

**PA-12, done 2026-10-02.** Every `DiscountTag` call moved to two new helpers
on `OfferCollarBadge`: `storeCorner(store, {inset, atBottom})` (best perk, money
off over free delivery) for store covers/logos — `item_widget` store branch
(bottom corner: the heart holds top-start), `store_card_with_distance`,
`best_store_nearby_view` — and `itemCorner(item, {base})` for the not-live
shop/pharmacy cards (`item_card`, `medicine_item_card`,
`review_item_card_widget`, `flash_sale_card_widget`). `forDiscount` /
`forFreeDelivery` take `onPhoto`. Deleted with zero callers left:
`common/widgets/discount_tag.dart` and the whole `common/widgets/corner_banner/`
folder (`CornerDiscountTag`, `CornerBanner`, `PositionedCornerBanner`); copies in
the session scratchpad `deleted_pa12/`.

---

## 3. Surfaces in scope

Live, by module. "Shared" widgets are reached from every module.

| Surface | File | Price | Collar | Add/stepper |
|---|---|---|---|---|
| Food menu row | `features/store/screens/food_store/food_store_menu.dart` | already target → `PriceTag` | ribbon → collar | white disc → `AddToCartControl` |
| Food home Order Again | `features/home/screens/modules/food_home_screen.dart` ~640 | `PriceTag` | collar on photo | dark square → control |
| Mart card / row / menu row / compact row | `features/store/widgets/store_product_card.dart` | `_PriceLine` → `PriceTag` | `_Badge`, `_Tag` → collar | `StoreAddControl` → shared control |
| Aisle tile | `features/store/widgets/shop_product_tile.dart` | `PriceTag` | `_Tag` → collar | own `_AddControl` → shared |
| Category items page | `store_category_items_screen.dart` (via `ShopProductTile`) | inherits | inherits | inherits |
| Grocery legacy store page | `store_special_offer_view.dart`, `store_ramadan_stall_view.dart` | `PriceTag` | collar | control |
| Specialty store | `specialty_store_screen.dart` (via `StoreCompactRow`, `StoreMenuRow`) | inherits | inherits | inherits |
| Pet store | `pet_store_screen.dart` (via `StoreProductCard`, `StoreMenuRow`) | inherits | inherits | inherits |
| Pets hub "usual" | `features/pets/widgets/pet_usual_card.dart` | `PriceTag` | collar | control |
| Search items | `common/widgets/item_widget.dart` (via `ItemsView`) | `PriceTag` | `DiscountTag` → collar | `CartCountView` → control |
| Favourites | `features/favourite/widgets/favourite_item_card.dart` | `PriceTag` | collar | control |
| Item view-all | `features/item/screens/item_view_all_screen.dart` | `PriceTag` | collar | control |
| Flash sale details | `features/flash_sale/widgets/flash_product_card_widget.dart` | `PriceTag` | collar | control |
| Item details | `item_title_view_widget.dart`, `item_details_screen.dart` | `PriceTag.large` | collar | stepper `large` |
| Food item sheet | `common/widgets/item_bottom_sheet.dart` | `PriceTag.large` | collar | stepper `large` |
| Product options sheet | `features/store/widgets/product_options_sheet.dart` | `PriceTag.large` | collar | stepper `large` |
| Cart line | `features/cart/widgets/cart_item_widget.dart` | `PriceTag(now, was)` | none (cart shows savings in totals) | stepper `regular` |

**Not live** (shop / pharmacy home modules, not in the mobile module set):
`special_offer_view`, `flash_sale_view_widget`, `item_that_you_love_view`,
`most_popular_item_view` → `ItemCard`, `review_item_card_widget`,
`medicine_item_card`, `flash_sale_card_widget` (no callers). They get the new
look for free where they route through `ItemCard` / `CartCountView`; no bespoke
work. Flag for deletion with the mobile-only cleanup.

**Out of scope, seen in the screenshots** (data, not UI): subtitle repeating the
name ("Jumbo Shrimp 1kg / Jumbo Shrimp 1kg"), "/ Kilogram" on a steel bowl and
on yogurt. Same admin unit cleanup already noted in the mart critique.

---

## 4. Order of work

| Phase | IDs | Notes |
|---|---|---|
| 0 | PA-01, PA-02 | Backend first; independent of the app. User deploys. |
| 1 | PA-03, PA-04 | Client merge. Safe before or after the deploy. |
| 2 | PA-05..PA-08 | Primitives only, no screen changes yet; analyze clean. |
| 3 | PA-09, PA-10 | Food + mart/specialty/pets — the screenshots. |
| 4 | PA-11 | Shared surfaces. |
| 5 | PA-12 | Delete old shapes once grep shows zero callers (keep scratch copies — dead-code check rule). |

New `.tr` keys (`n_off` for the flat-amount label if `off` alone does not
read right in Arabic, `update_cart`) go into **both** `en.json` and `ar.json`.

## 5. Decisions needed

- **D1 — food photo stepper.** Recommended: the 112×40 pill overlaps the bottom
  edge of the 110 photo (half on, half below). Alternative: stepper leaves the
  photo and sits under the price.
- **D2 — food menu "store-wide promo" rule.** Today a row's ribbon is hidden
  when it only repeats the store's own header promotion (a 25%-off store would
  otherwise show "25% OFF" on every row). The ask is "every discounted item".
  Recommended: follow the ask — collar on every discounted item, everywhere,
  no exceptions — since the per-row strike + mint block already repeats it and
  consistency is the point of this plan. **Fallback if it reads as noise on
  device:** keep the mint block + strike on every row and bring back today's
  rule for the collar only (show it when the item's discount differs from the
  store promo). One flag in `food_store_menu.dart`, no other surface affected.
- **D3 — sheet merge.** Recommended as in PA-04: "Add" from a `+` accumulates,
  "Update" from the cart replaces.
