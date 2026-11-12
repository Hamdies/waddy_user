# Partner brochure: unconfirmed commercial information

Everything in the brochure that still needs a decision or a figure from Waddy
before it goes to print. Each item appears in the brochure as an amber
`[placeholder]`. Replace the text in `master.js` (or in the PowerPoint) and
rebuild.

Nothing below has been invented. Where a value is missing, the brochure prints
the placeholder rather than a guess.

## Commercial terms (page 20)

| Placeholder | What is needed |
|---|---|
| `[Commission Structure]` | Rate per order, whether it differs by category or by delivery/pickup, and any launch rate |
| `[Delivery Fee Model]` | Who pays delivery (customer, partner, shared), how the fee is set, any free-delivery funding rule |
| `[Monthly Subscription, if any]` | Whether a fixed fee exists; if not, replace with "None" |
| `[Settlement Schedule]` | Payout frequency, method, and how cash-on-delivery orders are reconciled (also printed on page 17) |
| `[Refund & Cancellation Policy]` | Who bears the cost of a refund in each case: store error, rider error, customer cancellation |
| `[Sponsored Placement Pricing]` | Price per placement type and period (also printed on page 14) |
| `[Contract Term & Notice]` | Contract length, renewal, notice period, any exclusivity |

## Marketing commitments (pages 9–12)

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
| `[Confirmed Launch Service Areas]` | 5 | The exact launch zones. The map names Maadi, Degla and Sarayat for illustration |
| `[Confirmed Placement Formats]` | 14 | Which sponsored formats are sold at launch |
| `[Confirmed Analytics: …]` | 18 | Which insights the Partner App really shows |
| `[Onboarding Timeline]` | 19 | Realistic days from signature to go-live |

## Contact details (page 22)

| Placeholder | What is needed |
|---|---|
| `[Partner Team Phone]` | Sales / partner line |
| `[Partner WhatsApp]` | WhatsApp number |
| `[Partner Email]` | Partner inbox |
| QR code | Currently encodes `https://waddyapp.com` (the site referenced in the app). Replace `assets/qr.png` with a QR for the partner sign-up form when one exists |

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
