# Out-of-Zone "Browse, don't reject" — Waddy Hybrid

**Status: Phase 1 + Phase 2 complete.** Flutter: 0 analyzer errors, debug APK builds. Backend: all PHP lints clean, migration verified against real MySQL.

Repos: `waddi_user` (Flutter) · `waddy_back` (Laravel)
Completed: 2026-08-01

---

## 1. Why

When someone outside the delivery zone opens Waddy, four things need to be true at once: they shouldn't be confused, they shouldn't lose interest, we should capture their demand, and we should convert them the day their area launches. Most apps solve only the first — Talabat blocks at the door, which reads as *"this app doesn't work"* rather than *"this app isn't here yet."*

The chosen approach is the Rabbit-style hybrid: **let them browse everything, replace every delivery promise with "Coming soon", and block only at checkout** — with a capture step at the block.

The key finding from exploring the codebase: **~60% of this was already built and simply not connected.**

- `LocationController.outOfServingZone` was already derived from the saved address's empty `zoneIds` — a single source of truth that survives restart and can't drift.
- Out-of-zone users were already routed to home rather than a wall.
- `closestZoneName` already computed the nearest serving zone.
- The escalation sheets already existed in `guest_gate_helper.dart`.

What was missing was the **honesty layer** (cards still promised "25 min" and "FREE DELIVERY") and the **conversion layer** (no demand capture at all). Plus one live bug.

### The signalling ladder

Each rung is cheaper than the last, so no rung feels like a wall. Rungs 0–2 are what prevent the bait-and-switch — by rung 3 the user has been told three times, so the block reads as consistent rather than as a trick.

| Depth | Surface | Cost to user |
|---|---|---|
| 0 | Home header: "Coming soon · Closest zone: Maadi" | Passive |
| 1 | Every store card: "Coming soon" chip replaces "25 min" | Passive |
| 2 | Store detail: "Coming soon" replaces ETA + fee rows | Passive |
| 3 | First add-to-cart → sheet + Notify me | One tap |
| 4 | Cart → checkout → same sheet | One tap |

### Decisions taken

- **Keep blocking at add-to-cart** (already the behaviour). Not building "save this cart": the cart is server-side with real prices and stock that would be stale by launch, restoring as unavailable items at wrong prices. The block sheet instead becomes the highest-intent Notify-me prompt — it knows exactly which store they wanted.
- **Dropped the tilted "OUT OF ZONE" stamp.** It reads as rejection; the banner reads as invitation.
- **No `contact` field.** FCM is the channel — no typing, no PII, and it actually works.

---

## 2. What shipped — Phase 1 (Flutter)

### 2.1 P0 bug: out-of-zone users could place real orders

`GuestGate.checkoutGuard` was called in exactly one place — inside the **guest login** button. Any logged-in user bypassed the zone gate entirely and could place an unfulfillable order.

Fixed in two layers:

| File | Change |
|---|---|
| `lib/features/checkout/screens/checkout_screen.dart` | Zone check as the first condition in the `place_order` validation chain |
| `lib/features/cart/screens/cart_screen.dart` | Same guard on the `confirm_delivery_details` button |

Both use the synchronous `outOfServingZone` getter, not `checkoutGuard` — the chain is sync, and the user is already past auth. The getter re-reads `SharedPreferences` on every call, so it cannot hold a stale value at tap time.

Layer B alone was insufficient (checkout is reachable directly via `RouteHelper.getCheckoutRoute`); Layer A alone would walk the user through a full checkout screen before rejecting.

### 2.2 The "Coming Soon" primitive

**New:** `lib/features/location/widgets/coming_soon_delivery.dart`

The ~18 delivery-time sites are structurally heterogeneous (icon pill, bare `Text`, `TextSpan` in `RichText`, info row), so one drop-in widget could not serve them all. Instead the module exports the shared predicate plus one shape per render style:

| Export | Purpose |
|---|---|
| `isComingSoon` | The single predicate every site uses |
| `ComingSoonChip` | Pill form for store cards (neutral grey — must not read as a promotion) |
| `ComingSoonText` | Plain text for info rows |
| `comingSoonSpan()` | `TextSpan` for `RichText` sites |
| `ZoneAware` | Wraps a branch so it rebuilds on zone change |
| `ComingSoonBanner` | Rung 0, harvested from the dead `ModuleAppBar` |
| `NotifyMeButton` | Phase 2 capture CTA |

**Sites gated:** `cart_screen` (`arriving_in`), `store_screen` (delivery time + fee + min-order collapse to one honest row), `food_home_screen` (the teal pill + offer badges), `grocery_home_screen` (×2), `module_ribbon_sticker`.

