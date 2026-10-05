import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/spots_draw_round_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';

/// The way into the claw from the Spots home, once a round has closed.
///
/// The week's champion is crowned and, in the same transaction, the server
/// draws winners from **that venue's voters**. This card says so and opens
/// the replay. It is reachable by winner, loser and onlooker alike — the
/// draw being visible to everyone is what makes it believable to the winner.
///
/// Renders nothing until a round with entrants exists: before the first
/// close, an empty "the claw" card would only advertise a feature with
/// nothing in it.
class ClawDrawEntryCard extends StatelessWidget {
  const ClawDrawEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      id: PlacesController.idDraw,
      builder: (controller) {
        final SpotsDrawRound? round = controller.latestDraw;
        if (round == null || round.draw.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: Spots.sectionGap),
          child: _Card(round: round),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.round});

  final SpotsDrawRound round;

  String get _kicker {
    final week = round.week;
    return week == null
        ? 'spots_claw_card_kicker'.tr
        : 'spots_claw_card_kicker_week'.trParams({'week': '$week'});
  }

  String get _title {
    switch (round.draw.outcome) {
      case DrawOutcome.won:
        return 'spots_claw_card_title_won'.tr;
      case DrawOutcome.lost:
        return 'spots_claw_card_title_entered'.tr;
      case DrawOutcome.onlooker:
        return 'spots_claw_card_title'.tr;
    }
  }

  String get _body {
    final draw = round.draw;
    final place = round.placeTitle;
    final params = {
      'place': place ?? '',
      'count': '${draw.displayTotal}',
      'pulls': '${draw.effectivePulls}',
    };
    return (place == null
            ? 'spots_claw_card_body_no_place'
            : 'spots_claw_card_body')
        .trParams(params);
  }

  void _open() {
    Get.toNamed(
      RouteHelper.getSpotsClawDrawRoute(period: round.period),
      // Already fetched — the claw opens on it without a second round trip.
      arguments: round,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool won = round.draw.outcome == DrawOutcome.won;

    return Semantics(
      button: true,
      label: '$_title. $_body',
      excludeSemantics: true,
      child: SpotsPressable(
        onTap: _open,
        child: Container(
          width: double.infinity,
          decoration: Spots.card(
            fill: Spots.panel,
            dx: 0,
            dy: 0,
          ),
          padding: const EdgeInsets.all(Spots.s16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: won ? Spots.mint : Spots.teal,
                  border: Border.all(color: Spots.mint, width: Spots.borderThin),
                  borderRadius: BorderRadius.circular(Spots.radiusMd),
                ),
                child: Icon(
                  won ? Icons.emoji_events_rounded : Icons.toys_rounded,
                  size: 28,
                  color: won ? Spots.teal : Spots.mint,
                ),
              ),
              const SizedBox(width: Spots.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayCaps(_kicker),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Spots.kicker(10, color: Spots.mint),
                    ),
                    const SizedBox(height: Spots.s4),
                    Text(
                      displayCaps(_title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Spots.display(18, color: Colors.white),
                    ),
                    const SizedBox(height: Spots.s4),
                    Text(
                      _body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: waddyRegular.copyWith(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: Spots.s8),
                    Text(
                      displayCaps('spots_claw_watch_draw'.tr),
                      style: Spots.kicker(11, color: Spots.mint, tracking: 0.08),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Spots.mint,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
