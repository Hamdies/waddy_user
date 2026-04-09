import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/widgets/podium_winner_card.dart';
import 'package:waddy_app/features/places/widgets/podium_runner_card.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class PodiumSection extends StatelessWidget {
  const PodiumSection({super.key});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<PlacesController>(
      builder: (controller) {
        final leaderboard = controller.leaderboard;

        if (controller.isLeaderboardLoading) {
          return _buildShimmer(context);
        }

        if (leaderboard == null || leaderboard.isEmpty) {
          return const SizedBox.shrink();
        }

        final winnerVotes = leaderboard[0].votesCount;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Neubrutalism section header ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Accent bar
                  Container(
                    width: 5,
                    height: 26,
                    decoration: BoxDecoration(
                      color: neon,
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'BEST OF THIS WEEK IN MAADI',
                    style: robotoBlack.copyWith(
                      fontSize: 15,
                      color: Colors.black,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration:  BoxDecoration(
                      color: Theme.of(context).secondaryHeaderColor,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0),
                      ],
                    ),
                    child: Text(
                      'Top 3',
                      style: robotoBold.copyWith(
                        fontSize: 10,
                        color: Theme.of(context).primaryColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── #1 Winner ──
              Transform.scale(
                scale: 1.05,
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PodiumWinnerCard(place: leaderboard[0]),
                ),
              ),

              // ── #2 and #3 — podium base steps ──
              if (leaderboard.length >= 2) ...[
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // #2 — sits on the taller base step
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PodiumRunnerCard(
                            place: leaderboard[1],
                            rank: 2,
                            winnerVotesCount: winnerVotes,
                            imageAspectRatio: 0.95, // taller = more prominent
                          ),
                          Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color:  Theme.of(context).primaryColor,
                              border: Border.all(color: Colors.black, width: 1.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black,
                                    offset: Offset(2, 2), blurRadius: 0),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '#2',
                                style: robotoBlack.copyWith(
                                  fontSize: 11,
                                  color:    Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (leaderboard.length >= 3) ...[
                      const SizedBox(width: 8),
                      // #3 — sits on the shorter base step
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PodiumRunnerCard(
                              place: leaderboard[2],
                              rank: 3,
                              winnerVotesCount: winnerVotes,
                              isLast: true,
                              imageAspectRatio: 1.4, // shorter = lower podium step
                            ),
                            Container(
                              height: 18,
                              decoration: BoxDecoration(
                                color:  Theme.of(context).primaryColor
                                    .withValues(alpha: 0.75),
                                border: Border.all(
                                    color: Colors.black, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black,
                                      offset: Offset(2, 2), blurRadius: 0),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '#3',
                                  style: robotoBlack.copyWith(
                                    fontSize: 10,
                                    color:    Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: 8,
      ),
      child: Column(
        children: [
          // Header shimmer
          Container(
            height: 26,
            width: 160,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 14),
          // Winner shimmer
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              border: Border.all(color: Colors.grey.shade400, width: 2),
            ),
          ),
          const SizedBox(height: 16),
          // Runner #2 and #3 shimmer squares
          Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      border: Border.all(color: Colors.grey.shade400, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      border: Border.all(color: Colors.grey.shade400, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
