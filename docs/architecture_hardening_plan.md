# Architecture Hardening Plan — Competing at Talabat / HungerStation scale

**Status:** P0 done · flavors/staging done (iOS schemes outstanding) · P1 next
**Revised:** 2026-09-19 after review — see §12 for what the review changed
**Written:** 2026-09-19
**Codebase at time of writing:** 220,334 LOC · 850 Dart files · 40 features · 0 analyzer errors · 466 analyzer infos/warnings

---

## 0. The thesis

Waddi's skeleton is already better than most apps its size. Forty features all follow
`controllers/ domain/{models,repositories,services}/ screens/ widgets/`. There are 39
repository interfaces and 38 service interfaces against 39 controllers — near 1:1, with
dependencies inverted through a single composition root in `lib/helper/get_di.dart`. The
comments carry *reasoning* rather than description (`api_client.dart` explains why the
shared `http.Client` exists in terms of Egyptian mobile RTT). CI already runs analyze +
test + a bespoke architectural guard.

That is not the problem.

The problem is that **the architecture is a convention, not a constraint.** Nothing stops
a developer from violating it, so entropy accumulates at a predictable rate: 100 orphaned
files, 527 unscoped `update()` calls, 260 unguarded `int.parse`, a truncating money
function with no test. Talabat and HungerStation do not beat us because their engineers
are better. They beat us because at their scale, the cost of a regression is measured in
revenue per minute, so they made the architecture *mechanically enforced*.

This plan has one organizing principle:

> **Every architectural rule in this document must be enforced by a machine, or it is not
> a rule — it is a wish.**

Each phase below ships (a) the fix, and (b) the guard that prevents the fix from decaying.
A phase is not "done" when the code is correct. It is done when the code is correct *and
CI fails if someone makes it incorrect again.*

### Non-goals

- Rewriting to Bloc/Riverpod. GetX is not the bottleneck; **undisciplined** GetX is. A
  rewrite would burn a quarter and reintroduce bugs already fixed. We constrain GetX instead.
- Modularising into separate pub packages. Considered in §9 as a *later* option, gated on
  team size. Premature here.
- Redesigning the backend. Out of scope except where the client/server contract is the bug.

---

## 1. Scoreboard — what "scale-ready" means, measurably

These are the gates. Each phase moves specific numbers. No phase is complete until its
metric is both hit *and* CI-locked.

| # | Metric | Today | Target | Phase | Enforced by |
|---|---|---|---|---|---|
| M1 | Money bugs | 1 known, 0 tests | 0 ✅, 51 PHP vectors | P0 | `money-parity-guard` |
| M2 | Unguarded parses at the JSON boundary | 26 | **0 ✅** (183 elsewhere, ratcheted) | P2 | `parse-guard` |
| M3 | Dead files | 132 (30,216 LOC) | **0 ✅** | P2 | `dead-code-guard` (budget 0) |
| M4 | Unscoped `update()` | 526 | **not a perf metric** — see §22 | P4 | maintainability only |
| M5 | Unguarded **optional-field** bangs | ~60 | 0 ✅ (money/gating) | P3 | `sparse_config_test` |
| M6 | Silent `catch (_) {}` | 50 | 0 ✅ | P3 | `silent-failure-guard` |
| M7 | Tier-1 money paths covered | 0 | **done ✅** — ratio is the wrong measure, §22 | P1 | contract tests |
| M8 | Guarded sensitive routes | 6 / 75 | 22 / 22 ✅ | P3 | `route-guard` |
| M9 | Build flavors | 0 | 3 ✅ (iOS schemes pending) | P5→P0.5 | `flavor-guard` |
| M10 | Cold start to first paint | ~1,014ms frame | **instrumented ✅**, baseline pending | P6 | `BootStats` |
| M11 | Crash-free sessions | anonymous reports | **context attached ✅**, alert pending | P6 | `CrashContext` |
| M12 | Real secrets in repo | 1 (HMAC) | 0 ✅ | P0 | secret scan |

---

## 2. Phase 0 — Stop the bleeding (1 day)

Ship today. No dependencies, no risk, immediate value.

### 0.1 Fix the money truncation — `lib/helper/price_converter.dart:114`

```dart
// WRONG — truncates. 10.999 -> 10.99, 2.675 -> 2.67
return (((val * mod).toPrecision(digits)).floor().toDouble() / mod);
```

`toFixed` is called by all 209 `convertPrice` call sites and by the checkout total. It
biases **every price in the app downward** by up to one minor unit. Because
`PlaceNewOrder.php` recomputes `order_amount` server-side, the client and server can
disagree on every order — the customer is shown one total and charged another. At Talabat
volume this is a regulatory problem, not a rounding problem.

Replace `.floor()` with `.round()`, then add the test that should always have existed:

```dart
test('toFixed rounds half-up, never truncates', () {
  expect(PriceConverter.toFixed(10.999), 11.00);
  expect(PriceConverter.toFixed(2.675),   2.68);
  expect(PriceConverter.toFixed(0.1+0.2), 0.30);
});
```

**Verify against the backend first.** If PHP uses `floor` too, changing only the client
converts a silent agreement into a visible mismatch. Check `PlaceNewOrder.php` rounding
and change both in the same deploy.

### 0.2 Move the auth token to secure storage

`lib/helper/secure_storage_helper.dart` already has `saveToken`/`getToken`/`deleteToken`
with `encryptedSharedPreferences: true`. **Nothing calls them.** The token is written in
plaintext at `auth_repository.dart:170` and read at `:402`. The infrastructure was built
and never connected.

Wire it, with a one-time migration: on read, if SharedPreferences holds a token and secure
storage does not, copy it across and delete the plaintext copy.

### 0.3 Decide on the order signature

`OrderSecurityService.php` says it outright: *"Logs warnings only — never blocks the order."*
Expired timestamps log and continue. Bad HMACs log and continue. And the secret is
**compiled into the shipped client**:

```dart
static const _orderSignatureSecret = 'waddi_order_sec_2026';  // order_security_helper.dart:17
```

The backend falls back to the same literal. A secret in a distributed binary is not a
secret. Either enforce it with a server-only secret, or delete it and stop implying a
protection that does not exist. The idempotency half *is* correctly wired and does block
duplicates — keep that.

### 0.4 Hoist Firebase keys out of `main.dart:48-55`

Hardcoded `apiKey`/`appId`/`projectId`. Move to `firebase_options.dart` via FlutterFire
CLI, per flavor (§5).

**Exit:** M1 closed. Token encrypted. Signature decision made and documented.

---

## 3. Phase 1 — A test net around money and orders (1 week)

Today: 29 test files, 6,912 LOC against 220k — **3.1%**. The existing tests are well aimed
(`out_of_zone_derivation`, `di_graph`, `cart_reward_state`, `location_gate`, goldens) —
they cover exactly the seams that have burned us. But there was no test on `toFixed`,
which is why §0.1 survived to production.

We do not chase global coverage. We ring-fence the paths where a bug costs money.

