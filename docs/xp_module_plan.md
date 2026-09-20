# XP module — audit and fix plan

**Date:** 2026-09-16 · **Scope:** `waddi_user`, the XP / levelling module end to
end — levels home, challenges, prizes, leaderboard, the level-up celebration,
the checkout prize path
**Status:** `X-01` and `X-02` landed 2026-09-16 (Phases 0–2). `X-03`–`X-12`
open; `X-05`/`X-04` are next.

Findings are `X-01`…`X-12`, referenceable from commits the way `S-*` is used in
`spots_module_plan.md`, `F-*` in `food_module_plan.md`, `G-*` in
`grocery_module_plan.md`, `M-*` in `module_architecture_plan.md` and `CC-*` in
`cart_checkout_fix_plan.md`.

The surface: `xp_levels_screen.dart` (2,034 lines),
`level_claim_celebration_widget.dart` (665), `xp_leaderboard_screen.dart` (630),
`xp_challenges_screen.dart` (582), `xp_leaderboard_preview_widget.dart` (559),
`xp_controller.dart` (551), `level_up_screen.dart` (469), plus the widget set
and a 10-model domain layer. **8,879 lines total.**

---

## Summary

XP is the module with the widest blast radius in the app: **28
`GetBuilder<XpController>` sites across 19 files**, reaching into checkout,
home, profile, menu and orders. It is also the only gamified surface that
touches money — the checkout free-delivery prize changes what the customer pays.

That combination is what makes its two structural problems matter more here than
the same problems did in Spots:

1. **No rebuild scoping at all** (`X-01`) — 18 bare `update()`, zero ids, and
   all 28 builders unscoped. Where Spots had the machinery and bypassed it
   (`S-04`), XP never built it. A challenge-tab tap rebuilds the checkout
   screen's XP block.
2. **A stale-cache bug on the money path** (`X-02`) — `checkoutPrizesFetched`
   latches true forever, so amount-eligible prizes are fetched once and never
   refreshed when the cart changes.

Then the two patterns this codebase keeps producing, both confirmed by the
analyzer:

3. **Finished features with no way in** (`X-03`, `X-04`) — 1,860 lines of
   widgets built by nothing, which also strands the 630-line leaderboard screen
   and wastes a request per home open. Exactly `S-01`/`S-02`'s shape.
4. **A comment describing a control, and an empty slot where it should be**
   (`X-05`) — the level-up screen's reward chip, commented out, while the
   screen's own doc still claims it renders. The same tell as `S-01` and `S-13`.

And a localization gap (`X-06`, `X-07`) that Spots does not have: user-facing
English hardcoded on a **reachable** screen, including a hand-rolled weekday
array sitting one file away from the correct `DateFormat.EEEE(locale)` call.

**Verified clean, and worth recording so nobody re-audits it:**

- **Translation keys.** All 86 `.tr` keys used by the module are present in
  **both** `en.json` and `ar.json`. The localization problem here is not missing
  keys — it is strings that never got a key at all (`X-06`).
- **`_XpSourcesSection`.** Builds "ways to earn" purely from live server config
  with an explicit "no hardcoded XP values" rule, skips zero-valued sources, and
  drops the whole section rather than inventing numbers. It is the best-behaved
  thing in the module.
- **`hasUnclaimedRewards`.** The nav badge is tied to an actual claimable
  action, with a documented rationale for why a permanently-lit dot is worse
  than none.

---

## Part 1 — Findings

### X-01 · The controller has no rebuild scoping, and 29 builders pay for it

```
bare   update()        → 18
scoped update([...])   → 0
GetBuilder<XpController> with an id → 0 of 28
```

`XpController` declares no `idX` constants at all. Every one of its 18
`update()` calls rebuilds **every** subscribed builder in the app, and those
builders are not confined to the XP tab:

| file | what rebuilds |
|---|---|
| `checkout_screen.dart`, `bottom_section.dart`, `prize_selection_widget.dart` | the checkout prize block |
| `dashboard_screen.dart` | the dashboard's XP surface |
| `home_app_bar_widget.dart`, `xp_progress_widget.dart` | the home XP chip |
| `profile_screen.dart`, `menu_screen.dart`, `order_screen.dart` | XP progress surfaces |
| `xp_levels_screen.dart` | **the whole 2,034-line screen**, via one unscoped builder at its root |

So `changeChallengeTab(0→1)` — a local tab tap — rebuilds the levels screen and
the checkout prize selector. The levels screen's root builder wraps
its entire content tree, so there is no smaller unit to repaint.

Compare `S-04`: Spots defined seven ids and then bypassed them in two thirds of
its call sites, which was bad. XP never defined any.

A secondary oddity, seven times over:

```dart
_isChallengesLoading = true;
Future.microtask(() => update());     // ×7 across the fetchers
```

Deferring the loading-flag notify by a microtask is a workaround for calling
`update()` during a build — which happens because `bottom_section.dart:98`
kicks a fetch off *from inside a builder*. The microtask hides the symptom; the
fetch-from-build is the cause (see `X-02`).

**Fix:** the `S-04` treatment, one step earlier. Declare ids —
`idLevel`, `idChallenges`, `idPrizes`, `idLeaderboard`, `idHistory`,
`idCheckoutPrizes` — scope the 18, and give the levels screen's sections their
own builders instead of one root builder over 2,034 lines. Tab and filter
changes (`changeChallengeTab`, `changePrizeFilter`) are the cheapest wins: both
are pure local UI state that currently repaint checkout.

---

### X-02 · Checkout prizes are fetched once and never refreshed when the cart changes

The flag is a one-way latch:

```dart
// xp_controller.dart
bool _checkoutPrizesFetched = false;
…
_checkoutPrizes = await xpServiceInterface.getCheckoutPrizes(orderAmount);
_checkoutPrizesFetched = true;        // never set back to false anywhere
```

and the fetch is gated on it, from inside a builder:

```dart
// bottom_section.dart:95
if (!xpController.checkoutPrizesFetched &&
    !xpController.isCheckoutPrizesLoading &&
    orderAmount > 0) {
  Future.microtask(() => xpController.getCheckoutPrizes(orderAmount));
}
```

But eligibility **depends on the amount**. The request is
`xp/checkout-prizes?order_amount=$orderAmount`, and `CheckoutPrize` carries
`min_order_amount`. So:

- A user opens checkout at EGP 120 and the free-delivery prize needing EGP 150
  is correctly absent. They add an item, reaching EGP 180 — **the prize is never
  fetched, and they never learn they qualified.**
- The reverse is worse. They qualify at EGP 180, select the prize, then remove
  an item down to EGP 120. `getCheckoutPrizes` has a guard that clears a
  selection when it is no longer in the returned list — but it only runs *inside
  a fetch that no longer happens*. The stale selection stands, and
  `checkout_calculation_helper.dart:473` reads
  `selectedCheckoutPrize!.isFreeDelivery` straight into the total.

That last path is a client/server disagreement about the price of an order,
which is the most expensive class of bug in this app.

**Fix:** key the cache on the amount it was fetched for, not on a boolean —
refetch when `orderAmount` changes materially, and re-validate the selection on
every fetch. Move the trigger out of the builder while doing it (it is what the
seven `Future.microtask(update)` calls in `X-01` exist to tolerate).

---

### X-03 · 1,860 lines of widgets built by nothing — which also strands a whole screen

| widget | lines | built by |
|---|---|---|
| `LevelClaimCelebrationWidget` | 665 | **nothing** |
| `XpLeaderboardPreviewWidget` | 559 | **nothing** |
| `XpHistoryWidget` | 281 | **nothing** |
| `XpShoppingCounterWidget` | 228 | **nothing** |
| `HappyHourChipWidget` | 127 | **nothing** |

Two consequences beyond the dead lines:

