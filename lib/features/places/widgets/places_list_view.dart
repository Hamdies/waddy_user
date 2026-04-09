import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/widgets/place_card.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

// ── Neubrutalism constants ──
const _kBorderWidth = 2.0;
const _kShadowSm    = BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0);

class PlacesListView extends StatelessWidget {
  const PlacesListView({super.key});

  static const List<_SortOption> _sortOptions = [
    _SortOption(key: 'rating',   label: 'Top'),
    _SortOption(key: 'votes',    label: 'Popular'),
    _SortOption(key: 'newest',   label: 'New'),
    _SortOption(key: 'distance', label: 'Nearby'),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final accent  = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<PlacesController>(
      builder: (placesController) {
        final allPlaces          = placesController.places;
        final categories         = placesController.categories ?? const [];
        final selectedCategoryId = placesController.selectedCategoryId;
        final places             = allPlaces;

        if (placesController.isPlacesLoading && (allPlaces == null || allPlaces.isEmpty)) {
          return _buildShimmer(context);
        }

        if (places == null || places.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:     Colors.white,
                      border:    Border.all(color: Colors.black, width: 2),
                      boxShadow: const [_kShadowSm],
                    ),
                    child: Icon(
                      Icons.search_off_rounded,
                      size:  42,
                      color: primary.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'no_places_found'.tr.toUpperCase(),
                    style: robotoBlack.copyWith(
                      fontSize:      16,
                      color:         Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'try_different_filters'.tr,
                    style: robotoRegular.copyWith(
                      fontSize: 12,
                      color:    Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Section header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeDefault, 4,
                Dimensions.paddingSizeDefault, 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Accent bar
                      Container(
                        width:  5,
                        height: 24,
                        decoration: BoxDecoration(
                          color:  accent,
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'all_spots'.tr.toUpperCase(),
                        style: robotoBlack.copyWith(
                          fontSize:      18,
                          color:         Colors.black,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      if (placesController.totalPlaces != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:  Colors.white,
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: Text(
                            '${placesController.totalPlaces} ${"places".tr}',
                            style: robotoBold.copyWith(
                              fontSize: 10,
                              color:    Colors.black,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        enabled: categories.isNotEmpty,
                        accent:  accent,
                        onTap: categories.isEmpty
                            ? null
                            : () => _openFilterSheet(context, placesController),
                      ),
                    ],
                  ),
                  // Active sort indicator
                  Padding(
                    padding: const EdgeInsets.only(left: 13, top: 3),
                    child: GestureDetector(
                      onTap: () => _openFilterSheet(context, placesController),
                      child: Text(
                        'Sorted by: ${_sortLabel(placesController.sortBy)} ▼',
                        style: robotoRegular.copyWith(
                          fontSize:  10,
                          color:     Colors.black54,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Category chips ──
            if (categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeDefault),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _CategoryChip(
                        label:    'ALL',
                        selected: selectedCategoryId == null,
                        accent:   accent,
                        onTap: () => placesController.setSelectedCategory(null),
                      ),
                      for (final cat in categories)
                        _CategoryChip(
                          label:    cat.name,
                          selected: selectedCategoryId == cat.id,
                          accent:   accent,
                          onTap: () =>
                              placesController.setSelectedCategory(cat.id),
                        ),
                    ],
                  ),
                ),
              ),

            if (categories.isNotEmpty) const SizedBox(height: 10),

            ListView.builder(
              shrinkWrap: true,
              physics:    const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault),
              itemCount: places.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PlaceCard(
                    place: places[index],
                    index: index,
                    onTap: () => Get.toNamed(
                        RouteHelper.getPlaceDetailsRoute(places[index].id)),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _openFilterSheet(BuildContext context, PlacesController ctrl) {
    final categories = ctrl.categories ?? const [];
    final currentSort = ctrl.sortBy;

    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color:  Colors.white,
            border: Border(top: BorderSide(color: Colors.black, width: 2.5)),
            boxShadow: [
              BoxShadow(
                  color:      Colors.black,
                  offset:     Offset(0, -4),
                  blurRadius: 0),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle — neubrutalism bar
              Center(
                child: Container(
                  width:  40,
                  height: 4,
                  color:  Colors.black,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'FILTER & SORT',
                style: robotoBlack.copyWith(
                  fontSize:      18,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'SORT BY',
                style: robotoBold.copyWith(
                  fontSize:      11,
                  color:         Colors.black54,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (final opt in _sortOptions)
                      _SheetPill(
                        label:    opt.label,
                        selected: currentSort == opt.key,
                        accent:   Theme.of(context).secondaryHeaderColor,
                        onTap: () {
                          ctrl.setSortBy(opt.key);
                          Get.back();
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'CATEGORIES',
                style: robotoBold.copyWith(
                  fontSize:      11,
                  color:         Colors.black54,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                dense:           true,
                contentPadding:  EdgeInsets.zero,
                leading: const Icon(Icons.layers_outlined),
                title: Text('All', style: robotoMedium),
                onTap: () {
                  ctrl.setSelectedCategory(null);
                  Get.back();
                },
              ),
              ...categories.map(
                (cat) => ListTile(
                  dense:          true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle_outlined, size: 18),
                  title: Text(cat.name, style: robotoMedium),
                  onTap: () {
                    ctrl.setSelectedCategory(cat.id);
                    Get.back();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return ListView.builder(
      shrinkWrap: true,
      physics:    const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        height: 130,
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        color:  Colors.white,
        decoration: BoxDecoration(
          color:     Colors.white,
          border:    Border.all(color: Colors.black, width: 2.5),
          boxShadow: const [
            BoxShadow(
                color:      Colors.black,
                offset:     Offset(3, 3),
                blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 120,
              color: primary.withValues(alpha: 0.08),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:  MainAxisAlignment.center,
                children: [
                  Container(height: 14, width: 140, color: primary.withValues(alpha: 0.10)),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 100, color: primary.withValues(alpha: 0.07)),
                  const SizedBox(height: 12),
                  Container(height: 28, width: double.infinity, color: primary.withValues(alpha: 0.07)),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

String _sortLabel(String sortBy) {
  switch (sortBy) {
    case 'votes':    return 'most popular';
    case 'newest':   return 'newest first';
    case 'distance': return 'nearest first';
    default:         return 'top rated';
  }
}

class _SortOption {
  final String key;
  final String label;
  const _SortOption({required this.key, required this.label});
}

// ── Neubrutalism filter button (square, not circle) ──
class _FilterButton extends StatelessWidget {
  final bool      enabled;
  final Color     accent;
  final VoidCallback? onTap;

  const _FilterButton({
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          width:  36,
          height: 36,
          decoration: BoxDecoration(
            color:     accent,
            border:    Border.all(color: Colors.black, width: _kBorderWidth),
            boxShadow: const [_kShadowSm],
          ),
          child: const Icon(
            Icons.filter_alt_rounded,
            color: Colors.black,
            size:  18,
          ),
        ),
      ),
    );
  }
}

// ── Neubrutalism category chip ──
class _CategoryChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final Color        accent;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve:    Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:  selected ? accent : Colors.white,
            border: Border.all(color: Colors.black, width: _kBorderWidth),
            boxShadow: selected
                ? const [_kShadowSm]
                : null,
          ),
          child: Text(
            label.toUpperCase(),
            style: robotoBold.copyWith(
              fontSize:      10,
              color:         Colors.black,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Neubrutalism sort pill ──
class _SheetPill extends StatelessWidget {
  final String       label;
  final bool         selected;
  final Color        accent;
  final VoidCallback onTap;

  const _SheetPill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve:    Curves.easeOut,
          padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color:  selected ? accent : Colors.white,
            border: Border.all(color: Colors.black, width: _kBorderWidth),
            boxShadow: selected ? const [_kShadowSm] : null,
          ),
          child: Text(
            label.toUpperCase(),
            style: robotoBlack.copyWith(
              fontSize:      10,
              color:         Colors.black,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
