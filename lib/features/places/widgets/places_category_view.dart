import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/features/places/domain/models/place_category_model.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class PlacesCategoryView extends StatelessWidget {
  const PlacesCategoryView({super.key});

  // Neo palette derived from brand teal/neon
  static const List<Color> _vibeColors = [
    Color(0xFF1EF2A0), // neon green
    Color(0xFF0F766E), // teal
    Color(0xFF14B8A6), // lighter teal
    Color(0xFF34D399), // emerald
    Color(0xFF06B6D4), // cyan
    Color(0xFF22D3EE), // sky
    Color(0xFF10B981), // green
    Color(0xFF2DD4BF), // teal light
  ];

  static const List<String> _defaultEmojis = [
    '☕', '🍕', '🎭', '🎵', '🏖️', '🎨', '🍸', '🎪',
  ];

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      builder: (placesController) {
        List<PlaceCategory>? categories = placesController.categories;

        if (placesController.isCategoriesLoading) {
          return _buildShimmer(context);
        }

        if (categories == null || categories.isEmpty) {
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
                  const Text('✨', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'explore_vibes'.tr,
                    style: robotoBold.copyWith(fontSize: 18),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  PlaceCategory category = categories[index];
                  bool isSelected = placesController.selectedCategoryId == category.id;
                  final primary = Theme.of(context).primaryColor;
                  final neon = Theme.of(context).secondaryHeaderColor;
                  final vibeColor = _vibeColors[index % _vibeColors.length];

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        if (isSelected) {
                          placesController.setSelectedCategory(null);
                        } else {
                          placesController.setSelectedCategory(category.id);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        width: 76,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primary
                              : primary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? neon
                                : vibeColor.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: neon.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (category.icon != null && category.icon!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CustomImage(
                                  image: category.icon!,
                                  height: 32,
                                  width: 32,
                                ),
                              )
                            else
                              Text(
                                _defaultEmojis[index % _defaultEmojis.length],
                                style: const TextStyle(fontSize: 26),
                              ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                category.name,
                                style: robotoBold.copyWith(
                                  fontSize: 10,
                                  color: isSelected
                                      ? neon
                                      : vibeColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
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
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 76,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}
