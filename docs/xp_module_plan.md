# XP module — audit and fix plan

**Written:** 2026-09-16 (Part 1–2) · **Deep dive:** 2026-09-27 (Part 3–4) ·
**Second pass + motion plan:** 2026-10-04 (Part 5–6) ·
**Scope:** `waddi_user` + the XP half of `waddy_back`: levels home,
challenges, prizes, leaderboard, the level-up celebration, the checkout prize
path.

**Read the status table and the verify list below; they are the current
state.** The Parts underneath are the evidence, kept as they were written. When
a later pass found an earlier claim wrong, the correction is flagged in place,
not quietly edited.

**Phases:** 0–2 are numbered and done. The rest of the original plan (Phases
3–6) is dead. Everything that was live is lettered A–E in Part 4, and **A–E
landed 2026-09-27** (backend pending deploy). Open: the leaderboard screen
decision (`X-03`) and on-device verification.

**2026-10-04:** a second pass over the landed code found `X-31`…`X-45` (Part
5), and Part 6 plans the animated-icon pass (`XM-00`…`XM-07`). New phases are
lettered **F** (logic fixes) → **G** (structure, which unblocks motion) → **H**
(motion). **Phases F, G and H landed 2026-10-04** (X-32 backend needs deploy; X-41 deferred; X-47 needs a product decision). To swap any animation, edit `XpIcon` / `XpMotion` in `widgets/xp_motion.dart`. X-47 needs a product decision.

Other modules' plans and their ID prefixes: [`plans_index.md`](plans_index.md).

## Status

Severity: **Money** = client and server disagree about what the customer pays
or gets · **Broken** = a feature doesn't do what it shows · **Stale** = correct
data that stops updating · **Honesty** = the UI asserts something untrue ·
**Perf** · **Waste** = work with no consumer · **Polish** · **Cleanup**.

