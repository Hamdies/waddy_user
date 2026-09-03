import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/common/widgets/spots/spots_l10n.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// Live movement ticker under the voters podium — a pulsing LIVE pill next to a
/// looping marquee of this week's real standings movement. Mirrors `.newsbar`.
class LiveNewsBar extends StatefulWidget {
  final String? leaderName;
  const LiveNewsBar({super.key, this.leaderName});

  @override
  State<LiveNewsBar> createState() => _LiveNewsBarState();
}

class _LiveNewsBarState extends State<LiveNewsBar>
    with TickerProviderStateMixin {
  late final AnimationController _marquee;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _marquee = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: freeze both the marquee and the pulse.
    if (MediaQuery.of(context).disableAnimations) {
      _marquee.stop();
      _pulse.stop();
    } else {
      if (!_marquee.isAnimating) _marquee.repeat();
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _marquee.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Build ticker lines from real standings, falling back to a generic nudge.
  List<String> _lines(PlacesController c) {
    final lines = <String>[];
    final standings = c.liveStandings;
    // While the board is warming up, a marquee of "X — 1 VOTE" reads as empty;
    // skip the thin per-place counts and lead with an invitation instead.
    final totalVotes = standings.fold<int>(0, (sum, p) => sum + p.votesCount);
    final warmingUp = totalVotes < 5;

    if (warmingUp) {
      lines.add(displayCaps('spots_ticker_warming_up'.tr));
    }
    for (final p in standings.take(4)) {
      final d = c.rankDeltaFor(p.id);
      final name = displayCaps(p.title);
      if (d != null && d > 0) {
        lines.add(
          displayCaps(
            trPlural('spots_ticker_climbed', d, params: {'name': name}),
          ),
        );
      } else if (c.isNewOnBoard(p.id)) {
        lines.add(displayCaps('spots_ticker_entered'.trParams({'name': name})));
      } else if (!warmingUp && p.votesCount > 0) {
        lines.add(
          displayCaps(
            trPlural(
              'spots_ticker_week_votes',
              p.votesCount,
              params: {'name': name},
            ),
          ),
        );
      }
    }
    if (lines.isEmpty) {
      lines.add(displayCaps('spots_ticker_voting_live'.tr));
      if (widget.leaderName != null) {
        lines.add(
          displayCaps(
            'spots_ticker_leads_voters'.trParams({
              'name': displayCaps(widget.leaderName!),
            }),
          ),
        );
      }
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<PlacesController>();
    final lines = _lines(c);
    final run = lines.join('   •   ');
    final reduce = MediaQuery.of(context).disableAnimations;
    final textStyle = waddyBlack.copyWith(
      fontSize: 11,
      color: Colors.white,
      letterSpacing: displayTracking(0.03 * 11),
      height: 1.3,
    );

    return Container(
      decoration: Spots.card(fill: Spots.panel, radius: Spots.radiusMd),
      padding: const EdgeInsets.symmetric(
        horizontal: Spots.s8,
        vertical: Spots.s8,
      ),
      child: Row(
        children: [
          // LIVE pill with pulsing dot
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spots.s8,
              vertical: Spots.s4,
            ),
            decoration: BoxDecoration(
              color: Spots.red,
              borderRadius: BorderRadius.circular(Spots.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: Tween(begin: 1.0, end: 0.3).animate(_pulse),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: Spots.s4),
                Text(
                  displayCaps('spots_live'.tr),
                  style: waddyBlack.copyWith(
                    fontSize: 10,
                    color: Colors.white,
                    letterSpacing: displayTracking(0.08 * 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spots.s12),
          // Looping marquee — static first line under reduced motion.
          Expanded(
            child:
                reduce
                    ? Text(
                      lines.first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle,
                    )
                    : _Marquee(
                      controller: _marquee,
                      text: run,
                      style: textStyle,
                    ),
          ),
        ],
      ),
    );
  }
}

/// Seamlessly-looping text marquee. Measures the run once per text/style/scale
/// change with a [TextPainter], lays out two copies inside an [OverflowBox] so
/// it never overflows its slot, and slides in the reading direction by
/// `t * (width + gap)` so the second copy takes over exactly as the first exits.
class _Marquee extends StatefulWidget {
  final AnimationController controller;
  final String text;
  final TextStyle style;

  const _Marquee({
    required this.controller,
    required this.text,
    required this.style,
  });

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> {
  static const double _gap = 40;
  double _width = 0;
  double _height = 16;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measure();
  }

  @override
  void didUpdateWidget(_Marquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _measure();
    }
  }

  void _measure() {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    _width = tp.width;
    _height = tp.height;
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final label = Text(
      widget.text,
      maxLines: 1,
      softWrap: false,
      style: widget.style,
    );

    // A run that already fits its slot must not scroll. Two copies separated by
    // `_gap` are laid out unconditionally, so on a short run (one warming-up
    // line, say) the second copy is inside the visible slot from the first
    // frame — it reads as text bleeding under the LIVE pill, not as motion.
    // Motion here is meant to carry overflow; with nothing to overflow there is
    // nothing for it to carry.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_width <= constraints.maxWidth) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }
        return _buildMarquee(rtl, label);
      },
    );
  }

  Widget _buildMarquee(bool rtl, Widget label) {

    // A marquee cut dead-flat at the panel edge reads as a text-overflow bug,
    // not as motion. Fading the trailing edge (leading too, in RTL) makes the
    // run visibly *pass through* the slot instead of being sliced by it.
    return ShaderMask(
      shaderCallback:
          (rect) => LinearGradient(
            begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
            end: rtl ? Alignment.centerLeft : Alignment.centerRight,
            stops: const [0.0, 0.04, 0.88, 1.0],
            colors: const [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
          ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ClipRect(
        child: SizedBox(
          height: _height,
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              animation: widget.controller,
              builder:
                  (context, _) => Transform.translate(
                    offset: Offset(
                      (rtl ? 1 : -1) *
                          widget.controller.value *
                          (_width + _gap),
                      0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [label, const SizedBox(width: _gap), label],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
