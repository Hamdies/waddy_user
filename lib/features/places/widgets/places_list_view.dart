import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/features/places/domain/models/place_model.dart';
import 'package:sixam_mart/features/places/widgets/place_card.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class PlacesListView extends StatelessWidget {
  const PlacesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      builder: (placesController) {
        List<Place>? places = placesController.places;

        if (placesController.isPlacesLoading &&
            (places == null || places.isEmpty)) {
          return _buildShimmer(context);
        }

        if (places == null || places.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Text('\uD83D\uDD0D', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'no_places_found'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: 16,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'try_different_filters'.tr,
                    style: robotoRegular.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).disabledColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              child: Row(
                children: [
                  const Text('💎', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'hidden_gems'.tr,
                    style: robotoBold.copyWith(fontSize: 18),
                  ),
                  const Spacer(),
                  if (placesController.totalPlaces != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '${placesController.totalPlaces} ${"places".tr}',
                        style: robotoMedium.copyWith(
                          color: Theme.of(context).secondaryHeaderColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              itemCount: places.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PlaceCard(
                    place: places[index],
                    onTap: () => Get.toNamed(
                      RouteHelper.getPlaceDetailsRoute(places[index].id),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          height: 130,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
          ),
        );
      },
    );
  }
}
