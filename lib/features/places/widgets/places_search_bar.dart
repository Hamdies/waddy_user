import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class PlacesSearchBar extends StatefulWidget {
  const PlacesSearchBar({super.key});

  @override
  State<PlacesSearchBar> createState() => _PlacesSearchBarState();
}

class _PlacesSearchBarState extends State<PlacesSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final neon = Theme.of(context).secondaryHeaderColor;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: neon.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: neon.withValues(alpha: 0.06),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Text('🔍', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: robotoMedium.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'search_hidden_gems'.tr,
                  hintStyle: robotoRegular.copyWith(
                    fontSize: 14,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onSubmitted: (value) {
                  Get.find<PlacesController>().searchPlaces(value.trim());
                },
                textInputAction: TextInputAction.search,
              ),
            ),
            GetBuilder<PlacesController>(
              builder: (controller) {
                if (controller.searchQuery.isNotEmpty) {
                  return GestureDetector(
                    onTap: () {
                      _controller.clear();
                      controller.searchPlaces('');
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: neon.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 16, color: neon),
                    ),
                  );
                }
                return const SizedBox(width: 14);
              },
            ),
          ],
        ),
      ),
    );
  }
}