| ID | Finding | Severity | Status | Phase |
|---|---|---|---|---|
| X-01 | No rebuild scoping; 28 builders woke on every update | Perf | ✅ landed 09-16 | 2 |
| X-02 | Checkout prizes fetched once, never refetched on cart change | Money | ✅ landed 09-16 | 1 |
| X-03 | Widgets built by nothing; leaderboard screen unreachable; history fetched for nothing | Waste | ◐ all 5 widgets + `XpPreviewWidget` deleted; history no longer fetched (09-27). **Leaderboard screen: wire or delete — decision** | E |
| X-04 | Dead declarations in `level_up_screen.dart` | Cleanup | ✅ 09-27 (plus dead `_Pop` / confetti) | D |
| X-05 | Level-up celebration never names the reward | Broken | ✅ 09-27 — names the level and the reward | D |
| X-06 | Hardcoded English on the challenges screen (superseded by X-28) | Honesty | ✅ 09-27 via X-28; leaderboard screen's English waits on X-03 | D |
| X-07 | English weekday array | Honesty | ✅ 09-27 | D |
| X-08 | `getRewardName` duplicated and unlocalized ("التالي Prize: Free Delivery") | Honesty | ✅ 09-27 | D |
| X-09 | Levels screen is a `Column` in a scroll view | Perf | ✅ 09-27 — slivers | E |
| X-10 | `clearXpData` never called on logout | Stale | ✅ 09-27 — from `AuthController.clearSharedData` | B |
| X-11 | Analyzer issues (count is the progress signal) | Cleanup | ✅ **0** (09-27) | E |
| X-12 | No tests | — | ◐ 43 tests (`xp_module_test`, `xp_deep_dive_test`); grows per phase | all |
| X-13 | A failed fetch wedges its spinner; a null model renders as "empty" | Broken | ✅ 09-27 — `try/finally`, keep-on-failure, error states, tolerant parsing (`xp_json.dart`) | A |
| X-14 | Every level prize parsed as "badge" (`prize_type` vs `type`) | Broken | ✅ landed 09-27 | A |
| X-15 | A used free-delivery prize stays selected for the next same-amount order | Money | ✅ 09-27 — `afterOrderPlaced` | A |
| X-16 | Level 0 → 500 on `xp/level-details` (backend) | Broken | ✅ 09-27 — **deploy** | A |
| X-17 | A broken streak still shows as alive (backend) | Honesty | ✅ 09-27 — backend `effectiveStreak` (**deploy**) + client guard | C |
| X-18 | Expired challenges served as active for up to an hour (backend) | Honesty | ✅ 09-27 — backend (**deploy**) + client `isExpired` | C |
| X-19 | XP home pull-to-refresh is a no-op; tab never revalidates | Stale | ✅ 09-27 — `revalidate()` | B |
| X-20 | Nothing refreshes XP after orders or claims | Stale | ✅ 09-27 — `refreshAfter(XpEvent)`; delivered-order push triggers it | B |
| X-21 | `level_up` / `challenge_complete` pushes go nowhere | Broken | ✅ 09-27 — tap, background and cold start | B |
| X-22 | XP tab waits on a leaderboard it never shows | Waste | ✅ 09-27 | B |
| X-23 | Three different XP estimates for one basket | Honesty | ✅ 09-27 — `estimateForCart` everywhere; order list shows server `xp_earned` (**deploy**); reorder no longer toasts "earned"; "rate to earn" shows the review award | C |
| X-24 | Checkout offers prizes the server refuses (backend + client) | Money | ✅ 09-27 — shared `canRedeemFreeDelivery` (**deploy**); client sends pre-coupon amount | A |
| X-25 | Discount/free-item prizes unspendable | Broken | ✅ 09-27 — fixed-amount coupons (**deploy**) | — |
| X-26 | Claiming free delivery is a no-op but keeps the badge lit | Honesty | ✅ 09-27 — free delivery has no claim step; badge counts only prizes where claiming does something. Reversible | E |
| X-27 | Prizes screen: off-brand, fake stats, no use-it path | Broken | ✅ 09-27 — rebuilt on XP tokens, grouped by action, use-it CTAs | D |
| X-28 | Challenges screen mostly unlocalized | Honesty | ✅ 09-27 — 26 new keys, en + ar | D |
| X-29 | Reset countdowns never render (server sends none of the keys) | Broken | ✅ 09-27 — from each challenge's `expires_at` | C |
| X-30 | Claiming a quest ends in a snackbar | Polish | ✅ 09-27 — card stays claimed, XP flies up, level-up plays on the spot | D |
| X-31 | Home Rewards list ignores prize `status`: expired reads "Ready", a claimed-but-unspent coupon reads "Used" | Honesty | ✅ 10-04 — `RewardState` (`reward_state.dart`) shared by home rows, Rewards grouping and the hero; badges no longer light the nav dot | F |
| X-32 | `/prizes` drops period-limited and time-expired-not-yet-flipped prizes from all three groups, so they vanish (backend) | Honesty | ✅ 10-04 — exhaustive groups + `waiting_prizes` (**deploy**); see X-47 | F |
| X-33 | A failed claim shows two toasts, and the second (generic) one hides the server's reason | Polish | ✅ 10-04 — claim posts use `handleError: false` | F |
| X-34 | Level-up can replay: any level fetch between `takePendingLevelUps` and the ack re-queues the same events | Broken | ✅ 10-04 — `_celebratedIds` filters re-queued events | F |
| X-35 | Hero "N rewards ready" lives under `idLevel` but reads prizes, so it is stale whenever prizes land after the level | Stale | ✅ 10-04 — nested `idPrizes` / `idLevel` builders | F |
| X-36 | "What's next" shows an active quest before a claimable one, hiding the one tile that pays out now | Polish | ✅ 10-04 | F |
| X-37 | One payload, two "current level"s: `LevelsListModel` recomputes a level from thresholds that can disagree with the server's | Honesty | ✅ 10-04 — server `current_level` only; no threshold recompute (it had no reader, so this was latent) | G |
| X-38 | Prize-type knowledge is spread across 3 files and ~8 string compares (icon in a screen, name in the controller, value in another screen) | Cleanup | ✅ 10-04 — `PrizeKind` (`prize_kind.dart`) + `PrizeVisual` (`widgets/prize_visual.dart`); checkout's prize icon uses it too; `getRewardName` / `iconForPrizeType` deleted | G |
| X-39 | `_conditionsLine` duplicated between XP home and Rewards, with different expiry caps | Cleanup | ✅ 10-04 — `prizeConditionsLine(maxDays:)` | G |
| X-40 | XP history (repo, service, model, controller state) has zero consumers | Waste | ✅ 10-04 — history deleted (model, repo, service, controller, `xpHistoryUri`) + the dead prize filter (`filteredPrizes`, `changePrizeFilter`, 3 model getters) | G |
| X-41 | `XpController` (850 lines) carries the checkout money path for 20 outside files next to tab UI state | Cleanup | deferred — optional; do it when checkout is next touched | G |
| X-42 | `xp_levels_screen.dart` is 2,211 lines | Cleanup | ✅ 10-04 — `screens/xp_home/` part files (hero, whats_next, earn_and_rewards, primitives, states); screen file 255 lines | G |
| X-43 | Streak drawn three ways: Rive flame (home), static 🔥 (Quests), text row | Polish | ✅ 10-04 via XM-05 | H |
| X-44 | Claim feedback waits on a full refetch before the snackbar shows | Polish | ✅ 10-04 | F |
| X-45 | No in-flight dedupe: tab visit + claim + push all fire `getLevelDetails`, and an older response can land last | Stale | ✅ 10-04 — `_single`: join, or queue one follow-up for `fresh` callers; logout drops in-flight | F |
| X-46 | `clearXpData` called a bare `update()`; every XP builder is id-scoped, so logout repainted none of them | Stale | ✅ 10-04 — updates every id | F |
| X-47 | `recordUsage` marks a period-limited prize `used` once the first period's limit is hit, so "N per week" behaves as "N in total" (backend) | Money | open — **product decision**: should weekly prizes recur until `expires_at`? | — |
| XM-00 | Preview sheet for `interactive_icon_set.riv`: palette on the foil, whether Idle loops, what `Boolean 1` drives | — | dropped 10-04 — the user swaps files by name; no preview step | H |
| XM-01 | `XpRiveIcon`: one shared `.riv` load, play-once API, reduced-motion → static, Material fallback | — | ✅ 10-04 — `widgets/xp_motion.dart`: `XpMotion` + `XpIcon` (the one asset table), `XpRiveIcon` (shared loader per file, hold-and-release `Boolean 1`, glyph fallback), `XpLottieOnce` | H |
| XM-02 | `PrizeKind` → icon + artboard + label in one place (rides on X-38) | — | ✅ 10-04 — `XpIcon.forPrize` / `forChallengeType` | H |
| XM-03 | XP home: hero badge, ways to earn, ready rewards, next reward, just-earned, sign-in | — | ✅ 10-04 — crown badge (plays on level change), ways-to-earn icons, live reward rows, gift on next reward, coin burst on just-earned, rewards Lottie when signed out | H |
| XM-04 | Rewards screen: live cards, claim success, empty state | — | ✅ 10-04 — live cards animate (keyed by prize, so a claim plays the change), coin burst on a successful claim, gift empty state | H |
| XM-05 | Quests screen: streak card, quest icon by `challenge_type`, claimable chip | — | ✅ 10-04 — streak flame (alive only), quest icon by type (emoji fallback), plays on status change | H |
| XM-06 | Motion budget enforced: one loop on screen, play-once elsewhere, no motion on locked/used/errors | — | ✅ 10-04 — in the widgets' use: locked/used/expired/errors static; reduced motion → glyph | H |
| XM-07 | Asset cleanup: duplicate `level_up_*.riv` and `crown`/`crown_w` | Cleanup | ✅ 10-04 — 3 unreferenced level-up `.riv` moved out (~3.4 MB); `crown_w.riv` differs from `crown.riv`, kept | H |

## Verify on device

Append as phases land; tick when checked on a real device. Never verified by a
build (`no-builds-user-tests`).

