# Physical scratch card in the bag — plan

Every order bag carries a printed scratch card. The customer scratches it by hand and reads the result
right there on the paper:

```
   ┌──────────── under the foil ────────────┐
   │   Waddy! 🎉  You won FREE DELIVERY       │
   │   code:  A52-523T                        │
   │   use it before 31 Oct                   │
   └──────────────────────────────────────────┘
```

On their next order they type the code into the **existing promo-code field** in the cart or checkout, like
any coupon. There's no claim screen, no scanner and no digital re-scratch. The paper is the whole experience,
and the app just honours it.

Status: **built 2026-09-28: backend + admin + app. Backend needs deploy + `php artisan migrate`; on-device checks open. The app has not launched** (planned 2026-09-27; third version: digital card → claim-screen card → code typed
at checkout, as the user proposed). Prefix `SC-*`.

## Master status

| ID | Item | Severity | Status | Phase |
|---|---|---|---|---|
| SC-01 | `scratch_codes` table + batch generation with outcomes assigned + printer CSV | P0 | landed, deploy | 1 |
| SC-02 | Per-batch on/off + use-before date (**set at generation, extend-only**: see §5a note) | P0 | landed, deploy | 1 |
| SC-03 | Coupon apply + order placement understand card codes: first use binds the code to that customer | P0 | landed, deploy | 1 |
| SC-04 | Wrong-code lockout: 5 per user / 60 per IP per hour (§2) | P1 | landed, deploy | 1 |
| SC-05 | Code released if the order it was used on is cancelled / fails / refunded | P1 | landed, deploy | 1 |
| SC-06 | App: card-code-specific messages (already used / expired / not active / cap / lockout) | P0 | landed | 2 |
| SC-07 | App: "Waddy! Your card's free delivery is on" moment when a card code applies | P1 | landed | 2 |
| SC-08 | Logged-out user types a code | P1 | not needed: guests never see the promo field (cart and checkout both hide it) | 2 |
| SC-09 | Admin: batches, mix, activation, per-batch stats | P0 | landed, deploy | 1 |
| SC-10 | Measurement per batch/zone: redemption rate, reorder | P1 | open (batch counts are on the admin page; reorder rate not built) | 3 |
| SC-11 | Old digital `ScratchCardDialog`: unrelated, leave or delete | P3 | open | — |
| SC-12 | Launch schedule: stages advance when a box runs out, win rate 100 % → 65 % → 50 % → steady mix (§5a) | P0 | ops (the admin creates one batch per stage) | 1 |
| SC-13 | Generator writes losing cards into the printer CSV too, shuffled with the winners | P0 | landed, deploy | 1 |
| SC-14 | Program on/off: off = no new batches/cards, card UI hidden; cards already out honoured to use-before (§5b) | P0 | landed, deploy | 1 |
| SC-16 | App teaser for the card in the bag: cart, checkout, confirmation, order details (§3a) | P1 | landed, deploy (needs `scratch_cards` in config) | 2 |
| SC-15 | Card custody: `card_no` stored + `scratch_ranges` log, per-account cap in the apply steps, per-range report vs zone rate (§5c) | P0 | landed, deploy | 1 |

### What landed (2026-09-28)

- **Backend** (`waddy_back`): migration `2026_09_28_000001_create_scratch_card_tables.php`; models `ScratchBatch`,
  `ScratchCode`, `ScratchRange`; `App\Services\ScratchCardService` (generation, bind + cap, lockout, use/release,
  custody report); `Api\V1\CouponController::apply` falls back to card codes and returns worded card errors;
  `OrderObserver` marks a card used on create and releases it on `canceled`/`failed`/`refunded`.
- **Admin**: Users → Customers → **Scratch cards** (`admin/users/customer/scratch-cards`): program switch and cap,
  new batch with a live win-rate readout, batch list, and per batch: printer CSV, on/off, extend date, hand-out log and
  the custody report. Controller `Admin\ScratchCardController`, views `admin-views/scratch-cards/*`.
- **App**: `CouponApplyResult` carries the server's card error code; the repository URL-encodes the code (it
  didn't before) and stops swallowing card refusals; `CouponModel.scratchCard`; the promo card words each refusal and
  shows the card-applied title. 8 keys in `en.json` + `ar.json`.

