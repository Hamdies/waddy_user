import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/util/styles.dart';

class TagFilterView extends StatelessWidget {
  const TagFilterView({super.key});

  static const List<Color> _tagColors = [
    Color(0xFF1EF2A0),
    Color(0xFF14B8A6),
    Color(0xFF06B6D4),
    Color(0xFF34D399),
    Color(0xFF22D3EE),
    Color(0xFF10B981),
    Color(0xFF2DD4BF),
    Color(0xFF0F766E),
  ];

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      builder: (placesController) {
        List<PlaceTag>? tags = placesController.tags;

        if (placesController.isTagsLoading || tags == null || tags.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedIds = placesController.selectedTagIds;

        return SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              final isSelected = selectedIds.contains(tag.id);
              final primary = Theme.of(context).primaryColor;
              final neon = Theme.of(context).secondaryHeaderColor;
              final tagColor = _tagColors[index % _tagColors.length];

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => placesController.toggleTag(tag.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? primary : primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? neon : tagColor.withValues(alpha: 0.3),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: neon.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tag.icon != null && tag.icon!.isNotEmpty) ...[
                          Text(tag.icon!, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          tag.localizedName,
                          style: robotoMedium.copyWith(
                            fontSize: 12,
                            color: isSelected ? neon : tagColor,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.close_rounded, size: 13, color: neon),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