**The leaderboard screen is unreachable.** `xp_leaderboard_screen.dart` (630
lines) is registered at `route_helper.dart:1291`, and the *only* navigation to
it in the entire app is `xp_leaderboard_preview_widget.dart:32` — inside a
widget nothing builds. `getXpLeaderboardRoute()` has zero callers. This is
`S-01`'s exact shape: a finished screen behind a door nobody installed.

**A request per home open is wasted.** `_initXpData` calls `getHistory()` on
every levels-screen open, and `historyModel`'s only renderer is
`XpHistoryWidget` — dead. Nothing else in `lib/` reads it.

**The leaderboard fetch, by contrast, is justified** and should not be removed
with the screen: `leaderboardModel.currentUser.rank` is read by the level-up
celebration (`level_up_screen.dart:37`) and the levels screen
(`xp_levels_screen.dart:2001`). The screen is dead; the data is not. Worth
stating explicitly, because the tempting cleanup here is wrong.

**Fix:** a decision per widget, the `G-04` way. The leaderboard preview is the
interesting one — wiring it into the levels screen would light up 630 lines of
finished screen for a few lines of code, which is the `S-01` trade and it paid
off there. `getHistory()` should stop being called until something renders it.

---

### X-04 · Three dead declarations in `level_up_screen.dart`

Confirmed by the analyzer (`unused_element`, `unused_local_variable`):

| declaration | line | note |
|---|---|---|
| `_RewardUnlockedChip` | 169 | see `X-05` — this one is a regression, not dead weight |
| `_fmt` | 145 | a thousands-separator formatter; `intl`'s `NumberFormat` does this, localized |
| `streak` local | 67 | `_streakDays()` is called and the result dropped |

`_streakDays()` reads `XpController.streak?.currentStreak` and the value is
discarded — so the level-up screen computes the user's streak and shows nothing
about it. Two section-header comment blocks (`MEDAL`, `TIER NAME + LEVEL`) sit
over nothing at all, which is where the deleted widgets used to be.

---

### X-05 · The level-up celebration never says what you won

The reward chip is commented out at the call site:

```dart
// level_up_screen.dart:93
// if (event.rewardName != null) ...[
//   _FadeUp(
//     delayMs: 650,
//     child: _RewardUnlockedChip(rewardName: event.rewardName!),
//   ),
//   const SizedBox(height: Dimensions.paddingSizeDefault),
// ],
```

while the screen's own doc comment, nine lines from the top of the file, still
promises it:

> …chips, momentum stats, and **the reward unlocked this level**.

The data is fully plumbed: the backend sends `reward_name`, `reward_type` and
`rarity` under `pending_level_ups`; `LevelUpEvent.fromJson` parses all three;
`_RewardUnlockedChip` is written and styled and has a translated label
(`level_up_your_reward`). The Rive artboard does not show it either — it binds
level, current XP and next-level XP only.

So a user who levels up **into a prize** gets a celebration that never names the
prize.

The give-away that this is a regression rather than a decision: the debug
simulator (`xp_levels_screen.dart:1993`) synthesises
`rewardName: 'Free delivery for a week'` specifically to preview this — and
cannot, because the thing it feeds is commented out.

**Fix:** uncomment, and give the chip back its border/shadow (the `Container`
has a stray blank `decoration` slot where one was removed). One caveat worth
handling: `rewardName` arrives from the server unlocalized, which is `X-06`'s
problem in a different place.

---

### X-06 · User-facing English hardcoded on a reachable screen

`xp_challenges_screen.dart` is reachable (`xp_levels_screen.dart:1080`) and
renders untranslated English:

| line | string |
|---|---|
| 95 | `'Daily quests'` |
| 102 | `'Weekly quests'` |
| 216 | `'Play at your pace — new quests roll in daily and weekly'` |
| 570 | `'All done for now'` |
| 126 | `'soon'` |
| 132–133 | `'${d}d ${hh}h'` — unit suffixes |

