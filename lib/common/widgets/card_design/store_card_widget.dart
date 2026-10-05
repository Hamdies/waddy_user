import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/common/widgets/custom_ink_well.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';

class StoreCardWidget extends StatefulWidget {
  final Store? store;
  const StoreCardWidget({super.key, required this.store});

  @override
  State<StoreCardWidget> createState() => _StoreCardWidgetState();
}

class _StoreCardWidgetState extends State<StoreCardWidget> {
  bool _isFetching = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    double? discount = store!.discount != null ? store.discount!.discount : 0;
    String? discountType =
        store.discount != null ? store.discount!.discountType : 'percent';
    bool isAvailable = store.open == 1 && store.active!;
    bool hasDiscount = discount != null && discount > 0;

    return GetBuilder<StoreListController>(
      id: StoreListController.storeRecommendedItemsId,
      builder: (storeController) {
        // Get store-specific recommended items from the cache
        List<Item> storeItems =
            storeController.storeRecommendedItems[store.id] ?? [];

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

        return Container(
          width: 180,
          height: 150,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CustomInkWell(
            onTap: () {
              if (store != null) {
                StoreNavigator.open(store, page: 'item');
              }
            },
            radius: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child: Stack(
                children: [
                  // Background cover image
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

                  // 3 Tilted Items Showcase (top right)
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
                            // Item 3 (back left)
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
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(-2, 3),
                                        ),
                                      ],
                                    ),
                                    child: CustomImage(
                                      image: '${storeItems[2].imageFullUrl}',
                                      fit: BoxFit.cover,
                                      // Rounded by the decoration, not a ClipRRect — no saveLayer.
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusSmall,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Item 1 (back right)
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
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(2, 3),
                                        ),
                                      ],
                                    ),
                                    child: CustomImage(
                                      image: '${storeItems[1].imageFullUrl}',
                                      fit: BoxFit.cover,
                                      // Rounded by the decoration, not a ClipRRect — no saveLayer.
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusSmall,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Item 2 (center front - larger)
                            Positioned(
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusDefault,
                                  ),
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
                                child: CustomImage(
                                  image: '${storeItems[0].imageFullUrl}',
                                  fit: BoxFit.cover,
                                  // Rounded by the decoration, not a ClipRRect — no saveLayer.
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusSmall,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Smart badges (top left)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDiscount)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(
                              bottom: Dimensions.paddingSizeExtraSmall,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusDefault,
                              ),
                            ),
                            child: Text(
                              discountType == 'percent'
                                  ? '${discount.toInt()}%'
                                  : '\$${discount.toInt()}',
                              style: waddyMedium.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        if (store.freeDelivery == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(
                              bottom: Dimensions.paddingSizeExtraSmall,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusDefault,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_shipping_outlined,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'free_delivery'.tr,
                                  style: waddyMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Closed overlay
                  if (!isAvailable)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.6),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Dimensions.paddingSizeDefault,
                              vertical: Dimensions.paddingSizeSmall,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusExtraLarge,
                              ),
                            ),
                            child: Text(
                              'closed'.tr,
                              style: waddyMedium.copyWith(
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
                      padding: const EdgeInsets.all(
                        Dimensions.paddingSizeSmall,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusSmall,
                              ),
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
                              child: CustomImage(
                                image: '${store.logoFullUrl}',
                                fit: BoxFit.cover,
                                // Rounded by the decoration, not a ClipRRect — no saveLayer.
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
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
                                  style: waddyMedium.copyWith(
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
                                    _buildRatingWidget(context, store),
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
                                          style: waddyRegular.copyWith(
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
        );
      },
    );
  }
}

Widget _buildRatingWidget(BuildContext context, Store store) {
  final hasGoodRating = store.avgRating != null && store.avgRating! >= 4.0;
  final hasAnyRating =
      store.avgRating != null &&
      store.avgRating! > 0 &&
      store.ratingCount != null &&
      store.ratingCount! >= 5;

  if (hasAnyRating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          size: 12,
          color: hasGoodRating ? const Color(0xFFFFD700) : Colors.white70,
        ),
        const SizedBox(width: 2),
        Text(
          store.avgRating!.toStringAsFixed(1),
          style: waddyMedium.copyWith(fontSize: 11, color: Colors.white),
        ),
        Text(
          ' (${store.ratingCount})',
          style: waddyRegular.copyWith(fontSize: 9, color: Colors.white70),
        ),
      ],
    );
  } else {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            'new'.tr.toUpperCase(),
            style: waddyBold.copyWith(
              fontSize: 8,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreCardShimmer extends StatelessWidget {
  const StoreCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      width: 500,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      child: Shimmer(
        duration: const Duration(seconds: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Dimensions.radiusSmall),
                ),
                color: Theme.of(context).shadowColor,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      height: 15,
                      width: 200,
                      color: Theme.of(context).shadowColor,
                    ),
                    const SizedBox(height: 5),

                    Container(
                      height: 10,
                      width: 130,
                      color: Theme.of(context).shadowColor,
                    ),
                    const SizedBox(height: 5),

                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          Icons.star,
                          color: Theme.of(context).shadowColor,
                          size: 15,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
