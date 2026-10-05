# Pets module plan (`PET-*`)

Status: **phases 1–4 built 2026-10-02 (backend, screens, pet profile, lifecycle pushes), deploy + device check pending; phase 5 open, plus PET-15 art, PET-18/19.** Design source: Claude Design project
"Pet Module v2" (`Pet Module v2.dc.html`, three screens: 00 Meet your pet, 01 Pet hub,
02 Pet store). Scope: `waddi_user` + `waddy_back`. `waddi_store` (vendor app) needs no
change: pet shops are grocery-typed stores to it (PET-01).

Goal: a Pets module with pet shops (orderable stores) and vet clinics (info only: call,
WhatsApp, directions). It starts with a short "meet your pet" onboarding. The pet
profile it collects (name, species, sex, age, diet, later birthday) powers
personalised copy and pushes ("Luna's food runs out Thursday"). Ordering, cart and
checkout are unchanged.

## Master status

| ID | Item | Priority | Status | Phase |
|---|---|---|---|---|
| PET-01 | Module type: a second module row with `module_type = grocery` plus a new `modules.variant = 'pets'` column. The client turns that pair into `ModuleType.pets` at the model boundary. **Revised 10-02:** the first draft said "new `pets` type". On checking, a new type silently loses order-status pushes and about 40 admin/vendor screen branches (see evidence) | High, blocks the rest | **built** (P1, deploy pending): `modules.variant`, `ModuleType.of(type, variant:)`, `variant` round-trips through the cached module JSON | 1 |
| PET-02 | Product taxonomy: one shared tree, species as main category (Cats, Dogs, Birds, Fish, Small pets), need as sub (Food, Treats, Litter & care, Toys, Beds & bowls, Grooming, Health) | High | **built** (P1): `PetsModuleSeeder`, 6 mains / 32 subs, stable `categories.code` (`cat`, `cat.food`…) | 1 |
| PET-03 | Products for several species (a bowl, a carrier, a shampoo). `category_ids` holds one main category, so they would vanish from every species but one | Medium | **built** (P1) as D3's simple option: an "All pets" main category (`all`); the store screen must also query it (P2) | 1 |
| PET-04 | Clinics are not stores. A store with no items still carries a delivery fee, ETA, schedule, cart and order flow. Model clinics as Places with a `surface` flag instead | High | **revised 10-02 (user call): own `vet_clinics` table + Admin › Vet clinics in the Pets module**, apart from Spots. Migration `2026_10_02_000005` copied the 5 clinics out of `places` and switched those places + the category off (nothing deleted) | 1 |
| PET-05 | Clinics stored as Places will leak into Spots (leaderboard, trending, winner draw, Spots pushes). That's 7 customer-facing `Place::` query sites. Exclude them by default, not per call site | High | superseded by the separate table: Spots no longer holds clinics. `SurfaceScope` + `place_categories.surface` stay as inert leftovers (the pets category is off) | 1 |
| PET-06 | Pet profiles: new `user_pets` table + CRUD API. Nothing pet-shaped exists today | High | **built** (P1): `user_pets`, `customer/pets/{list,add,update/{id},delete/{id}}`, client `PetController` incl. guest draft | 1 |
| PET-07 | Arabic grammar is gendered: "لونا محتاجة" vs "ركس محتاج". Without the pet's sex, every Arabic personalised string is wrong for half the pets. The design never asks for it | High | **built** (P1 column, P2 Boy/Girl tiles on onboarding step 2; gendered copy via `PetCopy.tr` with `_m`/`_f` keys) | 1–2 |
| PET-08 | Client `ModuleType.pets` (from type + variant) + home branch + `StoreLayout` case + `isShoppingModule` (`home_screen.dart:560`). Until `PetStoreScreen` exists, pets stores fall to `menu` (FoodStoreScreen), which works | High | **built** (P1 type plumbing; P2 `PetHubScreen` in home's `hasOwnScaffold`, `StoreLayout.pets` → `PetStoreScreen`) | 2 |
| PET-09 | Onboarding (screen 00) for first entry into the module. Must work for guests: keep the pet locally and sync it on login | Medium | **built** (P2): `PetOnboardingScreen`, opens by itself once (`waddy_pet_onboarding_seen`), then a hub card; guest draft has no photo | 2 |
| PET-10 | "Subscribe, save 10% · every 4 weeks" on the hub. No recurring-order or saved-payment system exists, and most orders are COD. v1: "Remind me in 4 weeks" (push + prefilled cart) | Medium: design overpromises | **built** (P4): hub "Order again · Luna's usual" card (`/customer/pets/usual`), "Remind me every 4 weeks" → `pet_reminders`, every 2/3/4/6 weeks or off; pushes hourly in daytime. No discount, no recurring order | 4 |
| PET-11 | Hardcoded claims in the design: "in 30 min", clinic ★ ratings, "Popular in Maadi" names, "+12" categories. Each needs a real source or must go | Medium | **done** (P2): "in 30 min" dropped from the headline; clinic stars only at 5+ reviews; "Popular in Maadi" → "Need ideas?"; the "+N" tile is "View all" | 2 |
| PET-12 | Clinic "Chat" button: there is no chat with places. In Egypt clinics run on WhatsApp, so use `wa.me/<phone>` | Low | **built** (P2): WhatsApp button, hidden for landlines (server returns `whatsapp: null`) | 2 |
| PET-13 | Replenishment pushes ("Luna's food runs out Thursday"): estimate run-out from the last order of a food item, its pack size and the pet's size/age. Scheduled command, same shape as `xp:prize-expiry-reminders` | High value | **built** (P4) as `pets:pushes replenish`, 18:00 Cairo. Estimate = the customer's own gap between their last two orders of that product (clamped 7–90 days), else a typical bag per species (cat 30, dog 21, bird 30, fish 45, small 30); push 3 days before, never more than 7 days after. Pack size and pet weight are **not** used yet: item units are unreliable (CAT notes "Kilogram" defaults) | 4 |
| PET-14 | Old app builds don't know `variant`. They read the pets module as a second grocery module, and the dashboard's "last grocery module wins" loops (`store_list_controller.dart:565`, `category_controller.dart:157`) can put pet shops in the grocery rail. Don't enable the pets module in any zone until the build that parses `variant` is the minimum version | High | open: the seeder creates the module **switched off** (`status = 0`) for this reason | 2 |
| PET-15 | Pet product art (species tiles, category tiles, pet avatars). The design's image slots are all empty, so this is a content dependency, not code | Medium | open: stand-ins are HugeIcons since 10-02 (`hugeicons` bumped to ^1.2.0 for `Cat`, `Bird`, `Fish`, `Rabbit`, `PawPrint`; HugeIcons has **no dog** in any version, so a dog is `PawPrint`); need tiles map to `RiceBowl01`, `Bone01`/`Cookie`, `Shampoo`… in `_needIcon`. A category image uploaded in admin replaces the tile's icon automatically | 3 |
| PET-16 | Birthday / life-stage pushes: birthday coupon, "Luna turns 1, time for adult food", senior switch at 7. Needs `birth_date` (exact or approximate) on `user_pets` | Medium | **built** (P4): `pets:pushes birthdays` (real dates only; Feb 29 → Feb 28; optional `PETS_BIRTHDAY_COUPON` code in the copy) and `pets:pushes life-stage` (cats/dogs at 1 and 7, estimates count), 10:00 Cairo. Birthday asked in the pet profile + a hub nudge (D5) | 4 |
| PET-17 | Catalogue: pet products are branded (Royal Canin, Whiskas) and sold by several shops, a textbook case for `catalog_products` (CAT-*). Start pets on the catalogue, don't migrate later | Medium | open | 1, 3 |
| PET-18 | Clinics can't be reviewed yet: Spots' review/vote endpoints bind `Place` through the scoped query, so a clinic 404s there. That's intended for votes, but clinic ratings need their own review endpoint | Medium | open | 3 |
| PET-19 | The clinic sheet says "Treats cats and dogs". There's no field for which species a clinic treats. Place tags won't do: they surface in Spots' tag list. Needs a `species` JSON column on places or text in the description | Low | **built** 10-02: `places.clinic_species` / `clinic_services` (fixed keys), admin checkboxes, API `species`/`services`, app tags + rail toggles (Open now · 24/7 · Home visits · Treats {pet}) | 2 |
| PET-20 | Design deviations taken in P2: shop list uses `ModuleStoreRowCard` (food/grocery's row) instead of the design's big cover card, to keep the rating bar, out-of-zone collapse and offer chips identical across modules; sort offers Recommended/Nearest/Top rated and chips Offers/Free delivery/Under 30 (the design's Fastest, Open now and 4.7+ have no get-stores param); hub header is the shared compact hero + the design's full-mint "Everything Luna needs" block with the taped polaroid (design rev. 10-02, second polaroid peeks behind for a multi-pet household) instead of one continuous custom mint header; no "Order again" card (needs a cross-store buy-again; the existing one is per store) | Info | decided | 2 |

## Push guardrails (P4, all in `PetPushService::send`)

Per-pet `notify` switch (pet profile) · one push per (pet, kind, ref) via `pet_push_log` ·
automatic pushes (food, life stage) at most once per pet per 7 days; birthdays and
customer-set reminders exempt · daytime only (daily jobs 10:00/18:00 Cairo, reminders
held 21:00–09:00) · copy in the customer's app language (`users.current_language_key`),
`_m`/`_f` by the pet's sex (`resources/lang/{en,ar}/pets.php`) · every push is
`type: pets` → the app enters the Pets module.

## Verify on device / admin

Appended as phases land; tick when checked.

- [ ] (design rev. 10-02) Hub: mint block with the tilted polaroid (photo or species icon, name, amber tape, teal species badge); two pets → a second polaroid peeks behind; clinic rail is 220-wide photo cards with "600 m · ★ 4.9" (star only at 5+ reviews) and the open line; no emoji anywhere in Pets
- [ ] (hugeicons 1.2.0) Spot-check a few non-pet screens: 206 icons were redrawn upstream, nothing was renamed or removed for the 83 the app uses

Deploy (phase 1), in this order: code + `php artisan migrate` together. `SurfaceScope` reads
`place_categories.surface`, so code without the migration 500s every Spots list.

- [ ] (P1) `php artisan migrate` runs `2026_10_02_000001..000003` + the PlacesToVisit `2026_10_02_000001` cleanly on the live DB (could not run locally: the local DB has no core tables)
- [ ] (P1) `php artisan db:seed --class=PetsModuleSeeder --force` → prints the Pets module id (status 0), 6 species lines, the Vet clinics category id. Re-run → same ids, no duplicates
- [ ] (P1) Spots on device: list, leaderboard, trending and category chips unchanged; no "Vet clinics" chip
- [ ] (P1) Admin › Places › Categories: "Vet clinics" shows a "Pets · vet clinics" badge; the edit form has "Shown in"
- [ ] (P1) Admin › Places: add one clinic in "Vet clinics" (phone 01…, hours, cover) → `GET /api/v1/pets/clinics?lat=29.96&lng=31.25` returns it with `whatsapp` = `201…`, `rating` null; it does NOT appear in `GET /api/v1/places`
- [ ] (P1) `POST /api/v1/customer/pets/add` (name, species, sex) with a token → 201, `is_primary` true; second pet → `is_primary` false; delete the first → the second becomes primary
- [ ] (P1) `GET /api/v1/module` includes `"variant": "pets"` on the Pets row (after an admin switches it on for a test zone)
- [ ] (P2) `GET /api/v1/pets/categories` returns 6 species with children and codes, names in Arabic with `X-localization: ar`
- [ ] (P2) Device, Pets module on for a test zone with one shop + a few products filed under `Cats › Food`/`Cats › Treats`:
  - [ ] Dashboard → Pets opens the hub (not the grocery home); cart bar replaces the bottom nav
  - [ ] First visit with no pet: "Meet your pet" opens by itself once; Skip → hub shows the "Who's the boss at home?" card; second visit doesn't auto-open
  - [ ] Onboarding as a guest: no photo picker; after finishing, hub says "Everything Luna needs"; sign in → reopen Pets → the pet is on the account (`customer/pets/list`) and the draft is gone
  - [ ] Onboarding signed in with a photo: photo shows on the hub avatar and in the store switcher
  - [ ] Arabic, a female pet: hub headline reads "كل اللي لونا محتاجاه", store treat line "هتحبها"; a male pet "محتاجه" / "هيحبها"
  - [ ] Tap the avatar → edit flow, Save closes it; "+" adds a second pet
  - [ ] Clinic rail shows the test clinic with open/closed + distance; sheet Call dials, WhatsApp opens the chat (mobile number), Directions opens Maps; a landline clinic shows no WhatsApp button
  - [ ] Hub chips: sort cycles Recommended → Nearest → Top rated, Offers / Free delivery / Under 30 filter the list
  - [ ] Shop opens the pet store page (not the specialty page): switcher starts on the primary pet; tapping Dogs changes the grid and shelves; a species the shop doesn't stock shows "Nothing for Birds here yet"
  - [ ] Need tile "Food" opens the category page with the Food chip selected and only food items; "View all" opens the whole species
  - [ ] Add from Popular / Treat time / the care rows → cart bar updates; checkout places the order; the store app receives it; order status pushes arrive (grocery messages)
  - [ ] Logout → log in as another account → hub shows no pet (or theirs)
- [ ] (P3) Menu → My pets (only where Pets serves the zone) lists the pets; tap one → details: set a birthday by date, then by "about 3" (label "About 3 years old" / "حوالي ٣ سنين"); breed + weight save; Make main moves the badge; Remove asks, then removes
- [ ] (P3) Hub: a pet with no birthday shows "When's Luna's birthday?" → opens the birthday sheet directly
- [ ] (P4) Deploy: `migrate` runs `2026_10_02_000004`; `php artisan schedule:list` shows the four `pets:pushes` lines
- [ ] (P4) Hub after a delivered pets order: "Order again · Luna's usual" shows the food item; Buy again opens its sheet; Remind me every 4 weeks → "Every 4 weeks · next <date>"; Edit → 2 weeks ("كل أسبوعين" in Arabic) / Turn off
- [ ] (P4) Set a test pet's birth_date to today (real date), run `php artisan pets:pushes birthdays` → one push in the user's language, correct gender; run again → "sent 0"
- [ ] (P4) Set a cat's birth_date to exactly 1 year ago → `pets:pushes life-stage` sends "Luna is all grown up"; a second life-stage or replenish push within 7 days is held by the cap
- [ ] (P4) A delivered order with a `Cats › Food` item dated 28 days ago → `pets:pushes replenish` sends "Luna's food might be running low"; with a reminder set for that item it doesn't
- [ ] (P4) Set a reminder's `next_at` to the past → `pets:pushes reminders` sends it (between 09:00 and 21:00 Cairo) and moves `next_at` on by the interval
- [ ] (P4) Tap each push: app in foreground, background, and killed → lands on the Pets hub
- [ ] (P4) Turn "Reminders about Luna" off → none of the jobs push about her

## Decisions needed

| # | Question | Recommendation |
|---|---|---|
| D1 | New `pets` module type, or reuse grocery/ecommerce? | **Reuse grocery + `variant` flag** (PET-01, revised 10-02). The backend, admin and store app treat pet shops exactly like grocery shops, which are live and tested. Only the customer app knows they're pets. Not ecommerce: its config is `always_open: true` (no shop hours, but the design shows "Opens 10 AM"), and its app screens are the generic ones we'd replace anyway |
| D2 | Clinics: Places rows, a new `vet_clinics` table, or stores? | **Places + `place_categories.surface = 'pets'`** with a default-exclude global scope (PET-04/05). That gives phone, website, Instagram, `opening_hours` + `isOpenNow()`, coordinates, address, logo + cover, translations, reviews and admin CRUD for free. A new table is the fallback if the scope feels too clever |
| D3 | Multi-species products | Simplest: an "All pets" main category that every species page also queries. Alternative: a `pet_species` JSON column on items. That's more correct but it's a second filter system |
| D4 | Subscribe & save | Not in v1. Ship "Remind me" first and measure how many users set one before building recurring orders |
| D5 | Birthday in onboarding? | **Revised 10-02 by the user: yes, as step 3** (exact date or "about N years" → estimate; age band now derived, not asked), and the **photo is required** on step 2 (guests' photo kept on the device, uploaded with the draft after sign-in). Original recommendation was: Onboarding already has 4 steps. Ask age band there, ask the birthday later from the pet profile and one in-app nudge ("When's Luna's birthday? We'll bring a gift") |

---

## Evidence

### PET-01 · Why grocery + variant, not a new type (revised 10-02)

The first draft recommended a new `pets` type, citing Places as precedent. That precedent
only proves a type can be *registered*: Spots never puts anything in a cart, so it never
exercises orders. Checking the order path for a new type found:

**A new type breaks silently:**
- **No order-status pushes.** `Helpers::order_status_update_message()`
  (`helpers.php:1793`) looks up `notification_messages` by `module_type`. Those rows are
  seeded only for built-in types, so for `pets` it returns `false` and the customer gets
  no "confirmed / on the way / delivered" push. Nothing errors. You'd fix it by seeding
  the rows, but you'd only find it by noticing a missing push.
- **Landmine in order placement.** `PlaceNewOrder.php:330,1730` index
  `$extra_packaging_data[$store->module->module_type]` with no default. Today it's saved
  by short-circuit (the app sends `extra_packaging_amount = 0` because the store payload
  uses a safe `data_get`). Turn extra packaging on for that type and order placement
  throws "Undefined array key".
- **About 40 admin and vendor Blade branches hardcode `'grocery'`** (grep `module_type` in
  `resources/views`): product add/edit/view, POS quick view, campaign items, category
  page tabs, cuisine (store type) pickers (`Module::whereIn('module_type', ['food','grocery'])`),
  vendor sidebar, store settings. A new type falls through all of them.
- **`waddi_store` hardcodes `'grocery'`** in `add_item_screen.dart:62`,
  `item_details_screen.dart:44`, `store_controller.dart:612`, `store_repository.dart:135,154`.

**Grocery-typed is safe server-side:**
- Nothing in `app/` or `Modules/` queries stores or items by `module_type = 'grocery'`.
  Every list is scoped by `module_id` (the only grocery-named code is `organic` on item
  save, `Admin/ItemController.php:337`). So pet shops can't leak into grocery lists on
  the backend.
- Order flags come from `config('module.grocery')`: stock, units, schedule interval, no
  add-ons. All correct for a pet shop.
- Order messages, admin screens, POS and the store app work on day one.

**The customer app is the only place that must tell them apart.** The client work is the
same as with a new type, because the decision lives in one place: `ModuleType.of` at
the model boundary (`module_model.dart:35`). Given `module_type = grocery` and
`variant = pets`, it returns `ModuleType.pets`. After that, every existing
`== ModuleType.grocery` check skips the pets module, which is what we want:
- `home_screen.dart:1136` `hasOwnScaffold`: pets gets its own hub, not `GroceryHomeScreen`.
- `store_navigator.dart:34,55`: pets gets its own layout, not aisles/specialty.
- `store_list_controller.dart:565`, `category_controller.dart:157`: the "find the grocery
  module" loops stay on the real grocery module.
- To add pets to: `isShoppingModule` (`home_screen.dart:560`, out-of-zone sheet), the
  `_ModuleState` getters, `StoreLayout.of`.

Backend cost: one migration (`modules.variant` nullable string). Check that the module
API serialises it (`/api/v1/module`, zone module data), then create the module row from
admin. No order-path code changes.

Old builds: see PET-14. They treat the module as grocery. It's browsable and orderable,
but it can hijack the dashboard's grocery rail, so gate the module behind the app version.

### PET-02/03 · Taxonomy

The store screen's "Shopping for Luna" switcher changes species and the grid below shows
that species' needs. That's main category → subs in the shared tree
(`categories.store_id = NULL`, same as supermarkets). Every shop uses the same tree, so
switching species works the same in every shop. `category_ids` convention: position
1 = main (species), position 2 = sub (need) (CAT-08).

PET-03: a stainless bowl sold for cats and dogs has one main category. D3 decides
the fix.

### PET-04/05 · Clinics as Places

`places` already has every field the clinic sheet shows:
`address, latitude, longitude, image, cover_image, phone, website, instagram,
opening_hours` (migrations `2026_01_04_000002`, `2026_02_10_000001`,
`2026_04_04_110740`), `Place::isOpenNow()` with overnight ranges (`Place.php:169`),
`place_reviews` (rating 1–5, one per user), translations, zones, admin CRUD.

The leak risk is real. Customer-facing `Place::` queries live in `PlaceController`,
`LeaderboardService`, `TrendingService`, `WinnerService`, `PlacePushService` (×2) and
`PrizeRedemptionController`. Votes and leaderboards query through `place_votes` too. A
global scope on `Place` that excludes `surface = 'pets'` by default, removed only in
the pets clinic endpoint, makes a forgotten call site safe instead of leaky.

Ratings: clinics start with zero reviews. Show no star until there are reviews (or
until N ≥ 5). Don't seed a number. If you want a launch rating, store the Google
rating as a separate field labelled as Google's.

### PET-06/07 · Pet profile

```
user_pets
  id, user_id (fk, cascade), name (≤16, design's maxlength), species enum
  (cat|dog|bird|fish|small), sex enum (male|female|unknown), photo nullable,
  age_band enum (baby|adult|senior), birth_date nullable, birth_date_is_estimate bool,
  diet enum (dry|wet|both|picky), breed nullable, weight_kg nullable,
  is_primary bool, timestamps, softDeletes
```

- `age_band` is what onboarding asks. `birth_date` comes later (D5). Derive the band from
  `birth_date` when both exist, so a kitten grows up without the owner editing anything.
- `sex` is one extra pair of tiles on step 2 ("Boy / Girl"). It also fixes English:
  the design's "Thinks every bag is for him" is fine as a species joke, but a push
  needs "her treats" or "his treats".
- `breed`, `weight_kg`: not in onboarding. They're the next data that pays off (food size,
  run-out estimate). Ask for them in the profile.
- API: `GET/POST/PUT/DELETE /api/v1/customer/pets`. Guest: store the draft in prefs and
  POST it after OTP, the same pattern as the guest cart.

Data value, in order of payoff:
1. **Replenishment** (PET-13): the one that drives revenue. Chewy's whole model.
2. **Personalised shop**: open the store on the user's species, rank best sellers by it.
3. **Life-stage moments** (PET-16): kitten→adult at 12 months, senior at 7, birthday.
4. **Copy with the name**: "Everything Luna needs". Cheap, and it compounds the above.

Push guardrails: max one pet push per pet per week, quiet hours, and an off switch in
notification settings. The emotional hook stops working the moment it feels like
spam about your pet.

### PET-10 · Subscribe & save

The design's hub card offers a 10% subscription every 4 weeks. Nothing in the backend
creates recurring orders, and COD can't be charged ahead. v1 ships the same card as
"Remind me every 4 weeks": a scheduled push that opens a cart prefilled with the
usual item. The discount, if any, is a coupon the reminder carries (coupon infra
exists). Real subscriptions wait until reminder uptake shows demand.

### PET-11 · Claims the design makes

| Design text | Source needed |
|---|---|
| "Everything Luna needs, in 30 min" | min ETA of open pet shops in zone, else drop the number |
| Clinic ★ 4.9 | `place_reviews` avg with N threshold (PET-04) |
| "Need ideas? Popular in Maadi" | static per-species list. Rename to "Need ideas?" unless counted from `user_pets` |
| "+12 View all" category tile | real sub-category count |
| Shop deal badge "15% off cat food" | store discount / campaign |
| "Luna's usual, from Pet Corner" | buy-again endpoint (mart page v4, deploy pending) scoped to the pets module |

---

## Phases

1. **Backend foundation** (*built 10-02, deploy pending*): `modules.variant` migration + grocery-typed "Pets" module row
   (zone enable waits on PET-14),
   shared category tree seed (species × needs), `user_pets` migration + API,
   `place_categories.surface` + default-exclude scope + `/api/v1/pets/clinics`
   (nearby, open-now).
   Pet products go in via `catalog_products` (PET-17).
   Also landed: the six grocery seeders now pick `whereNull('variant')`, so a re-run
   can't seed into Pets; client `ModuleType.pets`, `features/pets` data layer
   (models, repository, service, `PetController` with guest draft sent on the first
   signed-in load, cleared on logout).
2. **Client screens** (*built 10-02*): `ModuleType.pets`; `PetHubScreen` (01) as its own scaffold;
   `PetStoreScreen` (02) built from the specialty/food store part files, using the existing
   `PillCartBar` (the cart bar replaces nav); clinic bottom sheet with
   call / WhatsApp / directions; onboarding (00) incl. sex tiles; en + ar keys.
   Also landed: `GET /api/v1/pets/categories` (backend, deploy pending) so the store
   gets the whole species tree with codes in one request; `StorePageController.useCategories`;
   `StoreCategoryItemsScreen.initialSubCategoryId`; 83 en/ar keys. Deviations: PET-20.
3. **Personalisation + content** (*built 10-02 except art*): store opens on the primary pet's species, name in
   headers, best sellers ranked by species; species/category art (PET-15); pet profile
   screen in Profile (edit, add pet, birthday, breed, weight).
4. **Lifecycle pushes** (*built 10-02, deploy pending*): one command,
   `pets:pushes {birthdays|life-stage|replenish|reminders}`, scheduled in `Kernel`;
   `PetPushService` holds the guardrails; `pet_push_log` + `pet_reminders` tables;
   `/customer/pets/usual` + `/customer/pets/reminders`; app `NotificationType.pets` in all
   three tap tables (foreground, background, cold start) → `PetsNavigator.openHub`.
5. **Later**: recurring orders, vaccination reminders, clinic booking.