- [ ] **X-02** Checkout below a prize's threshold, add items to cross it: the prize appears. Select it, remove items to fall below: the selection clears and the total corrects.
- [ ] **X-01** Switch the challenges tab: checkout's prize block does not rebuild.
- [ ] **Challenges `[]` crash (09-27)** A user with no active challenges opens Challenges and claims the last one: no crash, no stuck spinner.
- [ ] **X-14** XP home Rewards rows show a delivery van / wallet / tag per type, not a medal on every row.
- [ ] **X-25 — deploy first:** `php artisan migrate`; then `SELECT prize_type, COUNT(*) FROM level_prizes GROUP BY prize_type` and fix any `free_item` or percent `discount` rows in the admin.
- [ ] **X-25** Claim a discount prize: the snackbar names the code; the card shows it with Copy; it appears in Coupons in more than one module; it applies at checkout; after the order the prize reads "Used" and the code is refused.
- [ ] **Backend deploy (09-27 batch)** — `php artisan migrate`, then check the items below. Files: Api `XpController`, `OrderController`, `CouponController`; Admin `XpController` + `xp/levels/edit.blade.php`; `XpService`, `ChallengeService`; models `User`, `UserStreak`, `UserLevelPrize`; `CouponLogic` (`coupon.php`); `PlaceNewOrder`; `file-exports/coupon.blade.php`.
- [ ] **X-15** Order with a free-delivery prize, then reorder the same basket: checkout shows the delivery fee, not free delivery.
- [ ] **X-24** A Food-only free-delivery prize is not offered in Grocery checkout. With a coupon applied, a prize whose minimum you meet before the coupon is still offered.
- [ ] **X-13** Airplane mode, open Challenges / Rewards: "Couldn't load this" + Retry, not "All done" or an endless spinner.
- [ ] **X-19** Pull to refresh on the XP tab actually refetches (watch the API log).
- [ ] **X-20 / X-21** Foreground push for a delivered order refreshes XP; tapping a `level_up` push opens the XP tab and plays the celebration; `challenge_complete` opens Quests. Also from a killed app.
- [ ] **X-17** A user whose last order was 3+ days ago sees "No streak yet", not a burning count.
- [ ] **X-29** Quests show "Resets in 7 h 12 m" (daily) and a weekday (weekly).
- [ ] **X-30** Claim a quest: the card flips to "✓ Claimed", "+N XP" floats up, it stays until tomorrow; a claim that crosses a level plays the celebration immediately.
- [ ] **X-05** Level-up shows the level name and "Your reward: …" (debug simulate button).
- [ ] **X-23** Cart banner, live cart bar and success screen agree for the same basket; delivered orders show the XP actually earned; reorder shows no "coins earned" toast.
- [ ] **X-27** Rewards screen in Arabic: dark XP styling, groups (claim / use / badges / used / expired), free delivery shows "Order with free delivery".
- [ ] **X-09** XP tab scrolls and lays out as before (sections left-aligned, hero full width).
- [ ] **X-31** With one expired prize and one claimed discount: the XP home rows say "Expired" and "Ready to use", the same as the Rewards screen.
- [ ] **X-32 — deploy first:** a free delivery with a weekly limit, already used this week, still shows in Rewards (with when it's next usable), not nothing.
- [ ] **X-33** Claim an already-claimed prize (two phones): exactly one toast, naming the real reason.
- [ ] **X-34** Simulate a level-up, then pull to refresh while the dialog is open: after closing, it does not play again.
- [ ] **X-35** Cold-open the XP tab with a ready reward: the hero says "1 reward ready" without a second refresh.
- [ ] **XM-06** XP home, Rewards, Quests: only the streak flame moves at rest; with Reduce Motion on, nothing moves.
- [ ] **XM-03..05** Scroll the XP tab and the Rewards list fast on a mid-range Android: no jank (perf overlay), icons don't flash blank.
- [ ] **XM-03..05** Arabic / RTL: overhangs and icon slots mirror correctly.
- [ ] **XM-01** `interactive_icon_set.riv` artboards are 1000×1000 with a black fill in a headless render: if the rows show black squares on device, swap the file/artboards in `XpIcon`.
- [ ] **XM-04** Claim a wallet credit: coin burst over the list, the card moves to Used. Claim a discount: its icon plays as it moves to Ready to use.

---

Findings are `X-01`…`X-30`, referenceable from commits. The other prefixes
used in this doc (`S-*`, `F-*`, `G-*`, `M-*`, `CC-*`) are mapped in
[`plans_index.md`](plans_index.md).

The surface as of 2026-09-16 (7,659 lines by 2026-09-27, after the `X-03` deletions): `xp_levels_screen.dart` (2,034 lines),
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

### X-01 · The controller has no rebuild scoping, and 29 builders pay for it — Perf ✅

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

### X-02 · Checkout prizes are fetched once and never refreshed when the cart changes — Money ✅

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

### X-03 · 1,860 lines of widgets built by nothing — which also strands a whole screen — Waste

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

### X-04 · Three dead declarations in `level_up_screen.dart` — Cleanup

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

### X-05 · The level-up celebration never says what you won — Broken

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

### X-06 · User-facing English hardcoded on a reachable screen — Honesty

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

### X-07 · A hardcoded English weekday array, one file from the correct solution — Honesty

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

### X-08 · `getRewardName` / `getRewardIcon` exist twice, and neither is localized — Honesty

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

### X-09 · The levels screen is a `Column` in a `SingleChildScrollView` — Perf

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

### X-10 · `clearXpData` is defined and never called — Stale

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

### X-11 · 25 analyzer issues, 14 of them one deprecation — Cleanup

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

## Part 2 — Phased plan (Phases 0–2 done; 3–6 superseded by Part 4)

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

### Phase 3 — Say what was won (`X-05`), and the dead declarations (`X-04`) — superseded

Uncomment the reward chip, restore its decoration, delete `_fmt` and the dropped
`streak` local (or render it — the celebration has room for a streak stat and
the data is already fetched).

**Verify:** debug simulate button shows "Your reward: Free delivery for a week".

### Phase 4 — Localization (`X-06`, `X-07`, `X-08`) — superseded

Keys for the challenges screen, `DateFormat.EEEE` for the weekday, one localized
reward-name helper with four new key pairs, and the `live_cart_widget` string
rebuilt as a parameterised whole.

**Verify:** switch to Arabic, open Challenges and the cart bar — no English.

### Phase 5 — Decide on the dead weight (`X-03`), and `X-10` — superseded

Per widget. The leaderboard preview is the one worth *wiring* rather than
deleting — it unlocks a finished 630-line screen. Stop calling `getHistory()`
until something renders it. Resolve `clearXpData` against the actual logout
path.

### Phase 6 — Render scope (`X-09`) and the deprecations (`X-11`) — superseded

Slivers once the scoping is in, and `withValues()` across the module to take the
analyzer to zero.

---

## Part 3 — Deep dive, 2026-09-27

Prompted by a production crash: `GET xp/challenges` for a user with no
challenges returns `"challenges": []` (an empty PHP array serializes as a list,
not `{}`), and `ChallengeModel.fromJson` indexed it with `['daily']`. Fixed the
same day at `challenge_model.dart:18-22`. Chasing that crash's class through the
whole module turned up far more than Part 1 recorded. Part 1 audited the
client's *structure*; this pass read the backend too and followed the data end
to end, which is where most of these live.

### Status of Part 1

| id | status 2026-09-27 |
|---|---|
| X-03 | Widgets built by nothing; leaderboard screen unreachable; history fetched for nothing | Waste | ◐ all 5 widgets + `XpPreviewWidget` deleted; history no longer fetched (09-27). **Leaderboard screen: wire or delete — decision** | E |
| X-04 / X-05 | open, unchanged. `level_up_screen.dart` now also has an unused `size` local and an unused import. |
| X-06 / X-07 | **worse than recorded.** `X-07` was fixed on the levels screen but the English weekday array is still in `xp_challenges_screen.dart:143`. See `X-28` for the full list. |
| X-08 | `getRewardName` duplicated and unlocalized ("التالي Prize: Free Delivery") | Honesty | ✅ 09-27 | D |
| X-09 | Levels screen is a `Column` in a scroll view | Perf | ✅ 09-27 — slivers | E |
| X-10 | `clearXpData` never called on logout | Stale | ✅ 09-27 — from `AuthController.clearSharedData` | B |
| X-11 | Analyzer issues (count is the progress signal) | Cleanup | ✅ **0** (09-27) | E |
| X-12 | No tests | — | ◐ 43 tests (`xp_module_test`, `xp_deep_dive_test`); grows per phase | all |

### Severity key

**Money** = a client/server disagreement about what the customer pays or gets.
**Broken** = a feature that does not do what it shows. **Stale** = correct data
that stops updating. **Honesty** = a number or state the UI asserts that is not
true.

---

### X-13 · A failed fetch wedges its spinner, and a null model renders as "empty" — Broken

Every fetcher has the same shape:

```dart
_isChallengesLoading = true;  update(...);
_challengeModel = await xpServiceInterface.getChallenges();   // may throw
_isChallengesLoading = false; update(...);
```

No `try`/`finally`. When parsing throws (today's crash), the flag stays `true`
for the rest of the session: the challenges screen shows a spinner forever, and
since `getChallenges` returns early on nothing but a cached model, nothing ever
recovers it. Applies to all seven fetchers.

The non-throwing failure is quieter and worse: a non-200 leaves the model
`null`, and the challenges screen renders `null` as two empty sections — "All
done for now" / "check back tomorrow", twice. An outage looks like finished
quests.

The parsing itself is `json['x'] ?? 0` straight into `int` fields throughout.
It holds today only because the backend casts every numeric column
(`LevelPrize` casts `value`/`min_order_amount` to float, `XpChallenge` casts
`xp_reward` to int). One uncast column or one more empty-array response and it
is today's crash again.

**Fix:** `try/finally` on every loading flag, with an error state distinct from
empty. Tolerant number parsing (`num`→int/double, numeric strings) in the
models. Treat any `[]` where a map is expected as empty, as the challenge model
now does.

### X-14 · Every level prize is a "badge" — the model reads a key the server never sends — Broken ✅

`LevelPrize.fromJson` reads `json['type'] ?? 'badge'`. `xp/level-details` sends
the field as **`prize_type`** (`XpController.php:240`). So every level prize in
the app has type `badge`:

- the Rewards section's "type-specific glyph per reward" (`iconForPrizeType`,
  written specifically so "a delivery van never looks like a discount tag")
  draws the same medal on every row
- the next-reward tile shows a medal for a free delivery
- `live_cart_widget.dart:242`'s fallback name reads "Badge"

`Prize.fromJson` (the `/prizes` model) already reads
`json['type'] ?? json['prize_type']`, which is why the prizes screen looks right
and hid this.

**Fix:** one line, the same fallback `Prize` uses.

### X-15 · A used free-delivery prize stays selected for the next order — Money

After an order is placed, nothing clears `selectedCheckoutPrize` and nothing
resets `_checkoutPrizesFetchedFor`. `X-02` made a refetch happen whenever the
*amount* changes. The same basket again — "order again", or the same usual
order — is the same amount, so no refetch happens and the spent prize stays
selected. The checkout quotes free delivery; the server finds the prize `used`,
ignores it, and charges delivery.

**Fix:** on order placed, clear the selection, null the amount key, and reload
prizes (`X-20`).

### X-16 · `xp/level-details` returns 500 for any user at level 0 — Broken (backend)

Level 1 needs 50 XP (`LevelsSeeder`). `calculateLevelFromXp` returns **0** below
that, and `reverseOrderXp` calls it. A refund that takes a user under 50 XP sets
`users.level = 0`. `User::getXpProgressAttribute` then does
`Level::where('level_number', 0)->first()` → null →
`$currentLevel->xp_required` → error. Both `xp/level-details` and `xp/level`
500, and the XP tab shows its error state for that user permanently.

The neighbouring case: a new user has `level = 1` (column default) with
`total_xp = 0` when the signup bonus is off. `xpInCurrentLevel = 0 − 50`, so
`progress_percentage` goes **negative**. It is capped with `min(100, …)` and
never floored.

**Fix (backend):** missing current level → `xp_required` 0; clamp progress to
0..100; decide what level 0 is called (the app falls back to "Newbie", the
backend to "Starter").

### X-17 · A broken streak still shows as alive — Honesty

`UserStreak.current_streak` is only reset by the *next* activity
(`recordActivity`). Nothing resets it at the day boundary. A user who last
ordered a week ago with a 5-day streak still gets `current_streak: 5`, and the
app draws a coral-burning flame and "5 days". The coral is the "don't break it"
urgency colour, shown for a streak that is already broken.

The client has `last_activity_date` parsed (`UserStreakModel.isActiveToday`) and
does not use it.

**Fix:** the backend returns the effective streak (0 unless the last activity
was today or yesterday, app-local). Keep a client guard on
`lastActivityDate` too.

### X-18 · Expired challenges are served as active for up to an hour — Honesty (backend)

`getAvailableDailyChallenge` returns the `status = 'active'` row without calling
`isExpired()`. Expiry is written only by the hourly `expireOldChallenges` cron
or by the next order's `checkProgress`. `Challenge.expiresAt` is parsed
client-side and read by nothing.

**Fix:** skip expired rows in `getAvailable*` (and assign a fresh one); the
client treats `expiresAt < now` as expired.

### X-19 · Pull-to-refresh on the XP home does nothing — Stale

`_initXpData` is the `onRefresh` handler, and it calls every fetcher **without**
`reload: true`. Each returns early on a cached model. The spinner spins and
nothing is requested.

The tab has the same problem at a larger scale. `XpLevelsScreen` sits in the
dashboard `PageView` without keep-alive, so it re-inits on every visit, but
every init is served from cache. Challenges and prizes are fetched **once per
app session**. Only level details refresh, and only because the home screen
reloads them.

**Fix:** `onRefresh` reloads. A tab visit revalidates in the background (show
the cache, fetch, swap), the pattern Places uses (`places-perf-cache-first`).

### X-20 · Nothing refreshes XP after the events that change it — Stale

| event | what changes | what the app refreshes |
|---|---|---|
| order delivered | XP, challenge progress, streak, prizes unlocked, maybe a level | level details on the next home load; **challenges and prizes never** |
| order placed with a prize | prize → `used` | **nothing** (`X-15`) |
| prize claimed | `/prizes` + the level payload's `is_claimed` | `/prizes` only, so the XP home's Rewards section still says "ready" |
| challenge claimed | XP, maybe a level-up | challenges + level, in series. The level-up it causes is queued but not shown until the XP tab is re-entered. |

**Fix:** one `XpController.refreshAfter(XpEvent)` that reloads the affected
payloads in parallel and drains pending level-ups when a route is available.
Call it from claims, order placement and the order-delivered status push.

### X-21 · The level-up and challenge-complete pushes go nowhere — Broken

The backend sends `type: 'level_up'` (`XpService::handleLevelUp`) and
`type: 'challenge_complete'` (`ChallengeService::notifyChallengeCompleted`,
documented as "the retention hook challenges exist for"). `NotificationType`
has neither. Tapping either one opens the app to wherever it was.

**Fix:** two enum values. `level_up` → XP tab (which drains the celebration),
`challenge_complete` → challenges screen.

### X-22 · The XP tab waits on a leaderboard it never shows — Waste

`_initXpData` **awaits** `getLeaderboard()` alongside `getLevelDetails()` before
it starts challenges and config. The comment says this is so the level-up
celebration can show the user's rank, but:

- `LevelUpScreen` takes `rank` and **never renders it**
- the hero dropped rank deliberately (`xp_levels_screen.dart:425`)

So first open is a serial waterfall behind a request with no consumer.
`getHistory()` is the same, minus the waiting (`X-03`).

**Fix:** drop both from `_initXpData`, fire the rest in parallel, and delete the
`rank` plumbing.

### X-23 · Four surfaces, three different XP numbers for one basket — Honesty

The server awards `xp_per_order + Σ floor(item price × qty × multiplier × rate)`,
plus a streak bonus. That is item prices only, **excluding delivery fee and tax**.

| surface | estimate |
|---|---|
| `live_cart_widget` | per-item ✓ matches |
| `cart_screen.dart:307` | aggregate over `subTotal` — reads a few XP high |
| `order_successful_screen.dart:391` | aggregate over `order_amount`, **which includes delivery and tax** — overstates |
| `order_view_widget.dart:620` | for *delivered* orders, the same estimate **labelled as earned** — the real number exists server-side in `xp_transactions` |

The model's own doc says to prefer the per-item method "wherever line items are
known". Two surfaces that know them don't use it.

**Fix:** per-item everywhere before the order. After delivery, show the server's
real figure (a `xp_earned` field on the order payload).

### X-24 · Checkout offers prizes the server will refuse — Money (backend + client)

`PlaceNewOrder.php:466` honours a free-delivery prize only when **all** of these
hold: `isUsable()` (period limits), `isApplicableToModule`, the minimum measured
on the subtotal *before* the coupon, and not expired. `xp/checkout-prizes`
checks two of them — expiry and the minimum. So:

- a prize restricted to Food is offered in Grocery checkout
- a prize over its period usage limit is offered

In both cases the client zeroes delivery in the total and the server charges
it. Per `order-amount-overwritten-backend` that is a wrong quote rather than a
wrong charge, but the customer sees a different total on the receipt.

The reverse also happens: the client passes an amount with the coupon already
subtracted, and the server compares before the coupon. A user with a coupon can
be told they don't qualify when they do.

**Fix (backend):** filter `checkout-prizes` with the same predicate
`PlaceNewOrder` uses, extracted into one method both call. Pass the module id
(the header is already there). Client: send the pre-coupon subtotal.

### X-25 · Discount and free-item prizes cannot be spent anywhere — Broken (product)

`PlaceNewOrder` redeems `free_delivery` only. `wallet_credit` pays out at claim.
`discount` and `free_item` can be unlocked, claimed, and displayed as "10% off"
on the prizes screen, and there is no place in the app or API to use them.
`xp/reward-items` exists server-side with no client caller.

**Decided 2026-09-27 — landed, backend needs deploy.** Prize types are badge,
free delivery, **fixed-amount discount**, wallet credit. No free item, no
percentages.

- **Claim mints a personal coupon** (`XpService::issueDiscountCoupon`, called
  inside the claim transaction): `customer_id = [user]`, `limit = 1`,
  `discount_type = amount`, `max_discount = discount`, `min_purchase` from the
  prize, expiry = the prize's `expires_at`, `created_by = admin` (platform
  funds it), code `WADDY-XXXXXX`. A prize with no amount rolls the claim back.
