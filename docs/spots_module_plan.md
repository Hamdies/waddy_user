# Waddy Spots module — audit and fix plan

**Date:** 2026-09-16 · **Scope:** `waddi_user`, the Spots (places) module end to
end — home, details, voting, prizes, submissions, the controller
**Status:** `S-01`–`S-05`, `S-07`–`S-11` landed 2026-09-16, plus `S-13` (found
while fixing `S-02`). `S-06` is partly done — the dead declarations are deleted
and sort is wired; trending/tags/banners are still a deletion decision. `S-12`
open beyond the Phase 0 net that now exists.

The module went from **12 analyzer issues to 0**, and the test suite from 140 to
161 passing.

Findings are `S-01`…`S-13`, referenceable from commits the way `F-*` is used in
`food_module_plan.md`, `G-*` in `grocery_module_plan.md`, `M-*` in
`module_architecture_plan.md` and `CC-*` in `cart_checkout_fix_plan.md`.

The surface: `place_details_screen.dart` (1,657 lines), `places_controller.dart`
(1,342), `top_voters_podium_section.dart` (858), `spots_prize_details_screen.dart`
(668), `weekly_top3_section.dart` (656), `places_to_visit_section.dart` (544),
`spots_marks.dart` (526), `place_vote_sheet.dart` (512), `place_submission_screen.dart`
(492), `spots_prizes_screen.dart` (454), plus the home screen (152) and the
domain layer (~1,800 across models, repo, service). **12,693 lines total.**

---

## Summary

Spots is the newest module and the one with the most deliberate design thinking
in it — `SpotsRound` collapsed two contradictory deadlines into one instant,
`rankOf`/`isTiedAt` render ties as ties rather than asserting an order the votes
don't support, `RecentWinnersStrip` is kept visually distinct from the podium so
a random draw never reads as a ranking, and `places_init_test.dart` already pins
the partial-failure behaviour. The care is real and it is mostly in the right
places.

What it has instead is a **reach problem**. The module was built wide before it
was wired, and large parts of it are finished code with no way in:

1. **Whole features that cannot be reached at all** (`S-01`, `S-02`, `S-06`) —
   the zone filter, the submission flow, and four controller features with no UI
   at any layer. This is not stale-comment dead weight of the `G-05`/`G-08`
   kind; it is working, tested-looking code the user can never trigger.
2. **A threshold that exists twice** (`S-03`) — `SpotsStage.warmThreshold` and
   a literal `5` in `LiveNewsBar`, agreeing by coincidence on exactly the value
   the enum was written to centralise. (The enum's doc also argues for gating
   the home's composition on it; see `S-03` for why that part did not survive
   contact.)
3. **Rebuild and render scope** (`S-04`, `S-05`, `S-07`) — the twins of `F-07`,
   `G-03` and `M-03`, in a module that already built the `id` machinery to
   avoid them and then bypassed it in two thirds of its call sites.

The good news: none of `S-01`–`S-04` was large, and the analyzer independently
confirmed every dead-code finding in `S-06` and `S-13`.

**What the fixes actually bought**, beyond the findings as written:

- `_isVoting` turned out to have **no readers at all** (`S-04`), so the vote
  path's full-screen rebuilds were publishing a flag nothing renders.
- The reviews' "load more" spinner was **unreachable** (`S-05`) — it tested a
  first-page-only flag, so the button showed its label for the whole round trip.
- Every place card was computing a champion / top-3 / first-appearance badge
  and **discarding it** (`S-13`), into a slot that had been deliberately
  reserved for it.

All three were live defects sitting behind what looked like cosmetic analyzer
warnings.

**Verified clean, and worth recording so nobody re-audits them:**

- **Translations.** All 299 `.tr` keys used by the module (104 `spots_*` plus
  195 shared) are present in **both** `en.json` and `ar.json`. No raw-key
  renders. (`translation-keys-workflow` in memory.)
- **`SpotsRound.lockAt`.** The `8 - weekday` arithmetic is correct on every day
  of the week — Monday through Sunday all resolve to the same upcoming Monday
  00:00, never a week out. The three-hour label/timer disagreement recorded in
  the `spots-round-lock-time` memory **is fixed**; that memory is stale and
  should be updated to say so. What remains is the documented `TODO(backend)`:
  the lock instant is computed on-device, so a skewed phone clock still shows a
  deadline the server does not enforce.
- **Test baseline.** 140 tests pass; `test/golden/marks_render_test.dart` fails
  to load, the same known exclusion both sibling plans record.

---

## Part 1 — Findings

### S-01 · The zone filter is unreachable — and a third of the controller exists to serve it — **DONE**