**Tier 1 — must be exhaustively tested (target ~80%):**
- `PriceConverter` — every rounding path
- `CheckoutCalculationHelper` — all 655 lines: subtotal, addons, variations, discount,
  coupon, tax, delivery fee, surge, tips, partial pay
- `OrderPayloadBuilder` — payload shape is the client/server contract
- `CartController` — add/remove/update/clear, quantity edges
- `OrderSecurityHelper` — idempotency, rate limit, fingerprint stability

**Tier 2 — behavioural coverage:** auth flow, address/zone resolution, module switching.

**Tier 3 — golden tests:** already seeded; extend to cart bar, checkout summary, order card.

### The contract tests that matter most

The recurring class of bug in this codebase is **client/server contract drift** — every
one of your existing plan docs has at least one. Add a `test/contract/` suite that asserts
parsing against **real captured JSON fixtures**, one per endpoint:

```
test/contract/fixtures/get_stores_response.json
test/contract/fixtures/place_order_response.json
test/contract/fixtures/config_response.json
```

Then assert both directions: fixture parses without throwing, *and* the payload we build
matches what the backend validator accepts. Refresh fixtures from staging in CI weekly —
a diff is an early warning of a breaking backend change, caught before release rather than
in Crashlytics.

**CI gate:** `--coverage`, fail if Tier 1 files drop below 80%.

**Exit:** M1, M7 (critical paths) closed.

---

## 4. Phase 2 — Delete, then make deletion permanent (3 days)

### 2.1 Remove the 100 dead files (22,658 LOC — 10% of the codebase)

Verified individually for a sample: `order_info_widget.dart`, `tracking_stepper_widget.dart`,
`home_app_bar_widget.dart`, `dark_theme.dart`, `network_info.dart` — all zero external references.

| Feature | Dead files |
|---|---|
| order | 23 |
| home | 19 |
| common | 6 |
| xp | 5 |
| helper | 5 |
| other | 42 |

`order` is worst: **three** orphaned tracking-stepper implementations (`tracking_stepper_widget`,
`enhanced_tracking_stepper_widget`, `order_steps_card`), plus `lucky_spin_widget`,
`waiting_game_widget`, `order_calcuation_widget` (the typo never got used). This is the
direct cause of "which widget is actually live?" — the ambiguity that `cart-bar-which-widget`
had to resolve by hand.

Also live-but-duplicated: `payment_button.dart` **and** `payment_button_new.dart`.

**Caution:** the list came from an import grep. Files reached only via dynamic string
route names would evade it. Delete in one commit, on a branch, with CI green — trivially
revertable.

Move the two stray `.md` files out of `lib/features/auth/screens/`.

### 2.2 Eliminate unguarded parsing (260 sites)

`int.parse`/`double.parse` throw on malformed input. 20 sit directly on the JSON boundary:

```dart
// order_details_model.dart:129 — throws on null/garbage, kills the whole screen
quantity = int.parse(json['quantity'].toString());
```

Backend seed data and nullable columns make this a live crash, not a theoretical one.
Introduce `lib/util/json_parse.dart` with `asInt`/`asDouble`/`asString`/`asBool`/`asList`
helpers that never throw, and migrate all 260. Manual `fromJson` (614 of them, no
`json_serializable`) is defensible — but it must be *defensive*.

### 2.3 The guards

Extend `.github/workflows/ci.yml`, which already proves this pattern works with
`mobile-only-guard`:

```yaml
  dead-code-guard:
    # An unimported file is a maintenance liability and a source of
    # "which widget is live?" ambiguity. See docs/architecture_hardening_plan.md §4.
    - name: No unimported files in lib/
      run: |
        fail=0
        for f in $(find lib -name '*.dart' ! -name 'main.dart' ! -name '*.g.dart'); do
          b=$(basename "$f")
          if [ "$(grep -rl "/$b'" lib --include='*.dart' | wc -l)" = "0" ]; then
            echo "::error file=$f::unimported — delete it or wire it up"; fail=1
          fi
        done
        exit $fail

  unsafe-parse-guard:
    - name: No raw int.parse/double.parse
      run: |
        if grep -rnE "(int|double)\.parse\(" lib --include='*.dart'; then
          echo "::error::use JsonParse.asInt/asDouble — raw parse throws on bad payloads"
          exit 1
        fi
```

**Exit:** M2, M3 closed and locked.

---

## 5. Phase 3 — Make invalid states unrepresentable (2 weeks)

This is the phase that most separates us from a template fork.

### 3.1 The 366 `configModel!` dereferences

Every one is a crash on any path where config has not loaded. `PriceConverter.toFixed`
itself calls `Get.find<SplashController>().configModel!.digitAfterDecimalPoint!` — so a
config failure crashes *price formatting*, on every screen.

Introduce a typed, non-null config accessor with explicit fallbacks:

```dart
/// Config with guaranteed-safe defaults. `configModel!` was a crash on every
/// path where config had not loaded yet — including price formatting, which
/// runs on essentially every screen.
class AppConfig {
  static ConfigModel? get _raw => Get.find<SplashController>().configModel;
  static int get digitsAfterDecimal => _raw?.digitAfterDecimalPoint ?? 2;
  static bool get cashOnDelivery => _raw?.cashOnDelivery ?? false;
  static bool get isLoaded => _raw != null;
}
```

Migrate all 366, then guard `configModel!` to zero in CI.

### 3.2 The 202 bang operators in `CheckoutCalculationHelper`

655 lines, one null-assertion every 3.2 lines, reaching into five controllers
(Splash, Cart, Coupon, Profile, XP) via `Get.find` with no guards. This is the single
most fragile file on the revenue path.

Refactor to a **pure function over an explicit input struct**:

```dart
/// All pricing inputs, resolved once at the call site. The helper no longer
/// reaches into five controllers mid-calculation, so it is testable without a
/// GetX container and cannot crash on a controller that is not registered.
class PricingInputs {
  final Store store;
  final List<CartModel> cart;
  final ConfigSnapshot config;
  final UserDiscount? userDiscount;
  final CouponState coupon;
  final XpState xp;
}

CheckoutPricing calculatePricing(PricingInputs inputs) { /* pure */ }
```

This kills three problems at once: untestability, hidden dependencies (your
`checkout-pricing-hidden-deps` note), and the crash surface.

### 3.3 The 50 silent `catch (_) {}`

Each one swallows an error with no log and no user feedback — invisible failures in
production. Every catch must do one of: log to Crashlytics, show user feedback, or carry
a comment explaining why the error is genuinely ignorable.

### 3.4 Route guards — 6 of 75

Guarded today: `profile`, `address`, `flashSaleDetails`, `favourite`.
**Unguarded:** `wallet`, `checkout`, `orderDetails`, `refund`, `payment`, `updateProfile`.

With `app_links` deep linking active, an unauthenticated user can be dropped straight onto
a wallet or checkout screen. The screens presumably null-check their way out — that is
defense by accident, not by design.

Define the sensitive route set explicitly and add a test asserting every member carries
`AuthGuardMiddleware`. New sensitive route without a guard → red CI.

### 3.5 Backfill 36 Arabic keys