- **Module:** a prize limited to exactly one module binds the coupon to it;
  otherwise `module_id` is null. Migration `2026_09_27_000001` makes
  `coupons.module_id` nullable (keeping its type) and adds
  `user_level_prizes.coupon_id`. `CouponLogic::is_valide` / `is_valid_for_guest`
  and the customer `coupon/list` treat a null module as "any module". Admin
  coupon lists filter by the current module, so XP coupons never appear there.
- **Spending:** it goes through the ordinary coupon flow (coupons screen, cart
  and checkout promo card). `PlaceNewOrder` marks the linked prize `used` when
  its coupon is spent.
- **Admin:** the level prize dropdown offers "Discount (fixed amount)";
  `free_item` is gone from validation.
- **App:** the prize card shows the code with Copy and the amount as money;
  used prizes show "Used" instead of a disabled Claim button; the claim
  snackbar names the coupon. Keys `xp_coupon_added`, `xp_coupon_use_hint` in
  `en` + `ar`. `X-14` fixed in passing (it decides the discount glyph).

Not done: an "order now" CTA on the card (`X-27` rebuild), and pre-existing
discount/free-item prize rows in the DB, if any. Check before relying on this:
`SELECT prize_type, COUNT(*) FROM level_prizes GROUP BY prize_type`.

