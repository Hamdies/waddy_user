# Spots — Claw Machine Winner Picker

Implementation plan for the claw-machine voter draw screen, imported from the
Claude Design project `823bc3e8` (`Claw Machine Winner Picker.dc.html`), built
against the WADDI Spots design system `bb4b3c6b`.

Work items are `CLAW-01 … CLAW-14`. Phases are ordered: nothing in a later phase
compiles without the one before it.

---

## 0. What the screen is

A weekly **voter draw**. Every user who voted in the round goes into a claw
machine as a ball. One press runs the whole draw: the claw makes N grabs, each
pulling one random ball out of the pile. Pulled voters land in a "PULLED BY THE
CLAW" result list; everyone left gets a consolation panel.

`N` is **`pull_count` from the payload**, not a client constant. The design
assumes 3; the live backend draws `prize.winners_per_week`, **default 5** (§8.1).
Treat 1–8 as the supported range.

It is theatre over a result the server already decided. That distinction drives
the entire design below — see §2.

### Source of truth

| Concern | Source |
|---|---|
| Layout, copy, animation timings | `Claw Machine Winner Picker.dc.html` |
| Colour / type / spacing tokens | already ported to `lib/common/widgets/spots/spots_theme.dart` |
| CTA button | `Spots` button conventions already in the module |

The design's raw token names map to Dart constants that **already exist**:

| CSS | Dart |
|---|---|
| `--mint` `#1EF2A0` | `Spots.mint` |
| `--teal` `#134E4A` | `Spots.teal` |
| `--teal-900` `#0C3532` | `Spots.teal900` |
| `--panel` `#0E3532` | `Spots.panel` |
| `--red` `#FF3B30` | `Spots.red` |
| `--ink` / `--ink-3` | `Spots.ink` / `Spots.ink3` |
| `--paper` / `--paper-2` | `Spots.paper` / `Spots.paperWarm` |
| `--border` | `Spots.border` |

**No new colour constants.** Three design values have no Dart equivalent
(`--paper-3` `#E7ECEA`, `--mint-100` `#D6FCEC`, `--mint-200` `#A7F8D4`,
`--teal-100` `#D3E0DE`); `CLAW-02` adds them to `spots_theme.dart` rather than
letting literals land in a screen file.

### One deliberate divergence from the design

The design uses **3px borders, 4px hard shadows, 6–10px radii** — the original
neubrutalist weight. `spots_theme.dart` documents that the module was softened
one step in Sept 2026 (`borderThin 1.5` / `borderThick 2.5`, `radiusLg 16`,
shadow at 80% opacity) precisely because "everything shouted at the same
volume."

**Decision: follow the shipped Dart tokens, not the design's raw CSS.** A screen
that reverts to 3px/6px would be the only one in the app doing so. The cabinet
itself — the one hero element — keeps `borderThick` and the mint hard shadow, so
it still reads as the loudest thing on screen, which is the design's intent.

---

## 1. Files

**New:**

```
lib/features/places/domain/spots_draw.dart          # pure state machine
lib/features/places/domain/spots_draw_geometry.dart # pile slots + claw travel
lib/features/places/domain/spots_draw_timeline.dart # grab steps as pure frames
lib/common/widgets/spots/spots_marquee.dart         # shared, ex-live_news_bar
lib/features/places/domain/models/draw_entrant_model.dart
lib/features/places/screens/spots_claw_draw_screen.dart
lib/features/places/widgets/claw/claw_cabinet.dart  # glass box + lighting + balls
lib/features/places/widgets/claw/claw_arm.dart      # the claw itself (CustomPainter)
lib/features/places/widgets/claw/claw_ball.dart     # one voter ball
lib/features/places/widgets/claw/claw_marquee.dart  # scrolling ticker
lib/features/places/widgets/claw/claw_winner_row.dart
test/unit/spots_draw_test.dart
test/widget/spots_claw_draw_test.dart
```

**Modified:**

```
lib/helper/route_helper.dart                        # route + getter
lib/helper/notification_helper.dart                 # spots_draw_ready → claw
lib/features/places/controllers/places_controller.dart   # fetch entrants
lib/features/places/domain/repositories/…           # draw endpoint call
assets/language/en.json + ar.json                   # ~16 keys
```

**Backend (Phase Z, §9):**

```
Modules/PlacesToVisit/Database/Migrations/…_create_place_draw_entrants_table.php
Modules/PlacesToVisit/Entities/PlaceDrawEntrant.php
Modules/PlacesToVisit/Http/Controllers/Api/DrawController.php
Modules/PlacesToVisit/Services/PrizeDrawService.php       # persist the pool
Modules/PlacesToVisit/Routes/api/v1/api.php               # before {place}
```

> **This list is the plan as written, not the final inventory.** Five more
> files landed than anticipated (`spots_draw_timeline.dart`,
> `spots_draw_fixtures.dart`, `spots_draw_demo.dart`, `claw_masthead.dart`,
> and four more test files). §11.1 is the authoritative list.

> `test/widget/` did not exist before this feature — it is now the project's
> first widget-test directory, and `flutter test` picks it up.

---

## 2. Phase A — domain, no Flutter (CLAW-01 … CLAW-04)

