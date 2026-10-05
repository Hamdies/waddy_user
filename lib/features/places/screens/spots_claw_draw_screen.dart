import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/spots/spots_confetti.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/domain/claw_audio.dart';
import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw.dart';
import 'package:waddy_app/features/places/domain/spots_draw_fixtures.dart';
import 'package:waddy_app/features/places/domain/spots_draw_geometry.dart';
import 'package:waddy_app/features/places/domain/spots_draw_timeline.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_cabinet.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_chute.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_header_strip.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_marquee.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_masthead.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_tokens.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';

/// The claw machine voter draw.
///
/// Theatre over a result the server decided weeks ago — see [SpotsDraw]. The
/// screen's job is to replay that result legibly and then get out of the way.
///
/// One [AnimationController] drives the whole run. The design chains
/// `setTimeout`s per step; with a back button, a skip control and a ~15s run
/// there are three ways to leave mid-chain, and a controller is disposed
/// correctly by construction where a timer list is disposed correctly only if
/// nobody ever forgets.
class SpotsClawDrawScreen extends StatefulWidget {
  const SpotsClawDrawScreen({
    super.key,
    required this.draw,
    this.zoneName,
    this.week,
  });

  final SpotsDraw draw;
  final String? zoneName;
  final int? week;

  @override
  State<SpotsClawDrawScreen> createState() => _SpotsClawDrawScreenState();
}

