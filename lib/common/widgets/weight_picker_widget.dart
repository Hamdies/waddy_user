import 'package:flutter/material.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Detects if a list of option strings look like weight/unit values.
/// Returns true if most options match patterns like "500g", "1kg", "250ml", "1L", "1 piece", etc.
bool looksLikeWeightOptions(List<String> options) {
  if (options.isEmpty) return false;
  final weightPattern = RegExp(
    r'^\s*\d+\.?\d*\s*(g|kg|gm|gram|grams|ml|l|liter|litre|liters|litres|oz|lb|lbs|piece|pieces|pcs|pc|pack|packs|unit|units)\s*$',
    caseSensitive: false,
  );
  int matchCount = 0;
  for (final option in options) {
    if (weightPattern.hasMatch(option.trim())) {
      matchCount++;
    }
  }
  return matchCount >= (options.length * 0.5);
}

/// A horizontal chip-based picker for weight/unit variations.
/// Replaces the default vertical radio list when options look like weights.
class WeightPickerWidget extends StatelessWidget {
  final Item? item;
  final ItemController itemController;
  final int choiceIndex;

  const WeightPickerWidget({
    super.key,
    required this.item,
    required this.itemController,
    required this.choiceIndex,
  });

  @override
  Widget build(BuildContext context) {
    final choiceOption = item!.choiceOptions![choiceIndex];
    final options = choiceOption.options!;
    final selectedIndex = itemController.variationIndex![choiceIndex];
    final Color primaryColor = Theme.of(context).primaryColor;

    // Find matching variation prices for each option
    List<double?> optionPrices = _getOptionPrices(options);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.scale_rounded, size: 16, color: primaryColor),
            const SizedBox(width: 6),
            Text(
              choiceOption.title ?? 'select_weight',
              style: waddyMedium.copyWith(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(options.length, (i) {
            final bool isSelected = selectedIndex == i;
            final String label = options[i].trim();
            final double? price = optionPrices[i];

            return GestureDetector(
              onTap:
                  () => itemController.setCartVariationIndex(
                    choiceIndex,
                    i,
                    item,
                  ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeMedium,
                  vertical: Dimensions.paddingSizeSmall,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: waddyMedium.copyWith(
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (price != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        PriceConverter.convertPrice(price),
                        style: waddyRegular.copyWith(
                          fontSize: 11,
                          color:
                              isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: Dimensions.paddingSizeLarge),
      ],
    );
  }

  /// Try to match each option to a Variation to get its price.
  List<double?> _getOptionPrices(List<String> options) {
    if (item?.variations == null || item!.variations!.isEmpty) {
      return List.filled(options.length, null);
    }

    // Build the variation type string for each option index
    // For single choice option, the type is just the option value
    // For multiple choice options, it's "opt1-opt2-..."
    List<double?> prices = [];
    for (int i = 0; i < options.length; i++) {
      double? matchedPrice;
      String optionValue = options[i].trim().replaceAll(' ', '');

      for (Variation v in item!.variations!) {
        if (v.type != null && v.type!.contains(optionValue)) {
          matchedPrice = v.price;
          break;
        }
      }
      prices.add(matchedPrice);
    }
    return prices;
  }
}
