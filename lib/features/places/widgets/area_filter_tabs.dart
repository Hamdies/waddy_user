import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Zone-based filter tabs at the top of Places home screen.
/// Fetches zones from the Places API and displays them as selectable chips.
class AreaFilterTabs extends StatelessWidget {
  const AreaFilterTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      builder: (controller) {
        // Show shimmer while loading
        if (controller.isZonesLoading) {
          return _buildShimmer(context);
        }

        final zones = controller.zones;

        // No zones available → nothing to filter
        if (zones == null || zones.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: 10,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // "ALL" tab (no zone filter)
                _buildTab(
                  context,
                  label: 'ALL',
                  isSelected: controller.selectedZoneId == null,
                  onTap: () => controller.setSelectedZone(null),
                ),
                // Zone tabs from API
                ...zones.map((zone) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildTab(
                    context,
                    label: (zone.displayName ?? zone.name ?? 'Zone ${zone.id}').toUpperCase(),
                    isSelected: controller.selectedZoneId == zone.id,
                    onTap: () => controller.setSelectedZone(zone.id),
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: 10,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(4, (index) => Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
            child: Container(
              width: 80,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )),
        ),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primary : Colors.grey.shade400,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: robotoBold.copyWith(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
