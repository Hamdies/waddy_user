# Partner brochure: unconfirmed commercial information

**All terms and contact details now live in one file: `terms.js`.** Fill a
value in there (English and Arabic) and rebuild; it updates the offer page,
the join page and the short version in every edition and both languages. A
WhatsApp number there also becomes a scannable wa.me QR code on the join page.

## Decided (2026-11-12)

| Point | Decision | Where it shows |
|---|---|---|
| Exclusivity | **Non-exclusive.** "Stay on your other apps. Waddy adds Maadi customers." | Cover, offer page (p06), extra-orders page (p05), join page |
| Setup fee | **None** | Cover, offer page, join page |
| Launch offer | **Reduced commission for founding partners**, no rate printed | Cover, offer page |
| Commission | **Two rates, not printed**: one when Waddy delivers, one when the partner delivers. Agreed in the room | Offer page |
| Delivery fee, settlement, refunds, exit | **Not printed.** "Agreed with you, in writing, before you start" | Offer page |
| 30-day review | After 30 days Waddy shows the partner every order that came through Waddy | Offer page, roadmap (p15) |
| Proof | None yet. "We're new, so there are no case studies yet" | Offer page |
| Waddy Spots | **Out of the merchant pitch.** Keep it for the separate venue pitch | – |
| Rider areas | Degla, Sarayat, Nerco and Corniche | Pages 2, 3, 6 |
| Monthly fee | **None** (confirmed 2026-11-13) | Offer page |
| Delivery PIN | **Live** (confirmed 2026-11-13). `deliveryPin: false` in `terms.js` drops the bullet | Deliver page |

**Before you negotiate:** decide your standard, launch and floor rates
privately. Owners in one neighborhood compare notes, and very different
rates will leak.

## Still needed before print (in `terms.js`)

| Key | What is needed |
|---|---|
| `whatsapp` | A number a real person on the partner team answers. It becomes the QR code on the join page. Until set, the join page prints blank write-in lines |
| `phone`, `email` | Partner line, or the company phone and email until one exists |

The other keys in `terms.js` (commission, settlement…) are no longer printed.

---|---|---|
| Exclusivity | **Non-exclusive.** Partners keep every other app | Cover, offer page (p05), join page, short version |
| Setup fee | **None.** Joining, onboarding, catalogue and photos are free | Cover, offer page, join page |
| Launch offer | **Reduced commission for founding partners** (rate and period still to fill) | Cover, offer page |
| Proof | **None yet.** Framed honestly as "we're new; founding partners get these terms in writing" | Offer page |

## Still needed before print (in `terms.js`)

| Key | What is needed |
|---|---|
| `commission` | Standard rate per completed order. "What you keep" is calculated from it |
| `launchCommission`, `launchPeriod` | The founding-partner rate and how long it lasts |
| `monthlyFee` | Fixed monthly fee, or "None" |
| `deliveryFee` | Who pays delivery and how it is set |
| `settlement` | Payout schedule and method, including cash orders |
| `refunds` | Who bears the cost of a refund, by cause |
| `contract` | Term and notice period. Printed as "Clear exit" under *Start risk-free*, so a short notice period helps most |
| `whatsapp` | A number a real person on the partner team answers. It is the main call to action |
| `phone`, `email` | Secondary contacts |

The offer page carries a "confirm before print" chip until `commission` and
`settlement` are filled.

---

The rest of this document lists the remaining placeholders elsewhere in the
brochure.

## Marketing commitments (page 10)

None of these is printed any more; the promote page carries no budget or
frequency. Decide them internally anyway.

| Placeholder | What is needed |
|---|---|
| `[Monthly Advertising Budget]` | Decide whether to print a figure at all. A range or "ongoing investment" is safer than a number you may change |
| `[Campaign Frequency]` | How often platform campaigns run |
| `[Targeting Radius / Areas]` | No longer printed; still decide the targeting used in Meta ads |
| `[Partner Spotlight Selection Criteria]` (no longer printed) | How partners are chosen: rotation, performance, category balance, launch partners first |
| `[Spotlight Schedule]` (no longer printed) | How many spotlights per period. Do not print a per-partner promise unless it is approved |
| `[Production Services Included]` (no longer printed) | Whether Waddy shoots photo/video for partners, at whose cost, and who owns the content |

## Operations

| Placeholder | Page | What is needed |
|---|---|---|
| `[Confirmed Placement Formats]` | – (no longer printed) | Which sponsored formats are sold at launch |
| `[Confirmed Analytics: …]` | – (removed) | The Grow page no longer claims analytics. Add them back once the Partner App shows them |
| `[Onboarding Timeline]` | – (removed) | Still worth knowing: realistic days from signature to go-live |

## Statements made on your instruction, not verified in code

These come from the brief and are presented as fact. Confirm each is true at
launch.

- Waddy operates its own rider network, and riders work only Degla, Sarayat, Nerco and Corniche (pages 2, 4, 11).
- A Partner App exists for orders, products, availability and operations (pages 2, 13).
- Launch covers Maadi (throughout); the Degla mention and area map are no longer printed.
- Riders collect cash on delivery on the partner's behalf (pages 6, 11).
- Sponsored placements are always labelled as sponsored (page 9).
- Standard listing never requires buying advertising (page 9).

## Status chips

Each page footer carries a chip: *Live in the app*, *Operating policy*,
*Marketing plan* or *Concept mockup*. They are there for internal review.
Build with `FINAL=1 node build_master.js` to hide them for print, once the
pages they mark have been confirmed.
- Waddy can produce, for each partner, a list of every order that came
  through Waddy in its first 30 days (offer page and roadmap). Make sure
  someone owns that report before the first partner reaches day 30.
- "Faster deliveries" (page 2) is stated as a consequence of short routes.
  Do not upgrade it to "fastest" until you have delivery times to show.

## Claims to keep true (checked against the app code on 2026-11-13)

All of these exist in the customer app's code. Several were built with a
backend deploy still pending when last documented (`docs/plans_index.md`), so
confirm each works in the production app before an owner looks for it:

| Claim | Page | Plan status when last documented |
|---|---|---|
| XP and weekly quests | 4 | Built; later phases waited on a backend deploy |
| Scratch card in the bag | 4 | Built 09-28; backend deploy and migration pending |
| Wallet, referrals, one-tap reorder | 4 | Standard, long-standing |
| Live tracking and ETA | 6 | Built 10-03; backend deploy and device check pending |
| Delivery PIN | 6 | Confirmed live by Waddy 2026-11-13. It shows only while `order_delivery_verification` is on in the backend |
| Pet profiles, refill reminders, vet listings | Pet-shop appendix | Built 10-02; deploy pending, and the pets module is seeded switched off |
| 30-day order list per partner | 7, 8 | Not a feature: someone must be able to export it by day 30 |