The tell that this is an oversight rather than a choice: line 98, immediately
below `'Daily quests'`, is `'check_back_tomorrow'.tr`. Localization was intended
and these were missed.

Spots solved the identical unit problem with `spots_unit_d` / `_h` / `_m`, which
already exist in both language files and could be reused directly.

`xp_leaderboard_screen.dart` has the same issue (`_resetNote`'s three strings,
`'Earn XP to claim your spot on the board.'`) — lower priority only because the
screen is unreachable (`X-03`).

**Fix:** keys for all of it, in both `en.json` and `ar.json`
(`translation-keys-workflow`).

---

### X-07 · A hardcoded English weekday array, one file from the correct solution

```dart
// xp_challenges_screen.dart:138
const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday',
              'Friday', 'Saturday', 'Sunday'];
return days[(resetTime.weekday - 1).clamp(0, 6)];
```

The app already knows how to do this, in the same module:

```dart
// xp_levels_screen.dart:1117
// read "resets Monday". `DateFormat.EEEE` resolves them per locale.
DateFormat.EEEE(Get.locale?.toString()).format(t);
```

Two answers to one question, in one module, with the correct one carrying a
comment explaining itself. An Arabic user sees "Monday".

**Fix:** delete the array, call `DateFormat.EEEE(Get.locale?.toString())`.

---

### X-08 · `getRewardName` / `getRewardIcon` exist twice, and neither is localized

Byte-identical implementations in two places:

- `XpController.getRewardName` / `getRewardIcon` (`xp_controller.dart:535`, `:517`)
- `AppDesignTokens.getRewardName` / `getRewardIcon`
  (`app_design_tokens.dart:155+`)

Both return hardcoded English: `'Free Delivery'`, `'Wallet Credit'`,
`'Free Item'`, `'Badge'`, `'Discount'`, `'Reward'`.

The live consumer makes it visible:

```dart
// live_cart_widget.dart:242
'${'next'.tr} Prize: $rewardTitle'
```

A translated word, the hardcoded English word "Prize", and a hardcoded English
reward name — concatenated. In Arabic that renders as
**"التالي Prize: Free Delivery"**.

**Scope correction (2026-09-16).** This is reachable, but on fewer surfaces than
the audit assumed. `LiveCartWidget` is built only by `store_screen.dart:310` —
the grocery/general store screen. Food stores (`food_store_screen.dart:446`) and
the dashboard (`dashboard_screen.dart:886`) use `PillCartBar`, which builds on
`CartController` alone and shows no XP line at all. `dashboard_screen.dart` still
imports `LiveCartWidget` but no longer builds it.

`LiveCartWidget` also reads the controller through `Get.find` inside `build`
(lines 77, 232) rather than a `GetBuilder`, so it is **not** one of `X-01`'s
builders and never rebuilds on `update()`.

Of the six reward types, only `free_delivery` and `discount` have keys in the
language files at all; `wallet_credit`, `badge`, `free_item` and `reward` have
none, so this needs new keys, not just `.tr` calls.

**Fix:** one localized helper, one home (the controller or the tokens file, not
both), four new key pairs, and the `live_cart_widget` line rebuilt as a single
parameterised string rather than concatenation — RTL will not lay that
concatenation out correctly even once the words are translated.

---

### X-09 · The levels screen is a `Column` in a `SingleChildScrollView`

```dart
// xp_levels_screen.dart:142
child: SingleChildScrollView(
  child: Column(children: [
    const _Masthead(),
    Padding(child: Column(children: [
      _FoilHeroCard(xp: xp), const _OrderCta(),
      const _WhatsNextSection(),      // challenge tiles
      const _XpSourcesSection(),
      const _RewardsSection(),        // reward rows
      …
    ])),
  ]),
)
```

The `G-03` / `S-05` twin. Every section — including the rewards list and the
challenge tiles — is built and laid out on the first frame and on every rebuild,
and per `X-01` "every rebuild" means all 18 `update()` calls plus any tab tap.

