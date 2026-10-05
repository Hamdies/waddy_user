# Live tracking plan (`LT-*`)

The "on the way" part of the order screen: when the map shows, what it looks
like, and how often anyone asks the server where the rider is.

Reference: Breadfast's tracking screen (screens shared 2026-10-03) — full-bleed
map behind the status bar, top-down scooter that turns with the road, a home
pin, no route line, a draggable sheet carrying ETA + segmented progress + cards.
User call 10-03: no dashed line between rider and home on the map; keep the
helmet marker.

## Status

| ID | What | Side | Status |
|---|---|---|---|
| LT-01 | Distance-gated map: no map while the rider is far | app | built 10-03, device check pending |
| LT-02 | Near state = full-bleed map + draggable sheet (Breadfast layout) | app | built 10-03, device check pending |
| LT-03 | Markers: keep the helmet marker; drop the dashed rider→home line; home pin | app | built 10-03, device check pending |
| LT-04 | Camera: fit rider+home once, re-fit only when a point leaves the safe frame | app | built 10-03, device check pending |
| LT-05 | Light `rider-location` endpoint, cached 5 s per order | backend | built 10-03, **backend deploy pending** |
| LT-06 | Two-speed polling: status 30 s always, location 10 s only when near | app | built 10-03, device check pending |
| LT-07 | Stale fix guard: hide the rider when the last fix is > 2 min old | backend + app | built 10-03, device check pending |
| LT-08 | ETA: near-state ETA from distance, kill the "85 mins · running late" false alarm | app | built 10-03, device check pending |
| LT-09 | Segmented progress bar in the sheet (placed → prepared → on the way, last segment fills by distance) | app | built 10-03, device check pending |
| LT-10 | Retire the separate full-map screen (`order_tracking_screen.dart`, own 10 s poll) | app | built 10-03, device check pending |
| LT-11 | Rider app: write location every 30 s when it has no active order (10 s while delivering) | rider app | optional |

## What is there today

- **Map** — [order_live_map.dart](../lib/features/order/widgets/order_details/order_live_map.dart):
  a 220–300 px strip under the header, shown whenever `stage == onWay` and both
  points exist, **however far the rider is**. Helmet-in-a-mint-disc marker,
  straight polyline rider→home, camera follows the rider at zoom 16.8 so home is
  usually off-screen (screenshot 1: rider visible, home nowhere).
