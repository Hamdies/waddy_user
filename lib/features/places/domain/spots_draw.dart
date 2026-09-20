import 'dart:math';

import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';

/// Where a draw is in its performance.
enum DrawPhase {
  /// Payload not in yet. CTA disabled.
  loading,

  /// Entrants placed, nothing pulled. The only phase the CTA fires from.
  ready,

  /// The claw is running. CTA disabled — a second press mid-run would start a
  /// concurrent draw over the same pool.
  picking,

  /// Every pull replayed. Terminal.
  done,
}

/// Where the person looking at the screen stands in a finished draw.
///
/// The screen has always known whether the user won — [SpotsDraw.iWon] gates
/// the confetti and the voucher button. What it did not distinguish is the
/// difference between *losing* and *never having been in it*, which is the
/// difference between a voter and a guest, and the two need different words.
enum DrawOutcome {
  /// Pulled by the claw. There is a voucher waiting.
  won,

  /// In the machine, not pulled. The consolation case.
  lost,

  /// Not in this draw at all — a guest, or someone who did not vote this
  /// round. Watching someone else's result, which is a legitimate way to
  /// arrive here from a shared link or a push.
  onlooker,
}

/// The weekly voter draw, as a pure state machine.
///
/// ## Why this is not where winners are decided
///
/// The source design picks on-device:
///
/// ```js
/// const target = pool[Math.floor(Math.random() * pool.length)];
/// ```
///
/// That is right for a mockup and wrong for a prize draw. The backend already
/// decides: `PrizeDrawService::drawFor()` runs at crown time — distinct voters
/// for the winning venue, flagged votes excluded, past winners inside their
/// cooldown excluded, `inRandomOrder()->limit(winners_per_week)`, idempotent
/// per period. Vouchers are created and pushed in that same transaction,
/// before anyone opens this screen.
///
/// So by the time a user presses the button, the result is weeks-old fact. If
/// the client also rolled dice there would be two answers to the same question
/// and the client's would be the one that could be patched out of an APK.
/// [SpotsDraw.fromServer] therefore takes the outcome as **input** and the
/// animation replays it. [SpotsDraw.local] exists for fixtures only and is the
/// one place [Random] appears.
///
/// ## Why it holds no Flutter
///
/// Same reason as `spots_stage.dart` and `spots_round.dart`: the cases worth
/// testing here — a winner id with no entrant, fewer entrants than pulls, an
/// empty round — are the ones that are painful to reach through a widget and
/// trivial to reach through a constructor.
class SpotsDraw {
  /// The claw supports 1..8 grabs.
  ///
  /// The design assumed 3. The live backend draws `prize.winners_per_week`,
  /// which defaults to **5**, and the value is config — so this clamps a
  /// server number rather than declaring a client one. Above 8 the run passes
  /// 24 seconds and stops being something anyone watches.
  static const int minPulls = 1;
  static const int maxPulls = 8;

  final DrawPhase phase;

  /// Everyone in the machine, winners included, in payload order.
  final List<DrawEntrant> entrants;

  /// Pulled entrants in pull order. Grows as the animation replays.
  final List<DrawEntrant> winners;

  /// Server's decision: who gets pulled, in what order. Replayed verbatim.
  final List<int> winnerIds;

  /// How many the server actually drew. Not `winnerIds.length` — a backfilled
  /// period can carry fewer entrant rows than the draw had pulls.
  final int pullCount;

  /// Size of the real pool before sampling. Null for a backfilled period where
  /// the losers were never recorded. See `CLAW-Z4`.
  final int? totalEntrants;

  /// The signed-in user's prize, when they won. Null gates the confetti and
  /// makes the winner rows non-tappable.
  final int? myPrizeId;

  const SpotsDraw({
    this.phase = DrawPhase.loading,
    this.entrants = const [],
    this.winners = const [],
    this.winnerIds = const [],
    this.pullCount = 0,
    this.totalEntrants,
    this.myPrizeId,
  });