**Where the build differs from the text below:**
- **Use-before is set when the batch is generated, not when the box is opened.** The date is printed on the card,
  so the server date has to match the paper from the start. Admin can extend it later (coupons already minted get the
  new date too) but can't shorten it. To avoid a box sitting around eating its window, generate each stage close to
  when it's needed, which §5a already recommends.
- **The IP lockout is 60 wrong per hour, not 5.** Egyptian mobile carriers put many customers behind one IP
  (CGNAT), so a per-IP 5 would lock out strangers. The per-user limit is the real one (5), and each account needs a phone OTP.
- **Release on cancel** raises the minted coupon's `limit` by one (the coupon counts every order carrying its code),
  instead of forgetting the order.
- **The custody rate uses "typed in"** (the code was bound to someone), not "used on an order". A pocketed card is
  never typed in; a customer who hasn't ordered yet still counts as reached.
- ~~No app config flag for the program switch~~ **Superseded 2026-09-28:** the teaser (SC-16) is a card surface, so the
  config endpoint now sends `scratch_cards: {active, zone_ids}` and the app hides every teaser when it's off.

## Verify on device

- [ ] Type a winning card code in the cart promo field → free delivery / discount applies, carries to checkout
- [ ] Lowercase, with a dash or spaces → still accepted
- [ ] Place the order → the same code on another account says "already used"
- [ ] Same code, same account, a second order → "already used"
- [ ] Apply the code, then remove it without ordering → it still works later (still yours)
- [ ] Cancel the order that used it → the code works again
- [ ] Code from an inactive batch / past its date → the right message
- [ ] Program switch off → admin can't generate or activate a batch; any card hint in the app is gone
- [ ] Program switch off → a card already handed out (inside its use-before) still applies
- [ ] One batch switched off → its codes refused, other batches still work
- [ ] 5 wrong codes within an hour → the 6th attempt says "too many tries, wait a bit" (even a correct code)
- [ ] Account over the card cap → a valid card code is refused with the cap message, and still works on another account
- [ ] Re-applying a code already bound to you doesn't count against the cap
- [ ] Admin: log a range → report shows its winners, redeemed count and distinct accounts vs the zone rate
- [ ] Arabic: messages translated
- [ ] A batch on → badge/sticker on store pages, cart, confirmation, live order details, delivered order details (7 days)
- [ ] Program off, or no batch on → no teaser on any of the four
- [ ] Batch limited to zone A, address in zone B → no teaser
- [ ] Parcel order → no teaser on confirmation or order details
- [ ] Food store: badge on the cover's bottom-right, clear of the rating card, scrolls away; no product's ADD is ever covered
- [ ] Grocery store: sticker in the app bar before the info button
- [ ] Cart: sticker at the end of the top app bar; checkout screen shows nothing
- [ ] Confirmation: bar under the XP chip, same style; order details: bar in the card list (live, and 7 days after delivery)
- [ ] Tap any badge or sticker → sheet opens; "Got it" closes it
- [ ] Reduce motion on → card is still, no flipping
- [ ] Arabic: cover badge on the bottom-left (logo moves right), cart sticker at the app bar's left end, sheet reads right to left
- [ ] Admin: create a 20-card batch with 13 winners → CSV has 20 rows, exactly 13 with codes, winners scattered (not first 13)
- [ ] Admin: program switch off → "Create batch" disabled, "Switch batch on" refused
- [ ] Admin: extend the date → a card coupon already applied shows the new expiry in the coupon list

---

## 1. Why a card code can't just be a normal coupon

The existing coupon system can't do "one code, one use, ever":
- `coupons.limit` is **per user**. `CouponLogic::is_valide` (`app/CentralLogics/coupon.php`) counts *this user's*
  orders with the code. Nothing caps total uses.
- `CouponController::list` sends every active coupon with `customer_id: ["all"]` to **every** user.

So both obvious shortcuts break:
| Shortcut | What goes wrong |
|---|---|
| One shared code on every card | Someone posts it on Facebook, and every account in Egypt uses it once. Unlimited cost. |
| Thousands of unique codes as normal coupons | All of them show up in every user's coupon list, each usable once by everyone. |

