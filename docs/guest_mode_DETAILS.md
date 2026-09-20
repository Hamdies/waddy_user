# Waddy Guest Mode — Full Details

> Complete record of the guest-mode effort: the analysis, the decisions, everything
> built, what was reverted and why, and what's still open. Companion to
> `docs/guest_mode_plan.md` (the plan) — this file is the "what actually happened."
>
> **Status:** implemented, hardening phase, `flutter analyze` clean (0 errors).
> Everything gated behind the remote `guest_browse_status` flag — flag off = the
> old login-first flow is untouched.

---

## 1. The goal

Let anyone open Waddy and reach a populated, in-zone home in one tap — no phone
number — then convert to an account only at the moment it actually matters
(checkout, vote, favourite, profile, etc.). Deeply inspired by the Rabbit
reference screens the user shared.

## 2. The core insight

The app gates every screen on **a saved address with valid zone ids — not on
login**. `route_helper.getRoute()` sends anyone without a saved address to
`AccessLocationScreen`; login state is never checked there. So a "guest" is
simply a session with **(a guest token) + (a zone-valid address)**. Guest mode's
real job is to produce both silently so a guest lands on the same home a
logged-in user sees.

**Guest mode is a location problem first, an auth problem second.**

## 3. What already existed (this was ~70% built)

Verified in source before writing anything. Reused, not reinvented:

- `helper/guest_bootstrap_helper.dart` — silent guest login + zone-valid address (GPS or Maadi seed) → home.
- Remote flag `guest_browse_status` (`configModel.guestBrowseStatus`); defaults on in `kDebugMode`.
- `auth_controller.guestLogin()` / `AuthHelper.isGuestLoggedIn()` — guest session (saves a `guest_id`, **no Bearer token**).
- `location_controller.setOutOfServingZone()` + `out_of_zone_hint_widget.dart` — out-of-zone state & hint pill.
- `serving_zones_screen.dart` — the "All delivery Locations" list (reference screen 4).
- `auth_bottom_sheet.dart` — the soft phone→OTP sheet, already backs up & merges the guest cart.
- `splash_route_helper.dart::_handleUserRouting()` — the entry resolver (Gap 1, already built).
- `splash_route_helper.dart::_forEvictedGuestRouteProcess()` — 3-strike `guestBootstrapFailCount` backoff (Gap 6, already built).

## 4. Decisions locked with the user

| Area | Decision |
|---|---|
| Auth walls | **Soft phone→OTP sheet everywhere**; retire hard middleware on browse-adjacent routes. |
| Guest-open surfaces | Home, stores, items, search, **cart** (wall at checkout), Places/Spots. Local favourites **not** in scope → favouriting gates. |
| Returning guest | Straight to cached home, **re-verify zone in the background**. |
| Guest cart | **Server cart via `guest_id`** — backend already supports it (`is_guest`) and migrates to the user on login (`check_guest_cart`). Client just sends `guest_id`. (An earlier local-cart workaround was reverted — see §6.7.) |
| 401 handler | **Reverted** to original for the hardening phase (see §8). |

## 5. Amendments A–D (edge cases caught before building)

- **A — Checkout ordering.** The zone gate fires FIRST at checkout; an out-of-zone guest gets NO DELIVERY *before* the OTP sheet ever shows. Never make someone sign up for an order we can't fulfil. `checkoutGuard()` = zone (sync re-check) → then account.
- **B — Address carry-over.** On login, an out-of-zone guest must NOT persist the Maadi seed. Carry the **real GPS** location (or nothing → AccessLocationScreen), and carry the `outOfServingZone` flag into the authed session. Required a bootstrap fix: the real GPS **coordinates** were being discarded (only a label string survived).
- **C — Far-away vs checkout.** The "you're a bit far away" distance-confirm (reference screen 2) does **not** exist yet — net-new work. It belongs at address-selection, NOT checkout. `checkoutGuard()` stays two gates, never three. Zone beats far-away.
- **D — Zone gate is unconditional.** Because Amendment B creates logged-in out-of-zone accounts for the first time, the checkout zone gate runs for **guest AND user**. Zone is an *outer* precondition, not inside `requireAccount()` (which no-ops for logged-in users and would let them slip through).

## 6. What was built this session