> The trigger is wired, where its own comment said it belonged: a quiet mint
> sub-line under the wordmark (`_AreaTrigger`), padded to a ≥44px hit box,
> tapping through to `_openAreaSheet`. It shows the selected zone or "ALL
> AREAS", ellipsizes rather than pushing the prizes pill off-screen, and
> carries a `Semantics` label.
>
> Selecting a zone now also **closes the sheet** — it was a scope picker left
> open over a board refetching behind it, which hid the only feedback the
> choice produces. `setSelectedZone` is not awaited there: it fans out to four
> refetches and the sheet should not linger for them.
>
> That lights up the five stranded mechanisms — the zone refetch, the FCM topic
> swap, the per-zone rank snapshots, `AreaFilterTabs`, and
> `WeeklyTop3Section`'s zone kicker, which could previously never render its
> left branch. Done together with `S-10`, as the plan required.

`SpotsMasthead` builds the teal panel, computes the selected zone name, and
defines the sheet that would let a user change it:

```dart
// spots_masthead.dart:22
final zoneName = controller.selectedZoneName;   // ← assigned, never read

// spots_masthead.dart:93
void _openAreaSheet(BuildContext context) { … AreaFilterTabs() … }
```

`_openAreaSheet` has **zero call sites**, and `zoneName` is never used. The
comment that should mark the trigger is still in the widget tree, describing a
control that is not there:

```dart
// Area filter trigger — reads as a quiet sub-line, but the
// hit box is padded up to a ≥44px touch target.
```

— followed immediately by the closing bracket of an empty `Column`. The
analyzer confirms both (`unused_element`, `unused_local_variable`).

Because nothing can call `setSelectedZone`, `_selectedZoneId` is permanently
null, and everything downstream of it is inert:

| stranded by S-01 | what it does when reachable |
|---|---|
| `AreaFilterTabs` (129 lines) | the chips themselves — built only by the dead sheet |
| `setSelectedZone` | refetches board + voters + places + winner, per zone |
| `_updateZoneRaceTopic` | FCM subscribe/unsubscribe per zone |
| `_standingsSnapshotKey`'s `_${zoneId}` suffix | per-zone ▲/▼ movement snapshots |
| `selectedZoneName` | the masthead sub-line and `WeeklyTop3Section`'s kicker |
| every fetcher's `zoneId:` parameter | zone scoping across five endpoints |

`WeeklyTop3Section` renders `zone ?? 'spots_this_week'.tr` as its kicker — the
left branch is currently unreachable, so the section always says "THIS WEEK" and
never names an area.

**Fix:** wire the trigger. The sub-line belongs where its own comment says it
does, inside the masthead's `Column` under the wordmark, tapping through to
`_openAreaSheet`. That is a handful of lines and it lights up six stranded
mechanisms at once. The alternative — deleting all of it — is a much larger
deletion than it looks, and throws away the only geographic scoping the module
has.

---

### S-02 · "Submit a hidden gem" is registered, built, and unreachable — **DONE**

> `SubmitSpotCta` — one quiet full-width button — in the two places the plan
> named: inside the venue list's empty state (where a user has just failed to
> find what they wanted, the strongest possible moment to ask) and at the end
> of the rail. On the rail it appears only once there is nothing left to load,
> so it cannot strand itself mid-list once pagination (`S-09`) kicks in.
>
> Deliberately quiet: it is an offer, not the screen's main action — the vote
> CTA above keeps that role.
>
> Still open from this finding: `getMySubmissions` has no consumer, so a
> submission cannot be checked on after it is made.

`PlaceSubmissionScreen` is 492 lines: a full form with image upload, category
picker, validation, and a `submitNewPlace` round trip. Its route is registered:

```dart
// route_helper.dart:173, 514, 1310
static const String placeSubmit = '/places/submit';
static String getPlaceSubmitRoute() => placeSubmit;
GetPage(name: placeSubmit, page: () => getRoute(const PlaceSubmissionScreen()));
```

`grep -rn 'getPlaceSubmitRoute' lib/` outside `route_helper.dart` returns
**nothing**. No screen, sheet, empty state or menu entry navigates there.
`getMySubmissions` likewise has no UI consumer, so a submission that *was* made
could not be checked on afterwards.

This is the user-generated-content half of the module — the thing that makes a
"hidden gems" board self-sustaining — complete and switched off.

**Fix is partly a product decision** (where does the entry point live?), but the
defensible default is the places list's empty state and the end of the
places-to-visit rail: "know somewhere we're missing?". Both already exist as
widgets and neither currently offers an action.

---

### S-03 · `SpotsStage` exists to gate the home's composition, and the home ignores it — **DONE**

