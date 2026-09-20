---
target: The Claw spots draw results screen
total_score: 30
max_score: 36
na_heuristics: 9
p0_count: 2
p1_count: 2
timestamp: 2026-09-18T02-23-51Z
slug: eatures-places-screens-spots-claw-draw-screen-dart
---
Method: dual-agent (A: design review, source-only · B: detector + mechanical evidence)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 4 | "5 OF 5 PULLED" on the machine's brow; LIVE pill drops at `done`; differentiated haptics |
| 2 | Match System / Real World | 4 | Arcade metaphor executed to the serial plate; colloquial Egyptian Arabic, not MSA |
| 3 | User Control and Freedom | 3 | SKIP exists, back is `canPop`-gated — but the `done` state offers the loser nothing |
| 4 | Consistency and Standards | 3 | `ClawTokens` forks geometry (documented), but 44/40/46 are three adjacent sizes in one row |
| 5 | Error Prevention | 4 | `visibleEntrants()` guarantees winners on-screen from frame one; confetti gated on `iWon` |
| 6 | Recognition Rather Than Recall | 3 | Faces-not-ids is real recognition; winner rows lose their tie to the scrolled-off cabinet |
| 7 | Flexibility and Efficiency | 2 | SKIP only exists during `picking`. At `done`: no replay, no share, no vote-again |
| 8 | Aesthetic and Minimalist Design | 4 | Reflections moved behind the pile; votes demoted out of leaderboard grammar |
| 9 | Error Recovery | n/a | No user-input surface, no user-causable failure; outcome is server-decided weeks earlier |
| 10 | Help and Documentation | 3 | Random-note earns its line; no "how many win / when's next / what's the voucher" |
| **Total** | | **30/36** | **Good (83%)** — heuristic 9 n/a, applicable max 36 |

(Note: 7 scored 2 and 9 n/a; applicable max 36.)

## Design Specificity Verdict

**Authored, emphatically.** The central conceit — a machine full of real people's faces, a claw reaches in — is a designed idea, not a decorated list. The cabinet is modeled as ONE physical object; spots_claw_draw_screen.dart:356-362 records that splitting it onto the page background was tried and lost the idea the screen rests on. Four decisions serve that one idea: glass takes a border and no lift; glass floor darkened off-spec so the interior doesn't flatten into the chassis; full mint excluded from the ball palette so the pile doesn't dissolve into the frame. Mint is dominant AND structural — it is the machine's body, far above the ~2% defect threshold.

Arabic is the strongest specificity signal: "كل صوت كورة جوه الماكينة" is spoken Egyptian, not translated MSA. The brand pun survives translation.

Generic exactly where stakes are highest: winner row is standard avatar+name+meta+chevron; consolation card is emoji + heading + body + caps line.

**Deterministic scan: UNAVAILABLE.** Detector returned [] exit 0, but that is a non-result: `.dart` is absent from SCANNABLE_EXTENSIONS (zero files ingested), AND a control probe with deliberately broken HTML also returned [] with stderr reporting missing HTML parser modules ("findings are an undercount, not a clean bill of health"). Mechanical evidence gathered via targeted greps + hand-written WCAG script instead. `flutter analyze lib/features/places/` is clean: 0 errors, 0 warnings, 0 infos.

**Visual overlays:** n/a — mobile-only Flutter target, no viewable URL.

## Overall Impression

The most authored screen in the codebase, whose finished state forgets that the person looking at it lost. Above the fold: excellent. Below: it inverts its own priorities — a loser scrolls past ~400pt of five strangers' wins (row 1 haloed mint, brightest object on screen) before learning their own outcome, then the scroll ends on a mint line that looks like a button and does nothing.

Biggest opportunity: the `done` state is a dead end with a live idea sitting above it.

## What's Working