class _SpotsClawDrawScreenState extends State<SpotsClawDrawScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late SpotsDraw _draw;
  late final AnimationController _run;

  /// The idle drift — `cabSway 3.4s ease-in-out infinite` in the design.
  ///
  /// Before anyone presses anything the claw slides gently left and right
  /// along its rail. A machine that sits perfectly still until tapped reads
  /// as a picture of a machine; the drift is what says it is powered up and
  /// waiting for you.
  ///
  /// Its own controller rather than a slice of [_run]: the two have opposite
  /// lifetimes — this one runs *until* the draw starts and stops forever
  /// after, where `_run` runs only during it.
  late final AnimationController _sway;

  /// Entrants the claw has already pulled — the winners so far.
  ///
  /// Named for the voter's outcome, not the claw's action. This set was once
  /// called `_lost` and fed straight into [ClawBallState.lost], which greyed
  /// out every winner and stamped it with 😢 while the voters who actually
  /// missed out stayed bright.
  final Set<int> _won = {};

  /// How many balls have been released into the glass so far.
  ///
  /// The balls do not all fall at once: each is released a beat after the one
  /// before it, so the pile loads the way a real machine is filled. A ball is
  /// airborne once its index is below this.
  int _released = 0;

  /// Timers for the staggered release and its haptics. Cancelled on dispose —
  /// this screen has a back button, a skip control and a ~15s run, so there
  /// are several ways to leave with these still pending.
  final List<Timer> _dropTimers = [];

  /// False until the entry animation has dropped every ball in.
  bool _dropped = false;

  /// Which grab (0-based) the run is on, and how far through it.
  int _grabIndex = 0;

  /// Guards the once-per-grab commit: [_run] ticks ~60×/second and the pull
  /// must happen on exactly one of those ticks.
  int _committed = 0;

  /// The machine's sound. Silent until the user asks for it — see [ClawAudio].
  final ClawAudio _audio = ClawAudio();

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draw = widget.draw;
    _run = AnimationController(vsync: this)..addListener(_onTick);
    // One full there-and-back cycle. The design's `cabSway` is 3.4s for a
    // half sweep under `alternate`, so a whole round trip is twice that.
    _sway = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dropped && _released == 0) {
      if (_reduceMotion) {
        // No drop-in: the balls are simply already in the machine.
        _dropped = true;
        _released = SpotsDrawGeometry.visibleSlots;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startDrop();
        });
      }
    }
    _syncSway();
  }

  /// Where the claw sits this frame while it is drifting.
  ///
  /// A **sine**, not a linear ramp bounced with `reverse: true`. Reversing a
  /// linear controller reaches each end at full speed and turns on the spot,
  /// which is what made the drift lurch rather than glide; a sine slows into
  /// each end and accelerates out of it, so the claw eases through the turn
  /// the way something with mass on a rail actually would.
  ///
  /// The controller therefore runs `repeat()` without reverse — the sine
  /// supplies the return leg — and one full cycle is one there-and-back.
  double get _swayX =>
      SpotsDrawGeometry.parkX +
      math.sin(_sway.value * 2 * math.pi) * SpotsDrawGeometry.swayReach;

  /// The marquee bulbs' chase position, 0–1, wrapping.
  ///
  /// ## Why the lights no longer go out when nothing is happening
  ///
  /// This used to be `picking ? (_run.value * 8) % 1.0 : 0` — the bulbs ran
  /// during the draw and were *frozen* every other second the screen was
  /// open. That is backwards for an arcade cabinet: the marquee is what a
  /// machine does while it waits for someone, and a dark one reads as
  /// unplugged. The one moment the screen most needs to look alive — a idle
  /// machine inviting a press — was the moment its lights were off.
  ///
  /// ## Why the speed no longer depends on the round
  ///
  /// The old expression was also tied to `_run.duration`, which scales with
  /// the pull count: a five-winner round chased at one rate and a three-winner
  /// round 1.67× faster, for no reason a viewer could name. A marquee has a
  /// fixed tempo; how many prizes are in the machine is not a property of its
  /// bulbs.
  ///
  /// So both phases derive from a controller running at a known period, and
  /// the chase runs at a constant ~1.2 cycles/sec either way. It is faster
  /// during the run than at rest, which is the one distinction worth keeping:
  /// the machine works up when it is working.
  double get _bulbPhase {
    if (_draw.phase == DrawPhase.picking) {
      // `_run` spans the whole performance, so its duration varies. Converting
      // to seconds first makes the tempo independent of the round's length.
      final seconds =
          _run.value * (_run.duration?.inMilliseconds ?? 0) / 1000.0;
      return (seconds * 1.8) % 1.0;
    }
    // `_sway` is already ticking while the machine is idle — 6.8s per cycle —
    // so the resting chase costs no extra ticker.
    //
    // It stops in exactly two cases, and a frozen phase is right for both: a
    // still controller leaves the bulbs at fixed, *different* brightnesses
    // rather than dark, so the rail still reads as a lit marquee that simply
    // is not chasing. Under reduced motion that is the whole point, and once
    // the draw is `done` the machine has finished its performance and a rail
    // still running would keep promising one.
    return (_sway.value * 6.8 * 1.2) % 1.0;
  }

  /// Runs the idle drift only while the machine is genuinely idle.
  ///
  /// Stopped under reduced motion, and stopped the moment the draw starts —
  /// once the claw is hunting, its position belongs entirely to the timeline
  /// and a second source nudging it sideways would fight the run.
  void _syncSway() {
    final wants = _draw.phase == DrawPhase.ready && !_reduceMotion;
    if (wants) {
      if (!_sway.isAnimating) _sway.repeat();
    } else {
      _sway.stop();
    }
  }

  /// Silences the machine when the app leaves the foreground.
  ///
  /// Without this, backgrounding mid-run leaves a 43-second loop — or a result
  /// sting — playing over whatever the user switched to. `dispose` does not
  /// help here: the screen is still mounted, it is the *app* that left.
  ///
  /// Coming back does not resume. The performance it was scoring has moved on
  /// without them, and music restarting under a finished draw is worse than
  /// silence; the speaker toggle is right there if they want it back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) {
      _audio.stopAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final t in _dropTimers) {
      t.cancel();
    }
    _run.dispose();
    _sway.dispose();
    // Fire-and-forget: `dispose` cannot await, and leaving this screen must
    // never be gated on an audio session closing. The players are stopped
    // inside, so nothing survives the screen.
    _audio.dispose();
    super.dispose();
  }

  /// The speaker toggle in the masthead.
  ///
  /// Enabling on an idle machine starts the bed; enabling once the draw is
  /// over does not, because the performance is finished and music arriving
  /// after the result would be scoring an empty stage.
  Future<void> _toggleSound() async {
    if (_audio.enabled) {
      await _audio.disable();
    } else {
      await _audio.enable(playBed: _draw.phase == DrawPhase.ready);
    }
    if (mounted) setState(() {});
  }

  // ==================== Loading the machine ====================

  /// Releases the balls one at a time, each with a haptic tick as it lands.
  ///
  /// The first frame must render them above the glass and a later frame must
  /// animate them down, so each ball's release is its own `setState` rather
  /// than one flag for the whole pile. The gaps are uneven on purpose —
  /// evenly spaced releases read as a conveyor, not as someone tipping a bag
  /// of balls into a machine.
  void _startDrop() {
    final count = _visible.length.clamp(0, SpotsDrawGeometry.visibleSlots);
    if (count == 0) {
      setState(() => _dropped = true);
      return;
    }

    for (var i = 0; i < count; i++) {
      // ~90ms apart, wobbling either side so no two gaps match.
      final releaseAt = 60 + i * 90 + (i.isEven ? 0 : 35);
      _dropTimers.add(
        Timer(Duration(milliseconds: releaseAt), () {
          if (!mounted) return;
          setState(() => _released = i + 1);
        }),
      );

      // The landing tick, fired when that ball's fall actually finishes
      // rather than when it starts — the vibration has to coincide with the
      // impact or it reads as unrelated buzzing.
      final landsAt = releaseAt + ClawCabinet.dropDurationFor(i);
      _dropTimers.add(
        Timer(Duration(milliseconds: landsAt), () {
          if (!mounted) return;
          // Light, not medium: this fires up to twelve times in under two
          // seconds, and a heavier impact repeated that often stops reading
          // as texture and starts reading as a malfunction.
          HapticFeedback.lightImpact();
          if (i == count - 1) setState(() => _dropped = true);
        }),
      );
    }
  }

  // ==================== The run ====================

  void _start() {
    if (!_draw.ctaEnabled) return;

    // Pressing the big button on an arcade cabinet *is* asking for the
    // arcade, so this is the second way sound gets enabled — the first being
    // the masthead's speaker toggle.
    //
    // `playBed: false` because `start()` owns the bed from here: it plays the
    // press sting and then starts the music under it if it is not already
    // running. Enabling with the bed on would race that — two `play` calls on
    // the same player in the same frame — and the ordering would be whichever
    // future resolved first.
    if (!_audio.enabled) _audio.enable(playBed: false);
    _audio.start();

    final started = _draw.start();

    // Reduced motion: the result without the performance. The outcome is
    // server-decided, so nothing is lost but the theatre — and this is the
    // same code path as SKIP, which is why skip costs almost nothing.
    if (_reduceMotion) {
      final finished = started.finish();
      setState(() {
        _draw = finished;
        // The pile still has to agree with the winner list, even when the
        // performance is skipped entirely.
        _won
          ..clear()
          ..addAll(finished.winners.map((w) => w.userId));
      });
      _announce('spots_claw_announce_picking'.tr);
      _onDone();
      return;
    }

    setState(() {
      _draw = started;
      _grabIndex = 0;
      _committed = 0;
    });
    _announce('spots_claw_announce_picking'.tr);
    _syncSway();

    _run
      ..duration = ClawGrabTimeline.total(_draw.effectivePulls)
      ..forward(from: 0);
  }

  void _onTick() {
    if (!mounted || _draw.phase != DrawPhase.picking) return;

    final pulls = _draw.effectivePulls;
    if (pulls == 0) return;

    // Global 0–1 split into per-grab local time.
    final global = _run.value * pulls;
    final index = global.floor().clamp(0, pulls - 1);
    final local = global - index;

    // Each grab commits its pull exactly once, at the release — the moment the
    // prongs open over the chute is the moment the winner row appears. That is
    // also what gates the reveal card, so the name and the row arrive together.
    if (index >= _committed &&
        ClawGrabTimeline.frameAt(local).stage == ClawStage.release) {
      _committed = index + 1;
      final pulled = _draw.winnerIds[index];
      setState(() {
        _won.add(pulled);
        _draw = _draw.pullNext();
      });
      // The pull is the beat the whole screen is built around, so it gets a
      // heavier tick than a ball landing — the two must not feel alike.
      HapticFeedback.mediumImpact();
      final winner = _draw.winners.last;
      _announce(
        'spots_claw_announce_winner'.trParams({
          'rank': '${winner.rank}',
          'name': winner.name,
        }),
      );
      if (_draw.phase == DrawPhase.done) _onDone();
    } else if (index != _grabIndex) {
      setState(() => _grabIndex = index);
    } else {
      // Nothing to do. The claw's position is *not* repainted from here.
      //
      // This used to be a bare `setState(() {})`, which rebuilt the entire
      // page — masthead, ticker, chute, winner rows, control deck — ~60 times
      // a second for the whole 15-second run, to move one painter. The
      // cabinet and the status line now listen to `_run` directly through
      // their own `AnimatedBuilder`s, exactly as the idle drift already
      // listened to `_sway`, so the frames that only change the claw's
      // position repaint only the claw.
      //
      // The two branches above still call `setState`: those are real draw
      // state changing (a winner committed, the grab index advancing), which
      // the whole page legitimately depends on. They fire at most twice per
      // grab rather than sixty times a second.
    }
  }

  void _onDone() {
    // Confetti when the machine finishes, per the design's `allDone`.
    //
    // It used to fire only when the signed-in user won, on the reasoning that
    // celebrating over someone else's win is tactless. The design takes the
    // other view and it is the better one here: this is a neighbourhood draw
    // being watched as an event, and the burst marks *the draw landing*, not
    // the viewer winning. The result itself is never ambiguous — a loser gets
    // "NOT THIS WEEK" in the same breath, so nothing about the burst can be
    // misread as "you won".
    //
    // Reduced motion is handled inside `showSpotsConfetti`, which no-ops.
    //
    // `from: context` is load-bearing: without a caller's context the helper
    // falls back to `Get.context`, which sits above the navigator and so has
    // no `Overlay` to insert into — the burst never appeared on this screen
    // or any other. `originY` puts the launch at the prize chute rather than
    // at the bottom of the screen, which is where the vote bar's default
    // sends it and well below where this screen's result lands.
    if (_draw.winners.isNotEmpty) {
      showSpotsConfetti(from: context, originY: 0.62);
    }

    // The result sting. This is the one funnel every ending passes through —
    // the full run, SKIP, and the reduced-motion jump — so the sound is
    // attached here rather than at three call sites that would drift apart.
    //
    // Keyed to [DrawOutcome], and deliberately silent for the third case.
    //
    // A win plays the win sting and a loss plays the losing one, both of which
    // are statements about the viewer. An **onlooker** — a guest, or anyone
    // who did not vote this round — gets neither: a defeat sting would tell
    // someone they lost a draw they were never in, which is the audio version
    // of the bug the chute's three-way label exists to avoid, and a win sting
    // would be celebrating someone else's prize at them.
    //
    // A draw with no winners at all is silent too: there is no result to
    // score.
    // The bed runs from the press until here. `result` cuts it as part of
    // playing the sting, but the silent branches have to cut it themselves —
    // otherwise an onlooker's draw ends with the music still looping under a
    // finished machine, which is the one state where it would never stop.
    switch (_draw.outcome) {
      case DrawOutcome.won:
        _audio.result(won: true);
      case DrawOutcome.lost:
        if (_draw.winners.isNotEmpty) {
          _audio.result(won: false);
        } else {
          _audio.stopAll();
        }
      case DrawOutcome.onlooker:
        _audio.stopAll();
    }
  }

  /// Phase changes and each winner are announced, because the cabinet is
  /// [ExcludeSemantics] and a screen reader would otherwise get no signal that
  /// anything happened between pressing the button and the list filling.
  void _announce(String message) {
    if (!mounted) return;
    // `SemanticsService.announce` is deprecated in favour of the view-scoped
    // form; `View.of` is how you get the view this screen is actually in.
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  // ==================== Frame ====================

  ClawGrabFrame get _frame {
    if (_draw.phase != DrawPhase.picking) {
      return const ClawGrabFrame(
        travel: 0,
        descend: 0,
        open: 1,
        held: false,
        ejected: 0,
      );
    }
    final pulls = _draw.effectivePulls;
    final global = _run.value * pulls;
    final local = global - global.floor().clamp(0, pulls - 1);
    return ClawGrabTimeline.frameAt(local);
  }

  /// The entrants actually in the glass — the one list the claw and the pile
  /// must agree on.
  ///
  /// Recomputed per build rather than cached because `visibleEntrants` is a
  /// cheap partition and caching it would mean invalidating on every phase
  /// change for no gain.
  List<DrawEntrant> get _visible =>
      _draw.visibleEntrants(SpotsDrawGeometry.visibleSlots);

  /// The pile index the current grab is aiming at.
  ///
  /// Indexes into [_visible], **not** `_draw.entrants`: with a pool larger
  /// than the twelve slots those two lists differ, and aiming by the full-list
  /// index would send the claw to an empty slot — or to a bystander's face.
  int get _targetSlot {
    if (_draw.phase != DrawPhase.picking) return 0;
    final id = _draw.winnerIds[_grabIndex.clamp(0, _draw.winnerIds.length - 1)];
    final i = _visible.indexWhere((e) => e.userId == id);
    return i < 0 ? 0 : i;
  }

  /// The entrant the claw is hunting right now, or null between grabs.
  ///
  /// Distinct from the held ball: this is what the beam points at and what
  /// the rest of the pile dims *around*, from the moment the claw sets off
  /// until it closes its jaws. Once the ball is in the jaws the hunt is over,
  /// so the spotlight goes out and the glass comes back up.
  int? get _targetId {
    if (_draw.phase != DrawPhase.picking) return null;
    // Lit from the moment the claw commits to crossing until it closes on the
    // ball. Deliberately *not* during `scan`: the machine has not chosen yet,
    // and lighting the target while it sweeps the other way gives the answer
    // away during the one step built to withhold it.
    switch (_frame.stage) {
      case ClawStage.seek:
      case ClawStage.drop:
      case ClawStage.grab:
        return _draw.winnerIds[_grabIndex.clamp(0, _draw.winnerIds.length - 1)];
      case ClawStage.scan:
      case ClawStage.lift:
      case ClawStage.carry:
      case ClawStage.release:
      case ClawStage.reveal:
        return null;
    }
  }

  /// "+653 MORE IN THE CLAW" — the hidden pool, under the CTA's label.
  ///
  /// The glass holds twelve balls and a real round draws from hundreds, so
  /// the button states the rest: without it the machine looks like a
  /// twelve-person raffle, which undersells the draw and invites "why is my
  /// face not in there?".
  ///
  /// A second line rather than text appended to the label, because the label
  /// is the *action* and this is a fact about the draw. Concatenating them
  /// also made the button's accessible name and its test finder into one long
  /// compound string, which is a smell in both.
  ///
  /// Once the draw has run it stops being about the pool and becomes the
  /// result's second line — the short form of what the consolation panel used
  /// to say below the machine. A pool size hung off "NOT THIS WEEK" would be
  /// noise; "vote again Monday to be back in" is the move that follows from
  /// it.
  String? _ctaSubLabel(bool done) {
    if (done) {
      // At the end the second line carries what the consolation panel's body
      // used to: the reason the headline above it matters and what to do
      // next. The panel's own copy is too long to sit under a 15pt label —
      // 74 characters against a button — so these are the short forms.
      //
      // An onlooker gets nothing here. "VOTE AGAIN MONDAY" already says the
      // whole thing for someone who was never in the draw, and a second line
      // under it would be padding.
      switch (_draw.outcome) {
        case DrawOutcome.won:
          return 'spots_claw_cta_sub_won'.tr;
        case DrawOutcome.lost:
          return 'spots_claw_cta_sub_lost'.tr;
        case DrawOutcome.onlooker:
          return null;
      }
    }
    final hidden = SpotsDrawGeometry.overflowCount(_draw.displayTotal);
    if (hidden <= 0) return null;
    return 'spots_claw_cta_more'.trParams({'count': '$hidden'});
  }

  /// The status line under a running claw, keyed to the step it is on.
  ///
  /// These are the design's own four labels, mapped onto its eight steps.
  String get _statusLabel {
    switch (_frame.stage) {
      case ClawStage.scan:
        return 'spots_claw_status_scanning'.tr;
      case ClawStage.seek:
      case ClawStage.drop:
      case ClawStage.grab:
        return 'spots_claw_status_locking'.tr;
      case ClawStage.reveal:
        return 'spots_claw_status_winner'.tr;
      case ClawStage.lift:
      case ClawStage.carry:
      case ClawStage.release:
        return 'spots_claw_status_working'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final picking = _draw.phase == DrawPhase.picking;

    return Scaffold(
      // Flat mint, with no dot grid painted over it.
      //
      // The grid was added here on the stated grounds that "every other
      // screen in this system stands on it". It does not: this was the only
      // screen in the app painting one. Every other Spots surface — the
      // prizes screen, place details, the submission flow — is flat
      // `Spots.canvas`, and `canvasDot` is used everywhere else as an
      // ordinary fill colour rather than as a texture.
      //
      // So the grid was not the system's background, it was a second
      // background invented for one screen, and it read as noise behind a
      // cabinet that is already the busiest object in the app.
      //
      // Was `Spots.canvas` (a cool grey that read as white behind the
      // cabinet); overridden on request to the system's own mint fill.
      backgroundColor: Spots.mint,
      body: SafeArea(child: _page(picking: picking)),
    );
  }

  /// Everything above the canvas: masthead, ticker, cabinet, result.
  ///
  /// Split out of [build] so the dot-grid painter and the content are siblings
  /// in one [Stack] rather than the whole page being nested inside a painter's
  /// child, which would repaint the grid on every one of the run's ~60 frames
  /// per second.
  Widget _page({required bool picking}) {
    return Column(
      children: [
        // Compile-time false unless --dart-define=SPOTS_DRAW_PREVIEW=true,
        // so this and the fixtures behind it are tree-shaken out of any
        // normal build. The ribbon exists so a screenshot of fake data can
        // never be read as real — see `home-preview-flags-mock-data`.
        if (kSpotsDrawPreview) const _PreviewRibbon(),
        ClawMasthead(
          eyebrow: _eyebrow,
          live: _draw.phase != DrawPhase.done,
          // Only offered when there is somewhere to go. Arriving from a
          // push notification cold, this screen can be the root of the
          // stack, and a back button that pops to a black screen is worse
          // than none at all.
          onBack: Navigator.canPop(context) ? () => Get.back() : null,
          soundOn: _audio.enabled,
          // Offered only when there is something to play. An empty round has
          // no performance and no result, so a speaker there would toggle
          // silence into silence.
          onToggleSound: _draw.isEmpty ? null : _toggleSound,
        ),
        ClawMarquee(running: _draw.phase != DrawPhase.done),
        Expanded(
          child: SingleChildScrollView(
            // Horizontal padding is applied per-section rather than to the
            // whole scroll view, so a section can opt out of the gutter if it
            // ever needs to bleed. Both sections currently sit on
            // [Spots.gutter]: the cabinet used to run 2pt wider than the page
            // content below it, which read as a misalignment rather than as
            // emphasis.
            //
            // The bottom pad clears the home indicator the way the rest of
            // Spots does — `places_home_screen` ends its sliver padding on
            // `MediaQuery.padding.bottom + Spots.s24` for the same reason.
            // A flat 24 left the fairness line sitting under the gesture bar
            // on a notched phone, which is where this screen's last piece of
            // real copy lives.
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + Spots.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The machine as one physical object.
                //
                // The design frames the glass, its header strip, the CTA
                // and the hint inside a single mint chassis — the cabinet
                // is a thing you stand in front of, not four stacked
                // sections that happen to be about a claw. Splitting them
                // onto the page background (which is what this screen did
                // first) loses the one idea the whole screen rests on.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spots.gutter),
                  child: _machine(picking: picking),
                ),
                // The consolation panel that used to sit here is gone.
                //
                // It carried the loser's result — a trophy, "NOT THIS WEEK",
                // and two lines of body — in a card *below* the machine,
                // while the button inside the machine, in the thumb zone,
                // said "VOTE AGAIN MONDAY". Two surfaces for one message,
                // with the headline in the quieter one and the screen's
                // loudest element carrying the footnote.
                //
                // The control deck now states the outcome and the move that
                // follows from it, which is the same information in the
                // position the eye and the thumb are already on. Repeating it
                // underneath would be the duplication this removed.
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _eyebrow => 'spots_claw_eyebrow'.trParams({
    'zone': widget.zoneName ?? '',
    'week': '${widget.week ?? ''}',
  });

  /// The cabinet: deep-teal shell, mint brow, glass, prize chute, controls.
  ///
  /// A [Spots.panel] moulding, flat on the page — the mint is reserved for
  /// the brow, the glass, the chute's rings and the CTA. A dark object
  /// holding a lit window reads as an arcade cabinet; a mint box holding a
  /// dark one reads as a card about an arcade cabinet.
  ///
  /// This is the screen's one licensed departure from the Spots geometry — a
  /// 26pt radius where the system says 16 — because the cabinet is a moulded
  /// object rather than a printed card. It still wears the system's drawn
  /// teal border, and everything outside it on this screen is ordinary
  /// Spots. See [ClawTokens].
  Widget _machine({required bool picking}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: ClawTokens.shellFill,
        borderRadius: BorderRadius.circular(ClawTokens.rShell),
        // The drawn teal border is the one piece of the Spots language the
        // cabinet does keep. Its radius and its soft drop are the sanctioned
        // exception — a moulded object, not a printed card — but a borderless
        // shell on the dot-grid canvas floated, because in this system an
        // object's edge is *drawn*. The border is what lands it on the page.
        border: Border.all(color: Spots.border, width: Spots.borderThick),
        boxShadow: ClawTokens.shell,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_draw.isEmpty)
            ClawHeaderStrip(
              pulled: _draw.winners.length,
              total: _draw.effectivePulls,
            ),
          const SizedBox(height: Spots.s12),
          // The cabinet carries no information a screen reader needs: every
          // identity in it is repeated as real text below.
          // Rebuilt against the two controllers that move it, and nothing
          // else on the screen with it.
          //
          // Both phases of this screen animate the same painter: `_sway`
          // drifts the claw while the machine is idle, `_run` drives it
          // through the whole performance. Neither belongs on the page's
          // `setState` — the run's frames used to rebuild the masthead, the
          // ticker, the chute and the control deck sixty times a second to
          // move one claw, none of which change between pulls.
          //
          // `Listenable.merge` is what lets the two live under one builder:
          // only one of them is ever animating (see `_syncSway`, which stops
          // the drift the moment the draw starts), so this repaints at 60fps
          // for whichever is currently running and is idle otherwise.
          ExcludeSemantics(
            child: AnimatedBuilder(
              animation: Listenable.merge([_sway, _run]),
              builder: (context, _) {
                final idle = _draw.phase == DrawPhase.ready;
                // Derived here rather than passed in, so that reading a new
                // frame costs a repaint of the cabinet and not of the page.
                final frame = _frame;

                // The claw's x is three blended moves, not one.
                //
                // Park → scan sweeps it *away* from the target; scan → target
                // brings it across; target → chute carries the ball out.
                // Blending rather than switching is what makes the run one
                // continuous travel instead of four separate slides with a
                // stop between each.
                //
                // While idle all of this is ignored and the position comes
                // from the sway instead.
                final targetX = SpotsDrawGeometry.clawXFor(_targetSlot);
                final scanned =
                    SpotsDrawGeometry.parkX +
                    (SpotsDrawGeometry.scanX - SpotsDrawGeometry.parkX) *
                        frame.scanAway;
                final sought = scanned + (targetX - scanned) * frame.travel;
                final clawX =
                    sought + (SpotsDrawGeometry.chuteX - sought) * frame.carry;

                final clawY =
                    SpotsDrawGeometry.parkY +
                    (SpotsDrawGeometry.clawYFor(_targetSlot) -
                            SpotsDrawGeometry.parkY) *
                        frame.descend;

                final heldId =
                    frame.held && picking
                        ? _draw.winnerIds[_grabIndex.clamp(
                          0,
                          _draw.winnerIds.length - 1,
                        )]
                        : null;

                return ClawCabinet(
                  // Winner-guaranteed, not just the payload's first 12: the
                  // claw must never reach for a face that was not already in
                  // the glass. See `visibleEntrants`.
                  entrants: _visible,
                  clawX: idle ? _swayX : clawX,
                  clawY: clawY,
                  clawOpen: frame.open,
                  heldEntrantId: heldId,
                  targetEntrantId: _targetId,
                  // The knock, only while the prongs are actually biting.
                  shake:
                      frame.stage == ClawStage.grab
                          ? (1 - frame.open).clamp(0.0, 1.0)
                          : 0,
                  wonEntrantIds: _won,
                  // The non-picked only mourn once the draw is actually over.
                  // Greying them out mid-run would call the result before the
                  // claw has finished reaching for them.
                  drawClosed: _draw.phase == DrawPhase.done,
                  releasedCount: _released,
                  bulbPhase: _bulbPhase,
                  totalEntrants: _draw.totalEntrants,
                  week: widget.week,
                  lighting:
                      picking ? ClawLighting.twinCones : ClawLighting.topWash,
                );
              },
            ),
          ),
          if (!_draw.isEmpty) ...[
            const SizedBox(height: Spots.s12),
            // The chute is now the *only* place a winner's name survives on
            // screen — the "pulled by the claw" list below it was removed —
            // so unlike the cabinet it is not excluded from semantics. Each
            // filled slot carries a `pick N, name` label of its own; see
            // `ClawChute`. Excluding it would leave a screen-reader user with
            // the run's announcements and nothing afterwards.
            ClawChute(winners: _draw.winners, totalPulls: _draw.effectivePulls),
          ],
          const SizedBox(height: Spots.s12),
          _controlDeck(),
          // How the draw actually works, stated on the machine.
          //
          // This screen is a prize draw whose entry is voting, dressed as a
          // claw machine — and a real claw machine is a game of skill that is
          // famously rigged. Both halves of that invite the same suspicion:
          // that voting more improves your odds, or that the claw was aimed.
          // Neither is true, the copy to say so was already written and
          // translated, and it was rendering nowhere.
          //
          // It sits under the CTA rather than in the ticker because the
          // ticker scrolls it out of view, and a fairness statement that is
          // only sometimes on screen is not a fairness statement. Hidden
          // mid-run: the claw is mid-reach, and a line about randomness
          // arriving exactly then reads as the machine defending itself.
          if (!_draw.isEmpty && _draw.phase != DrawPhase.picking) ...[
            const SizedBox(height: Spots.s12),
            Text(
              'spots_claw_fair'.tr,
              textAlign: TextAlign.center,
              style: waddyRegular.copyWith(
                fontSize: 10,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The control deck — the CTA, or the run's status while it is going.
  ///
  /// The design flanks the button with ◀ ▶ plates. They are omitted: nothing
  /// in the payload is previous or next, and a 44pt control that looks
  /// pressable and does nothing is worse than no control.
  ///
  /// v2 drops the recessed plate the button used to sit on, and the hint line
  /// under it. The shell is already the surround, and the hint said what the
  /// button says — the chute's own readout now carries the count that was the
  /// only part of it doing work.
  Widget _controlDeck() {
    if (_draw.isEmpty) return _empty();
    return _cta();
  }

  Widget _cta() {
    final picking = _draw.phase == DrawPhase.picking;
    final done = _draw.phase == DrawPhase.done;

    // At `done` the draw is over and `ctaEnabled` is false forever after, so
    // this slot used to render a dead "THAT'S THE DRAW" plate — 48pt of the
    // machine's control deck, in the thumb zone, doing nothing. It is the best
    // position on the screen for the one thing the user should do next, so the
    // finished state hands it a real action instead of a label: the winner
    // goes to their voucher, everyone else goes back to vote for next week.
    // `hasVoucher`, not `iWon`: a demo win carries a sentinel prize id so the
    // whole win path can be shown on an account with no prize row, and
    // routing to that id would open a details screen with nothing in it.
    // The label still says the user won — only the navigation is withheld.
    final VoidCallback? doneAction =
        !done
            ? null
            : _draw.hasVoucher
            ? () => Get.toNamed(
              RouteHelper.getSpotsPrizeDetailsRoute(_draw.myPrizeId!),
            )
            // The vote surface is a dashboard tab, not a route of its own, and
            // this screen is reachable from a push with no dashboard beneath
            // it. `goToTab` drives a mounted dashboard and replaces the stack
            // when there is none, which is the only correct move from here.
            : () => RouteHelper.goToTab(RouteHelper.tabExplore);

    // While the claw is working, v2 replaces the button entirely with a
    // status row: a blinking lamp and the step the machine is on. The old
    // screen left a dead, greyed-out button in the thumb zone for fifteen
    // seconds, which invites tapping at exactly the moment nothing can
    // happen. A row that is visibly not a button does not.
    if (picking) {
      // A plain container, no longer a `Row` holding this beside a SKIP
      // button: with SKIP gone the wrapper was an `Expanded` with one child,
      // which is a `SizedBox.expand` written the long way.
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: Spots.s12),
        decoration: BoxDecoration(
          color: Spots.teal900,
          borderRadius: BorderRadius.circular(Spots.radiusMd),
          border: Border.all(
            color: Spots.mint.withValues(alpha: 0.28),
            width: Spots.borderThin,
          ),
        ),
        child: Row(
          children: [
            _RunLamp(pulse: _run),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                // The key the a11y suite taps for is the label of the
                // *state*, so it stays on this row: mid-run, "the claw
                // is working" is what the control area says.
                displayCaps('spots_claw_cta_picking'.tr),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Spots.kicker(
                  12,
                  color: Colors.white.withValues(alpha: 0.88),
                  tracking: 0.1,
                ),
              ),
            ),
            // The live step — "LOCKING ON…" — as quiet trailing text.
            // It changes four times per grab, so it cannot be the loud
            // element or the deck flickers for the whole run.
            //
            // Unscaled and capped: this is machine chrome sitting beside
            // the label a screen reader actually needs, and at 2.0 scale
            // the unbounded pair ran 55px past the deck.
            //
            // Its own `AnimatedBuilder` for the same reason the cabinet
            // has one: the stage it reads changes continuously through
            // the run, and this is the only element in the deck that
            // cares. Rebuilding the row around it — lamp, label, SKIP
            // button — to retype two words would be the page-wide
            // `setState` all over again, one scope down.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: AnimatedBuilder(
                animation: _run,
                builder:
                    (context, _) => Text(
                      displayCaps(_statusLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                      style: Spots.kicker(
                        9,
                        color: Spots.mint.withValues(alpha: 0.7),
                        tracking: 0.12,
                      ),
                    ),
              ),
            ),
          ],
        ),
      );
    }

    // Once the draw is over the button *is* the result.
    //
    // The outcome used to live in a separate panel below the machine — "NOT
    // THIS WEEK", a trophy and two lines of body copy — while the button in
    // the thumb zone said "VOTE AGAIN MONDAY". That is two cards saying one
    // thing, with the headline in the quieter of the two and the loudest
    // element on the screen carrying the footnote. The result belongs in the
    // best position on the screen, so it takes it, and the panel goes.
    //
    // Keyed to [DrawOutcome] rather than `iWon`, for the same reason the
    // chute's label is: a guest who never entered has not "not won this
    // week", and telling them so is a claim about a draw they were never in.
    // They keep the plain invitation to vote.
    final String label;
    if (!done) {
      label = 'spots_claw_cta_ready'.tr;
    } else {
      switch (_draw.outcome) {
        case DrawOutcome.won:
          // "See my voucher" only when there is one to see. A demo win has no
          // prize row behind it, so the button offers the next round instead
          // of promising a voucher it cannot open.
          label =
              _draw.hasVoucher
                  ? 'spots_claw_cta_see_voucher'.tr
                  : 'spots_claw_cta_vote_again'.tr;
        case DrawOutcome.lost:
          label = 'spots_claw_consolation_title'.tr;
        case DrawOutcome.onlooker:
          label = 'spots_claw_cta_vote_again'.tr;
      }
    }

    final sub = _ctaSubLabel(done);

    // The CTA is a Spots button: a mint slab with a drawn teal border that
    // slides onto a hard offset plate when pressed.
    //
    // It used to be a borderless slab with a CSS `inset 0 -4px 0` lip and no
    // press movement at all — a faithful port of the web design, and the one
    // control on the screen that behaved unlike every other button in the app.
    // The neubrutalist press *is* the affordance in this system, so the button
    // now has a border to define its edge and a plate to travel onto.
    //
    // The done-state action is an offer rather than the main event, so it
    // steps down to the dark panel fill instead of competing with the mint the
    // machine's own brow is already wearing.
    final enabled = _draw.ctaEnabled || doneAction != null;
    final Color fill =
        !enabled
            ? Spots.teal900
            : done
            ? Spots.teal900
            : Spots.mint;
    final Color ink =
        !enabled
            ? Colors.white.withValues(alpha: 0.4)
            : done
            ? Spots.mint
            : Spots.teal;

    return SpotsPressable(
      enabled: enabled,
      onTap: done ? doneAction : (enabled ? _start : null),
      radius: Spots.radiusMd,
      // No plate while disabled: a shadow under a dead control advertises a
      // press that will not happen.
      dx: enabled ? 4 : 0,
      dy: enabled ? 4 : 0,
      shadowColor: Spots.teal900,
      child: Container(
        // Taller when it carries the pool count, so the two lines are not
        // crushed against the slab's edges.
        height: sub == null ? 56 : 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Spots.radiusMd),
          border: Border.all(
            color:
                enabled && !done
                    ? Spots.teal
                    : Spots.mint.withValues(alpha: 0.35),
            width: enabled && !done ? Spots.borderThick : Spots.borderThin,
          ),
        ),
        // The label must never be the thing that sets the button's width.
        // FittedBox shrinks it instead of ellipsising, because a CTA reading
        // "RUN THE D…" is worse than one reading small.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spots.s16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayCaps(label),
                  maxLines: 1,
                  style: Spots.kicker(15, color: ink, tracking: 0.14),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    displayCaps(sub),
                    maxLines: 1,
                    style: Spots.kicker(
                      9,
                      // Sits *on* the mint slab, so it steps down in opacity
                      // rather than switching colour — a second ink here
                      // would read as two unrelated labels stacked.
                      color: ink.withValues(alpha: 0.6),
                      tracking: 0.16,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The empty round, on the shell where the controls would be.
  ///
  /// Light on dark, because in v2 this sits *inside* the machine rather than
  /// on the page: a warm-paper card in the control deck of a deep-teal
  /// cabinet reads as a sticker someone left on it.
  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spots.s16),
      decoration: BoxDecoration(
        color: Spots.teal900,
        borderRadius: BorderRadius.circular(Spots.radiusMd),
        border: Border.all(
          color: Spots.mint.withValues(alpha: 0.28),
          width: Spots.borderThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayCaps('spots_claw_empty_title'.tr),
            style: Spots.kicker(11, color: Spots.mint, tracking: 0.18),
          ),
          const SizedBox(height: Spots.s8),
          Text(
            'spots_claw_empty_body'.tr,
            style: waddyRegular.copyWith(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// The blinking lamp on the status row while the claw is working.
///
/// Driven off the run controller the screen already owns rather than a
/// controller of its own. The run ticks ~60×/s for the whole performance and
/// stops dead at the end, which is exactly the lifetime this lamp wants — a
/// second controller would be one more thing to dispose and one more ticker
/// alive after the result has landed.
class _RunLamp extends StatelessWidget {
  const _RunLamp({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    const dot = DecoratedBox(
      decoration: BoxDecoration(color: Spots.mint, shape: BoxShape.circle),
      child: SizedBox(width: 7, height: 7),
    );

    if (MediaQuery.of(context).disableAnimations) return dot;

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        // ~0.85s per blink over a run whose value sweeps 0→1 once: multiplying
        // up and taking a triangle wave gives the blink its own tempo without
        // caring how many pulls the round has.
        final t = (pulse.value * 18) % 1.0;
        return Opacity(
          opacity: 0.25 + (t < 0.5 ? t * 2 : (1 - t) * 2) * 0.75,
          child: child,
        );
      },
      child: dot,
    );
  }
}

/// A loud, unmissable band stating that nothing on this screen is real.
///
/// Only ever built when [kSpotsDrawPreview] was compiled in, so it costs
/// nothing in a normal build.
class _PreviewRibbon extends StatelessWidget {
  const _PreviewRibbon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Spots.red,
        border: Border(
          bottom: BorderSide(color: Spots.border, width: Spots.borderThick),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: Spots.s4),
      alignment: Alignment.center,
      child: Text(
        displayCaps('spots_claw_preview_ribbon'.tr),
        maxLines: 1,
        style: Spots.kicker(10, color: Colors.white),
      ),
    );
  }
}