> **Resolved as a threshold unification, not as section gating — the first
> attempt at this overreached and was reverted.**
>
> `LiveNewsBar`'s literal `totalVotes < 5` is gone; it reads `c.stage.isCold`.
> The two copies of the threshold are one again, which was the enum's actual
> purpose: the ticker and the hero can no longer reach opposite conclusions
> about one board.
>
> The first pass also hid the voters podium and the winners strip below
> `stage.isHot`, reading the enum's doc comment as a mandate to gate the home's
> composition. **That was wrong on the merits and the user reverted it.** Two
> reasons it does not hold up:
>
> - `roundHeat` sums the **venues'** votes, and the podium ranks **people**. A
>   voters board is perfectly real in a week where no single spot has pulled
>   ahead, so gating one on the other is a category error.
> - `roundHeat` sums `liveStandings`, which is capped at five entries. Forty
>   spots on two votes each — a busy week — totals ~10 and reads as "warm". The
>   measure tracks concentration at the top, not activity.
>
> Every section renders unconditionally again. That is not a regression to the
> original state: `WeeklyTop3Section` has its "the crown is open" state and
> `_VotersEmpty` has its own, and saying so in place is the honest way to
> handle a quiet round — removing the section just makes the screen look like
> the feature is missing.
>
> **The lesson worth keeping:** `SpotsStage`'s doc comment argues for gating
> composition but never says *which* sections belong at which stage. That
> mapping was mine, not the enum's, and it should have been asked rather than
> assumed.

`spots_stage.dart` is 49 lines of enum plus a long doc comment that states the
problem precisely:

> the Spots home used to be a fixed five-section template rendered over a
> variable dataset … an "EARLY LEAD" sticker over a 1-vote tie, three hundred
> pixels above a ticker admitting "VOTING IS WARMING UP" … buried the venue
> list, the only thing a cold round can actually offer, below about 1900px of
> theatre about a race nobody had run yet.
>
> **One derived value now drives the composition instead. Sections are unlocked
> as the round earns them.**

They are not. The entire consumer set of `stage` across the module is:

```dart
// weekly_top3_section.dart:48 — the only line that reads it
final lowData = !controller.stage.isHot;
```

One boolean, used to swap copy inside a structure that never changes — which is
verbatim what the doc says it *replaced* (`_kWarmupVotes`). `isCold`, `isWarm`
and `hasBoard` have no callers. `places_home_screen.dart` renders
`RoundCountdownBar`, `WeeklyTop3Section`, `TopVotersPodiumSection`,
`RecentWinnersStrip` and `PlacesToVisitSection` unconditionally, at full height,
on a two-vote board exactly as on a two-hundred-vote one.

Worse, `LiveNewsBar` re-derives the threshold rather than asking:

```dart
// live_news_bar.dart:62
final totalVotes = standings.fold<int>(0, (sum, p) => sum + p.votesCount);
final warmingUp = totalVotes < 5;          // ← literal
// spots_stage.dart:38
static const int warmThreshold = 5;        // ← the constant it should read
```

Two copies of one threshold that agree today by coincidence. This is `M-03`'s
shape — two stores of one fact, no owner — on the exact value the enum was
written to centralise. The ticker and the hero can still reach opposite
conclusions the moment either number is tuned.

**Fix:** make `places_home_screen.dart` read `stage` and order sections by it —
cold: countdown, invitation, places list; warm: add the board; hot: the full
stadium. Point `LiveNewsBar` at `controller.stage` and delete its literal. This
is the finding that changes what a cold round actually looks like, and the
machinery for it is already written and paid for.

---

### S-04 · Two thirds of the controller bypasses its own rebuild scoping — **DONE**

> **The finding held, and the cause was worse than described.** `_isVoting` —
> the flag four of the vote path's `update()` calls existed to publish — has
> **no readers anywhere in the app**. `grep -rn 'isVoting' lib/` outside the
> controller returns nothing. So `submitVote`, `removeVote`, `submitReview` and
> `removeReview` each repainted six sections, twice, to record a boolean
> nothing renders.
>
> Those notifies are gone rather than scoped: there is no section to scope them
> to. The vote's feedback is the confetti and the undo snackbar the caller
> shows, plus the refetched board. The trailing `update()` after the three
> `notify: false` refetches is now `refreshRankDeltas()` + `update([idPlaces])`
> — so the `notify: false` the author wrote finally pays, instead of being
> undone one line later.
>
> The rest, scoped to what actually changed: `setSelectedCategory` →
> `[idFilters]`, `setSelectedZone` → `[idMasthead, idFilters]`, `setSortBy` →
> `[idFilters]` (plus an early return when the value is unchanged),
> `getFavorites` → `[idDetails]`, `markPrizeCelebrated` and `getMyPrizes`'
> entry → `[idMasthead]`, `clearPlacesData` → `idAllHome`.
>
> `getLatestWinner` and `getRecentWinners` were the illustration in the
> original finding — scoped on exit, bare on entry, where the entry rebuild is
> the one that paints the skeleton. Both are scoped both ways now.
>
> The bare `update()`s that remain are all in methods with no UI consumer
> (`S-06`), plus `submitNewPlace` — which is correct: the submission screen
> uses an unscoped `GetBuilder` and `_isSubmitting` is genuinely read there.

