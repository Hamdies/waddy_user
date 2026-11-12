# Capabilities to implement or verify before advertising them

The partner brochure describes things at three levels of certainty. This list
says which is which, so nothing is sold as a live guarantee before it is one.
"Checked" means checked in this repository (the customer app, `waddy_user`);
the backend and the Partner App live in other repositories and were not
inspected.

## Live in the customer app (checked in code)

| Capability | Where | Note |
|---|---|---|
| Top 10 Maadi ranked list, browse by cuisine | food home | |
| Ripeness and salad/cooking choice on produce | `lib/features/item/domain/produce_preference.dart` | Admin marks which categories ask |
| Pet profiles, "the usual", reminders, vet clinic listings | `lib/features/pets/` | **Backend deploy and device check pending** (`docs/pets_module_plan.md`). The pets module is seeded switched off |
| Waddy Spots weekly vote, champion, voter draw | `lib/features/places/` | |
| XP, levels, weekly quests | `lib/features/xp/` | Later phases wait on a backend deploy |
| Scratch card in the bag | `docs/scratch_card_plan.md` | Built; backend deploy and migration pending |
| Wallet, referral, reorder, coupons | cart / wallet / refer features | |
| Live tracking, ETA, delivery PIN | `docs/live_tracking_plan.md` | Built; backend deploy and device check pending |
| In-app advertisement placements | `lib/features/home/controllers/advertisement_controller.dart` | The mechanism exists. Which formats are sold, and the "Sponsored" label on each, need confirming |

Anything marked pending must be live on launch day or come out of the brochure.

## Needs verification outside this repository

| Claim in the brochure | Page | What to verify |
|---|---|---|
| Waddy operates its own rider network | 2, 4, 5, 17 | Riders are employed or contracted by Waddy in every launch zone, not a third-party fleet |
| Partner App: orders, products and prices, availability, opening hours | 2, 18 | Each function exists in the shipped Partner App. The brochure's Partner App screen is a labelled concept, not a screenshot. Replace it with a real one |
| Analytics: sales, peak hours, top products, customer insights | 18 | Which of these the Partner App actually reports. Print only those |
| Cash collection and settlement | 17, 20 | The reconciliation flow for cash-on-delivery orders |
| Campaign measurement incl. attributed orders | 12 | Ad attribution into the app (`docs/ads_tracking_plan.md`) |

## Needs implementation or a policy decision

### Maadi branch priority (page 6)

The brochure presents this as an **intended operating policy** and says so in
the page footer. Before it becomes a live promise:

- **Branch as its own store per zone.** Confirm each branch of a brand is a
  separate store bound to a delivery zone, so a Maadi customer only resolves
  to the Maadi branch.
- **Routing.** An order from a Maadi address must go to the Maadi branch even
  if another branch of the same brand is also within range.
- **One brand, one card.** Decide how a multi-branch brand appears in lists
  and search: a single brand card that resolves to the local branch, rather
  than several near-identical rows.
- **Branch-level promotions.** Offers and sponsored placements must be
  settable per branch.
- **Brand-level account.** Whether a chain gets one login across branches and
  consolidated reporting.

The brochure deliberately does **not** promise first position in search or any
fixed ranking. Keep it that way unless ranking rules are written and built.

### Other items

| Item | Page | Decision or work needed |
|---|---|---|
| Sponsored placement formats (home, category, featured rail) | 14 | Confirm which exist at launch and that each is labelled |
| Partner-specific paid social campaigns | 9 | A process and price list; nothing to build in the app |
| Partner Spotlight | 11 | Selection rules, schedule, production scope |
| Recognition for the Spots champion | 13 | Confirm the champion badge and prize draw run as described each week |
| Expansion to other neighborhoods | 6 | The brochure says other branches "join as Waddy opens in their areas". No dates are given; do not add any |

## Mockups in the brochure

Every phone screen in the brochure is an illustration drawn in the app's
colors to explain a feature. None is a screenshot of a build. Two carry a
"concept view" caption because they show the Partner App and sponsored
placements, which were not verified. For print, replace the illustrations with
real screenshots from the submitted build wherever possible.