1. **The won/lost refactor, defended in code.** claw_ball.dart:19-25 records an earlier version that named the pulled set `_lost` — greying winners and stamping them 😢 while actual losers stayed bright. Paired with confetti gated on `iWon` and visibleEntrants() guaranteeing winners in the glass from frame one (nobody screenshots a pile that later changes), the screen is systematically defended against looking rigged.
2. **Reduced motion as a first-class path.** All 4 controllers guarded; `_start()` under reduced motion shares the exact code path as SKIP, so skipping costs nothing by construction. Confetti checks it too (spots_confetti.dart:22). Cleanest implementation in the codebase.
3. **Localization complete and idiomatic.** All 30 keys in both en.json and ar.json — zero silent raw-key risk. displayCaps no-ops under Arabic; displayTracking collapses to 0 because connected letterforms break when spaced.

## Priority Issues

### [P0] The loser's only forward action is inert text
spots_claw_draw_screen.dart:770-777 — "NEXT TIME — VOTE MONDAY" is a bare Text. Mint, uppercase, CTA position. No GestureDetector, no onTap, no Semantics(button:true), no hit target.
Why: every convention in the app says tappable. It is the last thing a loser experiences, and the retention loop (vote again Monday) has zero conversion surface. Compounding: `done` offers the loser NO action — CTA disabled, SKIP gated on `picking`, winner rows tappable only when `w.isMe && myPrizeId != null` which a loser never satisfies. Back button only.
Fix: SpotsPressable over a 48pt container, mint fill / teal ink matching _cta() primary, routed to Spots voting home. Best consolidated into the CTA slot (see P2-1).
Command: /impeccable harden

### [P0] Consolation card mounted after five strangers' wins
spots_claw_draw_screen.dart:370-375 — verified: _winners() at :370, _consolation() at :374.
Why: the user's own outcome is the highest-priority info on a personal results screen. Peak-end rule: the reframe ("You stayed in the machine") is the right closing note and it's buried. Cognitive-load item 4 (visual hierarchy) fails — loudest elements are other people's wins.
Fix: in the `done && !iWon` branch only, hoist _consolation() above _winners(); drop margin top: Spots.s24 at :730 in favour of the sibling SizedBox. The iWon path is unaffected.
Command: /impeccable layout

### [P1] Vote counts assert a causality the copy must argue against
claw_winner_row.dart:98-111 — rows read 6, 4, 5, 10, 7 against plates numbered PICK 1–5.
Why: leaderboard grammar applied to random data. Refutation is one 12pt line ~200pt above that scrolls away. Layout claims on every row; copy refutes once, quietly, elsewhere. Cognitive-load item 7 (working memory) fails. Comment at :687-692 names the stake: "a user who concludes the draw is rigged is the one outcome a prize screen cannot afford."
Fix: remove the vote count from the winner row — it is not evidence of anything on a random draw. Removing deletes the false read rather than arguing with it. If retained, repeat the random-note as a footer under the last row.
Command: /impeccable clarify

### [P1] 😢 on every unpulled ball is the anti-reference, and lands before any words
claw_ball.dart:185-211 — `if (lost || won)`.
Why: PRODUCT.md names "emoji as primary status iconography" as an explicit anti-reference. Fair split: 🎉 on winner rows is defensible (row already says PICK 1 + name — association, not status); 30px 😢 on the consolation card is fine (decorates a state already named in words). But 😢 on every ball IS the per-ball state marker on a surface with no accompanying text. Sequentially worse: at `done` the cabinet is above the fold, so the first thing a loser sees is greyscale crying faces, possibly their own, before reading a word about their outcome. Desaturation already carries the state.
Fix: change `if (lost || won)` to `if (won)`. Lost keeps desaturation + paperSunk + faded shadow.
Command: /impeccable polish

### [P2] Disabled CTA burns the best real estate; half its styling is dead code
spots_claw_draw_screen.dart:570-582 — verified: ctaEnabled is `phase == ready && !isEmpty`, so `enabled && done` is unsatisfiable. The `done ? Spots.teal : Spots.mint` and `done ? Colors.white : Spots.teal` branches can NEVER render; the "RUN AGAIN" state described at :563-567 is unreachable.
Why: ~72pt of the hero object renders a dead button in the thumb zone at `done` — the best place for the loser's forward action. Contrast 3.33:1, passing only on the large-text threshold (disabled is WCAG-exempt, but it's the lowest-contrast element on screen).
Fix: delete the dead branches; put a live action in the reserved slot — !iWon gets the vote-Monday CTA (P0-1), iWon routes to prize details. Consolidates both P0 fixes.
Command: /impeccable harden