  /// The real constructor: a decided outcome, ready to replay.
  ///
  /// [winnerIds] order **is** pull order. Ids with no matching entrant are
  /// dropped rather than thrown on — a backfilled period legitimately has
  /// winners whose entrant rows were never written.
  factory SpotsDraw.fromServer({
    required List<DrawEntrant> entrants,
    required List<int> winnerIds,
    int? pullCount,
    int? totalEntrants,
    int? myPrizeId,
  }) {
    final known = {for (final e in entrants) e.userId};
    final resolved = winnerIds.where(known.contains).toList();

    return SpotsDraw(
      phase: entrants.isEmpty ? DrawPhase.done : DrawPhase.ready,
      entrants: entrants,
      winnerIds: resolved,
      pullCount: (pullCount ?? resolved.length).clamp(0, maxPulls),
      totalEntrants: totalEntrants,
      myPrizeId: myPrizeId,
    );
  }

  /// Parse a `GET /api/v1/places/draw/{period?}` response body.
  ///
  /// Accepts the whole envelope (`{success, data}`) or the bare `data` object,
  /// because the two call sites — a fresh fetch and a cached blob — disagree
  /// about which they hold and neither should have to know.
  factory SpotsDraw.fromApi(Map<String, dynamic> json) {
    final data =
        json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : json;

    final entrants =
        (data['entrants'] is List ? data['entrants'] as List : const [])
            .whereType<Map<String, dynamic>>()
            .map(DrawEntrant.fromJson)
            .toList();

    final winnerIds =
        (data['winner_ids'] is List ? data['winner_ids'] as List : const [])
            .map((e) => e is int ? e : int.tryParse('$e'))
            .whereType<int>()
            .toList();

    return SpotsDraw.fromServer(
      entrants: entrants,
      winnerIds: winnerIds,
      pullCount: _int(data['pull_count']),
      totalEntrants: _int(data['total_entrants']),
      myPrizeId: _int(data['my_prize_id']),
    );
  }

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Fixtures and previews only — the design's on-device pick, quarantined.
  ///
  /// Never reachable from a real payload. Pass a seeded [Random] to make a
  /// fixture deterministic.
  factory SpotsDraw.local({
    required List<DrawEntrant> entrants,
    int pulls = 5,
    Random? random,
  }) {
    final rng = random ?? Random();
    final pool = List<DrawEntrant>.from(entrants);
    final picked = <int>[];
    final want = pulls.clamp(minPulls, maxPulls);

    while (picked.length < want && pool.isNotEmpty) {
      picked.add(pool.removeAt(rng.nextInt(pool.length)).userId);
    }

    return SpotsDraw.fromServer(
      entrants: entrants,
      winnerIds: picked,
      pullCount: want,
      totalEntrants: entrants.length,
    );
  }

  // ==================== Derived ====================

  bool get isEmpty => entrants.isEmpty;

  /// How many pulls this run will actually perform.
  ///
  /// A round with fewer entrants than the server's pull count pulls everyone
  /// and stops — the design's `if (!pool.length) return this.finish()`.
  int get effectivePulls => min(winnerIds.length, entrants.length);

  /// Entrants who were never pulled. The consolation panel's population.
  List<DrawEntrant> get losers {
    final won = {for (final w in winners) w.userId};
    return entrants.where((e) => !won.contains(e.userId)).toList();
  }

  /// True when the signed-in user was pulled. Gates the confetti — celebrating
  /// a loss is the one unambiguous bug this screen could ship.
  bool get iWon => myPrizeId != null;

  /// Whether the win has a voucher that can actually be opened.
  ///
  /// A real win always does. A *demo* win does not: `SpotsDrawDemo.winning`
  /// hands out a negative sentinel so a debug build can show the whole win
  /// path on an account that has no prize row, and routing to prize `-1`
  /// would land on a details screen with nothing to load.
  ///
  /// The distinction is only ever true in debug, but it belongs here rather
  /// than in the screen: `iWon` gates the celebration and this gates the
  /// navigation, and conflating them is what would ship a button that opens
  /// an empty screen.
  bool get hasVoucher => (myPrizeId ?? -1) > 0;

  /// True when the signed-in user was one of the balls in the machine.
  ///
  /// Distinct from [iWon] in the case that matters: a **guest**, or anyone who
  /// did not vote this round, is neither a winner nor a loser — they are an
  /// onlooker. The endpoint only sets `is_me` on an authed request, so this is
  /// false for guests by construction, which is the answer we want.
  ///
  /// Sampling does not affect this: `is_me` is a property of the entrant row
  /// the server sends, and the server includes the signed-in user's row when
  /// they were in the draw.
  bool get iEntered => entrants.any((e) => e.isMe);

