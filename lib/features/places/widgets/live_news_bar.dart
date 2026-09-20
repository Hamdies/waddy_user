import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/common/widgets/spots/spots_l10n.dart';
import 'package:waddy_app/common/widgets/spots/spots_marquee.dart';
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
    //
    // This used to be a local `totalVotes < 5`, sitting beside
    // `SpotsStage.warmThreshold = 5` on the controller — two copies of one
    // threshold that agreed by coincidence, on exactly the value the enum was
    // written to centralise. The ticker and the hero could still reach
    // opposite conclusions about one board the moment either number moved.
    // See `S-03`.
    final warmingUp = c.stage.isCold;

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
    // Subscribed, not just read. This used to be a bare
    // `Get.find<PlacesController>()` with no builder around it, so the ticker
    // repainted only when its *parent* did — the podium's
    // `GetBuilder(id: idTopVoters)`. It rendered standings and ▲/▼ movement
    // and updated when the voters list changed instead. It was correct by
    // accident: `refreshRankDeltas`, whose whole job is recomputing the
    // movement shown here, happens to notify `idTopVoters` alongside
    // `idLeaderboard`. Drop that and the arrows freeze silently. This is
    // standings data, so it says so. See `S-07`.
    return GetBuilder<PlacesController>(
      id: PlacesController.idLeaderboard,
      builder: (c) => _buildBar(context, c),
    );
  }

  Widget _buildBar(BuildContext context, PlacesController c) {
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
                    : SpotsMarquee(
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