### X-26 · "Claim" is a ritual for most prizes, and it keeps the badge lit — Honesty (product)

Checkout accepts a free-delivery prize whether it is `unlocked` or `claimed`, so
claiming one changes nothing. Only `wallet_credit` does anything at claim. But
`hasUnclaimedRewards` counts every `unlocked` prize, so the nav badge stays lit
until the user performs a claim that has no effect. The comment on the getter is
right that a badge must mean something, and for these prizes it doesn't.

Discount prizes now *do* something at claim (they mint their coupon, `X-25`),
so this narrows to **free delivery**, the one prize type where claiming is
still a no-op.

**Decision needed:** auto-claim free-delivery prizes at unlock, or leave them
out of the badge count.

### X-27 · The prize screen is where every tap lands, and it is the least finished screen — Broken + polish

The masthead level chip, every Rewards row, "See all" and the next-reward tile
all route to `XpPrizesScreen`. The XP home is a dark, neubrutalist foil surface.
This screen is stock light Material — grey pills, `Colors.blue/purple/amber`,
a default spinner and `ElevatedButton`, `withOpacity` — so every tap is a hard
dark-to-light flip into a different product. On it:

- **the stats row always reads "0 unlocked · 0 claimed"**: it reads
  `total_unlocked` / `total_claimed`, which `/prizes` does not send