The design's `.dc.html` script mixes three things that must be separated in
Dart: **who wins**, **where things are on screen**, and **what time it is**.

### CLAW-01 — `DrawEntrant` model

```dart
class DrawEntrant {
  final int userId;
  final String name;
  final String handle;
  final int votes;
  final int rank;      // 0 = not pulled; 1..N = pull order
  final bool pulled;
}
```

`initials` getter ports the design's `ini()` — first letter of first word +
first letter of last word, uppercased.

> **Guard the design misses.** `ini()` does `n.split(" ")` then `w[0][0]` — it
> crashes on an empty name and on a leading space. Real backend display names
> include both. `initials` must handle empty / single-word / whitespace-only and
> fall back to `'?'`. This is a test case, not a comment.

### CLAW-02 — missing tokens into `spots_theme.dart`

Add `paperSunk` (`#E7ECEA`), `mint100` (`#D6FCEC`), `mint200` (`#A7F8D4`),
`teal100` (`#D3E0DE`) with the same doc-comment style as the existing block.

### CLAW-03 — `SpotsDraw` state machine

A pure class, zero Flutter imports, mirroring `spots_stage.dart` /
`spots_round.dart` in style (heavy doc comment explaining *why*).

```dart
enum DrawPhase { loading, ready, picking, done }
```

Holds: `phase`, `entrants`, `winners`, `heldEntrantId`, `clawOpen`, `clawX`,
`clawY`. Exposes `statusLine`, `hintLine`, `ctaLabel`, `ctaEnabled` — the four
derived strings the design computes inline in `renderVals()`.

**The important departure.** The design picks winners on-device:

```js
const target = pool[Math.floor(Math.random() * pool.length)];
```

That is fine for a mockup and wrong for a real prize draw — the client would be
deciding who wins, and anyone could patch the APK. `SpotsDraw` therefore takes
the winner list **as input**:

```dart
SpotsDraw.fromServer({required List<DrawEntrant> entrants,
                      required List<int> winnerIds})
```

The animation replays a decided outcome. A `SpotsDraw.local()` constructor keeps
the design's random behaviour for **test data only** (§5) and is the only place
`Random` appears.

### CLAW-04 — pile geometry

Port `PILE` (12 fixed x/y slots), `BS = 62`, `GW/GH = 350/342`, `HANG = 116`,
`GRABOFF = 97`, `PARK = 10`, `PARKX = 46` as named constants with a comment
that they are a **350×342 design-space grid**, scaled at render time.

> **The fairness invariant: every winner is in the glass.**
>
> A real round can have a thousand voters; the pile holds twelve. If the claw
> reached for someone who was not already on screen, the screen would have to
> conjure a thirteenth ball mid-grab, or swap one silently — and a user who
> screenshots the pile could prove it changed. Forcing a winner from the
> visible twelve instead would be worse still: the client would be showing a
> different outcome than the server decided.
>
> `SpotsDraw.visibleEntrants(slots)` therefore partitions winners-first before
> taking N, so the claw only ever grabs a face that was in the glass from the
> first frame, and the overflow plate states the hidden remainder honestly.
> The backend already sorts this way, but ordering is not a guarantee — a
> cache or a re-sort could undo it silently — so it is enforced client-side
> where the pile is drawn. Seven unit tests and two widget tests pin it,
> including a 1000-entrant round with winners at indices 517 and 918.
>
> `_targetSlot` indexes into the *visible* list for the same reason: aiming by
> the full-list index would send the claw to an empty slot, or to a
> bystander's face.

> The design hardcodes 12 slots and 12 voters. A real round has any number.
> `pileSlot(index)` must wrap (`PILE[i % PILE.length]`) and the cabinet renders
> at most `PILE.length` balls, with an overflow count. Decide the copy with
> product; `+N MORE IN THE MACHINE` is the placeholder.

---

## 3. Phase B — static widgets (CLAW-05 … CLAW-09)

Build every piece **at rest** first, with animation stubbed. Each is independent
and reviewable on its own.

- **CLAW-05 — masthead.** `Spots.panel` bar: eyebrow (`Maadi · Week 27 · Voter
  draw`, 11px/500/`.14em`/mint), `THE CLAW` (30px/900/`-.03em`), and the LIVE
  pill (mint 2px border, pulsing red dot). Reuse `spots_masthead.dart` patterns
  where they fit rather than re-deriving.
- **CLAW-06 — `claw_marquee.dart`.** Three phrases, seamless loop. Must **pause
  when off-screen or on reduced-motion** (§6).

  > **Landed differently, and better.** `live_news_bar.dart` already contained a
  > seamless marquee — private, but RTL-aware, edge-faded, text-scale-aware and
  > with a short-run guard the design's CSS never needed. Rather than port
  > `translate(-50%)` a second time, it was promoted to
  > `lib/common/widgets/spots/spots_marquee.dart` and both callers now share it.
  > `ClawMarquee` is just the three phrases plus the pause policy.
- **CLAW-07 — `claw_cabinet.dart`.** The hero. Mint frame, `borderThick`, mint
  hard shadow, `radiusLg`. Inside: the `teal100` glass, top light bar (4 pulsing
  bulbs + rail), the skewed glass-reflection overlays, and the footer plate
  (`WADDI · MDL-27`). Lighting modes (`twinCones`, `topWash`, `threeBars`,
  `strobe`, `off`) become an enum — **default `twinCones`**, matching the design.
