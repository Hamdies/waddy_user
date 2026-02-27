import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/features/places/domain/models/place_model.dart';
import 'package:sixam_mart/features/places/widgets/leaderboard_place_card.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class LeaderboardSection extends StatelessWidget {
  const LeaderboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      builder: (placesController) {
        List<Place>? leaderboard = placesController.leaderboard;

        if (placesController.isLeaderboardLoading) {
          return _buildShimmer(context);
        }

        if (leaderboard == null || leaderboard.isEmpty) {
          return const SizedBox.shrink();
        }

        final primary = Theme.of(context).primaryColor;
        final neon = Theme.of(context).secondaryHeaderColor;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          margin: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary.withValues(alpha: 0.06),
                neon.withValues(alpha: 0.04),
                Theme.of(context).cardColor,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: neon.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(color: neon.withValues(alpha: 0.08), blurRadius: 12),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      'top_gems'.tr,
                      style: robotoBold.copyWith(fontSize: 18),
                    ),
                    const Spacer(),
                    if (placesController.leaderboardPeriod != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: neon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: neon.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          placesController.leaderboardPeriod!,
                          style: robotoMedium.copyWith(
                            fontSize: 10,
                            color: neon,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: leaderboard.length > 10 ? 10 : leaderboard.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: LeaderboardPlaceCard(
                        place: leaderboard[index],
                        rank: index + 1,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 155,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
            ),
          );
        },
      ),
    );
  }
}
