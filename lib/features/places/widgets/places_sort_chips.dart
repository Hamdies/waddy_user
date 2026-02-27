import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class PlacesSortChips extends StatelessWidget {
  const PlacesSortChips({super.key});

  static const List<_SortOption> _options = [
    _SortOption(key: 'rating', label: 'top_rated', emoji: '⭐'),
    _SortOption(key: 'votes', label: 'most_voted', emoji: '🗳️'),
    _SortOption(key: 'newest', label: 'newest', emoji: '🆕'),
    _SortOption(key: 'distance', label: 'nearest', emoji: '📍'),
  ];

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      builder: (placesController) {
        final currentSort = placesController.sortBy;
        final primary = Theme.of(context).primaryColor;
        final neon = Theme.of(context).secondaryHeaderColor;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              child: Row(
                children: [
                  const Text('🧭', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'discover'.tr,
                    style: robotoBold.copyWith(fontSize: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final option = _options[index];
                  final isSelected = currentSort == option.key;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => placesController.setSortBy(option.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [primary, primary.withValues(alpha: 0.8)],
                                )
                              : null,
                          color: isSelected ? null : primary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? neon.withValues(alpha: 0.5)
                                : primary.withValues(alpha: 0.12),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: neon.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(option.emoji, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 5),
                            Text(
                              option.label.tr,
                              style: robotoMedium.copyWith(
                                fontSize: 12,
                                color: isSelected ? neon : Theme.of(context).textTheme.bodyMedium?.color,
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
}

class _SortOption {
  final String key;
  final String label;
  final String emoji;

  const _SortOption({required this.key, required this.label, required this.emoji});
}