- **CLAW-08 — `claw_ball.dart`.** 62px circle, `borderThick`, `teal900` offset
  shadow, initials at 20px/900 in `Spots.teal`, fill cycling the 6-colour list,
  static rotation per index. The `lost` variant desaturates to `paperSunk` and
  shows the 😢 badge.
- **CLAW-09 — `claw_arm.dart`.** A `CustomPainter`, not nested widgets — the
  design's SVG is three bezier jaws plus a housing circle carrying the Waddi
  logo. Painter takes `openAmount` (0–1) and rotates the outer jaws ±15°, with
  the centre jaw translating −4px. Cable is a plain rect from the rail down.

---

## 4. Phase C — animation (CLAW-10, CLAW-11)

### CLAW-10 — the grab sequence

The design's `seq()` per grab, ported to an `AnimationController` timeline:

| ms | step |
|---|---|
| 60 | claw travels to target X, jaws open |
| 700 | claw descends to `ball.y − GRABOFF` |
| 700 | jaws close, ball becomes held |
| 300 | claw retracts to `PARK` |
| 650 | ball flies up and out (fade + scale), winner appended |
| 520 | gap before next grab |

≈3.03s per grab. The design's 3 grabs is ~9.1s; **the live default of 5 is
~15.2s** (§8.1), and at the 8-grab ceiling ~24s. Curves port directly:
`cubic-bezier(.4,.1,.2,1)` for travel, `(.3,1.5,.5,1)` for the jaw snap,
`(.3,1.4,.6,1)` for the ball settle.

> **Do not use `Future.delayed` chains.** The design's `setTimeout` list leaks
> on unmount — it clears timers in `componentWillUnmount`, and we would have to
> get the same discipline right by hand across a screen with a back button. One
> `AnimationController` + `TickerProviderStateMixin` is disposed correctly by
> construction.

### CLAW-11 — entry and result

Balls drop in from above with a per-slot `65ms` stagger (design:
`transitionDelay: slot * 65ms`), gated on a `dropped` flag set at 120ms.
`ready` at 1600ms. Winner rows use the `slam` keyframe — a 380ms
scale `1.14 → .97 → 1` with a −3° → +1° → 0 rotation.

On `done`, fire `showSpotsConfetti()` — already in
`lib/common/widgets/spots/spots_confetti.dart` — only when `my_prize_id != null`.
Confetti for a loss would be a bug. (The helper already no-ops under reduced
motion at `spots_confetti.dart:22`, so CLAW-13 needs no extra guard here.)

### CLAW-11b — skip

At 15s the run is no longer something a user can be assumed to want twice. A
**SKIP** control appears once `picking` starts and jumps straight to `done`:
all winners listed, no confetti suppression, no half-finished claw. It shares
the reduced-motion code path from CLAW-13 — that path must exist anyway, so skip
is nearly free, and it is the difference between theatre and a hostage
situation for anyone who opens the screen a second time.

The screen is reachable from a push (§8.3), so a returning user hitting a
15-second unskippable animation to re-read their own voucher code is the
failure mode this prevents.

---

## 5. Phase D — test data (CLAW-12)

The design ships 12 hardcoded voters (`Farida Nabil @faridaaa 14` …
`Aya Mostafa @ayam 4`). Port them verbatim into
`lib/features/places/domain/spots_draw_fixtures.dart`, behind a
`kSpotsDrawPreview` const flag.

> **Guard this hard.** `home-preview-flags-mock-data` is already a known trap in
> this codebase: preview flags rendering fake stores have caused real confusion
> when reading screenshots. This flag must be `const bool kSpotsDrawPreview =
> bool.fromEnvironment('SPOTS_DRAW_PREVIEW')` — **compile-time false by
> default**, so the fixtures are tree-shaken out of release builds entirely and
> cannot be left on by accident. When on, the screen shows a `PREVIEW DATA`
> ribbon.

Fixtures cover: the 12-voter happy path, a 2-entrant round (fewer entrants than
picks), a 0-entrant round, an 18-entrant round (pile overflow), and one entrant
with a single-word name and one with an empty name.

Each fixture is the **CLAW-Z2 payload shape verbatim** — `pull_count`,
`total_entrants`, `winner_ids`, `my_prize_id`, `is_me` — so the swap from
fixture to live response is a source change, not a remodel. Add two more that
only the real backend produces:

- **5 winners** (`pull_count: 5`), the live default — the happy path fixture
  should be this, with the design's 3 kept as a second case.
- **A backfilled period**: `total_entrants: null`, losers absent, winners
  present. §9 CLAW-Z4 says this will exist in production on day one.

---

## 6. Accessibility and motion (CLAW-13)

Not optional, and cheap if done alongside rather than after.

- **Reduced motion.** `MediaQuery.disableAnimations` → skip the claw run
  entirely: balls appear placed, winners appear already listed, marquee holds
  static, bulbs and cones stop. The screen must be fully usable with every
  animation off, because the result is server-decided anyway.
