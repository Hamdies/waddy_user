import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class NearbyStoresHeroView extends StatelessWidget {
  const NearbyStoresHeroView({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<StoreController>(builder: (storeController) {
      List<Store>? stores = storeController.latestStoreList;

      if (stores == null) {
        return _buildShimmer(context);
      }
      if (stores.isEmpty) {
        return const SizedBox();
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              child: Row(
                children: [
                  Icon(Icons.storefront_rounded, size: 20, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'nearby_stores'.tr,
                    style: robotoBold.copyWith(
                      fontSize: 17,
                      color: Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: stores.length,
                padding: const EdgeInsets.only(
                  left: Dimensions.paddingSizeDefault,
                ),
                itemBuilder: (context, index) {
                  return _StoreHeroCard(
                    store: stores[index],
                    primaryColor: primaryColor,
                    accentColor: accentColor,
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildShimmer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Container(
              width: 140,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              padding: const EdgeInsets.only(
                left: Dimensions.paddingSizeDefault,
              ),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Shimmer(
                    child: Container(
                      width: 260,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreHeroCard extends StatelessWidget {
  final Store store;
  final Color primaryColor;
  final Color accentColor;

  const _StoreHeroCard({
    required this.store,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOpen = store.open == 1;
    final bool hasDiscount =
        store.discount != null &&
        store.discount!.discount != null &&
        store.discount!.discount! > 0;

    return GestureDetector(
      onTap: () => Get.toNamed(
        RouteHelper.getStoreRoute(id: store.id, page: 'store'),
        arguments: StoreScreen(store: store, fromModule: false),
      ),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with overlay badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: CustomImage(
                      image: store.coverPhotoFullUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Open/Closed badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? accentColor
                          : Colors.red.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOpen ? 'open'.tr : 'closed'.tr,
                      style: robotoBold.copyWith(
                        fontSize: 10,
                        color: isOpen ? primaryColor : Colors.white,
                      ),
                    ),
                  ),
                ),

                // Discount badge
                if (hasDiscount)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade500,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${store.discount!.discount!.toInt()}% ${'off'.tr}',
                        style: robotoBold.copyWith(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                // Store logo
                Positioned(
                  bottom: -20,
                  left: 12,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CustomImage(
                        image: store.logoFullUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Store info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    store.name ?? '',
                    style: robotoBold.copyWith(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Rating + delivery time + min order
                  Row(
                    children: [
                      // Rating
                      if (store.avgRating != null && store.avgRating! > 0) ...[
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          store.avgRating!.toStringAsFixed(1),
                          style: robotoMedium.copyWith(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                        _dot(),
                      ],

                      // Delivery time
                      if (store.deliveryTime != null &&
                          store.deliveryTime!.isNotEmpty) ...[
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${store.deliveryTime} ${'min'.tr}',
                          style: robotoRegular.copyWith(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        _dot(),
                      ],

                      // Free delivery or min order
                      if (store.freeDelivery == true)
                        Text(
                          'free_delivery'.tr,
                          style: robotoMedium.copyWith(
                            fontSize: 11,
                            color: accentColor,
                          ),
                        )
                      else if (store.minimumOrder != null)
                        Text(
                          '${'min'.tr} ${store.minimumOrder!.toStringAsFixed(0)}',
                          style: robotoRegular.copyWith(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
