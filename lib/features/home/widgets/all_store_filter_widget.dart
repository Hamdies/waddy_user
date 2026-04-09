import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

// Theme colors from light_theme.dart
const _kTeal = Color(0xFF134E4A);
const _kNeonGreen = Color(0xFF1EF2A0);
const _kTealLight = Color(0xFFE8F5F3);
const _kNeonGreenLight = Color(0xFFE0FFF2);

class AllStoreFilterWidget extends StatelessWidget {
  const AllStoreFilterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreController>(builder: (storeController) {
      return Center(
        child: Container(
          width: Dimensions.webMaxWidth,
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.only(
            left: Dimensions.paddingSizeDefault,
            right: Dimensions.paddingSizeDefault,
            top: 10,
            bottom: 6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Get.find<SplashController>()
                            .configModel!
                            .moduleConfig!
                            .module!
                            .showRestaurantText!
                        ? 'restaurants'.tr
                        : 'stores'.tr,
                    style: robotoBold.copyWith(
                      fontSize: 20,
                      color: _kTeal,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '${storeController.storeModel?.totalSize ?? 0} ${Get.find<SplashController>().configModel!.moduleConfig!.module!.showRestaurantText! ? 'restaurants_near_you'.tr : 'stores_near_you'.tr}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: robotoRegular.copyWith(
                        color: _kTeal.withOpacity(0.5),
                        fontSize: Dimensions.fontSizeSmall,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Filter chips row
              _buildFilterRow(context, storeController),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildFilterRow(
      BuildContext context, StoreController storeController) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          // Filter button
          _ThemedChip(
            label: 'filter'.tr,
            icon: Icons.tune_rounded,
            isSelected: false,
            onTap: () => _showFilterBottomSheet(context, storeController),
          ),
          const SizedBox(width: 8),

          // Delivery type dropdown (covers delivery / take away)
          _ThemedSortDropdown(storeController: storeController),
          const SizedBox(width: 8),

          // For You chip (only if logged in)
          if (AuthHelper.isLoggedIn()) ...[
            _ThemedChip(
              label: 'just_for_you'.tr,
              icon: Icons.auto_awesome_rounded,
              isSelected: storeController.storeType == 'for_you',
              useAccent: true,
              onTap: () => storeController.setStoreType(
                storeController.storeType == 'for_you' ? 'all' : 'for_you',
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Popular chip
          _ThemedChip(
            label: 'popular'.tr,
            icon: Icons.local_fire_department_rounded,
            isSelected: storeController.storeType == 'popular',
            onTap: () => storeController.setStoreType(
              storeController.storeType == 'popular' ? 'all' : 'popular',
            ),
          ),
          const SizedBox(width: 8),

          // Top Rated chip
          _ThemedChip(
            label: 'top_rated'.tr,
            icon: Icons.star_rounded,
            isSelected: storeController.storeType == 'top_rated',
            onTap: () => storeController.setStoreType(
              storeController.storeType == 'top_rated' ? 'all' : 'top_rated',
            ),
          ),
          const SizedBox(width: 8),

          // Newly Joined chip
          _ThemedChip(
            label: 'newly_joined'.tr,
            icon: Icons.fiber_new_rounded,
            isSelected: storeController.storeType == 'newly_joined',
            onTap: () => storeController.setStoreType(
              storeController.storeType == 'newly_joined'
                  ? 'all'
                  : 'newly_joined',
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(
      BuildContext context, StoreController storeController) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _FilterBottomSheet(storeController: storeController),
    );
  }
}

/// Themed pill chip using teal/neon-green palette
class _ThemedChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final bool useAccent;
  final VoidCallback onTap;

  const _ThemedChip({
    required this.label,
    this.icon,
    required this.isSelected,
    this.useAccent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color fgColor;
    final Color borderColor;

    if (isSelected && useAccent) {
      bgColor = _kNeonGreen;
      fgColor = _kTeal;
      borderColor = _kNeonGreen;
    } else if (isSelected) {
      bgColor = _kTeal;
      fgColor = Colors.white;
      borderColor = _kTeal;
    } else {
      bgColor = Colors.white;
      fgColor = _kTeal.withOpacity(0.7);
      borderColor = _kTeal.withOpacity(0.15);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: icon != null ? 10 : 14,
            vertical: 0,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fgColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: robotoMedium.copyWith(
                  fontSize: 12,
                  color: fgColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sort dropdown using teal theme — uses GestureDetector + showMenu
/// to avoid PopupMenuButton's 48px minimum touch target.
class _ThemedSortDropdown extends StatelessWidget {
  final StoreController storeController;

  const _ThemedSortDropdown({required this.storeController});

  String _getSortLabel() {
    switch (storeController.filterType) {
      case 'delivery':
        return 'fastest_delivery'.tr;
      case 'take_away':
        return 'take_away'.tr;
      default:
        return 'delivery_type'.tr;
    }
  }

  void _showMenu(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final Size size = box.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      color: Colors.white,
      elevation: 6,
      shadowColor: _kTeal.withOpacity(0.12),
      items: [
        _buildMenuItem('all', 'all'.tr),
        _buildMenuItem('delivery', 'fastest_delivery'.tr),
        _buildMenuItem('take_away', 'take_away'.tr),
      ],
    ).then((value) {
      if (value != null) {
        storeController.setFilterType(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isActive = storeController.filterType != 'all';

    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: isActive ? _kTeal : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isActive ? _kTeal : _kTeal.withOpacity(0.15),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delivery_dining_rounded,
              size: 15,
              color: isActive ? Colors.white : _kTeal.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              _getSortLabel(),
              style: robotoMedium.copyWith(
                fontSize: 12,
                color: isActive ? Colors.white : _kTeal.withOpacity(0.7),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive ? Colors.white : _kTeal.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String text) {
    final isSelected = storeController.filterType == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: robotoMedium.copyWith(
                fontSize: 14,
                color: isSelected ? _kTeal : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_rounded, size: 18, color: _kNeonGreen),
        ],
      ),
    );
  }
}

/// Bottom sheet for advanced filtering
class _FilterBottomSheet extends StatelessWidget {
  final StoreController storeController;

  const _FilterBottomSheet({required this.storeController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kTealLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: _kTeal, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'filter'.tr,
                style: robotoBold.copyWith(fontSize: 20, color: _kTeal),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Store Type Section
          Text(
            'store_type'.tr,
            style: robotoMedium.copyWith(
              fontSize: 13,
              color: _kTeal.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterOption(
                label: 'all'.tr,
                isSelected: storeController.storeType == 'all',
                onTap: () {
                  storeController.setStoreType('all');
                  Navigator.pop(context);
                },
              ),
              _FilterOption(
                label: 'popular'.tr,
                isSelected: storeController.storeType == 'popular',
                onTap: () {
                  storeController.setStoreType('popular');
                  Navigator.pop(context);
                },
              ),
              _FilterOption(
                label: 'top_rated'.tr,
                isSelected: storeController.storeType == 'top_rated',
                onTap: () {
                  storeController.setStoreType('top_rated');
                  Navigator.pop(context);
                },
              ),
              _FilterOption(
                label: 'newly_joined'.tr,
                isSelected: storeController.storeType == 'newly_joined',
                onTap: () {
                  storeController.setStoreType('newly_joined');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Delivery Type Section
          Text(
            'delivery_type'.tr,
            style: robotoMedium.copyWith(
              fontSize: 13,
              color: _kTeal.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterOption(
                label: 'all'.tr,
                isSelected: storeController.filterType == 'all',
                onTap: () {
                  storeController.setFilterType('all');
                  Navigator.pop(context);
                },
              ),
              _FilterOption(
                label: 'delivery'.tr,
                isSelected: storeController.filterType == 'delivery',
                onTap: () {
                  storeController.setFilterType('delivery');
                  Navigator.pop(context);
                },
              ),
              _FilterOption(
                label: 'take_away'.tr,
                isSelected: storeController.filterType == 'take_away',
                onTap: () {
                  storeController.setFilterType('take_away');
                  Navigator.pop(context);
                },
              ),
            ],
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

/// Filter option chip for bottom sheet
class _FilterOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterOption({
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
        borderRadius: BorderRadius.circular(50),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _kTeal : _kTealLight,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: isSelected ? _kTeal : _kTeal.withOpacity(0.1),
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: robotoMedium.copyWith(
              fontSize: 14,
              color: isSelected ? Colors.white : _kTeal.withOpacity(0.7),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
