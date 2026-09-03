import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_winner_model.dart';
import 'package:waddy_app/common/widgets/spots/spots_section_header.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// Real people who won the voter prize — social proof, not a ranking.
///
/// Visually distinct from the Top Voters podium on purpose: short wide cards,
/// no rank numerals, no crowns. If it looked like the leaderboard, users would
/// read it as "these are the top voters and that's why they won", which is
/// exactly the causation the random draw is designed not to have.
class RecentWinnersStrip extends StatelessWidget {
  const RecentWinnersStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      id: PlacesController.idWinners,
      builder: (controller) {
        if (controller.isRecentWinnersLoading &&
            controller.recentWinners == null) {
          return const _WinnersStripSkeleton();
        }

        final all = controller.recentWinners;
        // No winners yet is the normal state before the first week closes —
        // an empty-state card here would just be noise on the home screen.
        if (all == null || all.isEmpty) return const SizedBox.shrink();

        // One person per strip. The same name twice reads as a rendering bug
        // rather than as two wins, and the strip's job is breadth of proof —
        // that real, different people win — not a per-prize history.
        final seen = <String>{};
        final winners = <RecentWinner>[
          for (final w in all)
            if (seen.add('${w.name}|${w.avatar ?? ''}')) w,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SpotsSectionHeader(
              kicker: 'spots_real_winners'.tr,
              title: 'spots_recent_winners_title'.tr,
            ),
            const SizedBox(height: Spots.s12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: winners.length,
                separatorBuilder: (_, __) => const SizedBox(width: Spots.s12),
                itemBuilder: (_, i) => _WinnerCard(winner: winners[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.winner});

  final RecentWinner winner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 214,
      decoration: Spots.card(
        fill: Spots.mint,
        borderWidth: Spots.borderThin,
        dx: 3,
        dy: 3,
      ),
      padding: const EdgeInsets.all(Spots.s12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Spots.canvas,
              border: Border.all(color: Spots.border, width: Spots.borderThin),
              borderRadius: BorderRadius.circular(Spots.radiusMd),
            ),
            child:
                (winner.avatar != null && winner.avatar!.isNotEmpty)
                    ? CustomImage(
                      image: winner.avatar!,
                      height: 44,
                      width: 44,
                      fit: BoxFit.cover,
                    )
                    : const Icon(
                      Icons.person_rounded,
                      size: 22,
                      color: Spots.ink3,
                    ),
          ),
          const SizedBox(width: Spots.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "@${winner.name}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBlack.copyWith(
                    fontSize: 14,
                    color: Spots.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  winner.placeTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: waddyRegular.copyWith(
                    fontSize: 11,
                    color: Spots.ink3,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnersStripSkeleton extends StatelessWidget {
  const _WinnersStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpotsSectionHeader(
          kicker: 'spots_real_winners'.tr,
          title: 'spots_recent_winners_title'.tr,
        ),
        const SizedBox(height: Spots.s12),
        const SizedBox(
          height: 92,
          child: Row(
            children: [
              SpotsSkeleton(width: 214, height: 92),
              SizedBox(width: Spots.s12),
              SpotsSkeleton(width: 214, height: 92),
            ],
          ),
        ),
      ],
    );
  }
}