### 6.1 Bootstrap: preserve real GPS coords (unblocks Amendment B)
- `location_controller.dart` — `setOutOfServingZone()` now also carries `realLat`/`realLng` (new getters `outOfZoneRealLat/Lng`), populated wherever out-of-zone is detected (`refreshOutOfZoneStatus` too).
- `guest_bootstrap_helper.dart` — captures real GPS coords at the 404 branch and threads them through `_ResolvedAddress` → `setOutOfServingZone`. Previously only a display `String?` label survived; the coordinates were thrown away.

### 6.2 The central guard — `helper/guest_gate_helper.dart` (NEW)
- `GuestGate.requireAccount(onGranted, reason:)` — generic soft-sheet guard; no-ops for logged-in users, opens the phone→OTP sheet for guests.
- `GuestGate.checkoutGuard(onGranted)` — two-gate: **unconditional** `refreshOutOfZoneStatus()` → out-of-zone → NO DELIVERY sheet (stop); in-zone → `requireAccount`.
- `GuestGate.showNoDeliverySheet()` — the "No delivery there" escalation (reference screen 3) → serving-zones list.
- Both sheets present via `WidgetsBinding.endOfFrame` + `Get.overlayContext` to avoid the "deactivated widget's ancestor" crash when triggered mid-rebuild.

### 6.3 Auth-wall matrix applied
- `checkout_screen.dart` — guest CTA routes through `GuestGate.checkoutGuard` (zone-first).
- `route_helper.dart` — retired `AuthGuardMiddleware` on the **cart** route (guests build carts; wall at checkout).
- `place_vote_action.dart`, `podium_winner_card.dart`, `podium_runner_card.dart` — vote gates converted from hard sign-in redirects to `requireAccount` (soft sheet). These duplicate hard-redirect gates were the cause of "voting bounces to auth."
- `place_details_screen.dart` — place-favourite → soft sheet.
- `custom_favourite_widget.dart` — item favourite → soft sheet.

### 6.4 Return path — background zone re-verify (Gap 2)
- `splash_route_helper.dart` — returning-guest branch now fire-and-forgets `refreshOutOfZoneStatus()` before landing home.

### 6.5 Entry-resolver self-heal (fixes "restart → auth")
- `splash_route_helper.dart` — a single failed bootstrap used to consume the intro flag without creating a guest session, trapping the user on unified auth on **every** later restart. The resolver now re-attempts bootstrap (bounded by the 3-strike counter) whenever the flag is on and the user isn't logged in — self-healing across restarts.
- Added a `kDebugMode` diagnostic line printing the exact entry state on launch: `[Waddy] entry resolver → loggedIn=… guest=… savedAddr=… showIntro=… guestBrowse=… failCount=…`. **Kept in** until add-to-cart is verified end-to-end.

### 6.6 Login carry-over — `helper/guest_carryover_helper.dart` (NEW)
- `GuestCarryover.onLogin()` — fired from the auth sheet's single success choke point. In-zone guest → keep address; out-of-zone guest → save the real GPS location (or clear → AccessLocationScreen if no coords); never the Maadi seed.

### 6.7 Guest cart = SERVER cart via `guest_id` (final answer — the "everything → auth" fix)

**Root cause of "everything → auth":** the client wasn't sending `guest_id` on
cart requests. `OnlineCart.toJson()` omitted it, so the backend rejected the
call (a validation **403**, not a real auth failure), and the client's global
handler treats any non-200 as eject-to-auth.

**Backend was already done.** `waddy_back/CartController` supports guest carts
natively — every method validates `guest_id` (required when unauthenticated),
sets `is_guest = 1`, and scopes by it. And `CustomerAuthController` calls
`check_guest_cart($user, guest_id)` on login, which **re-parents every guest
cart row to the user automatically**. The client already sends `guest_id` with
login. So the whole guest→user handoff was wired end-to-end server-side — the
only gap was the client not sending `guest_id` on the cart ops themselves.

**Fix (client only, no backend change):**
- `cart_repository.dart` — a `_guestId` getter (guest_id when not logged in, else
  empty) is injected into **all five** cart requests: add & update (body),
  list, remove-item, remove-all (query param). This is what the backend has
  always expected.
- `cart_controller.dart` — the earlier **local-cart workaround was reverted**.
  `addToCartOnline` / `updateCartOnline` / `clearCartOnline` no longer branch on
  login; guests and users both use the server cart. (The `localFallback` /
  `localIndex` params are retained but unused, to avoid re-churning ~9 call
  sites; the call-site edits from the local-cart attempt are now harmless.)
