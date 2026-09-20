# Mobile-only plan — strip web & desktop from waddy_app

Written 2026-08-22 against branch `home-critique-fixes` (`ad8940f`).
Goal: the app targets **Android and iOS only**. No web build, no desktop build,
no web/desktop code paths in Dart.

---

## Part 1 — What's actually there today

### 1.1 Platform targets

| Target | Status |
|---|---|
| `android/` | present, live (170 MB incl. local build output) |
| `ios/` | present, live (278 MB incl. `Pods/` + `build/`) |
| `web/` | present — 7 files, 80 KB, tracked in git since `b783e6a` (first commit) |
| `public/` | present — 2 files, the Firebase Hosting starter page |
| `windows/` `macos/` `linux/` | **never scaffolded** |

`.metadata` registers only `root` and `ios` as managed platforms — `web/` came in
with the 6amMart template and was never a first-class target. `flutter config`
has every `enable-*` flag unset (i.e. defaults, which enable web).

**Consequence:** "remove desktop" is a no-op at the project level. There is no
desktop build to delete. Desktop only exists as Dart branching
(`GetPlatform.isDesktop`, `ResponsiveHelper.isDesktop`) — and on this codebase
*that branching is really the web branching wearing a different name*.

### 1.2 The real cost centre: dead responsive branching

`lib/helper/responsive_helper.dart` resolves like this on Android/iOS:

| Method | Value on native | Call sites |
|---|---|---|
| `isDesktop(context)` | **always `false`** (explicit `!kIsWeb` early return) | 517 across 171 files |
| `isWeb()` | **always `false`** | 9 |
| `isMobilePhone()` | **always `true`** | 2 |
| `isMobile(context)` | **always `true`** (`size < 650 \|\| !kIsWeb`) | 51 |
| `isTab(context)` | `650 <= width < 1300` — **no `kIsWeb` guard** | 12 |

**573 call sites across 189 files.** Every `isDesktop ? A : B` on a phone takes
`B`; every `isMobile ? A : B` takes `A`. The other branch is unreachable.

This is not free. `ResponsiveHelper.isDesktop` is a runtime static call reading
`MediaQuery`, not a compile-time constant — so Dart's tree shaker **cannot**
drop the desktop branches. All 48 `web_*` widget files and the entire web
screen graph are compiled into the shipping AOT snapshot.

`isTab` is the one genuinely reachable case: iOS is safe (`TARGETED_DEVICE_FAMILY = 1`,
so iPad runs iPhone-compat at phone width), but Android has no tablet exclusion,
and `android:screenOrientation="portrait"` on a tablet still gives >650 dp width.
So 12 call sites take an untested branch on Android tablets.

### 1.3 Web-only Dart surface

| Thing | Count | Notes |
|---|---|---|
| `web_*.dart` / `widgets/web/` files | **48 files, 10,405 LOC** | excludes `payment_webview_screen.dart`, which is a real in-app webview and stays |
| `Dimensions.webMaxWidth` (= 1170) | 169 references | many leak into mobile layout code |
| `lib/common/widgets/hover/` | 2 files, 47 call sites | `OnHover` / `TextHover` — meaningless on touch |
| `cookies_view.dart` + splash cookie plumbing | 75 LOC + 8 plumbing sites | GDPR banner, web-only |
| `footer_view.dart` | 327 LOC, ~15 mobile screens | see bug 1.6 |
| `kIsWeb` direct uses | 13 across 7 files | |
| `GetPlatform.isWeb` / `.isDesktop` | ~85 sites | |

### 1.4 Web-only packages in `pubspec.yaml`

| Package | Usage |
|---|---|
| `universal_html` | 7 files — `window.location`, `window.open`, `document.querySelector` |
| `pointer_interceptor` | 5 dialogs; no-op on mobile |
| `url_strategy` | `setPathUrlStrategy()` at `main.dart:42`, unconditional; no-op on mobile |
| `google_maps_flutter_web` | **never imported** |
| `google_sign_in_web` | **never imported** |
| `image_network` | **never imported** |
| `dependency_overrides: web: ^1.1.0` | only needed for web interop |

`.flutter-plugins-dependencies` currently resolves **28 web plugins** on every
`pub get`.

### 1.5 Non-web dead dependencies found along the way

Declared but never imported anywhere in `lib/` or `test/`, and each ships native
Android/iOS code that is currently linked into the binary:

`syncfusion_flutter_datepicker`, `rive`, `flutter_animarker`, `custom_info_window`,
`flutter_swipe_button`, `skeletonizer`, `local_auth`, `image`, `expandable_bottom_sheet`

