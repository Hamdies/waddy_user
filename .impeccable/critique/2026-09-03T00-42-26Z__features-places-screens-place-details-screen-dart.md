---
target: lib/features/places/screens/place_details_screen.dart
total_score: 22
max_score: 40
na_heuristics: 
p0_count: 1
p1_count: 4
timestamp: 2026-09-03T00-42-26Z
slug: features-places-screens-place-details-screen-dart
---
Method: dual-agent (A: design review · B: detector + static analysis, isolated & parallel). No browser step — Flutter native target, no URL/live server/overlay. Bundled detector ran once: `[]`, exit 0 — it has no Dart grammar, so that means "not applicable", not "clean". Deterministic evidence is `flutter analyze` + mechanical greps.

## Design Health Score — 22/40 (Fair)

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 2 | `getVoteStatus` fetched at :55, read by nothing. Bar says "VOTE →" whether or not you voted here. Load-more spinner branch (:950) unreachable — controller sets `_isReviewsLoading` only when `offset == 1 \|\| reload`. |
| 2 | Match System / Real World | 3 | "DROP THE FIRST REVIEW" opens the *vote* sheet; "Website" shows an Instagram URL; `isOpenNow`/`openingHours` parsed and never rendered. |
| 3 | User Control and Freedom | 2 | Back lives only in the hero and scrolls away; `_DetailsSkeleton` has no back button. No pull-to-refresh, no share. |
| 4 | Consistency and Standards | 2 | `_socialRow` called with two opposite label/sub conventions; file leaves its own design system in 12 places. |
| 5 | Error Prevention | 2 | "Get directions" renders unconditionally (:619) then fails to a snackbar on null lat/lng. `launchUrl` bool discarded (:73). No in-flight guard on load-more. |
| 6 | Recognition Rather Than Recall | 3 | Address rendered twice, rank up to three times in three visual languages. |
| 7 | Flexibility and Efficiency | 2 | Vote status fetched at load AND again behind a non-dismissible modal spinner. Route always cold-fetches. |
| 8 | Aesthetic and Minimalist Design | 3 | 10 font sizes, 28 hand-rolled TextStyles, off-grid spacing (2,3,5,10,11,13,18,26,30). |
| 9 | Error Recovery | 1 | `_errorScaffold` reports "NO INTERNET CONNECTION" for every failure, and flashes for one frame on every cold entry. |
| 10 | Help and Documentation | 2 | One-vote-per-week rule never stated; discovered via a 409 switch-vote dialog. |
| **Total** | | **22/40** | **Fair — authored hero on an assembled body** |

## Design Specificity Verdict

**Hero: authored. Body: a well-drawn neubrutalist template that happens to be teal.**

Hero is unmistakably Waddy Spots: three-stop teal scrim (`0xF210312E → 0x6610312E → 0x1A10312E`), title at 32pt/`height: 0.92`/`letterSpacing: -1`, `right: 82` reserving the badge footprint, badge breaking the bottom edge at `bottom: -22` under `Clip.none`.

Below the fold it leaves its own system:

| Spots system says | This screen does |
|---|---|
| `radiusLg = 10` ("the maximum") | `radiusDefault` (12) everywhere; `radiusLarge` (16) on logo; `radiusExtraLarge` (24) on the pill = 2.4× max |
| shadows "hard, zero-blur" | `blurRadius: 15` on the logo badge |
| `Spots.gutter = 16` | literal `18` in `_section`, `_quickStatRow`, `_photosSection`, `_hero` |
| `Spots.borderThick = 3` | 9× literal `width: 3`; 8× `2.5` vs `borderThin = 2` |
| `SpotsPressable` (9 sibling files) | private `_PressableButton` duplicate |
| `Spots.display()` / `Spots.kicker()` | 28 hand-rolled TextStyles, 10 sizes |
| `SpotsGlyph` (7 marks) | six Material icons |
| tokens only | `_paper2 = Color(0xFFF4F3EE)` invented for this file |

**`Spots.*` spacing tokens appear ONLY inside `_DetailsSkeleton`.** Lines 1–1310 import `Spots` for colour aliases and nothing else.

`_PressableButton` doesn't do what its doc comment claims: the hard shadow is on the child's own decoration, and `AnimatedContainer(transform:)` moves box and shadow together — the neubrutalist collapse never happens. `SpotsPressable` puts the shadow on a separate `Positioned.fill` plate and honours `disableAnimations`; this one does neither.

**Deterministic scan:** detector `[]` (no Dart support). `flutter analyze` → 1 warning: `_map` (:836) unreferenced — 55 dead lines carrying the only `GoogleMap`, so `google_maps_flutter` is live only through dead code. Greps: ~118 raw-literal sites, zero `EdgeInsetsDirectional`/`PositionedDirectional`, zero `Semantics`/`tooltip`, one inline `Color(0x73104130)` matching no token (`Spots.ink` is `10312E` — digits transposed). i18n keys clean: all 33 `.tr` keys present in en.json and ar.json.

## Overall Impression

