import 'package:waddy_app/features/search/controllers/search_controller.dart'
    as search;
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/util/dimensions.dart';

class FilterWidget extends StatefulWidget {
  final double? maxValue;
  final bool isStore;
  const FilterWidget({
    super.key,
    required this.maxValue,
    required this.isStore,
  });

  @override
  State<FilterWidget> createState() => _FilterWidgetState();
}

class _FilterWidgetState extends State<FilterWidget> {
  int _selectedTab = 0;

  List<String> get _tabLabels =>
      widget.isStore
          ? ['Sort', 'Filter', 'Rating']
          : ['Sort', 'Filter', 'Price', 'Rating'];

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimensions.radiusExtraLarge),
        ),
      ),
      child: GetBuilder<search.SearchController>(
        builder: (searchController) {
          return Column(
            children: [
              _buildHeader(context, primaryColor),
              Expanded(
                child: Row(
                  children: [
                    _buildTabRail(primaryColor, searchController),
                    Container(width: 1, color: Colors.grey.shade200),
                    Expanded(
                      child: _buildContent(
                        context,
                        primaryColor,
                        searchController,
                      ),
                    ),
                  ],
                ),
              ),
              _buildBottomButtons(context, primaryColor, searchController),
            ],
          );
        },
      ),
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
            style: waddyBold.copyWith(fontSize: 18, color: Colors.black87),
          ),
          const Spacer(),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
            child: Container(
              width: 32,
              height: 32,
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

  Widget _buildTabRail(
    Color primaryColor,
    search.SearchController searchController,
  ) {
    return SizedBox(
      width: 100,
      child: Column(
        children: List.generate(_tabLabels.length, (index) {
          final bool isSelected = _selectedTab == index;
          String? subtitle;
          // Price tab subtitle
          if (!widget.isStore &&
              index == 2 &&
              (searchController.lowerValue > 0 ||
                  searchController.upperValue > 0)) {
            subtitle =
                '${PriceConverter.convertPrice(searchController.lowerValue)} - ${PriceConverter.convertPrice(searchController.upperValue)}';
          }
          // Rating tab subtitle
          final int ratingTabIndex = widget.isStore ? 2 : 3;
          final int currentRating =
              widget.isStore
                  ? searchController.storeRating
                  : searchController.rating;
          if (index == ratingTabIndex && currentRating > 0) {
            subtitle = '$currentRating+';
          }
          // Sort tab subtitle
          final int currentSortIndex =
              widget.isStore
                  ? searchController.storeSortIndex
                  : searchController.sortIndex;
          if (index == 0 &&
              currentSortIndex >= 0 &&
              currentSortIndex < searchController.sortList.length) {
            subtitle = searchController.sortList[currentSortIndex];
          }

          return GestureDetector(
            onTap: () => setState(() => _selectedTab = index),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeDefault,
                horizontal: Dimensions.paddingSizeSmall,
              ),
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
                    style: (isSelected ? waddyBold : waddyMedium).copyWith(
                      fontSize: 13,
                      color: isSelected ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: waddyRegular.copyWith(
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
    BuildContext context,
    Color primaryColor,
    search.SearchController searchController,
  ) {
    if (_selectedTab == 0)
      return _buildSortContent(primaryColor, searchController);
    if (_selectedTab == 1)
      return _buildFilterContent(primaryColor, searchController);
    if (!widget.isStore && _selectedTab == 2)
      return _buildPriceContent(primaryColor, searchController);
    return _buildRatingContent(primaryColor, searchController);
  }

  Widget _buildSortContent(
    Color primaryColor,
    search.SearchController searchController,
  ) {
    final int currentIndex =
        widget.isStore
            ? searchController.storeSortIndex
            : searchController.sortIndex;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeSmall,
      ),
      itemCount: searchController.sortList.length,
      separatorBuilder:
          (_, __) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        final bool isSelected = currentIndex == index;
        return InkWell(
          onTap: () {
            if (widget.isStore) {
              searchController.setStoreSortIndex(index);
            } else {
              searchController.setSortIndex(index);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeMedium,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    searchController.sortList[index],
                    style: (isSelected ? waddyMedium : waddyRegular).copyWith(
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

  Widget _buildFilterContent(
    Color primaryColor,
    search.SearchController searchController,
  ) {
    final bool showVegNonVeg =
        Get.find<SplashController>().configModel.toggleVegNonVeg! &&
        Get.find<SplashController>()
            .configModel
            .moduleConfig!
            .module!
            .vegNonVeg!;

    return ListView(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeSmall,
        horizontal: Dimensions.paddingSizeDefault,
      ),
      children: [
        if (showVegNonVeg) ...[
          _buildFilterOption(
            title: 'veg'.tr,
            isSelected:
                widget.isStore
                    ? searchController.storeVeg
                    : searchController.veg,
            onTap:
                () =>
                    widget.isStore
                        ? searchController.toggleStoreVeg()
                        : searchController.toggleVeg(),
            primaryColor: primaryColor,
          ),
          _buildFilterOption(
            title: 'non_veg'.tr,
            isSelected:
                widget.isStore
                    ? searchController.storeNonVeg
                    : searchController.nonVeg,
            onTap:
                () =>
                    widget.isStore
                        ? searchController.toggleStoreNonVeg()
                        : searchController.toggleNonVeg(),
            primaryColor: primaryColor,
          ),
        ],
        _buildFilterOption(
          title:
              widget.isStore
                  ? (Get.find<SplashController>()
                              .configModel
                              .moduleConfig!
                              .module!
                              .showRestaurantText ??
                          false
                      ? 'currently_opened_restaurants'.tr
                      : 'currently_opened_stores'.tr)
                  : 'currently_available_items'.tr,
          isSelected:
              widget.isStore
                  ? searchController.isAvailableStore
                  : searchController.isAvailableItems,
          onTap: () {
            if (widget.isStore) {
              searchController.toggleAvailableStore();
            } else {
              searchController.toggleAvailableItems();
            }
          },
          primaryColor: primaryColor,
        ),
        _buildFilterOption(
          title:
              widget.isStore
                  ? (Get.find<SplashController>()
                              .configModel
                              .moduleConfig!
                              .module!
                              .showRestaurantText ??
                          false
                      ? 'discounted_restaurants'.tr
                      : 'discounted_stores'.tr)
                  : 'discounted_items'.tr,
          isSelected:
              widget.isStore
                  ? searchController.isDiscountedStore
                  : searchController.isDiscountedItems,
          onTap: () {
            if (widget.isStore) {
              searchController.toggleDiscountedStore();
            } else {
              searchController.toggleDiscountedItems();
            }
          },
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
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeMedium,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: (isSelected ? waddyMedium : waddyRegular).copyWith(
                  fontSize: 14,
                  color: isSelected ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(
                  Dimensions.radiusExtraSmall,
                ),
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child:
                  isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceContent(
    Color primaryColor,
    search.SearchController searchController,
  ) {
    double lowerValue = searchController.lowerValue;
    double upperValue = searchController.upperValue;
    double maxVal = widget.maxValue ?? 1000;

    return Padding(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'price'.tr,
            style: waddyMedium.copyWith(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${PriceConverter.convertPrice(lowerValue)} - ${PriceConverter.convertPrice(upperValue)}',
            style: waddyBold.copyWith(fontSize: 22, color: Colors.black87),
          ),
          const SizedBox(height: 32),
          Text(
            'maximum_cost'.tr,
            style: waddyMedium.copyWith(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
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
              valueIndicatorTextStyle: waddyBold.copyWith(
                color: Colors.white,
                fontSize: 12,
              ),
              showValueIndicator: ShowValueIndicator.always,
            ),
            child: Slider(
              value: upperValue.clamp(0, maxVal),
              min: 0,
              max: maxVal,
              divisions: maxVal.toInt() > 0 ? maxVal.toInt() : 1,
              label: PriceConverter.convertPrice(upperValue),
              onChanged:
                  (val) =>
                      searchController.setLowerAndUpperValue(lowerValue, val),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'minimum_cost'.tr,
            style: waddyMedium.copyWith(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
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
              valueIndicatorTextStyle: waddyBold.copyWith(
                color: Colors.white,
                fontSize: 12,
              ),
              showValueIndicator: ShowValueIndicator.always,
            ),
            child: Slider(
              value: lowerValue.clamp(0, maxVal),
              min: 0,
              max: maxVal,
              divisions: maxVal.toInt() > 0 ? maxVal.toInt() : 1,
              label: PriceConverter.convertPrice(lowerValue),
              onChanged:
                  (val) =>
                      searchController.setLowerAndUpperValue(val, upperValue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingContent(
    Color primaryColor,
    search.SearchController searchController,
  ) {
    final int currentRating =
        widget.isStore ? searchController.storeRating : searchController.rating;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeSmall,
      ),
      itemCount: 5,
      separatorBuilder:
          (_, __) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        final int rating = 5 - index;
        final bool isSelected = currentRating == rating;
        return InkWell(
          onTap:
              () =>
                  widget.isStore
                      ? searchController.setStoreRating(rating)
                      : searchController.setRating(rating),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeMedium,
            ),
            child: Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(
                        i < rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 20,
                        color:
                            i < rating
                                ? Colors.amber.shade600
                                : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  rating == 5 ? '5' : '$rating+',
                  style: waddyMedium.copyWith(
                    fontSize: 14,
                    color: isSelected ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child:
                      isSelected
                          ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          )
                          : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButtons(
    BuildContext context,
    Color primaryColor,
    search.SearchController searchController,
  ) {
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
                  if (widget.isStore) {
                    searchController.resetStoreFilter();
                  } else {
                    searchController.resetFilter();
                  }
                },
                child: Center(
                  child: Text(
                    'clear_all'.tr,
                    style: waddyMedium.copyWith(
                      fontSize: 14,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () {
                  if (widget.isStore) {
                    searchController.sortStoreSearchList();
                  } else {
                    searchController.sortItemSearchList();
                  }
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimensions.paddingSizeMedium,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'apply'.tr,
                      style: waddyBold.copyWith(
                        fontSize: 15,
                        color: Colors.white,
                      ),
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