- **used prizes show a disabled "Claim" button**: `/prizes` sends no
  `is_claimed`, so `status: used` is neither claimed, claimable nor expired and
  falls through to the claim button with `onPressed: null`. *(Fixed 09-27 with
  `X-25`: used prizes now render "Used".)*
- the "Claimed" filter excludes used prizes, so they show only under "All"
- empty state isn't scrollable (no pull-to-refresh when empty); refresh swaps
  the list for a full-screen spinner
- no way to *use* a prize: a claimed free delivery has no "order now"
- `'level'.tr + ' ${prize.level}'` and `'$days ${'days_left'.tr}'` concatenate
  (RTL)

**Fix:** rebuild on the XP tokens, grouped by what the user can do (ready to use
/ ready to claim / used / expired) rather than by status filter, with a
use-it CTA per type.

### X-28 · The challenges screen is mostly unlocalized — Honesty

`X-06` listed six strings. The full list on the reachable challenges screen:
`WHAT'S NEXT`, `QUESTS`, the subtitle, `N DAY(S) STREAK`,
`ONE ORDER A DAY KEEPS IT ALIVE`, `N of M`, `CLAIMED` / `READY TO CLAIM` /
`COMPLETE` / `IN PROGRESS`, `✓ CLAIMED`, `CLAIM +N`, `RESETS IN …`,
`All done for now`, `Daily quests`, `Weekly quests`, `soon`, the `d`/`h`/`m`
suffixes, and the English weekday array. On the XP home: `+N XP JUST EARNED`.

The challenges screen also carries its own `_Q` copy of the brand colours. The
levels screen was migrated onto `Spots` tokens; this screen was not.
Spend-challenge progress prints as a bare "150 of 250" with no currency.

### X-29 · Reset countdowns never render: the server sends none of the four keys the client reads — Broken

`ChallengeModel` looks for `daily_reset_time`, `daily_reset`,
`weekly_reset_time` and `weekly_reset`. `xp/challenges` sends none of them. So:

- the challenges screen's "RESETS IN …" is always blank, and its once-a-minute
  countdown `Timer` repaints for nothing
- the XP home's "resets soon" coral urgency (`_resetsSoon`) can never fire

Each challenge *does* carry its real deadline, `expires_at`, and the daily
challenge is a rolling 24 h from assignment, not midnight (`assignChallenge`).
The per-challenge `expires_at` is the true countdown.

**Fix:** drive both countdowns from `Challenge.expiresAt`; drop the four dead
keys.

### X-30 · Claiming a quest, the core loop's payoff, is a snackbar — Polish

Tap claim, then two **serial** refetches (challenges, then level), then a
snackbar. The claimed card does not stay to show its "✓ CLAIMED" state either.
The server returns no claimed rows and assigns the next daily only after
midnight, so the card is replaced by "All done for now". The XP total changes
silently somewhere else. If the claim caused a level-up, that is not shown here
either (`X-20`).

**Fix:** optimistic claimed state held locally until the next day, an XP
fly-up into the total (the `_JustEarnedToast` animation already exists), a
parallel background refetch, and the level-up queue drained on the spot.

---

## Part 4 — Revised plan (supersedes Part 2's Phases 3–6)

**Landed 2026-09-27, all five phases in one pass.** The status table has the
per-finding outcome. Two things changed from the plan as written: `X-26` was
decided in code (free delivery has no claim step, so the badge ignores it),
because the rebuilt prizes screen no longer offers that claim; and `X-23`
gained two findings on the order list, which also had a reorder toast saying
"+N coins earned!" and a "Rate to earn +N" showing the order's XP instead of
the review award. The backend half is written and linted, not deployed.

Ordered by consequence: money first, then things that are broken or untrue,
then staleness, then polish. Backend items are marked; per
`get-stores-filter-contract`, the user deploys the backend.

### Phase A — Money and crashes

`X-15` (clear the prize after an order), ~~`X-14`~~ (✅ 09-27), `X-13`
(`try/finally` on every fetch, an error state distinct from empty, tolerant
parsing). **Backend:** `X-16` (level 0 → 500), `X-24` (one shared prize
predicate for `checkout-prizes` and `PlaceNewOrder`).

Tests: a prize used at an unchanged amount is cleared; a `LevelPrize` with
`prize_type` parses its type; a throwing service leaves no loading flag set.

### Phase B — Freshness

