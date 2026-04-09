import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';

import 'package:waddy_app/common/widgets/title_widget.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/common/models/module_model.dart';

/// Top Grocery Stores view - shows only grocery module stores
/// with the same design as TopRestaurantsView
class TopGroceryStoresView extends StatelessWidget {
  const TopGroceryStoresView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreController>(
      builder: (storeController) {
        // Use featured store list and filter to grocery module only
        List<Store>? allStores = storeController.featuredStoreList;

        // Filter for grocery module stores only
        List<Store>? groceryList;
        if (allStores != null) {
          final splashController = Get.find<SplashController>();
          final modules = splashController.moduleList;

          // Find the grocery module ID
          int? groceryModuleId;
          if (modules != null) {
            for (var module in modules) {
              if (module.moduleType?.toLowerCase() ==
                  AppConstants.grocery.toLowerCase()) {
                groceryModuleId = module.id;
                break;
              }
            }
          }

          if (groceryModuleId != null) {
            groceryList =
                allStores
                    .where((store) => store.moduleId == groceryModuleId)
                    .toList();
          } else {
            // Fallback: If no grocery module found, show all stores
            groceryList = allStores;
          }
        }

        return (groceryList != null && groceryList.isEmpty)
            ? const SizedBox.shrink()
            : Padding(
              padding: const EdgeInsets.only(
                top: Dimensions.paddingSizeDefault,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                    ),
                    child: TitleWidget(
                      title: 'top_grocery_stores'.tr,
                      onTap:
                          () => Get.toNamed(
                            RouteHelper.getAllStoreRoute('featured'),
                          ),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  SizedBox(
                    height: 170,
                    child:
                        groceryList != null
                            ? ListView.builder(
                              controller: ScrollController(),
                              physics: const BouncingScrollPhysics(),
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(
                                left: Dimensions.paddingSizeDefault,
                              ),
                              itemCount:
                                  groceryList.length > 10
                                      ? 10
                                      : groceryList.length,
                              itemBuilder: (context, index) {
                                final store = groceryList![index];
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    right: Dimensions.paddingSizeDefault,
                                    bottom: Dimensions.paddingSizeSmall,
                                    top: Dimensions.paddingSizeSmall,
                                  ),
                                  child: _GroceryStoreCard(store: store),
                                );
                              },
                            )
                            : const _GroceryStoreShimmer(),
                  ),
                ],
              ),
            );
      },
    );
  }
}

/// Creative grocery store card with tilted top items showcase
class _GroceryStoreCard extends StatefulWidget {
  final Store store;

  const _GroceryStoreCard({required this.store});

  @override
  State<_GroceryStoreCard> createState() => _GroceryStoreCardState();
}

class _GroceryStoreCardState extends State<_GroceryStoreCard> {
  bool _isPressed = false;
  bool _isFetching = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;

    return GetBuilder<StoreController>(
      builder: (storeController) {
        // Get store-specific recommended items from the cache
        List<Item> storeItems = storeController.storeRecommendedItems[store.id] ?? [];
        
        // If not loaded yet, fetch them
        if (storeItems.isEmpty && !_isFetching) {
          _isFetching = true;
          storeController.fetchStoreRecommendedItems(store.id!).then((items) {
            if (mounted) {
              setState(() {
                _isFetching = false;
              });
            }
          });
        }
        
        // Take only first 3 items
        storeItems = storeItems.take(3).toList();

        final hasDiscount =
            store.discount != null &&
            store.discount!.discount != null &&
            store.discount!.discount! > 0;
        final isOpen = store.open == 1 && store.active == true;

        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _navigateToStore();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              width: 180,
              height: 150,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Background image (store cover)
                    Positioned.fill(
                      child: CustomImage(
                        image: '${store.coverPhotoFullUrl}',
                        fit: BoxFit.cover,
                      ),
                    ),

                    // Gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.black.withOpacity(0.7),
                            ],
                            stops: const [0.3, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // 3 Tilted Items Showcase (top right) - only show if items exist
                    if (storeItems.isNotEmpty)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: SizedBox(
                          width: 80,
                          height: 50,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // Item 3 (back left) - show 3rd item if available
                              if (storeItems.length >= 3)
                                Positioned(
                                  left: 0,
                                  child: Transform(
                                    transform:
                                        Matrix4.identity()
                                          ..setEntry(3, 2, 0.001)
                                          ..rotateZ(-0.15),
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(-2, 3),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CustomImage(
                                          image:
                                              '${storeItems[2].imageFullUrl}',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Item 1 (back right) - show 2nd item if available
                              if (storeItems.length >= 2)
                                Positioned(
                                  right: 0,
                                  child: Transform(
                                    transform:
                                        Matrix4.identity()
                                          ..setEntry(3, 2, 0.001)
                                          ..rotateZ(0.15),
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(2, 3),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CustomImage(
                                          image:
                                              '${storeItems[1].imageFullUrl}',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Item 2 (center front - larger) - always show 1st item
                              Positioned(
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: CustomImage(
                                      image: '${storeItems[0].imageFullUrl}',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Discount badge
                    if (hasDiscount)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${store.discount!.discount!.toInt()}%',
                            style: robotoMedium.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),

                    // Closed overlay
                    if (!isOpen)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.6),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'closed'.tr,
                                style: robotoMedium.copyWith(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Bottom info section
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CustomImage(
                                    image: '${store.logoFullUrl}',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    store.name ?? '',
                                    style: robotoMedium.copyWith(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 12,
                                        color: Color(0xFFFFD700),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${store.avgRating?.toStringAsFixed(1) ?? '0.0'}',
                                        style: robotoMedium.copyWith(
                                          fontSize: 11,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (store.deliveryTime != null) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 10,
                                          color: Colors.white70,
                                        ),
                                        const SizedBox(width: 2),
                                        Flexible(
                                          child: Text(
                                            store.deliveryTime!,
                                            style: robotoRegular.copyWith(
                                              fontSize: 10,
                                              color: Colors.white70,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToStore() {
    final store = widget.store;
    final splashController = Get.find<SplashController>();
    if (splashController.moduleList != null) {
      for (ModuleModel module in splashController.moduleList!) {
        if (module.id == store.moduleId) {
          splashController.setModule(module);
          break;
        }
      }
    }
    Get.toNamed(
      RouteHelper.getStoreRoute(id: store.id, page: 'module'),
      arguments: StoreScreen(store: store, fromModule: true),
    );
  }
}

/// Shimmer loading state
class _GroceryStoreShimmer extends StatelessWidget {
  const _GroceryStoreShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: Dimensions.paddingSizeDefault),
          child: Shimmer(
            duration: const Duration(seconds: 2),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );
      },
    );
  }
}