The controller opens with a careful comment about exactly this:

> `update()` with no argument rebuilds every GetBuilder watching this
> controller — on the Spots home that is six sections, including the podium, on
> every one of the seven init responses. These ids let each fetch repaint only
> the section it actually changed.

Seven ids are defined. Then:

```
bare   update()  → 41 call sites
scoped update([…]) → 19 call sites
```

The init path and the primary fetchers are scoped correctly — that work is
real and it holds. What is not scoped is **everything a user does**:

| path | current | should be |
|---|---|---|
| `setSelectedCategory` | `update()` | `[idFilters, idPlaces]` |
| `setSelectedZone` | `update()` | `[idMasthead, idFilters]` + its awaited refetches |
| `submitVote` / `removeVote` | 4 × `update()` each | `[idDetails]`, then the refetch ids |
| `getFavorites` | `update()` | `[idDetails]` |
| `getTrending` / `getTags` / `getFeaturedBanners` | `update()` ×2 each | — (see `S-06`) |
| `getLatestWinner` | `update()` in, `[idWinners, idMasthead]` out | scoped both ways |
| `getWinnersHistory` | `update()` ×2 | — (see `S-06`) |
| `markPrizeCelebrated` | `update()` | `[idMasthead]` |
| `clearPlacesData` | `update()` | `idAllHome` |

`getLatestWinner` is the clearest illustration: it sets its loading flag with a
**bare** `update()` and clears it with a **scoped** one. The entry rebuild is
the expensive one — it repaints the podium, the board, the places list and the
masthead to show a spinner on the winners strip — and it is the unscoped half.

**The cost is concentrated on the vote**, the module's core act. One tap on the
home's vote CTA runs:

```
getVoteStatus          → update([idDetails])
submitVote             → update()              ← full screen
  getPlaceDetails      → update([idDetails]) ×2
  getVoteStatus        → update([idDetails])
  getLeaderboard ┐
  getTopVoters   ├ notify:false (correct)
  getPlaces      ┘
  refreshRankDeltas    → update([idLeaderboard, idTopVoters])
                       → update()              ← full screen again
```

Two full-screen rebuilds — each one podium, board, ticker, winners strip and
the whole places list — around an action whose visible result is a number
changing on one card. The `notify: false` on the three refetches shows the
author was thinking about exactly this; the bare `update()`s on either side
undo it.

**Fix:** scope the 41. Mechanical, low-risk, and it is the change that makes the
existing id system actually pay.

---

### S-05 · The details screen is a `Column` in a `SingleChildScrollView` (`G-03`'s twin, one level down) — **DONE**

> `CustomScrollView`. The fixed sections above stay eager in one
> `SliverToBoxAdapter` — they are above the fold, and a hero that builds lazily
> is a hero that flashes — and the reviews became `_reviewsSliver`: a
> `SliverList.separated` for the cards, with the composer button and the
> load-more footer as their own small adapters around it.
>
> The reviews also got their own id. `idReviews` is split out of `idDetails`,
> and `getPlaceReviews` notifies only that, so appending a page can no longer
> repaint the cover photo or re-inflate the `GoogleMap`. `submitReview` /
> `removeReview` still refresh both surfaces, because they also call
> `getPlaceDetails`.
>
> **One live bug fell out of this.** The load-more button's spinner branch
> tested `isReviewsLoading`, which by construction covers the first page only —
> exactly what the controller's own comment warns about — so it was
> unreachable and the button showed its label for the whole round trip. It now
> reads `isLoadingMoreReviews` and disables itself while in flight.

```dart
// place_details_screen.dart:151
child: SingleChildScrollView(
  child: Column(
    children: [
      _hero(context, c, place),       // 290px cover + scrim + nav + map
      _statsOrPitch(place),
      if (place.description…) _section(…),
      _photosSection(context, place), // horizontal ListView.separated
      _findThemSection(place),        // GoogleMap + links
      _section(title: 'what_locals_say'.tr, child: _reviewsBlock(c, place.id)),
    ],
  ),
)
```

Everything below the fold — gallery, map, every review card — is built and laid
out on the first frame and on every rebuild, exactly the defect `G-03` fixed on
the grocery store screen and the perf programme fixed on the module homes.

`_reviewsBlock` compounds it with an eager `for` loop over the full review list,
and reviews are **paginated** — so each "load more" tap rebuilds every review
already on screen plus the hero, the gallery and the `GoogleMap` above them.

And the whole screen is one `GetBuilder(id: idDetails)`, while
`getPlaceReviews` fires `update([idDetails])` on entry *and* exit. Loading page
two of the reviews repaints the cover photo and re-inflates the map twice.

