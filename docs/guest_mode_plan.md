# Waddy Guest Mode — Consolidated Plan & Amendments

> Status: **planned, ship-ready, not yet built.** Everything stays behind the
> remote `guest_browse_status` flag; flag off = today's login-first flow is
> untouched. Derived from reading the live codebase (files cited inline).

---

## 0. Framing

Guest mode is **~70% already built** in the codebase. This is a **hardening &
consolidation** plan, not greenfield. The plan consolidates a scattered entry
decision, defines one auth-wall matrix, and closes six specific gaps + four
amendments.

### Core insight
The app gates on **a saved address with valid zone ids — not on login**.
`route_helper.getRoute()` sends anyone without a saved address to
`AccessLocationScreen` (`AddressHelper.getUserAddressFromSharedPref() == null`,
`route_helper.dart:1273`). Login state is never checked there. So a "guest" is
just a session with **(guest token) + (zone-valid address)**, and bootstrap
exists to produce both silently. **Guest mode is a location problem first,
auth problem second.**

---

## 1. What already exists (verified in source)

| Capability | Lives in | State |
|---|---|---|
| Silent guest bootstrap (GPS/seed addr + guest login → home) | `helper/guest_bootstrap_helper.dart` | works |
| Remote flag `guestBrowseEnabled` | config · `guest_browse_status` | works |
| Guest session/token | `auth_controller.guestLogin()` · `AuthHelper.isGuestLoggedIn()` | works |
| Out-of-zone state + hint pill | `location_controller.setOutOfServingZone()` · `out_of_zone_hint_widget.dart` | works |
| Serving-zones map/list ("All delivery Locations") | `location/screens/serving_zones_screen.dart` | works |
| Checkout auth sheet + cart merge | `auth/widgets/auth_bottom_sheet.dart` (`backupGuestCart()`) | works |
| Address gate (no addr → AccessLocationScreen) | `route_helper.getRoute()` | works |
| Hard auth redirect (!isLoggedIn → unified auth) | `auth_guard_middleware.dart` | **retire on browse routes** |
| Unified entry decision (first-run / returning-guest / user) | split across splash · route_helper · onboarding | **consolidate** |

---

## 2. Entry flow (one decision tree)

```
App cold start
 └─ Saved address with zoneIds?
     ├─ yes → logged in?
     │         ├─ user  → Home (logged-in)
     │         └─ guest → Home (guest) + background zone re-verify
     └─ no  → first run (intro not seen)?
               ├─ yes → Onboarding (3 screens) → [flag check below]
               └─ no  → guest_browse_status ON?
                         ├─ yes → bootstrapGuest()
                         │          ├─ ok   → Home (guest) + bg re-verify
                         │          └─ fail → Unified Auth
                         └─ no  → Unified Auth
```

- **Returning guest:** straight to cached home, then a **non-blocking**
  background zone re-check updates `outOfServingZone` / the "OUT OF ZONE" stamp
  if they moved. No re-prompt, no open-latency.
- **Bootstrap failure:** fall back to Unified Auth. Use the existing
  `guestBootstrapFailCount` pref to stop retrying after repeated silent
  failures; reset to 0 on any success.

---

## 3. Location engine

`bootstrapGuest()` runs guest-login and address-resolution in **parallel**
(~one round trip), never throws, never hard-prompts.

```
bootstrapGuest
 ├─ soft-ask GPS permission (once)
 └─ parallel:
     ├─ guestLogin()
     └─ resolveAddress:
         GPS granted & in-zone → use GPS address (real coords)
         GPS granted & 404     → Maadi seed + flag outOfZone + keep real label
         GPS denied/timeout    → Maadi seed
 → save addr → Home
```

### Three location outcomes (map to reference screens)
- **In zone** (`outOfServingZone=false`) → normal home.
- **Out of zone** (`outOfServingZone=true`) → browse on Maadi seed + "OUT OF
  ZONE" stamp + "Coming soon / View All Delivery Locations" (ref screens 3/4/5).
- **Far from store** → in-zone address but far from the specific store being
  viewed → distance-confirm sheet (ref screen 2). **Separate axis** — see
  Amendment C.

---

## 4. Auth-wall matrix

Decision: **soft phone→OTP sheet everywhere** a wall is needed; retire the hard
middleware redirect on browse-adjacent routes. Guest keeps their place; cart /
context merges on success.