### 2.3 The reactivity trap — solved differently than planned

`outOfServingZone` is a plain getter, not observable. The food-home pill sits inside `GetBuilder<StoreController>`, which **never** rebuilds on a `LocationController.update()`. Wrapping only the chip wouldn't fix it: when the branch currently renders a real "25 min", there is no chip in the tree to do the rebuilding — and that stale delivery promise is exactly the case that must not leak.

The plan called for adding `update(['zone_status'])` at each zone-change path. That relies on every current *and future* `update()` call site remembering the id.

**Instead, `LocationController.update()` is overridden** so all 17 existing call sites automatically refresh zone-status builders. One change; no path can be missed.

```dart
@override
void update([List<Object>? ids, bool condition = true]) {
  super.update(ids == null ? null : <Object>{...ids, kZoneStatusId}.toList(), condition);
}
```

### 2.4 Contextual block copy

`showNoDeliverySheet` fires from four depths. Identical copy each time is what turns a soft block into a wall. It now takes `source` and varies **only the subtitle** (title stays constant so it reads as one message), naming the user's actual area:

- `add_to_cart` → *"We can't deliver to {area} yet — but you can keep exploring."*
- `checkout` / `cart_proceed` → *"We don't deliver to {area} yet. Change your address to order now."*

### 2.5 Cleanup

- **Deleted** `module_app_bar.dart` (never instantiated; mounting it would have produced two stacked headers) and `out_of_zone_hint_widget.dart` (commented out at its only call site). 0 dangling references.
- **Removed 8 dead strings** from `en.json`/`ar.json`, with a script asserting the live look-alikes (`service_not_available_in_this_area`, used by deliveryman/store registration) survived.
- **Re-pointed `serving_zones_screen`** via a new link in the delivery-locations sheet, so the polygon map isn't orphaned.

---

## 3. What shipped — Phase 2 (demand capture, both sides)

### 3.1 Backend

| File | Purpose |
|---|---|
| `database/migrations/2026_07_31_120000_create_zone_requests_table.php` | The table |
| `app/Models/ZoneRequest.php` | Model + `scopeNear` bounding box |
| `app/Http/Controllers/Api/V1/ZoneRequestController.php` | `store` + `status` |
| `app/Http/Controllers/Admin/Zone/ZoneRequestAdminController.php` | Admin aggregation |
| `app/Services/ZoneLaunchNotifier.php` | Fires pushes when a zone goes live |
| `resources/views/admin-views/zone/requests.blade.php` | The expansion dashboard |

**Endpoints** (`routes/api/v1/api.php`), both under `apiGuestCheck` + `throttle:30,1`:

```
POST /api/v1/zone-request          → { message, total_requests_in_area }
GET  /api/v1/zone-request/status   → { requested, total_requests_in_area }
```

**Admin:** `zone/requests` — demand by area (with a *reachable* %), where-they-stopped, most-wanted stores, IP/timestamp audit tail.

**Zone activation** (`ZoneController::updateStatus`) now calls `ZoneLaunchNotifier::notifyForZone()`. This is what makes "we'll tell you the moment we launch" an honest promise rather than a broken one. The notifier swallows its own errors — a push outage must never roll back a zone activation.

### 3.2 Three design decisions worth keeping

**Dedupe by identity, never by coordinates.** An early draft rounded lat/lng to ~3dp (~111m). At Cairo apartment density that merges genuinely distinct households into one row, under-reporting the exact signal the expansion roadmap depends on.

**Do not use nullable `user_id` + nullable `guest_id` with a composite unique index — it silently fails.** MySQL treats `NULL` as never equal to `NULL` for unique constraints. With one column always null, *every* row contains a NULL in the key, so InnoDB treats every row as distinct and permits unlimited duplicates. The constraint would look correct in the migration and enforce nothing — the worst failure mode for a table whose credibility is the whole point.

The fix mirrors the existing `carts` convention: one non-nullable `user_id` holding either a users.id or a guests.id, disambiguated by `is_guest`, with `unique(user_id, is_guest)`. Both columns non-nullable, so the index binds. It also makes the app-level `updateOrCreate` key and the DB constraint identical, closing the double-tap race.

**No per-identity time throttle.** It would contradict the dedupe design (tapping Notify-me on store A then store B in one session is normal; a window check rejects the second before `updateOrCreate` runs, so `source`/`store_id` never refresh) and it wouldn't stop the attack anyway — a spam script mints a fresh `guest_id` per request. The unique constraint handles identity abuse for free. Volume abuse is IP-shaped, hence `throttle:30,1` — deliberately loose, because Egyptian carriers run heavy CGNAT and a tight cap would reject real users during exactly the launch-post spike this data matters most for.

