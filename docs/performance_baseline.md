# Performance: measure before scoping

**Status:** instrumentation landed, **baseline not yet taken**
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