| Surface / action | Guest | Behavior |
|---|---|---|
| Home / stores / items / search | **Open** | full browse |
| Cart (add / edit / totals) | **Open** | local cart, no wall while building |
| Places / Spots (browse) | **Open** | browsable |
| Checkout | **Soft wall** | zone gate → phone→OTP → merge cart → resume |
| Vote (Spots) | Soft wall | sheet, then complete vote |
| Favourite | Soft wall | sheet on tap (local favourites **not** in scope) |
| Profile / Orders / Wallet / Loyalty / Refer / Chat / Notifications | Soft wall | sheet |

**One reusable guard:** `requireAccount(onGranted)` — logged-in → run action;
guest → back up context, open sheet, run action on success. `requireAccount()`
is **auth-only** and no-ops for logged-in users (this matters for Amendment D).

---

## 4b. Guest cart = local (found during build)

### The 401 handler: reverted ON PURPOSE for this phase — REVISIT before GA

An earlier build made `api_checker.dart` swallow 401s for guests. **Reverted.**
`checkApi` is back to original: **any 401 → eject to auth**, for everyone.

**Why the revert is correct RIGHT NOW (hardening phase):** eject-to-auth is the
loudest possible failure. It makes every not-yet-guest-safe endpoint impossible
to miss, so it surfaces them for free. A silent swallow (or even a silent log)
would only help someone actively watching logs — and would *mask* exactly the
bug we're hunting. During hardening, loud > graceful.