That's the reason for the separate table below. It's small, and it keeps card codes out of the coupon list entirely.

## 2. Server (waddy_back)

```
scratch_batches  id, name, quantity, outcome_mix(json), zone_id NULL, active(bool),
                 use_before(date), timestamps
scratch_codes    id, batch_id, card_no, code UNIQUE, outcome_type(free_delivery|discount),
                 value, min_order, max_discount,
                 user_id NULL, bound_at NULL, order_id NULL, used_at NULL,
                 coupon_id NULL, timestamps          UNIQUE(batch_id, card_no)
scratch_ranges   id, batch_id, from_no, to_no, holder_type(rider|store), holder_id NULL,
                 holder_name, zone_id, handed_at, notes, timestamps
```

`card_no` is stored on each winning code, so "which winners were in #0001–0100" is a query, not a CSV lookup.
`scratch_ranges` is the hand-out log from §5c. Losing cards still have no rows: the report only needs the winners in a
range, and it gets the range size from `to_no − from_no + 1`.

Only winning cards get a row and a code. Losing cards are printed with a message and no code.

**Generation (SC-01/09/13):** admin picks the quantity and prize mix → random codes → a CSV
(`card_no, batch_label, result, code, text_ar, text_en, use_before`) for the printer. **The CSV holds every card,
losers included, already shuffled.** Presses print in file order, so a CSV of 325 winners followed by 175 losers
would put all the winners in the first boxes. The win rate is **exact**, not rolled per card: 500 cards at 65 %
means exactly 325 winners. The customer experiences it as random, and you know the maximum cost before printing. Codes must be **random, never sequential**:
`A52523T` next to `A52524T` means anyone who wins can guess the neighbours. **8 characters** from an alphabet with no
`0 O 1 I L`, case-insensitive.

**Applying a card code (SC-03)** fits into the existing flow instead of beside it:
1. `CouponController::apply` gets `code`. It looks in `coupons` first, as today. If there's no match, it normalises
   the code (uppercase, strip spaces and dashes) and looks in `scratch_codes`.
2. Checks (the program switch is deliberately NOT one of them: cards already out are honoured, §5b): batch active, today ≤ `use_before`, and `user_id` null **or** equal to
   this user. If it's already bound to this user, return the same coupon and stop here (re-applying never counts
   against the cap).
3. **Per-account cap (SC-15):** count this user's `scratch_codes` with `bound_at` in the last 30 days. At the cap,
   refuse with `card_limit` and **don't bind**. The code stays free for whoever holds the card legitimately.
4. On the first valid apply, with a row lock: set `user_id` and mint a personal coupon for that customer, with the
   same shape as `XpService::issueDiscountCoupon` (`customer_id=[uid]`, `limit=1`, `expire_date=use_before`,
   `coupon_type` `free_delivery` or default, `module_id` null = any module). Its `code` is **the card's code**,
   so the customer sees the same code they typed. Return that coupon as the apply result.
5. From then on it's an ordinary personal coupon. `PlaceNewOrder` validates and charges it through the
   existing path (`free_delivery` at `PlaceNewOrder.php:455`), with no special case. After it's used, `limit=1`
   stops a second use by the same person, and `customer_id` stops everyone else.

   Binding on apply (not on order) means that whoever types it first owns it, even if they don't order right
   away. For a physical card that's the right rule: it's theirs.
6. **Cancel/refund (SC-05):** `OrderObserver` already reacts to `refunded`. Add `canceled` there too for card codes,
   so the minted coupon becomes usable again (limit counts orders, so a cancelled order may already stop counting,
   but that needs checking when building).

**Guessing (SC-04):** the promo field now answers "is this a real card code?", so count wrong codes per user and IP.
**5 wrong within a rolling hour → the 6th attempt is refused for an hour**, whether or not it's correct. A normal user mistypes once or twice.

The numbers: 31⁷ ≈ 27 billion possible 7-character codes, 31⁸ ≈ 850 billion for 8. The live pool is every switched-on
batch together, not one batch. With ~1,000 live codes and 7 characters, an unthrottled script firing 100 million guesses
would find about 3–5 real ones. With 8 characters, roughly 0.1. So guessing is a small risk, not zero, and the fix is
Laravel's `throttle` middleware on the apply route (about one line). That's P1: cheap enough to ship with W1, but not a launch blocker.

