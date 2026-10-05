---
target: pick map screen
total_score: 14
max_score: 40
na_heuristics: 
p0_count: 2
p1_count: 3
timestamp: 2026-09-22T07-28-51Z
slug: lib-features-location-screens-pick-map-screen-dart
---
Method: dual-agent (A: design review · B: detector + measured evidence)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 2/4 | `inZone` recomputed every pan (location_controller.dart:967), rendered nowhere. Pan replaces pin with spinner (:214). |
| 2 | Match System / Real World | 1/4 | Plus Code `X755+8JM` is the loudest text. Geocode failure shows untranslated `'Unknown Location Found'`. |
| 3 | User Control and Freedom | 1/4 | No visible back. Comment at :219 claims buttons that don't exist. 10 of 11 entry points dismissible; only location_gate_helper.dart:135 is mandatory. |
| 4 | Consistency and Standards | 2/4 | :385 raw `.tr.toUpperCase()` bypasses `displayCaps()` (121 call sites). Six TextStyles lack fontFamily vs 1203-call-site house pattern. |
| 5 | Error Prevention | 1/4 | `hasPin` (:375) accepts any non-empty string -> sentinel enables button and is saved as address label. |
| 6 | Recognition Rather Than Recall | 2/4 | `Center` centers whole Column; true coordinate ~40px above the triangle tip. |
| 7 | Flexibility and Efficiency | 2/4 | cairo_location_search_widget.dart:53 hard-appends ', Cairo, Egypt'. No debounce: Places call per keystroke. |
| 8 | Aesthetic and Minimalist Design | 1/4 | :326 + :336-350 print the address twice, ~55% duplicated chars, no maxLines. |
| 9 | Error Recovery | 1/4 | No error state. Only in-screen error path (:473) unreachable — hasPin gates identical condition. |
| 10 | Help and Documentation | 1/4 | Can be first screen ever seen; explains nothing. |
| **Total** | | **14/40** | **Poor (35%)** |

## Design Specificity Verdict

Category-interchangeable. Strip the "W" and this is Talabat/Careem/Glovo or any Flutter map-picker tutorial. PRODUCT.md anti-reference "theming a competitor's layout" applies directly. Bottom card is the literal generic white delivery card; :326-350 is gray-on-white caption soup.

Deterministic scan: Impeccable detector DOES NOT SUPPORT DART — exit 0 / `[]` because .dart falls through an HTML-extension gate (detector/node/file-system.mjs:32). Control test proved binary works. All findings hand-derived. `flutter analyze lib/features/location/`: 2 issues (unused_element `_locationCheck` at :477, plus one unrelated info).

Browser overlays: impossible. Mobile-only Flutter, no DOM, no dev server.

### Correction: mint direction is contested
Assessment A recommended large mint fills citing PRODUCT.md mint-dominance. light_theme.dart:25-29 states the opposite ("Mint means 'press this'. Nothing else... it used to be the brand wash, which is why the eye could not use colour to triage this screen"), committed 2026-09-20 — SIX DAYS AFTER the PRODUCT.md mint-dominance decision (2026-09-14). Code carries newer intent. Mint fills excluded from recommendations pending user decision.

### Correction: contrast on the screen proper passes
Independently computed, confirmed by B: "Deliver Here" mint-on-teal 6.44:1; bold address 17.40:1; sub-address 6.19:1. All pass AA. A's "low-contrast whisper" claim is wrong.

## What's Working
1. Controller concurrency model: `_positionRequestId` fencing, refcounted loading, `_suppressIdleCount`, finally-block `_endLoading` discipline.
2. Out-of-zone product decision correct and documented at :366-374, :380-384.
3. `isMandatory`/`PopScope` clean minimal gate; `offAllNamed` validates the locked case.

## Priority Issues