The first 0.4s are excellent, then the screen apologises five times. The screenshots show the state that matters most — a place with nothing yet — and the design spends its heaviest containers saying nothing three times: `0`, `—`, `—`, the third reading "— IN CAFES". Then three broken-image tiles in lavender-gray, a colour from no part of the Waddy palette — the PRODUCT.md anti-reference rendered three times and clipped off the right edge.

**Biggest opportunity: an empty place is not a failure state, it's an unclaimed one.** Zero votes currently reads as "this place isn't really in the app yet."

## What's Working

1. `_DetailsSkeleton` is a real loading state mirroring hero → stat row → two sections, routed through `SpotsSkeleton` which goes static under `disableAnimations`. Also the only correctly-tokenised code in the file.
2. Vote is centralised: `_onVoteTap` → `openVoteSheet`, the same entry the leaderboard and mission CTAs use. One verb, one behaviour, one guest gate.
3. Hero typography and scrim are genuinely tuned — teal-tinted alpha stops, real optical tracking, badge footprint reserved in the text inset.
4. `GuestGate` soft wall on favourite and vote keeps the guest in place.

## Priority Issues

### [P0] "DROP THE FIRST REVIEW" silently spends the user's weekly vote
- **What**: :912 `onCta: () => _onVoteTap(placeId)`. The empty-reviews CTA opens `PlaceVoteSheet`, which submits a *vote* under the one-per-week cap. A user who voted elsewhere gets `showVoteSwitchDialog` from a button labelled "review".
- **Why it matters**: the vote is the scarcest thing in the product. Spending it from a mislabeled affordance teaches users Spots buttons don't mean what they say.
- **Fix**: rename to a vote-framed key (`vote_and_leave_a_review`), render the weekly cap as a caption. Better: pass `voteStatus` down so the switch framing appears before the tap.
- **Command**: `/impeccable clarify`

### [P1] The vote bar never reflects that you voted
- **What**: `_voteBar` reads only `votesCount`/`rank`. `voteStatus` fetched at :55, referenced nowhere else. After voting the bar still reads "VOTE →". Tapping VOTE puts the user behind a `barrierDismissible: false` spinner re-fetching what the screen already has.
- **Why it matters**: in Operate mode the confirmation IS the completion. The snackbar is the only evidence and it disappears.
- **Fix**: read `c.voteStatus` in `_voteBar`; "VOTED ✓ · EDIT" + "YOUR VOTE IS HERE" when the vote is here; "SWITCH VOTE" when elsewhere. Drop or de-block the pre-sheet re-fetch.
- **Command**: `/impeccable harden`

### [P1] The empty place reads as abandoned
- **What**: three heavy bordered boxes reading `0`, `—`, `—` as the second element. `_photosSection` handles an empty gallery but not gallery entries whose images fail — the state actually shipping. `'—'` as the ABOUT fallback under a heavy header. `SafeArea(top: false)` is right for the hero and wrong after it, so scrolled content runs under the iOS clock with no scrim and no back button.
- **Why it matters**: the highest-value arrival gets the least persuasive screen; nothing says what Spots is or that voting is weekly.
- **Fix**: collapse the stat row when all values are null; replace with votes-needed-to-enter-top-3-this-week. Waddy-palette fallback tile in `CustomImage`; hide the strip when every entry fails. Hide ABOUT rather than printing an em-dash. Collapsing top bar keeping back reachable.
- **Command**: `/impeccable onboard`

### [P1] The Arabic build and the accessible build are both broken
- **What**: `displayCaps()` (styles.dart:53) exists to no-op under Arabic — used twice (one inside dead `_map`) while raw `.toUpperCase()` is called on translated strings 12×. `displayTracking()` used zero times against 8 raw `letterSpacing` values on display text. Six strings never reach `.tr`: rank pill `'CURRENTLY #n · HELD n WEEKS'` / `'RANK #n'`, `'CITIZEN_id'`, all three `_timeAgo` outputs — while `'currently'` and `'rank'` are localised keys used elsewhere in the same file. Zero `EdgeInsetsDirectional`; two literal `Text('→')`; 8 hard shadows offset down-right; `_rankPill` `Positioned(left: 14)` lands under the bookmark in RTL. Accessibility: zero `Semantics`/`tooltip`, two icon-only 38×38 buttons vs `Dimensions.minTapTarget = 48`, and `RichText` (:483) defaults to `TextScaler.noScaling` so stat values ignore system text size while their labels scale. `main.dart` no longer pins textScaler, so this is live.
- **Why it matters**: the app ships Arabic and ar.json is complete. Sibling Spots files label their icon buttons correctly; this file is the regression.
- **Fix**: route 12 `.toUpperCase()` through `displayCaps()`, 8 tracking values through `displayTracking()`; add the six keys; `Icon(Icons.arrow_forward)` for both arrows; `EdgeInsetsDirectional` throughout; `Text.rich` not `RichText`; `Semantics(button: true, label:)` on back/bookmark; size both hero nav buttons to 48.
- **Command**: `/impeccable harden`

