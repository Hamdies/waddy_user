import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class TrendingPlacesView extends StatelessWidget {
  const TrendingPlacesView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      builder: (placesController) {
        List<Place>? trending = placesController.trending;

        if (placesController.isTrendingLoading) {
          return _buildShimmer(context);
        }

        if (trending == null || trending.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'trending_now'.tr,
                    style: robotoBold.copyWith(fontSize: 18),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'hot'.tr.toUpperCase(),
                      style: robotoBold.copyWith(
                        fontSize: 10,
                        color: Theme.of(context).secondaryHeaderColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: trending.length > 8 ? 8 : trending.length,
                itemBuilder: (context, index) {
                  final place = trending[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => Get.toNamed(RouteHelper.getPlaceDetailsRoute(place.id)),
                      child: _TrendingCard(place: place, rank: index + 1),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 170,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final Place place;
  final int rank;

  const _TrendingCard({required this.place, required this.rank});

  static const List<List<Color>> _gradients = [
    [Color(0xFF1EF2A0), Color(0xFF10B981)],
    [Color(0xFF134E4A), Color(0xFF0F766E)],
    [Color(0xFF14B8A6), Color(0xFF06B6D4)],
    [Color(0xFF34D399), Color(0xFF22D3EE)],
    [Color(0xFF0F766E), Color(0xFF1EF2A0)],
    [Color(0xFF06B6D4), Color(0xFF14B8A6)],
    [Color(0xFF10B981), Color(0xFF2DD4BF)],
    [Color(0xFF22D3EE), Color(0xFF34D399)],
  ];

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).secondaryHeaderColor;
    final primary = Theme.of(context).primaryColor;
    final gradientColors = _gradients[(rank - 1) % _gradients.length];

    return Container(
      width: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: neon.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: neon.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
                    primary.withValues(alpha: 0.2),
                    primary.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),

            // Rank badge top-left
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: robotoBold.copyWith(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
            ),

            // Fire badge top-right
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: neon.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: neon.withValues(alpha: 0.3), blurRadius: 6)],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🔥', style: TextStyle(fontSize: 10)),
                    SizedBox(width: 2),
                    Icon(Icons.trending_up_rounded, size: 12, color: Colors.white),
                  ],
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
                      fontSize: 14,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 4)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (place.categoryName != null)
                    Text(
                      place.categoryName!,
                      style: robotoRegular.copyWith(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 11, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(
                              place.rating.toStringAsFixed(1),
                              style: robotoBold.copyWith(fontSize: 10, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.how_to_vote_rounded, size: 12,
                          color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
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
    );
  }
}
