# Partner brochure: unconfirmed commercial information

**All terms and contact details now live in one file: `terms.js`.** Fill a
value in there (English and Arabic) and rebuild; it updates the offer page,
the join page and the short version in every edition and both languages. A
WhatsApp number there also becomes a scannable wa.me QR code on the join page.

## Decided (2026-11-12)

| Point | Decision | Where it shows |
|---|---|---|
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

## Marketing commitments (page 09)

| Placeholder | What is needed |
|---|---|
| `[Monthly Advertising Budget]` | Decide whether to print a figure at all. A range or "ongoing investment" is safer than a number you may change |
| `[Campaign Frequency]` | How often platform campaigns run |
| `[Targeting Radius / Areas]` | The geographic targeting actually used in Meta ads |
| `[Partner Spotlight Selection Criteria]` | How partners are chosen: rotation, performance, category balance, launch partners first |
| `[Spotlight Schedule]` | How many spotlights per period. Do not print a per-partner promise unless it is approved |
| `[Production Services Included]` | Whether Waddy shoots photo/video for partners, at whose cost, and who owns the content |

## Operations

| Placeholder | Page | What is needed |
|---|---|---|
| `[Confirmed Placement Formats]` | – (no longer printed) | Which sponsored formats are sold at launch |
| `[Confirmed Analytics: …]` | 14 | Which insights the Partner App really shows |
| `[Onboarding Timeline]` | 15 | Realistic days from signature to go-live |

## Statements made on your instruction, not verified in code

These come from the brief and are presented as fact. Confirm each is true at
launch.

- Waddy operates its own rider network (pages 2, 4, 5, 17).
- A Partner App exists for orders, products, availability and operations (pages 2, 18).
- Launch covers Maadi and surrounding areas including Degla (page 5).
- Riders collect cash on delivery on the partner's behalf (page 17).
- Sponsored placements are always labelled as sponsored (page 14).
- Standard listing never requires buying advertising (page 9).

## Status chips

Each page footer carries a chip: *Live in the app*, *Operating policy*,
*Marketing plan* or *Concept mockup*. They are there for internal review.
Build with `FINAL=1 node build_master.js` to hide them for print, once the
pages they mark have been confirmed.