- `mergeGuestCartToServer` — simplified to **just refresh from the server**. The
  backend already migrated the guest cart on login; re-pushing a local backup
  would double items or race the migration. The `_guestCartBackup` field,
  `backupGuestCart()`, and `_toOnlineCart()` were removed as dead code.

**Net:** one cart code path, cross-device, guest→user migration handled by the
backend. No local cart, no merge step.

### 6.8 Translations
- `en.json` / `ar.json` — added `no_delivery_there`, `no_delivery_there_desc`, `view_all_delivery_locations`, `got_it` for the NO DELIVERY sheet.

### 6.9 Analytics (wired)
Guest-flow events already emit via `AnalyticsHelper.log`:
- `account_required` `{reason}` — soft wall shown (checkout/vote/favourite/…).
- `checkout_blocked_out_of_zone` `{auth_state: guest|user}` — Amendments A/D zone short-circuit (splits guest vs user, so you can see whether the new logged-in-out-of-zone case actually fires).
- `no_delivery_sheet_shown` / `no_delivery_sheet_view_zones` — NO DELIVERY escalation.
- `guest_carryover` `{result: saved_real_gps | cleared_no_coords | error}` — Amendment B login carry-over outcome.
- `checkout_auth_sheet_opened|success|abandoned` — soft-sheet funnel.

**Note:** these measure *walls and carry-over*, NOT 401s. The signal that gates
the §8 flip is separate — see §6.10.

### 6.10 401-sweep instrumentation (debug only)
`api_checker.dart` logs every 401 with its endpoint and auth-state:
`[Waddy] 401-SWEEP → authState=guest|user|none|none-FLAG_ON-SUSPECT endpoint=/api/…`.
Behaviour is unchanged (still ejects). **A 401 logged with `authState=guest`
names a not-guest-safe endpoint to fix.** This is the hard evidence the §8 flip
depends on — "sweep finds no guest 401" is now something you can point at.

**The `none` mislabel guard.** A `none` 401 (no user token, no `guest_id`) is
only *expected* when guest-browse is OFF. A `none` 401 **while the flag is ON**
is suspicious — it can be a guest-safety bug wearing the wrong label: a call
racing an in-flight bootstrap, or a session just cleared. Those are tagged
**`none-FLAG_ON-SUSPECT`** and must be treated like a `guest` hit during the
sweep, not dismissed as benign.

**Race analysis (verified, not assumed).** The bootstrap path is race-safe:
`guestLogin()` awaits `saveSharedPrefGuestId` before returning →
`_ensureGuestSession()` awaits that → `Future.wait([...])` awaits both →
`_applyAndNavigate()` (which calls `HomeScreen.loadData` and navigates) runs
only after. So `guest_id` is durably persisted **before** any mounted screen
fires its first API call — no window where home renders as `none`. The only
theoretical `none` window is the sub-ms inside `guestLogin` between the 200 and
the prefs write, when no screen is mounted. The `-FLAG_ON-SUSPECT` tag is the
belt-and-suspenders so even an unforeseen race can't hide behind a benign label.
(Note: `AuthController._guestLoading` exists but is dead/never set — no reliable
in-flight flag today; the flag-on heuristic is used instead.)

Remove alongside the 401-guard revisit (§8).

## 7. Files changed

**New:**
- `lib/helper/guest_gate_helper.dart`
- `lib/helper/guest_carryover_helper.dart`

**Modified:**
- `lib/features/location/controllers/location_controller.dart`
- `lib/helper/guest_bootstrap_helper.dart`
- `lib/helper/splash_route_helper.dart`
- `lib/helper/route_helper.dart`
- `lib/features/auth/widgets/auth_bottom_sheet.dart`
- `lib/features/checkout/screens/checkout_screen.dart`
- `lib/features/cart/controllers/cart_controller.dart`
- `lib/features/cart/domain/repositories/cart_repository.dart` (sends `guest_id` on all cart ops)
- `lib/common/widgets/item_bottom_sheet.dart`
- `lib/features/item/controllers/item_controller.dart`
- `lib/features/item/screens/item_details_screen.dart`
- `lib/features/item/widgets/details_web_view_widget.dart`
- `lib/features/cart/screens/cart_screen.dart`
- `lib/features/places/widgets/podium_winner_card.dart`
- `lib/features/places/widgets/podium_runner_card.dart`
- `lib/features/places/widgets/place_vote_action.dart`
- `lib/features/places/screens/place_details_screen.dart`
- `lib/common/widgets/custom_favourite_widget.dart`
- `assets/language/en.json`, `assets/language/ar.json`