Missing in `ar.json`: `maadi_exclusive`, `tap_to_scratch`, `free_cold_coffee`,
`see_live_rider`, `share_now`, … These render as **raw keys** to Arabic users — half the
market. 24 orphans exist only in `ar.json`.

Guard: CI fails if the key sets diverge. This is mechanical and should never regress
again (`translation-keys-workflow`).

**Exit:** M5, M6, M8 closed and locked.

---

## 6. Phase 4 — The performance ceiling (3 weeks)

The single biggest structural weakness, and it is systemic.

| Signal | Count |
|---|---|
| `GetBuilder<>` | 347 |
| Bare `update()` | **527** |
| Scoped `update([...])` | 73 |
| `Obx` | **0** |
| `.obs` / Rx | **0** |

The app uses GetX but **only the non-reactive half**. Every bare `update()` rebuilds
*every* `GetBuilder` bound to that controller. Home alone has 96.

| Controller | bare | scoped |
|---|---|---|
| `item_controller` | 60 | **0** |
| `store_controller` | 43 | **0** |
| `checkout_controller` | 37 | **0** |
| `cart_controller` | 22 | **0** |
| `places_controller` | 18 | **30** ← the model |

`places_controller` is the proof the fix is known and achievable — someone already did it
there. It simply never propagated.

Concretely: **every quantity tap in the cart repaints the entire checkout tree.** On the
mid-range Androids that dominate the Egyptian market, that is the difference between
feeling like Talabat and feeling like a template.

Compounding it: 101 `shrinkWrap: true` + 102 `NeverScrollableScrollPhysics` against only
50 Sliver usages — nested non-lazy lists doing full-subtree layout on each rebuild.

### Order of attack (by revenue impact)

1. `cart_controller` — every tap, directly pre-purchase
2. `checkout_controller` — the conversion moment
3. `item_controller` — highest absolute count (60)
4. `store_controller` — 22 GetBuilders downstream
5. `home` — 96 GetBuilders, biggest absolute win

### Method

Per controller: enumerate update ids in one enum, replace bare `update()` with
`update([Ids.x])`, give each `GetBuilder` its matching `id:`, and honour the
`getx-builder-scoping` rule (id'd builders ignore plain `update()` — use filter + `ValueKey`).

Convert the worst `shrinkWrap` offenders on home/store to slivers.

**Measure, don't guess.** Establish a baseline first with a scripted profile run on a real
mid-range device. Record jank frames on: home scroll, store scroll, cart quantity tap,
checkout load. Target < 1% jank; regression fails CI.

**Guard:**
```yaml
  update-scoping-guard:
    - name: Bare update() budget
      run: |
        n=$(grep -rho "update();" lib --include='*.dart' | wc -l)
        echo "bare update(): $n (budget 50)"
        [ "$n" -le 50 ] || { echo "::error::bare update() over budget"; exit 1; }
```

A ratchet: lower the budget as each controller lands.

**Exit:** M4, M10 closed and locked.

---

## 7. Phase 5 — Release engineering (1 week)

Today there is **one hardcoded production URL** (`app_constants.dart:30`), no flavors, no
staging. Every developer test hits production. This alone disqualifies us from operating
at competitor scale.

### 5.1 Three flavors — dev / staging / prod

Separate `applicationId` suffixes so all three install side by side; base URL, Firebase
project and analytics keys per flavor; `--dart-define-from-file` for config.

### 5.2 Secrets out of the repo

Three classes today: Firebase keys (`main.dart:48`), the HMAC secret
(`order_security_helper.dart:17`), and the `google-services.json` / `Info.plist` pair.
Move to CI secrets injected at build; add a secret-scanning CI step.

### 5.3 CI/CD build-out

The existing pipeline is a good foundation. Extend to: coverage gate, all §4/§5/§6 guards,
build both flavors on every PR, golden-test diffs as PR artifacts, automatic staging
deploy on merge to main, tagged prod release.

### 5.4 Crash & performance budget

Crashlytics is wired but thin (8 refs). Firebase Performance is **absent** (0 refs).

Add: Performance Monitoring, cold-start trace, network traces per endpoint, custom traces
for cart→checkout→order. Alert on crash-free sessions < 99.5%.

**Exit:** M9, M11, M12 closed.

---

## 8. Phase 6 — Resilience under real conditions (2 weeks)

Egyptian mobile networks are the operating environment. The app must degrade, not fail.

### 6.1 Offline cache — 12 of 38 repositories

Cached today: splash, category, banner, store, item, brands, places, flash sale, parcel,
cuisine, campaign, advertisement. **Not cached:** order history, profile, wallet, address,
coupon, favourite.

Order history in particular is the screen a user opens on a flaky connection to check
their delivery — and it shows a spinner. Extend `LocalClient` coverage; define an explicit
TTL per endpoint (`CacheTtlHelper` already supports this well).

### 6.2 Network layer

Already good: shared `http.Client`, 12s timeout, one GET retry deliberately not applied to
POST/PUT/DELETE, 401 sweep with instrumentation. Add: exponential backoff with jitter,
a circuit breaker for repeatedly-failing endpoints, and request coalescing (home fires ~25
requests at once — dedupe identical in-flight calls).

### 6.3 Boot sequence

`main()` serially awaits Firebase → `di.init()` → notifications → deep links →
`initializeDateFormatting()` before `runApp`. Each is a cold-start tax. Parallelise what
is independent; defer what is not needed for first paint. Budget cold start and enforce it.

### 6.4 Error UX

Every network-dependent surface needs explicit loading / empty / error / offline states.
The inline error+retry row approved in `home-critique-decisions` is the pattern —
generalise it. Also remove the `textScaler` pin at `main.dart:208` (already identified as
a bug: it breaks OS accessibility settings).

**Exit:** M10 closed. Offline coverage at 100% of user-visible read paths.

---

## 9. Structural options — deliberately deferred

Revisit only when the trigger fires. Doing these now would be premature.

**Melos / pub-package modularisation.** Trigger: > 8 engineers, or build times
> 10 min. Today's coupling is already concentrated where it should be (home→21,
order→18, dashboard→14 — aggregators *should* aggregate). Two genuine inversions worth
fixing regardless: `location`→11 and `splash`→12, infrastructure reaching up into features.

**Melos-free module boundaries.** Cheaper interim: an import-boundary CI guard declaring
which features may import which. Catches 80% of the value for 5% of the cost. **Recommended
after Phase 4.**

**State management migration.** Not until Phase 4 proves scoped GetX is insufficient.
It almost certainly will be sufficient.

**Vendor screens split.** `store_registration_screen.dart` (3,606 LOC) and
`delivery_man_registration_screen.dart` (2,190 LOC) = **5,796 lines** of merchant/courier
onboarding compiled into the consumer binary, reachable via two `route_helper` entries.
Move to a separate vendor app, or gate behind a flavor. Trigger: when vendor onboarding
gets its own roadmap.

---

## 10. Sequencing