- **Semantics.** The cabinet is decorative (`ExcludeSemantics`). Announce phase
  changes via `SemanticsService.announce` — "Picking", then each winner by name.
  Winner rows read "Pick 1, Farida Nabil, 14 votes."
- **Text scale.** The masthead, marquee and status line all use `white-space:
  nowrap` in the design and will clip at large text scale. Every nowrap string
  needs a decision: `FittedBox` for the masthead, marquee scrolls so it is fine,
  status line wraps.
- **Touch targets.** The two ◀ ▶ side plates are 44px — at `--touch-min`
  exactly. **They have no behaviour in the design.** Either wire them (previous
  / next round) or make them decorative and `ExcludeSemantics` — do not ship a
  44px thing that looks pressable and is not.
- **Localisation.** ~14 new keys. Per `translation-keys-workflow`, every key
  lands in **both** `en.json` and `ar.json` in the same commit — a missing key
  renders as the raw key, silently. The marquee and `THE CLAW` are ALL-CAPS
  Latin; Arabic has no case, so the Arabic strings need their own weight/size
  treatment, not `toUpperCase()`.

---

## 7. Testing (CLAW-14)

Three layers, matching what the module already does
(`test/unit/spots_module_test.dart`, 21 tests).

### Unit — `test/unit/spots_draw_test.dart`

Pure, no `pumpWidget`, fast. The state machine is where correctness lives.

- `initials`: two words → `FN`; one word → first letter; empty → `?`;
  whitespace-only → `?`; leading/trailing spaces; a name with three words uses
  first + last. **These are the design's crash cases.**
- Phase order `loading → ready → picking → done`; CTA disabled in `loading` and
  `picking`; `ctaLabel` per phase.
- `fromServer` pulls **exactly** the server's winner ids, in order, never a
  random one.
