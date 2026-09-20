# WADDI SPOTS — Places to Visit

**Product & technical documentation** · Last updated 2026-07-11 · Owner: Ahmed Hamdy

> The weekly battle for the best spot in the neighborhood. Real votes, real trophy
> in the winning cafe, real Monday-morning line at the counter.

---

## 1. Concept

Every week, users crown the best spot (cafe / restaurant / hangout) in their area.
The competition is **weekly**, **zone-aware** (Degla, Road 9, …), and spills into
the real world:

- 🏆 **The trophy is physical** — a Waddi cup displayed at the winning cafe. It
  moves when the crown moves. Cafes compete to keep it; customers see it on the
  counter and ask about the app.
- 📰 **The winner is news** — the app publishes the weekly champion like a front
  page, with a Hall of Fame of past winners.
- 👥 **Voters are players, not ballots** — backing a spot puts your XP, your
  streak, and your reputation on the line (see §4).

**North-star metric: Weekly Active Voters (WAV).**

**Naming:** "Places to Visit" is the internal module name only. The tab is
branded **WADDI Spots**; the competition needs a campaign name — recommended:
**"The Weekly Crown"** (fits the trophy narrative; Arabic-friendly). Other
candidates: Spot Wars, Best of Maadi, Battle for the Crown. Decision: owner.

---

## 2. The weekly cycle

Period format everywhere: **ISO week** — `2026-W28` (`o-\WW` in PHP).