```
Week 1     P0  Stop the bleeding          money · token · signature · keys
Week 2     P1  Test net                   Tier-1 + contract fixtures
Week 3     P2  Delete + guards            100 files · 260 parses
Week 4-5   P3  Invalid states             configModel · bangs · catches · routes · i18n
Week 6-8   P4  Performance                cart→checkout→item→store→home
Week 9     P5  Release engineering        flavors · secrets · CI · monitoring
Week 10-11 P6  Resilience                 cache · network · boot · error UX
```

**Parallelisable:** P1 is independent of P2. P5 can run alongside P3/P4 by a different
person. P0 blocks nothing and should ship immediately.

**Critical path:** P0 → P1 → P3 → P4. P1 before P3 is non-negotiable — refactoring the
pricing helper without tests is how you turn one money bug into five.

---

## 11. The one rule

Every phase ships a guard. A rule a machine does not enforce is a rule that decays the
moment the person who remembers it is on holiday.

The `mobile-only-guard` in `ci.yml` already proves the team can do this — it exists
precisely because web code paths "kept finding their way back in through merges," and a
grep in CI stopped it permanently.

**That is the template. Apply it to everything in this document.**

---

## 12. What review changed (2026-09-19)

The plan was reviewed before execution. Six things were wrong; all are corrected
above or here. Recording them because the *reasons* generalise.

### 12.1 The signature could never have been "enforced"

The original §0.3 offered "enforce it with a server-only secret, or delete it."
The first option is incoherent: a client-generated signature requires the client
to hold the signing key, so there is no such thing as a server-only secret in
that design. Any key the app can use, an attacker who unpacks the APK can use.

**Done:** deleted from both sides — client signing method, the hardcoded
`waddi_order_sec_2026`, the payload fields, `verifySignature()`, its validation
rules, and the orphaned `config/services.php` fallback. Idempotency (which does
block duplicates), the cooldown, and fingerprint telemetry all kept.

If tamper-evidence is wanted later, the shape that works is **server-issued**:
the server signs a short-lived quote token with its own secret and the client
echoes it back. Play Integrity / App Attest is the tool for proving the caller is
a genuine app build. Neither is urgent.

### 12.2 `.round()` was not enough — and the fix is shared vectors

`2.675` and `1.005` are binary-float traps, and a naive `.round()` does **not**
reproduce PHP:

| value | PHP `round(v,2)` | `(v*100).round()/100` |
|---|---|---|
| `1.005` | **1.01** | 1.0 |
| `8.995` | **9.0** | 8.99 |

PHP pre-rounds to undo representation error; Dart does not. `toStringAsFixed`
was worse — 5 of 12 mismatches.

**Done:** `roundLikeServer()` ports PHP's `_php_math_round`, verified against
**51 vectors generated by PHP itself** (`tool/generate_rounding_vectors.php`).
Client and server are now locked together by construction rather than by both
sides happening to agree. `Money` (integer piasters) is the target type for new
pricing code. See `docs/money_rounding.md`.

### 12.3 The dead-code grep would have failed on valid code

Confirmed: 4 same-directory relative imports (`import 'foo.dart';` — no slash)
and a `part` file would have been flagged as dead. The grep also could not see
`export`, could not distinguish same-named files in different folders, and
treated two dead files importing each other as alive.

**Done:** replaced with `tool/find_unused_files.dart`, which resolves every
directive to an absolute path and walks the graph from `main.dart` and every
test.

It finds **132 files / 30,202 lines**, against the grep's 100 / 22,658 — the
grep was missing transitively-dead code. Notably **the entire `online_payment`
feature (5 files) is dead**: its controller is unreferenced, so the whole
subtree is unreachable. That is exactly the dead-cycle case a filename grep
cannot see.

### 12.4 Never-throw parse helpers are wrong for money

Silently defaulting a missing price to `0` is worse than crashing — it produces
a plausible wrong number that flows into an order.

**Revised for P2:** two tiers, not one.
- **Lenient** (`asIntOrNull`, display fields): tolerate garbage, render a
  fallback.
- **Strict** (price, quantity, totals, ids): log to Crashlytics and **block the
  flow**. A checkout that refuses to proceed is recoverable; a wrong total is not.

The same applies to `AppConfig` in §5.1: a wrong tax or delivery fee that
"works" is worse than gating checkout until config has loaded. Defaults are for
*display* config (decimal digits, currency side), never for money inputs.

### 12.5 The sequencing had a dependency bug

P1 said "refresh contract fixtures from staging in CI weekly" — but staging did
not exist until P5.

**Done:** flavors and staging pulled forward out of P5 and shipped now. Every
developer test previously hit production, which was the most dangerous single
fact in the document. See `docs/build_flavors.md`.

Also: the phase durations summed to ~9 weeks while §10 said 11. Treat §10's
calendar as indicative; the phase estimates are the real ones.

### 12.6 M12 overcounted secrets

Firebase API keys and `google-services.json` are **identifiers**, not
credentials — they ship inside every public binary by design. Protect them with
console key restrictions and security rules, not by hiding files.

**Done:** M12 now counts one real secret (the HMAC), which is removed.
Per-flavor Firebase config is still worth doing, for environment separation and
to keep developer sessions out of production Crashlytics — not for secrecy.

### 12.7 On priorities

Talabat and HungerStation win on rider density, supply and logistics — not on
`Obx` counts. This plan must not eat the roadmap.

Two consequences, both adopted:

- **P4 and P6 wait for profiling data.** 527 bare `update()` is a smell, but
  rebuild counts are not jank. Nested `shrinkWrap` lists and image handling may
  matter more. Measure first.
- **No jank gate in GitHub Actions.** It cannot work without real devices. Track
  it on a device farm and *alert*, rather than blocking merges. M10's "enforced
  by: perf test" should read "device-farm alert".

### 12.8 Guards should be lints, not greps, where possible

For the `int.parse` and `configModel!` rules, a custom analyzer plugin
(`custom_lint`) is more robust than grep, which also matches comments and
strings. The greps shipped now are the interim; treat the plugin as the P3
deliverable.

The two cheapest mechanical guards — the route-guard test and the `ar.json` key
diff — were moved early as recommended. The i18n one is live as `i18n-guard`.

---

## 13. Landed so far

| Item | Artifact | Guard |
|---|---|---|
| Money rounding parity | `lib/util/money.dart`, `docs/money_rounding.md` | `money-parity-guard` |
| Integer minor units | `Money` in `lib/util/money.dart` | contract test |
| Token in encrypted storage | `lib/helper/auth_token_store.dart` | `credential-guard` |
| Fake HMAC removed | both repos | `credential-guard` |
| Real dead-code analysis | `tool/find_unused_files.dart` | `dead-code-guard` (ratchet: 132) |
| i18n key parity | — | `i18n-guard` (ratchet: 36 / 24) |
| Flavors + staging | `lib/util/app_environment.dart`, `env/*.json`, `docs/build_flavors.md` | `flavor-guard` |

**Verification at time of writing:** analyzer 466 issues (unchanged — no new
debt), 440 tests passing (up from 424). Three failures are pre-existing and
unrelated: `marks_render_test.dart` is entirely commented out (no `main`), and
two Spots draw-count assertions in files modified before this work began.

