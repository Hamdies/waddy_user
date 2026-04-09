import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';

class LeaderboardPlaceCard extends StatelessWidget {
  final Place place;
  final int rank;

  const LeaderboardPlaceCard({
    super.key,
    required this.place,
    required this.rank,
  });

  static const List<String> _rankEmojis = ['👑', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final bool isTopThree = rank <= 3;
    final neon = Theme.of(context).secondaryHeaderColor;
    final primary = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () => Get.toNamed(RouteHelper.getPlaceDetailsRoute(place.id)),
      child: Container(
        width: 155,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: neon.withValues(alpha: isTopThree ? 0.25 : 0.1)),
          boxShadow: [
            BoxShadow(
              color: neon.withValues(alpha: isTopThree ? 0.25 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              CustomImage(
                image: place.image ?? '',
                fit: BoxFit.cover,
              ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      primary.withValues(alpha: 0.15),
                      primary.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),

              // Rank badge
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isTopThree
                        ? neon.withValues(alpha: 0.9)
                        : primary.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: neon.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: isTopThree
                        ? Text(
                            _rankEmojis[rank - 1],
                            style: const TextStyle(fontSize: 16),
                          )
                        : Text(
                            '#$rank',
                            style: robotoBold.copyWith(fontSize: 10, color: Colors.white),
                          ),
                  ),
                ),
              ),

              // Bottom content
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.title,
                      style: robotoBold.copyWith(
                        fontSize: 13,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 10, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                place.rating.toStringAsFixed(1),
                                style: robotoBold.copyWith(fontSize: 10, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.how_to_vote_rounded, size: 11,
                            color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 2),
                        Text(
                          '${place.votesCount}',
                          style: robotoMedium.copyWith(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