## 8. The 401 handler — DEFERRED decision (not closed)

An earlier build made `api_checker.dart` swallow 401s for guests. **Reverted.**
`checkApi` is back to original: **any 401 → eject to auth**, for everyone.

- **Why revert is correct NOW (hardening):** eject-to-auth is the loudest
  possible failure — it makes every not-yet-guest-safe endpoint impossible to
  miss, surfacing them for free. A silent swallow/log would mask exactly the bug
  we're hunting.
- **Why it MUST be revisited before GA:** eject-to-auth is bad UX for a real
  guest hitting a **transient** 401 (flaky network, backend hiccup) — a
  legitimate user kicked to login for a non-bug reason.
- **Production answer:** a permanent guest-safe guard + silent error logging
  (`if (!AuthHelper.isLoggedIn()) { logError(response); return; }` in
  `checkApi`).
- **Trigger to flip (now measurable):** the §9.1 guest-open surface sweep runs
  clean — **zero `[Waddy] 401-SWEEP → authState=guest` lines** across every §4
  surface (§6.10 provides that signal). Not "seemed fine" — no guest-401 lines.
- **Do not** let "reverted" quietly become "permanent" by default.

## 9. Still open / follow-ups

1. **Guest-open surface sweep (the real gating test).** The cart bug proved the
   pattern — an online call assuming a Bearer token — can exist on ANY guest-open
   surface, not just cart. With the 401 handler back to blanket eject-to-auth,
   any surface with the same bug ejects the whole app on first tap (loud = good).
   So the test is not "does cart work" — it's **walk every §4 guest-open surface
   once as a guest, console open, and confirm no `[Waddy] 401-SWEEP →
   authState=guest` line appears.** Explicit checklist:

   - [ ] **Home** — modules, banners, hero, current-order area render; no 401.
   - [ ] **Stores** — open a store, scroll its items; no 401.
   - [ ] **Items** — open an item detail / bottom sheet; no 401.
   - [ ] **Search** — run a query, open a result; no 401.
   - [ ] **Cart** — add from item sheet, item detail, and cart-screen suggestions; edit qty; clear; no 401. End-to-end: guest → cart → **checkout** (in-zone → soft sheet; out-of-zone → NO DELIVERY, not the sheet).
   - [ ] **Places / Spots** — browse leaderboard, open place details; no 401. Vote/favourite should show the SOFT SHEET (not eject).
   - [ ] **Address / zone** — out-of-zone guest sees the stamp + hint; NO DELIVERY sheet reachable.

   Any `authState=guest` **or `authState=none-FLAG_ON-SUSPECT`** 401 in the
   console = a not-guest-safe endpoint (the latter is a guest-safety bug that
   raced/lost its label — see §6.10). Fix it at that endpoint before calling the
   sweep clean. A plain `none` (flag off) is expected and fine.
2. **Remove both debug lines** (`entry resolver` + `401-SWEEP`) once the sweep
   above is clean and has been run a few times without surprises.
3. **Revisit the 401 guard** per §8 — the trigger is a *clean sweep* (no
   `authState=guest` 401s), which §6.10 now makes measurable rather than a guess.
4. **Far-away distance-confirm (reference screen 2)** — net-new, Phase 3. Fires at
   address-selection only; zone beats far-away.
5. **Full-screen gated routes** (profile / wallet / orders / favourite-screen) still
   use hard `AuthGuardMiddleware`. Converting to soft sheets needs guest-safe empty
   states behind each screen first — deliberately deferred, not faked.
6. **Onboarding ordering** — `disableIntro()` runs before bootstrap; the resolver
   self-heal covers the failure case, but reordering so intro is only consumed on a
   confirmed bootstrap would make first-run failures retry onboarding naturally.

## 10. How to turn it off

Everything is behind `guest_browse_status`. Flag off → the app behaves exactly as
before (login-first). Safe to ship dark and enable per-region.
