import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/card_design/store_list_card.dart'
    show kMinRatingsToShow;
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// A restaurant inside a search result list.
///
/// Deliberately lighter than [StoreListCard], which is the browse card: no
/// surface, no shadow, no offer pills. A result list is read by *scanning for a
/// name you already have in mind*, so the name is the only thing carrying bold
/// weight, and everything else — cuisines, rating, time — is the confirmation
/// you read once you have found it. Cards would put a container edge between
/// every two names and halve how many fit on a screen.
///
/// The metric line is built from discrete widgets rather than one interpolated
/// string, for the same reason [StoreListCard] does it: Western digits inside
/// an Arabic run get reordered by the bidi algorithm, which walks the
/// separators into the wrong gaps.
class SearchStoreRow extends StatelessWidget {
  final Store store;

  static const double _imageSize = 88;
  static const Color _ink = Color(0xFF1A1F1E);
  static const Color _inkMuted = Color(0xFF6B7876);
  static const Color _inkFaint = Color(0xFF9EAAA8);

  const SearchStoreRow({super.key, required this.store});

  void _openStore() {
    final splashController = Get.find<SplashController>();
    Get.find<SplashController>().activateModuleFor(store.moduleId);
    Get.toNamed(
      RouteHelper.getStoreRoute(id: store.id, page: 'store'),
      arguments: StoreScreen(store: store, fromModule: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuisines = store.cuisineNames ?? const <String>[];

    return Pressable(
      scale: 0.98,
      onTap: _openStore,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeSmall,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge - 2),
              child: CustomImage(
                image: store.coverPhotoFullUrl ?? '',
                variants: store.coverPhotoVariants,
                decodeWidth: _imageSize,
                height: _imageSize,
                width: _imageSize,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeDefault),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    store.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyBold.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: _ink,
                    ),
                  ),

                  if (cuisines.isNotEmpty) ...[
                    const SizedBox(
                      height: Dimensions.paddingSizeExtraSmall + 1,
                    ),
                    Text(
                      cuisines.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: waddyMedium.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall,
                        color: _inkFaint,
                      ),
                    ),
                  ],

                  const SizedBox(height: Dimensions.paddingSizeExtraSmall + 1),
                  _buildMetricRow(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context) {
    final rating = store.avgRating;
    final ratingCount = store.ratingCount ?? 0;
    final hasRating =
        rating != null && rating > 0 && ratingCount >= kMinRatingsToShow;

    final meta = <String>[];
    final deliveryTime = store.deliveryTime;
    if (deliveryTime != null && deliveryTime.isNotEmpty) {
      meta.add('$deliveryTime ${'min'.tr}');
    }
    if (store.freeDelivery == true) {
      meta.add('free_delivery'.tr);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasRating) ...[
          // Mint star with a dark outline, matching the rating mark used across
          // the redesigned surfaces — gold would be the only warm pixel here.
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFF1EF2A0)),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            textDirection: TextDirection.ltr,
            style: waddyBold.copyWith(
              fontSize: Dimensions.fontSizeExtraSmall,
              color: _ink,
            ),
          ),
        ],

        if (hasRating && meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeExtraSmall + 1,
            ),
            child: Text(
              '·',
              style: waddyRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: _inkMuted,
              ),
            ),
          ),

        if (meta.isNotEmpty)
          Flexible(
            child: Text(
              meta.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: waddyMedium.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: _inkMuted,
              ),
            ),
          ),
      ],
    );
  }
}