**Outstanding from this batch:** iOS schemes (§4 of `docs/build_flavors.md`) and
dev/staging Firebase apps (§5). Both are console/Xcode work, deliberately not
scripted.

**Next:** P1 — characterization tests on `CheckoutCalculationHelper` capturing
today's behaviour, *then* the pure-function refactor on top of `Money`.

---

## 14. P1 progress — what the characterization tests found

`test/unit/checkout_pricing_gaps_test.dart` covers the six helper methods
`cart_checkout_test.dart` never reached: `getDiscountPrice`,
`getExtraDiscountPrice`, `calculateFoodVariationDiscount`,
`calculateOrderAmount`, `calculateOriginalDeliveryCharge`, and the two payment
gates. 27 tests, all green.

**Revision to the plan:** §5.2 assumed `CheckoutPricing` had to be built. It
already exists (`lib/features/checkout/domain/models/checkout_pricing.dart`) and
is exactly the right shape — the fourteen calculations run once, in dependency
order, into an immutable object, with the two tooltip out-parameters already
converted to return values. **The orchestration layer is done.** What Phase 3
still owes is pushing the four `Get.find` dependencies out of the *leaf* methods
and onto an explicit input struct.

Three things the tests found by failing first. Each is pinned as current
behaviour, with the intended behaviour stated in a comment.

### 14.1 `calculateOriginalDeliveryCharge` returns `-1`, not `0`

`deliveryCharge` initialises to `-1` and every branch that could overwrite it is
guarded by `store != null`. A null store therefore yields **minus one**, which
is a negative charge if a caller ever adds it to a total without checking.

Callers do check — `checkout_screen.dart:1021` tests `deliveryCharge == -1`
alongside `distance == -1` — so this is a latent trap rather than a live bug.
But the sentinel is invisible in the type, and one unguarded `+` turns it into a
discount. **Phase 3: return a nullable or a result type instead.**

### 14.2 The payment gates crash without a stored address

`checkCODActive` and `checkDigitalPaymentActive` both open with
`AddressHelper.getUserAddressFromSharedPref()!` — a bang on a nullable read. A
signed-in user whose address has not loaded yet gets a thrown exception in the
payment section rather than "no methods available".

Pinned as `throwsA(anything)` so the Phase 3 fix registers as a deliberate
change. This is a concrete instance of the 366 unguarded dereferences in M5, on
the checkout path.

### 14.3 `calculateOrderAmount` has no zero clamp

An over-large coupon drives the order amount negative (`-150` on a 50 EGP cart
with a 200 EGP coupon), and that negative figure then selects the delivery tier.

The server recomputes the charge, so this is a wrong *quote*, not a wrong
charge. It is precisely what `Money.clampedToZero` exists to make
unrepresentable once the helper moves onto `Money`.

### 14.4 Method note

Every one of these was found because a test asserted what the code *should* do,
failed, and was then corrected to assert what it *does*. That is the
characterization loop working as intended — the failures were the deliverable,
not an obstacle. Writing these tests to pass first time would have found
nothing.

---

## 15. P1 complete, and the three findings fixed

### 15.1 The rest of the net

`test/unit/cart_guards_and_payload_test.dart` — 27 tests, green first run.

- **The cart mixing guards** (`existAnotherStoreItem`, `existAnotherModuleItem`,
  `isExistInCart`, `cartQuantity`). These decide whether adding an item silently
  replaces the cart. Get one wrong and a customer either loses a cart they were
  building or ends up with an order spanning two stores no single rider can
  fulfil. Nothing tested them.
- **`OrderPayloadBuilder`** — the contract for what an order *is*. `CS-07`
  records that its loop existed verbatim twice and `CS-02` is the bug that
  slipped through because of it; it was deduplicated but never pinned.

These passed first time, unlike the pricing tests, because they are genuinely
pure functions over lists. That contrast is the argument for §5.2: the leaf
pricing methods are hard to test *because* they reach into controllers, not
because the arithmetic is hard.

One assertion choice worth noting: `OnlineCart._variations` has no getter, so
the food-variation tests assert against `toJson()`. That is the better level
anyway — the JSON is the contract, and both variation shapes serialise to the
same `variation` key.

### 15.2 A fifth hidden dependency

`cart_checkout_test.dart` documents four controllers the "pure" helper reaches
for. There are **five**: `calculateDeliveryCharge` also asks `CouponController`
whether free delivery was won. Found by a test failing to boot.

### 15.3 The `-1` sentinel was a live bug, not a latent one

§14.1 called it latent because `checkout_screen.dart:1021` guards submission on
it. A probe test disproved that:

```dart
charge = calculateDeliveryCharge(store: null, ...);  // -1
total  = calculateTotal(subTotal: 100, deliveryCharge: charge, ...);  // 99
```

`calculateTotal` adds `deliveryCharge` unguarded. The screen guarded
**submission**, never the total it **displays** — so a user waiting for a
distance to resolve saw a total one pound light.

**Fixed** in `calculateDeliveryCharge`: the sentinel is absorbed to `0` before
any arithmetic. `calculateOriginalDeliveryCharge` still returns `-1` for callers
that must distinguish "not yet known" from "free".

The submission guard then had a dead condition — `deliveryCharge == -1` could
never fire — so it now tests `distance == -1` alone, which is the real question:
a delivery order whose distance has not resolved cannot be priced, whatever the
charge reads.

### 15.4 The other two

- **Payment gates** no longer crash without a stored address. Both banged
  through `getUserAddressFromSharedPref()!` despite `AddressHelper`'s own doc
  saying "having no saved address is a NORMAL state". They now report no
  methods available, which is what an unresolved address means.
- **`calculateOrderAmount` clamps at zero.** A 200 EGP coupon on a 50 EGP cart
  returned `-150`, and that figure chose the delivery tier and decided whether
  the free-delivery threshold was met.

Each characterization test flipped from pinning the wrong behaviour to asserting
the right one, in the same commit as the fix — so the diff shows both what
changed and what it used to do.

### 15.5 State

| | before P1 | now |
|---|---|---|
| Tests passing | 441 | **497** |
| Analyzer issues | 466 | 466 |
| Tier-1 money paths untested | 6 methods | 0 |

The 3 pre-existing failures are unchanged: `marks_render_test.dart` is entirely
commented out (no `main`), and two Spots draw-count assertions in files modified
before this work began.

**Next:** §5.1 (`AppConfig` and the 366 `configModel!` dereferences) is the
natural continuation — the payment-gate fix was one instance of it, and the
pattern is now established.

---

## 16. M5 was counting the wrong thing

The plan said "366 unguarded `configModel!` dereferences, each a crash on any
path where config has not loaded." That framing was wrong, and building
`AppConfig` with ~358 safe defaults would have made the codebase **less** safe.

### 16.1 Why the count was not the risk

Config is non-null on every screen, by construction:

- `_tryNavigate` requires `_configLoaded` (`splash_controller.dart:120`)
- `_configLoaded` is set **only** inside the `statusCode == 200` branch
- a failure shows `NoInternetScreen`; the app never routes onward
- **nothing** assigns `_configModel` back to null — zero occurrences repo-wide
- the cached-config path runs through the same handler, so the invariant holds
  on both

