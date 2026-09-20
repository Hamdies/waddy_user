# Waddi Splash Screen

## Overview
Brand-field splash: a full mint (`#1EF2A0`) field — identical to the native
launch screens on both platforms, so the native → Flutter handoff is
invisible — with the Waddi "W" mark tinted deep teal (`#134E4A`) at center.
The splash is brand-constant: it does not change with light/dark theme.

The mark asset (`assets/image/waddy.png`) is the mint glyph on transparency;
it is recolored at runtime via `Image.asset(color: …)`, so no separate teal
asset exists.

## Motion (two `AnimationController`s; the splash never sits on a dead frame)
- **Idle breath** — from the very first frame, the mark scales 1.0 ⇄ 1.05
  (`easeInOutSine`, 1600ms, auto-reversing loop). It loops until the moment
  navigation actually happens — through config loading AND all navigation
  prep (token refresh, favourites fetch, deep-link resolution). A slow
  network never looks like a frozen app, and there is never a blank field
  after the mark has left.
- **Exit (played on demand, always the final beat)** — the splash registers
  `_playExit` with `SplashController.registerSplashExit()`. The route helper
  awaits `playSplashExit()` immediately before every `Get.offNamed` that
  replaces the splash — after its async prep is done. The mark dissolves:
  scale 1.0 → 1.15 (`easeOutCubic`) while fading out (`easeInOut`), 350ms,
  then the route pushes over the mint field (app default `Transition.topLevel`).
- **Minimum brand beat** — if everything is ready faster than
  `_minBrandBeatMs` (500ms), the exit waits for that mark so instant launches
  read as a beat, not a strobe. There is no fixed animation cost added on top
  of network time.

## Flow
1. `initState` starts the breath loop, config loading (`getConfigData`),
   connectivity monitoring, and registers the exit callback — all up front.
2. Each `GetBuilder` rebuild calls `_checkConfigReady()`; once
   `SplashController.configLoaded` is true, `markAnimationComplete()` fires
   immediately (the breath keeps looping).
3. The controller's `_tryNavigate` → `route()` runs its routing branches;
   right before pushing the destination, `_exitSplashThen()` awaits the
   dissolve, then navigates. Notification deep links that push *on top* of
   the splash (`Get.toNamed`) skip the exit so the field beneath stays alive.

## Accessibility
If the system "disable animations" setting is on, neither the breath nor the
exit runs; the exit callback resolves instantly and navigation proceeds as
soon as config is ready.

## Customization
Tuning knobs at the top of `splash_screen.dart`:
- `_mintField` / `_tealInk` — brand colors (keep `_mintField` in sync with
  `launch_background.xml` and `LaunchScreen.storyboard`)
- `_logoSide` — logo box size (default 100)
- `_minBrandBeatMs` — minimum splash hold on instant readiness (default 500)
- `_exit` duration — dissolve length (default 350ms)
