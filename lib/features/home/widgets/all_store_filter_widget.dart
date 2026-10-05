import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class AllStoreFilterWidget extends StatelessWidget {
  const AllStoreFilterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.storeListId,
      builder: (storeController) {
        return Center(
          child: Container(
            width: Dimensions.maxContentWidth,
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.only(
              top: Dimensions.paddingSizeSmall,
              bottom: 6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeDefault,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Get.find<SplashController>()
                                .configModel
                                .moduleConfig!
                                .module!
                                .showRestaurantText!
                            ? 'restaurants'.tr
                            : 'stores'.tr,
                        style: waddyBold.copyWith(
                          fontSize: 20,
                          color: WaddyColors.primary,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${storeController.storeModel?.totalSize ?? 0} ${Get.find<SplashController>().configModel.moduleConfig!.module!.showRestaurantText! ? 'restaurants_near_you'.tr : 'stores_near_you'.tr}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: waddyRegular.copyWith(
                            color: WaddyColors.inkLight,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildFilterRow(context, storeController),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterRow(
    BuildContext context,
    StoreListController storeController,
  ) {
    final bool filterActive = storeController.storeType != 'all';

    return SizedBox(
      height: 34,
      child: Row(
        children: [
          const SizedBox(width: Dimensions.paddingSizeDefault),
          _IconPillButton(
            icon: Icons.tune_rounded,
            active: filterActive,
            onTap:
                () => _openSheet(
                  context,
                  _FilterSheetContent(storeController: storeController),
                ),
          ),
          const SizedBox(width: 9),
          _IconPillButton(
            icon: Icons.swap_vert_rounded,
            active: storeController.filterType != 'all',
            onTap:
                () => _openSheet(
                  context,
                  _SortSheetContent(storeController: storeController),
                ),
          ),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 9),
            color: WaddyColors.divider,
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(
                end: Dimensions.paddingSizeDefault,
              ),
              clipBehavior: Clip.none,
              children: [
                _ThemedChip(
                  label: 'popular'.tr,
                  isSelected: storeController.storeType == 'popular',
                  onTap:
                      () => storeController.setStoreType(
                        storeController.storeType == 'popular'
                            ? 'all'
                            : 'popular',
                      ),
                ),
                const SizedBox(width: 9),
                _ThemedChip(
                  label: 'top_rated'.tr,
                  isSelected: storeController.storeType == 'top_rated',
                  onTap:
                      () => storeController.setStoreType(
                        storeController.storeType == 'top_rated'
                            ? 'all'
                            : 'top_rated',
                      ),
                ),
                const SizedBox(width: 9),
                _ThemedChip(
                  label: 'newly_joined'.tr,
                  isSelected: storeController.storeType == 'newly_joined',
                  onTap:
                      () => storeController.setStoreType(
                        storeController.storeType == 'newly_joined'
                            ? 'all'
                            : 'newly_joined',
                      ),
                ),
                if (AuthHelper.isLoggedIn()) ...[
                  const SizedBox(width: 9),
                  _ThemedChip(
                    label: 'just_for_you'.tr,
                    isSelected: storeController.storeType == 'for_you',
                    onTap:
                        () => storeController.setStoreType(
                          storeController.storeType == 'for_you'
                              ? 'all'
                              : 'for_you',
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, Widget content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // Sized to its content rather than a fixed fraction of the screen, so a
      // short sheet (sort) stays short and a taller one (filters) grows until
      // the scaffold's cap takes over.
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: const Color(0x73131F1D),
      builder: (context) => content,
    );
  }
}

/// Round icon-only pill button used for the Filter / Sort entry points.
class _IconPillButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _IconPillButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active ? WaddyColors.primary : WaddyColors.surfaceRaised,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 17,
            color: active ? Colors.white : WaddyColors.ink,
          ),
        ),
      ),
    );
  }
}

/// Themed pill chip using teal/neon-green palette
class _ThemedChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemedChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? WaddyColors.primary : WaddyColors.surfaceRaised,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            style: waddyMedium.copyWith(
              fontSize: 14,
              color: isSelected ? Colors.white : WaddyColors.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared chrome for both bottom sheets: handle, title row, close button.
class _SheetScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? footer;

  const _SheetScaffold({required this.title, required this.body, this.footer});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: WaddyColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: waddyBold.copyWith(
                    fontSize: 18,
                    color: WaddyColors.ink,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: WaddyColors.surfaceRaised,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: WaddyColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: body),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

class _SortSheetContent extends StatelessWidget {
  final StoreListController storeController;
  const _SortSheetContent({required this.storeController});

  @override
  Widget build(BuildContext context) {
    final options = [
      ('all', 'all'.tr),
      ('delivery', 'fastest_delivery'.tr),
      ('take_away', 'take_away'.tr),
    ];

    return GetBuilder<StoreListController>(
      id: StoreListController.storeListId,
      builder: (storeController) {
        return _SheetScaffold(
          title: 'sort_by'.tr,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  options.map((option) {
                    final selected = storeController.filterType == option.$1;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          storeController.setFilterType(option.$1);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 15,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                option.$2,
                                style: waddyRegular.copyWith(
                                  fontSize: 15,
                                  fontWeight:
                                      selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                  color:
                                      selected
                                          ? WaddyColors.primary
                                          : WaddyColors.ink,
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 19,
                                  color: WaddyColors.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _FilterSheetContent extends StatelessWidget {
  final StoreListController storeController;
  const _FilterSheetContent({required this.storeController});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreListController>(
      id: StoreListController.storeListId,
      builder: (storeController) {
        final storeTypeChips = <(String, String)>[
          ('popular', 'popular'.tr),
          ('top_rated', 'top_rated'.tr),
          ('newly_joined', 'newly_joined'.tr),
          if (AuthHelper.isLoggedIn()) ('for_you', 'just_for_you'.tr),
        ];

        final deliveryChips = <(String, String)>[
          ('delivery', 'fastest_delivery'.tr),
          ('take_away', 'take_away'.tr),
        ];

        return _SheetScaffold(
          title: 'filter'.tr,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _FilterSection(
                  title: 'store_type'.tr,
                  chips:
                      storeTypeChips.map((option) {
                        final selected = storeController.storeType == option.$1;
                        return _FilterChip(
                          label: option.$2,
                          selected: selected,
                          onTap:
                              () => storeController.setStoreType(
                                selected ? 'all' : option.$1,
                              ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 22),
                _FilterSection(
                  title: 'sort_by'.tr,
                  chips:
                      deliveryChips.map((option) {
                        final selected =
                            storeController.filterType == option.$1;
                        return _FilterChip(
                          label: option.$2,
                          selected: selected,
                          onTap:
                              () => storeController.setFilterType(
                                selected ? 'all' : option.$1,
                              ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
          footer: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: WaddyColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      storeController.setStoreType('all');
                      storeController.setFilterType('all');
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: WaddyColors.divider),
                      ),
                      child: Text(
                        'reset'.tr,
                        style: waddyMedium.copyWith(
                          fontSize: 15,
                          color: WaddyColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: WaddyColors.primary,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '${'show'.tr} ${storeController.storeModel?.totalSize ?? 0} ${Get.find<SplashController>().configModel.moduleConfig!.module!.showRestaurantText! ? 'restaurants'.tr : 'stores'.tr}',
                        style: waddyBold.copyWith(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? WaddyColors.primary : WaddyColors.surfaceRaised,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? WaddyColors.primary : WaddyColors.surfaceRaised,
            ),
          ),
          child: Text(
            label,
            style: waddyMedium.copyWith(
              fontSize: 14,
              color: selected ? Colors.white : WaddyColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// One labelled group of filter chips, matching the design's section stack.
class _FilterSection extends StatelessWidget {
  final String title;
  final List<Widget> chips;

  const _FilterSection({required this.title, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title.toUpperCase(),
          style: waddyMedium.copyWith(
            fontSize: 13,
            color: WaddyColors.inkLight,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 9, runSpacing: 9, children: chips),
      ],
    );
  }
}
