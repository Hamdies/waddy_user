import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class PlacesSortChips extends StatelessWidget {
  const PlacesSortChips({super.key});

  static const List<_SortOption> _options = [
    _SortOption(key: 'rating', label: 'Top'),
    _SortOption(key: 'votes', label: 'Popular'),
    _SortOption(key: 'newest', label: 'New'),
    _SortOption(key: 'distance', label: 'Nearby'),
  ];

  static List<_SortOption> get options => _options;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      builder: (placesController) {
        final currentSort = placesController.sortBy;
        final primary = Theme.of(context).primaryColor;
        final neon = Theme.of(context).secondaryHeaderColor;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort by',
                style: robotoBold.copyWith(
                  fontSize: 12,
                  color: primary.withValues(alpha: 0.45),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.16),
                    width: 1.2,
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final option in _options)
                        _SortSegment(
                          label: option.label,
                          selected: currentSort == option.key,
                          onTap: () => placesController.setSortBy(option.key),
                          selectedColor: neon,
                          borderColor: primary.withValues(alpha: 0.25),
                          textColor: primary,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SortOption {
  final String key;
  final String label;

  const _SortOption({required this.key, required this.label});
}

class _SortSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color borderColor;
  final Color textColor;

  const _SortSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? selectedColor.withValues(alpha: 0.96) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.black87 : borderColor,
              width: 1.4,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: selectedColor.withValues(alpha: 0.18),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label.toUpperCase(),
            style: selected
                ? robotoBold.copyWith(
                    fontSize: 11,
                    color: Colors.black87,
                    letterSpacing: 0.3,
                  )
                : robotoBold.copyWith(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.72),
                    letterSpacing: 0.3,
                  ),
          ),
        ),
      ),
    );
  }
}