## 3. App (waddi_user)

The field already exists (the cart and checkout promo card, carried across since 2026-09-25). The app work is
small:
- **Messages (SC-06):** new error codes from `apply` → their own `.tr` lines in `en.json` **and** `ar.json`:
  "This card was already used", "This card's offer ended on 31 Oct", "This card isn't active yet". A generic
  "invalid coupon" makes a real card feel fake.
- **The moment (SC-07):** when the apply response says the code came from a card, the promo card shows
  "Waddy! Your card's free delivery is on 🎉" with a short celebration instead of the plain applied state.
  This is the one place where the app answers the paper.
- **Logged out (SC-08):** if a guest types a code, send them through login and keep the code in the field.
  A friend handed a card becomes a new customer.
- Since the code is bound as soon as it's applied, it also appears in the user's coupon list afterwards
  (personal coupon), so they can't lose it.
- `card_limit` gets its own message too: "You've used 3 Waddy cards this month. This one will still work after [date]".

## 3a. The teaser (SC-16)

Placement history, 2026-09-28: a wide inline strip (rejected: not the design) → the design's floating corner badge on
every screen (rejected: in LTR the bottom-right is where the ADD buttons, prices and CTAs live, so it covered the most
important tap on every screen) → **the badge placed ON a surface on each screen, never floated over content**:

