import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/domain/spots_round.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// The anticipation headline + live "this round ends in" bar.
/// Mirrors `.anthd` + `.roundbar` from templates/home/Home.dc.html.
///
/// Both the timer and the "crown locks" label now derive from
/// [SpotsRound.lockAt]. They previously disagreed by three hours — the label
/// rendered the lock instant minus 3h — so the bar stated two deadlines at
/// once. See [SpotsRound] for the pending backend contract.
class RoundCountdownBar extends StatefulWidget {
  const RoundCountdownBar({super.key});

  @override
  State<RoundCountdownBar> createState() => _RoundCountdownBarState();
}

class _RoundCountdownBarState extends State<RoundCountdownBar>
    with WidgetsBindingObserver {
  Timer? _timer;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _left = SpotsRound.remaining();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode registers a dependency: this re-runs when a route covers or
    // uncovers the page, pausing the timer while we're not visible.
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      _syncTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// 1Hz always — a countdown that only moves once a minute reads as a frozen
  /// screenshot, and this is the screen's live heartbeat. The cost is one text
  /// repaint per second, and the timer is cancelled outright whenever the page
  /// is covered or the app is backgrounded (see [_syncTimer] callers).
  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!TickerMode.valuesOf(context).enabled) return;
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _left = SpotsRound.remaining());
  }

  @override
  Widget build(BuildContext context) {
    // Same instant the timer above is counting down to — not a shifted one.
    final lockLabel = SpotsRound.lockLabel();
    final urgent = SpotsRound.isUrgent(_left);

    return Container(
      decoration: Spots.card(fill: Spots.panel),
      padding: const EdgeInsets.symmetric(
        horizontal: Spots.s16,
        vertical: Spots.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 12,
                      color: urgent ? Spots.red : Spots.mint,
                    ),
                    const SizedBox(width: Spots.s4),
                    Flexible(
                      child: Text(
                        displayCaps('spots_round_ends_in'.tr),
                        style: Spots.kicker(
                          10,
                          color: urgent ? Spots.red : Spots.mint,
                          tracking: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spots.s4),
                Text(
                  SpotsRound.countdown(_left),
                  style: waddyBlack.copyWith(
                    fontSize: 27,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: displayTracking(0.02 * 27),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Spots.s4),
              Text(
                lockLabel, // already caps-folded by SpotsRound.lockLabel()
                style: waddyBold.copyWith(
                  fontSize: 10,
                  color: Spots.mint,
                  letterSpacing: displayTracking(0.04 * 10),
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