- Pull count comes from the payload and clamps to 1..8 (§8.1 — **not** the
  design's 1..4); a round with fewer entrants than picks pulls all of them and
  terminates (the design's `if (!pool.length) return this.finish()`).
- A `winner_ids` entry with no matching entrant (backfilled period, §9 CLAW-Z4)
  is skipped, not crashed on.
- `my_prize_id == null` → no confetti, winner rows not tappable.
- Zero entrants → stays out of `picking`, shows an empty state.
- `statusLine` counts correctly (`0/3` → `3/3`).
- No entrant is pulled twice across a full run.
- `pileSlot` wraps past 12.
- `SpotsDraw.local()` with a seeded `Random` is deterministic.

### Widget — `test/widget/spots_claw_draw_test.dart`

- Renders at 430×932 with **no overflow** — the design is a fixed 430px canvas
  and this is the most likely regression.
- Renders at `textScaleFactor` 1.3 and 2.0 without overflow.
- Reduced-motion: `pumpWidget` inside `MediaQuery(disableAnimations: true)`,
  tap CTA, `pump()` once → winners already present, no pending timers.
- CTA disabled during `picking` — tapping again mid-run does not start a second
  draw (the design guards with `if (this.state.phase !== "ready") return`).
- `tester.pumpAndSettle()` after a run completes → **no timers pending**. This
  is the unmount-leak test; it fails loudly if anyone reintroduces
  `Future.delayed`.
- Dispose mid-animation: pump the CTA, `pump(400ms)`, then unmount → no
  exception.
- Empty round renders the empty state, not a broken cabinet.
- SKIP mid-run (CLAW-11b) → all winners listed, no pending timers, and the
  confetti decision matches a full run's.
- A 5-grab run (the live default, not the design's 3) completes and lists five.

### Golden

`test/golden/` currently holds `spots_marks.png` and a **fully commented-out**
`marks_render_test.dart` — the module's golden layer is not live. Do not add
goldens of a 9-second animation. **One** golden of the cabinet at rest
(`phase: ready`, `twinCones`, animations disabled) is worth it; anything
animated is not.

### Running

Per `no-builds-user-tests`, I run `flutter analyze` and `flutter test` and hand
off — no `flutter build` / `flutter run`. Device verification is yours.

---

## 8. Resolved questions

Settled 2026-09-17 against the backend as it actually stands. The findings
changed the plan's shape, so they are recorded here rather than deleted.

### 8.1 The draw already exists server-side — and it is better than assumed

`Modules/PlacesToVisit/Services/PrizeDrawService::drawFor()` runs the real
draw the moment a venue is crowned:

- Pool = distinct voters for the winning venue that period, `is_flagged = false`
- Minus anyone inside `winner_cooldown_days` (default 30)
- `inRandomOrder()->limit($limit)` where `$limit = prize.winners_per_week`
  (**default 5**, not the design's 3)
- Overall champion only — zone champions crown but do not draw
- Idempotent per period (`PlacePrize::forPeriod()->exists()`), which is
  load-bearing because `WinnerService::closePeriod()` is lazily invoked on
  every read of the public winners endpoints

So §2's "the animation replays a decided outcome" is not an aspiration — it is
already true. The client never had a decision to make. **Keep `SpotsDraw.fromServer`
exactly as designed.**

> **Correction to §0 and §3.** The design's default of 3 grabs (range 1–4) does
> not match the backend's 5 per week. `pullCount` must come from the payload,
> not a client constant, and the claw must handle **5 grabs ≈ 15.2s** — long
> enough that a skip control is no longer optional (see CLAW-11b).

### 8.2 The gap: entrants are never persisted

`eligiblePool()` computes the pool and **discards the losers**. Nothing in the
schema records who was in the machine — `place_prizes` holds winners only, and
`winners/recent` returns just those. The claw needs the losing balls.

Resolved: **add the endpoint** (Phase Z below). The existing query is the whole
of the logic; what is missing is persistence and exposure.

### 8.3 Entry points — all three

| Path | Status |
|---|---|
| Push on win | Plumbing exists. `notifyWinner()` sends `type: 'spots_prize_won'` with the prize id as `data_id`; [`notification_helper.dart:506`](../lib/helper/notification_helper.dart#L506) already parses it into `NotificationType.spots_prize`. Intercept there. |
| Spots home | New entry card. Reachable by winner and loser alike — which is what makes the consolation panel mean anything. |
| Round-close push to all voters | **New backend work.** No such send path exists; `notifyWinner()` only touches winners. New notification type + a fan-out over the period's voters. |

### 8.4 Prize is a `PlacePrize`, rows are not terminal

Confirmed. `spotsPrizeDetails` exists at [`route_helper.dart:175`](../lib/helper/route_helper.dart#L175)
and takes a prize id. A winner row for **the current user** routes into it; other
winners' rows are not tappable (no prize id is exposed for them, by design —
`winners/recent` deliberately omits codes).

### 8.5 The ◀ ▶ plates are decorative

`ExcludeSemantics`, non-pressable, visually part of the cabinet chrome. No 44px
target that does nothing.

---

## 9. Phase Z — backend (CLAW-Z1 … CLAW-Z4)

Lands in `waddy_back/Modules/PlacesToVisit`. **Blocks Phase E only** — Phases A–D
build against the contract and the fixtures, so client work starts immediately.
User deploys; per `get-stores-filter-contract`, I do not.

### CLAW-Z1 — persist the entrant pool

New table `place_draw_entrants`, written inside `drawFor()`'s existing
transaction so entrants and prizes commit together or not at all:

```
id, period, place_winner_id, place_id, user_id,
votes (their vote count that period), rank (0 = not pulled, 1..N = pull order)
unique (period, user_id)
```

`eligiblePool()` currently returns only the capped winners. Split it: one query
for the **full** eligible pool (uncapped), then the random pick over it. Write
every pool member as an entrant row; stamp `rank` on the pulled ones in pull
order. This is the one change that makes the whole screen possible.

> **Cap the stored pool.** A popular venue could have thousands of voters and
> the payload must not carry them all. Store at most `draw.max_entrants`
> (suggest 60) — the pulled winners **always**, plus a random sample of losers
> to fill. The response carries `total_entrants` so the overflow copy in
> CLAW-04 states the true number, not the sampled one.

### CLAW-Z2 — the endpoint

```
GET /api/v1/places/draw/{period?}   → public, defaults to last closed period
```

Declared **before** the `{place}` catch-all in `api.php` — `prizes/my` already
had to dodge that trap and the comment there says so.

```json
{
  "period": "2026-W27",
  "place": { "id": 12, "title": "…", "image": "…" },
  "pull_count": 5,
  "total_entrants": 143,
  "entrants": [
    { "user_id": 88, "name": "Farida N.", "handle": "@faridaaa",
      "votes": 14, "rank": 1, "is_me": false }
  ],
  "winner_ids": [88, 41, 7, 19, 60],
  "my_prize_id": 331
}
```

- `name` uses the **same** "first + last initial" masking as
  `LeaderboardService::getRecentPrizeWinners()` — do not invent a second
  masking rule for the same people.

> **`votes` is the week's total, not this venue's.** `place_votes` is unique on
> `(place_id, user_id, period)`, so counting a user's votes *for the winning
> venue* always returns exactly 1 — a winner list where everyone is credited
> with "1 vote" says nothing. The stored count is the user's votes that week
> across all venues, which is what `LeaderboardService` already means by a
> voter's score and therefore what the row should show. Snapshotted at draw
> time, because votes can be flagged or removed afterwards and the replay must
> show the round as it was.

> **`handle` ships empty.** The design has `@faridaaa`; the `users` table has
> no handle column. Rather than invent one from an email local-part, the field
> is present-but-empty and `ClawWinnerRow` already hides the line when it is.
> Populating it is a schema decision, not a rendering one.

> **`image` is the payload's point, added 2026-09-17.** The balls render
> **faces**, not monograms — a machine full of actual people, and the claw
> reaches in and picks one up, is the joke the whole screen is built around.
> `DrawEntrant.image` parses `image_full_url` then `image` through
> `pickImageUrl`, the same two-candidate pick every other model in this module
> uses; `User` already appends `image_full_url`, so the backend needed one
> field, not a schema change. No new disclosure either — `winners/recent`
> already pairs a voter's avatar with their masked name on the Spots home.
>
> `initials` stays as the fallback for a user with no photo, and a lost ball
> goes greyscale rather than grey-blank so you can still see who is out.
- `is_me` is set only for an authed request; guests get all `false`.
- `my_prize_id` is null unless the caller won — it is what makes the winner row
  tappable and gates the confetti in CLAW-11.
- `winner_ids` order **is** the pull order. The client animates it verbatim.

### CLAW-Z3 — round-close push to all voters

New type `spots_draw_ready`, fanned out to the period's voters after
`drawFor()` commits. Follows `notifyWinner()`'s constraint exactly: the FCM
helper forwards only a fixed key list, so the period travels as `data_id`.
Batched and queued — this is the first Spots push that goes to a whole voter
pool rather than five people.

> **Production has a malformed period.** The first `--dry-run` on 2026-09-17
> reported three periods: `2026-W31`, `2026-W32`, and **`9`** — the last with
> 5 prizes, which is the live `winners_per_week` default and so looks like a
> real draw rather than junk. `place_prizes.period` is an unconstrained
> `varchar(10)`, and the route constraint on `places/draw/{period?}` means
> period `9` can never be served. **Unresolved:** where it came from
> (`SimulateWeekCommand` passes `--period` through unvalidated and defaults to
> `RaceClock::lastClosedPeriod()`, so a hand-typed `--period=9` is the leading
> theory) and what should happen to those 5 prizes. The backfill now refuses
> malformed periods and names them rather than extending the problem into a
> second table.

### CLAW-Z4 — backfill

Existing periods have prizes but no entrant rows. A command that replays the
pool query for past periods cannot recover *who lost* (votes may have been
edited since), so it backfills **winners only**, with `total_entrants` null.
The screen must render a draw whose losers are unknown: pile shows winners plus
a "…and N others" plate. Alternative — show the claw only for periods from the
feature's launch onward — is simpler and worth considering with product.

---

## 10. Order of work

| Phase | Items | Gate |
|---|---|---|
| A ✅ | CLAW-01 … 04 | **Landed 2026-09-17** — `spots_draw_test.dart`, 38 tests green |
| B ✅ | CLAW-05 … 09 | **Landed 2026-09-17** — `spots_claw_draw_test.dart`, 22 tests green |
| C ✅ | CLAW-10, 11, 11b | **Landed 2026-09-17** — `spots_claw_run_test.dart` (18) + `spots_draw_timeline_test.dart` (14), no pending timers |
| D ✅ | CLAW-12, 13 | **Landed 2026-09-17** — `spots_claw_fixtures_test.dart` (38) + `spots_claw_a11y_test.dart` (14); 23 keys in both locales |
| Z ✅ | CLAW-Z1 … Z4 | **Written 2026-09-17** — 8 files lint-clean, `spots_draw_contract_test.dart` (15) green. **Not yet deployed or migrated.** |
| E | CLAW-14 | full suite + `flutter analyze` clean, hand off |

Phase A is worth landing alone — it is the part that carries the correctness,
it is ~30 minutes of review, and it is the part the design got wrong.

Phase Z runs **in parallel** with A–D: the contract in CLAW-Z2 is fixed now, the
fixtures in CLAW-12 mirror it field for field, and swapping the fixture source
for the live one is the last commit rather than a rewrite.

---

## 11. Status — 2026-09-17

Everything in §10 is built. `flutter analyze` reports **zero issues** across
every file touched, and the client suite is **328 tests green** (187 of them
this feature's).

### 11.0 Fidelity pass — the machine is one object

The first build rendered the design's parts correctly and its *structure*
wrongly. The design frames the glass, its `VOTER DRAW / 0/3 PULLED` header
strip, the CTA and the hint inside **one mint chassis** with a mint hard
shadow; the build stacked those four as separate sections on the page canvas.

That is not a spacing nitpick. The screen's whole idea is that there is a
machine in front of you and a claw inside it. Four stacked panels are a
*report about* a claw machine; one chassis is the machine. Rebuilt as
`_machine()` in `spots_claw_draw_screen.dart`:

- **Mint chassis**, `--shadow-mint` (`dx/dy: 5`) — the system readme reserves
  the mint lift for "hero / leader moments", and this screen has exactly one.
- **Header strip** — dark `--panel` plate across the brow, title left, the
  pull readout right. The count moved here from below the cabinet: it is a
  readout *on the machine*, and it puts the one number that changes during the
  run at the top of the object the user is already watching.
- **Control deck** — the CTA on a recessed `paperWarm` plate, which is what
  made the design's ◀ ▶ plates read as a panel rather than as floating keys.
- **Hint** — inside the chassis, centred, caps.
- **The cabinet lost its own drop shadow.** A hard shadow on a panel nested
  inside another panel reads as a sticker lying on top of it. The glass is a
  window cut into the front: border, no lift.

**The CTA now follows the DS `Button`** (`_ds_bundle.js`,
`components/actions/Button.jsx`), which the design imports via `x-import` and
the first build hand-rolled:

| State | Was | Now (DS) |
|---|---|---|
| ready / picking | mint / teal ink | unchanged — `primary` |
| **done** | `paperWarm` — read as disabled | **`solid`: teal fill, white ink** |
| **disabled** | same as enabled | **`paper-3` fill, `ink-3` text, flat** |

Radius moved to `radiusMd` on both buttons, matching the DS `md` size.

One divergence from the design stands, deliberately: **the ◀ ▶ plates are
still omitted.** Nothing in the payload is previous or next, and per §8.5 a
44pt control that looks pressable and does nothing is worse than no control.

Verified after the pass: **328 tests green**, `flutter analyze` clean, 24
`spots_claw_*` keys in `en.json` and `ar.json` both (the new one is
`spots_claw_panel_title`).

> **The tests caught the regression.** The header strip's two caps labels
> overflowed **164px** at 2.0 text scale on a 320pt screen. The readout is now
> `Flexible` and the *title* is the half that ellipsises, since "VOTER DRAW" is
> also on the masthead two rows up. Three a11y tests and nine fixture tests
> failed until it was fixed — the layer that exists for exactly this.

### 11.1 What exists

**Client — new (14 files):**

| File | Role |
|---|---|
| `domain/spots_draw.dart` | State machine. `fromServer` / `fromApi` / `local`, phases, `visibleEntrants` |
| `domain/spots_draw_geometry.dart` | 12 pile slots, claw travel, overflow count, wrapping |
| `domain/spots_draw_timeline.dart` | The six grab steps as a **pure** `frameAt(t)` |
| `domain/spots_draw_fixtures.dart` | 10 fixtures behind `kSpotsDrawPreview` |
| `domain/spots_draw_demo.dart` | Debug padding helper (§11.4) |
| `domain/models/draw_entrant_model.dart` | One ball — name, votes, rank, `isMe`, **image** |
| `screens/spots_claw_draw_screen.dart` | The screen: one `AnimationController`, skip, confetti gate, announcements |
| `widgets/claw/claw_cabinet.dart` | Glass, lighting enum, bulb rail, reflections, footer plate |
| `widgets/claw/claw_arm.dart` | `CustomPainter` — bezier jaws, housing, cable |
| `widgets/claw/claw_ball.dart` | The face, greyscale when lost, initials fallback, overflow plate |
| `widgets/claw/claw_masthead.dart` | Eyebrow, `THE CLAW`, pulsing LIVE pill |
| `widgets/claw/claw_marquee.dart` | Three phrases + pause policy |
| `widgets/claw/claw_winner_row.dart` | Avatar + rank badge, tappable only for your own win |
| `common/widgets/spots/spots_marquee.dart` | Promoted from `live_news_bar.dart`, now shared |

**Client — modified:** `spots_theme.dart` (4 tokens), `route_helper.dart`
(`spotsClawDraw` + getter + `GetPage`), `app_constants.dart` (`placesDrawUri`),
`places_repository{,_interface}.dart` (`getDraw`), `spots_prizes_screen.dart`
(debug bar), `live_news_bar.dart` (uses the shared marquee),
`en.json` + `ar.json` (**24 keys — 23 `spots_claw_*` plus `spots_a_waddi_voter` — in both files, verified in sync**).

**Backend — committed and deployed** (`c6a87f6`, `94cb1a0`):
`place_draw_entrants` migration, `PlaceDrawEntrant`, `DrawController`,
`PrizeDrawService` (pool split + entrant write), `BackfillDrawEntrantsCommand`,
route, config, provider.

### 11.2 Tests — 187 across 8 files

| File | Tests | Covers |
|---|---|---|
| `unit/spots_draw_test.dart` | 45 | Initials crash set, phase order, pull integrity, **the fairness invariant** (§2), geometry |
| `unit/spots_draw_timeline_test.dart` | 14 | Step ordering — "held before the jaws close" is a millisecond assertion, not an eyeball |
| `unit/spots_draw_contract_test.dart` | 19 | The CLAW-Z2 payload, including faces and hostile shapes |
| `unit/spots_draw_demo_test.dart` | 13 | The padding helper |
| `widget/spots_claw_draw_test.dart` | 24 | Every widget at rest, 320–480px, 2.0 scale |
| `widget/spots_claw_run_test.dart` | 20 | The run, skip, no pending timers, **1000-voter round** |
| `widget/spots_claw_fixtures_test.dart` | 38 | Every fixture rendered *and* run to completion |
| `widget/spots_claw_a11y_test.dart` | 14 | Semantics, announcements, touch targets, RTL |

`test/widget/` did not exist before this feature — it is now the project's
first widget-test directory, and `flutter test` picks it up.

### 11.3 Three bugs the tests caught

1. **A vacuous assertion.** The first `_expectNoOverflow` helper returned `true`
   unconditionally — eleven layout tests that could never fail. Flutter reports
   overflow as a *caught* exception, so only `takeException()` sees it.
2. **A 137px overflow** at 2.0 text scale during a run: skip was unbounded
   beside an `Expanded` CTA. Skip is now capped at 120pt and the CTA label is a
   `FittedBox`.
3. **`_targetSlot` indexed the wrong list.** It searched `_draw.entrants` while
   the cabinet drew `visibleEntrants`. With a pool larger than twelve those
   differ, and the claw would have flown at an empty slot. Found by asking what
   happens with a thousand voters — see the fairness invariant in §2.

### 11.4 Debug launcher (not in the original plan)

`spots_prizes_screen.dart` carries a `kDebugMode`-only bar with three buttons —
**WIN (REAL)**, **LOSE**, **EMPTY**. `kDebugMode` is a compile-time constant, so
the bar and everything it reaches is tree-shaken out of release builds: it
cannot ship and there is no flag to remember.

`SpotsDrawDemo` pads a round to twelve visible balls over a ~1000 pool, entirely
**in memory**. Nothing is written, so there is nothing to clean up — which is
the point, given that seeding test rows into production is what produced the
"9" period (§9 CLAW-Z3). Your own prize is pull #1 and keeps its real
`my_prize_id`, so the win path is genuine rather than mocked. Padded entrants
use negative user ids and pravatar faces; every third has no photo so the
initials fallback is always on screen.

### 11.5 Still unverified — the honest list

- **Nobody has called the live endpoint.** The migration ran and the route
  registered (`GET|HEAD api/v1/places/draw/{period?}`), but no response has
  ever been produced. `spots_draw_contract_test.dart` asserts the client parses
  a payload *hand-written to match the controller* — both halves were written
  from one spec by one author, which is exactly when a contract test agrees
  with itself and both sides are wrong together. **`curl` the endpoint.**
- **The 15-second run has never been watched.** Every timing claim is asserted
  against the clock. Whether the eject reads as a ball *leaving* or *vanishing*
  is a device question, and per `no-builds-user-tests` it is yours.
- **Twelve faces in a 350×342 cabinet** may read as a crowd or as mush on a
  small phone. If it is mush, the fix is fewer visible slots, not smaller balls.
- **Arabic copy needs a native read.** All 23 strings are written in Egyptian
  colloquial to match `waddi-brand-tone` («الكلّاب», «كل صوت كورة جوه الماكينة»).
  The register feels right but has not been checked by a native speaker.
- **The ticker copy is invented.** The design's three phrases were placeholder
  English; these say what the machine actually does. One key each, change
  freely.
- **The `9` period, and its siblings.** `place_votes` holds four period formats
  — ISO weeks, bare integers (`2`–`9`), and year-month (`2026-07`, `2026-02`,
  `2026-04`). Guards now exist in `WinnerService::closePeriod()`,
  `SimulateWeekCommand` and the backfill, so no *new* malformed rows can
  appear. The existing ones are untouched: 5 prizes on period `9` are
  unreachable by the endpoint, and the real backfill has not been run.

### 11.6 What Phase E still needs

1. `curl` the endpoint and compare against §9's payload
2. `php artisan placestovisit:backfill-draw-entrants --dry-run`, then for real
3. Watch a full run on a device
4. Decide the `9` prizes: correct the period, leave, or delete
5. CLAW-Z3 (round-close push) — written but never exercised
6. The one golden of the cabinet at rest (§7), still not added
7. **The fetch is not wired end to end.** §1 lists two files as modified that
   are not:
   - `notification_helper.dart` — untouched. `spots_prize_won` still routes to
     `NotificationType.spots_prize` as before, and nothing handles
     `spots_draw_ready`. Both push entry points in §8.3 reach the prize screen,
     not the claw.
   - `places_controller.dart` — untouched. `PlacesRepository.getDraw()` exists
     and is on the interface, but **no caller invokes it**. The route reads its
     `SpotsDraw` from `Get.arguments` and falls back to the empty state.

   So the chain is: endpoint ✅ → repository ✅ → **controller ✗** → screen ✅.
   The screen has only ever been fed fixtures and the debug demo. Closing this
   is one controller method plus a loading state, and it is the last thing
   between the feature and a real round.

### 11.7 Wired end to end — 2026-10-05

§11.6 item 7 is closed. The chain is now endpoint → repository →
**service (`getDraw`) → controller (`getLatestDraw` / `fetchDraw`)** → screen.

- **Who is in the machine:** the voters of the week's winning venue — the pool
  `PrizeDrawService::eligiblePool()` already draws from. `SpotsDrawRound`
  carries the venue and period around the untouched `SpotsDraw`, and the
  masthead eyebrow names the venue.
- **Entry points:**
  - Spots home — `ClawDrawEntryCard` under the countdown, for the last closed
    round. "The claw picked you!" / "You were in the machine" / "The claw has
    picked", by outcome. Hidden until a round has entrants.
  - Round-close push — `spots_draw_ready` (period as `data_id`) →
    `NotificationType.spots_draw` → `/spots/draw?period=…`, in all three
    dispatch tables (foreground, background-open, cold start).
  - Voucher — "Watch the draw" on the prize details screen, for that prize's
    period.
- **`SpotsClawDrawLoaderScreen`** owns loading / not-found (404) / failed +
  retry, then hands a finished draw to the claw. A malformed period (the legacy
  `9`, `2026-07`) never reaches the request path.
- **Prize screens repaint again.** Both were id-less `GetBuilder`s while
  `getMyPrizes` notified only `idMasthead`, so a winner opening the prize push
  stayed on "no prizes". New `idPrizes`; the push open reloads when the cached
  list lacks the id; a failed refresh no longer erases vouchers.
- Tests: `test/unit/spots_draw_wiring_test.dart` (13) and
  `test/widget/spots_claw_entry_test.dart` (7).

Still owed from §11.6: items 1–6 (curl the live endpoint, the backfill, a
device run, the `9` prizes, exercising CLAW-Z3's push, the golden).
