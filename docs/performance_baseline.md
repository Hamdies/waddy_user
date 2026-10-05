# Performance: measure before scoping

**Status:** baseline taken on a Mi 9T (2026-09-20). **Raster-bound.**
**Blocks:** M4 (527 unscoped `update()`), M10 (cold start)

---

## 1. Why this comes before the work

The hardening plan puts M4 at three weeks: scope 527 bare `update()` calls
across five controllers. The number is real — `store_controller` alone has 43
bare updates feeding 43 `GetBuilder`s.

But **527 is a proxy, not a measurement**, and proxies have misled this plan
three times:

| metric | counted | actually mattered |
|---|---|---|
| M5 | 358 `configModel!` | ~60 optional-field bangs |
| M2 | 260 raw parses | 26 at the JSON boundary |
| i18n | 36 missing keys | 0 (all unused) |

Each time, acting on the count would have burned days without reducing risk.
M4 is the same shape. A rebuild is not jank: a `GetBuilder` wrapping a `Text`
costs nothing to rebuild, one wrapping a grid of network images costs a frame.
Nothing in the repo currently says which is which.

And without a baseline there is no way to know whether three weeks of scoping
moved anything.

## 2. What landed

`lib/util/frame_stats.dart` — frame timing via Flutter's own
`addTimingsCallback`. No new dependency.

It reports, per named window:

```
── FRAMES home load ────────────────────
frames: 142   janky: 7 (4.9%)   severe: 2   wall: 2380ms
  build   avg   4.2ms   worst  18.7ms
  raster  avg   6.1ms   worst  41.3ms
  raster-bound — painting cost, not rebuild cost. Look at images, shadows,
  blurs; scoping update() will not help
```

**The build/raster split is the whole point.** Build is Dart — rebuilds,
layout, paint instructions; this is what unscoped `update()` inflates. Raster
is the GPU rendering those instructions; this is inflated by image decode size,
`BackdropFilter`, `Opacity` layers and unclipped shadows.

- build over, raster fine → **scope the updates.** M4 is the right fix.
- raster over, build fine → **M4 will not help.** Look at images and effects.
- both → start with raster; usually the cheaper fix.

Wired at two points:

- **`HomeScreen.loadData`** — alongside the existing `ApiStats` window, so one
  log line shows both. The two failure modes look identical to a user ("home is
  slow") and have opposite fixes: `ApiStats` blames the network, `FrameStats`
  blames the device.
- **`CartController.setQuantity`** — the most-repeated action on the revenue
  path, and the specific claim the plan makes ("every quantity tap repaints the
  entire checkout tree"). The window closes at the optimistic paint, not after
  the server sync, so the network is not charged against the tap.

Both are `kDebugMode`-gated at the cart site. Collection is cheap enough to
leave on in a profile build, which is where the real numbers come from.

## 3. Taking the baseline

**Profile mode, real device.** Debug is 3–10× slower than release and its
numbers mean nothing.

**Not the emulator.** An Android emulator on Apple Silicon rasterises through a
translation layer to the Mac's GPU — it measures the host, not a phone. Since
the build-vs-raster split is the entire decision here, the emulator gets the one
signal that matters wrong.

**Device in hand: Xiaomi Mi 9T / K20.** Snapdragon 730, 6 GB, 60 Hz, 2019. That
is a good proxy for the Egyptian mid-range and better for this than a modern
flagship — an iPhone 14 Pro Max glides through work that stutters on a
customer's phone, and its 120 Hz screen halves the frame budget on top.

The budget is read from the display at runtime, so it is correct on whichever
device is attached. The report prints it; on the Mi 9T expect `budget: 16.7ms`.
Seeing `16.7ms` on a 120 Hz screen would mean the rate was not read.

```sh
flutter run --profile --flavor prod --dart-define-from-file=env/prod.json
```

Record, from a cold start each time:

| # | interaction | what it isolates |
|---|---|---|
| 1 | cold start → home first paint | boot cost (M10) |
| 2 | scroll home to the bottom | list + image cost |
| 3 | open a food store, scroll the menu | the 43-builder `store_controller` |
| 4 | add an item, tap quantity ×5 | the M4 claim, directly |
| 5 | open checkout | `checkout_controller`, 37 bare updates |

For each, note `janky %`, `worst build`, `worst raster`, and the verdict line.

## 4. Targets

| metric | target | note |
|---|---|---|
| janky frames | **< 1%** | above 5% is visibly broken |
| severe frames | **0** on any single interaction | a 32ms frame is a hitch, not a stutter |
| worst build | **< 16ms** | over this, scoping is justified |
| worst raster | **< 16ms** | over this, scoping will not help |

## 5. Then decide

- **Build times over budget on cart or checkout** → do M4, on those two
  controllers only, using `places_controller` (18 bare / 30 scoped) as the
  in-repo reference. Re-measure. Only widen if it paid.
- **Raster over budget** → M4 is the wrong work. Look first at image decode
  size (`CustomImage` and the `X-Image-Variants` header the backend already
  honours), then at `Opacity`/`BackdropFilter`/shadow layers.
- **Both under budget** → M4 is not urgent. 527 bare `update()` is still a
  smell worth a ratchet, but it is not what is costing customers.

Whatever the answer, **write the numbers into this file** before starting. A
baseline nobody recorded is a baseline nobody can compare against.

## 6. What is still not measured

- **Cold start (M10)** — `FrameStats` covers the first *frame*, not the boot
  before it. `main()` serially awaits Firebase → `di.init()` → notifications →
  deep links → `initializeDateFormatting()` before `runApp`. Timing those five
  is the next instrumentation step.
- **Crash-free sessions (M11)** — Crashlytics is wired (13 references, plus 14
  `swallow(report: true)` sites) but nothing alerts. That is a console setting,
  not code.
- **Field data** — everything here is one developer on one device. A device
  farm or Firebase Performance would give the distribution. Worth it once the
  obvious wins are taken, not before.

## 7. Why not Firebase Performance

Considered and deferred. It gives field data across real devices, which
`FrameStats` cannot, and it is the right long-term answer for M10/M11.

But it needs a new dependency, per-flavor Firebase apps that **do not exist
yet** (see `docs/build_flavors.md` §5), and its dashboard aggregates — which
tells you *that* home is slow, not whether the cost is build or raster.

For the immediate question — is M4 worth three weeks — a local profile run
answers it today, for free. Revisit after the baseline.

---

## 8. Flow audit: store → cart → checkout → track

Prompted by a real symptom — *"checkout takes too much time to load, and the
store home screen"*. That is **latency**, not jank, and M4 would not have
touched it. Scoping `update()` is a rendering fix; this was the network.

### 8.1 Checkout opened three things in a queue

```
getStoreDetails          ← network
   └─ fires initializeTimeSlot + getDistanceInKM as side effects
getSurgePrice            ← network, waited for the above
initializeTimeSlot       ← ran AGAIN, duplicating the side effect
```

Only `getSurgePrice` genuinely had to wait — it needs `zoneId` and `moduleId`
off the store response. The rest queued for no reason, on a connection where
each leg is 200–800 ms.

**`initializeTimeSlot` ran four times where once would do.** `getStoreDetails`
already fires it ([store_controller.dart:888](../lib/features/store/controllers/store_controller.dart#L888)),
then `initCheckoutData` called it again — and *inside* it, `_timeSlots` and
`_allTimeSlots` were assigned from **the same call with the same arguments**,
so the whole schedule loop ran twice to build two identical lists.

Pure computation, so the cost was main-thread CPU rather than round trips —
still work done four times while the user stares at a shimmer.

Fixed: the duplicate call is gone, and the two lists come from one computation.
`_allTimeSlots` is a copy rather than the same reference, because `_timeSlots`
is filtered and mutated later (`validateTimeSlot`, and the rebuild at :810) and
sharing an instance would make one silently mutate the other.

### 8.2 The store screen waited on a response it did not need

The item list, recommendations and reviews are all keyed on the store id the
*caller already has*. None needs the store **detail** response — but all three
sat behind `await getStoreDetails(...)`, so opening a store cost one round trip
before the menu fetch even started.

They now fire first and the detail fetch runs alongside. The menu paints when
its own response lands.

One genuine dependency survives: a **slug-based deep link** arrives with no id,
and only the detail response can supply one. That branch still waits, and says
why.

### 8.3 Four more crash sites on the way through

`getStoreDetails` carried the same double-failure pattern fixed elsewhere in
§20.4 — `AddressHelper.getUserAddressFromSharedPref()!.latitude!` plus
`double.parse`, four throwing reads on one call, on the path that opens a
store. Plus three in the tracking screen's route polyline.

A distance that cannot be computed is a missing distance, not a crash.

### 8.4 What was already good

Worth recording, so nobody "optimises" it later:

- **Add to cart** is optimistic — the row appears on the current frame, before
  the request goes out, and every entry point funnels through one chokepoint
  that also gates out-of-zone users. This is the pattern the rest of the flow
  should copy.
- **`CartController.setQuantity`** already paints the new number before the
  server call, with a comment explaining that the animation was never the
  bottleneck.
- **Tracking** cancels its poll timer on `AppLifecycleState.paused` and checks
  the current route before each tick, so a backgrounded order is not polling
  every 10 s.

### 8.5 The god-method, decomposed

`getStoreDetails` fetched a store **and** initialised time slots, computed a
distance, set the order type, reassigned the user's saved address on a slug
link, and could trigger a full home reload — five anonymous `if` branches
behind a name that says "get".

That anonymity is why the duplicate in §8.1 survived: nothing at the call site
said the fetch already initialised time slots, so `initCheckoutData` did it
again.

Each effect is now a named method — `_applyOrderType`,
`_computeDeliveryDistance`, `_adoptStoreLocationAsUserAddress` — so the call
site reads as a list of what happens. The flags keep their meaning as
*suppressors*: `fromCart` means "I already know the distance", `slug` means "I
arrived by link and have no address yet".

**Done behind a net.** `test/unit/store_details_contract_test.dart` pins all
five effects, the short-circuit for callers that already hold a store, the
failure behaviour (`_store` cleared before the await so a failed fetch cannot
leave the previous menu on screen), and that checkout does not re-initialise
slots. 12 tests, written before the refactor and passing after it unchanged in
substance.

Two things that test taught on the way:

- **It failed first on layout, not behaviour.** The original version asserted
  the effects appeared *inside the method body*, so moving five branches into
  five methods broke it while changing nothing. A test that fails on a refactor
  it was written to protect is worse than no test. It now asserts the effects
  still happen, and that the *decisions* stay at the call site.
- **It matched its own comment.** The assertion that `initCheckoutData` no
  longer calls `initializeTimeSlot` failed against the comment explaining the
  removal. Comments are stripped before matching now — the same trap that
  mangled a comment about empty catches in §17.4.

Splitting this into separate public entry points is still the right end state.
It changes six call sites, so it wants its own pass; the net is in place for
whoever does it.

### 8.6 Still open on this flow

- **~47 coordinate parses remain** in this flow, inside null-checked branches.
  In the M2 ratchet, not swept — a blanket regex over this shape produced 78
  errors in §17.4.
- **The 10 s tracking poll.** `order_tracking_stream_service` existed and
  supported `guest_id`, but nothing imported it — it was deleted in the M3
  sweep as unreachable. A stream is still the better shape than polling every
  10 s while an order is open; that is a build, not a rewire.
- **`_categoryIndex = 0` on every call**, including the short-circuit. Harmless
  today, but it means asking for store details silently resets the user's
  category selection.

---

## 9. The baseline, and what it overturned

Xiaomi Mi 9T (Snapdragon 730, 6 GB, 60 Hz), profile build, `--flavor prod`.

| window | frames | janky | build avg | build worst | raster avg | raster worst |
|---|---|---|---|---|---|---|
| home load (cold) | 81 | 28.4% | 4.8ms | 84.8ms | **9.8ms** | 41.3ms |
| home refresh | 51 | **76.5%** | 5.1ms | 45.5ms | **14.5ms** | 37.4ms |
| home refresh | 44 | 70.5% | 6.1ms | 40.8ms | **11.1ms** | 30.1ms |

Budget 16.7 ms, correctly read from the 60 Hz display.

### 9.1 It is RASTER-bound, not build-bound

**Raster averages 2–3× build across every window.** On the middle run raster
averages 14.5 ms against a 16.7 ms budget — the GPU alone nearly misses the
frame before any Dart runs.

The tool said "build-bound" on all three, and the tool was wrong. Its verdict
compared **worst** build against **worst** raster, and a single 84 ms build
outlier during a cold start outvoted a raster average running triple the build
average across every other frame. A lone stutter is not what a scroll feels
like; the steady state is.

Fixed: the verdict now judges on averages, reports both, and says MIXED rather
than picking a side when neither dominates by 30%.

### 9.2 So M4 is not the first fix

This is the fourth time in this plan a proxy pointed the wrong way (§21.5), and
the first time the *instrumentation built to stop that* did it. Worth stating
plainly: a measurement is only as good as the question it asks.

Scoping 526 `update()` calls would have been weeks aimed at the smaller half of
the cost. Build average is 4.8–6.1 ms against a 16.7 ms budget — **already
inside budget**. Halving it saves ~3 ms on a frame losing 14.5 ms to raster.

### 9.3 What to look at instead

Home carries **88 `BoxShadow`s and 84 `ClipRRect`s**. Every clip forces a
`saveLayer`, every shadow is a blur pass, and both are per-widget in a scrolling
list.

Ordered by likely return:

1. **Shadows.** 88 of them. A `BoxShadow` with a blur is one of the most
   expensive things a mobile GPU does. Most cards want one shadow on the card,
   not one per element inside it.
2. **Clips.** 84 `ClipRRect`s. A rounded `DecoratedBox` clips without a
   `saveLayer`; `Card` and `Material` take a `borderRadius` directly.
3. **`Opacity`** — 54 uses. `Opacity` allocates an offscreen layer;
   `AnimatedOpacity` on a static value, or a colour with an alpha channel,
   usually does not.

Image decode is **not** the problem: `CustomImage` already sets `memCacheWidth`
and `maxWidthDiskCache`.

### 9.4 The refresh windows are the worst

76.5% and 70.5% janky, against 28.4% on the cold load. A refresh repaints a
fully-populated home — every card, shadow and clip already on screen — where the
cold load paints into an empty tree.

That is also the shape a user hits most: pull-to-refresh, or returning to home.

### 9.5 Android's own instrumentation agrees

```
I/Choreographer: Skipped 64 frames!  The application may be doing too much work
                 on its main thread.
W/Looper: PerfMonitor doFrame : time=1050ms latency=789ms
```

A 1,050 ms frame during startup. That one *is* main-thread work and belongs to
cold start (M10), separately from the raster story above.

### 9.6 Revised order

1. **Shadow and clip audit on home** — the measured cost.
2. **Re-measure.** Target: raster average under 8 ms.
3. **M4 on cart + checkout only**, if their own windows justify it. Build is
   inside budget on home, so home's 22 builders are not the priority the count
   implied.
4. **Cold start (M10)** — the 1,050 ms frame is a separate problem.

The M4 numbers stay in the scoreboard as a maintainability metric. They are not
the performance metric.

---

## 10. First raster pass

Aimed at §9.3, on the cards the measured rails actually render.

### 10.1 Double shadows collapsed — 3 cards

`store_card_with_distance`, `store_card` and `popular_store_card` each drew an
**ambient** shadow (12px blur) stacked on a **directional** one (8px blur):
two full blur passes per card, on rails that render several at once.

Replaced with one shadow whose blur (10px) and offset (0,3) sit between the
pair, at slightly higher alpha to keep the depth. Halves the blur work per
card, and a card is the unit that multiplies by how many are on screen.

### 10.2 `CustomImage.borderRadius` — 7 saveLayers removed

A `ClipRRect` forces a `saveLayer`: render the subtree to an offscreen buffer,
mask it, composite back. These cards did that per image, in scrolling rails.

`CustomImage` now takes an optional `borderRadius` and paints the loaded image
as a `DecorationImage` on a rounded `BoxDecoration` via `imageBuilder`. The
renderer rounds while drawing — no offscreen pass, identical result.

Seven single-image clips converted across the four card files. Clips that wrap
a **`Stack`** were deliberately left alone: there the clip masks badges and
overlays too, so it is doing real work rather than just rounding a photo.

### 10.3 What was checked and left

**Image decode is not the problem.** `CustomImage` already sets `memCacheWidth`
and `maxWidthDiskCache` from the laid-out width and device pixel ratio, capped
at 1080px. The bytes-in-memory half was done before this.

**The "54 `Opacity` widgets"** was a miscount — see §13.1. There are six, and
only two are on a scrolling path.

### 10.4 Re-measure before doing more

```sh
flutter run --profile --flavor prod --dart-define-from-file=env/prod.json
```

**Target: raster average under 8ms** (was 9.8–14.5). The refresh windows are
the ones to watch — 76.5% and 70.5% janky, worse than the cold load, because a
refresh repaints a fully-populated home.

If raster drops and jank follows, continue with the `Opacity` pass. If raster
drops and jank does **not**, the remaining cost is elsewhere and the next
measurement should say where — not a guess.

---

## 11. Second measurement, and the bug it exposed

### 11.1 The raster pass held

| | baseline | after §10 |
|---|---|---|
| home cold — janky | 28.4% | **16.1% / 23.6%** |
| home cold — raster avg | 9.8ms | **6.7ms / 7.1ms** |
| home cold — raster worst | 41.3ms | **16.6ms / 40.8ms** |

Two cold runs, because a second measurement is how you learn the variance: 16.1%
and 23.6% jank for the same interaction. Any single number here is ±7 points, so
a change under that is noise.

Raster average went 9.8ms → 6.7–7.1ms and stayed under the 16.7ms budget. The
verdict line now reads correctly: `RASTER-bound (avg 6.7ms vs build 3.1ms)`.

### 11.2 Refresh is still the worst case

75.0%, 60.0%, 30.0%, 14.7% janky across four refreshes, raster 9.5–14.1ms. The
spread tracks how much was already on screen — a refresh over a full home
repaints every card, where the cold load paints into an empty tree.

Still the next target, and still raster.

### 11.3 The fan-out cap worked

Home cold went 29 requests → **17**. The `items/recommended` fan-out that fired
8× now fires within its cap and skips stores already fetched.

### 11.4 Checkout: 0 requests, 25ms — and that was the clue

```
── API checkout open ──
requests: 0   failures: 0   bytes: 0B   wall: 25ms
```

Checkout's own load is instant; the store-cache reuse works. So the reported
"takes forever and doesn't load" was happening *after* that window closed.

The shimmer was gated on `distance != null && store != null`, and **the cache
short-circuit skipped the distance computation entirely**:

```dart
if (store.name != null) {
  _store = store;
  _applyOrderType();
  return _store;        // <- _computeDeliveryDistance never ran
}
```

So the optimisation from §8 — reuse the store the cart already fetched — made
checkout faster at fetching and permanently stuck at rendering. A fix that
caused the symptom it was meant to relieve.

Two changes:

1. **The short-circuit now computes the distance.** A cached store does not
   imply a cached distance; they are separate fetches.
2. **The shimmer no longer gates on distance at all.** It waited on a second
   serial chain (distance → extra charge) to show the address, the items and
   the payment methods — none of which need it. `_computeDeliveryDistance`
   also bails silently when coordinates are missing, so `distance` could stay
   null forever and the screen would never load on that path either.

   The fee shows as pending while it resolves, `-1` already means "not
   computable" downstream, and the place-order button keeps its own
   `distance == -1` guard, so submission is still blocked when it must be.

### 11.5 What this cost, and the lesson

The §8 optimisation shipped without a measurement of the screen it optimised —
checkout was the one window with no instrumentation, which is exactly why the
regression was invisible. It was found by instrumenting it and reading a
**zero**: 0 requests in 25ms is not a fast screen, it is a screen whose work
happens somewhere the window does not cover.

An unexpectedly good number deserves the same suspicion as a bad one.

---

## 12. Third measurement

### 12.1 Raster is holding, and the trend is real

| run | cold raster avg | cold janky |
|---|---|---|
| baseline | 9.8ms | 28.4% |
| after §10 | 6.7 / 7.1ms | 16.1% / 23.6% |
| this run | **6.7ms** | 20.3% |

Three cold loads now: 16.1%, 23.6%, 20.3%. Mean ~20%, spread ±4 — so the drop
from 28.4% is real, and anything under ~5 points is noise. Raster average has
been 6.7-7.1ms across every run since the shadow and clip work, against a
16.7ms budget.

One refresh landed at **4.3% janky, MIXED (build 2.7ms, raster 3.2ms)** — the
first window in this whole exercise to come in genuinely fast. That is what the
screen looks like when little has changed and nothing needs repainting.

### 12.2 Checkout is instant, and the zero was honest this time

```
── API checkout open ──
requests: 0   bytes: 0B   wall: 55ms / 90ms / 81ms
```

Three opens, no requests, under 100ms each. The §11 fixes hold: the cached
store is reused *and* the distance still computes, and the shimmer no longer
waits on it.

The "no frames captured" line was the window closing synchronously at the end
of `initCall`, before anything painted — technically accurate, practically
useless. It now closes on a post-frame callback.

### 12.3 Duplicate requests: the guard that loses a race

Cold load went 17 → 22, and the trace named them:

```
3×  /api/v1/stores/get-stores/all   91.7KB
2×  /api/v1/module                  20.8KB
2×  /api/v1/customer/cart/list
```

Home calls `getModules()` twice: once unconditionally, once from the
quick-delivery rail behind `if (moduleList == null)`. Both run inside the same
`Future.wait`, so **the guard loses the race** — the second caller reads null
before the first has assigned anything.

`if (x == null) fetch()` is not a guard against concurrency. It only works
against sequential repeats.

`getModules` and `getFeaturedStoreList` now coalesce: a caller arriving while a
fetch is in flight joins it. Same shape as `CartController.getCartDataOnline`,
which had already solved this — the pattern existed, it just had not spread.

Clearing is by `identical()` so a stale completion cannot clear a newer fetch.
`test/unit/request_coalescing_test.dart` pins all three.

### 12.4 Where this leaves the numbers

| | baseline | now |
|---|---|---|
| cold janky | 28.4% | ~20% |
| cold raster avg | 9.8ms | 6.7ms |
| cold requests | 16-29 | 17 expected after coalescing |
| checkout open | shimmer forever on failure | <100ms, 0 requests |

**Refresh remains the worst case** — 55.3% on the populated one this run. Still
raster, still the `Opacity` pass in §10.3 as the next lever.

---

## 13. The Opacity pass, and what it was actually worth

### 13.1 The count was wrong — 6, not 54

§9.3 listed "54 `Opacity` uses" as the third lever. That grep matched
`.withOpacity(...)` **colour calls**, which are free — they produce a colour
value, not a layer. Actual `Opacity` **widgets** in home and the shared
widgets: **six**.

That is the fifth miscount in this plan (§21.5 lists the first four). The
pattern is identical every time: a grep-able proxy adopted as the metric,
without checking that the thing being counted is the thing that costs.

### 13.2 The two that mattered

Both are the "closed store" dim, in `module_store_row_card` and the grocery
home list:

```dart
Opacity(opacity: isOpen ? 1.0 : 0.55, child: ...)
```

`Opacity` allocates an offscreen buffer and composites it back **at any value,
including 1.0** — where the result is identical to not wrapping at all. Most
stores are open most of the time, so every row in a scrolling list paid for a
layer that did nothing.

Both now skip the wrapper entirely when the store is open. The dim stays for
closed stores, where it is a real requirement.

The other four are in dialogs and a letter animation — one-shot surfaces, not
scrolling lists. Left alone.

### 13.3 What is deliberately NOT being removed

Each card still carries four small blurs on **badges inside it**: a logo tile
lifted off the cover photo, a rating pill, a discount tag, a coloured
info chip. They are genuine visual design — the thing that makes a card read as
layered rather than flat.

Removing them would buy raster time, and it is a **design decision, not a
performance fix**. Flagging rather than doing it: if the brand is willing to
lose the badge lift, there is measurable time in it. That is a call for whoever
owns the look, not something to take unilaterally.

The card's own shadow (one per card, already halved in §10.1) stays regardless.

### 13.4 Expected effect

Small. Two layers per visible row in two lists, against a cold raster average
already down to 6.7ms. The refresh case — 55-75% janky, raster 12-14ms — is
where the remaining cost is, and it is spread across many small paints rather
than concentrated in one fixable thing.

Measure before assuming otherwise.

---

## 14. Orders and tracking

Reported as "orders and order tracking so slow, and order updates". Three
separate causes, none of them rendering.

### 14.1 The dashboard downloaded 50 orders to light a badge

`getRunningOrders(1, fromDashboard: true)` requested **limit 50**, and the
dashboard used the result for exactly one thing:

```dart
hasRunningOrders: orderController.runningOrderModel!.orders!.isNotEmpty
```

37.3 KB on every home load and every refresh — and the traces show
`running-orders` appearing in nearly every window — to answer a boolean. One
order answers `isNotEmpty` as well as fifty, and `total_size` in the response
carries the real count for anything that needs it.

`fromDashboard` now requests **1**. The order screen still asks for 10; it
renders the list.

### 14.2 The tracking poll rebuilt everything every 10 seconds

`timerTrackOrder` fires every 10s while a tracking screen is open and called a
bare `update()` on each tick — rebuilding all **15**
`GetBuilder<OrderController>` trees, the map included, whether or not anything
had changed. A rider stopped at a light still cost a full rebuild every ten
seconds, for the length of the delivery.

It now compares the fields a user can actually see — status, rider lat/lng,
rider identity, amount — and only rebuilds when one moved. A failed poll still
updates, because the error state has to show.

This is the one place where M4's rebuild story *is* the cost, and it is worth
noting why: not because 15 builders is many, but because it repeats on a timer.
A rebuild that happens once when a screen opens is invisible; the same rebuild
on a 10-second loop is a stutter the user learns to expect.

### 14.3 The marker was always one tick behind

```dart
Get.find<OrderController>().timerTrackOrder(...);   // not awaited
updateMarker(...trackModel...);                     // reads the OLD model
```

Every rider position was drawn from the *previous* poll — ten seconds stale,
permanently — and the first tick drew against whatever the screen happened to
load with. Now awaited.

The same call also banged through `trackModel!`, which took the screen down on
a dropped connection mid-delivery. Read once, null-checked, then used.

### 14.4 What was not the problem

Order history and running orders are **not** module-scoped server-side
(`Order::scopeScopedToRequester` filters by user or guest only), so the
`moduleId` header bug that emptied the cart does not apply here.

`OrderController` has 25 bare `update()` calls and 0 scoped. Only the polling
one was worth changing — the others fire on user actions, where a rebuild is
both expected and invisible.

---

## 15. Cold start measured — and it was one thing

```
── BOOT to runApp ────────────────────
total: 2039ms   measured: 2034ms
   1500ms   74%  firebase.init
    503ms   25%  di.init
     18ms    1%  notifications
     13ms    1%  deeplinks
      0ms    0%  intl.localeData
      5ms    0%  (unmeasured)
```

Two seconds before the first frame. That is the `Skipped 61-79 frames` line
every trace has opened with, and it is the single largest number in this whole
exercise — bigger than any rendering cost measured.

### 15.1 The instinct was wrong again

§22.3 named `initializeDateFormatting` as the obvious thing to defer, and
flagged the risk of a `LocaleDataException` in exchange.

**It costs 0ms.** The locale data is compiled in, not fetched. Deferring it
would have risked a crash on home to save nothing at all — the sixth time in
this plan that acting on an untested guess would have been wasted or harmful
work (§13.1 lists the first five).

Notifications and deep links are 31ms between them. Nothing but Firebase and DI
matters here.

### 15.2 `di.init` never needed to wait

`di.init` registers SharedPreferences, the `ApiClient` and the controllers.
None touches a Firebase API in its constructor — `CrashContext.recordBuild()`
is fire-and-forget. It had no reason to queue behind Firebase; it simply came
second in the file.

Firebase and deep links now start first and are awaited where they are
genuinely needed, with `di.init`'s 503ms overlapping Firebase's 1500ms.
Expected total ~1,550ms, a **~490ms saving** on every cold start.

The notification read still blocks, and correctly: `body` decides the initial
route, so the first frame cannot be chosen without it.

### 15.3 The 1500ms itself is the real target

`Firebase.initializeApp` taking 1.5s on a Snapdragon 730 is slow even for a
mid-range device. Every trace carries the likely reason:

```
E/com.facebook.GraphResponse: {HttpStatus: 400, errorCode: 190,
  errorMessage: Error validating application. Application has been deleted.}
```

**About a dozen of these per boot.** The Facebook SDK auto-initialises from
`AndroidManifest.xml` with app id `380903914182154`, which **no longer exists**
upstream, and retries. Those are failing network round trips during startup,
competing for the main thread with Firebase.

Three things follow, and none is a code change to make blind:

1. **Meta ads attribution is currently dead.** Every `logAddToCart`,
   `logInitiateCheckout` and `logPurchase` in `analytics_helper.dart` is going
   to a deleted app. Campaigns cannot be optimising on events that never
   arrive.
2. **Every session pays for the retries** — network, battery, and startup time.
3. **Fixing it is an account action, not a commit:** either restore/recreate
   the Meta app and update `facebook_app_id`, or remove the SDK until there is
   one. Both are decisions for whoever owns the ads work.

Re-measure after that is resolved. If `firebase.init` stays at 1.5s with the FB
SDK quiet, the next candidates are deferring Crashlytics collection and
Analytics auto-init past the first frame — but that is a guess, and this
section is the sixth reminder to measure instead.
