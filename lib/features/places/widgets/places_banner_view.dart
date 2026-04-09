import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_banner_model.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class PlacesBannerView extends StatefulWidget {
  const PlacesBannerView({super.key});

  @override
  State<PlacesBannerView> createState() => _PlacesBannerViewState();
}

class _PlacesBannerViewState extends State<PlacesBannerView> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      builder: (placesController) {
        List<PlaceBanner>? banners = placesController.banners;

        if (placesController.isBannersLoading) {
          return _buildShimmer();
        }

        if (banners == null || banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            SizedBox(
              height: 160,
              child: PageView.builder(
                controller: _pageController,
                itemCount: banners.length,
                onPageChanged: (index) {
                  placesController.setCurrentBannerIndex(index);
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                    ),
                    child: InkWell(
                      onTap: () => _handleBannerTap(banners[index]),
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                        child: CustomImage(
                          image: banners[index].image ?? '',
                          fit: BoxFit.cover,
                          height: 160,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (banners.length > 1) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              SmoothPageIndicator(
                controller: _pageController,
                count: banners.length,
                effect: WormEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  activeDotColor: Theme.of(context).primaryColor,
                  dotColor: Theme.of(context).disabledColor.withOpacity(0.3),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _handleBannerTap(PlaceBanner banner) {
    // Handle banner tap based on type
    if (banner.type == 'category' && banner.categoryId != null) {
      Get.find<PlacesController>().setSelectedCategory(banner.categoryId);
    } else if (banner.type == 'place' && banner.placeId != null) {
      // Navigate to place details
      // Get.toNamed(RouteHelper.getPlaceDetailsRoute(banner.placeId!));
    } else if (banner.link != null && banner.link!.isNotEmpty) {
      // Open external link
    }
  }

  Widget _buildShimmer() {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
    );
  }
}