### [P2] "N votes" fails WCAG AA on both backgrounds
claw_winner_row.dart:107-110 — Spots.ink3 #6E8481 at 12px w400. 3.98:1 on white, 3.60:1 on the mint hero row. Both under 4.5:1. Independently computed and confirmed by both assessment passes. Most-repeated failing element (5 instances); only genuine contrast failure on the screen.
Fix: Spots.ink2 #3F5754 → 7.77:1 on white, 7.03:1 on mint100. One token swap.
Command: /impeccable audit

## Persona Red Flags

**Glance-based user (Egypt 18–40, 1–2s glances):** a one-second glance at `done` lands on greyscale crying faces — reads as "something went wrong," not "here's your standing." Status strip says "5 OF 5 PULLED", a process readout. Nothing in the glance zone says whether the viewer won.

**Arabic RTL reader:** plumbing is genuinely there (marquee reverses, chevron mirrors, shadows correctly stay physically down-right). But condensed-uppercase doesn't survive: displayCaps returns Arabic unchanged, so "الكلّاب" renders at Spots.display(30) with height: 0.95 — tuned for Latin caps with no descenders — clipping ascenders and shadda/kasra diacritics. Worst at claw_masthead.dart:128 and the 18pt headings. Kicker tracking collapses to 0, so all-caps labels lose their only distinguishing feature.

**Low-vision / 200% text scale:** well-handled at macro level (FittedBox scaleDown on wordmark, CTA, section header — each with a documented regression behind it). But TextScaler.noScaling appears in 7 places; cumulatively the PICK plates, LIVE pill and face initials stay fixed while everything around them grows. Hierarchy inverts; structural PICK 1–5 plates become the smallest text on screen.

**Screen-reader user:** strong and deliberate — cabinet is ExcludeSemantics, winner rows collapse to one node with a composed label, phases announced via the non-deprecated view-scoped API. Breaks: the inert "VOTE MONDAY" line is invisible to AT too; SpotsPressable(enabled: false) returns the bare child so no disabled state is exposed.

## Minor Observations

- Clipped marquee is intentional and correctly built — triple-guarded (short-run bypass, explicit ClipRect, direction-aware ShaderMask fade). Not a bug. Nit: fade is asymmetric (4% leading, 12% trailing); at 32pt the leading 4% is ~1.5px, too narrow to read as a fade. Widen to ~0.08.
- ClawLighting implements 5 modes; the screen reaches 2. threeBars and strobe are ~50 lines of unreachable paint code.
- Back plate 44×44 — meets iOS HIG, 1pt under Material 48, and it is the only exit from the screen.
- One raw hex in the feature (Color(0xFFAEC4C1), glass floor, documented) and one hardcoded string (WADDI · MDL-nn, a serial plate, plausibly intentional).
- Off-grid neighbours in one row: _MedalPlate 44×40, _Face 46×46. Both at 44×44 would resolve the winner row's slightly unfinished quality.
- NON-FINDING worth stating: zero Dimensions.* usage is NOT a violation — Spots.s4…s32 + ClawTokens is a deliberate, documented parallel token layer.

## Questions to Consider

1. If the outcome was decided weeks ago on the server, why does the button say "RUN THE DRAW"? Every loser who learns this has grounds to feel the machine was a puppet show. Would "SEE WHAT THE CLAW DID" cost the magic, or would owning the replay be more trustworthy?
2. Should the loser's own ball be guaranteed a slot? The copy's whole argument is "You stayed in the machine" — but the viewer's face is in the pile only by luck, and if it is, it's greyscale with a sad face. Guarantee it, mark it with a mint ring, let the card point at it.
3. Is PICK 1–5 a list, or five independent events flattened into one? Five random pulls have no first place. Five equal tiles with no vertical order makes "not a ranking" structural instead of parenthetical — and deletes P1-1.
4. Is this a screen, or a cutscene being asked to also be a screen? Most opens are returning opens, from a push, by a loser. For that user the theatre is spent and the screen has nothing.