**Fix:** `CustomScrollView`; fixed sections as `SliverToBoxAdapter`s, the review
list as a `SliverList.builder`. Then split the single `GetBuilder` — the
reviews block wants its own id (`idReviews`) so a page append cannot reach the
hero. Same move as `G-03`, same shape, one screen over.

---

### S-06 · Four controller features, four layers deep, with no UI at any level — **PARTLY DONE**

> **Sort is wired, the dead declarations are deleted, the rest is still a
> decision.**
>
> `setSortBy` was the sharpest gap and it is closed: `_SortRow` gives the venue
> list "MOST VOTED / TOP RATED / NEWEST". The whole path was already built and
> correct end to end — the client sends `sort=` as `&sort_by=`, and the backend
> (`PlaceController.php:71`) matches `votes`, `rating`, `featured`, `distance`,
> `newest` — so this was purely a missing control. On a screen whose premise is
> a weekly vote race, "most voted" had been the one order you could not ask
> for. Three options, not five: `featured` duplicates the board above, and
> `distance` needs a location the Spots home does not collect.
>
> Deleted, both tracked so both a `git restore` away: `_DefendMission` (138
> lines, plus its commented-out call site) and `_RedemptionSteps` (~76 lines —
> checked first that the prize *details* screen, the one a winner actually
> holds up at the counter, already covers redemption). Two remnant fragments
> went with them: an empty `Row(children: [])` in the countdown bar and the
> now-unused imports that served both.
>
> **Still open, and still a decision:** `getTrending`, `getTags` /
> `toggleTag` / `clearTagFilters`, `getFeaturedBanners` /
> `setCurrentBannerIndex`, `getWinnersHistory`, `searchPlaces`,
> `getMySubmissions`. Each runs model → repository → service → controller with
> no UI at any layer, and `app_constants` carries `placesTrendingUri` and
> `placesBannersUri` for endpoints nothing calls. Deleting them reaches four
> layers deep, so it wants a product call on whether any is planned rather than
> an audit's judgment.

Eleven public controller methods have **zero** UI call sites:

| method | reachable from UI |
|---|---|
| `getTrending` | no |
| `getTags` / `toggleTag` / `clearTagFilters` | no |
| `getFeaturedBanners` / `setCurrentBannerIndex` | no |
| `getWinnersHistory` | no |
| `setSortBy` | no |
| `searchPlaces` | no |
| `getMySubmissions` | no (see `S-02`) |
| `clearPlacesData` | no |

These are not stubs. Each runs the full stack — `PlaceTag` / `PlaceBanner`
models, `placesRepository.getTags()` / `getTrending()` / `getFeaturedBanners()`
/ `getWinners()`, the service parse layer with its own error handling, the
interface declaration, the controller state and loading flags. `app_constants`
carries `placesTrendingUri` and `placesBannersUri` for endpoints nothing calls.

The sort and search cases are the interesting ones: `getPlaces` accepts `sort`
and `search`, threads them into the query, and `_sortBy` defaults to `'rating'`
— so **the places list is permanently rating-sorted** with no way for a user to
change it, on a screen whose entire premise is a weekly vote race. Sorting by
votes is not offered.

Three dead private declarations sit alongside, all confirmed by the analyzer:

| declaration | lines |
|---|---|
| `_DefendMission` (`top_voters_podium_section.dart:411`) | 138 |
| `_RedemptionSteps` (`spots_prizes_screen.dart:233`) | ~76 |
| `_openAreaSheet` + `zoneName` (`spots_masthead.dart`) | see `S-01` |

`_DefendMission` is the notable one: its call site is still there, commented
out, three lines above `_PrizeFairnessNote`. Someone switched off the
"defend your crown" mission strip and left both halves in place.

**Fix is a decision per feature, taken the way `G-04` took it.** Search and
sort are worth *wiring* (`S-02`'s judgment — finished code, missing entry
point). Trending, tags and banners are worth *deleting* down through the
service layer unless there is a design for them. `_DefendMission` and
`_RedemptionSteps` are straight deletions — both files are tracked, so a
`git restore` brings them back.

---

### S-07 · `LiveNewsBar` reads the controller without subscribing to it — **DONE**

> Wrapped in `GetBuilder(id: idLeaderboard)` — it renders standings, so it
> subscribes to standings. The animation controllers stay outside the builder,
> so a data rebuild cannot restart the marquee or the pulse mid-sweep.

```dart
// live_news_bar.dart:108
final c = Get.find<PlacesController>();
final lines = _lines(c);          // reads liveStandings, rankDeltaFor, isNewOnBoard
```