Milder than the Spots details screen (no embedded map, no long paginated list),
which is why it ranks below `X-01`: fixing the scoping removes most of the cost
without touching the layout.

**Fix:** `CustomScrollView` with the fixed blocks as `SliverToBoxAdapter`s, once
`X-01` has landed and it is clear what still rebuilds.

---

### X-10 · `clearXpData` is defined and never called

`XpController.clearXpData()` nulls every field and is documented "on logout".
Nothing calls it. So XP level, challenges, prizes, history, streak, leaderboard
and **the selected checkout prize** all survive a logout in memory.

Worth checking against the auth flow before acting: if the controller is
disposed and re-created on logout, this is dead code to delete; if it is a
`GetxService` that persists (it is declared `implements GetxService`), the next
user to sign in on the same device inherits the previous user's XP state until
each fetch replaces it.

**Fix:** determine which, then either call it from the logout path or delete it.
Not a guess to make from the audit.

---

### X-11 · 25 analyzer issues, 14 of them one deprecation

`flutter analyze lib/features/xp` reports 25: three `unused_*` (`X-04`), and 14
`withOpacity` deprecations across `xp_progress_bar.dart`, `prize_card_widget.dart`,
`xp_prizes_screen.dart`, `xp_item_indicator_widget.dart` and
`xp_shopping_counter_widget.dart`, plus const/interpolation hints.

The rest of the app has already moved to `.withValues()`. Mechanical, and it is
the cheap way to get this module to the zero that Spots now holds — which makes
the count a usable progress signal for the real work.

---

### X-12 · Nothing tests the XP module

`test/` references `XpController` only inside `di_graph_test.dart`, which checks
it can be constructed.

Untested, and each is pure or near-pure:

- `calculateEstimatedXp` / `calculateEstimatedXpForItems` — the second exists
  specifically to match the backend's per-item floor "so the cart/checkout
  promise doesn't overshoot". An off-by-one here is a promise broken to the
  customer, and it is a pure function over a config object.
- `nextReward` / `nextRewardLevel` / `xpToNextReward` — three getters walking
  the same loop with three different return values; `xpToNextReward` has a
  `clamp` and a fallback branch.
- `filteredPrizes` / `currentChallenges` — filter switches.
- `hasUnclaimedRewards` — drives the nav badge.
- The `X-02` staleness, once fixed, is exactly a three-line controller test.

---

## Part 2 — Phased plan

### Phase 0 — Safety net ✅ landed 2026-09-16

`test/unit/xp_module_test.dart`:

- `calculateEstimatedXpForItems` matches a per-item floor against a known config
- `xpToNextReward` on a levels list with a claimed prize, an unclaimed one, and
  none at all
- `hasUnclaimedRewards` false before the fetches land, true on a claimable
  challenge, true on a claimable prize
- checkout prizes refetch when the order amount changes (**fails today** —
  `X-02`)

**Landed** as `test/unit/xp_module_test.dart` — 29 tests. Written against the
target API (`syncCheckoutPrizes`), so the `X-02` group failed to compile before
Phase 1 rather than failing an assertion; Phase 1 followed immediately.

### Phase 1 — The money path (`X-02`) ✅ landed 2026-09-16

The only finding with a wrong-price consequence. Key the cache on the amount,
re-validate the selection on each fetch, move the trigger out of the builder.

**Landed.** `_checkoutPrizesFetched` (bool) became `_checkoutPrizesFetchedFor`
(double?), keyed on the amount with a 0.01 epsilon. New `syncCheckoutPrizes`
is what the UI calls: it skips a zero amount, skips an amount already fetched,
and de-dupes a request already in flight. Selection re-validation was already
inside `getCheckoutPrizes` and now actually runs, because a cart change causes
a fetch.

The trigger moved out of the builder: `bottom_section.dart`'s inline
`GetBuilder` + `Future.microtask` is now `_CheckoutPrizeSection`, a small
`StatefulWidget` syncing from `initState`/`didUpdateWidget`. That removed the
reason all seven `Future.microtask(() => update())` calls existed, and they are
gone.

