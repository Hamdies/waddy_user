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

  /// One short line. The venue, the week and the full sentence lived here
  /// once; the draw screen says all of that, and a card that tries to is the
  /// loudest thing on a screen whose job is the board below it.
  String get _sub => 'spots_claw_card_sub'.trParams({
    'pulls': '${round.draw.effectivePulls}',
    'count': '${round.draw.displayTotal}',
  });

  void _open() {
    Get.toNamed(
      RouteHelper.getSpotsClawDrawRoute(period: round.period),
      // Already fetched — the claw opens on it without a second round trip.
      arguments: round,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$_title. $_sub. ${'spots_claw_watch_draw'.tr}',
      excludeSemantics: true,
      child: SpotsPressable(
        onTap: _open,
        child: Container(
          width: double.infinity,
          // A slim mint strip: the claw is news, not a section, so it sits as
          // one line of colour between the countdown and the board.
          decoration: Spots.card(fill: Spots.mint, dx: 0, dy: 0),
          padding: const EdgeInsets.symmetric(
            horizontal: Spots.s12,
            vertical: Spots.s8,
          ),
          child: Row(
            children: [
              const Text('🎰', style: TextStyle(fontSize: 26, height: 1)),
              const SizedBox(width: Spots.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayCaps(_title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Spots.display(15, color: Spots.teal),
                    ),
                    Text(
                      _sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: waddyMedium.copyWith(
                        fontSize: 12,
                        color: Spots.teal.withValues(alpha: 0.75),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Spots.teal,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