| Screen | Placement | Piece |
|---|---|---|
| Food store | Bottom-right of the cover, the logo tile's twin, overhanging 14px; label only | `ScratchCardBadge` at 0.6, `compact` |
| Grocery store | Pinned white app bar, before the info button | `ScratchCardSticker` 40×46, flips |
| Cart | Top app bar, at the end (moved off the Checkout bar after the device check) | `ScratchCardSticker` 46×52, flips |
| Checkout | Top app bar, at the end, same as the cart (added 09-28 at the user's request; still nothing in the page itself) | `ScratchCardSticker` 46×52, flips |
| Confirmation | Under the XP chip, in its colours: flipping 40×46 card, bold title over one line, chevron | `ScratchCardBar` |
| Order details, live | In the card list, after the rider card | `ScratchCardBar` |
| Order details, delivered (7 days) | After the ending card: "Won something on your card?" | `ScratchCardBar` |

The sticker always takes taps over at least `Dimensions.minTapTarget` (48×48) and dips to 90 % under the finger. The
minimum is built into `ScratchCardSticker`, so no caller can place one too small to hit.

Every piece opens `ScratchCardSheet`. There's no ✕ any more: nothing floats, so there's nothing to dismiss. It shows only
when cards are really going into bags (config `scratch_cards.active` + the customer's zone in `zone_ids`), and never
for parcel orders.

Known limit: the part that overhangs its parent (the cover badge's bottom 14px) doesn't
take taps. Flutter only hit-tests inside a widget's own box. The rest of it does.

### 3b. Claude Design "Scratch Card" (2026-09-28)

Implemented from `Scratch Card.dc.html` (Claude Design project d2778074):
- **`ScratchFlipCard`**: the drawn card. A mint→mint-ink face tiled with the Waddy W (`assets/image/waddy.png`,
  white at 28 %, tilted −8°) under a gloss. It floats (3.2s, −7°↔−5°, 4px lift) and flips in 3D every 2.2s to a back
  that cycles sample outcomes. Motion stops under the system's reduce-motion setting.
- **`ScratchCardBadge`** (the design's 116×132 badge, teal plate, "SCRATCH CARD / Comes with your order") and
  **`ScratchCardSticker`** (the card alone), in `scratch_card_badge.dart`. Placement is in §3a.
- **`ScratchCardSheet`**: tapping any teaser (the corner badge or the inline strip) opens it: a bigger flipping card,
  "LUCKY SCRATCH CARD", 3 steps, "Got it", and the terms line.
- The card uses the design's exact palette: face `#2EF5A8`→`#0A7A50`, edge `#9AF8D3`, and the W pattern in deep teal at 28 %.

**Deliberate differences from the design file:**
- **The back shows no amounts and no real-looking codes.** The design's samples ("EGP 100 OFF", "A52-523T") would
  promise prizes a batch may not carry, and customers would try typing the code. The back cycles FREE DELIVERY,
  "A DISCOUNT ON YOUR ORDER" and "Better luck next time", with the code shown as `XXXX-XXXX`.
- **The terms link isn't tappable.** waddyapp.com/card doesn't exist yet (§8). Make it a link once the page is live.
- The design's "Show scratch card again" button was a prototype control and wasn't built.

## 4. The human touch (print and ops)

- Handwritten-style card, Egyptian-colloquial copy ("اخدش يا باشا 👀"), and a "Packed by ______" line the
  store or rider fills in with a pen.
- The rider hands it over rather than burying it in the bag.
- Losing cards carry a joke, a proverb or "next one's yours". They should still feel like a small gift.
- Seasonal batches (Ramadan, Eid, match nights) need only new art and a new batch.
- Print on the card: **how to use it** ("type the code in the promo field on your next Waddy order"), the
  use-before date, and "terms at waddyapp.com/card".

## 5. Phases

1. **Server + admin (SC-01..05, 09, 12..15):** it has to exist before printing, because the printer needs the CSV.
2. **App (SC-06..08):** live in the stores before the first cards go into bags. It's small.
3. **Measurement (SC-10).**

## 5a. Launch schedule (SC-12)

The first stage is generous so people build the habit, then the win rate steps down. Waddi hasn't launched yet
(2026-09-27), so there's no real order count to size weeks by. **Stages therefore move on when a box runs out,
not on a calendar date.** Each stage is its own batch, with its own box, win rate and use-before date:

| Stage | Batch | Cards | Win rate | Winners | Losers | Prize |
|---|---|---|---|---|---|---|
| 1 | W1 | 500 | 100 % | 500 | 0 | Free delivery |
| 2 | W2 | 500 | 65 % | 325 | 175 | Free delivery |
| 3 | W3 | 500 | 50 % | 250 | 250 | Free delivery |
| 4+ | W4… | 500 | steady mix (decision #1) | — | — | Free delivery / small discount |

**Why a box, not a week:**
- If launch is slow, stage 1 lasts three weeks and nobody has to guess.
- If launch is fast, stage 2 starts on day 4. Either way the generous stage covers exactly 500 customers.
- There are no leftover cards to destroy: the next box is opened only when the last one is empty.
- The maximum cost is fixed per box, not per week, so a surprise busy week can't blow the budget.

**Don't print all four stages up front.** Generate and print W1, then watch how fast it goes, then print W2 with a
realistic size and the right lead time for your printer. Admin can generate a batch any time, and nothing
about W2 has to exist before W1 is in bags.

**Why it retains:** give each batch a short use-before date (about 10–14 days after the box is opened). A stage-1
winner spends the prize on their next order, and that order brings a stage-2 card, so each card pulls in the next order.

**Maximum cost per box** = winners × delivery fee × redemption rate. For illustration only, at EGP 25 and 60 %
redemption: W1 ≈ EGP 7,500, W2 ≈ 4,900, W3 ≈ 3,750. It can never exceed winners × delivery fee.

**Rules the schedule needs:**
- **Label each box W1 / W2 / W3 / W4 on the outside** (and in small print on the card back). Otherwise a
  stage-1 card gets handed out during stage 3 and the win rate quietly jumps back to 100 %.
- **Use-before is set when the box is opened, not when it's printed.** A box printed today might not be opened
  until next month, so the admin sets the date when switching the batch on.
- **Don't print odds on the card.** Stage 1 has everyone winning, so "1 in 3 wins" would be false. "Scratch to see
  what you got" is true in every stage.

## 5b. The on/off switch (SC-14)

One admin switch turns the card program on or off at any time. **Off means no more cards**:
- Admin can't generate a new batch or switch one on, so no new codes exist to print.
- No new cards go into bags (the ops side of the same decision: boxes stay in the drawer).
- Anything in the app that advertises cards is hidden. Today the plan has no such surface; the rule is there for
  any future one (a "got a card?" hint, a banner). The app reads the switch from the config endpoint, so it
  changes with no app update.

**Cards already handed out keep working until their use-before date.** Switching off stops new cards, not
promises already made: a customer holding a winning card can still type it and get the prize. Refusing a card
someone is holding in their hand is the one outcome that turns a gift into a complaint. After the last
use-before date passes, the program is fully closed.

**Emergency stop is per batch, not this switch.** If a box is lost or stolen, switch off that one batch (SC-02).
Its codes stop working at once, and every other batch carries on.

## 5c. Card custody (SC-15)

Whoever holds a sealed box (rider, store packer) could keep cards instead of handing them out. At stage 1 every
card wins, so there's no need to scratch: just pocket some. From stage 2 they could also scratch, keep the
winners, and throw the losers away. In the numbers this looks like "low redemption in that area", not like fraud,
unless you track where each card went.

**These are detective controls, not preventive ones.** Nothing stops a rider pocketing cards mid-shift. The range log
only lets you work out afterwards whose range leaked. The per-account cap and the tamper line are the only parts that
act at the moment of abuse, and even they only limit it. So "we log ranges" doesn't mean custody is solved. It means
you can find out, and then decision #6 says what happens.

Cheap controls, together:
- **Numbered cards.** `card_no` (already in the CSV) is printed on the outside. Boxes go out as number ranges
  (for example W2 #0001–0100 → rider Karim), recorded in the admin batch screen or even a sheet. That record is the whole
  control. Without it no report can point anywhere.
- **Per-range redemption report.** The admin batch screen shows, per range: winners in the range, winners redeemed, and
  how many distinct accounts redeemed them. Two signals:
  - **Low redemption, judged against the same batch in the same zone.** A slow zone redeems less for everyone, so a fixed
    threshold would flag every rider in the quietest zone. Flag a range only when it's well below its zone's rate for that batch.
  - **Few accounts:** many winners from one range redeemed by one or two accounts.

  **Minimum sample:** a 100-card range at 50 % has only 50 winners, so one range is noise. Flag only after a holder's ranges
  add up to about 100 winners, and treat a flag as "look closer", not as proof.
- **Per-account cap:** at most 3 card codes bound to one account per 30 days. That stops a rider running a stack through
  their own account. It doesn't stop friends' accounts, but those show up in the report above.
- **Print "Scratched already? Don't accept it — tell us"** on the card. A scratched card is a tamper seal the
  customer can check.
- **Hand-over at the door.** Boxes stay sealed until the rider's shift. Riders never get more than one shift's range.

## 6. Open decisions

1. **Stage 4+ steady mix:** for example 1 card in 3 wins free delivery, 1 in 10 wins EGP 20 off (min EGP 150), the
   rest carry a message only. This needs your delivery fee and margin.
2. **Use-before window:** short (10–14 days from opening the box) pushes the next order; long is friendlier. This is the retention lever.
3. **Who hands it over:** the rider or the store.
4. **Test zones:** start with one or two zones and compare reorder rates with zones that don't get cards.
5. **Per-account cap:** 3 card codes per 30 days is the suggested default.
6. **What happens when a range is flagged?** For example: first a conversation, then that holder stops getting boxes,
   then deduction or dismissal if the account signal confirms it. Detection with no consequence is just a spreadsheet,
   and riders need to know the rule before the first box goes out.

## 7. Metrics (SC-10)

Per batch and zone:
- **Redemption rate**: winning codes used ÷ winning cards printed
- New accounts whose first order used a card code
- **14-day reorder rate, card zones vs non-card zones**
- Cost = print + redeemed prize value, per extra reorder

## 8. Risks

- **Promotion rules:** a free card with a purchase and non-cash prizes is normally a promotion, not gambling. Confirm
  Egyptian consumer-protection rules and print a terms link.
- **Printing errors:** a printed prize that doesn't match the server row. The server wins. Proof the CSV and
  spot-check a sample from each box before activating the batch.
- **Stolen boxes:** they're worthless until the batch is switched on, and a single batch can be switched off alone.
- **Handlers keeping cards:** see §5c. It shows up as low redemption in one card range, so ranges must be logged.
