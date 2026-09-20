import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// Zone-based filter tabs inside the masthead's "select area" sheet.
/// Fetches zones from the Places API and displays them as selectable chips —
/// boxy Spots pills, on-system (teal borders, hard shadow, radiusPill).
class AreaFilterTabs extends StatelessWidget {
  const AreaFilterTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      id: PlacesController.idFilters,
      builder: (controller) {
        if (controller.isZonesLoading) {
          return _buildSkeleton(context);
        }

        final zones = controller.zones;

        // A failed fetch used to render nothing at all — no error, no retry,
        // indistinguishable from "this city has no areas". Three states, not
        // two: in flight (above), failed (here), genuinely empty (below).
        // See `S-10` in docs/spots_module_plan.md.
        if (zones == null && controller.zonesFailed) {
          return _buildError(controller);
        }

        // No zones available → nothing to filter
        if (zones == null || zones.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spots.gutter,
            vertical: Spots.s12,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // "ALL" tab (no zone filter)
                _buildTab(
                  label: displayCaps('spots_all_chip'.tr),
                  isSelected: controller.selectedZoneId == null,
                  onTap: () => _select(controller, null),
                ),
                // Zone tabs from API
                ...zones.map(
                  (zone) => Padding(
                    padding: const EdgeInsetsDirectional.only(start: Spots.s8),
                    child: _buildTab(
                      label: displayCaps(
                        zone.displayName ??
                            zone.name ??
                            'spots_zone_fallback'.trParams({
                              'id': '${zone.id}',
                            }),
                      ),
                      isSelected: controller.selectedZoneId == zone.id,
                      onTap: () => _select(controller, zone.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Apply the zone and dismiss the sheet.
  ///
  /// The sheet is a scope picker, not a workspace: leaving it open over a board
  /// that is already refetching behind it hides the only feedback the choice
  /// produces. `setSelectedZone` is deliberately not awaited — it fans out to
  /// four refetches, and the sheet should not linger for them.
  void _select(PlacesController controller, int? zoneId) {
    if (controller.selectedZoneId != zoneId) {
      controller.setSelectedZone(zoneId);
    }
    if (Get.isBottomSheetOpen ?? false) Get.back();
  }

  Widget _buildError(PlacesController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spots.gutter,
        vertical: Spots.s12,
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: Spots.ink3),
          const SizedBox(width: Spots.s8),
          Expanded(
            child: Text(
              'spots_areas_unavailable'.tr,
              style: waddyBold.copyWith(fontSize: 12, color: Spots.ink3),
            ),
          ),
          const SizedBox(width: Spots.s8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => controller.getZones(reload: true),
            child: Padding(
              // Padded to a real touch target — the label alone is ~16px tall.
              padding: const EdgeInsets.symmetric(
                horizontal: Spots.s12,
                vertical: Spots.s12,
              ),
              child: Text(
                displayCaps('retry'.tr),
                style: waddyBlack.copyWith(
                  fontSize: 12,
                  color: Spots.teal,
                  letterSpacing: displayTracking(0.05 * 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spots.gutter,
        vertical: Spots.s12,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            4,
            (index) => Padding(
              padding: EdgeInsetsDirectional.only(
                start: index == 0 ? 0 : Spots.s8,
              ),
              child: const SpotsSkeleton(
                width: 80,
                height: 42,
                radius: Spots.radiusPill,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: Spots.s16,
          vertical: Spots.s12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Spots.teal : Spots.paper,
          borderRadius: BorderRadius.circular(Spots.radiusPill),
          border: Border.all(color: Spots.border, width: Spots.borderThin),
          boxShadow: isSelected ? Spots.shadow(dx: 2, dy: 2) : null,
        ),
        child: Text(
          label,
          style: waddyBold.copyWith(
            fontSize: 12,
            color: isSelected ? Colors.white : Spots.teal,
            letterSpacing: displayTracking(0.5),
          ),
        ),
      ),
    );
  }
}