  /// What this draw means *for the person looking at it*.
  ///
  /// The chute used to report the machine's state after a run — "ALL PULLED" —
  /// at the exact moment the user wants to know their own. This is the value
  /// that replaces it, and it is deliberately three-way rather than a boolean
  /// on [iWon]: telling a guest "you're not in this one" is false, because
  /// they never were, and telling them they lost is worse.
  DrawOutcome get outcome {
    if (iWon) return DrawOutcome.won;
    if (iEntered) return DrawOutcome.lost;
    return DrawOutcome.onlooker;
  }

  /// Pool size to state in the overflow copy: the true total when the server
  /// sent one, otherwise what we can see.
  int get displayTotal => totalEntrants ?? entrants.length;

  /// The entrants the cabinet may draw, with **every winner guaranteed
  /// present**.
  ///
  /// A real round can have a thousand voters and the pile holds twelve. If the
  /// claw ever reached for someone who was not already in the glass, the
  /// screen would have to invent a thirteenth ball mid-grab or silently swap
  /// one — and a user who screenshots the pile could prove it changed. Either
  /// reads as a rigged machine, which is exactly the accusation a prize draw
  /// cannot afford.
  ///
  /// So the visible pile is: winners first, then losers to fill. The claw only
  /// ever grabs a face that was on screen from the first frame, and the
  /// overflow plate states the rest honestly rather than hiding them.
  ///
  /// The backend already sorts this way, but ordering is not a guarantee —
  /// a cache, a re-sort or a hand-built payload could undo it, and the failure
  /// would be silent. This enforces it client-side where the pile is drawn.
  List<DrawEntrant> visibleEntrants(int slots) {
    if (entrants.length <= slots) return entrants;

    final winners = {...winnerIds};
    final pulled = entrants.where((e) => winners.contains(e.userId));
    final rest = entrants.where((e) => !winners.contains(e.userId));

    return [...pulled, ...rest].take(slots).toList();
  }

  bool get ctaEnabled => phase == DrawPhase.ready && !isEmpty;

  // ==================== Transitions ====================

  /// `ready → picking`. A no-op from any other phase, which is the guard the
  /// design writes as `if (this.state.phase !== "ready") return`.
  SpotsDraw start() {
    if (!ctaEnabled) return this;
    return copyWith(phase: DrawPhase.picking);
  }

  /// Append the next pull. Called once per completed grab by the animation.
  ///
  /// Terminates itself: once every id in [winnerIds] is spent — or the pool
  /// runs dry — the next call moves to [DrawPhase.done] instead of pulling.
  SpotsDraw pullNext() {
    if (phase != DrawPhase.picking) return this;
    if (winners.length >= effectivePulls) {
      return copyWith(phase: DrawPhase.done);
    }

    final nextId = winnerIds[winners.length];
    final entrant = entrants.firstWhere((e) => e.userId == nextId);

    final appended = [...winners, entrant.copyWith(rank: winners.length + 1)];

    return copyWith(
      winners: appended,
      phase:
          appended.length >= effectivePulls
              ? DrawPhase.done
              : DrawPhase.picking,
    );
  }

  /// Jump to the finished state with every winner listed.
  ///
  /// Two callers, one code path: the SKIP control (`CLAW-11b`) and the
  /// reduced-motion branch (`CLAW-13`). Both want the same thing — the result
  /// without the theatre — and the result is server-decided anyway, so nothing
  /// is being skipped except the performance.
  SpotsDraw finish() {
    if (phase == DrawPhase.done) return this;

    final all = <DrawEntrant>[];
    for (var i = 0; i < effectivePulls; i++) {
      final id = winnerIds[i];
      all.add(entrants.firstWhere((e) => e.userId == id).copyWith(rank: i + 1));
    }

    return copyWith(phase: DrawPhase.done, winners: all);
  }

  SpotsDraw copyWith({
    DrawPhase? phase,
    List<DrawEntrant>? entrants,
    List<DrawEntrant>? winners,
  }) {
    return SpotsDraw(
      phase: phase ?? this.phase,
      entrants: entrants ?? this.entrants,
      winners: winners ?? this.winners,
      winnerIds: winnerIds,
      pullCount: pullCount,
      totalEntrants: totalEntrants,
      myPrizeId: myPrizeId,
    );
  }
}
