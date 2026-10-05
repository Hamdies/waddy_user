---
target: iOS Live Activity (lock screen + Dynamic Island)
total_score: 16
max_score: 36
na_heuristics: 10
p0_count: 1
p1_count: 4
timestamp: 2026-09-30T21-28-00Z
slug: diliveactivity-waddiliveactivityliveactivity-swift
---
Method: dual-agent (A: design review · B: detector + measurements)

## Design Health Score
| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 1 | "17 min" frozen between pushes; no staleDate; bar identical at handover and picked_up |
| 2 | Match System / Real World | 2 | Warm copy but English-only for Arabic users; "Now" shown while food still cooking |
| 3 | User Control and Freedom | 1 | No widgetURL; tap opens app wherever it was, not the order |
| 4 | Consistency and Standards | 2 | Titles/ETA wording diverge from in-app tracker; dismissal 30s client vs 4h backend |
| 5 | Error Prevention | 2 | Nothing prevents trusting a stale number (isStale never read) |
| 6 | Recognition Rather Than Recall | 3 | Visible, but 4 unlabeled bar segments |
| 7 | Flexibility and Efficiency | 1 | No deep link, no actions |
| 8 | Aesthetic and Minimalist Design | 3 | Tight; merchant duplicated in expanded island; title/line redundancy on the way |
| 9 | Error Recovery | 1 | Canceled: 🙏, no reason, bar wiped, gone in 30s; refunds mislabeled canceled |
| 10 | Help and Documentation | n/a | Glance surface |
| **Total** | | **16/36** | **Poor (44%)** |

## Design Specificity
Uber Eats skeleton in Waddy colours: dark card, merchant/title left, mint ETA right, segmented bar, caption. Mint ~5% of card. Emoji is the only stage icon (PRODUCT.md anti-reference). Copy has voice but the "Waddy!" pun never appears. Detector: .swift unsupported, 0 files scanned (exit 0 is not clean); design HTML scanned in degraded regex mode, 0 findings.

## Priority Issues
- [P0] Status truth: frozen minutes, "Now" during preparing, no staleDate, bar doesn't move at pickup, handover claims a rider/bag that may not exist, take-away says "Arrives".
- [P1] Borrowed layout + emoji icons + wasted delivered peak (30s, dark card).
- [P1] Terminal states and tap-through: no widgetURL (deep link helper only handles store), canceled cold/erased/30s, refund_requested shown as canceled, update wipes store name when a push omits it.
- [P1] English-only, no RTL, en_US_POSIX clock.
- [P1] Accessibility: 0 accessibility labels, fixed point sizes (no Dynamic Type), empty track 1.66:1 and current-vs-pending 2.23:1 non-text contrast.

## Persona Red Flags
Casey: tap doesn't open order; frozen number forces opening app. Sam: VoiceOver reads "woman cook", bar silent. Egyptian glancer: English, generic dark card, delivered gone in 30s. Riley: 120 min squeezes title; refund shown as canceled; handover-without-rider claims rider.

## Minor
Half segment is half-opacity (reads as dim-done, not in-progress); Dart title/subtitle now dead payload; 12.5/13.5 off grid; no isLuminanceReduced handling.