### 3.3 Frontend

- `zone_request_model.dart` + repository/service methods
- `submitZoneRequest()` folded into `LocationController` (it already owned the three inputs: position, closest zone, zone list)
- **Notify-me promoted to the primary button** in `showNoDeliverySheet` — because that sheet already fires from all four rungs, one edit lights up the whole ladder
- Add-to-cart passes `storeId` — the highest-intent signal in the app

**Resilience:** on failure the request is parked in `SharedPreferences` and replayed on next launch, and the success state still shows — the tap is a promise, and a network blip is our problem, not the user's.

**Analytics idempotency:** `zone_request_submitted` fires **once, at tap time**. The retry path emits `zone_request_retry_succeeded` instead, so a response lost in transit can't double-count the very funnel metric used to judge the feature.

**Push-permission denial is detected, not papered over.** If notifications are denied, the request is still recorded (the demand signal doesn't depend on the channel) but the confirmation shows count-only copy with **no** notification promise. `has_push` on the row tells the admin view how much of an area's demand is actually reachable at launch.

---

## 4. Verification performed

### Automated

| Check | Result |
|---|---|
| `flutter analyze` (whole project) | **0 errors** |
| `flutter build apk --debug` | **Builds** |
| `php -l` on all 10 touched backend files | **Clean** |
| `en.json` / `ar.json` parse + key assertions | **Valid**, live keys intact |
| Blade compiles (`artisan view:cache`) | **OK** (cache cleared after) |

### Database — run against an isolated scratch DB, then dropped

The dedupe design was the risky part, so it was tested directly rather than assumed:

| Test | Result |
|---|---|
| Schema | `user_id` + `is_guest` both `null=NO` |
| **Raw duplicate insert, bypassing `updateOrCreate`** | **Correctly rejected** — this is the NULL-trap test; `updateOrCreate` would have masked a broken index |
| Guest 5 vs user 5 | Distinct rows (same integer, different namespace) |
| Two users at identical coordinates | **Two rows** — the same-building regression coordinate-rounding would have caused |
| `scopeNear` | 3 near / 1 far correctly excluded |
| `EXPLAIN` on the count query | `type=range`, `key=zone_requests_latitude_longitude_index` — **no full scan** |

Scratch DB dropped; the real database was never touched (`zone_requests` still shows `Pending`).

### Not verified — needs a device / real environment

- **In-session address change** (out-of-zone → Maadi without restarting). The `update()` override should cover it, but this is the silent-failure case: a fresh install always starts correct, so the bug only appears at step 2 below.
- **Arabic/RTL chip overflow** on the food and grocery cards.
- **Live HTTP endpoint** and **FCM push end-to-end** — no working local DB, no device.

---

## 5. Deploy / execute

### Backend

```bash
cd /Users/mac/Waddi/waddy_back
php artisan migrate          # creates zone_requests
php artisan route:clear && php artisan config:clear && php artisan view:clear
```

> **Note:** `php artisan migrate` fails on the local machine at an unrelated 2022 migration (`Table 'multi_food_db.users' doesn't exist`) — the local DB is essentially empty. Run where the schema is real.
>
> `php artisan route:list` also fails locally inside `ConfigController::__construct`. Verified this fails identically with the new routes stashed, so it is environmental — but it does mean route registration was never confirmed at runtime. **Worth a quick check after deploy:**
> ```bash
> php artisan route:list --path=zone-request
> ```

### Frontend

```bash
cd /Users/mac/Waddi/waddi_user
flutter pub get
flutter run          # or: flutter build apk --release
```

No new dependencies were added. `firebase_messaging` was already in `pubspec.yaml`.

### Manual test script (in order)

**1 — The P0 bug (must reproduce before, fail after)**
1. Set an in-zone address (Maadi), log in, add items to a cart.
2. Change the delivery address to out-of-zone (Nasr City) — **do not restart**.
3. Checkout → **Place Order** → must show the no-delivery sheet, no order placed.
4. Repeat via the cart's "confirm delivery details" button.

**2 — In-session address change (the silent-failure case)**
1. Start out-of-zone. Confirm banner + chips on home, store detail, cart.
2. **Without restarting**, change to Maadi → banner disappears, every chip reverts to a real time, free-delivery badges and speed stickers return.
3. Reverse it → chips reappear everywhere, no stale "25 min".
4. Check a `GetBuilder<StoreController>`-scoped card specifically (`food_home_screen.dart:977`) — staleness surfaces there first.

**3 — Notify-me**
- Tap Notify me → success state, then reopen the sheet → shows "You're on the list", never re-prompts.
- Deny notification permission → row still created with `has_push = 0`, confirmation shows count-only copy with **no** notification promise.
- Point `zoneRequestUri` at a missing endpoint → success still shows, `zone_request_failed` logged, replayed next launch, and the retry emits `zone_request_retry_succeeded` **not** a second `zone_request_submitted`.

**4 — Backend**
- Same identity taps on store A then store B seconds apart → **both accepted**, one row, `store_id` updated to B. (A per-identity throttle would fail this — that's why there isn't one.)
- Simulate CGNAT: 25 requests from distinct identities sharing one IP → all accepted.
- Activate a zone in admin → requesters with `has_push = 1` receive the launch push and flip to `notified = 1`.

**5 — Arabic**
- Switch to Arabic and check `food_home_screen.dart:977` and `store_card_with_distance.dart:183` for chip overflow in tight rows.

---

## 6. Files changed

### `waddi_user` (Flutter)

**New**
```
lib/features/location/widgets/coming_soon_delivery.dart
lib/features/location/domain/models/zone_request_model.dart
```

**Deleted**
```
lib/features/home/screens/modules/widgets/module_app_bar.dart
lib/features/location/widgets/out_of_zone_hint_widget.dart
```

**Modified**
```
lib/features/checkout/screens/checkout_screen.dart      P0 zone gate
lib/features/cart/screens/cart_screen.dart              P0 zone gate + chip
lib/features/cart/controllers/cart_controller.dart      storeId passthrough
lib/features/store/screens/store_screen.dart            delivery block gating
lib/features/home/screens/modules/food_home_screen.dart
lib/features/home/screens/modules/grocery_home_screen.dart
lib/features/home/screens/modules/widgets/module_ribbon_sticker.dart
lib/features/home/widgets/home_hero_banner_widget.dart  banner mount
lib/features/home/screens/home_screen.dart              retry queue init
lib/features/location/controllers/location_controller.dart  update() override + submitZoneRequest
lib/features/location/domain/{repositories,services}/*   zone request plumbing
lib/helper/guest_gate_helper.dart                       contextual copy + Notify me
lib/util/app_constants.dart                             URIs + prefs keys
assets/language/{en,ar}.json                            +5 keys, −8 dead
```

### `waddy_back` (Laravel)

**New**
```
database/migrations/2026_07_31_120000_create_zone_requests_table.php
app/Models/ZoneRequest.php
app/Http/Controllers/Api/V1/ZoneRequestController.php
app/Http/Controllers/Admin/Zone/ZoneRequestAdminController.php
app/Services/ZoneLaunchNotifier.php
resources/views/admin-views/zone/requests.blade.php
```

**Modified**
```
routes/api/v1/api.php                              zone-request routes + throttle
routes/admin/routes.php                            admin requests route
app/Http/Controllers/Admin/Zone/ZoneController.php launch notification hook
resources/lang/{en,ar}/messages.php                +5 keys each
```

---

## 7. Corrections made to the original plan

Found while reading the code; each changed the implementation:

1. **`guest_id` is a bigint, not a string.** There is a real `guests` table with `id` and `fcm_token`. So `user_id` is `foreignId`, matching `carts` exactly.
2. **`Helpers::get_customer()` does not exist.** The real optional-auth idiom is `$request->user instanceof \App\Models\User`.
3. **Longitude delta must divide by `cos(latitude)`.** The plan's fixed `0.031` is right for Cairo but wrong elsewhere; `scopeNear` computes it, with a guard near the poles.
4. **Ribbon stickers were narrowed.** The plan said drop all stickers out of zone. But only "Speedy", "Under 30 min" and "Free delivery" are delivery claims — **"Top rated" and "Hot deals" stay true** regardless of whether we deliver. Dropping them would strip exactly the browsing appeal this feature exists to preserve.
5. **Two planned P0 chip sites were already dead code** (`cart_screen.dart:331`, `:361` — inside unreferenced methods). Skipped; gated the live `arriving_in` row instead.
6. **`update()` override instead of ~18 manual `update(['zone_status'])` calls** — see §2.3.

---

## 8. Deliberately not built

- **P2/P3 long-tail chip sites** — `module_view.dart`, `store_card.dart`, `store_card_with_distance.dart`, the `views/` files, web. Mechanical, same pattern, low traffic.
- **A vote widget or voting screen.** The `vote_*` strings in `en.json` belong to the **PlacesToVisit** gamification module and are unrelated — reusing them would collide. One Notify-me tap in a sheet the user is already reading captures the same signal without a competing feature.
- **"Save this cart for launch."** See §1 — stale prices and stock would make it restore as a broken cart.
- **A `contact` field.** FCM covers it without typing or PII.