**Still to verify on device:** checkout below a prize's threshold, add items to
cross it — the prize appears; select it, remove items to fall below — the
selection clears and the total corrects.

### Phase 2 — Rebuild scope (`X-01`) ✅ landed 2026-09-16

Ids on the controller, the 18 scoped, the levels screen's root builder split
into per-section builders. The widest-reaching change in the module and the one
everything else gets cheaper after.

**Landed.** Eight ids on the controller — `idLevel`, `idChallenges`,
`idPrizes`, `idLeaderboard`, `idHistory`, `idCheckoutPrizes`, `idConfig`,
`idBadge`. All 18 `update()` calls are scoped; the one remaining bare `update()`
is `clearXpData`, which nulls everything and should wake everything.

Every surviving builder carries an id (26 of them). Two were deleted outright
rather than scoped, because they read nothing off the controller and only
subscribed 49 and ~60 lines of unrelated tree to every XP update:

- `menu_screen.dart:848` — the quick-actions grid
- `profile_screen.dart:480` — the XP card, whose only live part is
  `XpProgressBar`, which subscribes on its own

`checkout_screen.dart:300` looks like a third but is not: it reads nothing
directly, yet `_calcHelper.calculatePrice` resolves `selectedCheckoutPrize`
through `Get.find`, so the total is only correct while that tree repaints on a
selection change. Scoped to `idCheckoutPrizes` with a comment saying so.

Pinned by six tests in the `X-01 · update() is scoped` group.

**Still to verify on device:** switch the challenges tab — checkout's prize
block does not rebuild.

### Phase 3 — Say what was won (`X-05`), and the dead declarations (`X-04`)

Uncomment the reward chip, restore its decoration, delete `_fmt` and the dropped
`streak` local (or render it — the celebration has room for a streak stat and
the data is already fetched).

**Verify:** debug simulate button shows "Your reward: Free delivery for a week".

### Phase 4 — Localization (`X-06`, `X-07`, `X-08`)

Keys for the challenges screen, `DateFormat.EEEE` for the weekday, one localized
reward-name helper with four new key pairs, and the `live_cart_widget` string
rebuilt as a parameterised whole.

**Verify:** switch to Arabic, open Challenges and the cart bar — no English.

### Phase 5 — Decide on the dead weight (`X-03`), and `X-10`

Per widget. The leaderboard preview is the one worth *wiring* rather than
deleting — it unlocks a finished 630-line screen. Stop calling `getHistory()`
until something renders it. Resolve `clearXpData` against the actual logout
path.

### Phase 6 — Render scope (`X-09`) and the deprecations (`X-11`)

Slivers once the scoping is in, and `withValues()` across the module to take the
analyzer to zero.

---

## Out of scope

- **`LevelUpScreen`'s Rive artboard.** `level_up_rive_burst.dart` binds the
  artboard's own text to real numbers; extending it to carry the reward name is
  a Rive authoring question (`rive-localization-approach` in memory), not a Dart
  one. `X-05` puts the reward in Flutter text above it, which needs no `.riv`
  change.
- **The backend's XP award rules.** `calculateEstimatedXp` mirrors them; whether
  they are right is a product question.
- **`app_design_tokens.dart`'s other contents.** `X-08` touches only the two
  duplicated reward helpers.
- **Checkout's own structure.** `X-02` fixes the XP side of the prize path;
  `cart_checkout_fix_plan.md` owns the rest.

## Verification discipline

`flutter analyze` and `flutter test` after every phase — never a build; the user
tests on device (`no-builds-user-tests`). Exclude
`test/golden/marks_render_test.dart`; 161 tests pass without it at the time of
this audit. **Do not run `dart format`** on this repo's files — see the note in
`food_module_plan.md`.

The module currently reports **25 analyzer issues**; Spots is at 0 after its
pass. That count is the progress check.
