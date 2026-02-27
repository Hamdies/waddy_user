import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FilterWidget extends StatefulWidget {
  final double? maxValue;
  const FilterWidget({super.key, required this.maxValue});

  @override
  State<FilterWidget> createState() => _FilterWidgetState();
}

class _FilterWidgetState extends State<FilterWidget> {
  int _selectedTab = 0;

  static const List<_TabItem> _tabs = [
    _TabItem(label: 'Sort', icon: Icons.swap_vert_rounded),
    _TabItem(label: 'Filter', icon: Icons.filter_list_rounded),
    _TabItem(label: 'Price', icon: Icons.attach_money_rounded),
    _TabItem(label: 'Rating', icon: Icons.star_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: GetBuilder<StoreController>(builder: (storeController) {
        double lowerValue = storeController.lowerValue.clamp(0, widget.maxValue!);
        double upperValue = storeController.upperValue.clamp(0, widget.maxValue!);

        return Column(
          children: [
            // ─── Header ───
            _buildHeader(context, primaryColor),

            // ─── Body: left tabs + right content ───
            Expanded(
              child: Row(
                children: [
                  // Left tab rail
                  _buildTabRail(primaryColor, accentColor, storeController),

                  // Vertical divider
                  Container(width: 1, color: Colors.grey.shade200),

                  // Right content
                  Expanded(
                    child: _buildContent(
                      context, primaryColor, accentColor,
                      storeController, lowerValue, upperValue,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Bottom buttons ───
            _buildBottomButtons(context, primaryColor, accentColor, storeController),
          ],
        );
      }),
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            'sort_by'.tr,
            style: robotoBold.copyWith(fontSize: 18, color: Colors.black87),
          ),
          const Spacer(),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabRail(Color primaryColor, Color accentColor, StoreController storeController) {
    return SizedBox(
      width: 100,
      child: Column(
        children: List.generate(_tabs.length, (index) {
          final bool isSelected = _selectedTab == index;
          final tab = _tabs[index];
          String? subtitle;
          if (index == 2 && (storeController.lowerValue > 0 || storeController.upperValue > 0)) {
            subtitle = '${PriceConverter.convertPrice(storeController.lowerValue)} - ${PriceConverter.convertPrice(storeController.upperValue)}';
          }
          if (index == 3 && storeController.rating > 0) {
            subtitle = '${storeController.rating}+';
          }

          return GestureDetector(
            onTap: () => setState(() => _selectedTab = index),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey.shade50,
                border: Border(
                  left: BorderSide(
                    color: isSelected ? primaryColor : Colors.transparent,
                    width: 3,
                  ),
                  bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tab.label,
                    style: (isSelected ? robotoBold : robotoMedium).copyWith(
                      fontSize: 13,
                      color: isSelected ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: robotoRegular.copyWith(
                        fontSize: 10,
                        color: primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, Color primaryColor, Color accentColor,
    StoreController storeController, double lowerValue, double upperValue,
  ) {
    switch (_selectedTab) {
      case 0:
        return _buildSortContent(primaryColor, storeController);
      case 1:
        return _buildFilterContent(primaryColor, storeController);
      case 2:
        return _buildPriceContent(primaryColor, accentColor, storeController, lowerValue, upperValue);
      case 3:
        return _buildRatingContent(primaryColor, storeController);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSortContent(Color primaryColor, StoreController storeController) {
    final sortOptions = [
      'default'.tr,
      'price_low_to_high'.tr,
      'price_high_to_low'.tr,
      'a_to_z'.tr,
      'z_to_a'.tr,
    ];
    // Map sort index: -1 = default (index 0), 0..3 = options 1..4
    int currentIndex = (storeController.sortIndex ?? -1) + 1;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortOptions.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        final bool isSelected = currentIndex == index;
        return InkWell(
          onTap: () {
            storeController.setSortIndex(index == 0 ? -1 : index - 1);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sortOptions[index],
                    style: (isSelected ? robotoMedium : robotoRegular).copyWith(
                      fontSize: 14,
                      color: isSelected ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_rounded, size: 20, color: primaryColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterContent(Color primaryColor, StoreController storeController) {
    bool isFood = Get.find<SplashController>().module != null &&
        Get.find<SplashController>().module!.moduleType.toString() == AppConstants.food;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      children: [
        if (isFood)
          _buildFilterOption(
            title: 'currently_available_items'.tr,
            isSelected: storeController.isAvailableItems,
            onTap: () => storeController.toggleAvailableItems(),
            primaryColor: primaryColor,
          ),
        _buildFilterOption(
          title: 'discounted_items'.tr,
          isSelected: storeController.isDiscountedItems,
          onTap: () => storeController.toggleDiscountedItems(),
          primaryColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildFilterOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: (isSelected ? robotoMedium : robotoRegular).copyWith(
                  fontSize: 14,
                  color: isSelected ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ),
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceContent(
    Color primaryColor, Color accentColor,
    StoreController storeController, double lowerValue, double upperValue,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'price'.tr,
            style: robotoMedium.copyWith(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '${PriceConverter.convertPrice(lowerValue)} - ${PriceConverter.convertPrice(upperValue)}',
            style: robotoBold.copyWith(fontSize: 22, color: Colors.black87),
          ),
          const SizedBox(height: 32),
          // Maximum cost
          Text(
            'maximum_cost'.tr,
            style: robotoMedium.copyWith(fontSize: 13, color: Colors.grey.shade600),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: primaryColor,
              inactiveTrackColor: Colors.grey.shade300,
              thumbColor: Colors.black87,
              overlayColor: primaryColor.withValues(alpha: 0.1),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              valueIndicatorColor: Colors.black87,
              valueIndicatorTextStyle: robotoBold.copyWith(color: Colors.white, fontSize: 12),
              showValueIndicator: ShowValueIndicator.always,
            ),
            child: Slider(
              value: upperValue,
              min: 0,
              max: widget.maxValue!,
              divisions: widget.maxValue!.toInt() > 0 ? widget.maxValue!.toInt() : 1,
              label: PriceConverter.convertPrice(upperValue),
              onChanged: (val) {
                storeController.setLowerAndUpperValue(lowerValue, val);
              },
            ),
          ),
          const SizedBox(height: 24),
          // Minimum cost
          Text(
            'minimum_cost'.tr,
            style: robotoMedium.copyWith(fontSize: 13, color: Colors.grey.shade600),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: primaryColor,
              inactiveTrackColor: Colors.grey.shade300,
              thumbColor: Colors.black87,
              overlayColor: primaryColor.withValues(alpha: 0.1),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              valueIndicatorColor: Colors.black87,
              valueIndicatorTextStyle: robotoBold.copyWith(color: Colors.white, fontSize: 12),
              showValueIndicator: ShowValueIndicator.always,
            ),
            child: Slider(
              value: lowerValue,
              min: 0,
              max: widget.maxValue!,
              divisions: widget.maxValue!.toInt() > 0 ? widget.maxValue!.toInt() : 1,
              label: PriceConverter.convertPrice(lowerValue),
              onChanged: (val) {
                storeController.setLowerAndUpperValue(val, upperValue);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingContent(Color primaryColor, StoreController storeController) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 5,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        final int rating = 5 - index;
        final bool isSelected = storeController.rating == rating;
        return InkWell(
          onTap: () => storeController.setRating(rating),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Row(
                  children: List.generate(5, (i) => Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 20,
                      color: i < rating ? Colors.amber.shade600 : Colors.grey.shade300,
                    ),
                  )),
                ),
                const SizedBox(width: 8),
                Text(
                  rating == 5 ? '5' : '$rating+',
                  style: robotoMedium.copyWith(
                    fontSize: 14,
                    color: isSelected ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButtons(BuildContext context, Color primaryColor, Color accentColor, StoreController storeController) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Clear All
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => storeController.resetFilter(),
                child: Center(
                  child: Text(
                    'clear_all'.tr,
                    style: robotoMedium.copyWith(fontSize: 14, color: primaryColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Apply
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () {
                  storeController.getStoreItemList(storeController.store!.id, 1, storeController.type, true);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'apply'.tr,
                      style: robotoBold.copyWith(fontSize: 15, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  const _TabItem({required this.label, required this.icon});
}