`X-19` (pull-to-refresh actually reloads; tab visits revalidate), `X-20`
(`refreshAfter(event)`), `X-21` (the two push types), `X-22` (drop the
leaderboard and history from the tab's init; parallel fetches). `X-10` falls out
of this: `clearXpData` on logout.

### Phase C — Honest numbers

`X-23` (per-item estimate everywhere; the server's figure after delivery, which
needs a backend field), `X-29` (countdowns from `expiresAt`). **Backend:**
`X-17` (effective streak), `X-18` (skip expired challenges).

### Phase D — The two screens users actually use

`X-27` (prizes screen rebuilt on the XP tokens, grouped by action, with use-it
CTAs), `X-28` + `X-06`/`X-07`/`X-08` (localization, with `en`+`ar` keys per
`translation-keys-workflow`), `X-30` (the claim moment), `X-05`/`X-04` (the
level-up names the level and the reward).

### Phase E — Product decisions, then cleanup

~~`X-25`~~ decided and landed 09-27. `X-26` needs a decision before code. Then `X-03`'s remainder (delete
`XpPreviewWidget`; wire or delete the leaderboard screen), `X-09` (slivers),
`X-11` (analyzer to zero).

---

## Part 5 — Second pass, 2026-10-04

A read of everything that landed in A–E, with the backend for the prize paths.
The module's shape held up: tolerant parsing, failure flags, id-scoped builders
and the freshness API (`revalidate` / `refreshAfter`) are all doing their jobs.
What's left is mostly **two sources of truth for one fact**. That is the same
shape as `X-23`, appearing in new places.

### Logic (Phase F)

**X-31 — the home Rewards list ignores `status`.** `_RewardsSection._buildRewards`
builds rows from the level payload's `is_unlocked` / `is_claimed`. The backend
(`Api/V1/XpController.php:243-245`) sets `is_claimed` for `claimed` **and**
`used`, and `is_unlocked` for any instance, expired included. So:
- an expired prize → unlocked, not claimed → **"Ready"**;
- a claimed discount whose coupon is unspent → claimed → **"Used"**, while
  Rewards shows it under "Ready to use" with its code.

The payload already sends `status`, but `LevelPrize` parses it and nothing reads
it. **Fix:** one classifier, `RewardState.of(type, status, expiresAt)` →
`claim | use | badge | used | expired | locked`, used by the home rows, the
Rewards grouping (`_group`) and the hero count. Client only.

**X-32 — prizes that vanish (backend).** `getPrizes` groups by `is_usable`,
`status == used` and `status == expired`. `isUsable()` is false for a prize
that is `unlocked`/`claimed` but either past `expires_at` (the status flips
later, on a schedule) or blocked by `canUseInPeriod()`. Such a prize is in
**none** of the three lists, so a weekly free delivery used on Monday
disappears from the app until next week. **Fix:** add a fourth group (or one
flat list with `is_usable` + `next_usable_at`); the client shows it as "Next
usable {day}".

**X-33 — two toasts on a failed claim.** `claimChallenge` and `claimPrize` call
`postData` with defaults (`handleError: true, showError: true`). On a non-200,
`ApiClient.handleResponse` toasts the server's message through `ApiChecker`,
then returns an empty `Response()`. The controller sees `statusCode != 200`,
finds no body for `_extractError`, and toasts the generic fallback on top. The
user reads "Failed to claim" over the real reason ("already claimed").
**Fix:** `handleError: false` on the two claim posts; the controller's
`_extractError` then gets the real body.

**X-34 — level-up replay.** `LevelUpScreen.showQueue` takes the queue, awaits
every dialog (user-paced), and only then acks. A `getLevelDetails` that lands
in between reassigns `_pendingLevelUps` from the server, which still lists the
same events: a push refresh, the Quests screen's init fetch, or a claim's
`refreshAfter`. The next `showQueue` plays them again. **Fix:** the controller
keeps `_celebratedIds`, filled by `takePendingLevelUps` and used to filter
incoming events. Ack stays where it is.

**X-35 — the hero is scoped to the wrong id.** `_FoilHeroCard` is built inside
the page's `idLevel` builder but reads `prizeModel.livePrizes` (`idPrizes`) and
`xpConfig.maxLevel` (`idConfig`). `revalidate` fetches all of them in parallel;
when prizes land last, the hero keeps saying "180 XP until …" over a banked
reward until something else touches `idLevel`. `_WhatsNextSection` has the
mirror problem: it's under `idChallenges` but reads `nextReward` (level). **Fix:**
nested builders on the reading widget (`_RewardWallet` under `idPrizes`), per
`getx-builder-scoping`.

**X-36 — "What's next" order.** It picks `isActive` first, then `canClaim`. A
finished quest waiting for its claim is the one thing on the page that pays out
right now, and it loses to a quest at 1/3. **Fix:** `canClaim` → `isActive` →
first.