No `GetBuilder`, no `Obx`. It renders live standings, ▲/▼ movement and
new-entry state, and it repaints only when its parent happens to — which is
`TopVotersPodiumSection`'s `GetBuilder(id: idTopVoters)`. So the ticker updates
when the **voters** list changes and not when the **standings** do.

`refreshRankDeltas` — whose entire job is recomputing the movement this widget
displays — fires `update([idLeaderboard, idTopVoters])`. The `idTopVoters` half
is what saves it today, by accident: the ticker is correct because it happens to
live inside the other section that id rebuilds. Move it, or drop `idTopVoters`
from that call, and the ticker silently freezes with stale arrows.

**Fix:** give it its own `GetBuilder(id: idLeaderboard)` — it is standings data,
and it should say so.

---

### S-08 · `liveStandings` sorts on every read, and the hero reads it five times — **DONE**

> Memoised, keyed on the **identity** of `_placeList` and `_leaderboardList`
> rather than invalidated at each assignment site. There are five places that
> write those fields, and a memo depending on someone remembering all five is
> a memo that goes stale when a sixth is added.
>
> The result is `List.unmodifiable`: with a shared memo behind it, a caller
> sorting or trimming the returned list in place would corrupt every later
> read. A test pins that.

```dart
List<Place> get liveStandings {
  final source = (leaderboard != null && leaderboard!.isNotEmpty)
      ? leaderboard!
      : (places ?? []).where((p) => p.votesCount > 0).toList();
  final list = List<Place>.from(source);
  list.sort(…);                     // full sort, every call
  return list.take(5).toList();
}
```

It is a getter, so every read copies, filters, sorts and takes. `rankOf` and
`isTiedAt` each call it again internally, and `roundHeat` — and therefore
`stage` — calls it once more.

`WeeklyTop3Section.build` alone:

| line | call | sorts |
|---|---|---|
| 36 | `liveStandings` | 1 |
| 48 | `stage` → `roundHeat` → `liveStandings` | 1 |
| 65 | `isTiedAt(leader.id)` | 1 |
| 84 | `rankOf(runners[i].id)` ×2 | 2 |
| 85 | `isTiedAt(runners[i].id)` ×2 | 2 |

**Seven sorts per build of one section**, plus one in `LiveNewsBar` and two more
in the podium's empty state. On a 5-element list this is not a frame killer —
and it should be said plainly that it is not currently a user-visible problem.
It matters because `S-04` means this build runs on every bare `update()`, and
because the shape invites the mistake: nothing about `controller.liveStandings`
looks like work.

**Fix:** memoise on the inputs that can change it (`_leaderboardList`,
`_placeList`), invalidated where those are assigned. Cheap, and it makes
`rankOf`/`isTiedAt`/`stage` free at the point of use.

---

### S-09 · The places list is unpaginated on the home, and the backend is — **DONE**

> **Fixed by making the claim true rather than by shrinking it.** The header
> renders the catalogue count, and the list can now reach it: `_maybeLoadMore`
> hangs off the home's existing `_scrollController` (which already had a
> listener for the nav-bar hide/show) with 300px of lead time, matching the
> store screens.
>
> The controller gained what the reviews path already had: `_placesPage` from
> the server's own `offset` rather than a derived page number, `hasMorePlaces`,
> an `isLoadingMorePlaces` flag distinct from the first-page one, an in-flight
> guard (the scroll trigger fires every frame inside the zone, so one flick
> would otherwise queue several identical requests), and **de-duplication by
> id** on merge — a spot removed between two fetches shifts the window and
> makes the next page repeat a row.
>
> Changing the sort resets pagination, so page two of the new order cannot
> append onto page one of the old. Four tests pin all of it.

`getPlaces` takes an `offset`, merges pages, and tracks `totalSize`. The home
renders:

```dart
// places_to_visit_section.dart
final places = controller.places ?? [];
…
for (final p in places)
  Padding(… child: RepaintBoundary(child: _PlaceCard(place: p))),
```

No scroll listener, no "load more", no `offset` ever above 1 — `grep` finds
exactly two `getPlaces` callers outside the controller, both passing `reload`
only. So the home shows page one forever, while the section header confidently
renders `totalPlaces` — the **server's** count:

```dart
final count = controller.totalPlaces ?? controller.places?.length ?? 0;
…
stat: trPlural('spots_count_spots', count),
```

The header says "48 SPOTS" over a list of 10. That is `F-01`'s defect — a
headline that is not true of the data beneath it — in a milder form: the number
is honest about the catalogue and dishonest about the list.

