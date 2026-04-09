import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class PlacesCategoryView extends StatelessWidget {
  const PlacesCategoryView({super.key});

  static const List<_SortOption> _sortOptions = [
    _SortOption(key: 'rating', label: 'Top'),
    _SortOption(key: 'votes', label: 'Popular'),
    _SortOption(key: 'newest', label: 'New'),
    _SortOption(key: 'distance', label: 'Nearby'),
  ];

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      builder: (controller) {
        if (controller.isCategoriesLoading) {
          return _buildShimmer(context);
        }

        final categories = controller.categories ?? const [];
        final currentSort = controller.sortBy;
        final primary = Theme.of(context).primaryColor;
        final accent = Theme.of(context).secondaryHeaderColor;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: primary.withValues(alpha: 0.14),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by category',
                    style: robotoBold.copyWith(
                      fontSize: 12,
                      color: primary.withValues(alpha: 0.45),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _CategorySegment(
                          label: 'All',
                          selected: controller.selectedCategoryId == null,
                          onTap: () => controller.setSelectedCategory(null),
                          selectedColor: accent,
                          borderColor: primary.withValues(alpha: 0.25),
                          textColor: primary,
                        ),
                        for (final category in categories)
                          _CategorySegment(
                            label: category.name,
                            selected: controller.selectedCategoryId == category.id,
                            onTap: () => controller.setSelectedCategory(category.id),
                            selectedColor: accent,
                            borderColor: primary.withValues(alpha: 0.25),
                            textColor: primary,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sort by',
                    style: robotoBold.copyWith(
                      fontSize: 12,
                      color: primary.withValues(alpha: 0.45),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        for (final option in _sortOptions)
                          _SortSegment(
                            label: option.label,
                            selected: currentSort == option.key,
                            onTap: () => controller.setSortBy(option.key),
                            selectedColor: accent,
                            borderColor: primary.withValues(alpha: 0.25),
                            textColor: primary,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Container(
              width: 128,
              height: 12,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Container(
              height: 118,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortOption {
  final String key;
  final String label;

  const _SortOption({required this.key, required this.label});
}

class _CategorySegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color borderColor;
  final Color textColor;

  const _CategorySegment({
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.black87 : borderColor,
              width: 1.4,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: selectedColor.withValues(alpha: 0.22),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label.toUpperCase(),
            style: robotoBold.copyWith(
              fontSize: 11,
              color: selected ? Colors.black87 : textColor.withValues(alpha: 0.72),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
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