Four bypass paths were audited before relying on that:

| path | verdict |
|---|---|
| Notification cold start | routes through `getSplashRoute(body)` — gated |
| Deep links | cold links stash, replay from dashboard's first frame — post-gate |
| Other `offAllNamed` | all in-app returns to home — post-gate |
| Config refresh (3 callers) | same handler, assigns only on 200 — cannot partially overwrite |

`notification_screen.dart:31` null-checks config before refetching, which is
what a pre-gate caller correctly looks like.

So ~358 `?? default` fallbacks could never fire, and each would **hide** a
broken gate. A wrong-but-plausible default for a payment flag or a tax rate is
far worse than a crash that names the bug — the same reasoning that rejected
never-throw parse helpers for money fields in §12.4.

### 16.2 What shipped instead

**`configModel` is now non-null and throws by name:**

```dart
ConfigModel get configModel => _configModel ?? (throw StateError(
    'configModel read before the config load completed. …'));
ConfigModel? get configModelOrNull => _configModel;   // pre-gate callers
```

The 358 `!` became *warnings*, not errors — nothing broke. 339 were stripped
mechanically **by analyzer line/column**, not by text replace, so inner bangs on
genuinely-optional fields (`configModel.country!`) were preserved. The ~15
callers that legitimately handle absence — splash, guest bootstrap, onboarding,
`PriceConverter` — now read `configModelOrNull`.

`config_load_gate_test.dart` pins the invariant, including that a loaded config
survives session state changes and that a refresh replaces it wholesale.

### 16.3 The real bugs were the *second* bang

Not `configModel!` — the bang on optional fields underneath it.

**`socialLogin![0]` ran with no emptiness check at all**, and `socialLogin![1]`
assumed a second entry. A config whose `social_login` array was short or absent
took out the entire sign-in screen. Fixed with a length-checked accessor; an
unconfigured provider is simply not offered.

**`activePaymentMethodList!.length`** as an `itemCount` crashed the payment list
builder instead of showing no methods. 5 sites, now `?.length ?? 0`.

**`defaultLocation!`** was banged on the wrapper even though every call site
already supplied `?? fallback` for the coordinate. These are map-camera seeds —
display, not gating — so `?.` is correct. 6 files.

`moduleConfig!.module!.showRestaurantText!` was left alone. It picks a label
("restaurants" vs "stores"); a regex pass across 33 files produced 78 errors and
was reverted rather than patched. It belongs in a per-site change, not a sweep.

### 16.4 The check that proves it

`test/contract/sparse_config_test.dart` feeds the real `ConfigModel.fromJson` a
payload omitting `social_login`, `module_config`, `active_payment_method_list`,
`default_location` and `centralize_login_setup`, then asserts the app degrades
rather than throws — including the one-entry `social_login` array that used to
break the second lookup.

Its load-bearing assertion: **an unstated payment method is OFF.** Defaulting a
missing `cash_on_delivery` to true would offer a method the business never
enabled, and a customer could place an order the operation cannot collect on.

### 16.5 State

| | before | after |
|---|---|---|
| Tests passing | 497 | **504** |
| Analyzer issues | 466 | **466** |
| Analyzer errors | 0 | 0 |
| Redundant `configModel!` | 358 | 0 |

---

## 17. M6 — silent failures now explain themselves

50 bare `catch (_) {}` blocks. The problem was never that they were silent; it
was that a considered silence and an oversight looked identical. The codebase
already carried the receipt for that, in `location_controller.dart`:

> *"Never swallow silently — a bare empty catch here hid a hanging zone lookup
> for a long time."*

### 17.1 `swallow(reason, e, s, [report])`

`lib/util/swallow.dart`. Debug prints; release is silent unless `report` is
set, which records a **non-fatal** in Crashlytics — visible in the dashboard,
invisible to the user.

The API forces the decision to be written down. Three tiers:

| form | when |
|---|---|
| `swallow(reason, e, s)` | the failure genuinely does not matter — cosmetic fallback, cleanup of something already unreachable |
| `swallow(reason, e, s, true)` | flow continues, but you want to know how often it happens |
| neither | the user's next action depends on it — **surface it**, do not swallow |

### 17.2 What was converted

**39 sites → `swallow`**, 14 of them reporting. Judged by what the failure
costs, not by where it sits:

- **Reported**: ATT / Facebook SDK sync (silently degrades ad attribution —
  exactly what nobody notices), XP level-up acknowledgement (a server that
  keeps rejecting means level-ups celebrate forever), notification tap routing,
  tracking-map overlays, location permission probes, deep-link listener setup.
- **Not reported**: temp voice-recording cleanup, "no saved address yet" at
  `ApiClient` construction (the normal first-run state), podium name lookups,
  ETA formatting, tip-field parsing.

**11 left alone**: the 10 in `analytics_helper.dart`, whose class doc states
analytics must never break a user flow — and reporting an analytics failure
through analytics would loop — plus `swallow.dart`'s own doc example.

### 17.3 The guard

`silent-failure-guard` fails any new empty catch outside those two files.
Verified against a planted regression.

### 17.4 One self-inflicted lesson

The batch conversion replaced text inside the very comment quoted above,
producing 177 cascading errors across 10 files. Nothing was lost — the file was
intact and one restore fixed all 177 — but a script that rewrites code by
string match will eventually rewrite a comment *about* that code.

The `configModel` bang removal in §16.2 did not have this problem because it
worked from analyzer line/column positions rather than text. That is the better
tool for a sweep, and the rule worth keeping: **match on what the analyzer
says, not on what the source reads.**

### 17.5 State

| | before | after |
|---|---|---|
| Tests passing | 504 | **519** |
| Analyzer issues | 466 | **466** |
| Bare `catch (_) {}` | 50 | 0 (11 exempt by design) |

---

## 18. M8 — routes now refuse to open, rather than hoping the screen checks

### 18.1 The audit corrected two things in this plan

`wallet` and `checkout` **were** already guarded — the earlier count of "6 of 75"
was right but the named examples were not. The real exposure was different, and
worse.

Of the sensitive routes, six had **neither** a middleware nor an in-screen
`NotLoggedInScreen` fallback:

`order` · `orderTracking` · `refund` · `addAddress` · `editAddress` ·
`offlinePaymentScreen`

The rest were defended *by accident*: the screen happened to check. That is not
the same as the route refusing to open, and it fails silently the moment someone
writes a new screen without the check.

**16 routes guarded**, bringing the sensitive set to 22 of 22.

### 18.2 Two routes must stay open

`payment` and `orderSuccess` carry `guest_id` and `create_account`. They are the
tail of the guest-to-account conversion: the order is placed before the account
exists, and guarding them would bounce a paying customer to a login screen
mid-payment.

They are listed in the test as `deliberatelyOpen` **with reasons**, and a
separate assertion fails if either is quietly guarded later. An exclusion
without a reason is how a security control becomes folklore.

Guest checkout itself is off — `splash_controller.dart` forces
`guestCheckoutStatus = false`, and nothing reads the flag — so the rest of the
checkout chain does require an account.

