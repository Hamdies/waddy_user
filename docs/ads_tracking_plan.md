# Ads Tracking & Deep Linking Plan — Meta + TikTok

*Written 2026-08-01. Verified against the codebase and live server; supersedes all earlier drafts of this plan.*

## Implementation status (2026-08-01)

**Phases 0, 1, and 2 are FULLY IMPLEMENTED (app + backend).** No code work remains before TikTok (Phase 3).

Phase 2 backend (Conversions API, waddy_back): `app/Services/MetaConversionsService.php` sends `Purchase` to the app dataset with hashed phone/email (Egyptian 0x→20x normalization), `external_id`, `app_data.extinfo`, and `event_id = purchase_{order_id}`; skips events with nothing to match on; 5s timeout, failures logged, never on the order path (`app/Jobs/SendMetaPurchaseEvent` via `dispatchAfterResponse` after `DB::commit` in `PlaceNewOrder`). The app sends `X-Client-Platform` and `X-ATT` headers (api_client; TrackingHelper refreshes X-ATT after the prompt) and mirrors `_eventId` on the SDK purchase for dedup. **To activate: Admin panel → Business Settings → 3rd Party → Meta Ads Tracking** — paste the Dataset ID (Meta App ID, prefilled hint `380903914182154`) and the access token (Events Manager → dataset → Settings → Conversions API → Generate access token), toggle ON, Save. Stored in `business_settings` key `meta_capi`; `.env` (`META_CAPI_*`) remains a fallback for headless setups, and admin-panel values win. Verify dedup in Events Manager after the first orders; if Purchase double-counts, the `_eventId` param on the SDK side is the knob to investigate.

Phase 2 app-side (added same day): `app_tracking_transparency` package; `lib/helper/tracking_helper.dart` shows the ATT prompt ~1.2s after the dashboard's first frame (never gates anything, never before real content — Guideline 5.1.2), logs the answer as `att_prompt_answered`, and syncs the result into the FB SDK via `setAdvertiserTracking`. Info.plist: `NSUserTrackingUsageDescription` (English; Arabic needs Xcode variant groups later) + Meta's two SKAdNetwork IDs (`v9wttpbfk9`, `n38lu8286q`) so denied-ATT installs still attribute via SKAN postbacks.

Remaining before ads can go live:

1. **Play Console SHA-256** → replace `REPLACE_WITH_PLAY_APP_SIGNING_SHA256` in `waddy_back/public/.well-known/assetlinks.json` (Play Console → App integrity → App signing key certificate). Debug-keystore fingerprint is already the second entry for local App Links testing.
2. **Deploy waddy_back** so both `.well-known` files go live, and add the nginx block forcing JSON content-type for the extensionless AASA file:
   ```nginx
   location = /.well-known/apple-app-site-association {
       default_type application/json;
   }
   ```
3. **Enable Associated Domains capability** for `com.hamdiesolutions.waddi` in the Apple Developer portal / Xcode Signing & Capabilities (the entitlement is in the repo; the provisioning profile must allow it or signing fails).
4. **Dashboard work**: verify events in Meta Events Manager (App Ads Helper), link dataset to ad account, set AEM priority with Purchase on top.
5. **Store metadata**: Play Data Safety form + App Store privacy labels + privacy policy naming Meta.

What was implemented:
- `lib/helper/deep_link_helper.dart` — parser + stash; consumed by DashboardScreen first frame; warm links push directly once home has mounted; notification cold starts clear the stash; 5-min stash expiry.
- AndroidManifest: autoVerify App Links for waddyapp.com limited to `/store`, `/item`, `/category` prefixes + `waddy://` scheme. iOS: associated-domains entitlement (Runner + RunnerDebug) + `waddy` URL scheme; AASA restricts to the same paths.
- `flutter_facebook_auth` 6→7 (FBSDK 18.0.2, breaking change fixed: `accessToken.tokenString`, uniqueId from `userData['id']`), `facebook_app_events` 0.23.0, `app_links` 6.4.1; removed `facebook-android-sdk:latest.release` from app gradle (plugins pin their own).
- `AnalyticsHelper` fan-out (Firebase + Meta): `logCompleteRegistration` (registration + personal-info completion in AuthController), `logAddToCart` (CartController.addToCart), `logInitiateCheckout` (checkout initCall with cart total), `logPurchase` with EGP + order_id (OrderSuccessfulScreen, paid/COD-gated, session-deduped).

## Current state (verified)

