# Snackbar cleanup — status

**Date:** 2026-09-13 · **Branch:** `home-critique-fixes`
**Full analysis:** [snackbar_noise_plan.md](snackbar_noise_plan.md)

| Phase | Scope | State |
|---|---|---|
| 1 | Stop toasts stacking | ✅ Done |
| 2 | Stop background reads toasting | ✅ Done |
| 3 | Delete redundant success toasts | ✅ Done |
| 4 | Lift toasts out of the data layer | ✅ Done (narrowed) |
| 5 | Collapse 4 snackbar systems into 1 | ❌ Not started |

**Build state:** `dart analyze lib` → **0 errors, 0 warnings**.
No builds run — per standing preference, device testing is yours.

---

## ✅ What's done

### Phase 1 — Toasts replace instead of queueing
`lib/common/widgets/custom_snackbar.dart`

`ScaffoldMessenger` queues serially, so N toasts meant N × 2s of blocked screen.
Now `hideCurrentSnackBar()` runs before every show, and `Get.closeCurrentSnackbar()`
on the GetX branch.

Also hardened while in there: `Get.context!` → null-checked `Get.context` +
`ScaffoldMessenger.maybeOf`. A toast fired after teardown or from a background
isolate now drops silently instead of crashing on the bang operator.

### Phase 2 — Background reads went quiet (the actual fix)
`lib/api/api_checker.dart`, `lib/api/api_client.dart`

Root cause was that **117 of 120 `getData` calls toasted on failure** — every
background refresh, prefetch and parallel fan-out was wired to shout.

Added `showError` as a **new parameter, separate from `handleError`**, threaded
through all five `ApiClient` verbs and `handleResponse`:

- `getData` → `showError: false` (silent)
- `postData` / `putData` / `deleteData` / `postMultipartData` → `showError: true`
- The **401 session sweep stays unconditional** — it never depended on the toast flag

Per-call overrides applied after auditing every background write:

| Site | Setting | Why |
|---|---|---|
| `checkout_controller.dart` tax fetch | `showError: true` | Foreground; user is sat on checkout waiting |
| `chat_repository.dart` `markAsRead` | `showError: false` | Read receipts fire on scroll; user never asked |

`places_analytics` and the logout FCM-token clear already passed
`handleError: false`, so they were never reachable by the toast branch.

### Phase 3 — Redundant success toasts removed

| Site | Why it went |
|---|---|
| `favourite_controller.dart` ×2 | The heart already filled/emptied optimistically. **Error toasts kept** — the heart rolls back and that needs explaining. |
| `cart_screen.dart` ×2 | `added_to_cart` fired from the suggestion strip **on the cart screen**; the row lands in view behind it. |
| `places_controller.dart` ×2 | `review_submitted` / `review_removed` — sheet closes, list refreshes in view. |

### Phase 4 — Two real layer violations fixed

| Site | Fix |
|---|---|
| `order_repository.dart` `cancelOrder` | A **repository** was showing UI. Toast moved up to `order_controller.dart`, which owns the success path. New key `order_cancelled_successfully` added to **both** `en.json` and `ar.json`. |
| `location_repository.dart` `getAddressFromGeocode` | Silenced → `debugPrint`. Fired **on every failed lookup while dragging the map pin**. Already returns an `'Unknown Location Found'` fallback that all 6 callers render. |

---

## ⚠️ Deliberately left alone

Not oversights — auditing each site showed the original RC3 category was too broad.

**Validation refusals on a direct tap** — `cart_service.dart`, `item_service.dart`
(`out_of_stock`, `maximum_quantity_limit`, `maximum_variation_for`). You tap `+`,
nothing happens, and the toast is the only explanation. Silence would be worse.

**Success toasts before a navigation** — `order_service.dart` refund and
switch-to-COD. Both call `Get.offAllNamed` immediately after; the toast outlives
the transition and is the only trace on the destination screen. Confirmed their
three callers don't also toast on the same branch.

**`report_submitted`** — `reportReview` has **no callers**. Dead code, and a report
genuinely is invisible, so the toast is correct if it's ever wired up.

> **Revised rule for the data layer:** a toast in a service or repository is a defect
> when it announces an **async result** the caller is better placed to describe.
> It's fine when it explains a **synchronous refusal** the user just triggered,
> or when the caller is about to navigate away.

---

## ❌ What's missing

### Phase 5 — Collapse four snackbar systems into one (not started)

Still four visual languages for the same concept:

1. `showCustomSnackBar(getXSnackBar: false)` → `ScaffoldMessenger` queue
2. `showCustomSnackBar(getXSnackBar: true)` → `Get.showSnackbar` queue
3. `cart_snackbar.dart` — bespoke, has an action slot
4. `_showVoteToast` in `place_vote_action.dart` — bespoke, action slot + UNDO

(1) and (2) are **separate queues that don't know about each other** — Phase 1 fixed
stacking *within* each queue, but a GetX bar and a Messenger bar can still render
simultaneously and overlap. That hole is still open.

(3) and (4) exist *only* because `showCustomSnackBar` has no action slot. The vote
code says so in a comment.

**Order matters:** add `actionLabel` + `onAction` first → migrate the two bespoke
bars → *then* remove `getXSnackBar` (15 references; check each for the
`Get.context`-inside-bottom-sheet issue that probably motivated the split).

Largest diff of the five phases, purely hygiene, no user-visible win on its own.

### Device verification — nothing below has been tested

Static analysis can't confirm any of this:

1. **Airplane-mode the Spots home** → expect **0 toasts** + cached/partial render
   (was 7 identical bars, ~14s). This is the headline fix.
2. **Airplane-mode a tap** (submit vote, add address) → expect **exactly 1**.
3. **Favourite offline** → heart flips back **with** an error toast.
4. **Expired session** → still swept to auth. Confirms the 401 path survived the
   `handleError` / `showError` split. *Highest-risk regression of the whole change.*
5. **Cancel an order** → the new `order_cancelled_successfully` string renders in
   both EN and AR (a missing key renders as the raw key, silently).

### Known follow-ups, out of scope

- **Raw `statusText` as user copy.** The toasts we kept still surface raw server
  strings never written for users. Natural next task.
- **Stale-data affordance.** Phase 2 assumes quiet failures have somewhere to go.
  Confirmed for the home inline error/retry row; **not** audited for store, item,
  search or checkout surfaces. If a read fails quietly there, the user may see an
  empty screen with no explanation. Worth a pass.
- **Remaining volume.** 300 call sites across 96 files (from 305 / 97). The count
  barely moved because Phase 2 fixed *behaviour at a chokepoint*, not call sites —
  the 117 silenced reads all route through one `ApiClient`. Reducing the raw count
  is Phase 5 plus a copy pass, not a correctness issue.