### 18.3 The deep-link crash vector

Found while auditing the routes, and more serious than the missing guards:

```dart
id: int.parse(Get.parameters['id']!),       // payment route
```

**22 sites** parsed route parameters this way. Each throws twice over on a
malformed link — on the `!` when the key is absent, on the parse when the value
is not a number — and a throw inside a `GetPage` builder takes the app down *as
it opens*. With `app_links` live, that is a crash any stranger can trigger by
sending a URL.

All 22 now go through `_paramInt` / `_paramDouble` (and `OrNull` variants where
the original was conditional), which use `tryParse` and treat the literal string
`'null'` as absent. A junk link renders an empty screen; the server would reject
the id anyway.

This is M2's pattern arriving early, on the subset where the input is
externally controlled. The rest of M2 (260 sites, JSON boundary) still stands —
and per §12.4, those need the strict/lenient split, not a blanket fallback.

### 18.4 The guard

`route-guard` runs the test and greps for reintroduced parses. The test asserts
by **route name**, so removing a guard names the route in the failure — verified
by removing `refund`'s guard and watching it fail with `unguarded sensitive
routes: [refund]`.

### 18.5 State

| | before | after |
|---|---|---|
| Tests passing | 519 | **528** |
| Analyzer issues | 466 | **466** |
| Sensitive routes guarded | 6 | 22 / 22 |
| Throwing param parses | 22 | 0 |

---

## 19. M3 — 30,216 lines deleted

132 files, **13.7% of the codebase**. `lib/` went from 854 files / 221,156 lines
to 722 / 190,940.

### 19.1 The verification that mattered

The caveat on this from the start was that an import-graph walk cannot see
string-based references. Four checks before deleting:

1. **`part` / `export` directives** — only one pair (`cache_response.g.dart`),
   already handled by the tool.
2. **Symbol references from live code** — grepped every class, enum and mixin
   declared in a dead file for word-boundary matches in live files. **Six
   files came back flagged.**
3. **Reflection** — none. No `dart:mirrors`, no string-keyed widget factory.
4. **Non-Dart references** — nothing in yaml/json/xml but a docs-tool metadata
   cache.

### 19.2 All six flags were false alarms — for three different reasons

Worth recording, because the same shapes will recur:

- **Duplicate definitions.** `ModuleType` appeared to be used by 23 live files.
  It is defined **twice** — `common/models/module_model.dart` (live) and
  `helper/module_type.dart` (dead). Every one of those 23 used the live one.
  `CategoryShimmer` was the same story.
- **Matches inside comments.** `Distance` matched the word "Distance" in a
  doc comment. `PaymentButtonNew` and `ImagePickerWidget` matched code inside
  `/* */` blocks.
- **Transitively dead referrers.** `TextFieldShadow` was referenced five times
  — all from `receiver_view_widget.dart`, itself dead. This is the case a
  filename grep cannot see at all, and why the tool walks the graph.

### 19.3 What was in there

| feature | files |
|---|---|
| order | 39 |
| home | 21 |
| auth | 9 |
| common | 8 |
| helper | 6 |
| everything else | 49 |

The largest single file was `order/widgets/order_info_widget.dart` at 1,579
lines. `online_payment` went entirely — all 5 files, the whole feature
unreachable because its controller was never referenced.

**An entire dead auth sub-tree**: `sign_in_view`, `manual_login_widget`,
`otp_login_widget` and `social_login_widget`, which referenced each other and
nothing else. The live path is `unified_auth_screen` + `AuthFlowWidget`, which
does no social login at all.

That means the §16.3 `socialLogin![0]` hardening was applied to code that never
runs. The fix was still correct and cost nothing, but it is a reminder to check
reachability *before* hardening, not after. Had M3 run first, that work would
not have been done at all.

### 19.4 Result

| | before | after |
|---|---|---|
| Files in `lib/` | 854 | **722** |
| Lines in `lib/` | 221,156 | **190,940** |
| Analyzer issues | 466 | **384** |
| Analyzer errors | 0 | 0 |
| Tests passing | 528 | **528** |

Tests are identical — nothing depended on any of it. The analyzer dropped 82
issues that were lint noise in files nobody read.

Three duplicate definitions collapsed to one each (`ModuleType`,
`CategoryShimmer`, and `payment_button_new.dart` alongside `payment_button.dart`
— the "which widget is live?" ambiguity this metric exists to kill).

### 19.5 The ratchet is now zero

`dead-code-guard` budget dropped 132 → **0**. It does not go back up: a new
unreachable file is either dead on arrival or not wired up yet, and both are
worth failing on. Verified by planting an orphan and watching CI's check name it.

Files are backed up at `/tmp/claude-501/dead-backup/dead-files.tgz` for this
session, and the branch `dead-code-safety-point` marks the last commit before
the deletion.

---

## 20. M2 — the JSON boundary is closed

### 20.1 The count was smaller than the plan said, and better targeted

After the M3 deletion, 217 raw parses remained (not 260 — 43 were in dead
files). Of those, **26 sat directly on `json[...]`**: the client/server
contract, where a payload shape change becomes a crash.

Those 26 are now zero. The other ~183 are widget- and controller-level parses
of values already in memory, which are lower risk and ratcheted rather than
swept.

### 20.2 Two tiers, because one would have been worse than the bug

`lib/util/parse.dart`. The obvious helper — `asDouble(v) ?? 0` — is wrong for
money, and dangerously so: a missing price silently becoming `0` is a plausible
wrong number that flows into an order, a total and a payment. A crash at least
names the problem.

| tier | for | on bad input |
|---|---|---|
| `Parse.lenient*` | display values | returns a fallback |
| `Parse.strict*` | money, quantities, identifiers | returns **null** and reports to Crashlytics |
| `Parse.coordinate` | lat/lng | returns null, and range-checks |

The rule: *if a wrong value would change what the customer pays, receives, or
is shown as owing, it is strict.*

`Parse.coordinate` exists separately because **`0` is a valid latitude** — it is
in the Gulf of Guinea. A lenient fallback there puts a map pin in the Atlantic
and makes every distance nonsense.

Two details worth keeping: a fractional value is **not** silently truncated to
an int (`2.5` as a quantity returns null, not `2`), and `"12,50"` is **not**
reinterpreted as `12.50` — guessing a decimal separator would change a price.

### 20.3 What moved

- **`place_order_body_model.dart`** — the order contract. 13 sites:
  `order_amount`, `discount_amount`, `tax_amount`, `extra_packaging_amount`,
  `store_id`, `guest_id`, `partial_payment` all strict; `distance`, `cutlery`,
  `is_buy_now` lenient.
- **`order_details_model.dart:129`** — `quantity`, the line that threw on null
  and took down the whole order-details screen. Now strict.
- **`item_model.dart`** — `optionPrice` strict (it feeds the cart line);
  `veg`, `stock`, `min`, `max`, `offset` lenient.
- Pagination `offset`/`limit` across order, store, item, flash sale — lenient.

### 20.4 Coordinates: 105 parses, 8 protected

`double.parse(AddressHelper.getUserAddressFromSharedPref()!.latitude!)` carried
**two** failure modes on one line — the bang on an address that is null until
the location gate resolves one, and the parse on a server string that can be
null. Three such sites fixed: the store distance calculation and the tracking
screen's default camera position.

`getRestaurantDistance` now returns `double?` rather than a `-1` sentinel.
§14.1 records what the other sentinel cost — `calculateTotal` added it blindly
and knocked a pound off a displayed total. The type saying "unknown" is what
stops that recurring, and the compiler duly forced both call sites to handle it;
they now render `--` instead of `-1.00 km`.

Those two call sites were *also* parsing store coordinates unguarded, which is
how a single fix found two more.

The remaining ~100 coordinate parses are inside null-checked branches. They are
in the ratchet, not swept — a blanket regex over this shape is what produced 78
errors in §17.4.

### 20.5 State

| | before | after |
|---|---|---|
| Tests passing | 528 | **548** |
| Analyzer issues | 384 | **384** |
| Raw parses on `json[...]` | 26 | **0** |
| Raw parses elsewhere | 183 | 183 (ratcheted) |

---

## 21. i18n — the metric was measuring the wrong thing

§5.5 said: *"36 keys missing in `ar.json` … These render as **raw keys** to
Arabic users — half the market."* The `i18n-guard` ratchet enforced key-set
parity between `en.json` and `ar.json`.

Both were wrong. Nothing was broken.

### 21.1 Not one of the 36 is used

Every one of those keys — `maadi_exclusive`, `tap_to_scratch`, `see_live_rider`,
`order_items` and the rest — has **zero references in `lib/`**. They were not
lost in the M3 deletion either; a grep of the deleted-file archive finds none of
them. They were added to `en.json` and never wired up.

The same holds in reverse: all 24 `ar.json` orphans are equally unreferenced.

### 21.2 What actually matters, checked properly

Scanning every `.tr` literal in `lib/`:

```
1371 distinct .tr keys in lib/
  ar.json: 2680 keys, ok
  en.json: 2692 keys, ok