| Piece | Status |
|---|---|
| Facebook SDK | Embedded via `flutter_facebook_auth: 6.2.0` (FBSDKCoreKit 17.0.3), App ID `380903914182154` on both platforms — **login only** |
| Meta App Events | ❌ Nothing. No `facebook_app_events`, no purchase/cart events reach Meta |
| ATT prompt (iOS) | ❌ No `NSUserTrackingUsageDescription` |
| SKAdNetwork IDs | ❌ Not in Info.plist |
| Firebase Analytics | ✅ `AnalyticsHelper` (`lib/helper/analytics_helper.dart`) logs funnel events; no commerce events |
| Deep linking | ❌ None. No `app_links` package, no App Links intent-filter, no associated-domains entitlement. GetX routes (`/store`, `/item-details`, `/category-item`) are ready mapping targets |
| TikTok | ❌ Nothing |

Verified facts that shape the plan:

- **Gates are controller-level, not route-level.** A deep link straight to `/store?id=X` cannot bypass zone/guest gating: `CartController` blocks out-of-zone add-to-cart (`cart_controller.dart:371`), checkout blocks placement, and the store screen renders browse-safe out-of-zone (suppresses delivery time/fee/min-order). No bypass exists.
- **But the store API needs a `zoneId` header** from the saved address (`api_client.dart:60`). Deep-link navigation before a usable address exists = broken landing. Hence the sequencing rule below.
- **`flutter_facebook_auth` does NOT expose `fetchDeferredAppLink`** (checked plugin source, 6.2.0 and 7.1.2). Deferred deep linking via Meta SDK = hand-written platform channels. Decision: skip it; AppsFlyer OneLink covers deferred DL for Meta *and* TikTok in the MMP phase.
- **waddyapp.com serving is clean**: valid HTTPS, no redirects, 404s fall through nginx `try_files` to Laravel. Files dropped in `waddy_back/public/.well-known/` will be served directly. Only caveat: `apple-app-site-association` is extensionless → needs an nginx `location` block (or Laravel route) forcing `Content-Type: application/json`.
- **`waddy://` scheme is free** — registered schemes are only login callbacks (https/tel/signinwithapple on Android; Google/fb/2× Firebase on iOS).

## How Meta attributes orders (why each phase exists)

The app (SDK events) and backend (Conversions API) send events like `Purchase {value, currency: EGP, event_id}` to the app's dataset in Events Manager. Campaign info is never sent by us — **Meta matches ad clicks to events on their side** and surfaces Purchases / Purchase Value / ROAS per campaign → adset → ad in Ads Manager. Campaign names never land in our DB (that's what an MMP adds later).

- **Android:** deterministic (GAID + Install Referrer). Full ad-level granularity, near real-time.
- **iOS with ATT consent** (~20–30%): deterministic, like Android.
- **iOS without consent:** SKAdNetwork/AdAttributionKit postbacks + Aggregated Event Measurement modeling. Campaign-level reliable, adset/ad-level partly modeled, 24–48h delay. CAPI narrows this gap.

With `Purchase` + value flowing, campaigns graduate: App Installs → **App Events optimization** (Meta finds people who *order*) → **Value Optimization** (Meta optimizes basket size, needs ~30+ purchases/week/adset). Also unlocks purchase-based custom audiences and value-based lookalikes.

**Cost note:** everything Meta-side is free — no surcharge for events, CAPI, or better tracking. CPMs on AEO/VO campaigns often look higher (narrower, higher-quality audience) but cost-per-purchase and ROAS improve; expect a learning-phase wobble when switching optimization goals. The only new recurring cost in this plan is the MMP subscription in Phase 3 (AppsFlyer free tier covers early volume).

---

## Phase 0 — Deep links (app + small backend) — DO NOW

**Sequencing rule (the core design): a deep link never navigates by itself. It is stashed as `pendingDeepLink` and consumed only after splash routing fully completes.**

1. Add `app_links`. Create `DeepLinkHelper`: parses `https://waddyapp.com/...` and `waddy://...` into GetX route pushes (`/store?id=`, `/item-details?id=`, `/category-item?id=`).
2. **Cold start:** stash the initial link, do nothing. `splash_route_helper.dart` runs untouched (auth check → returning-guest check → intro → `bootstrapGuest()` / location gate). At the single point it does `Get.offNamed(getInitialRoute(...))`, check the stash: land on **home first, then push the target** — guarantees zone context is loaded and back-stack lands on home.
3. **Warm start / foregrounded:** context exists → validate id, push directly.
4. **Bootstrap fails / parked at location gate:** stash survives, consumed when the gate resolves; dies with the session if abandoned.
5. **Bad path / dead store id:** clear stash, land home as if organic. A deep link must never be worse than no deep link.
6. Android: `https` intent-filter (`autoVerify`) + `assetlinks.json` (needs release keystore SHA-256).
7. iOS: `applinks:waddyapp.com` entitlement + `apple-app-site-association` (needs Apple Team ID).
8. Backend: drop both files in `waddy_back/public/.well-known/`; nginx location block for AASA content-type.
9. Register `waddy://` scheme as fallback.