- **Polling** — [order_details_screen.dart:113](../lib/features/order/screens/order_details_screen.dart#L113):
  `track_order` every 10 s. That endpoint eager-loads store, store_sub,
  delivery_man.rating, parcel_category, refund, payments and formats all of it
  — the full order, six times a minute, to learn two numbers. Pauses on
  background (good). The full-map screen runs its own separate 10 s poll.
- **Rider app** — `ProfileController` posts `record-location-data` every 10 s,
  **always**, on or off an order. One row per rider (`updateOrCreate`), no
  heading sent.
- **ETA** — straight-line km ÷ time-of-day speed; the header anchor only moves
  later. With a rider 40 km away (test device) it lands on "85 mins · Running
  late" while the map makes the rider look next door.

## LT-01 · Distance gate

Straight-line distance rider→home, with hysteresis so it doesn't flicker:

| Rider → home | Shows |
|---|---|
| > 2.0 km (or no fix / stale fix) | **No map.** Current mint header + stage Lottie band + ETA + progress. Same as the "preparing" look. |
| map appears at < 1.5 km, hides again only above 2.0 km | **Near state** (LT-02) |
| < 150 m | Near state, title switches to "Your rider is arriving" |

1.5 km ≈ 4–5 min on a scooter in Cairo — the window where watching the dot is
actually useful. Before that the map is just a dot in an unknown street.

## LT-02 · Near-state layout

```
┌──────────────────────────────┐
│ (‹)                  (Help)  │  ← floating round buttons over the map
│                              │
│        MAP, full-bleed       │  ← behind status bar, ~55% of screen
│     🛵 →        ⌂            │
│                              │
├──────── ▬▬ ──────────────────┤  ← DraggableScrollableSheet
│ Arriving in   4 min          │     min 45% / max 92%
│ Order is on the way          │
│ ███████ ███████ ████░░░      │  ← LT-09
│ [ delivery PIN 8 5 1 5 ]     │
│ [ rider card · chat · call ] │
│ [ scratch card · address · … ]│
└──────────────────────────────┘
```

The far state keeps today's scroll page. Crossing the gate animates between
the two (map fades in under the header as the band collapses) — no route push,
the cards are the same widgets in both.

## LT-03 · Markers

- **Keep** the helmet-in-mint-disc rider marker (`MarkerHelper.riderMarker`).
- **Remove** the dashed rider→home line (user: "no need for it") — Breadfast
  shows only the two points.
- **Home** = ink teardrop pin with a house glyph, anchored at its tip (today's
  home is a small disc that gets lost on the map).
- No new art needed.

## LT-04 · Camera

Today it re-frames on every poll. Instead: fit rider+home once with bottom
padding = sheet height; afterwards move the camera only if the glided rider
would leave the inner 80% of the visible frame. Gestures stay off in the
collapsed sheet; when the user drags the map, stop auto-framing until they tap
a "recentre" chip.

## LT-05 · Light endpoint (backend)

`GET /api/v1/customer/order/rider-location?order_id=` (+ `contact_number` for
guests, same auth rule as `track_order`):

```json
{ "order_status": "picked_up", "lat": 30.06, "lng": 31.33,
  "recorded_at": "2026-10-03T20:27:14+02:00" }
```

One indexed select on `orders` + `delivery_histories` (single row per rider),
no eager loads, no formatting. Wrapped in `Cache::remember("rider_loc:$id", 5)`
so two phones on the same order, or a quick re-open, share a read.

## LT-06 · Polling cadence — the server question

Asked: "every 30 seconds or whatever is best for our server". The rider only
writes every 10 s, so polling faster than 10 s reads the same row twice.
Polling every 30 s while near is too coarse: at 20 km/h the rider covers
~170 m between fixes, which at street zoom is a jump across the screen.

| Timer | When | Calls |
|---|---|---|
| Status (`track_order`, heavy) | every **30 s** while the order is live, plus immediately on an `order_status` push | was every 10 s |
| Location (LT-05, light) | every **10 s**, only in near state and foreground | new |
| Far-state distance check | rides on the 30 s status poll (it already carries the rider's lat/lng) | no extra call |

Between fixes the scooter glides over the 10 s (the glide in `OrderLiveMap`
becomes ~9.5 s linear instead of 1.4 s ease), so it reads as continuous
movement rather than hops.

**Load, per 100 orders being watched at once** (say 20 of them near):

| | heavy req/min | light req/min |
|---|---|---|
| today | 600 | 0 |
| plan | 200 | 120 |

≈ 3× fewer heavy requests, and the light ones are a single row each.
Background still pauses everything.

## LT-07 · Stale fix

Add `location_updated_at` (from `delivery_histories.time`) to the rider in
`deliverymen_data_formatting`, and `recorded_at` in LT-05. App: older than
2 min → treat as "no fix" (far-state look, "Updating rider location…" under the
ETA). Covers riders whose app was killed, or a phone that lost GPS.

## LT-08 · ETA

- Near state: ETA = straight-line km ÷ speed, floored at 1 min, no "running
  late" pill (the dot itself is the truth now).
- Far state: keep the anchor logic, but don't flag "running late" off a
  rider→home leg > 15 km — that is a bad fix (or a test rider), not lateness;
  fall back to the promised time.

## LT-10 · Retire the full-map screen (decided 10-03: remove)

With the near state being a full map, the expand button and
`order_tracking_screen.dart` (1,014 lines, its own 10 s poll, route polyline)
are redundant. Recommendation: remove the expand button, make the tracking
route open order details. Every caller of `getOrderTrackingRoute` has to be
checked first (push-notification taps land there).

## What landed (10-03)

- Backend: `GET customer/order/rider-location` (ownership checked every call,
  rider fix cached 5 s per rider); `location_age_seconds` on every formatted
  rider. Ages are computed server-side so a wrong phone clock can't fake
  freshness.
- App: `OrderController.pollRiderLocation` (falls back to the full reload on a
  404, so it works before the deploy); `refreshTrackedOrder` on an
  `order_status` push; status poll 30 s; 10 s light poll only while near.
- Gate lives in `OrderDetailsScreen._updateGate`; near layout `_buildNear`
  with `OrderNearSheet` / `OrderNearSummary` / `OrderMapButton` in
  order_details_sections.dart. Stale fixes (> 2 min) count as no fix — no
  extra copy was added for that.
- `OrderLiveMap`: no line, helmet kept, teardrop home pin, 9.5 s glide
  throttled to ~12 marker moves/s, re-fit after 60 m, recentre chip after a
  user pan.
- Deleted: order_tracking_screen.dart, track_details_view_widget,
  modern_tracking_card_widget, delivery_instruction_tracking_widget,
  eta_chip_widget, marker_animator, the `/track-order` route and the
  `od_open_full_map` key.

## Build order

1. Backend: LT-05 + LT-07 (deploy).
2. App: LT-06 timers → LT-01 gate → LT-03/LT-04 markers + camera → LT-02 sheet
   → LT-08/LT-09.
3. LT-10 once LT-02 is checked on device. LT-11 whenever.

## Verify on device

- [ ] Rider > 2 km: no map, Lottie band, ETA sane, no "running late" from a bad fix
- [ ] Rider walks inside 1.5 km: map fades in once, doesn't flicker at the edge
- [ ] No line of any kind between rider and home on the map
- [ ] Helmet glides between 10 s fixes, no jumps; home stays in frame
- [ ] Kill rider app: after 2 min the rider disappears, copy says updating
- [ ] Two phones on one order: server log shows one `rider-location` read per 5 s
- [ ] Background the app 1 min: no requests in the server log
- [ ] Arabic: sheet, floating buttons and pins mirror correctly
