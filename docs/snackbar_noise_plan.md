# Snackbar noise: investigation and remediation plan

**Status:** Phases 1–4 landed. Phase 5 open.
**Branch:** `home-critique-fixes`
**Date:** 2026-09-13

---

## 1. The finding

305 snackbar call sites across 97 files. Exactly **2** of them clear the queue before
showing ([place_vote_action.dart:126](../lib/features/places/widgets/place_vote_action.dart#L126),
[auth_utils.dart:140](../lib/features/auth/screens/auth_utils.dart#L140)). Everything else
stacks, because Flutter's `ScaffoldMessenger` queues serially rather than replacing.

The headline number is not 305 though. It is this:

> **117 of the app's 120 read calls (`apiClient.getData`) toast on failure.**

`handleError` defaults to `true` on every `ApiClient` method, and the `true` branch
routes to `ApiChecker.checkApi` → `showCustomSnackBar(response.statusText)`. Only 3
`getData` calls opt out. So every background refresh, prefetch and parallel fan-out
is wired to shout at the user when the network hiccups.

### Worst case, concretely

`PlacesController` init runs a 7-way parallel fan-out
([places_controller.dart:1262](../lib/features/places/controllers/places_controller.dart#L1262)):

```
guard(getZones)  guard(getCategories)  guard(getLeaderboard)  guard(getTopVoters)
guard(getPlaces) guard(getLatestWinner) guard(getRecentWinners)
```

All seven default to `handleError: true`. Offline, each returns
`statusText = noInternetMessage` and each fires its own toast: **7 identical
"connection to api server failed" bars, 2s apiece, ~14 seconds of blocked screen.**

The `guard()` wrapper does catch the failures and `_hasInitError` correctly
degrades to a partial render — but the toast already fired *inside* `ApiClient`,
below the layer that knows the failure was tolerable. The error handling is
right; the announcement is wrong.

---

## 2. Four distinct root causes

These are separate defects. Fixing one does not fix the others.

### RC1 — `handleError: true` is the wrong default for reads

*Where:* [api_client.dart:119-300](../lib/api/api_client.dart#L119) (all five verbs),
[api_checker.dart:66](../lib/api/api_checker.dart#L66)

A repository read has no idea whether its caller is a user-initiated tap or a
silent background sync. Defaulting to "toast on failure" means the data layer
announces failures the presentation layer has already decided to absorb.

Note `ApiChecker.checkApi` has only **2** direct call sites
([api_client.dart:362](../lib/api/api_client.dart#L362) and
[checkout_controller.dart:651](../lib/features/checkout/controllers/checkout_controller.dart#L651)).
The blast radius is large but the chokepoint is tiny — this is cheap to fix centrally.

### RC2 — Success toasts for actions that are already visible

40 sites pass `isError: false`. The offenders are the ones where the UI already
answered the question before the toast arrived:

| Where | Why it is noise |
|---|---|
| [favourite_controller.dart:43](../lib/features/favourite/controllers/favourite_controller.dart#L43), [:91](../lib/features/favourite/controllers/favourite_controller.dart#L91) | Heart icon fills/unfills optimistically *before* the request fires. Fired from 5 widgets — the most-hit toast in the app. |
| [cart_screen.dart:1114](../lib/features/cart/screens/cart_screen.dart#L1114), [:1325](../lib/features/cart/screens/cart_screen.dart#L1325) | `added_to_cart` fires **while the user is looking at the cart**. The line item appears in front of them. |
| [places_controller.dart:923](../lib/features/places/controllers/places_controller.dart#L923), [:947](../lib/features/places/controllers/places_controller.dart#L947), [:997](../lib/features/places/controllers/places_controller.dart#L997) | Sheet closes and the list visibly refreshes. |

### RC3 — Presentation logic living in repositories and services

A repository showing a snackbar is a layer violation, and it makes double-toasting
invisible at the call site — the caller cannot tell the callee already spoke.

- [order_repository.dart:53](../lib/features/order/domain/repositories/order_repository.dart#L53) — a **repository** shows a snackbar
- [order_service.dart:62](../lib/features/order/domain/services/order_service.dart#L62), [:99](../lib/features/order/domain/services/order_service.dart#L99)
- [cart_service.dart:264-267](../lib/features/cart/domain/services/cart_service.dart#L264-L267)
- [item_service.dart:219-254](../lib/features/item/domain/services/item_service.dart#L219-L254)
- also `location_service`, `profile_service`, `business_service`, `deliveryman_registration_service`

### RC4 — Four competing snackbar implementations

1. `showCustomSnackBar(..., getXSnackBar: false)` → `ScaffoldMessenger` queue
2. `showCustomSnackBar(..., getXSnackBar: true)`  → `Get.showSnackbar` queue
3. [cart_snackbar.dart](../lib/common/widgets/cart_snackbar.dart) — bespoke, has an action slot
4. `_showVoteToast` in [place_vote_action.dart](../lib/features/places/widgets/place_vote_action.dart) — bespoke, has an action slot + UNDO

(1) and (2) are **separate queues that do not know about each other**, so they can
render simultaneously and overlap. `getXSnackBar` has only 8 real call sites and no
documented reason for the split — it looks like it was introduced to escape a
`Get.context` issue inside bottom sheets, not as a deliberate design.

(3) and (4) exist *only* because `showCustomSnackBar` has no action slot. The vote
code says so out loud at [place_vote_action.dart:115](../lib/features/places/widgets/place_vote_action.dart#L115):

> `/// [showCustomSnackBar] has no action slot, hence the local bar.`

### Prior art worth noting

Someone already hit this and patched locally: `PlacesController.submitVote` /
`removeVote` take a `silent` flag, with the comment at
[places_controller.dart:877](../lib/features/places/controllers/places_controller.dart#L877):

> *"A silent vote is announced by the undo snackbar the caller shows; stacking a
> second toast on top of it just covers the undo action."*

That is exactly the right instinct — applied to 2 paths out of 305.

---

## 3. The rule

> **A toast is only justified when the result is invisible, off-screen, or irreversible.**

| Situation | Toast? | Because |
|---|---|---|
| Cancel order | yes | Consequential and not otherwise announced |
| Copy code to clipboard | yes | Genuinely invisible — nothing on screen changes |
| Favourite / unfavourite | **no** | The heart already said it |
| Add to cart *from the cart screen* | **no** | The row appears in front of you |
| Add to cart from elsewhere | yes, with action | Off-screen destination; needs "View cart" |
| Background refresh fails, cache renders | **no** | Show a stale-data affordance, not a toast |
| Foreground action fails | yes | User is waiting on it |

---

## 4. Plan

Five phases, ordered so the cheapest and highest-impact land first. Each is
independently shippable and independently revertible.

### Phase 1 — Stop the stacking ✅ LANDED

Add a queue-clear inside `showCustomSnackBar` so a new bar replaces the current one
instead of waiting behind it.

- **File:** [custom_snackbar.dart](../lib/common/widgets/custom_snackbar.dart)
- **Change:** call `ScaffoldMessenger.of(Get.context!).hideCurrentSnackBar()` before
  `showSnackBar`; `Get.closeCurrentSnackbar()` on the GetX branch.
- **Effect:** the 7-toast offline pile-up becomes 1 toast. Does not reduce the
  *number* of toasts fired, only the time they block the screen.
- **Risk:** low. Worst case a genuinely-distinct second message is now missed —
  acceptable, and Phase 2 removes most of the second messages anyway.

### Phase 2 — Flip the read default ✅ LANDED

Make silence the default for failures and let callers opt into announcing.

> **Correction found during implementation.** The plan above assumed `handleError`
> meant "toast + 401 sweep". It actually carries a **third** responsibility:
> it changes the RETURN SHAPE. `handleError: true` returns `const Response()`
> (empty) on failure; `false` returns the real response — and 117 read paths
> branch on that contract. Repurposing `handleError` would have silently changed
> return values app-wide. So `showError` was added as a **separate orthogonal
> parameter** that controls only the toast, leaving `handleError` semantics
> exactly as they were. Safer and smaller than the original proposal.

- **Files:** [api_client.dart](../lib/api/api_client.dart), [api_checker.dart](../lib/api/api_checker.dart)
- **Change:** keep `handleError` untouched; add `showError` alongside it. The **401 session sweep must stay unconditional** — it
  is a security/session concern, not a presentation one. Only the
  `showCustomSnackBar(response.statusText)` branch becomes opt-in.
  - Add `bool showError` to `ApiChecker.checkApi`, defaulting `false`.
  - Thread a `showError` param through the five `ApiClient` verbs.
  - Default `getData` → `showError: false`. Reads should never toast.
  - Default writes (`postData` / `putData` / `deleteData` / `postMultipartData`)
    → `showError: true`, since a write is nearly always foreground.
- **Effect:** kills the 7× offline pile-up at source, and every silent background
  refresh across home, store, item, banner and places goes quiet.
- **Verify:** airplane-mode the Spots home. Expect **0** toasts and a cached/partial
  render, not 7 bars. Then airplane-mode a *tap* (submit vote) and expect exactly 1.
- **Risk:** medium — this is the behavioural change. Some read failures that
  previously announced themselves will now need a visible empty/error state
  instead. Cross-check against the inline error/retry row already approved in the
  home critique work.

### Phase 3 — Delete the redundant success toasts ✅ LANDED

- Favourites: drop the `isError: false` toast in both
  [`addToFavouriteList`](../lib/features/favourite/controllers/favourite_controller.dart#L43)
  and [`removeFromFavouriteList`](../lib/features/favourite/controllers/favourite_controller.dart#L91).
  **Keep the error toasts** — those matter, because the optimistic heart gets
  rolled back and the user needs to know why it flipped back.
- Cart: drop `added_to_cart` at [cart_screen.dart:1114](../lib/features/cart/screens/cart_screen.dart#L1114)
  and [:1325](../lib/features/cart/screens/cart_screen.dart#L1325) (both fire while on the cart screen).
- Places: drop `review_submitted`, `review_removed`, `report_submitted` where the
  list visibly refreshes behind the closing sheet.
- **Effect:** removes the highest-frequency toasts in the app.
- **Risk:** low, and trivially revertible per-line.

### Phase 4 — Lift presentation out of the data layer ✅ LANDED (narrowed)

Move each RC3 toast up to its controller, or gate it behind a `silent` /
`showFeedback` parameter following the pattern `PlacesController` already
established.

Start with `order_repository.dart:53` — a repository is the clearest violation and
the smallest change. Then the services, one feature at a time.

- **Risk:** low per-file, but touches many files. Do it feature-by-feature, not
  as one sweep.

### Phase 5 — Collapse to one snackbar

Give `showCustomSnackBar` an optional action slot (`actionLabel` + `onAction`),
which is the only thing `cart_snackbar` and `_showVoteToast` have that it lacks.
Then retire both, and delete the `getXSnackBar` branch so there is a single queue.

- **Order matters:** add the action slot *first*, migrate the two bespoke bars,
  then remove `getXSnackBar` — its 8 call sites need checking for the
  `Get.context`-inside-bottom-sheet issue that probably motivated it.
- **Effect:** one visual language, one queue, no possibility of overlap.
- **Risk:** low functionally, but it is the largest diff. Ship last.

---

## 5. Sequencing note

Phases 1 and 3 are cosmetic and safe — they can go in together and would visibly
cut the noise on their own.

Phase 2 is the one that actually fixes the problem, and it is the one that needs
real device testing (airplane mode, slow 3G, backgrounded-app resume) because it
changes what the user sees on failure.

Phases 4 and 5 are hygiene. They prevent the problem returning; they do not
themselves reduce what the user sees today.

---

## 6. Open questions

- **Phase 2 default for writes:** `showError: true` is proposed on the assumption
  that writes are always foreground. `places_analytics.dart:30` is already a
  background `postData` and correctly passes `handleError: false` — worth grepping
  for other fire-and-forget writes before flipping.
- **Raw `statusText` as user copy:** even the toasts we keep are surfacing raw
  server strings that were never written for users. Out of scope here, but it is
  the natural follow-up.
- **Stale-data affordance:** Phase 2 assumes there is somewhere to *put* a quiet
  failure. Confirm the inline error/retry row covers the non-home surfaces too.

---

## 7. What actually landed (2026-09-13)

### Phase 1 — `showCustomSnackBar` now replaces instead of queueing
[custom_snackbar.dart](../lib/common/widgets/custom_snackbar.dart)
- `hideCurrentSnackBar()` before every show; `Get.closeCurrentSnackbar()` on the GetX branch.
- Bonus hardening: `Get.context!` → null-checked `Get.context` + `ScaffoldMessenger.maybeOf`.
  A toast fired after teardown or from a background isolate now drops instead of crashing.

### Phase 2 — `showError` split out from `handleError`
[api_checker.dart](../lib/api/api_checker.dart), [api_client.dart](../lib/api/api_client.dart)
- `ApiChecker.checkApi` gains `showError` (default `false`). The **401 sweep stays
  unconditional** — session handling never depended on the toast flag.
- `showError` threaded through all five `ApiClient` verbs and `handleResponse`.
- Defaults: `getData` → `false` (silent), writes → `true` (announce).
- Opt-ins/outs applied after auditing every background write:
  - [checkout_controller.dart:653](../lib/features/checkout/controllers/checkout_controller.dart#L653) → `showError: true` (foreground tax fetch the user waits on)
  - [chat_repository.dart:115](../lib/features/chat/domain/repositories/chat_repository.dart#L115) → `showError: false` (read receipts fire on scroll; user never asked)
  - `places_analytics` and the logout FCM-token clear already passed `handleError: false`, so they were never reachable by the toast branch.

### Phase 3 — Redundant success toasts removed
- [favourite_controller.dart](../lib/features/favourite/controllers/favourite_controller.dart) — both branches inverted to guard clauses; **error toasts kept** (the optimistic heart rolls back and needs explaining).
- [cart_screen.dart](../lib/features/cart/screens/cart_screen.dart) ×2 — suggestion-strip quick-add on the cart screen itself.
- [places_controller.dart](../lib/features/places/controllers/places_controller.dart) ×2 — `review_submitted` / `review_removed`; sheet closes and the list refreshes in view.
- `report_submitted` left alone: `reportReview` has **no callers** — it is dead code, and a report *is* genuinely invisible, so the toast is correct if it is ever wired up.

### Verification
`dart analyze lib` → **0 errors, 0 warnings** (503 pre-existing lint infos, untouched).
No read path anywhere now passes `showError: true`.

### Still needs a real device (cannot be verified statically)
1. Airplane-mode the Spots home → expect **0 toasts** + cached/partial render (was 7 bars / ~14s).
2. Airplane-mode a *tap* (submit vote, add address) → expect **exactly 1**.
3. Favourite/unfavourite offline → heart flips back **with** an error toast.
4. Expired session → still swept to auth (confirms the 401 path survived the split).

---

## 8. Phase 4 — what landed, and why it narrowed

Auditing each RC3 site individually showed the category was **over-broad**. Not every
toast in a service is a layer violation; three genuinely different things were
lumped together. Only the first is a defect.

### (a) Real violations — fixed

| Site | Fix |
|---|---|
| [order_repository.dart](../lib/features/order/domain/repositories/order_repository.dart) `cancelOrder` | Toast removed from the repo, moved up to [order_controller.dart](../lib/features/order/controllers/order_controller.dart) `cancelOrder`, which owns the success path and already mutates the list. New key `order_cancelled_successfully` added to **both** `en.json` and `ar.json`. |
| [location_repository.dart](../lib/features/location/domain/repositories/location_repository.dart) `getAddressFromGeocode` | Silenced → `debugPrint`. This fires **continuously while the user drags the map pin**; every failed lookup toasted. It already returns an `'Unknown Location Found'` fallback that all 6 callers render, so the user-visible signal was never the toast. |

### (b) Validation refusals on a direct tap — correctly left alone

[cart_service.dart:264-267](../lib/features/cart/domain/services/cart_service.dart#L264-L267),
[item_service.dart:219-254](../lib/features/item/domain/services/item_service.dart#L219-L254)
— `out_of_stock`, `maximum_quantity_limit`, `maximum_variation_for`.

These are not async result announcements. The user taps `+`, **nothing happens**, and
the toast is the only thing explaining why. Silent failure here would be worse than
the noise. They live in a service for tidiness, not because they are misplaced UI.

### (c) Success toasts that survive a navigation — correctly left alone

[order_service.dart:62](../lib/features/order/domain/services/order_service.dart#L62) (refund),
[:99](../lib/features/order/domain/services/order_service.dart#L99) (switch to COD).

Both call `Get.offAllNamed` immediately after. The toast outlives the transition and
is the **only** trace of the outcome on the destination screen — exactly the
"invisible / off-screen" case the rule in §3 says to keep. Verified their three
callers do not also toast on the same branch (the caller toasts sit on the `else`
validation branch, so there is no double-toast).

### Revised guidance for RC3

> A toast in a service or repository is a defect when it announces an **async result**
> the caller is better placed to describe. It is fine when it explains a **synchronous
> refusal** the user just triggered, or when the caller is about to navigate away.

`reportReview` in [places_controller.dart:997](../lib/features/places/controllers/places_controller.dart#L997)
remains untouched — it has **no callers**, and a report genuinely is invisible, so its
toast is correct if the feature is ever wired up.