**[P0] Address block says one thing six times, with a machine code as headline**
Plus Code reads as an error code; duplicate line registers as a bug at peak-trust moment; no maxLines pushes CTA toward bottom edge.
Fix: split once, render disjoint (headline = first segment maxLines:1; sub = next two, maxLines:2 ellipsis); regex-drop leading Plus Code.
Command: /impeccable clarify

**[P0] `'Unknown Location Found'` is saveable, shippable, untranslated**
Non-empty sentinel enables the button; saved as permanent address label in English in an Arabic UI.
Fix: exclude from hasPin; coral retry row; keys in BOTH en.json and ar.json.
Command: /impeccable harden

**[P1] No visible way out on 10 of 11 entry points**
Comment promises back/close; Column has one child. MenuDrawer constructed at :91 with no opener.
Fix: 48x48 back button in top SafeArea if !isMandatory; delete endDrawer; reassurance line in mandatory mode.
Command: /impeccable harden

**[P1] Zone status computed every frame, shown never**
Out-of-zone user confirms, browses, builds cart, refused at add-to-cart. Screen knew at pan time.
Fix: amber chip when !inZone && !loading. `out_of_zone_pill` ALREADY EXISTS en.json:2282 / ar.json:2265.
Command: /impeccable harden

**[P1] Two real contrast failures, outside expected pairs**
Search hint + clear icon grey.shade400 = 1.88:1 (fails AA and 3:1 non-text floor). Disabled CTA label 3.96:1 — and disabled is the screen's INITIAL state.
Fix: inkMuted for hint; darken disabled label.
Command: /impeccable audit

**[P2] Typeface, tokens, one live RTL bug**
Six user-visible strings render in platform default font, not Thmanyah Sans (no fontFamily). :251 hardcodes `right:` fighting direction-aware CrossAxisAlignment.end at :246 — mis-insets in Arabic. Prediction rows ~42pt vs 48pt floor.
Fix: waddy*.copyWith; EdgeInsetsDirectional.only(end:); pad prediction row.
Command: /impeccable polish

## Persona Red Flags
- **Nadia, 24, first-timer, mandatory gate:** map of Cairo, no title, no back, no explanation, biggest text is `X755+8JM`. First impression is a trap with a plus-code in it.
- **Ahmed, 31, Arabic:** my-location button stays physically right (:251). BiDi can truncate the two address lines inconsistently. ar.json:423 renders search_location as "موقع البحث" (noun phrase, "the search's location") where imperative "ابحث عن موقع" belongs.
- **Hala, 38, larger OS font:** global textScaler pin ALREADY REMOVED (memory note stale) — screen fully exposed: unbounded Texts, fixed 56px button, 250px dropdown. Overflow unverified, not asserted.
- **Sam, screen reader:** ZERO Semantics/semanticLabel/tooltip in either file. Unlabeled pin image, unlabeled icon-only button, silent loading. Only CustomButton correct.

## Minor Observations
- Dead cluster: `_locationCheck()`; write-only `locationAlreadyAllow` making `_checkAlreadyLocationEnable()` a no-op (public, so analyzer misses it); unreachable `Get.isDarkMode` branch :143-146 (no darkTheme registered anywhere); three ghost comments; unreachable else :472; surviving `pickAddress!` bang :396 in the method documented as fixing that crash class.
- `Dimensions.pickMapIconSize = 100.0` named for this screen, used by nothing, while screen hardcodes 60/50.
- Dark-mode inversion failures latent, not live — unreachable because dark mode isn't registered.
- minMaxZoomPreference caps 16 but setLocation animates to 17; 16 too far out for adjacent Cairo buildings.
- No search debounce.
- CairoLocationSearchWidget bakes a city into a country-wide app's widget name.

## Questions to Consider
1. Why is the biggest text a Plus Code the user cannot act on?
2. If the triangle tip isn't the coordinate, what is it for — and isn't it lying?
3. Five flags drive navigation and zero visual difference. Should cold-start gate and Add Address look identical?
4. Why does confirming replace the CTA label with "Loading..."?