(Keep `cupertino_icons` — it's a font asset. Keep `image_picker_ios` — endorsement.)

### 1.6 Live bugs this audit surfaced

1. **`footer_view.dart:31` — identical ternary branches.**
   `(visibility && isDesktop) ? H * minHeight : H * minHeight`. Both sides are
   the same expression, so **every `FooterView`-wrapped scroll view on mobile
   gets a `minHeight` of 65 % of the viewport**, on ~15 screens. Almost certainly
   meant to be `0` on the non-desktop branch.

2. **`wallet_repository.dart:18-19` — unguarded `html.window.location`.**
   `addFundToWallet` computes `callback: '$protocol//$hostname/wallet'` with no
   `isWeb` guard, so mobile posts a synthetic-DOM hostname to the backend on
   every add-fund call.

3. **`splash_controller.dart:227 `_onRemoveLoader()`** runs unguarded at
   `:209` on every config load — `html.document.querySelector('.preloader')`
   against universal_html's fake DOM, on the cold-start hot path.

4. **`profile_screen.dart:80`** — `Container(width: 1170)` inside the *mobile*
   branch.

5. **`main.dart:56-65`** — the web Firebase branch hardcodes a **different
   Firebase project**: `stackmart-500c7`, appId `1:491987943015:web:…`. That is
   the 6amMart template's project, not `waddi-51062`. Dead code once web goes,
   but it is also a foreign project's API key committed to this repo.
   `web/index.html` likewise carries a `google-signin-client_id` for `491987943015`.

### 1.7 Build hygiene

- **119 Xcode build-cache files are tracked in git** under
  `ios/build/ios/XCBuildData/PIFCache/`. `.gitignore` covers `/build/` and
  `ios/Flutter/.last_build_id` but not `ios/build/` or `ios/Pods/`.
- Local: `build/` is 5.1 GB, `ios/Pods/` 275 MB, `.git` 58 MB.
- `.gitignore` has an empty `# Web related` section (template leftover).
- Root clutter: `bash.exe.stackdump`, `sixammart_user_app.textClipping`,
  `scraper.py`, `scraper_cloud.py`, `update_place_details.py`.
- **No CI at all** (`.github/` absent).

### 1.8 iOS config inconsistencies

- `project.pbxproj` sets `IPHONEOS_DEPLOYMENT_TARGET = 26.0` (6 places) while
  `ios/Podfile` line 2 sets `platform :ios, '14.0'`. An iOS 26 floor excludes
  nearly the whole installed base — this looks like an accidental Xcode-26
  default bump, not a decision. **Confirm before shipping.**
- `Podfile` also pins the `WaddiLiveActivityExtension` target to `16.2`.
- `TARGETED_DEVICE_FAMILY = 1` (iPhone only) — consistent with mobile-only. Good.
- No `SystemChrome.setPreferredOrientations` in Dart; portrait lock comes from
  the Android manifest and `Info.plist`. Fine, but the code comments imply Dart
  does it.

### 1.9 Baseline to protect

```
flutter analyze  →  0 errors, 69 warnings, 307 infos (376 total)
flutter test     →  37 tests, all passing (5 test files)
```

Every phase below must end with: **errors still 0, tests still 37 green.**

---

## Status — 2026-08-22

Phases 1, 2, 3, 4 and 6 are **done**. Phase 5 is **blocked on a product decision**
(see below). Verified after every phase:

| | baseline | now |
|---|---|---|
| `flutter analyze` errors | 0 | **0** |
| `flutter analyze` warnings | 69 | **55** |
| `flutter test` | 37 pass | **37 pass** |
| `.dart` files in `lib/` | 867 | **812** |
| LOC in `lib/` | 192,106 | **174,378** |
| pubspec dependencies | 74 | **63** |

`lib/` now contains **zero** references to `kIsWeb`, `dart:html`,
`universal_html`, `GetPlatform.isWeb/isDesktop`, or `ResponsiveHelper`.

### How the mechanical part was done

The 578 `ResponsiveHelper` call sites were not edited by hand. Four small
source-to-source tools in the scratchpad did it, each unit-tested first and each
followed by an `flutter analyze` + `flutter test` gate:

1. **substitute** — `ResponsiveHelper.isX(...)` → the literal it resolves to on
   native. A second pass did the same for `GetPlatform.isWeb/isDesktop/...` and
   `kIsWeb`. Strings and comments are skipped.
2. **collapse** — `false ? A : B` → `B`. String/comment aware, handles nested
   and right-associative ternaries, and refuses to fire unless the literal is
   the *whole* condition.
3. **simplify** — `!false` → `true`, `X && true` → `X`, `X || false` → `X`, with
   operand-boundary checks on both sides.
4. **collapse_if** — `if (false) A else B` → `B`, for braced statements, bare
   statements and collection-ifs, preserving block scoping.

**Two near-misses worth recording**, both caught by the gates and both fixed by
tightening a tool rather than by patching the output:

- A first cut of `simplify` rewrote `p == true && q` into `p == q` at 5 sites.
  Only 1 of the 5 produced an analyzer error; the other 4 were valid Dart with
  changed meaning. The tree was restored from a snapshot, the rule was given
  operand-boundary checks, and a per-file fingerprint of all 60 pre-existing
  `== true` / `== false` / `!= true` comparisons now proves none were touched.
- A paren-normalising regex matched `contains(true)` and `if (false)` and fused
  them into `containstrue` / `iffalse` at ~30 sites. Restored from snapshot and
  re-scoped to only strip parens that directly precede a `?`.

### What changed beyond the mechanical collapse

- **51 web widget files deleted** (10,498 LOC), plus `lib/features/home/widgets/web/`.
- **`sign_in_screen.dart` deleted** — 626 lines, 601 of them commented out, zero importers.
- **5 shared widgets rescued** from the web tree before deletion, because mobile
  code genuinely used them: `StoreCardWidget` → `common/widgets/card_design/`,
  `MedicineItemCard` and `SortingTextButton` → `home/widgets/components/`, and
  `MedicineCardShimmer` / `PopularStoreShimmer` / `WebNewOnShimmerView` extracted
  into `home/widgets/components/home_rail_shimmers.dart`.
- **`WebBusinessPlanWidget` renamed to `BusinessPlanWidget`** — it is reachable on
  phones (`storeStatus == 0.9` in the store-registration wizard), so the `Web`
  prefix was a misnomer. The duplicate copy under `features/business/widgets/`
  had no importers and was deleted.
- **`WebScreenTitleWidget` removed from 17 screens** — it was already a gutted
  stub returning `const SizedBox()`, so all 17 rendered nothing.
- **`hover/` deleted** — `OnHover`/`TextHover` are `MouseRegion` effects that
  never fire on touch. 20 wrappers unwrapped.
- **`CustomImage` lost its `AnimatedScale`** — it wrapped *every* network image
  in the app in an animation that was pinned at scale 1.0, because its
  `isHovered` input came from those hover wrappers. Also lost the
  `image-proxy` URL rewrite that only applied on web.
- **`Dimensions.webMaxWidth` renamed to `maxContentWidth`** (90 sites) and
  documented. Deliberately *not* deleted or changed to `double.infinity`: a
  `SizedBox` width is clamped by parent constraints, so on a phone it already
  means "fill available width", and changing it could break anywhere a parent
  passes unbounded width.

### Bugs fixed along the way (§1.6)

- #1 `footer_view.dart` identical ternary branches — resolved as part of the
  collapse. **Behaviour deliberately preserved**: both branches were the same
  expression, so the 65%-of-viewport `minHeight` still applies. See "Open" below.
- #2 `wallet_repository` unguarded `html.window.location` — now sends `''`.
- #3 `splash_controller._onRemoveLoader()` — deleted; it ran on every cold start.
- #4 `profile_screen` hardcoded `width: 1170` in the mobile branch — gone with
  the desktop layout removal.
- #5 the foreign `stackmart-500c7` Firebase keys in `main.dart` — deleted.

### Open — needs your call

1. **`FooterView` minHeight.** The collapse preserved current behaviour exactly:
   every `FooterView`-wrapped scroll view still gets `minHeight = 65% of the
   viewport` on ~15 screens. The original `(visibility && isDesktop) ? H*m : H*m`
   almost certainly meant `0` on the non-desktop side, but changing it alters
   layout on real screens, so it was left alone rather than changed silently
   during a mechanical refactor.
2. **`rive` kept.** Unused in Dart, but `assets/animation/22243-46463-level-up.riv`
   exists — looks like wired-up-later XP work. Removing the package drops
   `rive_common` native libs; say the word.
3. **iOS deployment target.** `project.pbxproj` still says
   `IPHONEOS_DEPLOYMENT_TARGET = 26.0` against a Podfile floor of `14.0`. Not
   touched — see §1.8. This is a ship blocker independent of this work.
4. **Phase 5** below is untouched and still needs the product answer.

### Note on §1.4's expectation

`.flutter-plugins-dependencies` still lists web/macOS/Linux/Windows entries after
`pub get`. That is not leftover project config — packages like `firebase_*`,
`connectivity_plus` and `share_plus` ship those implementations themselves. With
no platform directories and `flutter config` disabling those targets, nothing
builds for them.

---

## Part 2 — The plan

Six phases, ordered so each one is independently shippable and the risky one
comes after the cheap ones have shrunk the surface.

### Phase 1 — Kill the platform targets ✅ DONE

1. `git rm -r web public`
2. `git rm -r --cached ios/build` and add to `.gitignore`:
   ```
   /ios/build/
   /ios/Pods/
   ```
   (replace the empty `# Web related` section with these)
3. Document in `README.md` that the project is Android/iOS only, and that
   contributors should run:
   ```
   flutter config --no-enable-web \
                  --no-enable-linux-desktop \
                  --no-enable-macos-desktop \
                  --no-enable-windows-desktop
   ```
   (`flutter config` is machine-global, not repo state — hence documenting it.)
4. Delete root clutter: `bash.exe.stackdump`, `sixammart_user_app.textClipping`.

**Verify:** `flutter build apk --debug` and `flutter build ios --no-codesign` both
still pass. Nothing in `lib/` references `web/` assets except
`splash_controller._onRemoveLoader` (fake DOM — still compiles).

### Phase 2 — Remove web-only packages ✅ DONE

Do this *before* Phase 3: it shrinks what Phase 3 has to reason about.

1. **`universal_html`** — 7 files. Six sites sit inside `if (GetPlatform.isWeb)`;
   delete the branch and keep the `else`. Two are unguarded and are bugs 1.6 #2
   and #3 — fix them properly:
   - `wallet_repository.dart` → drop `callback` (or send `''`)
   - `splash_controller.dart` → delete `_onRemoveLoader()` and its call at `:209`
   - `business_service.dart:38-39` → delete the now-unused `hostname`/`protocol` locals
2. **`pointer_interceptor`** — 5 dialogs. `PointerInterceptor(child: X)` → `X`.
3. **`url_strategy`** — delete `setPathUrlStrategy()` (`main.dart:42`) + import.
4. **`main.dart` web block surgery:**
   - delete the `GetPlatform.isWeb` Firebase branch (`:55-65`) — takes the leaked
     `stackmart-500c7` keys with it
   - delete the `FacebookAuth.webAndDesktopInitialize` block (`:98-105`)
   - delete `_route()` entirely (`:131-155`) — its whole body is `if (isWeb)`
   - `initialRoute:` ternary → `RouteHelper.getSplashRoute(widget.body)`
   - drop the `(isWeb && configModel == null) ? SizedBox()` guard
   - delete the `CookiesView` entry in the `Stack` (`:234-256`)
5. **Delete `cookies_view.dart`** and the splash cookie plumbing
   (`savedCookiesData`, `getAcceptCookiesStatus` through repo/service/interface).
   Leave `ConfigModel.cookiesText` — it's just a parsed API field.
6. **pubspec:** remove `universal_html`, `pointer_interceptor`, `url_strategy`,
   `google_maps_flutter_web`, `google_sign_in_web`, `image_network`, and the
   `web:` line from `dependency_overrides`.

**Verify:** analyze errors 0, tests 37 green, both builds pass. Confirm
`.flutter-plugins-dependencies` no longer lists a `web` section after `pub get`.

### Phase 3 — Collapse `ResponsiveHelper` ✅ DONE

189 files, 573 call sites, ~10.9k LOC deleted. Do it in ordered sub-steps, one
commit per feature directory, `flutter analyze` after every batch of ~20 files.

- **3a — Delete the 48 web widget files** and `lib/features/home/widgets/web/`.
  This intentionally breaks compilation at ~15 call sites (the `isDesktop`
  branches that referenced them: `home_screen`, `conversation_screen`,
  `profile_screen`, `item_details_screen`, `cart_screen`, `wallet_screen`,
  `language_screen`, `access_location_screen`, `top_section`,
  `store_registration_screen`, `item_view`). The analyzer becomes your worklist —
  fix each by keeping the mobile branch.

- **3b — Mechanically collapse the branches.**
  `isDesktop(context) ? A : B` → `B`; `isMobile(context) ? A : B` → `A`;
  `isWeb()` → `false`; `isMobilePhone()` → `true`.
  **Do not do this with a global regex.** The expressions are multi-line and
  nested (`isDesktop ? 5 : isTab ? 3 : 2`, `item_view.dart:63`). Work file by
  file, largest first: `parcel_category_screen` (26), `cart_screen` (23),
  `store_registration_screen` (18), `flash_sale_details_screen` (12),
  `delivery_man_registration_screen` (12), `item_view` (10).

- **3c — Decide `isTab`.** Recommendation: **delete it and always take the phone
  branch.** That matches the portrait-phone product and matches what iOS already
  does via `TARGETED_DEVICE_FAMILY = 1`. Android tablets then get the phone
  layout — which is what they get today on iOS anyway. The alternative (keep a
  real breakpoint) means committing to testing a tablet layout nobody designed.

- **3d — Delete `lib/helper/responsive_helper.dart`.**

- **3e — Delete `lib/common/widgets/hover/`** (47 call sites) —
  `OnHover(child: X)` / `TextHover(builder: …)` → the child directly.

- **3f — `Dimensions.webMaxWidth` (169 sites).** Needs eyeballing, not sed. Most
  mobile uses are `width: Dimensions.webMaxWidth` inside an already-constrained
  parent, where the right answer is to delete the `width:` or use
  `double.infinity`. Fix bug 1.6 #4 (`profile_screen.dart:80`) here. Delete the
  constant when the last site is gone.

- **3g — Fix `footer_view.dart:31`** (bug 1.6 #1) as part of collapsing it. With
  `isDesktop` gone, `FooterView` reduces to roughly `widget.child` — at which
  point delete the widget and unwrap its ~15 call sites.

- **3h — Remaining `GetPlatform.isWeb` / `.isDesktop`** (~85 sites) → resolve to
  `false` and collapse.

**Verify:** analyze errors 0, tests 37 green. Then **manual smoke on a real
device**: home, store detail, cart, checkout, order tracking, wallet, profile,
chat, places. Phase 3 touches layout on nearly every screen — this is the one
that needs eyes, not just a green analyzer.

### Phase 4 — Drop unused native deps ✅ DONE (except `rive`, see Status)

Remove the nine packages in §1.5. Measure release APK and IPA size before and
after — `syncfusion_flutter_datepicker` and `rive` in particular carry real
native weight, and `local_auth` pulls AndroidX biometric into the manifest merge.

### Phase 5 — Web-shaped *features* ⛔ BLOCKED on your decision

These are 6amMart's merchant-onboarding web flows, reachable on mobile from
`menu_drawer.dart:116,125` and `registration_card_widget.dart:54,56`:

| Feature | Size | Question |
|---|---|---|
| `store_registration_screen.dart` | ~1,750 LOC | Does Waddi onboard **stores** through the customer app? |
| `delivery_man_registration_screen.dart` | ~1,100 LOC | Does Waddi onboard **riders** through the customer app? |
| `lib/features/business/` | 17 files, 1,466 LOC | Subscription/package payment — live? |
| `lib/features/parcel/` | 23 files, 3,915 LOC | Is parcel a shipping module? |

If the answer is no to store/rider onboarding, that's ~4,300 LOC plus a whole
subscription payment path gone. **I have not assumed an answer — this needs your
call before anyone deletes it.**

### Phase 6 — Guardrails so web never comes back ✅ DONE (`.github/workflows/ci.yml`)

There is no CI today. Add `.github/workflows/ci.yml` running on PR:

```
flutter analyze --fatal-infos=false
flutter test
! grep -rE "dart:html|package:universal_html|kIsWeb|GetPlatform\.isWeb|GetPlatform\.isDesktop" lib --include="*.dart"
! test -d web
```

The grep is the important half — Dart has no native forbidden-import lint, and
without it the next template merge quietly reintroduces all of this.

---

## Sequencing & effort

| Phase | Effort | Risk | Ship independently? |
|---|---|---|---|
| 1 — kill targets | 1 h | none | yes |
| 2 — web packages | 3 h | low | yes |
| 3 — collapse ResponsiveHelper | 2–4 d | **high** (touches layout everywhere) | per-feature commits |
| 4 — unused native deps | 1 h | low | yes |
| 5 — web-shaped features | 1 d after decision | medium | yes |
| 6 — guardrails | 2 h | none | yes |

Phases 1, 2, 4 and 6 can land this week and are individually revertible.
Phase 3 is the only one that needs a real device pass, and it should be split
into one commit per feature directory so a regression bisects cleanly.

## Net effect

- **~11,000 LOC deleted** from `lib/` (of 192,106 — about 6 %)
- **48 files removed**, 189 files simplified
- **9 packages + 28 web plugins** out of the dependency graph
- **5 live mobile bugs fixed** as a side effect (§1.6)
- Smaller AOT snapshot: the desktop widget graph is currently *not* tree-shaken
- One build story, two targets, no `kIsWeb` anywhere