| When (local) | What happens |
|---|---|
| Monday 00:00 | New week opens. Votes reset. Odds reset. Board is fresh. |
| All week | Voting, switching, board movement, trend arrows, crew recruiting |
| Sunday (final 24h) | Countdown chip turns red. (Planned: final-hours push) |
| Monday 00:00 | Week **locks** |
| Monday 00:10 | `placestovisit:close-week` crowns winners (overall + per zone), writes `place_winners`. (Planned: payouts settle, streaks update, push fires) |
| Monday morning | Champion banner ("WADDI NEWS") goes live in-app. (Planned: Winner's Rush at the cafe) |

**Failsafe:** `WinnerService` lazy-closes the previous week on any read of the
winners API — winners appear even if the cron never runs.

---

## 3. Shipped mechanics (live in code today)

### Voting — one vote per user per week
- A user has **one vote per ISO week**, total — not one per place.
- Voting for a second spot returns HTTP **409** + `code: already_voted_this_week`
  + the current spot's name. The app shows a **"MOVE YOUR WEEKLY VOTE?"** dialog
  and retries with `switch=1`. Switching moves the vote instantly (allegiance can
  change until the lock).
- Same-place re-vote updates rating/review/photo (never duplicates).
- `GET {place}/vote-status` returns `weekly_vote` — where the user's vote sits.

### The podium & the live race
- Leaderboard threshold `min_votes_for_leaderboard = 1` — the podium ranks from
  the **first vote** (fresh-app friendly; raise later if 1-vote crowns feel cheap).
- **Podium** (winner card + #2/#3 steps) with rank-movement stickers:
  ▲2 CLIMBING / ▼1 SLIPPING / 🔥 NEW ENTRY.
- **Live Race Board** fallback when the leaderboard lags: top 5 by this week's
  votes with stock-ticker movement chips, pulsing LIVE dot, leader highlight.
- Movement is computed against a per-week, per-zone rank snapshot cached on
  device (SharedPreferences) — arrows show change since the user last looked,
  and update live after voting.
- **Countdown chip** on podium + race board: "LOCKS IN 2D 14H" normally; inside
  the final 24h it becomes a live ticking clock — "ENDS IN 23:11:54", red.

### The news & Hall of Fame
- `place_winners` table stores every closed week's champion (overall + per zone).
- **Champion banner** ("📰 WADDI NEWS — WEEK 28") under the podium: crowned spot,
  votes, category, dynasty badge ("🏆 2×") when a spot holds multiple titles.
- **Hall of Fame** bottom sheet: every past weekly champion, tap-through to place.

### XP (live values from `config/placestovisit.php`)
| Action | XP | Dedupe |
|---|---|---|
| Weekly vote | 5 | once per **week** (switching never re-awards) |
| Text review | 10 | once per week |
| Photo review | 15 | once per week |
| Approved submission | 25 | once per submission |

XP lands in `users.total_xp` (the leveling system — **not** loyalty points).
The Spots header chip shows `total_xp` and opens the XP levels screen.

### Anti-abuse (live)
- One vote/week structurally kills vote spam.
- XP deduped per week — switch/remove/recast farms nothing.
- Review reports auto-flag at **3** reports (`report_auto_flag_threshold`).
- Rate limits: vote 30/min, report 10/min, submissions 10/min.
- Max **5** pending submissions per user.

---

## 4. Designed mechanics — the game economy (next builds)

> Status: specified, agreed, **not yet built**. Build order at §9.

### Principle: votes crown, stakes pay
- The **winner is decided by number of backers** — one human, one vote. Stakes
  never buy rank (pay-to-win would destroy the trophy's credibility and the
  cafes' incentive to display it).
- The **stake** is the voter's personal wager on their prediction.

### ① Stakes & Multipliers
> **Terminology rule:** never say "odds", "bet", or "betting" anywhere in the
> UI or marketing — in Egypt that wording reads as gambling (cultural + app
> review risk). User-facing words: **Multiplier** (×2.8) and **Champion
> Bonus**. The mechanic below is unchanged; only the language is safe.

- On voting, the user stakes XP: **10 / 50 / 100** (weekly cap 100).
- **Multiplier per spot**, recomputed live from vote share:

  ```
  multiplier = clamp( (total_voters / spot_voters) × 0.80 , 1.1 , 8.0 )
  ```
  rounded to 1 decimal. The 0.80 factor is the margin that keeps the XP
  economy from inflating (target: net XP minted by the game ≈ 0 ± 10%/week).
- Board shows votes (the race), the multiplier (the dare), and **the pot**
  (total XP riding per spot — pure drama).
- **Switching costs 25% of the stake.** Legal until lock. The Thursday
  "ride or defect" decision is the intended adrenaline.

### Payout table (settles Monday 00:10)
| Your spot finishes | You get |
|---|---|
| 🥇 #1 | stake × multiplier (locked at vote time), streak +1 |
| 🥈 🥉 podium | stake refunded |
| below | stake lost, streak resets |

Worked example (stake 50): favorite ×1.2 → +10 profit · mid ×2.5 → +75 ·
underdog ×5 → +200. **Herding is self-punishing** — the more pile on the
favorite, the worse it pays, the juicier the underdog. Two healthy player
types emerge: streak grinders (safe, small, consistent) and prophets
(contrarian, big multipliers).

> **Launch gate:** stakes ship only after the core loop proves itself —
> **WAV ≥ 500** or **W1 voter retention ≥ 40% for 3 consecutive weeks**.
> V1 stays simple: vote → board → champion → trophy → news. Keeps onboarding
> one-tap and validates the competition before adding economy complexity.

### ② Kingmakers board (replaces "Top Voters")
Ranked by **being right**, not tapping a lot:
- **W–L record** — weeks the user backed the champion
- 👑 **Kingmaker streak** — consecutive winning weeks (reset hurts = retention)
- 🔮 **Prophet badge** — won at multiplier ≥ ×3
- Season = calendar month; season leaders get the grand perk.

### ③ Overtake pushes
Exactly two triggers, no spam:
- Lead change: "🚨 Kong just took #1 from L'aroma — 6h to lock"
- Final 3 hours, to users whose spot is #2 within 3 votes.

### ④ Winner's Rush (the physical prize — replaces any raffle)
- **First 15** members of the winning crew to show up at the winning cafe on
  Monday get the prize (free drink / cafe's pledge). QR in app, scanned at the
  counter, first-come-first-served.
- Not a lottery — a race. And it manufactures a Monday line at the winning
  cafe, which is the sales pitch for recruiting partner cafes.

### Crews (identity layer, cheap to add)
Voting = joining that spot's **crew** for the week: member count on the board,
avatars, "we're down 3 votes" recruiting loop. Invite-a-friend lands the friend
in your crew.

### Hard rule — this stays a game, not gambling
**XP is earn-only. No purchase path into stakes, ever.** Money → XP → wagering
would make this a casino (app-store rejection + legal exposure). Earned points,
virtual payouts, physical perk redeemed in person: the safe side of the line.

---

## 5. KPIs & targets

North star: **Weekly Active Voters** (users who cast ≥1 vote that week).

### Engagement
| Metric | Definition | Target (M1) | Target (M3) |
|---|---|---|---|
| Voter activation | voters / MAU of Spots tab | 25% | 40% |
| Sessions per voter per week | app opens touching Spots | 3 | 5 |
| W1 voter retention | voted last week AND this week | 40% | 55% |
| Switch rate | switches / votes | 5–15% healthy band | — |
| Countdown-window traffic | share of weekly Spots sessions in final 24h | 20% | 30% |

### Game economy (once §4 ships)
| Metric | Definition | Target / guardrail |
|---|---|---|
| Stake participation | votes with stake > min / all votes | ≥ 50% |
| Underdog share | stakes at multiplier ≥ ×2.5 | 15–30% (below = herding, above = chaos) |
| XP inflation | net XP minted by game per week | 0 ± 10% |
| Streak holders | users with streak ≥ 2 | 20% of WAV |
| Push opt-in / open rate | — | ≥ 60% / ≥ 20% |

### Real-world loop
| Metric | Definition | Target |
|---|---|---|
| Rush redemption | rush prizes claimed / offered (15) | ≥ 60% |
| Partner cafes | cafes pledging prizes + hosting trophy | +2/month |
| Share-card CTR → install | (once share cards ship) | 5% |

### Guardrails (watch weekly)
- Report rate < 2% of votes; flagged-vote rate trending down
- One-session-only voters < 40% (higher = the mid-week loop is failing)
- Same spot winning ≥ 4 weeks straight in a zone → trigger category weeks /
  champions-tier rotation (§9 later items)

---

## 6. API reference (`/api/v1/places`)

Public unless marked 🔒 (`auth:api`).

| Method | Path | Notes |
|---|---|---|
| GET | `/` | List places. Filters: `category_id, search, zone_id, tag_ids, sort, lat/lng, page/offset`. `votes_count` is **current-week** scoped. Each place carries `titles_count` + `is_current_champion` |
| GET | `/leaderboard` | `period, zone_id, limit`. Threshold = 1 vote. Cached 60 min, cleared on every vote |
| GET | `/top-voters` | `zone_id, limit` (→ becomes Kingmakers, §4②) |
| GET | `/winners` | Hall of fame, newest first. `zone_id, limit≤52` |
| GET | `/winners/latest` | Latest champion (lazy-closes previous week) |
| POST | `/events` | KPI event ingestion (client whitelist, throttle 60/min, guest-friendly, user attached when authed) |
| GET | `/trending`, `/categories`, `/tags`, `/zones`, `/banners` | — |
| GET | `/{place}` | Details |
| GET | `/{place}/reviews` | Paginated, per-period |
| 🔒 POST | `/{place}/vote` | `rating, review, image, switch`. **409** + `current_vote` when weekly vote is elsewhere and `switch≠1` |
| 🔒 DELETE | `/{place}/vote` | Remove vote |
| 🔒 GET | `/{place}/vote-status` | `has_voted`, `vote`, **`weekly_vote {place_id, place_title}`**, `period` |
| 🔒 POST | `/votes/{vote}/report` | Auto-flag at 3 reports |
| 🔒 | favorites / submissions routes | unchanged |

---

## 7. Data model (backend `Modules/PlacesToVisit`)

- **places** — zone_id, category_id, images, translations, active flag
- **place_votes** — `place_id, user_id, period (2026-W28), rating, review, image,
  is_flagged`. One row per user per week (enforced in `VotingService`)
- **place_winners** — `period, zone_id (null = overall), place_id, votes_count,
  avg_rating`. Written at week close; idempotent per period
- **place_events** — `event, user_id?, place_id?, zone_id?, period, meta,
  created_at`. The KPI stream: every §5 metric is a SQL query over this table
- **place_zones / place_categories / place_tags / place_banners /
  place_submissions / place_vote_reports** — supporting tables
- XP side (main app): `users.total_xp`, `users.level`, `xp_transactions`
  (dedupe on user + reference_type + reference_id + source)
- Planned (§4): `place_stakes` (user, period, place, amount, multiplier_at_stake,
  status: open/won/refunded/lost), `voter_records` (W-L, streak) — or derive
  records from stakes

**Key config** (`config/placestovisit.php`): `min_votes_for_leaderboard=1`,
`leaderboard_limit=10`, `leaderboard_cache_minutes=60`, XP values (§3),
`report_auto_flag_threshold=3`, submission limits.

---

## 8. App architecture (`waddi_user/lib/features/places/`)

- **controllers/places_controller.dart** — all state; live standings +
  rank-delta snapshots (`places_rank_snapshot_<period>_<zone>`), weekly champion,
  hall of fame, vote/switch orchestration
- **screens/** — `places_home_screen` (header w/ XP chip → XP levels),
  `place_details_screen`, `place_submission_screen`
- **widgets/** — `podium_section` (podium ⇄ race board ⇄ empty state),
  `podium_winner_card` / `podium_runner_card` (trend stickers),
  `live_race_board`, `week_countdown_chip`, `champion_banner` (news),
  `hall_of_fame_sheet`, `vote_switch_dialog`, `chillers_section` (→ Kingmakers),
  `area_filter_tabs`, `places_list_view`
- **domain/models/** — `place_model` (+`PlaceList`, `TopVoter`),
  `place_winner_model`, `place_vote_model` (`weekly_vote`), review/submission/
  banner/category models

---

## 9. Roadmap — phased, with launch gates

### Phase 1 — Core loop (SHIPPED)
Weekly voting (one vote + switch), live board with movement, countdown clock
(live HH:MM:SS in final 24h), week close, champion news banner, Hall of Fame.

### Phase 2 — Growth loop
1. ✅ **Champion badges** (SHIPPED 2026-07-11) — place API now returns
   `titles_count` + `is_current_champion`; place cards show a
   👑 REIGNING CHAMPION / 🏆 N× CHAMPION sticker (earned titles outrank
   decorative stickers), and the details page shows the ribbon + titles chip
2. ✅ **Share cards** (SHIPPED 2026-07-11) — share button on the news banner
   opens a story-sized (4:5) branded champion card, captured at 3× and handed
   to the system share sheet (Instagram Stories / WhatsApp). This is the
   organic acquisition engine
3. ✅ **Smart pushes** (SHIPPED 2026-07-11) — two triggers only:
   - **Lead change**, checked after every vote mutation with a 30-min cooldown
     per scope ("🚨 {new} just took #1 from {old} — Nh until the crown locks")
   - **Final hours**, `placestovisit:final-hours-push` scheduled Sunday 21:00,
     fires per scope when the #1–#2 gap ≤ 3 votes (tied races get special copy)
   - FCM topics: `places_race_all` (subscribed on Spots screen load) +
     `places_race_zone_{id}` (follows the selected zone filter)
4. ✅ **Analytics events** (SHIPPED 2026-07-11) — `place_events` table feeds
   every §5 KPI. Server-trusted: `vote_created / vote_switched / vote_updated /
   vote_removed` logged inside VotingService. Client (POST `/places/events`,
   throttled, guests allowed): `banner_view, race_view, hof_view, details_view,
   share_open, share_done` — fire-and-forget via `PlacesAnalytics.log()`,
   view events deduped once per session
5. **The plaque program** (ops, not code) — permanent QR stand at partner
   cafes: "🏆 Official Waddi Champion — scan to vote for next week's crown."
   Trophy travels; plaque stays. Every cafe customer is a funnel entry

### Phase 3 — Game economy (GATED: WAV ≥ 500, or W1 retention ≥ 40% × 3 weeks)
5. **Stakes + Multipliers + Monday payout** — `place_stakes` table, multiplier
   in board payload, settlement inside `close-week` (§4①)
6. **Kingmakers board** — W-L / streak / prophet, replaces Top Voters (§4②)
7. **Winner's Rush** — QR redemption, cafe-side scan page, prize pledges (§4④)

### Phase 4 — Depth (as traction demands)
8. Crews UI (avatars on the board, invite deep link into your crew)
9. Heat map — zone map with 🔥 trending spots (places already have lat/lng)
10. Check-in / receipt-verified voting (fraud hardening once traffic is real)
11. Category weeks & champions tier (triggered by the §5 same-winner guardrail)
12. Seasons — monthly grand final; one physical trophy ceremony per month,
    weekly titles stay digital (cuts trophy logistics 4×)

---

## 10. Ops runbook

**Deploy checklist (backend):**
```bash
php artisan migrate          # place_winners
php artisan config:clear     # weekly period, threshold=1, XP values
# ensure crontab: * * * * * php artisan schedule:run
```

**Manual week close (idempotent):**
```bash
php artisan placestovisit:close-week            # closes last week
php artisan placestovisit:close-week --period=2026-W28
```

**Manual close-race push (e.g. testing):**
```bash
php artisan placestovisit:final-hours-push --gap=3
```

**KPI query example (WAV, current week):**
```sql
SELECT COUNT(DISTINCT user_id) FROM place_events
WHERE event = 'vote_created' AND period = '2026-W28';
```

**Troubleshooting**
- *Podium empty despite votes* → leaderboard cache (60 min) or period mismatch;
  any new vote clears the cache; check `place_votes.period` format is `2026-Wxx`
- *Header XP shows 0* → `/customer/info` must include `total_xp`; app reads
  `UserInfoModel.totalXp` (falls back to loyalty points)
- *No champion banner* → needs one closed week with ≥1 vote; check
  `place_winners`, or hit `GET /places/winners/latest` (lazy-close)
- *Old monthly votes* (`period=2026-07`) don't count in weekly races — expected

**Cadence note:** votes from before 2026-07-11 used monthly periods; weekly
history effectively starts week 2026-W28.
