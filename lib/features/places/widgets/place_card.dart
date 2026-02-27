import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/features/places/domain/models/place_model.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/util/styles.dart';

class PlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onTap;
  final bool showFavorite;

  const PlaceCard({super.key, required this.place, this.onTap, this.showFavorite = true});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final neon = Theme.of(context).secondaryHeaderColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: neon.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: neon.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ─── BACKGROUND IMAGE ───
              CustomImage(
                image: place.image ?? '',
                fit: BoxFit.cover,
              ),

              // ─── GRADIENT OVERLAY ───
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      primary.withValues(alpha: 0.25),
                      primary.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),

              // ─── TOP BADGES ───
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    // Open/Closed pill
                    if (place.isOpenNow != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: place.isOpenNow == true
                              ? neon.withValues(alpha: 0.9)
                              : Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              place.isOpenNow == true ? 'open'.tr : 'closed'.tr,
                              style: robotoBold.copyWith(fontSize: 9, color: Colors.white),
                            ),
                          ],
                        ),
                      ),

                    // Category pill
                    if (place.categoryName != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: neon.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: neon.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          place.categoryName!,
                          style: robotoMedium.copyWith(fontSize: 9, color: Colors.white),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Favorite heart
                    if (showFavorite && AuthHelper.isLoggedIn())
                      GestureDetector(
                        onTap: () => Get.find<PlacesController>().toggleFavorite(place.id),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(color: neon.withValues(alpha: 0.2)),
                          ),
                          child: Icon(
                            place.isFavorited == true
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 16,
                            color: place.isFavorited == true
                                ? const Color(0xFFFF5252)
                                : Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ─── BOTTOM CONTENT ───
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      place.title,
                      style: robotoBold.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Rating + Votes + Tags row
                    Row(
                      children: [
                        // Star rating
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                place.rating.toStringAsFixed(1),
                                style: robotoBold.copyWith(fontSize: 11, color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Votes
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.how_to_vote_rounded, size: 13,
                                color: Colors.white.withValues(alpha: 0.8)),
                            const SizedBox(width: 3),
                            Text(
                              '${place.votesCount}',
                              style: robotoMedium.copyWith(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Tags
                        if (place.tags != null && place.tags!.isNotEmpty)
                          ...place.tags!.take(2).map((tag) => Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: neon.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tag.icon != null && tag.icon!.isNotEmpty
                                    ? '${tag.icon} ${tag.localizedName}'
                                    : tag.localizedName,
                                style: robotoMedium.copyWith(fontSize: 9, color: Colors.white),
                              ),
                            ),
                          )),
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