**X-44 — feedback waits on the network.** `claimPrize` awaits `refreshAfter`
(two requests) before its snackbar. **Fix:** show the snackbar (and, later,
XM-04's burst) first, then refresh.

**X-45 — overlapping fetches.** Nothing dedupes in-flight requests. Opening
Quests from the XP tab after a claim fires `getLevelDetails` three times, and
GetConnect gives no ordering, so an older response can overwrite a newer one.
**Fix:** one `Future` per payload id in flight; a caller joins the running
one. This also narrows X-34.

### Structure (Phase G)

**X-37 — two current levels.** `getLevelDetails` parses one payload into
`XpLevelModel` (server `current_level`) **and** `LevelsListModel`, which
re-derives a level from `xp_required` thresholds and keeps the higher one. The
hero, `nextReward` and `maxLevel` checks read the first; `Level.isCurrent` /
`isUnlocked` read the second. Whenever the server lags (a pending level-up, a
refund that lowered XP, an admin threshold edit), the page disagrees with
itself. **Fix:** the server is the truth. Drop the recompute and keep one model.

**X-38 — prize types have no home.** Today the type is spread out:
- `iconForPrizeType` lives in `xp_levels_screen.dart` and the Rewards screen
  imports it from there;
- `getRewardName` lives in the controller;
- `_valueLine` lives in the Rewards screen;
- `type.toLowerCase() == 'free_delivery'` appears in about 8 places, including
  `PrizeModel.needsClaimPrizes` and `livePrizes`.

**Fix:** a `PrizeKind` enum parsed once in the model, plus
`widgets/prize_visual.dart` (icon, Rive artboard, label, value line). XM-02
hangs the animation mapping here, so this comes first.

**X-39** `_conditionsLine` exists twice (home caps expiry at 30 days, Rewards
doesn't). Move it to `prize_visual.dart`.

**X-40** `getHistory`, `XpHistoryModel`, `idHistory` and the repo/service
methods have no reader since X-22. Delete them, keeping a scratch copy
(`dead-code-reference-check`).

**X-41 — the controller's two jobs.** 20 files outside XP import
`XpController`. Most of them read level/estimate data, but checkout reads the
prize list and selection, which is the money path, with its own lifecycle
(amount-keyed, cleared by `afterOrderPlaced`). The suggested split is an
`XpCheckoutPrizeController` owning `_checkoutPrizes`, the selection and
`syncCheckoutPrizes`, matching the `StoreController` split. **Optional**: the
id scoping (X-01) already removed the perf cost. Do it if checkout is being
touched anyway.

**X-42** Split `xp_levels_screen.dart` into part files (`xp_home/hero.dart`,
`sections.dart`, `tiles.dart`, `states.dart`), as was done for the store
screens. XM-03 touches 8 of its widgets, so the split goes first.

*Not a finding:* the service layer is a pure pass-through of the repository.
That's the app-wide pattern, and changing it here alone would cost more than
it saves.

---

## Part 6 — Motion plan: animated icons, playful not noisy

### Assets

**`interactive_icon_set.riv`** (836 KB, 42 artboards). Each artboard has
`State Machine 1`, a `Boolean 1` input, `HITBOX Enter/Exit` listeners and an
`NN_Name_Idle` / `NN_Name_Anim` pair. Artboard names are `01_Star`,
`02_Heart`, `03_Flash`, `06_Diamon` (sic), `21_Crown`, `23_Coin`, `26_Fire`,
`27_Mail`, `22_Plant`, `35_Sun`, `42_Star 2`, and so on. **Excluded as
off-brand:** Cigarette, Gun, Skull, Bomb, Bandaid.

Others in use: `streak_w.riv` (hero flame, keep), `gift_box.riv` (artboard
`Referral_gift`), and the Lottie files `waddi_coins.json`,
`bottom_nav/rewards.json` and `gem.json`.

### Rules (XM-06)

1. **One loop per screen.** The streak flame on XP home and Quests. Nothing else
   loops.
2. **Everything else plays once:**
   - on first reveal, staggered about 80 ms apart;
   - when its state changes for the better (a reward becomes ready, a quest
     becomes claimable, a claim lands);
   - on tap, where the row has no other tap action.
3. **Motion means good news.** Locked, used and expired items, and error
   states, stay static Material glyphs.
4. **Reduced motion:** the Rive icon shows its first frame, and Lottie isn't
   built.
5. **Budget:** at most about 8 live Rive views per screen. The Rewards list
   animates only its `claim`/`use` cards.

### Pieces

**XM-00 — preview sheet (first).** A local HTML page renders all 42 artboards
on the `foil` / `panel` colours with the Rive web runtime. It answers three
questions:
- Does the set's own palette sit on dark teal + mint? If not, the set is out,
  or it's used only for gold "win" moments.
- Is `Idle` a still frame or a loop?
- Does `Boolean 1` drive a one-shot or a held state?

Final picks come from this.

**XM-01 — `widgets/xp_rive_icon.dart`.**
- **Loading:** one `File` for the set, loaded once per session by a small cache
  and reused by every icon, rather than a `FileLoader` per widget as in
  `StreakRiveBadge`.
- **Per icon:** a `RiveWidgetController` per instance with
  `ArtboardSelector.byName`. Guard it, since it throws on a missing artboard
  (`rive-014-api`).
- **API:** `XpRiveIcon(kind, size, playOnReveal)` plus a `GlobalKey` method
  `play()` that sets `Boolean 1` true and resets it.
- **Fallback:** the `PrizeVisual` Material icon on load failure or reduced
  motion.

**XM-02 — mapping (provisional, until XM-00):**

| Slot | Artboard |
|---|---|
| prize `free_delivery` | `03_Flash` |
| prize `discount` | `06_Diamon` |
| prize `wallet_credit` | `23_Coin` |
| prize `badge` / hero fallback | `21_Crown` |
| other prize | `42_Star 2` |
| source: order | `23_Coin` |
| source: vote | `02_Heart` |
| source: review | `01_Star` |
| source: add place | static `add_location` glyph (no pin in the set) |
| source / quest: streak | `26_Fire` |
| quest `complete_order` / `multiple_orders` | `23_Coin` |
| quest `min_order_amount` | `06_Diamon` |
| quest `new_store` | `01_Star` |

**XM-03 — XP home:**
- **`_HeroBadge`:** Crown when the server sends no badge image; plays on level
  change.
- **`_SourceRow`:** icon plays on reveal.
- **`_RewardRow`:** animated for `claim`/`use` only (X-31's state).
- **`_RewardTile`:** `gift_box.riv` once on reveal.
- **`_JustEarnedToast`:** a `waddi_coins.json` one-shot behind the number.
- **Sign-in prompt:** `rewards.json` replaces the trophy.

**XM-04 — Rewards screen:**
- **Live cards:** the glyph plays on reveal.
- **Claim success:** the card's icon plays plus the `waddi_coins` burst,
  replacing the snackbar-only payoff (with X-44's ordering).
- **Empty state:** 🎁 becomes `gift_box.riv`.
- **Error state:** 📡 stays static.

**XM-05 — Quests screen:**
- **Streak card:** 🔥 becomes `StreakRiveBadge`, so it matches the home flame
  (X-43).
- **Quest icon:** chosen by `challenge_type`, with the backend's emoji as the
  fallback for unknown types.
- **Reward chip:** plays once when `canClaim` flips. The existing "+N XP"
  fly-up stays.

**XM-07** Asset cleanup once XM-05 lands:
- `level_up_waddy.riv`, `level_up_w_f.riv` and `level_upـwaddy_f.riv` are
  ~1.3 MB each; one is used (`level_up_rive_burst.dart`).
- `crown.riv` and `crown_w.riv` are byte-identical in size; check with `cmp`.
- `22243-46463-level-up.riv` has no reference.

Grep before deleting (`dead-code-reference-check`).

### Order

**F** (X-33, X-34, X-35, X-36, X-44, X-45, X-31; X-32 backend in parallel) →
**G** (X-38, X-39, X-40, X-42, X-37; X-41 optional) → **H** (XM-00 → XM-01 →
XM-02 → XM-03..05 → XM-07). F and G are small and remove the wrong states the
animation would otherwise decorate. That's why motion goes last.

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

The analyzer count for `lib/features/xp` is the progress check; its current
value lives in the status table (`X-11`). Spots is at 0.
