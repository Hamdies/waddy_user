import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';

import 'package:sixam_mart/util/app_design_tokens.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/features/store/domain/models/store_model.dart';
import 'package:sixam_mart/features/store/screens/store_screen.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:sixam_mart/common/models/module_model.dart';

/// Top Grocery view - shows only grocery module stores
/// with full-bleed card style + "Waddy's Choice" sticker
class TopGroceryView extends StatelessWidget {
  const TopGroceryView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreController>(
      builder: (storeController) {
        List<Store>? allStores = storeController.featuredStoreList;

        List<Store>? groceryList;
        if (allStores != null) {
          final splashController = Get.find<SplashController>();
          final modules = splashController.moduleList;

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
            groceryList = allStores
                .where((store) => store.moduleId == groceryModuleId)
                .toList();
          } else {
            groceryList = allStores;
          }
        }

        return (groceryList != null && groceryList.isEmpty)
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: Dimensions.paddingSizeDefault),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeDefault,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IntrinsicWidth(
                            child: Stack(
                              children: [
                                Positioned(
                                  bottom: 2, left: 0, right: 0,
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                Text(
                                  'top_grocery_stores'.tr,
                                  style: robotoBold.copyWith(fontSize: 18, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Get.toNamed(RouteHelper.getAllStoreRoute('featured')),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppDesignTokens.secondaryNeon.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('view_all'.tr,
                                    style: robotoMedium.copyWith(fontSize: 12, color: Theme.of(context).primaryColor)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 14, color: Theme.of(context).primaryColor),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    SizedBox(
                      height: 165,
                      child: groceryList != null
                          ? ListView.builder(
                              controller: ScrollController(),
                              physics: const BouncingScrollPhysics(),
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(
                                left: Dimensions.paddingSizeDefault,
                              ),
                              itemCount: groceryList.length > 10
                                  ? 10
                                  : groceryList.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 14, bottom: 4, top: 4),
                                  child: _GroceryCard(store: groceryList![index]),
                                );
                              },
                            )
                          : const _GroceryShimmer(),
                    ),
                  ],
                ),
              );
      },
    );
  }
}

/// Full-bleed grocery card with Waddy's Choice sticker
class _GroceryCard extends StatefulWidget {
  final Store store;
  const _GroceryCard({required this.store});

  @override
  State<_GroceryCard> createState() => _GroceryCardState();
}

class _GroceryCardState extends State<_GroceryCard> {
  bool _isPressed = false;
  bool _isFetching = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;
    final isOpen = store.open == 1 && store.active == true;

    return GetBuilder<StoreController>(
      builder: (storeController) {
        List<Item> storeItems =
            storeController.storeRecommendedItems[store.id] ?? [];

        if (storeItems.isEmpty && !_isFetching) {
          _isFetching = true;
          storeController.fetchStoreRecommendedItems(store.id!).then((_) {
            if (mounted) setState(() => _isFetching = false);
          });
        }

        final topItems = storeItems.take(2).toList();

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
            child: Opacity(
              opacity: isOpen ? 1.0 : 0.55,
              child: Container(
                width: 210,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // ── Full-bleed cover ──
                      Positioned.fill(
                        child: CustomImage(
                          image: store.coverPhotoFullUrl ?? '',
                          fit: BoxFit.cover,
                        ),
                      ),

                      // ── Gradient overlay ──
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                primaryColor.withValues(alpha: 0.15),
                                primaryColor.withValues(alpha: 0.7),
                                primaryColor.withValues(alpha: 0.97),
                              ],
                              stops: const [0.0, 0.25, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // ── Closed overlay ──
                      if (!isOpen)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.55),
                            child: Center(
                              child: Transform.rotate(
                                angle: -0.12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: Text('CLOSED',
                                    style: robotoBold.copyWith(
                                      fontSize: 13, color: Colors.black87,
                                      letterSpacing: 3,
                                    )),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ── Logo floating top-left ──
                      Positioned(
                        top: 10, left: 10,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: CustomImage(image: store.logoFullUrl ?? '', fit: BoxFit.cover),
                          ),
                        ),
                      ),

                      // ── Tilted top items — bottom right ──
                      if (topItems.isNotEmpty && isOpen)
                        Positioned(
                          bottom: 44, right: 12,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(topItems.length, (i) {
                              final angles = [-0.15, 0.1, -0.08];
                              final offsets = [6.0, 0.0, 4.0];
                              return Transform.translate(
                                offset: Offset(0, offsets[i % 3]),
                                child: Transform.rotate(
                                  angle: angles[i % 3],
                                  child: Container(
                                    width: 38, height: 38,
                                    margin: const EdgeInsets.only(left: 5),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(9),
                                      color: Colors.white,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: CustomImage(
                                        image: topItems[i].imageFullUrl ?? '',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                      // ── Bottom info overlay ──
                      Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(store.name ?? '',
                                style: robotoBold.copyWith(
                                  fontSize: 14, color: Colors.white,
                                ),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              if (store.deliveryTime != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.schedule_rounded, size: 11, color: primaryColor),
                                      const SizedBox(width: 3),
                                      Text('${store.deliveryTime}',
                                        style: robotoBold.copyWith(fontSize: 10, color: primaryColor)),
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
class _GroceryShimmer extends StatelessWidget {
  const _GroceryShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Shimmer(
            duration: const Duration(seconds: 2),
            child: Container(
              width: 210,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );
      },
    );
  }
}