### [P1] Every failure reports "no internet", and the error screen flashes on every cold open
- **What**: (a) `_errorScaffold` hardcodes `wifi_off` + `no_internet_connection` for deleted place, 500, and bad id alike. (b) `_loadData` runs in `addPostFrameCallback`, so frame 1 has `place == null` AND `isDetailsLoading == false` → error scaffold for one frame on every cold entry. (c) `route_helper.dart:1299` `int.parse(Get.parameters['id'] ?? '0')` throws `FormatException` in the route builder on a malformed share link.
- **Why it matters**: the share-link visitor is the growth path; the first thing they can see is a wrong error or a crash.
- **Fix**: nullable error (status + message) on `getPlaceDetails`, branch on 404 vs network vs generic; call `_loadData()` directly in `initState` or gate on `_hasAttemptedLoad`; `int.tryParse(…) ?? 0`.
- **Command**: `/impeccable harden`

## Persona Red Flags

**Rania, first-timer from a WhatsApp share link** — malformed `?id=` crashes the route builder; a valid link still flashes "NO INTERNET CONNECTION"; she lands on `0 / — / —` with three broken tiles; `isOpenNow`/`openingHours` are parsed and rendered nowhere so she can't tell if it's open; **there is no share button on the screen she arrived at by share** — the loop doesn't close.

**Omar, repeat voter who already voted this week** — the bar reads "VOTE →" whether his vote is here, elsewhere, or nowhere; tapping puts him behind a non-dismissible spinner re-fetching line 55's data; the switch-vote dialog arrives with no forewarning; `GetBuilder` has no `id`, so every unrelated controller `update()` rebuilds the whole screen including the hero image tree.

**Hala, VoiceOver at 2× text** — back and bookmark are bare `Icon`s in `InkWell` with no label; both 38×38 vs the app's own 48; `RichText` stat values ignore her text size while 9pt labels scale and "IN CAFES" ellipsizes to "IN C…"; at 2× the 32pt title grows upward from `Positioned(bottom: 18)` inside a `Clip.none` Stack and paints over the nav buttons; trophy grid `childAspectRatio: 1.7` overflows above ~2.1×; `'4 ★ · 2d ago'` reads as "four black star middle dot two d ago".

**Ahmed, Arabic UI** — English rank pill, English timestamps, `CITIZEN_` fallback; two arrows pointing right in RTL; 8 hard shadows falling right; rank pill pinned physical-left lands under the bookmark; pin glyph's 4pt gap uses physical `right` so it lands against the screen edge and the glyph butts the address text.

## Minor Observations

- **Find Them inverts its hierarchy**: generic category word gets 14pt display w900 ink; the actionable value (phone, address, URL) gets 11pt gray. Backwards for 3 of 4 rows, and Instagram uses the opposite convention from the other three.
- `_instagramLabel` splits a URL on `/` and takes the last segment → `https://instagram.com/1980.coffee/?hl=en` renders as `@?hl=en`.
- "Get directions" sub repeats the hero's address. Show distance instead.
- Delete `_map` (55 dead lines) and the `google_maps_flutter` import with it.
- `Widget _reviewCard(review, …)` is implicitly `dynamic` — the only reason the two `as String` casts exist. `PlaceReview` is fully typed.
- Pagination `(reviews.length ~/ 15) + 1` hardcodes the backend `paginate(15)` default; correct only while every page is full. One partial page re-requests a loaded page, which the controller appends again without de-duping by id. No in-flight guard either.
- Logo badge has a rounded border and no `clipBehavior`, so `CustomImage` overpaints the corners. Gallery tiles and review avatars both set `Clip.hardEdge`.
- Skeleton→content jump: skeleton hero `260 + topPad` vs real `290 + topPad`; skeleton has no `bottomNavigationBar`; skeleton uses `Spots.gutter` (16) vs content's 18.
- `await launchUrl(...)` bool discarded; most failures return `false` rather than throwing.
- `tel:${place.phone}` unsanitised — spaces/parens mangle the URI.
- No report affordance on reviews despite `reportsCount` parsed and `reportReview` on the controller. App Store risk on a UGC surface.
- No pull-to-refresh on a screen whose headline number is push-notified live via `places_race_*`.
- `ImageVariants` exists; `Place.fromJson` doesn't parse `*_variants`. The full-bleed hero is the largest image in the app, fetched full size.
- `rank == 1` renders both "#1 / in Cafes" and "Category leader / Cafes" — two cards saying one thing, beside a stat box that already said it.

## Questions to Consider

1. If the stat row's three most prominent boxes are empty for every place not already winning, why is it the second thing on the screen? What if it showed votes-needed-to-enter-this-zone's-top-3-this-week — never null, always actionable, computable only by Spots?
2. What is this screen for — deciding, or voting? It's a directory listing with a vote bar bolted on. If it's a ballot, the case for this place should outrank the phone number. It shows the address twice and the argument zero times.
3. Why is Spots the only sub-product with a weekly cap and the only screen that never mentions it? What if the bar read "1 vote left this week" before the tap instead of "you already voted, move it?" after?
4. The hero was designed and the body was assembled. Nine sibling files use `Spots.card()`, `SpotsPressable`, `Spots.display()`, `Spots.gutter`, `SpotsGlyph`. What made this file the exception — and what stops the next screen from being one too?