**Why this MUST be revisited before shipping to real users (DECISION, not a
note):** once the known endpoints are swept guest-safe, eject-to-auth becomes
*bad UX* — a legitimate guest hitting a **transient** 401 (flaky network,
backend hiccup) gets kicked to login for a reason that has nothing to do with a
code bug. The production answer is a **permanent guest-safe guard + silent
error logging** (don't eject a non-logged-in session; log the failure).

**Trigger to flip it:** when add-to-cart is verified end-to-end (guest → cart →
checkout) AND a sweep finds no guest endpoint still 401ing, re-introduce the
guard (`if (!AuthHelper.isLoggedIn()) { logError(response); return; }` in
`checkApi`). Do **not** let "reverted" quietly become "permanent" by default —
this is a deferred decision, not a closed one.

**Add-to-cart for guests → local cart.** `OnlineCart.toJson()` sends no
`guest_id` and the cart request uses the guest Bearer header. Decision:
   **guest cart is local, merges at checkout** (`mergeGuestCartToServer`).
   `CartController.addToCartOnline/updateCartOnline/clearCartOnline` now route
   guests to the on-device cart. `addToCartOnline`/`updateCartOnline` take an
   optional `localFallback: CartModel` (+ `localIndex`) so callers with the
   source model land the item locally; callers without one safely no-op
   instead of 401ing. Wired at ALL cart add/update entry points:
   item_bottom_sheet, item_controller, item_details (quick-add, bundle,
   _handleAddToCart add+update), cart_screen (suggested-item quick-adds), and
   details_web_view (add + update). Every guest add/update/clear now routes to
   the local cart; no cart surface 401s a guest anymore.

## 5. Data continuity (guest → account)
- **Cart** — already handled (`backupGuestCart()` → merge on OTP success).
- **Address** — carry over per Amendment B (real location, never the seed).
- **Guest number** — `saveGuestNumber()/getGuestNumber()` exist; prefill OTP field.

---

# Amendments (A–D) — all ship-ready, mutually consistent

## Amendment A — Checkout ordering for out-of-zone guests
**Zone gate short-circuits before the OTP sheet ever shows.** Never make
someone sign up and then tell them "no delivery."

`checkoutGuard()` order (first failure wins):
1. **Zone gate first.** Re-run `refreshOutOfZoneStatus()` **synchronously**
   against the *current* delivery address (don't trust the possibly-stale flag).
   If out-of-zone → **NO DELIVERY** screen. **Stop — OTP never opens.**
2. In-zone → `requireAccount(resumeCheckout)`.
3. On success → merge guest cart → resume.

Zone is a **precondition ahead of** `requireAccount()`, not a step inside it —
keeps `requireAccount()` generic/reusable for every gated surface.
Analytics: `checkout_blocked_out_of_zone` logged **before** any auth event.

## Amendment B — Address carry-over uses real location, never the seed
On login success, branch on the flag:
- **In-zone guest** (`outOfServingZone=false`): carry the working address as-is
  (it's real & zone-valid).
- **Out-of-zone guest** (`outOfServingZone=true`): **do NOT carry the Maadi
  seed.**
  - Real GPS coords+label available → save *those* (even though out-of-zone).
  - Unavailable → carry **nothing**; new account starts addressless → routes to
    `AccessLocationScreen` to pick a real one. Blank-and-prompt is correct; a
    silently-wrong Maadi is not.
- **Also carry the `outOfServingZone` flag** into the authenticated session —
  don't reset on login. Otherwise a real-GPS address renders a Maadi-style home:
  same silently-wrong outcome moved one layer down.

**Prerequisite bootstrap fix (currently unbuildable without it):**
`_resolveAddress` today discards the real GPS **coordinates** for out-of-zone
guests and keeps only `outOfZoneRealAddress` as a display `String?`
(`guest_bootstrap_helper.dart:143`). Must **also preserve real lat/lng** —
either extend `_ResolvedAddress` with `outOfZoneRealLat/Lng` or store the real
`Position` on `LocationController` where it sets
`setOutOfServingZone(true, realAddress: …)`. **Sequence this bootstrap change
before the login-handler change.**

## Amendment C — Where "far-away" is allowed to fire
**Finding:** the far-away distance-confirm (ref screen 2) **does not exist in
Waddy yet** — no translation key, no dialog; only a raw `distanceBetween(...) >
1` at `location_controller.dart:825`. It's **net-new work** (Phase 3), not
existing behavior to sequence around.

**Decision:** far-away is an **address-selection** concern, not a checkout one.
Fires once, at address pick / address switch (and optionally first store-entry
when the address is far from that store). It does **NOT** re-fire at checkout.
→ `checkoutGuard()` stays **two gates** (zone → auth), never three.

§ collision guard scope = **address-change / store-entry, excluding checkout**.
Precedence there: **zone (hard) beats far-away (soft)** — out-of-zone address
shows NO DELIVERY, never the far-away confirm.

*Future door left open:* if far-away should ever reconfirm at checkout (e.g.
high-value carts) it slots in as gate 1.5 (`zone → far-away → OTP`) and the
collision guard expands to include checkout. Deliberate future choice, not the
default.

## Amendment D — Checkout zone gate is unconditional (guest AND user)
Once Amendment B ships, **logged-in out-of-zone accounts exist for the first
time** (previously only guests could be out-of-zone).

**Rule:** `checkoutGuard()`'s zone precondition runs for **everyone**, before
any auth branch. A logged-in out-of-zone user hitting checkout gets **NO
DELIVERY** — they do not skip the gate because they're authenticated.

This is exactly why zone must be an **outer** precondition, not inside
`requireAccount()`: `requireAccount()` no-ops for logged-in users, so a zone
check living inside it would let a logged-in out-of-zone user sail through.
Analytics: `checkout_blocked_out_of_zone` carries `auth_state: guest|user`.

---

## 6. Build list (6 gaps)
1. **Unify the entry resolver** — one function replaces partial logic in
   splash + route_helper + onboarding.
2. **Background zone re-verify on return** — instant cached home + non-blocking
   `refreshOutOfZoneStatus()`.
3. **Single `requireAccount()` guard** — replaces hard middleware + scattered
   `isLoggedIn()` checks. Checkout wraps it behind the **two-gate**
   `checkoutGuard()` (zone unconditional → auth).
4. **Out-of-zone vs far-away gating** — only one presents; zone wins; scope is
   address-change/store-entry, not checkout (Amendment C). Far-away dialog is
   net-new.
5. **Address + guest-number carry-over on login** — branch on out-of-zone flag
   (Amendment B). **Depends on** the bootstrap lat/lng fix — sequence that
   first.
6. **Fail-count backoff** — wire `guestBootstrapFailCount`; reset on success.

## 7. Rollout (4 phases, all flag-guarded)
1. **Entry & return** — unified resolver + background zone re-check.
2. **Soft walls** — single `requireAccount()` across the matrix; retire hard
   redirects; checkout two-gate sequence.
3. **Location polish** — far-away dialog (net-new) + out-of-zone/far-away
   gating; zones-sheet "Maybe later" + re-entry.
4. **Continuity** — address/number carry-over, bootstrap lat/lng fix,
   fail-count backoff, per-conversion analytics.

Ship dark, enable per-region via `guest_browse_status`.