```

**Every key the code uses exists in both files.** No Arabic user has ever seen a
raw key from this. The real risk — a key used in code but absent from a language
file — is at zero, and was already at zero.

### 21.3 The guard now enforces the real property

`i18n-guard` no longer compares the two files to each other. It extracts every
`.tr` key from `lib/` and requires each to exist in **every** language file.

That is strictly stronger where it counts and strictly weaker where it does not:
a new key added to only one file now fails, while 1,300 inherited template keys
nobody references stop failing honest PRs. It also scales automatically to a
third language.

Verified by adding `'brand_new_untranslated_key'.tr` to a live file and watching
it be named in both languages.

### 21.4 Why the dead keys stay

~1,300 unused keys per file, and 295 KB parsed at launch, is real weight. It is
**not** safe to prune with a static scan, and the proof is small:

```dart
// date_converter.dart:190 — type is 'day' | 'hour' | 'minute'
return '$firstValue-$secondValue ${type.tr}';
```

`'day'` and `'minute'` never appear as literals anywhere. A static scan marks
them unused; deleting them breaks every delivery-time estimate in the app.

There are **five** such dynamic lookups (`instruction.tr`, `option.label.tr`,
`title.tr`, `option.tr`, `type.tr`). Pruning needs each one's possible values
resolved first. That is worth doing for the launch cost, but it is a deliberate
piece of work, not a sweep — and it is exactly the shape that produced 78 errors
in §17.4.

### 21.5 The general lesson

This is the third metric in this plan that counted the wrong thing:

- **M5** counted `configModel!` (358) when the risk was optional-field bangs (~60)
- **M2** counted all parses (260) when the risk was the JSON boundary (26)
- **i18n** counted key-set parity when the risk was used-key coverage (0)

The pattern: a grep-able proxy gets adopted as the metric, and the metric then
drives work that does not reduce risk. Each time, checking what the number
*meant* before acting on it saved days. Worth doing before the remaining
metrics — **M4's 527 unscoped `update()` is the next one to interrogate**, and
§12.7 already says to profile before trusting it.

---

## 22. M4 and M7 measured the wrong things — recorded, not quietly dropped

### 22.1 M4 is not a performance metric

The scoreboard set "526 unscoped `update()` → under 50" as the P4 target, at
three weeks.

**The Mi 9T baseline says not to do it.** Build averages **2.7–4.6ms against a
16.7ms budget** — already inside. Raster averages 2–3× build on every window
measured. Halving build time saves ~3ms on a frame losing 12–14ms to raster.

M4 stays on the board as a **maintainability** metric: 526 bare `update()`
calls is still a smell, and `places_controller` (18 bare / 30 scoped) is still
the reference for anyone touching one. But it is not what is costing customers
frames, and completing it "because it is on the list" would be weeks aimed at
the smaller half of the cost.

Revisit if a future measurement comes back build-bound.

### 22.2 M7 counted lines, not coverage

"Test LOC / prod LOC, 3.1% → 15%" is not a goal, it is a ratio that moves when
either number changes for unrelated reasons — deleting 30,216 lines of dead
code (§19) improved it without adding a single test.

What the metric was reaching for is done: **Tier-1 money paths are exhaustively
covered.** `PriceConverter` against 51 PHP-generated vectors,
`CheckoutCalculationHelper` including the six previously untested methods,
`OrderPayloadBuilder`, the cart mixing guards, `OrderSecurityHelper`.

Tests went 424 → 586 over this work, all of it aimed at seams that had burned
the project before.

### 22.3 M10 — instrumented

`BootStats` brackets the five serial awaits in `main()`: Firebase, `di.init`,
notifications, deep links, locale data. Every trace opens with
`Skipped 61 frames` and a ~1,014ms frame before anything is on screen, and
neither `FrameStats` (measures frames) nor `ApiStats` (measures network) can
see it.

**Deliberately not "optimised" yet.** The obvious move — defer
`initializeDateFormatting` past `runApp` — risks a `LocaleDataException` on
home, which uses `DateFormat` directly. Which of the five actually costs the
second is not knowable by reading the code; Firebase alone can be 50ms or
600ms depending on whether Play Services is warm.

Measure, then parallelise by size. That is the discipline the rest of this
work established, and §13.1 is the fifth reminder of what skipping it costs.

### 22.4 M11 — context attached

Crashlytics was recording crashes anonymously: no flavor, no module, no
signed-in state. "3 users affected" that nobody can act on — a staging crash
and a production crash were indistinguishable, and so were a guest-path bug and
a signed-in one.

`CrashContext` attaches, as **custom keys** (grouped and filterable in the
console, unlike a log line):

- `flavor` and `backend` — once at boot
- `signed_in`, and the account id as the Crashlytics user identifier — on
  profile load, cleared on sign-out
- `module_type` and `module_id` — on every module change

No personal data: the id is the account id the backend already issues, used to
count distinct affected users. Debug builds are excluded, so a developer's
crashes stay out of the dashboard the release metric is read from.

**Still outstanding, and it is a console setting rather than code:** a velocity
alert on crash-free sessions below 99.5%.