**Effort:** ~2 days app + hours backend. Blocked on: release keystore SHA-256, Apple Team ID.

## Phase 1 — Meta event wiring (app) — DO NOW

10. Add `facebook_app_events` (oddbit). Must share the FBSDK major with `flutter_facebook_auth` — likely bump both to FBSDK 18 (`flutter_facebook_auth` 7.x). Verify single FBSDKCoreKit version in `Podfile.lock`.
11. Fan out through `AnalyticsHelper` (one call → Firebase + Meta, TikTok later):
    - `fb_mobile_complete_registration` — auth success (auth_bottom_sheet already logs here)
    - `fb_mobile_add_to_cart` — CartController
    - `fb_mobile_initiated_checkout` — checkout open
    - `logPurchase(value, 'EGP')` — order-success path; generate and persist an `event_id` per purchase for CAPI dedup later
12. Android needs no ATT — events + deterministic attribution work immediately. This alone unlocks AEO campaigns for Android traffic.
13. Store metadata (required as soon as events ship): Play Data Safety form (device IDs shared for advertising; FB SDK auto-merges `AD_ID` permission — declaration must match), App Store privacy labels ("Data Used to Track You"), privacy policy names Meta. Note: FBSDKCoreKit already auto-logs launch events today, so the label update is retroactively covering shipped behavior.

**Effort:** ~1–2 days + dashboard work (app registered in Business Manager, dataset linked to ad account, events verified with App Ads Helper, AEM priority with Purchase on top).

## Phase 2 — iOS attribution stack — HOLD until OS split justifies it

*Decision gate: check the platform breakdown in Firebase Analytics first. If iOS is a minor share of orders, park this phase.*

14. ATT prompt (`app_tracking_transparency`) + `NSUserTrackingUsageDescription`; show after first home screen, never gate or incentivize (Guideline 5.1.2). Pass result to FB SDK.
15. Meta SKAdNetwork IDs (`v9wttpbfk9.skadnetwork`, `n38lu8286q.skadnetwork`, …) in Info.plist.
16. Meta **Conversions API** from Laravel (`waddy_back`): POST `Purchase` on order placement with the same `event_id` as the app event (dedup) + hashed phone/email. Biggest signal-quality win — recovers the ATT-denied iOS majority.

**Effort:** ~1 day app + ~1 day backend.

## Phase 3 — TikTok + MMP — when TikTok app campaigns start

17. TikTok app-install campaigns effectively **require an MMP** for attribution (TikTok's SDK sends events but doesn't attribute installs). AppsFlyer recommended: free tier, official Flutter plugin, best Meta/TikTok partner integrations.
18. AppsFlyer SDK + **OneLink** — this also delivers deferred deep linking for both networks (replacing the Meta platform-channel idea, deliberately dropped).
19. Configure TikTok for Business + Meta as partners in AppsFlyer; optionally TikTok Events API server-side (same dedup pattern as CAPI).
20. Bonus: campaign/adset names finally land in our own data, not just network dashboards.

## Phase 4 — Catalog ads — separate backend project, do not bundle

Advantage+ catalog ads (auto-generated per-store/item ads retargeting browsers with exact items) are typically the best-ROAS format for food delivery — but require a live product feed in Meta's commerce spec (availability, price, id mapping, taxonomy) on a polling schedule. Real backend scope; depends on Phases 0–2. Scope it when we get there.

---

## Dependency chain

Deep links (P0) and purchase events (P1) are the roots. Everything Meta-side (AEO, VO, retargeting, catalog) and everything TikTok-side grows from those two. P0 and P1 are independent of each other — one pass, ~1 week including store metadata.

## Compliance checklist (both stores)

- iOS: ATT prompt before tracking; honest purpose string; never gate/incentivize; privacy labels declare tracking (identifiers, purchase, usage); FBSDK 17+/18 ships the required privacy manifest.
- Android: Data Safety form matches merged manifest (`AD_ID`); ads declaration in App content.
- Privacy policy explicitly names Meta (and later TikTok/AppsFlyer) — required by both stores and both networks' business terms.