It is also an eager `for` loop in a `Column` (`S-05`'s twin), which is why
nobody has noticed: the list is short *because* it is unpaginated.

**Fix:** paginate on the home's existing `_scrollController` — it already has a
listener for the nav-bar hide/show, so the hook is there — and convert the loop
to a `SliverList.builder` in the same pass. Until then, the header should count
what is on screen, not what the server holds.

---

### S-10 · `AreaFilterTabs` has no failure state (`G-06`'s twin) — **DONE**

> Three states, not two. `getZones` could not tell a failed request from a
> genuinely empty list — both leave `_zones` null — so the controller gained a
> `_zonesLoaded` flag and a `zonesFailed` getter, the same distinction
> `CuisineController` draws. Only a non-null response marks it loaded, so a
> cache miss cannot mark the network attempt as having succeeded.
>
> The sheet now shows an inline "couldn't load areas" row with a Retry on
> failure, and still renders nothing when the answer is genuinely empty.

```dart
if (controller.isZonesLoading) return _buildSkeleton(context);
final zones = controller.zones;
if (zones == null || zones.isEmpty) return const SizedBox.shrink();
```

`getZones` clears `_isZonesLoading` on both success and failure and leaves
`_zones` null on failure — so a failed fetch renders **nothing at all**, with no
error, no retry, and no explanation. Identical to `ModuleBestNearbySection`
before `G-06`, except that this one collapses silently rather than shimmering
forever, which is harder to notice and easier to misread as "there are no
zones".

Latent today only because `S-01` means nobody can open the sheet.

**Fix:** the `G-06` pattern — distinguish "in flight" from "failed" from
"genuinely empty", with a retry on the middle one. Do it when `S-01` lands, not
before; there is no point giving a retry button to a sheet nobody can open.

---

### S-11 · A prize win is fetched on home and can only be celebrated on the prizes screen — **DONE**

> The home awaits `getMyPrizes` and then offers the card, reusing the prizes
> screen's exact pattern. `markPrizeCelebrated` is the persisted once-per-prize
> gate, so whichever surface gets there first is the only one that offers it —
> it cannot double-congratulate.

`_loadData` on the home fetches prizes, and says why:

```dart
// Drives the masthead's prize badge — a won voucher has to be findable
// even when the push was swiped away.
controller.getMyPrizes();
```

The badge works — `_PrizeButton(hasLivePrize: controller.featuredPrize != null)`
lights a mint dot. But the celebration, `SpotsWinCardSheet`, fires only from
`spots_prizes_screen.dart:61`, gated on `uncelebratedPrize`.

So a user who wins while the app is closed opens Spots, sees a small mint dot on
a pill, and gets the confetti card only if they independently decide to tap
through to a prizes screen. The `_celebratedPrizeIds` persistence — built
specifically so nobody is congratulated twice — is doing its job in a place most
winners will not reach.

Given the module already spends a request on `getMyPrizes` at home load
precisely so the win is "findable", showing the card at the point the data
arrives is the smaller change.

**Fix:** present `SpotsWinCardSheet` from the home when `uncelebratedPrize` is
non-null after the prize fetch resolves. The once-per-prize gate already
guarantees it cannot nag.

---

### S-13 · The place card's status badge is computed and thrown away — **DONE**

**Found while fixing `S-02`, not in the original audit.** `_PlaceCard.build`
called `_badge(place)` on every card and never rendered the result — the
analyzer flagged it as `unused_local_variable` and it read as a trivial
cleanup, but `_badge` is a real classifier:

| condition | badge |
|---|---|
| `isCurrentChampion` | CURRENT CHAMPION (teal/mint, trophy) |
| `votesCount > 0 && rank <= 3` | TOP 3 (red/white, flame) |
| `votesCount == 0 && titlesCount == 0` | FIRST APPEARANCE (mint/teal, bolt) |

`_Badge` was a data class nothing constructed a widget from. So every spot on
the home was classified, styled and discarded.

The give-away was three lines above it, the same shape as `S-01` — a comment
describing a control, and an empty slot where it should be:

> Reserved slot: the badge is optional per spot, but without a fixed-height row
> the title of a badge-less card rides up and the list loses its shared
> baseline (see Dunkin vs Starbucks).

…followed by a bare `SizedBox(height: Spots.s8)`. The slot was reserved, the
data was computed, and the widget between them had been removed.

> **Resolved.** `_BadgeChip` renders it in the reserved slot at a fixed 18px, so
> the shared baseline the comment protects is kept whether or not a spot has a
> badge. Flat and small — it sits above the spot's own name inside a card that
> already has a border and a hard shadow, and a third stacked frame in an 80px
> row would be noise. `_Badge`'s unused `markWidget` parameter is gone.

---

### S-12 · Coverage stops at the init path — **PARTLY DONE**

> Phase 0 landed as `test/unit/spots_module_test.dart` — 21 tests covering the
> stage boundaries and the `isHot` gate the home composes from, `lockAt` across
> all seven weekdays, the tie semantics (`rankOf` / `isTiedAt` / unvoted spots
> off the board), the standings memo and its immutability, the three zone-fetch
> states, and the four pagination properties.
>
> Still open: the vote round trip — that a 409 routes to the switch dialog, and
> that the `notify: false` refetches do not fire extra rebuilds.

`test/unit/places_init_test.dart` covers four cases, and covers them well —
partial failure, total failure, cache-hit-before-network, cold-cache. That is
the hardest part of the controller and it is pinned.

Nothing covers what the rest of this plan is about:

- `rankOf` / `isTiedAt` — the tie semantics the module's credibility rests on,
  and pure functions over a list, which is the cheapest possible test
- `SpotsStage.fromHeat` boundaries (4/5 → cold/warm, 24/25 → warm/hot), which
  would have caught `S-03`'s duplicated literal the moment either moved
- `SpotsRound.lockAt` across all seven weekdays — verified by hand during this
  audit, unpinned in the repo
- the vote round trip: that a 409 routes to the switch dialog, and that
  `notify: false` refetches do not fire extra rebuilds (`S-04`)

`SpotsStage` and `SpotsRound` are both pure, dependency-free and already
extracted into `domain/` — they are three-line tests each.

---

## Part 2 — Phased plan

### Phase 0 — Safety net — **DONE**

`test/unit/spots_module_test.dart`, 21 tests. The `S-09` case failed on the
first run exactly as intended (`totalPlaces` 48 over a 2-row list) and now
passes against real pagination.

### Phase 1 — Give the module its missing entry points (`S-01`, `S-02`, `S-10`) — **DONE**

The two findings that changed what users can actually do, with `S-10` folded in
so a failed zone fetch has somewhere to go.

**Verify on device:** tap the area line under the wordmark → chips open →
picking one closes the sheet, refetches the board, and renames the top-3
kicker to the zone; the submit form opens from the list's empty state and the
end of the rail.

### Phase 2 — Compose the home from the stage it already computes (`S-03`) — **DONE**

**Verify on device:** on a cold board the top-3 hero reads "the crown is open"
and the ticker leads with an invitation rather than one-vote counts — with the
podium, winners strip and venue list all still present.

### Phase 3 — Rebuild scope (`S-04`, `S-07`, `S-08`) — **DONE**

**Verify on device:** vote from the home card — the board and the ticker update,
and the venue list below does not flash.

### Phase 4 — Render scope (`S-05`, `S-09`) — **DONE**

**Verify on device:** the details screen scrolls to the bottom with every
section in order; "load more reviews" shows a spinner and appends without the
cover photo or the map flashing; the venue list appends near the bottom and
reaches the count in its header.

### Phase 5 — Decide on the dead weight (`S-06`) — **PARTLY DONE**

Sort wired, `_DefendMission` and `_RedemptionSteps` deleted. Trending, tags,
banners, winners-history, search and submissions-list remain — see `S-06`.

### Phase 6 — Celebrate the win where the data lands (`S-11`) — **DONE**

**Verify on device:** with a live unredeemed voucher, opening Spots offers the
win card once, and never again.

---

## What is left

1. `S-06`'s remaining six features — delete or wire, a product call.
2. `S-12`'s vote round trip tests.
3. The backend lock instant (out of scope below).
4. `getMySubmissions` — `S-02` opened the submission door; nothing yet shows
   what happened to a submission afterwards.

## Out of scope

- **The backend lock instant.** `SpotsRound`'s `TODO(backend)` — the round's
  close time should arrive with the standings payload rather than being computed
  on-device. That is a contract change the user owns, in the same family as
  `get-stores-filter-contract`.
- **`place_vote_sheet.dart` and `spots_marks.dart`.** The sheet is shared with
  the review flow and the marks are the module's icon system; both behave
  correctly and belong to a design pass, not this one.
- **The prize/voucher redemption flow.** `spots_prize_details_screen.dart` (668
  lines) is its own surface with its own backend contract; `S-11` touches only
  when the win card is *shown*, not what it does.
- **`PlacesHomeScreen` being constructed in two places** (`dashboard_screen.dart`
  and `home_screen.dart:809`). Both are live entry paths and the duplication is
  the dashboard's, not Spots' — it belongs to `module_architecture_plan.md`.

## Verification discipline

`flutter analyze` and `flutter test` after every phase — never a build; the user
tests on device (`no-builds-user-tests`). Exclude
`test/golden/marks_render_test.dart`; **140 tests pass without it** at the time
of this audit. **Do not run `dart format`** on this repo's files — see the note
in `food_module_plan.md`.

The module reported 12 analyzer issues when this audit was written, 5 of them
the `unused_element` / `unused_local_variable` warnings that independently
confirmed `S-01`, `S-06` and `S-13`. **It now reports 0**, and the suite is at
161 passing (from 140), with `test/golden/marks_render_test.dart` still the one
known exclusion.
