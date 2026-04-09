import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/styles.dart';

class ItemViewAllFilterBottomSheet extends StatefulWidget {
  final double? maxValue;
  final bool isPopular;
  final bool isSpecial;
  final bool fromDialog;
  const ItemViewAllFilterBottomSheet({super.key, this.maxValue, required this.isPopular, required this.isSpecial, this.fromDialog = false});

  @override
  State<ItemViewAllFilterBottomSheet> createState() => _ItemViewAllFilterBottomSheetState();
}

class _ItemViewAllFilterBottomSheetState extends State<ItemViewAllFilterBottomSheet> {
  int _selectedTab = 0;

  static const List<String> _tabLabels = ['Filter', 'Price', 'Rating', 'Categories'];

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Container(
      height: widget.fromDialog ? 600 : MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(20),
          bottom: Radius.circular(widget.fromDialog ? 20 : 0),
        ),
      ),
      child: GetBuilder<ItemController>(builder: (itemController) {
        double maxVal = widget.maxValue ?? 1000;
        double lowerValue = itemController.selectedMinPrice.clamp(0, maxVal);
        double upperValue = itemController.selectedMaxPrice.clamp(0, maxVal);

        return Column(
          children: [
            _buildHeader(context, primaryColor),
            Expanded(
              child: Row(
                children: [
                  _buildTabRail(primaryColor, itemController),
                  Container(width: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: _buildContent(context, primaryColor, itemController, lowerValue, upperValue, maxVal),
                  ),
                ],
              ),
            ),
            _buildBottomButtons(context, primaryColor, itemController),
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

  Widget _buildTabRail(Color primaryColor, ItemController itemController) {
    return SizedBox(
      width: 100,
      child: Column(
        children: List.generate(_tabLabels.length, (index) {
          final bool isSelected = _selectedTab == index;
          String? subtitle;
          if (index == 1 && (itemController.selectedMinPrice > 0 || itemController.selectedMaxPrice > 0)) {
            subtitle = '${PriceConverter.convertPrice(itemController.selectedMinPrice)} - ${PriceConverter.convertPrice(itemController.selectedMaxPrice)}';
          }
          if (index == 2 && (itemController.rating ?? 0) > 0) {
            subtitle = '${itemController.rating}+';
          }
          if (index == 3 && itemController.selectedCategoryIds.isNotEmpty) {
            subtitle = '${itemController.selectedCategoryIds.length} ${'selected'.tr}';
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
                    _tabLabels[index],
                    style: (isSelected ? robotoBold : robotoMedium).copyWith(
                      fontSize: 13,
                      color: isSelected ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: robotoRegular.copyWith(fontSize: 10, color: primaryColor),
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

  Widget _buildContent(BuildContext context, Color primaryColor, ItemController itemController, double lowerValue, double upperValue, double maxVal) {
    switch (_selectedTab) {
      case 0:
        return _buildFilterContent(primaryColor, itemController);
      case 1:
        return _buildPriceContent(primaryColor, itemController, lowerValue, upperValue, maxVal);
      case 2:
        return _buildRatingContent(primaryColor, itemController);
      case 3:
        return _buildCategoriesContent(primaryColor, itemController);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFilterContent(Color primaryColor, ItemController itemController) {
    bool isFood = Get.find<SplashController>().module != null &&
        Get.find<SplashController>().module!.moduleType.toString() == AppConstants.food;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      children: [
        if (isFood) ...[
          _buildFilterOption(title: 'available'.tr, isSelected: itemController.isAvailableItems, onTap: () => itemController.toggleAvailableItems(), primaryColor: primaryColor),
          _buildFilterOption(title: 'unavailable'.tr, isSelected: itemController.isUnAvailableItems, onTap: () => itemController.toggleUnavailableItems(), primaryColor: primaryColor),
        ],
        _buildFilterOption(title: 'top_rated'.tr, isSelected: itemController.isTopRated, onTap: () => itemController.toggleTopRated(), primaryColor: primaryColor),
        _buildFilterOption(title: 'most_loved'.tr, isSelected: itemController.isMostLoved, onTap: () => itemController.toggleMostLoved(), primaryColor: primaryColor),
        _buildFilterOption(title: 'popular'.tr, isSelected: itemController.isPopular, onTap: () => itemController.togglePopular(), primaryColor: primaryColor),
        _buildFilterOption(title: 'latest'.tr, isSelected: itemController.isLatest, onTap: () => itemController.toggleLatest(), primaryColor: primaryColor),
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
              child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceContent(Color primaryColor, ItemController itemController, double lowerValue, double upperValue, double maxVal) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('price'.tr, style: robotoMedium.copyWith(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(
            '${PriceConverter.convertPrice(lowerValue)} - ${PriceConverter.convertPrice(upperValue)}',
            style: robotoBold.copyWith(fontSize: 22, color: Colors.black87),
          ),
          const SizedBox(height: 32),
          Text('maximum_cost'.tr, style: robotoMedium.copyWith(fontSize: 13, color: Colors.grey.shade600)),
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
              max: maxVal,
              divisions: maxVal.toInt() > 0 ? maxVal.toInt() : 1,
              label: PriceConverter.convertPrice(upperValue),
              onChanged: (val) => itemController.setMinAndMaxPrice(lowerValue, val),
            ),
          ),
          const SizedBox(height: 24),
          Text('minimum_cost'.tr, style: robotoMedium.copyWith(fontSize: 13, color: Colors.grey.shade600)),
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
              max: maxVal,
              divisions: maxVal.toInt() > 0 ? maxVal.toInt() : 1,
              label: PriceConverter.convertPrice(lowerValue),
              onChanged: (val) => itemController.setMinAndMaxPrice(val, upperValue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingContent(Color primaryColor, ItemController itemController) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 5,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        final int rating = 5 - index;
        final bool isSelected = itemController.rating == rating;
        return InkWell(
          onTap: () => itemController.setSelectedRating(rating),
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
                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesContent(Color primaryColor, ItemController itemController) {
    if (itemController.categoryList == null) {
      return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)));
    }
    if (itemController.categoryList!.isEmpty) {
      return Center(child: Text('no_category_found'.tr, style: robotoRegular.copyWith(color: Colors.grey.shade500)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemController.categoryList!.length,
      itemBuilder: (context, index) {
        final cat = itemController.categoryList![index];
        final bool isSelected = itemController.selectedCategoryIds.contains(cat.id);
        return InkWell(
          onTap: () => itemController.toggleCategory(cat.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    cat.name ?? '',
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
                  child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButtons(BuildContext context, Color primaryColor, ItemController itemController) {
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
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  itemController.resetFilters(isPopular: widget.isPopular, isSpecial: widget.isSpecial);
                  Navigator.pop(context);
                },
                child: Center(
                  child: Text(
                    'clear_all'.tr,
                    style: robotoMedium.copyWith(fontSize: 14, color: primaryColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () {
                  itemController.applyFilters(isPopular: widget.isPopular, isSpecial: widget.isSpecial);
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

