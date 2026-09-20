import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/spots/spots_marquee.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// The claw screen's ticker — three phrases on a seamless loop.
///
/// The scroll itself is [SpotsMarquee], shared with the Spots home ticker
/// rather than reimplemented: it already handles RTL, the faded edge, text
/// scale and the short-run case.
///
/// Pauses under reduced motion and whenever [running] goes false, which the
/// screen sets when the ticker scrolls off-screen — a marquee animating behind
/// a result list is spending frames on something nobody is looking at.
class ClawMarquee extends StatefulWidget {
  const ClawMarquee({super.key, this.running = true});

  final bool running;

  @override
  State<ClawMarquee> createState() => _ClawMarqueeState();
}

class _ClawMarqueeState extends State<ClawMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll;

  @override
  void initState() {
    super.initState();
    // The design's 20s linear translate of a duplicated run.
    _scroll = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ClawMarquee old) {
    super.didUpdateWidget(old);
    if (old.running != widget.running) _sync();
  }

  void _sync() {
    final wants = widget.running && !MediaQuery.of(context).disableAnimations;
    if (wants) {
      if (!_scroll.isAnimating) _scroll.repeat();
    } else {
      _scroll.stop();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phrases =
        [
          'spots_claw_ticker_one'.tr,
          'spots_claw_ticker_two'.tr,
          'spots_claw_ticker_three'.tr,
        ].map(displayCaps).toList();

    // The ticker is a Spots news bar, matching `LiveNewsBar` on the Spots
    // home: a dark panel card carrying white text, sitting on the canvas.
    //
    // It previously ran as muted ink directly on the page, which left it
    // reading as a stray caption rather than as the app's ticker — the one
    // element on this screen that *is* a shared Spots component was the one
    // dressed to look unlike it.
    final style = waddyBlack.copyWith(
      fontSize: 10,
      color: Colors.white.withValues(alpha: 0.82),
      letterSpacing: displayTracking(0.18 * 10),
      height: 1.3,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spots.gutter,
        Spots.s12,
        Spots.gutter,
        Spots.s4,
      ),
      child: Container(
        height: 30,
        alignment: Alignment.centerLeft,
        decoration: Spots.card(
          fill: Spots.panel,
          radius: Spots.radiusMd,
          borderWidth: Spots.borderThin,
          dx: 2,
          dy: 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: Spots.s12),
        child: SpotsMarquee(
          controller: _scroll,
          text: phrases.join('     '),
          style: style,
        ),
      ),
    );
  }
}
